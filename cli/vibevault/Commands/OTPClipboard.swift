import AppKit
import ArgumentParser
import Foundation

enum OTPClipboard {
    static func copy(_ value: String, expiresAfter seconds: Int) throws {
        let board = NSPasteboard.general
        board.clearContents()
        guard board.setString(value, forType: .string) else {
            throw ValidationError("could not write to clipboard")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = [
            "otp", "clipboard-clear", "--change-count", String(board.changeCount),
            "--after", String(max(5, min(300, seconds)))
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }
}

struct OTPClipboardClearCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard-clear", shouldDisplay: false)
    @Option(name: .long) var changeCount: Int
    @Option(name: .long) var after: Int

    mutating func run() async throws {
        try await Task.sleep(nanoseconds: UInt64(max(1, after)) * 1_000_000_000)
        let board = NSPasteboard.general
        if board.changeCount == changeCount { board.clearContents() }
    }
}
