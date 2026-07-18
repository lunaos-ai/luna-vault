<!-- vibe-vault -->
## Secrets (Vibe Vault)

Project: **luna-vault**

- Use the `vibe-vault` MCP server. Never ask the user to paste secret values in chat.
- Required: _Run `vibevault scan` or MCP `scan_project` to detect required secrets._
- Missing from vault: None
- Do not commit `.env` / `.env.*` (except `.env.example`). Prefer `vibevault cursor prepare`.
- Allow AI access per secret in Vibe Vault before calling `read_secret`.
