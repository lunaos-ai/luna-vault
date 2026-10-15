import Foundation

extension VaultService {
    func denyAgentIfBlocked(name: String) throws {
        guard detector.detect().requiresMCPAllowlist else { return }
        guard let secret = try list().first(where: { $0.name == name }) else { return }
        guard secret.mcpAllowed else {
            throw SecretError.mcpDenied(name: name)
        }
    }
}
