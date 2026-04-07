#Requires -Version 5.1
<#
.SYNOPSIS
    Removes wslp registry entries and optionally cmdp from WSL.

.NOTES
    If the context menu was installed in modern mode (HKCR), admin rights are required to remove it.
    This script is called automatically by Scoop on uninstall.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# Registry helpers — always use Win32 API directly to avoid any shell
# interpretation of special characters (e.g. the literal "*" key name)
# ---------------------------------------------------------------------------

function Remove-ContextMenuEntries([Microsoft.Win32.RegistryKey]$hive, [string]$classesRoot) {
    foreach ($subKey in @(
        "$classesRoot\*\shell\CopyWSLPath",
        "$classesRoot\Directory\shell\CopyWSLPath",
        "$classesRoot\Directory\Background\shell\CopyWSLPath"
    )) {
        try {
            # DeleteSubKeyTree(name, throwOnMissingSubKey: false) — safe no-op if absent
            $hive.DeleteSubKeyTree($subKey, $false)
        } catch { }
    }
}

# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "  wslp — uninstall" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# Registry: HKCU (no admin needed)
# ---------------------------------------------------------------------------

Write-Step "Removing HKCU registry entries..."
$hkcu = [Microsoft.Win32.Registry]::CurrentUser
Remove-ContextMenuEntries -hive $hkcu -classesRoot "Software\Classes"
Write-Ok "HKCU entries removed."
$hkcu.Close()

# ---------------------------------------------------------------------------
# Registry: HKCR (admin needed)
# ---------------------------------------------------------------------------

Write-Step "Checking HKCR registry entries..."
$hkcr = [Microsoft.Win32.Registry]::ClassesRoot

# Probe without deleting first to give a useful message if admin is missing
$hkcrPresent = $false
foreach ($subKey in @("*\shell\CopyWSLPath", "Directory\shell\CopyWSLPath", "Directory\Background\shell\CopyWSLPath")) {
    $probe = $hkcr.OpenSubKey($subKey, $false)
    if ($null -ne $probe) { $probe.Close(); $hkcrPresent = $true; break }
}

if ($hkcrPresent) {
    if (Test-IsAdmin) {
        Remove-ContextMenuEntries -hive $hkcr -classesRoot ""
        Write-Ok "HKCR entries removed."
    } else {
        Write-Warn "HKCR entries found but admin rights are required to remove them."
        Write-Warn "Re-run this script as administrator to remove them."
    }
}
$hkcr.Close()

# ---------------------------------------------------------------------------
# cmdp (WSL)
# ---------------------------------------------------------------------------

Write-Step "Checking cmdp in WSL..."
$cleanupScript = @'
DEST="$HOME/.local/share/cmdp"
if [ -d "$DEST" ]; then
    rm -rf "$DEST"
    echo "Removed $DEST"
    echo "Note: if you sourced cmdp.sh in your shell config, remove that line manually."
else
    echo "Nothing to remove."
fi
'@

try {
    $output = $cleanupScript | & wsl.exe bash 2>&1
    $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Ok "WSL cleanup done."
} catch {
    Write-Warn "WSL not available — ~/.local/share/cmdp was not removed."
}

Write-Host ""
Write-Host "  Done." -ForegroundColor White
Write-Host ""
