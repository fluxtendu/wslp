#Requires -Version 5.1
<#
.SYNOPSIS
    Installs optional wslp features: context menu and/or WSL cmdp function.

.DESCRIPTION
    This script is called automatically by Scoop after installing wslp,
    but can also be run standalone. All features are optional.

    - Context menu: right-click "Copy WSL path" on files and folders
    - cmdp (WSL): inverse function, copies Windows path from WSL to clipboard

.NOTES
    Context menu (modern Win11 style) requires admin rights.
    Context menu (classic Shift+right-click) does not require admin rights.
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

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdmin([string]$scriptPath, [string]$installDir) {
    Write-Warn "Restarting as administrator..."
    $psArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
    if ($installDir) { $psArgs += " -InstallDir `"$installDir`"" }
    Start-Process powershell.exe -ArgumentList $psArgs -Verb RunAs -Wait
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
        [Microsoft.Win32.RegistryKey]$hive,
        [string]$classesRoot,  # e.g. "" for HKCR, "Software\Classes" for HKCU
        [string]$vbsPath
    )

    $entries = @(
        @{ parent = "$classesRoot\*\shell\CopyWSLPath";                    cmd = "wscript.exe `"$vbsPath`" `"%1`"" },
        @{ parent = "$classesRoot\Directory\shell\CopyWSLPath";            cmd = "wscript.exe `"$vbsPath`" `"%1`"" },
        @{ parent = "$classesRoot\Directory\Background\shell\CopyWSLPath"; cmd = "wscript.exe `"$vbsPath`" `"%V`"" }
    )

    foreach ($entry in $entries) {
        Set-RegistryEntry -hive $hive -subKeyPath $entry.parent `
            -defaultValue "Copy WSL path" -properties @{ Icon = "wsl.exe" }
        Set-RegistryEntry -hive $hive -subKeyPath "$($entry.parent)\command" `
            -defaultValue $entry.cmd
    }
}

# ---------------------------------------------------------------------------
# Resolve install directory
# ---------------------------------------------------------------------------

if (-not $InstallDir) {
    $InstallDir = Split-Path -Parent $PSScriptRoot
}

$vbsPath = Join-Path $InstallDir "src\_wslp.vbs"

if (-not (Test-Path -LiteralPath $vbsPath)) {
    Write-Err "Cannot find _wslp.vbs at: $vbsPath"
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
    Write-Host ""
    Write-Host "  Choose context menu style:" -ForegroundColor White
    Write-Host "    1. Classic  (Shift+right-click on Win11, always visible on Win10)" -ForegroundColor Gray
    Write-Host "       No admin required" -ForegroundColor DarkGray
    Write-Host "    2. Modern   (always visible in Win11 right-click menu)" -ForegroundColor Gray
    Write-Host "       Requires admin rights" -ForegroundColor DarkGray
    Write-Host ""

    $menuStyle = if ($Silent) {
        "classic"
    } else {
        $choice = Read-Host "  Your choice [1/2] (default: 1)"
        if ($choice -eq "2") { "modern" } else { "classic" }
    }

    if ($menuStyle -eq "modern" -and -not (Test-IsAdmin)) {
        Write-Warn "Modern menu requires admin rights."
        $restart = Prompt-YesNo "Restart this script as administrator?"
        if ($restart) {
            Restart-AsAdmin $PSCommandPath $InstallDir
            exit 0
        }
        Write-Warn "Falling back to classic menu."
        $menuStyle = "classic"
    }

    Write-Step "Writing registry keys ($menuStyle)..."
    try {
        if ($menuStyle -eq "modern") {
            $hive = [Microsoft.Win32.Registry]::ClassesRoot
            Set-ContextMenuEntries -hive $hive -classesRoot "" -vbsPath $vbsPath
        } else {
            $hive = [Microsoft.Win32.Registry]::CurrentUser
            Set-ContextMenuEntries -hive $hive -classesRoot "Software\Classes" -vbsPath $vbsPath
        }
        $hive.Close()
        Write-Ok "Context menu installed ($menuStyle)."
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
    # Check wsl.exe exists and a default distro is available
    $wslAvailable = $false
    try {
        $null = & wsl.exe --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            # --status passes even with no distro; probe further
            $null = & wsl.exe -e true 2>$null
            $wslAvailable = ($LASTEXITCODE -eq 0)
        }
    } catch {
        # wsl.exe not found
    }

    if (-not $wslAvailable) {
        Write-Warn "WSL is not available or no default distro is configured. Skipping cmdp."
    } else {
        $cmdpSrc = Join-Path $InstallDir "scripts\cmdp.sh"

        # Pass the source path via environment variable so no path characters
        # (spaces, $, backticks…) can be interpreted by the bash script.
        $installScript = @'
set -e
DEST="$HOME/.local/share/wslp"
mkdir -p "$DEST"
cp "$WSLP_CMDP_SRC" "$DEST/cmdp.sh"
chmod +x "$DEST/cmdp.sh"
SOURCE_LINE='[ -f "$HOME/.local/share/wslp/cmdp.sh" ] && source "$HOME/.local/share/wslp/cmdp.sh"'
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$RC" ] && ! grep -qF "wslp/cmdp.sh" "$RC"; then
        printf '\n# wslp\n%s\n' "$SOURCE_LINE" >> "$RC"
        echo "Added to $RC"
    fi
done
echo "cmdp installed. Restart your WSL shell or run: source ~/.local/share/wslp/cmdp.sh"
'@

        Write-Step "Installing cmdp in WSL..."
        try {
            # Convert Windows path to WSL path and expose as env var inside WSL
            $cmdpWslSrc = (& wsl.exe wslpath -u $cmdpSrc 2>$null).Trim()
            $env:WSLP_CMDP_SRC = $cmdpWslSrc
            $output = $installScript | & wsl.exe bash 2>&1
            $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            Write-Ok "cmdp installed in WSL."
        } catch {
            Write-Err "Failed to install cmdp in WSL: $_"
        } finally {
            Remove-Item Env:\WSLP_CMDP_SRC -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
Write-Host "  Done." -ForegroundColor White
Write-Host ""
