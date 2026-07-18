import Foundation

public enum MCPInstallerError: Error, CustomStringConvertible, Sendable {
    case ioFailed(String)

    public var description: String {
        switch self {
        case .ioFailed(let m): return "I/O failed: \(m)"
        }
    }
}

public enum MCPClientInstaller {
    public static let serverKey = "vibe-vault"

    public static func status(of client: MCPClientID) -> MCPInstallStatus {
        let url = client.configURL
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: url.path)
        let parentExists = fm.fileExists(atPath: url.deletingLastPathComponent().path)
        let installed: Bool = {
            guard exists,
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = serversDict(in: json)
            else { return false }
            return servers[serverKey] != nil
        }()
        return MCPInstallStatus(
            client: client, configExists: exists, installed: installed, parentDirExists: parentExists
        )
    }

    public static func install(client: MCPClientID, binaryPath: String) throws {
        let url = client.configURL
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
            "env": agentEnv(for: client)
        ]
        setServersDict(in: &root, value: servers)
        do {
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            throw MCPInstallerError.ioFailed("\(error)")
        }
    }

    public static func uninstall(client: MCPClientID) throws {
        let url = client.configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var servers = serversDict(in: root)
        else { return }
        servers.removeValue(forKey: serverKey)
        setServersDict(in: &root, value: servers)
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
    }

    public static func agentEnv(for client: MCPClientID) -> [String: String] {
        ["LUNA_AGENT": client.lunaAgent, "LUNA_SESSION": SessionID.current()]
    }

    private static func serversDict(in root: [String: Any]) -> [String: Any]? {
        if let s = root["mcpServers"] as? [String: Any] { return s }
        if let s = root["servers"] as? [String: Any] { return s }
        return nil
    }

    private static func setServersDict(in root: inout [String: Any], value: [String: Any]) {
        if root["servers"] != nil { root["servers"] = value; return }
        root["mcpServers"] = value
    }
}
