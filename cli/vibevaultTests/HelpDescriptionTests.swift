import XCTest
@testable import vibevault

final class HelpDescriptionTests: XCTestCase {
    func test_root_help_explains_local_agent_access() {
        let help = normalized(VibeVault.helpMessage(columns: 200))

        XCTAssertTrue(help.contains("same Mac and user"))
        XCTAssertTrue(help.contains("macOS Keychain"))
        XCTAssertTrue(help.contains("host-level execution"))
        XCTAssertTrue(help.contains("vibevault run --only NAME"))
    }

    func test_run_help_explains_use_and_retrieval() {
        let help = normalized(RunCommand.helpMessage(columns: 200))

        XCTAssertTrue(help.contains("Prefer injection over retrieval"))
        XCTAssertTrue(help.contains("pbcopy"))
        XCTAssertTrue(help.contains("printenv"))
        XCTAssertTrue(help.contains("never reset the vault master key"))
    }

    private func normalized(_ help: String) -> String {
        help.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
