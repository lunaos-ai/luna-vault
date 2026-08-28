# Windows And Linux Support

Vibe Vault ships a **native macOS SwiftUI app**, plus **CLI, MCP, and a cross-platform desktop shell** on Linux and Windows.

| Surface | Stack |
|---------|--------|
| macOS production UI | `VibeVaultApp` (SwiftUI) |
| Linux / Windows UI | `VibeVaultDesktop` ([SwiftCrossUI](https://github.com/moreSwift/swift-cross-ui) — Gtk 4 / WinUI) |
| macOS desktop smoke | Same `VibeVaultDesktop` binary (AppKit backend); prefer SwiftUI for daily use |

## What works today

| Capability | macOS | Linux | Windows |
|------------|-------|-------|---------|
| Encrypted local vault | Yes | Yes | Yes via WSL2 / experimental Swift |
| Master key storage | Keychain | `0600` file under data dir | Same file store (DPAPI planned) |
| Unlock / biometrics | Touch ID / password | Session unlock lease | Same as Linux |
| CLI (`vibevault`) | Yes | Yes | WSL2 recommended |
| MCP server | Yes | Yes | WSL2 recommended |
| Native GUI app | Yes (SwiftUI) | Yes (`VibeVaultDesktop`) | Yes (`VibeVaultDesktop` / WSL) |
| iCloud Drive sync | Yes | No (export/import `.vvsync`) | No (export/import) |
| Vision QR import | Yes | Unsupported | Unsupported |

## Data directories

- **macOS**: `~/Library/Application Support/vibe-vault`
- **Linux**: `${XDG_DATA_HOME:-~/.local/share}/vibe-vault`
- **Windows**: `%APPDATA%\vibe-vault`

Override with `VIBEVAULT_VAULT_DIR`.

On Linux/Windows the vault master key is stored as a mode-`0600` file next to the ciphertext (not in Keychain). Protect the home directory and disk encryption the same way you would for SSH keys. OS keyring / DPAPI backends are planned.

## Linux CLI

Requires Docker with the official Swift image, or a local Swift 5.10+ toolchain:

```bash
bash scripts/build-linux.sh
# binary: .build/release/vibevault
```

Or native:

```bash
swift build -c release --product vibevault --product vibevault-mcp
```

## Linux desktop app

Needs **Swift 6+** (SwiftCrossUI 0.9 uses body macros) and Gtk 4 headers (`libgtk-4-dev` on Debian/Ubuntu). Docker build uses `swift:6.0-jammy` by default (`SWIFT_DESKTOP_LINUX_IMAGE` to override):

```bash
bash scripts/build-desktop-linux.sh
# binary: apps/VibeVaultDesktop/.build/release/VibeVaultDesktop
```

Native (Swift 6+ toolchain + Gtk 4):

```bash
cd apps/VibeVaultDesktop
swift build -c release --product VibeVaultDesktop
```

Unlock from the **Unlock** tab (or `vibevault session unlock`) before revealing secrets.

## Windows

**Supported path today:** [WSL2](https://learn.microsoft.com/windows/wsl/) with Ubuntu.

```bash
# inside WSL
bash scripts/build-wsl.sh
# CLI: .build/release/vibevault
# desktop (Gtk): apps/VibeVaultDesktop/.build/release/VibeVaultDesktop
```

Vault data lives in the Linux home unless you set `VIBEVAULT_VAULT_DIR` (for example to a Windows path under `/mnt/c/...`). Desktop UI needs a WSLg-capable distro (Windows 11) or an X server.

**Native Windows Swift** is experimental. With a Swift Windows toolchain and Windows App SDK:

```powershell
cd apps/VibeVaultDesktop
swift build -c release --product VibeVaultDesktop
```

There is no native Windows CI yet; DPAPI master-key storage is planned.

## Unlock on Linux / Windows

There is no Touch ID. Create a time-bounded unlock lease:

```bash
vibevault session unlock --minutes 30
vibevault get MY_SECRET
vibevault session lock
```

The desktop **Unlock** tab writes the same shared lease.

## Team license

Offline `VV1` license activation works the same on every platform:

```bash
vibevault license activate 'VV1.…'
vibevault license status
```

Or use the desktop **License** tab. Cloud Sync between Macs still uses iCloud Drive. Between Mac and Linux/Windows, use encrypted export/import:

```bash
vibevault sync export --path ./vault.vvsync
vibevault sync import --path ./vault.vvsync --overwrite
```

## Roadmap

1. Linux CLI + MCP packages (deb/rpm or static binary) — in progress.
2. Packaged `VibeVaultDesktop` (AppImage / deb, MSI) via Swift Bundler.
3. Windows native CLI with Credential Manager / DPAPI master-key storage.
4. Keep Solo local-first; no hosted cloud vault required.
