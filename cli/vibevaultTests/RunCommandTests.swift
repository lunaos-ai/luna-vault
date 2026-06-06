import XCTest
@testable import vibevault

final class RunCommandTests: XCTestCase {
    // Regression: `--only X -- sh -c '…'` used to capture "--" as the command,
    // making EnvInjector report `command not found: --`.
    func test_strips_double_dash_separator() throws {
        let cmd = try RunCommand.parse(["--only", "CF", "--", "sh", "-c", "echo hi"])
        XCTAssertEqual(cmd.only, ["CF"])
        XCTAssertEqual(cmd.command, ["sh", "-c", "echo hi"])
    }

    // Regression: `.upToNextOption` on --only swallowed `sh` into `only`,
    // leaving `-c` as the command → `command not found: -c`.
    func test_only_does_not_swallow_command_without_separator() throws {
        let cmd = try RunCommand.parse(["--only", "CF", "sh", "-c", "x"])
        XCTAssertEqual(cmd.only, ["CF"])
        XCTAssertEqual(cmd.command, ["sh", "-c", "x"])
    }

    func test_repeatable_only_and_exclude() throws {
        let cmd = try RunCommand.parse(["--only", "A", "--only", "B", "--exclude", "C", "--", "env"])
        XCTAssertEqual(cmd.only, ["A", "B"])
        XCTAssertEqual(cmd.exclude, ["C"])
        XCTAssertEqual(cmd.command, ["env"])
    }

    // Flags inside the passthrough command must survive untouched.
    func test_passes_flags_in_command_through() throws {
        let cmd = try RunCommand.parse(["--", "printenv", "CF_WRITE_TOKEN"])
        XCTAssertEqual(cmd.command, ["printenv", "CF_WRITE_TOKEN"])
    }

    // Only the FIRST `--` is the terminator; a second belongs to the child.
    func test_only_first_double_dash_stripped() throws {
        let cmd = try RunCommand.parse(["--", "tool", "--", "arg"])
        XCTAssertEqual(cmd.command, ["tool", "--", "arg"])
    }
}
