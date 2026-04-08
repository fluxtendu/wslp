#Requires -Version 5.1
<#
.SYNOPSIS
    Removes wslp: registry entries, cmdp from WSL, and optionally the install folder.

.DESCRIPTION
    Called automatically by Scoop on uninstall, or run manually.
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

function Remove-ContextMenuEntries([Microsoft.Win32.RegistryKey]$hive, [string]$classesRoot) {
    $prefix = if ($classesRoot) { "$classesRoot\" } else { "" }
    foreach ($subKey in @(
        "${prefix}*\shell\CopyWSLPath",
        "${prefix}Directory\shell\CopyWSLPath",
        "${prefix}Directory\Background\shell\CopyWSLPath"
    )) {
        try {
            $hive.DeleteSubKeyTree($subKey, $false)
        } catch { }
    }
}

# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "  wslp -- uninstall" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# Registry: HKCU
# ---------------------------------------------------------------------------

Write-Step "Removing HKCU registry entries..."
$hkcu = [Microsoft.Win32.Registry]::CurrentUser
Remove-ContextMenuEntries -hive $hkcu -classesRoot "Software\Classes"
Write-Ok "HKCU entries removed."
$hkcu.Close()

# ---------------------------------------------------------------------------
# Registry: HKCR (admin needed, legacy)
# ---------------------------------------------------------------------------

Write-Step "Checking HKCR registry entries..."
$hkcr = [Microsoft.Win32.Registry]::ClassesRoot

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
    $cleanupScript = $cleanupScript -replace "`r`n", "`n"
    $output = $cleanupScript | & wsl.exe bash 2>&1
    $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Ok "WSL cleanup done."
} catch {
    Write-Warn "WSL not available -- ~/.local/share/cmdp was not removed."
}

Write-Host ""
Write-Host "  Done." -ForegroundColor White
Write-Host ""
