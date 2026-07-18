import ArgumentParser
import CryptoKit
import Foundation
import VaultCore

struct LicenseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "license",
        abstract: "Activate and manage the offline Team license.",
        subcommands: [
            LicenseStatusCommand.self,
            LicenseActivateCommand.self,
            LicenseDeactivateCommand.self,
            LicenseIssueCommand.self
        ]
    )
}

struct LicenseStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    mutating func run() async throws {
        let prefs = KeychainPrefs()
        guard let lic = LicenseStore.load(prefs: prefs) else {
            print("tier: solo")
            print("checkout: \(LemonSqueezyConfig.checkoutURL(prefs: prefs).absoluteString)")
            return
        }
        print("tier: \(lic.tier)")
        print("email: \(lic.email)")
        print("seats: \(lic.seats)")
        print("order: \(lic.orderId)")
        if let exp = lic.expiresAt {
            print("expires: \(ISO8601DateFormatter().string(from: exp))")
        } else {
            print("expires: never")
        }
    }
}

struct LicenseActivateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate")

    @Argument(help: "Signed license key (VV1.payload.sig).")
    var key: String

    mutating func run() async throws {
        let prefs = KeychainPrefs()
        let lic = try LicenseStore.activate(key, prefs: prefs)
        print("activated team license for \(lic.email) (\(lic.seats) seats)")
    }
}

struct LicenseDeactivateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "deactivate")

    mutating func run() async throws {
        LicenseStore.deactivate(prefs: KeychainPrefs())
        print("license removed")
    }
}

struct LicenseIssueCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "issue",
        abstract: "Sign a Team license (operators only; needs private key)."
    )

    @Option(name: .long) var email: String
    @Option(name: .long) var seats: Int = 5
    @Option(name: .long) var orderId: String
    @Option(name: .long) var productId: String = "team"
    @Option(name: .long, help: "Days until expiry; omit for never.")
    var days: Int?
    @Option(name: .long, help: "Override VIBEVAULT_LICENSE_PRIVATE_KEY / private.b64.")
    var privateKey: String?

    mutating func run() async throws {
        let priv = try loadPrivateKey()
        var expires: Date?
        if let days { expires = Date().addingTimeInterval(TimeInterval(days * 86_400)) }
        let license = TeamLicense(
            email: email,
            seats: seats,
            expiresAt: expires,
            orderId: orderId,
            productId: productId
        )
        print(try LicenseCodec.sign(license, privateKey: priv))
    }

    private func loadPrivateKey() throws -> Curve25519.Signing.PrivateKey {
        if let privateKey {
            let s = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
            return try LicenseCodec.privateKey(fromBase64: s)
        }
        if let env = ProcessInfo.processInfo.environment["VIBEVAULT_LICENSE_PRIVATE_KEY"], !env.isEmpty {
            return try LicenseCodec.privateKey(fromBase64: env.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("dist/lemonsqueezy/private.b64")
        guard let data = try? Data(contentsOf: path),
              let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else {
            throw ValidationError("set VIBEVAULT_LICENSE_PRIVATE_KEY or dist/lemonsqueezy/private.b64")
        }
        return try LicenseCodec.privateKey(fromBase64: s)
    }
}
