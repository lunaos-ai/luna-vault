# Native Windows build for Vibe Vault CLI + MCP (and optional desktop).
# Requires: Swift for Windows (https://www.swift.org/install/windows/)
# Usage:
#   powershell -File scripts/build-windows.ps1
#   powershell -File scripts/build-windows.ps1 -Desktop
param(
    [switch]$Desktop
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Write-Error "Swift toolchain required. Install from https://www.swift.org/install/windows/"
}

& powershell -File (Join-Path $Root "scripts\ensure-sqlite-windows.ps1")

Write-Host "==> Building CLI + MCP"
if (Test-Path "Package.resolved") { Remove-Item "Package.resolved" }
swift build -c release --product vibevault --product vibevault-mcp
Get-Item .build\release\vibevault.exe, .build\release\vibevault-mcp.exe

if ($Desktop) {
    Write-Host "==> Building VibeVaultDesktop (WinUI / Windows App SDK)"
    Set-Location (Join-Path $Root "apps\VibeVaultDesktop")
    if (Test-Path "Package.resolved") { Remove-Item "Package.resolved" }
    swift build -c release --product VibeVaultDesktop
    Get-Item .build\release\VibeVaultDesktop.exe
    Set-Location $Root
}

Write-Host "==> Done. Unlock with: vibevault session unlock"
Write-Host "Data dir: %APPDATA%\vibe-vault"
