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
}
