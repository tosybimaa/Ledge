import CryptoKit
import XCTest
@testable import LedgeKit

final class LedgeKitTests: XCTestCase {
    func testClockFormatting() {
        XCTAssertEqual(PlayerModel.clock(84), "1:24")
        XCTAssertEqual(PlayerModel.clock(5), "0:05")
        XCTAssertEqual(PlayerModel.clock(-3), "0:00")
    }

    func testResetClearsEveryKey() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LedgeKitTests"))
        K.allCases.forEach { defaults.set(true, forKey: $0.rawValue) }
        Preferences.resetAll(defaults)
        for key in K.allCases {
            XCTAssertNil(defaults.object(forKey: key.rawValue), key.rawValue)
        }
    }

    func testResetAppearanceKeepsOtherSettings() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LedgeKitTests.appearance"))
        defaults.set(1.3, forKey: K.uiScale.rawValue)
        defaults.set(false, forKey: K.eq.rawValue)
        Preferences.reset(Preferences.appearance, defaults)
        XCTAssertNil(defaults.object(forKey: K.uiScale.rawValue))
        XCTAssertNotNil(defaults.object(forKey: K.eq.rawValue))
    }

    func testVersionOrdering() {
        XCTAssertTrue(Updater.isNewer("1.2", than: "1.1"))
        XCTAssertTrue(Updater.isNewer("1.10", than: "1.9"))
        XCTAssertFalse(Updater.isNewer("1.0", than: "1"))
        XCTAssertFalse(Updater.isNewer("1.1", than: "1.1.1"))
        XCTAssertFalse(Updater.isNewer("1.2", than: "1.2"))
    }

    func testOnlySignedDownloadsAreAccepted() throws {
        let key = Curve25519.Signing.PrivateKey()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        let archive = Data("Ledge.zip contents".utf8)
        let signature = Data(try key.signature(for: archive).base64EncodedString().utf8)

        XCTAssertNoThrow(try Updater.verify(archive, signature: signature, publicKey: publicKey))
        XCTAssertThrowsError(try Updater.verify(Data("tampered".utf8), signature: signature, publicKey: publicKey))
        XCTAssertThrowsError(try Updater.verify(archive, signature: signature, publicKey: ""))
        let otherKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        XCTAssertThrowsError(try Updater.verify(archive, signature: signature, publicKey: otherKey))
    }

    func testSyncedLyricsParsing() {
        let lrc = "[ar:Someone]\n[00:12.50]First line\n[00:05.00][01:00.00]Chorus\n[00:20.00]\n"
        let lines = PlayerModel.parseLRC(lrc)
        XCTAssertEqual(lines.map(\.text), ["Chorus", "First line", "Chorus"])
        XCTAssertEqual(lines.map(\.time), [5, 12.5, 60])
    }

    func testAirPodsBatteryFromSystemProfiler() throws {
        let json = """
        {"SPBluetoothDataType":[{"device_connected":[{"AirPods Pro":{"device_batteryLevelLeft":"80%","device_batteryLevelRight":"74%","device_batteryLevelCase":"100%"}},{"Speaker":{"device_batteryLevelMain":"55%"}}]}]}
        """
        let data = Data(json.utf8)
        XCTAssertEqual(SystemMonitor.parseBattery(data, name: "AirPods Pro"), 74)
        XCTAssertEqual(SystemMonitor.parseBattery(data, name: "Speaker"), 55)
        XCTAssertNil(SystemMonitor.parseBattery(data, name: "Keyboard"))
    }

    func testWeatherCodes() {
        XCTAssertEqual(WeatherModel.symbol(code: 0, day: false), "moon.stars.fill")
        XCTAssertEqual(WeatherModel.symbol(code: 63, day: true), "cloud.rain.fill")
        XCTAssertEqual(WeatherModel.condition(code: 95), "Thunderstorm")
    }
}
