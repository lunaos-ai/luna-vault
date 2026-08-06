# Luna Vault Agent Coordination — Reference

## Shared directories

```text
~/.luna/agents/registry/          # one JSON file per active session
~/.luna/agents/locks/             # one JSON file per repo/worktree lock
~/.luna/agents/inbox/<session>/   # messages addressed to a session
```

## Session registration

`~/.luna/agents/registry/<session-id>.json`:

```json
{
  "sessionId": "...",
  "agent": "claude-code",
  "pid": 12345,
  "repo": "/Users/.../project-x",
  "worktree": "/Users/.../project-x",
  "capabilities": ["edit", "scan", "test"],
  "startTime": "2026-08-06T14:00:00Z"
}
```

A session should update its registry file on heartbeat. Peers consider a file stale if it is older than 10 minutes and ignore it.

## Locks

Lock file name: SHA-256 of the absolute repo path.

`~/.luna/agents/locks/<repo-sha>.json`:

```json
{
  "sessionId": "...",
  "repo": "/Users/.../project-x",
  "since": "2026-08-06T14:00:00Z"
}
```

- Acquire only if the file does not exist or is stale (older than 10 minutes).
- Always release with `unlock <repo>` when done.
- Before editing any repo or dependency, the agent must acquire its lock.

## Messages

A message is a JSON file in the recipient's inbox directory.

### Request

```json
{
  "type": "request",
  "id": "...",
  "from": "<sender-session-id>",
  "task": "Update project Y to expose a new helper and add a test.",
  "repo": "/Users/.../project-y",
  "constraints": { "maxFiles": 3, "noBreakingChanges": true },
  "timestamp": "2026-08-06T14:00:00Z"
}
```

### Response

```json
{
  "type": "response",
  "id": "...",
  "inReplyTo": "<request-id>",
  "from": "<responder-session-id>",
  "status": "done",
  "summary": "Added helper and test in project-y/src/helper.ts.",
  "changedFiles": ["src/helper.ts", "tests/helper.test.ts"],
  "timestamp": "2026-08-06T14:05:00Z"
}
```

Allowed statuses: `done`, `blocked`, `error`.

## Notes

A human-readable shared log per repo lives at:

```text
~/.luna/agents/notes/<repo-sha>.md
```

Format is markdown so you can read it directly:

```markdown
- **2026-08-06T14:00:00Z** · `session-a`: Refactoring helper.ts; do not touch exports.
- **2026-08-06T14:05:00Z** · `session-b`: Waiting on project-y API change.
```

Agents should append short, actionable notes before starting risky or cross-repo work.

## Shared SQLite database (optional upgrade)

If file I/O becomes a bottleneck, replace the JSON registry/locks/inbox with a single database:

```text
~/.luna/agents/coordination.db
```

Suggested schema:

```sql
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY,
    agent TEXT,
    pid INTEGER,
    repo TEXT,
    worktree TEXT,
    capabilities TEXT, -- JSON array
    start_time TEXT,
    heartbeat_time TEXT
);

CREATE TABLE locks (
    repo_hash TEXT PRIMARY KEY,
    session_id TEXT,
    repo TEXT,
    since TEXT
);

CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    recipient TEXT,
    sender TEXT,
    type TEXT,        -- request | response
    content TEXT,     -- JSON blob
    timestamp TEXT
);

CREATE INDEX idx_messages_recipient ON messages(recipient);
CREATE INDEX idx_sessions_repo ON sessions(repo);
```

Use the existing file-based implementation as the default; switch to SQLite when you need to coordinate more than a handful of sessions or want atomic lock acquisition.

## CLI helper

`scripts/luna-vault-agent.py` implements the protocol.

```bash
# Register this session
python3 .devin/skills/luna-agent-coordination/scripts/luna-vault-agent.py register \
  --repo /Users/.../project-x \
  --worktree /Users/.../project-x \
  --capabilities edit scan test

# List active peers
python3 .../luna-vault-agent.py peers --repo /Users/.../project-y

# Lock a repo before editing
python3 .../luna-vault-agent.py lock /Users/.../project-x

# Ask another session to do work
python3 .../luna-vault-agent.py ask \
  --to <peer-session-id> \
  --repo /Users/.../project-y \
  --task "Update project Y to expose a new helper and add a test."

# Poll for a response (checks this session's inbox)
python3 .../luna-vault-agent.py poll --from <peer-session-id> --timeout 300

# Release lock
python3 .../luna-vault-agent.py unlock /Users/.../project-x

# Leave/read shared notes
python3 .../luna-vault-agent.py note --repo /Users/.../project-x \
  --text "Refactoring helper.ts; do not touch exports."
python3 .../luna-vault-agent.py notes --repo /Users/.../project-x
```

## Agent workflow

1. Register.
2. Before any edit, `lock` the target repo/worktree.
3. If a dependency (project Y) needs changes, find a peer active on that repo.
4. Send a request and poll for response.
5. If `done`, review the changed files in project Y before relying on them.
6. Release your lock.
