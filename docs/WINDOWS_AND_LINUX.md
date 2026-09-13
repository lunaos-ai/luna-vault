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
| Encrypted local vault | Yes | Yes | Yes (native Swift) |
| Master key storage | Keychain | libsecret, else `0600` file | DPAPI (`CryptProtectData`, current user) |
| Unlock / biometrics | Touch ID / password | Session unlock lease | Session unlock lease |
| CLI (`vibevault`) | Yes | Yes | Native (`scripts/build-windows.ps1`) |
| MCP server | Yes | Yes | Native |
| Native GUI app | Yes (SwiftUI) | Yes (`VibeVaultDesktop`) | Yes (`VibeVaultDesktop` / WinUI) |
| Duplicate / copy / AI toggle | Yes | Desktop | Desktop |
| Encrypted `.vvsync` export/import | Yes | CLI + desktop Sync tab | CLI + desktop Sync tab |
| iCloud Drive sync | Yes | No (use `.vvsync`) | No (use `.vvsync`) |
| Vision QR import | Yes | Unsupported | Unsupported |

WSL2 remains a supported fallback if you prefer a Linux toolchain on Windows.

## Data directories

- **macOS**: `~/Library/Application Support/vibe-vault`
- **Linux**: `${XDG_DATA_HOME:-~/.local/share}/vibe-vault`
- **Windows**: `%APPDATA%\vibe-vault`

Override with `VIBEVAULT_VAULT_DIR`.

On Linux the vault master key is stored in the session keyring via Secret Service (`libsecret`) when a keyring daemon is running. If libsecret is missing or the session has no keyring, Vibe Vault falls back to a mode-`0600` file and migrates that file into the keyring on the next successful store. On Windows the master key is a DPAPI blob (`master.vault.master.dpapi`) bound to the current user. A leftover plaintext `master.*.key` file is migrated on first load, then deleted.

## Linux CLI

Requires Docker with the official Swift image, or a local Swift 5.10+ toolchain:

```bash
bash scripts/build-linux.sh
# binary: .build/release/vibevault
bash scripts/package-linux-cli.sh
# archive: build/vibevault-linux-<arch>.tar.gz
KIND=cli bash scripts/package-linux-deb.sh
# deb: build/vibevault_<version>_<arch>.deb
```

CI uploads these tarballs as workflow artifacts on every `main` push (`vibevault-linux-cli`).

## Linux desktop app

Needs **Swift 6+** (SwiftCrossUI 0.9 uses body macros) and Gtk 4 headers (`libgtk-4-dev` on Debian/Ubuntu):

```bash
bash scripts/build-desktop-linux.sh
bash scripts/package-linux-desktop.sh
KIND=desktop bash scripts/package-linux-deb.sh
DOWNLOAD_APPIMAGETOOL=1 bash scripts/package-linux-appimage.sh
```

Unlock from the **Unlock** tab (or `vibevault session unlock`) before revealing secrets.

## Windows (native)

Install [Swift for Windows](https://www.swift.org/install/windows/), then:

```powershell
powershell -File scripts/build-windows.ps1
# CLI: .build\release\vibevault.exe
# MCP: .build\release\vibevault-mcp.exe
powershell -File scripts/package-windows-cli.ps1
# zip: build\vibevault-windows-<arch>.zip
powershell -File scripts/package-windows-msi.ps1
# msi: build\vibevault-windows-<version>.msi
```

`build-windows.ps1` downloads the SQLite amalgamation into `packages/CSQLite` (gitignored) on first run.

Desktop (WinUI / Windows App SDK):

```powershell
powershell -File scripts/build-windows.ps1 -Desktop
powershell -File scripts/package-windows-desktop.ps1
```

CI builds the Windows CLI + MCP on `windows-latest` (`vibevault-windows-cli` zip + MSI). Desktop WinUI is built in the `windows-desktop` job (`vibevault-windows-desktop` zip).

**WSL2 fallback:**

```bash
bash scripts/build-wsl.sh
```

## Unlock on Linux / Windows

There is no Touch ID. Create a time-bounded unlock lease:

```bash
vibevault session unlock --minutes 30
vibevault get MY_SECRET
vibevault session lock
```

The desktop **Unlock** tab writes the same shared lease.

## Sandbox MCP (passkey-gated HTTP)

Sandboxed AI clients cannot spawn `vibevault-mcp` over stdio or read Keychain. Keep Solo local-first: the host listens on **127.0.0.1 only**. The user enrolls a passkey; each session mints a short-lived bearer token. `mcpAllowed` still applies on every tool. Agents cannot enable MCP.

```bash
vibevault mcp passkey set
vibevault mcp sandbox start --client cursor --minutes 30
```

This writes HTTP MCP config (Cursor example):

```json
{
  "mcpServers": {
    "vibe-vault": {
      "type": "http",
      "url": "http://127.0.0.1:17832/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

The sandbox may also send `Authorization: Passkey <enrolled-passkey>` instead of the bearer token. Do not put the long-lived passkey in `mcp.json`. `GET /health` is unauthenticated on loopback. Default port is 17832.

On Linux and Windows, use the desktop **Sandbox** tab or the CLI above. **Audit** shows recent vault reads.

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

Or the desktop **Sync** tab.

## Roadmap

1. ~~Linux CLI + MCP tarball packaging~~ — `scripts/package-linux-cli.sh` + CI artifacts.
2. ~~Packaged `VibeVaultDesktop` tarball~~ — `scripts/package-linux-desktop.sh` + CI artifacts.
3. ~~Windows native CLI with DPAPI master-key storage~~ — `scripts/build-windows.ps1` + CI.
4. ~~Linux OS keyring (libsecret)~~ — Secret Service via `dlopen`, file fallback + migration.
5. ~~Windows desktop CI (WinUI) and MSI~~ — `windows-desktop` job, `scripts/package-windows-msi.ps1`.
6. ~~Linux AppImage / deb~~ — `scripts/package-linux-appimage.sh`, `scripts/package-linux-deb.sh`.
7. Keep Solo local-first; no hosted cloud vault required.
