import Foundation

/// Scans MCP config for servers that are not vibe-vault (shadow / unmanaged).
public struct ShadowMCPServer: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let command: String?
    public let isVibeVault: Bool
    public let isShadow: Bool

    public init(name: String, command: String?, isVibeVault: Bool, isShadow: Bool) {
        self.name = name
        self.command = command
        self.isVibeVault = isVibeVault
        self.isShadow = isShadow
    }
}

public struct ShadowMCPReport: Equatable, Sendable {
    public let client: MCPClientID
    public let configExists: Bool
    public let vibeVaultInstalled: Bool
    public let servers: [ShadowMCPServer]

    public var shadowCount: Int { servers.filter(\.isShadow).count }

    public init(
        client: MCPClientID,
        configExists: Bool,
        vibeVaultInstalled: Bool,
        servers: [ShadowMCPServer]
    ) {
        self.client = client
        self.configExists = configExists
        self.vibeVaultInstalled = vibeVaultInstalled
        self.servers = servers
    }
}

public enum ShadowMCPScanner {
    public static let vibeVaultKeys: Set<String> = ["vibe-vault", "vibevault", "vibe_vault"]

    public static func scan(client: MCPClientID = .cursor) -> ShadowMCPReport {
        let url = client.configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ShadowMCPReport(
                client: client, configExists: false, vibeVaultInstalled: false, servers: []
            )
        }
        let dict = serversDict(in: json) ?? [:]
        var servers: [ShadowMCPServer] = []
        var vibe = false
        for (name, value) in dict {
            let command = (value as? [String: Any])?["command"] as? String
            let isVV = vibeVaultKeys.contains(name.lowercased())
                || (command?.contains("vibevault-mcp") == true)
            if isVV { vibe = true }
            servers.append(ShadowMCPServer(
                name: name,
                command: command,
                isVibeVault: isVV,
                isShadow: !isVV
            ))
        }
        return ShadowMCPReport(
            client: client,
            configExists: true,
            vibeVaultInstalled: vibe,
            servers: servers.sorted { $0.name < $1.name }
        )
    }

    private static func serversDict(in root: [String: Any]) -> [String: Any]? {
        if let s = root["mcpServers"] as? [String: Any] { return s }
        if let s = root["servers"] as? [String: Any] { return s }
        return nil
    }
}
