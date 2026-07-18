import XCTest
import CryptoKit
@testable import VaultCore

final class LicenseCodecTests: XCTestCase {
    func test_sign_and_verify_roundTrip() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let license = TeamLicense(
            email: "dev@lunaos.ai",
            seats: 5,
            orderId: "order_test",
            productId: "prod_team"
        )
        let raw = try LicenseCodec.sign(license, privateKey: priv)
        XCTAssertTrue(raw.hasPrefix("VV1."))
        let decoded = try LicenseCodec.verify(raw, publicKey: priv.publicKey)
        XCTAssertEqual(decoded.email, "dev@lunaos.ai")
        XCTAssertEqual(decoded.seats, 5)
        XCTAssertTrue(decoded.isTeam)
    }

    func test_bad_signature_rejected() throws {
        let a = Curve25519.Signing.PrivateKey()
        let b = Curve25519.Signing.PrivateKey()
        let license = TeamLicense(email: "x@y.z", seats: 1, orderId: "o", productId: "p")
        let raw = try LicenseCodec.sign(license, privateKey: a)
        XCTAssertThrowsError(try LicenseCodec.verify(raw, publicKey: b.publicKey)) { err in
            XCTAssertEqual(err as? LicenseError, .badSignature)
        }
    }

    func test_expired_rejected() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let license = TeamLicense(
            email: "x@y.z",
            seats: 1,
            issuedAt: Date(timeIntervalSince1970: 1),
            expiresAt: Date(timeIntervalSince1970: 2),
            orderId: "o",
            productId: "p"
        )
        let raw = try LicenseCodec.sign(license, privateKey: priv)
        XCTAssertThrowsError(try LicenseCodec.verify(raw, publicKey: priv.publicKey)) { err in
            XCTAssertEqual(err as? LicenseError, .expired)
        }
    }

    func test_store_activate_with_dev_keypair() throws {
        let prefs = InMemoryPrefs()
        LicenseStore.deactivate(prefs: prefs)
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let privPath = root.appendingPathComponent("dist/lemonsqueezy/private.b64")
        guard let data = try? Data(contentsOf: privPath),
              let b64 = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !b64.isEmpty else {
            throw XCTSkip("dist/lemonsqueezy/private.b64 missing (local operator key)")
        }
        let priv = try LicenseCodec.privateKey(fromBase64: b64)
        let license = TeamLicense(email: "team@lunaos.ai", seats: 3, orderId: "ord_test", productId: "team")
        let raw = try LicenseCodec.sign(license, privateKey: priv)
        let saved = try LicenseStore.activate(raw, prefs: prefs)
        XCTAssertEqual(saved.email, "team@lunaos.ai")
        XCTAssertEqual(LicenseStore.load(prefs: prefs)?.seats, 3)
        LicenseStore.deactivate(prefs: prefs)
        XCTAssertNil(LicenseStore.load(prefs: prefs))
    }

    func test_invalid_format() {
        XCTAssertThrowsError(try LicenseCodec.verify("not-a-key")) { err in
            XCTAssertEqual(err as? LicenseError, .invalidFormat)
        }
    }

    func test_embedded_public_key_loads() throws {
        let key = try LicensePublicKey.curveKey()
        XCTAssertEqual(key.rawRepresentation.count, 32)
    }
}
