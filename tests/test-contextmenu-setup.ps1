# test-contextmenu-setup.ps1 — Prepare test files for manual context menu testing.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests\test-contextmenu-setup.ps1
#   powershell -ExecutionPolicy Bypass -File tests\test-contextmenu-setup.ps1 -Cleanup
#
# Creates a folder with edge-case filenames, opens Explorer, and shows a checklist.

param(
    [switch]$Cleanup
)

$testRoot = Join-Path $env:TEMP "wslp-test-contextmenu"

if ($Cleanup) {
    if (Test-Path $testRoot) {
        Remove-Item $testRoot -Recurse -Force
        Write-Host "Cleaned up: $testRoot" -ForegroundColor Green
    } else {
        Write-Host "Nothing to clean." -ForegroundColor Gray
    }
    exit 0
}

# --- Create test structure ---
Write-Host ""
Write-Host "=== Context Menu Test Setup ===" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $testRoot) {
    Remove-Item $testRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

# Files with accents
$accentFiles = @(
    "caf" + [char]0x00E9 + ".txt",                          # cafe.txt
    [char]0x00FC + "ber.txt",                                 # uber.txt
    "na" + [char]0x00EF + "ve.txt",                          # naive.txt
    [char]0x00E7 + "a va.txt"                                # ca va.txt
)

# Folders with special chars
$specialDirs = @(
    "Tom & Jerry (2024)",
    "100% Complete",
    "Important!",
    "key=value;data",
    "user@domain"
)

# Mixed scripts
$mixedName = [char]0x00E9 + "t" + [char]0x00E9 + "_" `
    + [string]::new([char[]]@(0x0422, 0x0435, 0x0441, 0x0442)) + "_" `
    + [string]::new([char[]]@(0x30C6, 0x30B9, 0x30C8))

foreach ($f in $accentFiles) {
    [System.IO.File]::WriteAllText((Join-Path $testRoot $f), "test", [System.Text.Encoding]::UTF8)
}

foreach ($d in $specialDirs) {
    New-Item -ItemType Directory -Path (Join-Path $testRoot $d) -Force | Out-Null
}

New-Item -ItemType Directory -Path (Join-Path $testRoot $mixedName) -Force | Out-Null

Write-Host "  Test folder: $testRoot" -ForegroundColor White
Write-Host ""

# --- Compute expected WSL paths ---
$drive = $testRoot.Substring(0, 1).ToLower()
$wslRoot = "/mnt/$drive" + $testRoot.Substring(2).Replace('\', '/')

Write-Host "  Manual test checklist:" -ForegroundColor White
Write-Host "  (Shift+right-click each item, choose 'Copy WSL path', paste to verify)" -ForegroundColor Gray
Write-Host ""

foreach ($f in $accentFiles) {
    Write-Host "  [ ] $f" -ForegroundColor Yellow
    Write-Host "      Expected: $wslRoot/$f" -ForegroundColor DarkGray
}
Write-Host ""
foreach ($d in $specialDirs) {
    Write-Host "  [ ] $d\" -ForegroundColor Yellow
    Write-Host "      Expected: $wslRoot/$d" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  [ ] $mixedName\" -ForegroundColor Yellow
Write-Host "      Expected: $wslRoot/$mixedName" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  When done, run with -Cleanup to remove test files." -ForegroundColor Gray
Write-Host ""

# Open Explorer
Start-Process explorer.exe $testRoot
