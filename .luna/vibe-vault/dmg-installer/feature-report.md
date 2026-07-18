# Feature Report: DMG Installer

**Status:** Complete  
**Date:** 2026-07-12  
**Branch:** local

## Summary

Added a full macOS DMG packaging pipeline that produces a double-click distributable installer. Users can drag VibeVault to Applications (standard macOS flow) or use the one-click **Install Vibe Vault** helper with a progress loader.

## Artifacts

| File | Purpose |
|------|---------|
| `scripts/create-dmg.sh` | Builds compressed `build/VibeVault.dmg` |
| `scripts/release.sh` | Orchestrates bundle → DMG → optional notarize |
| `scripts/notarize-dmg.sh` | Notarizes and staples the DMG |
| `scripts/dmg/InstallHelper.swift` | Progress UI for one-click install |
| `scripts/dmg/DMGBackgroundGen.swift` | Branded DMG window background |
| `scripts/dmg/build-installer-app.sh` | Compiles Install Vibe Vault.app |
| `scripts/dmg/configure-window.sh` | Finder icon layout + background |
| `scripts/tests/create-dmg-smoke.sh` | End-to-end packaging smoke test |

## User Flow

1. Double-click `VibeVault.dmg` — disk image mounts as **Vibe Vault**
2. **Option A:** Drag `VibeVault.app` onto the Applications folder
3. **Option B:** Double-click **Install Vibe Vault** — progress bar, copies to `/Applications`, offers to launch

## Test Results

```
bash scripts/tests/create-dmg-smoke.sh
PASS: DMG smoke test complete
DMG size: 5 MB (under 20 MB target)
```

## Notarization

Set `NOTARIZE=1` to notarize the `.app`. Set `NOTARIZE_DMG=1` to also notarize the DMG after creation.

## Out of Scope

- Playwright E2E (native macOS packaging, not web)
- Developer ID signing (still ad-hoc; production release needs `CODESIGN_IDENTITY`)
- GitHub Release workflow (future)

## Usage

```bash
bash scripts/release.sh
open build/VibeVault.dmg
```
