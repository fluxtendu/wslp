#Requires -Version 5.1
<#
.SYNOPSIS
    Installs wslp — Windows/WSL path converter.

.DESCRIPTION
    This script handles both remote and local installation:

    Remote (one-liner):
      irm https://raw.githubusercontent.com/erratos/wslp/main/install.ps1 | iex

      Downloads the latest release, extracts to %LOCALAPPDATA%\Programs\wslp,
      adds src\ to the user PATH, and offers optional features.

    Local (from project directory or Scoop post-install):
      .\install.ps1 [-InstallDir <path>] [-Silent]

      Skips download, sets up optional features (context menu, cmdp).

.PARAMETER InstallDir
    Override the install directory. Defaults to the script's parent folder
    (local mode) or %LOCALAPPDATA%\Programs\wslp (remote mode).

.PARAMETER Silent
    Non-interactive mode: install context menu, skip cmdp. Used by Scoop.
#>

param(
    [string]$InstallDir,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

$repo = "erratos/wslp"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Write-Warn([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }

function Prompt-YesNo([string]$question, [bool]$default = $true) {
    $hint   = if ($default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer -match "^[Yy]"
}

# ---------------------------------------------------------------------------
# Detect mode: remote (piped via irm | iex) or local
# ---------------------------------------------------------------------------

$isRemote = -not (Test-Path (Join-Path $PSScriptRoot "src\wslp.cmd") -ErrorAction SilentlyContinue)

Write-Host ""
Write-Host "  wslp installer" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# Remote mode: download and extract
# ---------------------------------------------------------------------------

if ($isRemote) {
    if (-not $InstallDir) {
        $InstallDir = Join-Path $env:LOCALAPPDATA "Programs\wslp"
    }

    Write-Step "Fetching latest release from GitHub..."
    try {
        $releaseUrl = "https://api.github.com/repos/$repo/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing
        $version = $release.tag_name
        $zipUrl = "https://github.com/$repo/archive/refs/tags/$version.zip"
        Write-Ok "Found version $version"
    } catch {
        Write-Step "No release found, downloading main branch..."
        $version = "main"
        $zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
    }

    $tmpZip = Join-Path $env:TEMP "wslp-download.zip"
    $tmpExtract = Join-Path $env:TEMP "wslp-extract"

    Write-Step "Downloading..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
    } catch {
        Write-Err "Download failed: $_"
        exit 1
    }

    Write-Step "Extracting..."
    if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

    $extracted = Get-ChildItem $tmpExtract -Directory | Select-Object -First 1
    if (-not $extracted) {
        Write-Err "Extraction failed: no folder found in archive."
        exit 1
    }

    if (Test-Path $InstallDir) {
        Remove-Item "$InstallDir\*" -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    Copy-Item -Path "$($extracted.FullName)\*" -Destination $InstallDir -Recurse -Force
    Write-Ok "Files installed to $InstallDir"

    # Cleanup temp files
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue

    # Add src\ to user PATH
    $srcDir = Join-Path $InstallDir "src"
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $pathEntries = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }

    if ($pathEntries -notcontains $srcDir.TrimEnd('\')) {
        Write-Step "Adding $srcDir to user PATH..."
        [Environment]::SetEnvironmentVariable("PATH", "$userPath;$srcDir", "User")
        $env:PATH = "$env:PATH;$srcDir"
        Write-Ok "Added to PATH. New terminals will have wslp available."
    } else {
        Write-Ok "Already in PATH."
    }
} else {
    # Local mode
    if (-not $InstallDir) {
        $InstallDir = $PSScriptRoot
    }
    Write-Host "  Install directory: $InstallDir" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Resolve required files
# ---------------------------------------------------------------------------

$ubpPath = Join-Path $InstallDir "src\ubp.exe"
$ps1Path = Join-Path $InstallDir "src\_wslp.ps1"

if (-not (Test-Path -LiteralPath $ubpPath)) {
    Write-Err "Cannot find ubp.exe at: $ubpPath"
    Write-Err "Please specify the correct install directory with -InstallDir."
    exit 1
}

# ---------------------------------------------------------------------------
# Registry helpers
# ---------------------------------------------------------------------------

function Set-RegistryEntry {
    param(
        [Microsoft.Win32.RegistryKey]$hive,
        [string]$subKeyPath,
        [string]$defaultValue,
        [hashtable]$properties = @{}
    )
    $key = $hive.OpenSubKey($subKeyPath, $true)
    if ($null -eq $key) {
        $key = $hive.CreateSubKey($subKeyPath, $true)
    }
    $key.SetValue('', $defaultValue)
    foreach ($name in $properties.Keys) {
        $key.SetValue($name, $properties[$name])
    }
    $key.Close()
}

function Set-ContextMenuEntries {
    param(
        [string]$ubpPath,
        [string]$ps1Path
    )

    $hive = [Microsoft.Win32.Registry]::CurrentUser
    $cmd = "`"$ubpPath`" `"powershell.exe`" `"-ExecutionPolicy`" `"Bypass`" `"-NoProfile`" `"-NonInteractive`" `"-File`" `"$ps1Path`" `"-RawPath`" `"%V`" `"-Quiet`""

    $entries = @(
        "Software\Classes\*\shell\CopyWSLPath",
        "Software\Classes\Directory\shell\CopyWSLPath"
    )

    foreach ($entry in $entries) {
        Set-RegistryEntry -hive $hive -subKeyPath $entry `
            -defaultValue "Copy WSL path" -properties @{ Icon = "wsl.exe" }
        Set-RegistryEntry -hive $hive -subKeyPath "$entry\command" `
            -defaultValue $cmd
    }

    $hive.Close()
}

# ---------------------------------------------------------------------------
# Context menu
# ---------------------------------------------------------------------------

Write-Host ""
$installMenu = if ($Silent) { $true } else {
    Prompt-YesNo "Install 'Copy WSL path' context menu entry (Shift+right-click)?"
}

if ($installMenu) {
    Write-Step "Writing registry keys (HKCU)..."
    try {
        Set-ContextMenuEntries -ubpPath $ubpPath -ps1Path $ps1Path
        Write-Ok "Context menu installed (Shift+right-click on Win11, always visible on Win10)."
    } catch {
        Write-Err "Failed to write registry: $_"
    }
}

# ---------------------------------------------------------------------------
# cmdp (WSL)
# ---------------------------------------------------------------------------

Write-Host ""
$installCmdp = if ($Silent) { $false } else {
    Prompt-YesNo "Install cmdp in WSL (converts WSL paths to Windows paths)?" $false
}

if ($installCmdp) {
    $cmdpSrc = Join-Path $InstallDir "scripts\cmdp.sh"

    $installScript = @'
set -e
DEST="$HOME/.local/share/cmdp"
mkdir -p "$DEST"
cp "$WSLP_CMDP_SRC" "$DEST/cmdp.sh"
chmod +x "$DEST/cmdp.sh"
echo "$DEST/cmdp.sh"
'@

    Write-Step "Installing cmdp in WSL..."
    try {
        $drive = $cmdpSrc.Substring(0, 1).ToLower()
        $rest  = $cmdpSrc.Substring(2).Replace('\', '/')
        $env:WSLP_CMDP_SRC = "/mnt/$drive$rest"
        $env:WSLENV = 'WSLP_CMDP_SRC'
        $output = $installScript | & wsl.exe bash 2>&1
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Write-Ok "cmdp copied to ~/.local/share/cmdp/cmdp.sh"
        Write-Host ""
        Write-Host "  To activate cmdp, add this line to your shell config" -ForegroundColor White
        Write-Host "  BEFORE any prompt initializer [starship, oh-my-zsh...]:" -ForegroundColor White
        Write-Host ""
        Write-Host '    source "$HOME/.local/share/cmdp/cmdp.sh"  # cmdp: convert WSL path -> Windows path + clipboard' -ForegroundColor Cyan
        Write-Host ""
    } catch {
        Write-Err "Failed to install cmdp in WSL: $_"
    } finally {
        Remove-Item Env:\WSLP_CMDP_SRC -ErrorAction SilentlyContinue
        Remove-Item Env:\WSLENV        -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Ok "wslp installed successfully!"
Write-Host ""
Write-Host "  Usage:  wslp ""C:\Users\janot\projects""" -ForegroundColor Gray
Write-Host "  Help:   wslp --help" -ForegroundColor Gray
Write-Host ""
if ($isRemote) {
    Write-Host "  Open a new terminal for the PATH change to take effect." -ForegroundColor Yellow
    Write-Host ""
}
