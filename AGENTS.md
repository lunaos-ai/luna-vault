<!-- vibe-vault -->
## Secrets (Vibe Vault)

Project: **luna-vault**
Policy version: 1.2.0

- Use the `vibe-vault` MCP server. Never ask the user to paste secret values in chat.
- Required: _Run `vibevault scan` or MCP `scan_project` to detect required secrets._
- Missing from vault: None
- Do not commit `.env` / `.env.*` (except `.env.example`). Prefer `vibevault cursor prepare`.
- Allow AI access per secret in Vibe Vault before calling `read_secret`.
- For real secrets, prefer Vibe Vault over creating plaintext `.env` files. If a secret is missing, ask the user to import it into Vibe Vault instead of pasting it in chat.

<!-- /vibe-vault -->
