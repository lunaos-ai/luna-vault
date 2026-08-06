#!/usr/bin/env python3
"""Lightweight agent coordination for Luna Vault / Vibe Vault projects.

Stores session registry, repo locks, and cross-session messages under ~/.luna/agents.
"""

import argparse
import datetime
import hashlib
import json
import os
import sys
import time
import uuid
from pathlib import Path

BASE = Path.home() / ".luna" / "agents"
REG_DIR = BASE / "registry"
LOCK_DIR = BASE / "locks"
INBOX_DIR = BASE / "inbox"
NOTES_DIR = BASE / "notes"
STALE_SECONDS = 600


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def ensure_dirs() -> None:
    REG_DIR.mkdir(parents=True, exist_ok=True)
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    NOTES_DIR.mkdir(parents=True, exist_ok=True)


def repo_note_path(repo: str) -> Path:
    key = hashlib.sha256(os.path.abspath(repo).encode()).hexdigest()
    return NOTES_DIR / f"{key}.md"


def session_id() -> str:
    return os.environ.get("LUNA_SESSION") or str(uuid.uuid4())


def agent_name() -> str:
    return os.environ.get("LUNA_AGENT") or "unknown"


def repo_lock_path(repo: str) -> Path:
    key = hashlib.sha256(os.path.abspath(repo).encode()).hexdigest()
    return LOCK_DIR / f"{key}.json"


def is_stale(path: Path) -> bool:
    if not path.exists():
        return True
    mtime = path.stat().st_mtime
    return time.time() - mtime > STALE_SECONDS


def cmd_register(args: argparse.Namespace) -> int:
    ensure_dirs()
    sid = session_id()
    payload = {
        "sessionId": sid,
        "agent": agent_name(),
        "pid": os.getpid(),
        "repo": args.repo,
        "worktree": args.worktree or args.repo,
        "capabilities": args.capabilities or [],
        "startTime": now(),
    }
    (REG_DIR / f"{sid}.json").write_text(json.dumps(payload, indent=2))
    print(sid)
    return 0


def cmd_peers(args: argparse.Namespace) -> int:
    ensure_dirs()
    found = False
    for path in sorted(REG_DIR.glob("*.json")):
        if is_stale(path):
            continue
        data = json.loads(path.read_text())
        if args.repo and data.get("repo") != args.repo:
            continue
        print(f"{data['sessionId']}\t{data['agent']}\t{data.get('repo', '')}\t{','.join(data.get('capabilities', []))}")
        found = True
    if not found:
        print("(no active peers)")
    return 0


def cmd_lock(args: argparse.Namespace) -> int:
    ensure_dirs()
    repo = args.repo
    sid = session_id()
    lock_path = repo_lock_path(repo)
    if lock_path.exists() and not is_stale(lock_path):
        data = json.loads(lock_path.read_text())
        if data.get("sessionId") == sid:
            print(f"already locked by {sid}")
            return 0
        print(f"locked by {data.get('sessionId')} since {data.get('since')}", file=sys.stderr)
        return 1
    lock_path.write_text(json.dumps({
        "sessionId": sid,
        "repo": repo,
        "since": now()
    }, indent=2))
    print("locked")
    return 0


def cmd_unlock(args: argparse.Namespace) -> int:
    repo = args.repo
    sid = session_id()
    lock_path = repo_lock_path(repo)
    if not lock_path.exists():
        print("not locked")
        return 0
    data = json.loads(lock_path.read_text())
    if data.get("sessionId") != sid:
        print(f"locked by {data.get('sessionId')}; refusing unlock", file=sys.stderr)
        return 1
    lock_path.unlink()
    print("unlocked")
    return 0


def cmd_ask(args: argparse.Namespace) -> int:
    ensure_dirs()
    sid = session_id()
    msg_id = str(uuid.uuid4())
    payload = {
        "type": "request",
        "id": msg_id,
        "from": sid,
        "task": args.task,
        "repo": args.repo,
        "constraints": args.constraints or {},
        "timestamp": now(),
    }
    target_dir = INBOX_DIR / args.to
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"{msg_id}.json"
    target.write_text(json.dumps(payload, indent=2))
    print(target)
    return 0


def cmd_poll(args: argparse.Namespace) -> int:
    ensure_dirs()
    sid = session_id()
    inbox = INBOX_DIR / sid
    if not inbox.exists():
        print("(no inbox)")
        return 0
    deadline = time.time() + args.timeout
    while True:
        for path in sorted(inbox.glob("*.json")):
            try:
                data = json.loads(path.read_text())
            except json.JSONDecodeError:
                continue
            if data.get("type") != "response":
                continue
            if args.from_session and data.get("from") != args.from_session:
                continue
            print(json.dumps(data, indent=2))
            path.unlink(missing_ok=True)
            return 0
        if time.time() >= deadline:
            print("(timeout)")
            return 0
        time.sleep(2)


def cmd_note(args: argparse.Namespace) -> int:
    ensure_dirs()
    note_path = repo_note_path(args.repo)
    sid = session_id()
    line = f"- **{now()}** · `{sid}`: {args.text}"
    with note_path.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(note_path)
    return 0


def cmd_notes(args: argparse.Namespace) -> int:
    ensure_dirs()
    note_path = repo_note_path(args.repo)
    if not note_path.exists():
        print("(no notes)")
        return 0
    print(note_path.read_text(), end="")
    return 0


def cmd_cleanup(args: argparse.Namespace) -> int:
    ensure_dirs()
    removed = 0
    for path in REG_DIR.glob("*.json"):
        if is_stale(path):
            path.unlink()
            removed += 1
    for path in LOCK_DIR.glob("*.json"):
        if is_stale(path):
            path.unlink()
            removed += 1
    print(f"removed {removed} stale entries")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Luna agent coordination")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_reg = sub.add_parser("register", help="register this session")
    p_reg.add_argument("--repo", required=True)
    p_reg.add_argument("--worktree")
    p_reg.add_argument("--capabilities", nargs="+", default=[])

    p_peers = sub.add_parser("peers", help="list active peer sessions")
    p_peers.add_argument("--repo")

    p_lock = sub.add_parser("lock", help="acquire repo lock")
    p_lock.add_argument("repo")

    p_unlock = sub.add_parser("unlock", help="release repo lock")
    p_unlock.add_argument("repo")

    p_ask = sub.add_parser("ask", help="send a request to another session")
    p_ask.add_argument("--to", required=True)
    p_ask.add_argument("--repo", required=True)
    p_ask.add_argument("--task", required=True)
    p_ask.add_argument("--constraints", type=json.loads, default={})

    p_poll = sub.add_parser("poll", help="poll inbox for a response")
    p_poll.add_argument("--from", dest="from_session")
    p_poll.add_argument("--timeout", type=int, default=0)

    p_note = sub.add_parser("note", help="append a note to the shared repo log")
    p_note.add_argument("--repo", required=True)
    p_note.add_argument("--text", required=True)

    p_notes = sub.add_parser("notes", help="read the shared repo note log")
    p_notes.add_argument("--repo", required=True)

    sub.add_parser("cleanup", help="remove stale registry and lock files")

    args = parser.parse_args(argv)
    ensure_dirs()

    handlers = {
        "register": cmd_register,
        "peers": cmd_peers,
        "lock": cmd_lock,
        "unlock": cmd_unlock,
        "ask": cmd_ask,
        "poll": cmd_poll,
        "note": cmd_note,
        "notes": cmd_notes,
        "cleanup": cmd_cleanup,
    }
    return handlers[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
