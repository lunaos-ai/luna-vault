import ArgumentParser
import Foundation
import VaultCore

struct OTPRecoveryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recovery", abstract: "Manage recovery codes.",
        subcommands: [OTPRecoveryImportCommand.self, OTPRecoveryNextCommand.self]
    )
}

struct OTPRecoveryImportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "import", abstract: "Replace recovery codes from stdin.")
    @Argument var identifier: String
    @Flag(name: .long) var stdin = false
    mutating func run() async throws {
        guard stdin else { throw ValidationError("use --stdin so recovery codes are not stored in shell history") }
        let values = try OTPCLI.stdin(maxBytes: 64 * 1_024)
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let service = try AuthenticatorService.live()
        let id = try OTPCLI.resolve(identifier, in: service)
        try await service.addRecoveryCodes(id: id, values: values)
        print("saved \(values.count) recovery codes")
    }
}

struct OTPRecoveryNextCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "next", abstract: "Reveal the next unused recovery code.")
    @Argument var identifier: String
    @Flag(name: .long) var copy = false
    @Option(name: .long) var clipboardSeconds = 30
    mutating func run() async throws {
        let service = try AuthenticatorService.live()
        let id = try OTPCLI.resolve(identifier, in: service)
        let code = try await service.nextRecoveryCode(id: id)
        if copy {
            try OTPClipboard.copy(code.value, expiresAfter: clipboardSeconds)
            print("copied; mark used with the app after use")
        } else {
            print(code.value)
        }
    }
}
