import Foundation
import VaultCore

@main
struct VibeVaultMCP {
    static func main() async {
        // Headless: never prompt biometric. mcpAllowed flag + audit log are the guardrails.
        let store = KeychainStore()
        guard let audit = try? AuditDB() else {
            FileHandle.standardError.write(Data("vibevault-mcp: failed to open audit DB\n".utf8))
            exit(1)
        }
        let service = VaultService(
            store: store,
            audit: audit,
            detector: StubAgentDetector(DetectedAgent(name: "mcp:unknown", confidence: .medium, source: "mcp-client")),
            biometric: NoopBiometricGate()
        )
        let context = MCPContext(service: service, clientName: "mcp:unknown")
        let server = MCPServer(context: context)
        await server.run()
    }
}
