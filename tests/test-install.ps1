# test-install.ps1 — Test install/uninstall cycle for wslp.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests\test-install.ps1
#
# Tests the classic (HKCU) context menu installation and cmdp WSL deployment.
# Run from the project root directory.

$ErrorActionPreference = "Continue"

$projectRoot = Split-Path $PSScriptRoot -Parent
$installScript   = Join-Path $projectRoot "scripts\install-registry.ps1"
$uninstallScript = Join-Path $projectRoot "scripts\uninstall-registry.ps1"
$installDir      = $projectRoot

$passed = 0
$failed = 0

function Test-Pass([string]$name) {
    Write-Host "  PASS  $name" -ForegroundColor Green
    $script:passed++
}
function Test-Fail([string]$name, [string]$detail = "") {
    Write-Host "  FAIL  $name" -ForegroundColor Red
    if ($detail) { Write-Host "        $detail" -ForegroundColor Gray }
    $script:failed++
}

Write-Host ""
Write-Host "=== wslp Install/Uninstall Test Suite ===" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Phase 1: Clean slate — uninstall first
# ---------------------------------------------------------------------------

Write-Host "--- Cleanup (uninstall any previous install) ---" -ForegroundColor Cyan
& powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $uninstallScript 2>&1 | Out-Null

# ---------------------------------------------------------------------------
# Phase 2: Install (classic mode, silent)
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Install (classic mode) ---" -ForegroundColor Cyan

# Run install in silent mode — but Silent installs menu without cmdp
& powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $installScript -InstallDir $installDir -Silent 2>&1 | Out-Null

# Check HKCU registry keys
$hkcu = [Microsoft.Win32.Registry]::CurrentUser

$starKey = $hkcu.OpenSubKey("Software\Classes\*\shell\CopyWSLPath\command", $false)
if ($null -ne $starKey) {
    $cmd = $starKey.GetValue("")
    $starKey.Close()
    if ($cmd -match "ubp\.exe") {
        Test-Pass "Registry: * key exists with ubp.exe command"
    } else {
        Test-Fail "Registry: * key exists but wrong command" $cmd
    }
} else {
    Test-Fail "Registry: * key not found"
}

$dirKey = $hkcu.OpenSubKey("Software\Classes\Directory\shell\CopyWSLPath\command", $false)
if ($null -ne $dirKey) {
    $cmd = $dirKey.GetValue("")
    $dirKey.Close()
    if ($cmd -match "ubp\.exe") {
        Test-Pass "Registry: Directory key exists with ubp.exe command"
    } else {
        Test-Fail "Registry: Directory key exists but wrong command" $cmd
    }
} else {
    Test-Fail "Registry: Directory key not found"
}

# Verify no Background key (removed by design)
$bgKey = $hkcu.OpenSubKey("Software\Classes\Directory\Background\shell\CopyWSLPath", $false)
if ($null -eq $bgKey) {
    Test-Pass "Registry: no Background key (by design)"
} else {
    $bgKey.Close()
    Test-Fail "Registry: unexpected Background key found"
}

# Verify command format includes %V
$starKey2 = $hkcu.OpenSubKey("Software\Classes\*\shell\CopyWSLPath\command", $false)
if ($null -ne $starKey2) {
    $cmd = $starKey2.GetValue("")
    $starKey2.Close()
    if ($cmd -match "%V") {
        Test-Pass "Registry: command uses %V (long path guaranteed)"
    } else {
        Test-Fail "Registry: command does not use %V" $cmd
    }
}

$hkcu.Close()

# ---------------------------------------------------------------------------
# Phase 3: Uninstall
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Uninstall ---" -ForegroundColor Cyan

& powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $uninstallScript 2>&1 | Out-Null

$hkcu = [Microsoft.Win32.Registry]::CurrentUser

$starKey = $hkcu.OpenSubKey("Software\Classes\*\shell\CopyWSLPath", $false)
if ($null -eq $starKey) {
    Test-Pass "Uninstall: * key removed"
} else {
    $starKey.Close()
    Test-Fail "Uninstall: * key still present"
}

$dirKey = $hkcu.OpenSubKey("Software\Classes\Directory\shell\CopyWSLPath", $false)
if ($null -eq $dirKey) {
    Test-Pass "Uninstall: Directory key removed"
} else {
    $dirKey.Close()
    Test-Fail "Uninstall: Directory key still present"
}

$hkcu.Close()

# ---------------------------------------------------------------------------
# Phase 4: cmdp install/uninstall via WSL
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "--- cmdp WSL install ---" -ForegroundColor Cyan

$cmdpSrc = Join-Path $installDir "scripts\cmdp.sh"
$drive = $cmdpSrc.Substring(0, 1).ToLower()
$rest  = $cmdpSrc.Substring(2).Replace('\', '/')

$installCmdpScript = @'
set -e
DEST="$HOME/.local/share/cmdp"
mkdir -p "$DEST"
cp "$WSLP_CMDP_SRC" "$DEST/cmdp.sh"
chmod +x "$DEST/cmdp.sh"
[ -f "$DEST/cmdp.sh" ] && echo "OK" || echo "FAIL"
'@

try {
    $env:WSLP_CMDP_SRC = "/mnt/$drive$rest"
    $env:WSLENV = 'WSLP_CMDP_SRC'
    $output = ($installCmdpScript | & wsl.exe bash 2>&1) -join ""
    if ($output -match "OK") {
        Test-Pass "cmdp: installed to ~/.local/share/cmdp/"
    } else {
        Test-Fail "cmdp: install failed" $output
    }
} catch {
    Test-Fail "cmdp: install exception" "$_"
} finally {
    Remove-Item Env:\WSLP_CMDP_SRC -ErrorAction SilentlyContinue
    Remove-Item Env:\WSLENV        -ErrorAction SilentlyContinue
}

# Uninstall cmdp
$cleanupScript = @'
DEST="$HOME/.local/share/cmdp"
rm -rf "$DEST"
[ -d "$DEST" ] && echo "STILL_PRESENT" || echo "REMOVED"
'@

try {
    $output = ($cleanupScript | & wsl.exe bash 2>&1) -join ""
    if ($output -match "REMOVED") {
        Test-Pass "cmdp: uninstalled (directory removed)"
    } else {
        Test-Fail "cmdp: directory still present after uninstall"
    }
} catch {
    Test-Fail "cmdp: uninstall exception" "$_"
}

# ---------------------------------------------------------------------------
# Phase 5: Reinstall menu for user (leave it installed)
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Reinstalling menu for user ---" -ForegroundColor Cyan
& powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File $installScript -InstallDir $installDir -Silent 2>&1 | Out-Null
Write-Host "  Context menu reinstalled (classic)." -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
$color = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "=== Results: $passed passed, $failed failed ===" -ForegroundColor $color

exit $failed
