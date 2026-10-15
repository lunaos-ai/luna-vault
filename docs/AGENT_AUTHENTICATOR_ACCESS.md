# Authenticator access for agents

Save the authenticator in VibeVault, open it under **Authenticator**, then enable
**Allow AI agents**. New and previously saved accounts default to private. This
permission lets connected agents complete TOTP challenges without asking for each
code. Turn it off to revoke future requests.

The MCP server exposes:

| Tool | Result |
| --- | --- |
| `list_authenticators` | Approved account IDs, issuer/account labels, digits, and period |
| `get_authenticator_code` with `id` | Current code, `valid_for_seconds`, and period |
| `revoke_authenticator_access` with `id` | Disables agent access for that account |

Only the app can enable this permission. Every successful code read is audited
as `authenticator:<UUID>` before returning. The audit includes the detected agent
and session, never the code or setup key. If audit storage fails, no code is
returned. `get_audit_log` can inspect records for currently approved accounts.

The CLI also uses this permission:

```sh
vibevault otp list --json
vibevault otp code <account-uuid>
```

CLI code generation additionally uses the existing biometric/shared unlock
session. MCP follows its existing authenticated transport and allowlist model.
The CLI enforces account permission even if it cannot identify the calling
process. Detected agents cannot read recovery codes, export authenticator seeds,
replace setup keys, or import permissions. Replacing a seed in the app revokes
agent access until the user enables it again.

Use returned codes only for the action the user authorized. Do not copy them into
chat, logs, files, or durable command arguments. They do not grant permission for
unrelated actions or satisfy a separate human approval requirement.

## Import from PushCI

The browser extension supports `https://app.pushci.dev` and
`https://staging.pushci.dev`, in addition to the existing AMLIQ integration.
Click **Save to VibeVault** during PushCI enrollment, review/save in the app, and
enter the generated code back in PushCI. Enable agent access separately after
saving. The browser cannot grant it. No new enrollment is created by the import
action; it transfers the QR setup already displayed by PushCI.

The native host encrypts the pending import locally. Its success response means
queued for review, not saved or MFA-verified. The browser bridge validates origin,
top-level window, message source, payload shape and size, and request identity.
Raw native errors are never sent back to the website.

- [x] Add private-by-default, backward-compatible account permission.
- [x] Add app control, CLI enforcement, MCP tools, and audit visibility.
- [x] Extend the browser import bridge to PushCI.
- [x] Add synthetic permission, revocation, audit, migration, and bridge tests.
- [ ] Release the signed app/MCP and browser extension; verify a live enrollment.
