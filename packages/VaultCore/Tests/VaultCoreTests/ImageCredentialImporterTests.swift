import XCTest
@testable import VaultCore

final class ImageCredentialImporterTests: XCTestCase {
    func test_parseRecognizedText_extracts_slack_credential_fields() {
        let text = """
        Basic Information
        App Credentials
        These credentials allow your app to access the Slack API.
        App ID
        ATEST12345
        Client ID
        1234567890.0987654321
        Client Secret
        fakeClientSecret123456 Show Regenerate
        Signing Secret
        fakeSigningSecret789 Show Regenerate
        Verification Token
        fakeVerifyTokenABC
        Date of App Creation
        July 23, 2026
        """

        let items = ImageCredentialImporter.parseRecognizedText(text, source: "slack-credentials.png")
        let pairs = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })

        XCTAssertEqual(pairs["SLACK_APP_ID"], "ATEST12345")
        XCTAssertEqual(pairs["SLACK_CLIENT_ID"], "1234567890.0987654321")
        XCTAssertEqual(pairs["SLACK_CLIENT_SECRET"], "fakeClientSecret123456")
        XCTAssertEqual(pairs["SLACK_SIGNING_SECRET"], "fakeSigningSecret789")
        XCTAssertEqual(pairs["SLACK_VERIFICATION_TOKEN"], "fakeVerifyTokenABC")
        XCTAssertNil(pairs["SLACK_DATE_OF_APP_CREATION"])
    }

    func test_parseRecognizedText_uses_source_prefix_when_provider_unknown() {
        let text = """
        API Key
        sk-test-example
        """

        let items = ImageCredentialImporter.parseRecognizedText(text, source: "my app screenshot.png")

        XCTAssertEqual(items.first?.name, "MY_APP_SCREENSHOT_API_KEY")
        XCTAssertEqual(items.first?.value, "sk-test-example")
    }
}
