# Vibe Vault Threat Model

Vibe Vault protects local AI-coding credentials by reducing copy-paste, keeping a local source of truth, and auditing agent access. It is not a replacement for device security, provider-side IAM, or incident response.

## Protected Assets

- API keys and tokens stored in the local vault.
- Credential metadata such as names, provider labels, and project scope.
- Audit history describing which agent or process requested a credential.
- Provider-sync configuration for services such as Cloudflare, Vercel, and PushCI.
- Team license state used to unlock paid seats.

## Architecture Summary

- Credentials are stored locally. The vault ciphertext lives on disk and the master key is held in macOS Keychain.
- Solo use does not require a Vibe Vault cloud account.
- Secret reads can require local approval, such as Touch ID, before a value is copied, injected, or served through MCP.
- Audit events record metadata: credential name, action, project context, agent or process, result, and timestamp.
- Provider sync is user initiated. Vibe Vault pushes selected credentials to a provider only when the user runs an explicit sync.
- Team license verification is local. The app verifies a signed license with an embedded public key.

## Assumed Attackers

- A coding agent that asks for a credential outside the intended workflow.
- A developer accidentally committing or pasting a credential.
- A project with scattered `.env` files or stale provider tokens.
- A local process that inherits environment variables unexpectedly.
- A former teammate with old credentials that should be rotated at the provider.

## Non-Goals And Limits

- Vibe Vault cannot protect a secret after an approved process receives it.
- Vibe Vault cannot prevent a compromised agent from printing, uploading, or misusing a credential that the user approved for that session.
- Vibe Vault cannot defend against full local device compromise, malware with the user's privileges, or malicious software with Keychain/Accessibility access.
- Vibe Vault cannot revoke provider credentials by itself; rotate or revoke keys at the provider.
- Vibe Vault audit logs are local evidence, not tamper-proof centralized compliance logs.
- Vibe Vault does not currently provide SSO, SCIM, SIEM export, centralized admin policy, or remote device posture enforcement.

## Secret Lifecycle

1. A user adds or imports a credential.
2. Vibe Vault stores the credential in local encrypted storage protected by macOS Keychain.
3. A command, agent, or provider-sync action requests the credential.
4. Vibe Vault applies local workflow checks and optional approval.
5. The approved value is copied, injected into a process, served through MCP, or pushed to a provider.
6. An audit event records metadata about the access.
7. Rotation and revocation happen at the source provider, then the local vault is updated.

## Provider-Sync Lifecycle

1. The user selects a provider sync command.
2. Vibe Vault reads the selected local credentials.
3. Vibe Vault calls the configured provider API directly from the user's machine.
4. The provider stores the secret in its own environment system.
5. Vibe Vault records the sync action as an audit event.

Provider sync does not turn Vibe Vault into a cloud vault. The Vibe Vault service does not receive the synced secret.

## Audit Guarantees

Audit rows are designed to answer:

- Which credential was requested.
- Which agent or process requested it.
- Which project context was involved.
- Whether the access succeeded or failed.
- When the access happened.

Audit rows should not include raw secret values. Commands and third-party tools can still leak values if a secret is printed, logged, or passed unsafely after approval.

## License Model

Team licenses are signed offline licenses. Opening the app does not require contacting a Vibe Vault license server. A subscription covers updates, support, and license use; renewal issues a fresh signed license.

## Roadmap Security Work

- Exportable audit logs.
- Repository-level allow and deny policies.
- Blocked-access audit events.
- Time-limited approvals.
- Team deployment templates.
- MDM-oriented configuration.
- SIEM export and centralized policy for larger organizations.
