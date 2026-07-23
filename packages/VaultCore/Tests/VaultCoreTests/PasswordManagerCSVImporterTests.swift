import XCTest
@testable import VaultCore

final class PasswordManagerCSVImporterTests: XCTestCase {
    func test_bitwarden_csv_imports_login_passwords() {
        let csv = """
        folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp
        Dev,0,login,Google AI Studio,,,0,https://aistudio.google.com,dev@example.com,gemini-secret,JBSWY3DPEHPK3PXP
        """

        let items = PasswordManagerCSVImporter.parse(csv, profile: .bitwarden)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "GOOGLE_AI_STUDIO_PASSWORD")
        XCTAssertEqual(items[0].value, "gemini-secret")
        XCTAssertEqual(items[0].totpAuthURL, "otpauth://totp/Google%20AI%20Studio?secret=JBSWY3DPEHPK3PXP&issuer=Bitwarden")
        XCTAssertTrue(items[0].notes?.contains("Bitwarden") == true)
        XCTAssertTrue(items[0].notes?.contains("dev@example.com") == true)
        XCTAssertTrue(items[0].notes?.contains("MFA code included") == true)
    }

    func test_apple_passwords_csv_imports_password_column() {
        let csv = """
        Title,URL,Username,Password,Notes,OTPAuth
        OpenRouter,https://openrouter.ai,me@example.com,"key,with,commas",,
        """

        let items = PasswordManagerCSVImporter.parse(csv, profile: .applePasswords)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "OPENROUTER_PASSWORD")
        XCTAssertEqual(items[0].value, "key,with,commas")
        XCTAssertTrue(items[0].notes?.contains("Apple Passwords") == true)
    }

    func test_apple_passwords_csv_preserves_otpauth_url() {
        let csv = """
        Title,URL,Username,Password,Notes,OTPAuth
        Console,https://console.example.com,me@example.com,password123,,otpauth://totp/Console:me@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Console
        """

        let items = PasswordManagerCSVImporter.parse(csv, profile: .applePasswords)

        XCTAssertEqual(items.first?.totpAuthURL, "otpauth://totp/Console:me@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Console")
    }

    func test_auto_detects_lastpass_shape() {
        let csv = """
        url,username,password,extra,name,grouping,fav
        https://console.example.com,admin@example.com,s3cret,notes,Console,Work,0
        """

        let items = PasswordManagerCSVImporter.parse(csv, profile: .auto)

        XCTAssertEqual(items.first?.name, "CONSOLE_PASSWORD")
        XCTAssertTrue(items.first?.notes?.contains("LastPass") == true)
    }
}
