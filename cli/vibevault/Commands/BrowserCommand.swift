import ArgumentParser
import Foundation

struct BrowserCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "browser",
        abstract: "Install and inspect the Vibe Vault browser import host.",
        subcommands: [BrowserStatusCommand.self, BrowserInstallCommand.self]
    )
}

struct BrowserStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show browser native messaging install status."
    )

    mutating func run() async throws {
        let host = BrowserHostInstaller.resolveHostBinary()
        print("host \(host ?? "(not found)")")
        for target in BrowserHostInstaller.BrowserTarget.allCases {
            let path = BrowserHostInstaller.manifestURL(for: target).path
            let installed = FileManager.default.fileExists(atPath: path)
            let state = installed ? "installed" : "missing"
            print("\(target.displayName.padding(toLength: 10, withPad: " ", startingAt: 0)) \(state)  \(path)")
        }
    }
}

struct BrowserInstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install the native messaging manifest for the browser extension."
    )

    @Option(name: .long, help: "Chrome extension id from chrome://extensions.")
    var extensionId: String

    @Option(name: .long, help: "Browser: chrome, brave, edge, chromium, all.")
    var browser: String = "chrome"

    @Option(name: .long, help: "Path to vibevault-browser-host binary.")
    var hostBinary: String?

    @Flag(name: .long, help: "Print intended changes without writing manifests.")
    var dryRun = false

    mutating func run() async throws {
        let normalizedId = extensionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard BrowserHostInstaller.isValidChromeExtensionId(normalizedId) else {
            throw ValidationError("--extension-id must be a 32-character Chrome extension id")
        }

        guard let host = hostBinary ?? BrowserHostInstaller.resolveHostBinary() else {
            FileHandle.standardError.write(Data("vibevault-browser-host not found\n".utf8))
            throw ExitCode(2)
        }
        guard FileManager.default.isExecutableFile(atPath: host) else {
            FileHandle.standardError.write(Data("host binary is not executable: \(host)\n".utf8))
            throw ExitCode(2)
        }

        let targets = try BrowserHostInstaller.targets(for: browser)
        for target in targets {
            let manifest = BrowserHostInstaller.Manifest(
                path: host,
                allowedOrigins: ["chrome-extension://\(normalizedId)/"]
            )
            let url = BrowserHostInstaller.manifestURL(for: target)
            if dryRun {
                print("would install \(target.displayName) -> \(url.path)")
            } else {
                try BrowserHostInstaller.install(manifest, for: target)
                print("installed \(target.displayName) -> \(url.path)")
            }
        }
    }
}

enum BrowserHostInstaller {
    static let hostName = "com.lunaos.vibevault.importer"

    enum BrowserTarget: String, CaseIterable {
        case chrome
        case brave
        case edge
        case chromium

        var displayName: String {
            switch self {
            case .chrome: return "Chrome"
            case .brave: return "Brave"
            case .edge: return "Edge"
            case .chromium: return "Chromium"
            }
        }

        var applicationSupportPath: String {
            switch self {
            case .chrome:
                return "Google/Chrome"
            case .brave:
                return "BraveSoftware/Brave-Browser"
            case .edge:
                return "Microsoft Edge"
            case .chromium:
                return "Chromium"
            }
        }
    }

    struct Manifest: Codable {
        let name = BrowserHostInstaller.hostName
        let description = "Vibe Vault browser API key importer"
        let path: String
        let type = "stdio"
        let allowedOrigins: [String]

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case path
            case type
            case allowedOrigins = "allowed_origins"
        }
    }

    static func targets(for raw: String) throws -> [BrowserTarget] {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "all" { return Array(BrowserTarget.allCases) }
        guard let target = BrowserTarget(rawValue: normalized) else {
            throw ValidationError("unknown browser: \(raw). Use chrome|brave|edge|chromium|all")
        }
        return [target]
    }

    static func manifestURL(for target: BrowserTarget) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(target.applicationSupportPath)
            .appendingPathComponent("NativeMessagingHosts")
            .appendingPathComponent("\(hostName).json")
    }

    static func install(_ manifest: Manifest, for target: BrowserTarget) throws {
        let url = manifestURL(for: target)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    static func resolveHostBinary(cliArgument: String = CommandLine.arguments[0]) -> String? {
        let fm = FileManager.default
        for path in hostCandidates(cliArgument: cliArgument) where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    static func hostCandidates(cliArgument: String) -> [String] {
        let exe = URL(fileURLWithPath: cliArgument).standardizedFileURL
        let dir = exe.deletingLastPathComponent()
        let cwd = FileManager.default.currentDirectoryPath
        return [
            dir.appendingPathComponent("vibevault-browser-host").path,
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/vibevault-browser-host").path,
            (cwd as NSString).appendingPathComponent(".build/release/vibevault-browser-host"),
            (cwd as NSString).appendingPathComponent(".build/debug/vibevault-browser-host"),
            "/usr/local/bin/vibevault-browser-host",
            "/opt/homebrew/bin/vibevault-browser-host"
        ]
    }

    static func isValidChromeExtensionId(_ value: String) -> Bool {
        guard value.count == 32 else { return false }
        return value.unicodeScalars.allSatisfy { $0.value >= 97 && $0.value <= 112 }
    }
}
