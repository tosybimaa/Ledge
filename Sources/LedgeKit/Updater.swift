import AppKit
import CryptoKit
import Foundation

/// In-app updates from your own GitHub Releases: check, download, verify the signature, swap the app, relaunch.
/// Publish a release with `scripts/release.sh`; every installed copy picks it up here.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    /// GitHub "owner/repo" that holds the releases. The repo (or at least its releases) must be public.
    static let repository = "tosybimaa/Ledge"
    static let publicKey = "2zE3rtkqPx/bDbTtbugothb4TO7hMsft8LrIuUFg+f8="

    enum Status: Equatable {
        case idle, checking, upToDate, notInstalled
        case downloading(String), installing(String)
        case failed(String)
    }

    @Published private(set) var status = Status.idle
    @Published private(set) var notes = ""

    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
    /// Only a built Ledge.app can replace itself; `swift run` has no bundle to swap.
    var isInstalledApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    /// Checks now and installs a newer release straight away.
    func checkAndInstall() async {
        switch status {
        case .checking, .downloading, .installing: return
        default: break
        }
        guard isInstalledApp else { status = .notInstalled; return }
        status = .checking
        do {
            let release = try await latestRelease()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: K.lastUpdateCheck.rawValue)
            notes = release.body ?? ""
            let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard Self.isNewer(version, than: currentVersion) else {
                status = .upToDate
                return
            }
            status = .downloading(version)
            let archive = try await download(release.asset("Ledge.zip"))
            let signature = try await download(release.asset("Ledge.zip.sig"))
            try Self.verify(archive, signature: signature, publicKey: Self.publicKey)
            status = .installing(version)
            try install(archive)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// At launch and then once a day, while "Automatically install updates" is on.
    func startAutomaticChecks() {
        Task {
            try? await Task.sleep(for: .seconds(10))
            while true {
                if UserDefaults.standard.object(forKey: K.autoUpdate.rawValue) as? Bool ?? true {
                    await checkAndInstall()
                }
                try? await Task.sleep(for: .seconds(86_400))
            }
        }
    }

    // MARK: - Steps

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }
        let tagName: String
        let body: String?
        let assets: [Asset]

        func asset(_ name: String) throws -> URL {
            guard let asset = assets.first(where: { $0.name == name }) else { throw UpdateError("The release has no \(name).") }
            return asset.browserDownloadUrl
        }
    }

    private func latestRelease() async throws -> Release {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest") else {
            throw UpdateError("Updater.repository is not a valid owner/repo.")
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data = try await download(request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Release.self, from: data)
    }

    private func download(_ url: URL) async throws -> Data {
        try await download(URLRequest(url: url))
    }

    private func download(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw UpdateError("The update server answered \(code).") }
        return data
    }

    /// Unzips next to a backup, then a helper swaps the bundles after Ledge quits and reopens it.
    /// If the swap fails, the old app is put back, so a bad update never leaves you without Ledge.
    private func install(_ archive: Data) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("ledge-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        let zip = work.appendingPathComponent("Ledge.zip")
        try archive.write(to: zip)
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])

        let newApp = work.appendingPathComponent("Ledge.app")
        guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError("The download is not Ledge. Update refused.")
        }
        let backup = work.appendingPathComponent("Ledge-previous.app")
        // Paths go in as arguments ($2…$4), never into the script text.
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if mv "$2" "$4" && mv "$3" "$2"; then open "$2"; else [ -e "$2" ] || mv "$4" "$2"; open "$2"; fi
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "ledge-update", String(ProcessInfo.processInfo.processIdentifier),
                            Bundle.main.bundleURL.path, newApp.path, backup.path]
        try helper.run()
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError("Could not unpack the update.") }
    }

    // MARK: - Pure checks (tested)

    /// "1.10" is newer than "1.9"; "1.0" is not newer than "1".
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Throws unless `signature` (base64 text) was made for `data` with the private key behind `publicKey`.
    nonisolated static func verify(_ data: Data, signature: Data, publicKey: String) throws {
        guard let keyData = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        else { throw UpdateError("No update key is set in Updater.swift, so updates are refused.") }
        let text = String(decoding: signature, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let signatureData = Data(base64Encoded: text), key.isValidSignature(signatureData, for: data) else {
            throw UpdateError("The download's signature does not match. Update refused.")
        }
    }
}

struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
