#Requires -Version 5.1
<#
.SYNOPSIS
    Installs optional wslp features: context menu and/or WSL cmdp function.

.DESCRIPTION
    This script is called automatically by Scoop after installing wslp,
    but can also be run standalone. All features are optional.

    - Context menu: Shift+right-click "Copy WSL path" on files and folders (HKCU, no admin)
    - cmdp (WSL): inverse function, copies Windows path from WSL to clipboard
#>

param(
    [switch]$Silent,
    [string]$InstallDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }

function Prompt-YesNo([string]$question, [bool]$default = $true) {
    $hint   = if ($default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer -match "^[Yy]"
}

# ---------------------------------------------------------------------------
# Registry helpers — always use Win32 API directly to avoid any shell
# interpretation of special characters (e.g. the literal "*" key name)
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
    $cmd = "`"$ubpPath`" `"powershell.exe`" `"-ExecutionPolicy`" `"Bypass`" `"-NoProfile`" `"-NonInteractive`" `"-File`" `"$ps1Path`" `"-RawPath`" `"%V`""

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
# Resolve install directory
# ---------------------------------------------------------------------------

if (-not $InstallDir) {
    $InstallDir = Split-Path -Parent $PSScriptRoot
}

$ubpPath = Join-Path $InstallDir "src\ubp.exe"
$ps1Path = Join-Path $InstallDir "src\_wslp.ps1"

if (-not (Test-Path -LiteralPath $ubpPath)) {
    Write-Err "Cannot find ubp.exe at: $ubpPath"
    Write-Err "Please specify the correct install directory with -InstallDir."
    exit 1
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "  wslp — optional features installer" -ForegroundColor White
Write-Host "  Install directory: $InstallDir" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# Context menu
# ---------------------------------------------------------------------------

$installMenu = if ($Silent) { $true } else {
    Prompt-YesNo "Install 'Copy WSL path' context menu entry?"
}

if ($installMenu) {
    Write-Step "Writing registry keys (HKCU, Shift+right-click)..."
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

    # Pass the source path via environment variable so no path characters
    # (spaces, $, backticks…) can be interpreted by the bash script.
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
        Write-Host '    source "$HOME/.local/share/cmdp/cmdp.sh"  # cmdp: convert WSL path → Windows path + clipboard' -ForegroundColor Cyan
        Write-Host ""
    } catch {
        Write-Err "Failed to install cmdp in WSL: $_"
    } finally {
        Remove-Item Env:\WSLP_CMDP_SRC -ErrorAction SilentlyContinue
        Remove-Item Env:\WSLENV        -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "  Done." -ForegroundColor White
Write-Host ""
