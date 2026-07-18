# Feature report: Cursor pack — proceed all

**Date:** 2026-07-15  
**Status:** Green (build + prepare applied on this repo)

## Shipped in this pass

| Feature | Detail |
|---------|--------|
| Audit agent chips | Cursor / Claude / Windsurf / VS Code quick filters |
| `suggest_secrets_for_task` | MCP tool — names only from scan + task text |
| `.gitignore` / `.cursorignore` | Via prepare + **Fix .gitignore** on git-leak banner |
| `AGENTS.md` section | Written by `CursorProjectPrep` |
| Prepare (expanded) | Rules + skill + MCP + guard + ignores + AGENTS.md |

## Applied on this repo

```
vibevault cursor prepare --path .
→ Cursor rules, skill, MCP, pre-commit guard, .gitignore, .cursorignore, AGENTS.md

vibevault cursor shadow
→ vibe-vault: installed · shadow: 0
```

## How to use

- **Projects** → Prepare for Cursor  
- **Audit** → agent chips  
- Git leaks → Fix .gitignore  
- Cursor agent: `suggest_secrets_for_task` with path + task  

## Verification

- Unit tests including `SecretTaskSuggesterTests`
- LOC ≤ 200  
- App bundled and launched
