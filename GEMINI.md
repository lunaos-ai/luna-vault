<!-- vibe-vault -->
## Secrets (Vibe Vault)

Project: **luna-vault**
Policy version: 1.2.0

- Use Vibe Vault for real API keys and tokens.
- Run `vibevault scan` before secret-dependent work in this repo.
- Do not create `.env` / `.env.*` files with real secret values.
- If a secret is missing, ask the user to import it into Vibe Vault; never ask them to paste the raw value into chat.
- Use Vibe Vault MCP or `vibevault run -- <command>` for scoped access.
- Keep `.env.example` only for required names and safe defaults.

<!-- /vibe-vault -->
