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

    func testEverySettingHasOneRegisteredDefault() throws {
        let missing = K.allCases.filter { $0 != .lastUpdateCheck && Preferences.defaults[$0] == nil }
        XCTAssertEqual(missing, [], "Add these to Preferences.defaults")
        let store = try XCTUnwrap(UserDefaults(suiteName: "LedgeKitTests.defaults"))
        Preferences.registerDefaults(store)
        XCTAssertEqual(store.double(forKey: K.sensoryDuration.rawValue), 3)
        XCTAssertFalse(store.bool(forKey: K.hideFromCapture.rawValue))
        XCTAssertTrue(store.bool(forKey: K.expandOnHover.rawValue))
    }

    func testTrackpadSwipeTurnsPages() {
        XCTAssertEqual(NotchController.swipeStep(CGSize(width: -60, height: 5), natural: true), 1)
        XCTAssertEqual(NotchController.swipeStep(CGSize(width: 60, height: 5), natural: true), -1)
        XCTAssertEqual(NotchController.swipeStep(CGSize(width: 60, height: 5), natural: false), 1)
        XCTAssertNil(NotchController.swipeStep(CGSize(width: 20, height: 0), natural: true))
        XCTAssertNil(NotchController.swipeStep(CGSize(width: 60, height: 50), natural: true))
    }

    func testNextPrayerAndCountdown() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12, minute: 12)))
        let prayers = [("Subuh", "04:10"), ("Dzuhur", "11:40"), ("Ashar", "14:56 (WIB)"), ("Maghrib", "17:49"), ("Isya", "19:01")]
            .map { Prayer(name: $0.0, time: PrayerModel.time($0.1, on: day, calendar: calendar)!) }
        let next = try XCTUnwrap(PrayerModel.next(after: day, in: prayers))
        XCTAssertEqual(next.name, "Ashar")
        XCTAssertEqual(PrayerModel.countdown(from: day, to: next.time), "2 h 44 min")
        let late = day.addingTimeInterval(9 * 3600)  // 21:12, after Isya
        XCTAssertEqual(PrayerModel.next(after: late, in: prayers)?.name, "Subuh")
        XCTAssertNil(PrayerModel.time("soon", on: day))
    }
}
