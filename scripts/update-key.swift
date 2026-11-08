// Signs update archives so Ledge only installs builds you made.
//   swift scripts/update-key.swift generate     makes ~/.ledge/update-key and prints the public key for Updater.swift
//   swift scripts/update-key.swift sign FILE    writes FILE.sig
import CryptoKit
import Foundation

let keyURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ledge/update-key")
let args = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

switch args.first {
case "generate":
    if FileManager.default.fileExists(atPath: keyURL.path) {
        fail("A key already exists at \(keyURL.path). Delete it only if you mean to: installed copies will then refuse new releases until you update Updater.publicKey.")
    }
    let key = Curve25519.Signing.PrivateKey()
    try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try key.rawRepresentation.base64EncodedString().write(to: keyURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
    print("Private key saved to \(keyURL.path). Back it up and never commit it.")
    print("Paste this into Updater.publicKey:")
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard args.count == 2 else { fail("Usage: swift scripts/update-key.swift sign <file>") }
    guard let raw = try? String(contentsOf: keyURL, encoding: .utf8),
          let keyData = Data(base64Encoded: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
    else { fail("No usable key at \(keyURL.path). Run: swift scripts/update-key.swift generate") }
    let file = URL(fileURLWithPath: args[1])
    let signature = try key.signature(for: Data(contentsOf: file))
    try signature.base64EncodedString().write(to: file.appendingPathExtension("sig"), atomically: true, encoding: .utf8)
    print("Signed \(file.lastPathComponent) -> \(file.lastPathComponent).sig")
default:
    fail("Usage: swift scripts/update-key.swift generate | sign <file>")
}
