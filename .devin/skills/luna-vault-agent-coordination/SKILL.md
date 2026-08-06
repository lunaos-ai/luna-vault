---
name: luna-vault-agent-coordination
description: Coordinate work across multiple AI-agent sessions for Luna Vault / Vibe Vault projects so they do not overwrite each other on the same repo or its dependency worktrees. Use when the user is working on a Luna Vault project that depends on another local project, wants another agent to update a dependency, or needs to avoid conflicting edits across Claude/Cursor/Devin sessions.
version: 1.0.0
---

# Luna Vault Agent Coordination

This skill lets one AI-agent session discover and request work from another session that is active on a different repo or worktree. It is a lightweight file-based protocol, not magic: both sessions must load this skill and read the shared registry.

## What is possible

- Discover which agents are active on which repo/worktree.
- Ask an agent on project Y to make a change and return the result.
- Claim a short-lived write lock on a repo/worktree so two agents do not overwrite each other.
- It is **not** possible to talk to arbitrary other sessions unless they also use this protocol.

## Shared locations

All agents read/write under:

```text
~/.luna/agents/registry/    # active session registrations
~/.luna/agents/inbox/       # request/response messages between sessions
~/.luna/agents/notes/       # shared markdown note log per repo
```

You can also back this protocol with a shared SQLite database (`~/.luna/agents/coordination.db`) or macOS Distributed Notifications if you need real-time updates, but the file-based registry works without any dependencies.

## Quick start

1. When the Vibe Vault MCP server is installed and started, the session is registered automatically under `~/.luna/agents/registry/`.
2. Before editing a repo or its dependency, run `vibevault agent lock <repo-path>`.
3. If you need another project changed, find an active agent with `vibevault agent peers --repo <other-repo>`.
4. Send a request: `vibevault agent ask --to <session-id> --repo <repo> --task "update project Y to ..."`.
5. Wait for the response file to appear, then apply/merge it.
6. Release the lock with `vibevault agent unlock <repo-path>` when done.

If you are not running through the MCP server (for example, a standalone CLI workflow), register manually with `vibevault agent register --nick <nickname>`. The nickname makes it easy to tell multiple sessions on the same repo apart.

If Vibe Vault is not available, the same protocol can be driven by `python3 .devin/skills/luna-vault-agent-coordination/scripts/luna-vault-agent.py`.

## Workflows

### Discover peers

```bash
vibevault agent peers --repo /Users/shaharsolomon/projects/lunaos/luna-vault
```

If a matching session is running, note its `sessionId` and capabilities.

### Request a change in another project

1. Run `vibevault agent ask --to <peer-session-id> --repo <repo> --task "..."`.
2. Poll the inbox for a response: `vibevault agent poll --from <peer-session-id> --timeout 300`.
3. The response contains either `status: done` with a diff/url or `status: blocked` with a reason.
4. If done, review the change in the other project before returning to your main task.

### Avoid overwriting another agent

```bash
vibevault agent lock /path/to/project-X
# do your edits
vibevault agent unlock /path/to/project-X
```

If the lock is already held, wait or message the holding session.

### Leave a note for other agents

```bash
vibevault agent note --repo /path/to/project-X --text "Refactoring helper.ts; do not touch exports."
vibevault agent notes --repo /path/to/project-X
```

## Reference

See [REFERENCE.md](REFERENCE.md) for the registry schema, message format, and lock-file rules.
