# AI Agent CLI Access

Use Vibe Vault without placing secret values in chat, command arguments,
repository files, or agent logs. The CLI injects selected secrets into a child
process environment and audits each read.

The installed product carries this guidance in its own help output:

```bash
vibevault --help
vibevault help run
```

## Preferred: use a secret without revealing it

```bash
vibevault run --only GHCR_TOKEN -- your-command
```

Some tools expect a different environment-variable name. Map it only inside
the child process:

```bash
vibevault run --only GHCR_TOKEN -- \
  sh -c 'GH_TOKEN="$GHCR_TOKEN" exec gh auth status'
```

Do not interpolate the value into the command line. Keep the assignment inside
single quotes so the parent shell does not expand it.

## Retrieve a value only when necessary

Prefer copying to the macOS clipboard:

```bash
vibevault run --only GHCR_TOKEN -- \
  sh -c 'printf %s "$GHCR_TOKEN" | pbcopy'
```

Printing is supported but exposes the value to terminal scrollback and any
captured agent output:

```bash
vibevault run --only GHCR_TOKEN -- printenv GHCR_TOKEN
```

An agent must not print a secret unless the user explicitly requests the raw
value and understands the exposure. Never paste the result into chat.

## Local macOS access is required

Vibe Vault is local-first. Its encrypted vault is on this Mac and its master
key is in the user's macOS Keychain. CLI access therefore requires:

- execution on the same Mac and logged-in user account as Vibe Vault;
- access to the interactive macOS login and Keychain security context;
- user approval for Touch ID, device authentication, or Keychain prompts;
- a valid shared unlock session when unattended child commands are needed.

Remote containers, CI runners, filesystem sandboxes, and some AI-agent command
runtimes may see the binary and vault files but still lack Keychain access.
Agents must request approved host-level execution through their tool runtime;
they must not copy the vault, bypass Keychain controls, or weaken permissions.

Start or inspect a shared local session with:

```bash
vibevault session unlock --minutes 30
vibevault session status
```

## Diagnose agent-only failures

First compare the same metadata-only command in the user's Terminal and the
agent runtime:

```bash
vibevault list
```

If Terminal succeeds but the agent reports `bad master key in Keychain`, treat
that message as a possible Keychain access-context failure, not proof of key
corruption. The current CLI maps several Keychain lookup failures to that one
message.

The agent should:

1. Keep the vault and master key unchanged.
2. Request host-level local execution with user approval.
3. Retry `vibevault list`, then the narrowly scoped `vibevault run --only ...`.
4. If host-level execution is unavailable, ask the user to run the operation
   locally or configure the Vibe Vault MCP server.

Never delete, replace, rotate, or recreate `vault.master` as a troubleshooting
step. Losing that key can make the encrypted vault unrecoverable.

## Agent checklist

- Scan first with `vibevault scan` or MCP `scan_project`.
- Select the minimum secrets with one or more `--only` options.
- Prefer injection over retrieval.
- Never create plaintext `.env` files containing real values.
- Never emit secret values into chat, logs, test output, or PR descriptions.
- Use MCP access only for secrets the user has explicitly allowed for AI.
- Preserve auditability by keeping reads inside Vibe Vault.
