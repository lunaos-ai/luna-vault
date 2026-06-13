import XCTest
@testable import VaultCore

final class SecretSearchTests: XCTestCase {
    private func secrets() -> [Secret] {
        [
            Secret(name: "STRIPE_KEY", value: "sk_live_abc123", notes: "billing prod"),
            Secret(name: "STRIPE_TEST", value: "sk_test_zzz", notes: nil),
            Secret(name: "OPENAI_API_KEY", value: "sk-proj-stripe-lookalike", notes: "model access"),
            Secret(name: "DB_URL", value: "postgres://u:p@h/db", notes: "primary database")
        ]
    }

    func test_emptyQuery_returnsNothing() {
        XCTAssertTrue(SecretSearch.rank(secrets(), query: "   ").isEmpty)
    }

    func test_exactName_scoresHighest() {
        let hits = SecretSearch.rank(secrets(), query: "DB_URL")
        XCTAssertEqual(hits.first?.secret.name, "DB_URL")
        XCTAssertEqual(hits.first?.field, .name)
        XCTAssertEqual(hits.first?.score, 100)
    }

    func test_prefixBeatsContains() {
        let hits = SecretSearch.rank(secrets(), query: "STRIPE")
        // Both STRIPE_KEY and STRIPE_TEST prefix-match; OPENAI matches only in value.
        XCTAssertEqual(Set(hits.prefix(2).map(\.secret.name)), ["STRIPE_KEY", "STRIPE_TEST"])
        XCTAssertEqual(hits.last?.secret.name, "OPENAI_API_KEY")
        XCTAssertEqual(hits.last?.field, .value)
    }

    func test_notesMatch_whenNameMisses() {
        let hits = SecretSearch.rank(secrets(), query: "database")
        XCTAssertEqual(hits.map(\.secret.name), ["DB_URL"])
        XCTAssertEqual(hits.first?.field, .notes)
    }

    func test_valueMatch_isLowestPriority() {
        let hits = SecretSearch.rank(secrets(), query: "postgres")
        XCTAssertEqual(hits.first?.secret.name, "DB_URL")
        XCTAssertEqual(hits.first?.field, .value)
    }

    func test_caseInsensitive() {
        XCTAssertEqual(SecretSearch.rank(secrets(), query: "stripe_key").first?.secret.name, "STRIPE_KEY")
    }

    func test_limitRespected() {
        let many = (0..<50).map { Secret(name: "KEY_\($0)", value: "v") }
        XCTAssertEqual(SecretSearch.rank(many, query: "KEY", limit: 5).count, 5)
    }
}
