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

Write-Host ""
Write-Host "  wslp — uninstall" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# Registry: HKCU (no admin needed)
# ---------------------------------------------------------------------------

$hkcuKeys = @(
    "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\CopyWSLPath",
    "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\CopyWSLPath",
    "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\CopyWSLPath"
)

Write-Step "Removing HKCU registry entries..."
$removedAny = $false
foreach ($key in $hkcuKeys) {
    if (Test-Path -LiteralPath $key) {
        Remove-Item -LiteralPath $key -Recurse -Force
        $removedAny = $true
    }
}
if ($removedAny) { Write-Ok "HKCU entries removed." }

# ---------------------------------------------------------------------------
# Registry: HKCR (admin needed)
# ---------------------------------------------------------------------------

$hkcrKeys = @(
    "Registry::HKEY_CLASSES_ROOT\*\shell\CopyWSLPath",
    "Registry::HKEY_CLASSES_ROOT\Directory\shell\CopyWSLPath",
    "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CopyWSLPath"
)

$hkcrPresent = $hkcrKeys | Where-Object { Test-Path -LiteralPath $_ }

if ($hkcrPresent) {
    if (Test-IsAdmin) {
        Write-Step "Removing HKCR registry entries..."
        foreach ($key in $hkcrKeys) {
            if (Test-Path -LiteralPath $key) {
                Remove-Item -LiteralPath $key -Recurse -Force
            }
        }
        Write-Ok "HKCR entries removed."
    } else {
        Write-Warn "HKCR entries found but admin rights are required to remove them."
        Write-Warn "Run this script as administrator, or remove manually:"
        $hkcrKeys | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
}

# ---------------------------------------------------------------------------
# cmdp (WSL)
# ---------------------------------------------------------------------------

Write-Step "Checking cmdp in WSL..."
$cleanupScript = @'
DEST="$HOME/.local/share/wslp"
if [ -d "$DEST" ]; then
    rm -rf "$DEST"
    echo "Removed $DEST"
fi
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$RC" ] && grep -q "wslp/cmdp.sh" "$RC"; then
        # Remove the wslp block (comment + source line)
        sed -i '/# wslp - Windows path converter/{N;d}' "$RC"
        sed -i '/wslp\/cmdp\.sh/d' "$RC"
        echo "Cleaned $RC"
    fi
done
'@

$wslCheck = & wsl.exe --status 2>$null
if ($LASTEXITCODE -eq 0) {
    $output = $cleanupScript | & wsl.exe bash 2>&1
    $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Ok "WSL cleanup done."
}

Write-Host ""
Write-Host "  Done." -ForegroundColor White
Write-Host ""
