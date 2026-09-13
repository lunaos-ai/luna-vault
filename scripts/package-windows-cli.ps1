# Package vibevault.exe + vibevault-mcp.exe into a Windows zip.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Cli = if ($env:CLI_BIN) { $env:CLI_BIN } else { Join-Path $Root ".build\release\vibevault.exe" }
$Mcp = if ($env:MCP_BIN) { $env:MCP_BIN } else { Join-Path $Root ".build\release\vibevault-mcp.exe" }
$Arch = if ($env:TARGET_ARCH) { $env:TARGET_ARCH } else { $env:PROCESSOR_ARCHITECTURE }
if (-not $Arch) { $Arch = "unknown" }
$Version = if ($env:VIBEVAULT_VERSION) { $env:VIBEVAULT_VERSION } else { "0.1.0" }
$Stage = Join-Path $Root "build\vibevault-windows-$Arch"
$Out = Join-Path $Root "build\vibevault-windows-$Arch.zip"

if (-not (Test-Path $Cli) -or -not (Test-Path $Mcp)) {
    Write-Error "missing release binaries. build first: powershell -File scripts/build-windows.ps1"
}

if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path (Join-Path $Stage "bin") | Out-Null
Copy-Item $Cli (Join-Path $Stage "bin\vibevault.exe")
Copy-Item $Mcp (Join-Path $Stage "bin\vibevault-mcp.exe")

$Readme = @"
# Vibe Vault Windows CLI $Version

Contents: vibevault.exe (CLI) and vibevault-mcp.exe (MCP server).

Install: copy bin\ onto PATH.

First use:
  vibevault session unlock --minutes 30
  vibevault --help
  vibevault mcp install --client all

Data dir: %APPDATA%\vibe-vault
Master key: DPAPI-protected for the current Windows user.
See docs/WINDOWS_AND_LINUX.md.
"@
$Readme | Set-Content -Path (Join-Path $Stage "README.md") -Encoding utf8

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
if (Test-Path $Out) { Remove-Item $Out }
Compress-Archive -Path $Stage -DestinationPath $Out
Write-Host "packaged $Out"
