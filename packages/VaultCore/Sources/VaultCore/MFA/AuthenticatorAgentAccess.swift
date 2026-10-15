import Foundation

extension AuthenticatorService {
    /// Explicit MCP/CLI boundary, including clients that have not sent initialize.
    public func listForAgent() throws -> [AuthenticatorAccountMetadata] {
        try store.listAuthenticators().filter(\.mcpAllowed)
    }

    public func codeForAgent(id: UUID, at date: Date? = nil) async throws -> TOTPCode {
        try await generateCode(id: id, reason: "Agent authenticator request", at: date, agentAccess: true)
    }

    public func setMCPAllowed(id: UUID, allowed: Bool) async throws {
        if allowed { try requireHumanManagement() }
        if !detector.detect().requiresAuthenticatorAllowlist {
            try await biometric.authenticate(reason: "Change AI access to authenticator codes")
        }
        var account = try store.readAuthenticator(id: id)
        account.mcpAllowed = allowed
        account.updatedAt = Date()
        // No permission change if audit recording fails.
        try record(id, action: .write)
        // Reuse a revision kind understood by existing backup readers.
        try update(account, action: .metadataEdited)
    }

    func requireAgentAccess(id: UUID) throws {
        guard try store.listAuthenticators().contains(where: { $0.id == id && $0.mcpAllowed }) else {
            throw AuthenticatorError.agentAccessDenied
        }
    }

    func requireHumanManagement() throws {
        guard !detector.detect().requiresAuthenticatorAllowlist else { throw AuthenticatorError.humanRequired }
    }
}

extension DetectedAgent {
    var requiresAuthenticatorAllowlist: Bool {
        if source == "mcp-initialize" || source == "LUNA_AGENT" || source.hasPrefix("env:") { return true }
        return ["codex", "claude-code", "cursor", "vscode", "devin", "sourcegraph-cody",
                "aider", "node", "python", "bun", "deno"].contains(name)
    }
}
