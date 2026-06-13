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
        let detector = MCPClientDetector()
        let service = VaultService(
            store: store,
            audit: audit,
            detector: detector,
            biometric: NoopBiometricGate()
        )
        let context = MCPContext(service: service, detector: detector)
        let server = MCPServer(context: context)
        await server.run()
    }
}
