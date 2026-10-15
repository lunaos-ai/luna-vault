import Foundation
import VaultCore

enum MCPAuthenticatorTools {
    static let definitions: [MCPToolDef] = [
        MCPToolDef(name: "list_authenticators",
            description: "List authenticator IDs and account names with Allow AI agents enabled. No setup keys or recovery codes.",
            inputSchema: ["type": "object", "properties": [:] as [String: Any]]),
        MCPToolDef(name: "get_authenticator_code",
            description: "Get a short-lived code for an approved authenticator. Use only for the user's authorized action; never log the code. Does not grant approval for other actions.",
            inputSchema: ["type": "object", "properties": ["id": ["type": "string",
                "description": "Exact authenticator UUID from list_authenticators."]], "required": ["id"]]),
        MCPToolDef(name: "revoke_authenticator_access",
            description: "Revoke agent access to an authenticator. Enabling access is only available in the VibeVault app.",
            inputSchema: ["type": "object", "properties": ["id": ["type": "string"]], "required": ["id"]])
    ]

    static func call(name: String, args: [String: Any], context: MCPContext) async throws -> [String: Any] {
        let service = try AuthenticatorService(vaultService: context.service)
        if name == "list_authenticators" {
            let accounts: [[String: Any]] = try service.listForAgent().map {
                ["id": $0.id.uuidString, "issuer": $0.issuer, "account": $0.accountName,
                 "digits": $0.digits, "period": $0.period]
            }
            return try result(["authenticators": accounts])
        }
        guard let raw = args["id"] as? String, let id = UUID(uuidString: raw) else {
            return MCPTools.errorResult("An authenticator UUID is required.")
        }
        if name == "get_authenticator_code" {
            let code = try await service.codeForAgent(id: id)
            return try result(["id": id.uuidString, "code": code.code,
                "valid_for_seconds": code.secondsRemaining, "period": code.period])
        }
        // Only expose revocation for accounts already visible to this client.
        guard try service.listForAgent().contains(where: { $0.id == id }) else {
            throw AuthenticatorError.agentAccessDenied
        }
        try await service.setMCPAllowed(id: id, allowed: false)
        return try result(["id": id.uuidString, "agent_access": false])
    }

    private static func result(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return MCPTools.textResult(String(decoding: data, as: UTF8.self))
    }
}
