import ArgumentParser
import XCTest
@testable import vibevault

final class AddCommandTests: XCTestCase {
    func test_explicit_value_wins() throws {
        let v = try AddCommand.resolveSecretValue(
            explicit: "tok", isTTY: false,
            readPiped: { "piped" }, promptHidden: { "prompted" }
        )
        XCTAssertEqual(v, "tok")
    }

    // Regression: piping a value used to hit an interactive prompt instead of
    // reading stdin. Non-tty must read the pipe and never prompt.
    func test_piped_value_read_when_not_tty() throws {
        var prompted = false
        let v = try AddCommand.resolveSecretValue(
            explicit: nil, isTTY: false,
            readPiped: { "from-pipe" },
            promptHidden: { prompted = true; return "should-not-run" }
        )
        XCTAssertEqual(v, "from-pipe")
        XCTAssertFalse(prompted, "must not prompt when stdin is piped")
    }

    func test_tty_uses_hidden_prompt() throws {
        let v = try AddCommand.resolveSecretValue(
            explicit: nil, isTTY: true,
            readPiped: { "from-pipe" }, promptHidden: { "hidden-secret" }
        )
        XCTAssertEqual(v, "hidden-secret")
    }

    // Regression guard: never silently store a blank secret.
    func test_empty_piped_value_rejected() {
        XCTAssertThrowsError(try AddCommand.resolveSecretValue(
            explicit: nil, isTTY: false, readPiped: { "" }, promptHidden: { nil }
        ))
    }

    func test_nil_piped_value_rejected() {
        XCTAssertThrowsError(try AddCommand.resolveSecretValue(
            explicit: nil, isTTY: false, readPiped: { nil }, promptHidden: { nil }
        ))
    }

    func test_empty_prompt_rejected() {
        XCTAssertThrowsError(try AddCommand.resolveSecretValue(
            explicit: nil, isTTY: true, readPiped: { nil }, promptHidden: { "" }
        ))
    }
}
