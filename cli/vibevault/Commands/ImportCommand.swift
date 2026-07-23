import ArgumentParser
import Foundation
import VaultCore

struct ImportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import secrets from dotenv files, environment, password apps, images, clipboard, or system Keychain."
    )

    @Option(name: .long, help: "Source: dotenv, env, op, clipboard, keychain, password-csv, image.") var from: String

    @Option(name: .long, help: "Path (for dotenv, password-csv, or image).") var path: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Glob patterns (for env source). Example: --pattern 'CF_*' 'STRIPE_*'") var pattern: [String] = []

    @Option(name: .long, help: "1Password item reference (for op source).") var item: String?

    @Option(name: .long, help: "Password CSV profile: auto, applePasswords, bitwarden, onePasswordCSV, lastPass, dashlane.") var profile: PasswordManagerImportProfile = .auto

    @Flag(name: .long, help: "Overwrite existing secrets if name matches.") var overwrite = false

    @Flag(name: .long, help: "Show what would be imported without writing.") var dryRun = false

    mutating func run() async throws {
        let service = try VaultService.live()
        let items = try collect()
        if items.isEmpty {
            print("(no candidates)")
            return
        }
        if dryRun {
            print("[dry-run] \(items.count) candidates:")
            for it in items { print("  - \(it.name)") }
            return
        }
        let result = try service.importSecrets(items, overwrite: overwrite)
        print("imported \(result.imported.count) · updated \(result.updated.count) · skipped \(result.skipped.count) · failed \(result.failed.count)")
        for f in result.failed { FileHandle.standardError.write(Data("  failed \(f.0): \(f.1)\n".utf8)) }
        if !result.failed.isEmpty { throw ExitCode(4) }
    }

    private func collect() throws -> [VaultService.ImportItem] {
        switch from {
        case "dotenv":
            guard let p = path else { throw ValidationError("--path required for dotenv") }
            return try DotenvImporter.parseFile(at: URL(fileURLWithPath: p))
        case "env":
            let globs = pattern.isEmpty ? ["*_TOKEN", "*_KEY", "*_SECRET", "*_PASSWORD", "*_API_KEY"] : pattern
            return EnvImporter.collect(matching: globs)
        case "op":
            guard let i = item else { throw ValidationError("--item required for 1Password import") }
            return try OnePasswordImporter.fetch(itemRef: i)
        case "clipboard":
            return ClipboardImporter.read()
        case "keychain":
            return try SystemKeychainImporter.scan()
        case "password-csv", "csv", "passwords":
            guard let p = path else { throw ValidationError("--path required for password-csv") }
            return try PasswordManagerCSVImporter.parseFile(at: URL(fileURLWithPath: p), profile: profile)
        case "image", "screenshot", "ocr":
            guard let p = path else { throw ValidationError("--path required for image") }
            return try ImageCredentialImporter.recognizeFile(at: URL(fileURLWithPath: p))
        default:
            throw ValidationError("unknown source: \(from). Use dotenv|env|op|clipboard|keychain|password-csv|image")
        }
    }
}

extension PasswordManagerImportProfile: ExpressibleByArgument {}
