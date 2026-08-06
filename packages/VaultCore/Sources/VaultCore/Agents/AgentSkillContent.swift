import Foundation

/// Embedded canonical skill; keep in sync with `skills/vibevault/SKILL.md`.
public enum AgentSkillContent {
    public static let version = "1.2.0"

    public static let markdown = """
    ---
    name: vibevault
    description: >-
      Use Vibe Vault for local macOS secrets in AI coding workflows. Use when
      scanning projects for required env vars, importing dotenv, pushing to
      Cloudflare/Vercel/PushCI, reading secrets via MCP, or auditing agent access.
      Never ask the user to paste secrets into chat.
    version: \(version)
    ---

    # Vibe Vault

    Local-first secret manager on macOS Keychain. Every read is audited per agent.

    ## When to use

    - Starting work on a repo with `wrangler.toml`, `vercel.json`, or `.env*`
    - User mentions missing API keys, Cloudflare tokens, or `.env` files
    - Deploying Workers / Vercel / PushCI and secrets need syncing
    - User asks who read a secret or wants agent audit

    ## Rules

    1. **Never ask for raw secret values in chat.** Use MCP `read_secret` only when MCP-allowed.
    2. **Scan first.** Call MCP `scan_project` with the workspace root.
    3. **No `.env` in git.** Suggest import via Vibe Vault; use `vibevault guard install`.
    4. **Push.** MCP `push_secrets` or Providers UI (Cloudflare, Vercel, PushCI).
    5. **Audit.** Use `get_audit_log` when asked which agent read a key.
    6. **Stay local.** CLI reads require the same Mac, user, and macOS Keychain
       context. Request approved host-level execution when a sandbox blocks access.

    ## MCP tools

    | Tool | Use |
    |------|-----|
    | `scan_project` | Project root; reports git leaks too |
    | `list_secrets` | MCP-allowed names only |
    | `read_secret` | Value if MCP-allowed |
    | `set_mcp_allowed` | Revoke only (`allowed: false`). Enable AI access in the app. |
    | `reconcile_provider` | Compare vault ↔ Cloudflare/Vercel/PushCI |
    | `push_secrets` | Push MCP-allowed secrets to a provider (`dry_run` supported) |
    | `pull_secrets` | Pull secret names/values from a provider; optionally import into vault |
    | `get_audit_log` | Optional `agent`, `secret`, `limit` |
    | `suggest_secrets_for_task` | Names only for a task + project path |

    ## Resources

    - `vibevault://workflow` — setup steps
    - `vibevault://skill` — this skill
    - `vibevault://project-setup` — optional `?path=` for live scan summary

    ## CLI

    ```bash
    vibevault scan
    vibevault run -- npm run dev
    vibevault push --to cloudflare|vercel|pushci --scope …
    vibevault mcp install --client cursor
    vibevault skill install
    vibevault cursor prepare --path .
    ```

    Prefer scoped injection over reading a raw value:

    ```bash
    vibevault run --only GHCR_TOKEN -- your-command
    ```

    If a tool expects another variable name, map it only in the child process:

    ```bash
    vibevault run --only GHCR_TOKEN -- \\
      sh -c 'GH_TOKEN="$GHCR_TOKEN" exec gh auth status'
    ```

    Only when the user explicitly needs the value, copy it without printing it:

    ```bash
    vibevault run --only GHCR_TOKEN -- \\
      sh -c 'printf %s "$GHCR_TOKEN" | pbcopy'
    ```

    If `vibevault list` works in Terminal but an agent reports `bad master key in
    Keychain`, do not reset or replace the key. Retry with user-approved host-level
    local execution. The sandbox may lack the required Keychain security context.
    """
}
