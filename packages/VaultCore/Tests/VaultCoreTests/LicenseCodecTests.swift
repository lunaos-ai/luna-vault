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
        XCTAssertTrue(decoded.isLicensed)
    }

    func test_studio_tier_is_licensed() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let license = TeamLicense(
            tier: "studio",
            email: "s@x.y",
            seats: 20,
            orderId: "o",
            productId: "p"
        )
        let raw = try LicenseCodec.sign(license, privateKey: priv)
        let decoded = try LicenseCodec.verify(raw, publicKey: priv.publicKey)
        XCTAssertTrue(decoded.isLicensed)
        XCTAssertTrue(decoded.isTeam)
    }

    func test_paid_tier_requires_positive_seats() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let license = TeamLicense(
            tier: "team",
            email: "zero@x.y",
            seats: 0,
            orderId: "o",
            productId: "p"
        )
        let raw = try LicenseCodec.sign(license, privateKey: priv)
        let decoded = try LicenseCodec.verify(raw, publicKey: priv.publicKey)
        XCTAssertFalse(decoded.isLicensed)
        XCTAssertFalse(decoded.isTeam)
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

    func test_forged_payload_without_raw_is_rejected() {
        let prefs = InMemoryPrefs()
        let forged = TeamLicense(email: "hacker@evil", seats: 99, orderId: "x", productId: "p")
        prefs.setCodable(forged, forKey: LicenseStore.payloadKey)
        XCTAssertNil(LicenseStore.load(prefs: prefs))
        XCTAssertFalse(TeamEntitlement.isLicensed(prefs: prefs))
        XCTAssertNil(prefs.data(forKey: LicenseStore.payloadKey))
    }

    func test_tampered_payload_ignored_raw_wins() throws {
        let prefs = InMemoryPrefs()
        let priv = Curve25519.Signing.PrivateKey()
        let real = TeamLicense(email: "real@co", seats: 5, orderId: "ord", productId: "team")
        let raw = try LicenseCodec.sign(real, privateKey: priv)
        // Activate against embedded pubkey would fail; store verified path via inject + custom verify.
        // Use activate only when pubkey matches — here inject raw after signing with ephemeral
        // key won't verify against embedded. So test load clearing on bad signature:
        prefs.set(raw.data(using: .utf8), forKey: LicenseStore.rawKey)
        prefs.setCodable(
            TeamLicense(email: "evil@co", seats: 999, orderId: "x", productId: "p"),
            forKey: LicenseStore.payloadKey
        )
        XCTAssertNil(LicenseStore.load(prefs: prefs))
        XCTAssertNil(prefs.data(forKey: LicenseStore.rawKey))
    }

    func test_store_activate_deactivate_with_ephemeral_pubkey_swap() throws {
        // Sign + verify with ephemeral key in codec path; store uses embedded pubkey.
        // Full Keychain activate covered when dist/lemonsqueezy/private.b64 is present.
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
        XCTAssertTrue(TeamEntitlement.isLicensed(prefs: prefs))
        _ = try TeamEntitlement.requireLicensed(prefs: prefs)

        // Tamper seats in cached payload — load must re-verify and restore signed seats.
        prefs.setCodable(
            TeamLicense(email: "team@lunaos.ai", seats: 999, orderId: "ord_test", productId: "team"),
            forKey: LicenseStore.payloadKey
        )
        XCTAssertEqual(LicenseStore.load(prefs: prefs)?.seats, 3)

        LicenseStore.deactivate(prefs: prefs)
        XCTAssertNil(LicenseStore.load(prefs: prefs))
        XCTAssertFalse(TeamEntitlement.isLicensed(prefs: prefs))
        XCTAssertThrowsError(try TeamEntitlement.requireLicensed(prefs: prefs)) { err in
            XCTAssertEqual(err as? LicenseError, .notLicensed)
        }
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

    func test_requireLicensed_denies_solo() {
        let prefs = InMemoryPrefs()
        XCTAssertThrowsError(try TeamEntitlement.requireLicensed(prefs: prefs)) { err in
            XCTAssertEqual(err as? LicenseError, .notLicensed)
        }
    }

    func test_default_checkout_uses_vibevault_subdomain() {
        XCTAssertEqual(LemonSqueezyConfig.defaultCheckoutURL, "https://vibevault.lunaos.ai/#pricing")
        XCTAssertFalse(LemonSqueezyConfig.defaultCheckoutURL.contains("REPLACE_VARIANT_ID"))
    }
}
