import Foundation
import VaultCore

enum MCPPrompts {
    static let definitions: [MCPPromptDef] = [
        MCPPromptDef(
            name: "setup-project-secrets",
            description: "Scan a project and guide secret setup via Vibe Vault",
            arguments: [["name": "path", "description": "Project root path", "required": true]]
        ),
        MCPPromptDef(
            name: "who-read-secret",
            description: "Query audit log for who accessed a secret",
            arguments: [["name": "secret", "description": "Secret name", "required": true]]
        )
    ]

    static func list() -> [[String: Any]] {
        definitions.map { p in
            ["name": p.name, "description": p.description, "arguments": p.arguments]
        }
    }

    static func get(name: String, args: [String: String]) -> [String: Any]? {
        switch name {
        case "setup-project-secrets":
            let path = args["path"] ?? "$PROJECT_ROOT"
            return promptResult(messages: [
                ["role": "user", "content": [
                    "type": "text",
                    "text": """
                    Set up secrets for this project using Vibe Vault MCP tools.

                    1. Read resource vibevault://project-setup?path=\(path) or run scan_project
                    2. List missing secrets; tell me to import via Vibe Vault app if values are missing
                    3. Do not ask me to paste secret values in chat
                    4. Suggest Providers push (Cloudflare/Vercel/PushCI) after import when relevant
                    """
                ]]
            ])
        case "who-read-secret":
            let secret = args["secret"] ?? "SECRET_NAME"
            return promptResult(messages: [
                ["role": "user", "content": [
                    "type": "text",
                    "text": """
                    Use get_audit_log with secret=\(secret) and summarize which agents read it, when, and from which project path.
                    """
                ]]
            ])
        default:
            return nil
        }
    }

    private static func promptResult(messages: [[String: Any]]) -> [String: Any] {
        ["description": "Vibe Vault prompt", "messages": messages]
    }
}

struct MCPPromptDef {
    let name: String
    let description: String
    let arguments: [[String: Any]]
}
