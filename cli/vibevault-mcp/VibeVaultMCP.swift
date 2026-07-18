import Foundation
import VaultCore

@main
struct VibeVaultMCP {
    static func main() async {
        let detector = MCPAgentDetector()
        // Same store as App/CLI: file vault (+ lazy Keychain migrate on read).
        // KeychainStore alone misses secrets that only live in EncryptedVaultStore.
        let store = MigratingVaultStore()
        guard let audit = try? AuditDB() else {
            FileHandle.standardError.write(Data("vibevault-mcp: failed to open audit DB\n".utf8))
            exit(1)
        }
        let service = VaultService(
            store: store,
            audit: audit,
            detector: detector,
            biometric: NoopBiometricGate()
        )
        let prefs = KeychainPrefs()
        let registry = ProviderRegistry.defaultsWithToken(from: prefs)
        let context = MCPContext(
            service: service, clientName: "unknown", prefs: prefs, registry: registry
        )
        let server = MCPServer(context: context, agentDetector: detector)
        await server.run()
    }
}
