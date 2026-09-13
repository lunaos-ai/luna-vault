import Foundation
import VaultCore

enum MCPHTTPTransport {
    static func run(server: MCPServer, port: UInt16) async {
        let prefs = KeychainPrefs()
        let http = LoopbackHTTPServer(port: port)
        do {
            try http.runBlocking { request in
                await MCPSandboxHTTPRouter.route(request, prefs: prefs) { body in
                    await server.handleBody(body)
                }
            }
        } catch {
            FileHandle.standardError.write(Data("vibevault-mcp: \(error)\n".utf8))
            exit(1)
        }
    }
}
