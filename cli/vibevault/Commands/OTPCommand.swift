import ArgumentParser
import Foundation
import VaultCore

struct OTPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "otp",
        abstract: "Manage standalone authenticator accounts.",
        subcommands: [
            OTPAddCommand.self, OTPImportURICommand.self, OTPImportImageCommand.self,
            OTPListCommand.self, OTPCodeCommand.self, OTPRecoveryCommand.self,
            OTPDeleteCommand.self, OTPClipboardClearCommand.self
        ]
    )
}

enum OTPCLI {
    static func stdin(maxBytes: Int = 16_384) throws -> String {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty, data.count <= maxBytes,
              let value = String(data: data, encoding: .utf8) else {
            throw ValidationError("stdin is empty, too large, or not UTF-8")
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError("stdin is empty") }
        return trimmed
    }

    static func resolve(_ identifier: String, in service: AuthenticatorService) throws -> UUID {
        if let id = UUID(uuidString: identifier), try service.list().contains(where: { $0.id == id }) {
            return id
        }
        let matches = try service.list().filter {
            $0.issuer.caseInsensitiveCompare(identifier) == .orderedSame
                || $0.accountName.caseInsensitiveCompare(identifier) == .orderedSame
                || "\($0.issuer):\($0.accountName)".caseInsensitiveCompare(identifier) == .orderedSame
        }
        guard matches.count == 1, let id = matches.first?.id else {
            throw ValidationError(matches.isEmpty ? "authenticator not found" : "authenticator name is ambiguous; use its UUID")
        }
        return id
    }
}
