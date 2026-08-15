import ArgumentParser
import Foundation
import VaultCore

struct OTPAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a setup key from stdin.")
    @Flag(name: .long, help: "Read the setup key from stdin.") var stdin = false
    @Option(name: .long, help: "Authenticator issuer.") var issuer: String
    @Option(name: .long, help: "Account name or email.") var account: String

    mutating func run() async throws {
        guard stdin else { throw ValidationError("use --stdin so the setup key is not stored in shell history") }
        let saved = try await AuthenticatorService.live().add(
            input: OTPCLI.stdin(), issuer: issuer, accountName: account
        )
        print(saved.id.uuidString)
    }
}

struct OTPImportURICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "import-uri", abstract: "Import an otpauth URI from stdin.")
    @Flag(name: .long, help: "Read the otpauth URI from stdin.") var stdin = false

    mutating func run() async throws {
        guard stdin else { throw ValidationError("use --stdin so the URI is not stored in shell history") }
        let saved = try await AuthenticatorService.live().add(input: OTPCLI.stdin())
        print(saved.id.uuidString)
    }
}

struct OTPImportImageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "import-image", abstract: "Import an authenticator QR image.")
    @Argument(help: "Path to an image containing one authenticator QR code.") var path: String

    mutating func run() async throws {
        let payloads = try TOTPQRCodeDecoder.payloads(in: URL(fileURLWithPath: path))
        guard payloads.count == 1, let payload = payloads.first else {
            throw ValidationError("image contains multiple QR codes; crop or select one")
        }
        let saved = try await AuthenticatorService.live().add(input: payload)
        print(saved.id.uuidString)
    }
}
