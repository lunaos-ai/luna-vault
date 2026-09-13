import Foundation

extension MCPClientInstaller {
    public static func httpServerConfig(url: String, bearerToken: String, client: MCPClientID) -> [String: Any] {
        [
            "type": "http",
            "url": url,
            "headers": [
                "Authorization": "Bearer \(bearerToken)"
            ],
            "env": agentEnv(for: client)
        ]
    }

    public static func installHTTP(
        client: MCPClientID,
        url: String,
        bearerToken: String
    ) throws {
        try installHTTP(at: client.configURL, client: client, url: url, bearerToken: bearerToken)
    }

    public static func installHTTP(
        at configURL: URL,
        client: MCPClientID,
        url: String,
        bearerToken: String
    ) throws {
        var root = loadRoot(from: configURL)
        var servers = serversDict(in: root) ?? [:]
        servers[serverKey] = httpServerConfig(url: url, bearerToken: bearerToken, client: client)
        setServersDict(in: &root, value: servers)
        try saveRoot(root, to: configURL)
    }
}
