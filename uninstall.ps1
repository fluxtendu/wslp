#Requires -Version 5.1
<#
.SYNOPSIS
    Removes wslp: registry entries, cmdp from WSL, PATH entry, and shows cleanup instructions.

.DESCRIPTION
    Called automatically by Scoop on uninstall, or run manually.
#>

param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }

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

function Remove-ContextMenuEntries([Microsoft.Win32.RegistryKey]$hive, [string]$classesRoot) {
    $prefix = if ($classesRoot) { "$classesRoot\" } else { "" }
    $removed = $false
    foreach ($subKey in @(
        "${prefix}*\shell\CopyWSLPath",
        "${prefix}Directory\shell\CopyWSLPath",
        "${prefix}Directory\Background\shell\CopyWSLPath"
    )) {
        try {
            $probe = $hive.OpenSubKey($subKey, $false)
            if ($null -ne $probe) {
                $probe.Close()
                $hive.DeleteSubKeyTree($subKey, $false)
                $removed = $true
            }
        } catch { }
    }
    return $removed
}

# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "  wslp -- uninstall" -ForegroundColor White
Write-Host ""

if (-not $Force) {
    if (-not (Prompt-YesNo "  Are you sure you want to uninstall wslp?")) {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Registry: HKCU
# ---------------------------------------------------------------------------

Write-Step "Removing HKCU registry entries..."
$hkcu = [Microsoft.Win32.Registry]::CurrentUser
$hkcuRemoved = Remove-ContextMenuEntries -hive $hkcu -classesRoot "Software\Classes"
if ($hkcuRemoved) {
    Write-Ok "Context menu entries removed (HKCU)."
} else {
    Write-Ok "No HKCU entries found."
}
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
        Write-Ok "Context menu entries removed (HKCR)."
    } else {
        Write-Warn "HKCR entries found but admin rights are required to remove them."
        Write-Warn "Re-run this script as administrator to remove them."
    }
} else {
    Write-Ok "No HKCR entries found."
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
    echo "REMOVED"
else
    echo "NONE"
fi
'@

try {
    $tmpSh = Join-Path $env:TEMP "wslp-uninstall.sh"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmpSh, ($cleanupScript -replace "`r`n", "`n"), $utf8NoBom)
    $tmpDrive = $tmpSh.Substring(0, 1).ToLower()
    $tmpRest  = $tmpSh.Substring(2).Replace('\', '/')
    $tmpShWsl = "/mnt/$tmpDrive$tmpRest"
    $output = & wsl.exe bash $tmpShWsl 2>&1
    Remove-Item $tmpSh -Force -ErrorAction SilentlyContinue
    if ($output -match "REMOVED") {
        Write-Ok "cmdp removed (~/.local/share/cmdp/)."
        Write-Warn "If you sourced cmdp.sh in your shell config (.bashrc, .zshrc), remove that line manually."
    } else {
        Write-Ok "cmdp was not installed in WSL."
    }
} catch {
    Write-Warn "WSL not available -- could not check for cmdp."
}

# ---------------------------------------------------------------------------
# PATH cleanup
# ---------------------------------------------------------------------------

Write-Step "Checking user PATH..."
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath) {
    $entries = $userPath -split ';' | Where-Object { $_.TrimEnd('\') -ne $scriptDir.TrimEnd('\') }
    $newPath = ($entries -join ';').TrimEnd(';')
    if ($newPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Ok "Removed $scriptDir from user PATH."
    } else {
        Write-Ok "Install directory was not in user PATH."
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "  Uninstall complete." -ForegroundColor White
Write-Host ""
Write-Host "  To finish cleanup, you can delete the install directory:" -ForegroundColor Yellow
Write-Host "    $scriptDir" -ForegroundColor Yellow
Write-Host ""
