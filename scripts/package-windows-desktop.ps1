# Package VibeVaultDesktop.exe into a Windows zip.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Desktop = if ($env:DESKTOP_BIN) {
    $env:DESKTOP_BIN
} else {
    Join-Path $Root "apps\VibeVaultDesktop\.build\release\VibeVaultDesktop.exe"
}
$Arch = if ($env:TARGET_ARCH) { $env:TARGET_ARCH } else { $env:PROCESSOR_ARCHITECTURE }
if (-not $Arch) { $Arch = "unknown" }
$Version = if ($env:VIBEVAULT_VERSION) { $env:VIBEVAULT_VERSION } else { "0.1.0" }
$Stage = Join-Path $Root "build\VibeVaultDesktop-windows-$Arch"
$Out = Join-Path $Root "build\VibeVaultDesktop-windows-$Arch.zip"

if (-not (Test-Path $Desktop)) {
    Write-Error "missing desktop binary. build first: powershell -File scripts/build-windows.ps1 -Desktop"
}

if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path (Join-Path $Stage "bin") | Out-Null
Copy-Item $Desktop (Join-Path $Stage "bin\VibeVaultDesktop.exe")

$Readme = @"
# Vibe Vault Desktop (Windows) $Version

WinUI shell via SwiftCrossUI. Same vault as the CLI under %APPDATA%\vibe-vault.

Unlock with the Unlock tab or: vibevault session unlock --minutes 30

See docs/WINDOWS_AND_LINUX.md.
"@
$Readme | Set-Content -Path (Join-Path $Stage "README.md") -Encoding utf8

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
if (Test-Path $Out) { Remove-Item $Out }
Compress-Archive -Path $Stage -DestinationPath $Out
Write-Host "packaged $Out"
