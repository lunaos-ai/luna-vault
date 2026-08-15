import XCTest
@testable import VibeVaultApp

final class AuthenticatorIssuerCatalogTests: XCTestCase {
    func test_aliasSearchReturnsCanonicalIssuer() {
        let results = AuthenticatorIssuerCatalog.suggestions(
            for: "aws", existingIssuers: []
        )

        XCTAssertEqual(results.first?.name, "Amazon Web Services")
    }

    func test_existingCustomIssuerIsSuggestedBeforeCatalogMatches() {
        let results = AuthenticatorIssuerCatalog.suggestions(
            for: "luna", existingIssuers: ["LunaOS", "GitHub"]
        )

        XCTAssertEqual(results.first?.name, "LunaOS")
        XCTAssertNil(results.first?.systemImage)
    }

    func test_resolveIsCaseAndPunctuationInsensitive() {
        XCTAssertEqual(
            AuthenticatorIssuerCatalog.resolve("google-cloud")?.name,
            "Google"
        )
    }
}
