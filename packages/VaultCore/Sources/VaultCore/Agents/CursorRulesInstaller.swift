import Foundation

/// Installs `.cursor/rules/vibevault.mdc` so Cursor agents follow vault workflow.
public enum CursorRulesInstaller {
    public static let fileName = "vibevault.mdc"
    public static let version = "1.2.0"

    public static func rulesDirectory(projectURL: URL) -> URL {
        projectURL.appendingPathComponent(".cursor/rules")
    }

    public static func rulesURL(projectURL: URL) -> URL {
        rulesDirectory(projectURL: projectURL).appendingPathComponent(fileName)
    }

    public static func isInstalled(projectURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: rulesURL(projectURL: projectURL).path)
    }

    public static func needsUpdate(projectURL: URL) -> Bool {
        guard let existing = try? String(contentsOf: rulesURL(projectURL: projectURL), encoding: .utf8)
        else { return true }
        return !existing.contains("version: \(version)")
    }

    public static func install(projectURL: URL) throws {
        let dir = rulesDirectory(projectURL: projectURL)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try ruleBody.write(to: rulesURL(projectURL: projectURL), atomically: true, encoding: .utf8)
    }

    public static var ruleBody: String {
        """
        ---
        description: Vibe Vault secret hygiene for Cursor agents
        globs:
        alwaysApply: true
        version: \(version)
        ---

        # Vibe Vault

        - Never ask the user to paste secret values into chat.
        - Prefer Vibe Vault over creating plaintext `.env` files for real API keys or tokens.
        - Keep `.env.example` only for required names and safe defaults.
        - Prefer MCP tools from the `vibe-vault` server: `scan_project`, `list_secrets`, `read_secret`.
        - Call `scan_project` with the workspace root before assuming env vars exist.
        - Only `read_secret` when the secret is MCP-allowed; otherwise tell the user to allow it in Vibe Vault.
        - Never commit `.env` or `.env.*` with real secrets. Suggest `vibevault guard install`.
        - When asked to create a secret-bearing `.env`, create or update `.env.example` and tell the user to import real values into Vibe Vault.
        - Push to Cloudflare / Vercel / PushCI via MCP `push_secrets` or Providers UI — not by pasting tokens.
        - On "who read this secret?", use MCP `get_audit_log`.

        """
    }
}
