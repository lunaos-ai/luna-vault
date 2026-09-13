# Download SQLite amalgamation for native Windows builds.
# Usage: powershell -File scripts/ensure-sqlite-windows.ps1
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dest = Join-Path $Root "packages\CSQLite"
$Header = Join-Path $Dest "include\sqlite3.h"
$Source = Join-Path $Dest "sqlite3.c"

if ((Test-Path $Header) -and (Test-Path $Source)) {
    Write-Host "SQLite amalgamation already present"
    exit 0
}

New-Item -ItemType Directory -Force -Path (Join-Path $Dest "include") | Out-Null
$Url = "https://www.sqlite.org/2024/sqlite-amalgamation-3470200.zip"
$Zip = Join-Path $env:TEMP "sqlite-amalgamation-vv.zip"
Write-Host "Downloading $Url"
Invoke-WebRequest -Uri $Url -OutFile $Zip
$Extract = Join-Path $env:TEMP "sqlite-amalgamation-vv"
if (Test-Path $Extract) { Remove-Item -Recurse -Force $Extract }
Expand-Archive -Path $Zip -DestinationPath $Extract
$Inner = Get-ChildItem $Extract -Directory | Select-Object -First 1
Copy-Item (Join-Path $Inner.FullName "sqlite3.h") $Header -Force
Copy-Item (Join-Path $Inner.FullName "sqlite3.c") $Source -Force
Write-Host "Wrote $Header and $Source"
