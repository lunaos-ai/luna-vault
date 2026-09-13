# Package vibevault.exe + vibevault-mcp.exe into an MSI (WiX 5).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Cli = if ($env:CLI_BIN) { $env:CLI_BIN } else { Join-Path $Root ".build\release\vibevault.exe" }
$Mcp = if ($env:MCP_BIN) { $env:MCP_BIN } else { Join-Path $Root ".build\release\vibevault-mcp.exe" }
$RawVersion = if ($env:VIBEVAULT_VERSION) { $env:VIBEVAULT_VERSION } else { "0.1.0" }
if ($RawVersion -match '^v?(\d+)\.(\d+)\.(\d+)') {
    $MsiVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"
} else {
    $MsiVersion = "0.1.0.0"
}

if (-not (Test-Path $Cli) -or -not (Test-Path $Mcp)) {
    Write-Error "missing release binaries. build first: powershell -File scripts/build-windows.ps1"
}

function Install-Wix {
    if (Get-Command wix -ErrorAction SilentlyContinue) { return }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Error "WiX CLI not found. Install .NET SDK and: dotnet tool install -g wix"
    }
    try {
        dotnet tool install --global wix --version 5.0.2 | Out-Host
    } catch {
        dotnet tool update --global wix --version 5.0.2 | Out-Host
    }
    $tools = Join-Path $env:USERPROFILE ".dotnet\tools"
    $env:PATH = "$tools;$env:PATH"
    if (-not (Get-Command wix -ErrorAction SilentlyContinue)) {
        Write-Error "wix CLI still not on PATH after install"
    }
}

Install-Wix

$Stage = Join-Path $Root "build\msi-cli"
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
Copy-Item $Cli (Join-Path $Stage "vibevault.exe")
Copy-Item $Mcp (Join-Path $Stage "vibevault-mcp.exe")

$Wxs = Join-Path $Stage "vibevault.wxs"
$CliPath = (Join-Path $Stage "vibevault.exe")
$McpPath = (Join-Path $Stage "vibevault-mcp.exe")
$Xml = @"
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package Name="Vibe Vault CLI" Manufacturer="LunaOS" Version="$MsiVersion"
           UpgradeCode="A7C4E91B-2D3F-4A18-9B6E-1F2A3B4C5D6E">
    <MajorUpgrade DowngradeErrorMessage="A newer version is already installed." />
    <MediaTemplate EmbedCab="yes" />
    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="INSTALLFOLDER" Name="Vibe Vault">
        <Component Id="CliExe" Guid="B1A2C3D4-E5F6-4789-A012-3456789ABCDE">
          <File Id="vibevault.exe" Source="$CliPath" KeyPath="yes" />
        </Component>
        <Component Id="McpExe" Guid="C2B3D4E5-F607-489A-B123-456789ABCDEF">
          <File Id="vibevaultmcp.exe" Source="$McpPath" KeyPath="yes" />
        </Component>
        <Component Id="CliPath" Guid="D3C4E5F6-0718-49AB-C234-56789ABCDEF0">
          <Environment Id="PATH" Name="PATH" Value="[INSTALLFOLDER]" Permanent="no"
                       Part="last" Action="set" System="no" />
        </Component>
      </Directory>
    </StandardDirectory>
    <Feature Id="Main" Title="Vibe Vault CLI">
      <ComponentRef Id="CliExe" />
      <ComponentRef Id="McpExe" />
      <ComponentRef Id="CliPath" />
    </Feature>
  </Package>
</Wix>
"@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Wxs, $Xml, $utf8)

$OutDir = Join-Path $Root "build"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Out = Join-Path $OutDir "vibevault-windows-$MsiVersion.msi"
wix build $Wxs -o $Out
Write-Host "packaged $Out"
