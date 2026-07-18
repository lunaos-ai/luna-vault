# Feature report: UX motion + sounds + smoke tour

**Date:** 2026-07-15  
**Status:** Ran live (`scripts/ux-smoke.sh`)

## What shipped

| Piece | Behavior |
|-------|----------|
| `Motion.swift` | Soft springs; `appearFade`, `pressableScale`; **Reduce Motion** → instant |
| `Feedback.swift` | Trackpad haptic + quiet `Tink`/`Pop`/`Blow`/`Funk` (vol 0.28) |
| Toasts | Bounce symbol + spring enter; dismiss animated |
| Secret rows | Hover scale + press scale |
| Sidebar | Bounce glyph on select + pressable |
| Quick actions | Pressable scale |
| Overview | Staggered `appearFade` sections |
| Settings → Feedback | UI sounds toggle, preview, **Run UX walkthrough** |
| Auto tour | `VIBEVAULT_UX_SMOKE=1` cycles every sidebar pane |

## Run

```bash
cd /Users/shacharsolomon/dev/mobile/luna-vault
bash scripts/ux-smoke.sh
# or manually: Settings → Feedback → Run UX walkthrough
```

Sounds stay optional (default on). Motion respects System Settings → Accessibility → Display → Reduce motion.

## Design note

Stays on the Locksmith's Bench: quiet clicks, small springs, no celebration chrome.
