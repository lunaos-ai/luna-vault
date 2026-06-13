import Foundation

enum MCPInstallerError: Error, CustomStringConvertible {
    case clientNotFound(String)
    case ioFailed(String)
    case invalidConfig(String)

    var description: String {
        switch self {
        case .clientNotFound(let m): return "Client not detected: \(m)"
        case .ioFailed(let m): return "I/O failed: \(m)"
        case .invalidConfig(let m): return "Existing config not in expected shape: \(m)"
        }
    }
}

enum MCPClientInstaller {
    static let serverKey = "vibe-vault"

    static func status(of kind: MCPClientKind) -> MCPClientStatus {
        status(at: kind.configURL, kind: kind)
    }

    /// URL-injectable core so the read path is testable without touching the
    /// user's real `~/.claude/mcp.json` and friends.
    static func status(at url: URL, kind: MCPClientKind) -> MCPClientStatus {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: url.path)
        let parentExists = fm.fileExists(atPath: url.deletingLastPathComponent().path)
        let installed: Bool = {
            guard exists,
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return false }
            return serversDict(in: json)?[serverKey] != nil
        }()
        return MCPClientStatus(kind: kind, configExists: exists, installed: installed, parentDirExists: parentExists)
    }

    static func install(kind: MCPClientKind, binaryPath: String) throws {
        try install(at: kind.configURL, binaryPath: binaryPath)
    }

    static func install(at url: URL, binaryPath: String) throws {
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = json
        }
        var servers = serversDict(in: root) ?? [:]
        servers[serverKey] = [
            "command": binaryPath,
            "args": [] as [String],
            "env": [:] as [String: String]
        ]
        setServersDict(in: &root, value: servers)
        do {
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            throw MCPInstallerError.ioFailed("\(error)")
        }
    }

    static func uninstall(kind: MCPClientKind) throws {
        try uninstall(at: kind.configURL)
    }

    static func uninstall(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }
        guard var servers = serversDict(in: root) else { return }
        servers.removeValue(forKey: serverKey)
        setServersDict(in: &root, value: servers)
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
    }

    private static func serversDict(in root: [String: Any]) -> [String: Any]? {
        if let s = root["mcpServers"] as? [String: Any] { return s }
        if let s = root["servers"] as? [String: Any] { return s }
        return nil
    }

    private static func setServersDict(in root: inout [String: Any], value: [String: Any]) {
        // Claude Code uses "mcpServers"; some clients use "servers". Default to "mcpServers" if creating.
        if root["servers"] != nil { root["servers"] = value; return }
        root["mcpServers"] = value
    }
}
