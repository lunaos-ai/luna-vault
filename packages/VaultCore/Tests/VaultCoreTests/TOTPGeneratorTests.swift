import XCTest
@testable import VaultCore

final class TOTPGeneratorTests: XCTestCase {
    func test_rfc6238_sha1_vector() throws {
        let url = "otpauth://totp/Test:alice@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&digits=8&period=30&algorithm=SHA1"

        let code = try TOTPGenerator.code(from: url, at: Date(timeIntervalSince1970: 59))

        XCTAssertEqual(code.code, "94287082")
        XCTAssertEqual(code.secondsRemaining, 1)
    }

    func test_normalizes_raw_setup_key_to_otpauth_url() throws {
        let url = try TOTPGenerator.normalizedAuthURL(
            from: "jbsw y3dp ehpk 3pxp",
            label: "Example",
            issuer: "VibeVault"
        )

        let account = try TOTPGenerator.account(from: url)
        XCTAssertEqual(account.issuer, "VibeVault")
        XCTAssertEqual(account.account, "Example")
        XCTAssertEqual(account.digits, 6)
        XCTAssertEqual(account.period, 30)
    }

    func test_invalid_setup_key_fails() {
        XCTAssertThrowsError(try TOTPGenerator.account(from: "not valid ***")) { error in
            XCTAssertEqual(error as? TOTPError, .invalidSecret)
        }
    }

    func test_rotatingCodeIsRejectedAsEnrollmentMaterial() {
        XCTAssertThrowsError(try TOTPGenerator.account(from: "123456")) { error in
            XCTAssertEqual(error as? TOTPError, .temporaryCode)
        }
    }

    func test_conflictingIssuerInLabelAndQueryIsRejected() {
        let uri = "otpauth://totp/LabelIssuer:alice?secret=JBSWY3DPEHPK3PXP&issuer=QueryIssuer"
        XCTAssertThrowsError(try TOTPGenerator.account(from: uri)) { error in
            XCTAssertEqual(error as? TOTPError, .invalidParameter("issuer"))
        }
    }

    func test_duplicateQueryParametersAreRejected() {
        let uri = "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&secret=GEZDGNBVGY3TQOJQ"
        XCTAssertThrowsError(try TOTPGenerator.account(from: uri)) { error in
            XCTAssertEqual(error as? TOTPError, .invalidParameter("duplicate secret"))
        }
    }

    func test_onlySixOrEightDigitCodesAreAccepted() {
        let uri = "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&digits=7"
        XCTAssertThrowsError(try TOTPGenerator.account(from: uri)) { error in
            XCTAssertEqual(error as? TOTPError, .invalidParameter("digits"))
        }
    }

    func test_timePeriodIsBounded() {
        let uri = "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&period=3600"
        XCTAssertThrowsError(try TOTPGenerator.account(from: uri)) { error in
            XCTAssertEqual(error as? TOTPError, .invalidParameter("period"))
        }
    }
}
