import AppKit
import ArgumentParser
import Foundation
import VaultCore

struct OTPListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List authenticator metadata.")
    @Flag(name: .long, help: "Output JSON.") var json = false

    mutating func run() async throws {
        let accounts = try AuthenticatorService.live().list()
        if json {
            let payload: [[String: Any]] = accounts.map {
                ["id": $0.id.uuidString, "issuer": $0.issuer, "account": $0.accountName,
                 "digits": $0.digits, "period": $0.period, "favorite": $0.favorite,
                 "recovery_codes_remaining": $0.unusedRecoveryCodeCount]
            }
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8) ?? "[]")
        } else if accounts.isEmpty {
            print("(no authenticators)")
        } else {
            for account in accounts {
                print("\(account.id.uuidString)  \(account.issuer)  \(account.accountName)")
            }
        }
    }
}

struct OTPCodeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "code", abstract: "Generate a current authenticator code.")
    @Argument(help: "Account UUID, issuer, account name, or issuer:account.") var identifier: String
    @Flag(name: .long, help: "Copy instead of printing.") var copy = false
    @Option(name: .long, help: "Clipboard lifetime in seconds.") var clipboardSeconds = 30

    mutating func run() async throws {
        let service = try AuthenticatorService.live()
        let id = try OTPCLI.resolve(identifier, in: service)
        let result = try await service.code(id: id, reason: "Generate authenticator code from CLI")
        if copy {
            try OTPClipboard.copy(result.code, expiresAfter: clipboardSeconds)
            print("copied; expires in \(max(5, min(300, clipboardSeconds)))s")
        } else {
            print(result.code)
        }
    }
}

struct OTPDeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete an authenticator account.")
    @Argument var identifier: String
    mutating func run() async throws {
        let service = try AuthenticatorService.live()
        let id = try OTPCLI.resolve(identifier, in: service)
        try await service.delete(id: id)
        print("deleted \(id.uuidString)")
    }
}
