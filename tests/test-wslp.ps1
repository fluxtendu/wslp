# test-wslp.ps1 — Automated test suite for wslp CLI path conversion.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests\test-wslp.ps1
#
# Run from the project root directory.

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$wslpScript  = Join-Path $projectRoot "src\_wslp.ps1"

# Ensure wsl.exe output is read as UTF-8
$savedEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Test cases ---
# Each test has: Name, Path (Windows input), Expected (WSL output)
# Build Unicode strings with char codes for PS5 compatibility.
$tests = @(

    # ===== Basic paths =====
    @{
        Name     = "Simple ASCII path"
        Path     = "C:\Windows\System32\notepad.exe"
        Expected = "/mnt/c/Windows/System32/notepad.exe"
    }
    @{
        Name     = "Drive root C:\"
        Path     = "C:\"
        Expected = "/mnt/c/"
    }
    @{
        Name     = "Drive root D:\"
        Path     = "D:\"
        Expected = "/mnt/d/"
    }
    @{
        Name     = "Bare drive letter C:"
        Path     = "C:"
        Expected = "/mnt/c/"
    }

    # ===== Accents and French characters =====
    @{
        Name     = "French accents (cafe)"
        Path     = "C:\Dossier " + [char]0x00C9 + "t" + [char]0x00E9 + "\caf" + [char]0x00E9 + ".txt"
        Expected = "/mnt/c/Dossier " + [char]0x00C9 + "t" + [char]0x00E9 + "/caf" + [char]0x00E9 + ".txt"
    }
    @{
        Name     = "Spaces and apostrophe with accents"
        Path     = "C:\L'" + [char]0x00E9 + "t" + [char]0x00E9 + " de l'ann" + [char]0x00E9 + "e\fichier.txt"
        Expected = "/mnt/c/L'" + [char]0x00E9 + "t" + [char]0x00E9 + " de l'ann" + [char]0x00E9 + "e/fichier.txt"
    }
    @{
        Name     = "c-cedilla and i-trema"
        Path     = "C:\" + [char]0x00E7 + "a va\na" + [char]0x00EF + "ve.txt"
        Expected = "/mnt/c/" + [char]0x00E7 + "a va/na" + [char]0x00EF + "ve.txt"
    }

    # ===== Shell metacharacters =====
    @{
        Name     = "Ampersand in path"
        Path     = "C:\Tom & Jerry\episode.txt"
        Expected = "/mnt/c/Tom & Jerry/episode.txt"
    }
    @{
        Name     = "Percent signs"
        Path     = "C:\100% Complete\file.txt"
        Expected = "/mnt/c/100% Complete/file.txt"
    }
    @{
        Name     = "Exclamation mark"
        Path     = "C:\Important!\urgent!.txt"
        Expected = "/mnt/c/Important!/urgent!.txt"
    }
    @{
        Name     = "Caret (cmd escape char)"
        Path     = "C:\Folder^name\file^1.txt"
        Expected = "/mnt/c/Folder^name/file^1.txt"
    }
    @{
        Name     = "Parentheses"
        Path     = "C:\Project (copy)\file (1).txt"
        Expected = "/mnt/c/Project (copy)/file (1).txt"
    }
    @{
        Name     = "Semicolons and equals"
        Path     = "C:\key=value;data\config.txt"
        Expected = "/mnt/c/key=value;data/config.txt"
    }
    @{
        Name     = "At sign and hash"
        Path     = "C:\user@domain\#channel\file.txt"
        Expected = "/mnt/c/user@domain/#channel/file.txt"
    }
    @{
        Name     = "Dollar sign"
        Path     = 'C:\$Recycle.Bin\$file.txt'
        Expected = '/mnt/c/$Recycle.Bin/$file.txt'
    }
    @{
        Name     = "Multiple special chars combined"
        Path     = "C:\Tom & Jerry (2024) [100%]!\file.txt"
        Expected = "/mnt/c/Tom & Jerry (2024) [100%]!/file.txt"
    }

    # ===== UNC WSL paths =====
    @{
        Name     = "UNC wsl.localhost"
        Path     = "\\wsl.localhost\Ubuntu\home\user\file.txt"
        Expected = "/home/user/file.txt"
    }
    @{
        # wsl$ is the legacy UNC prefix
        Name     = 'UNC wsl$'
        Path     = '\\wsl$\Ubuntu\home\user\file.txt'
        Expected = "/home/user/file.txt"
    }
    @{
        Name     = "UNC with spaces"
        Path     = "\\wsl.localhost\Ubuntu\home\user\mon dossier\fichier.txt"
        Expected = "/home/user/mon dossier/fichier.txt"
    }
    @{
        Name     = "UNC with accents"
        Path     = "\\wsl.localhost\Ubuntu\home\user\caf" + [char]0x00E9 + "\file.txt"
        Expected = "/home/user/caf" + [char]0x00E9 + "/file.txt"
    }

    # ===== CJK / Cyrillic =====
    @{
        Name     = "Cyrillic"
        Path     = "C:\" + [string]::new([char[]]@(0x0422, 0x0435, 0x0441, 0x0442)) + "\file.txt"
        Expected = "/mnt/c/" + [string]::new([char[]]@(0x0422, 0x0435, 0x0441, 0x0442)) + "/file.txt"
    }
    @{
        Name     = "CJK (Japanese)"
        Path     = "C:\" + [string]::new([char[]]@(0x30C6, 0x30B9, 0x30C8)) + "\file.txt"
        Expected = "/mnt/c/" + [string]::new([char[]]@(0x30C6, 0x30B9, 0x30C8)) + "/file.txt"
    }

    # ===== Mixed scripts =====
    @{
        Name     = "Mixed scripts"
        Path     = "C:\" + [char]0x00E9 + "t" + [char]0x00E9 + "_" `
                 + [string]::new([char[]]@(0x0422, 0x0435, 0x0441, 0x0442)) + "_" `
                 + [string]::new([char[]]@(0x30C6, 0x30B9, 0x30C8)) + "\file.txt"
        Expected = "/mnt/c/" + [char]0x00E9 + "t" + [char]0x00E9 + "_" `
                 + [string]::new([char[]]@(0x0422, 0x0435, 0x0441, 0x0442)) + "_" `
                 + [string]::new([char[]]@(0x30C6, 0x30B9, 0x30C8)) + "/file.txt"
    }

    # ===== Edge cases =====
    @{
        Name     = "Path with trailing backslash-quote (CMD artifact)"
        Path     = 'C:\Users\janot"'
        Expected = "/mnt/c/Users/janot"
    }
    @{
        Name     = "Spaces only in folder name"
        Path     = "C:\   \file.txt"
        Expected = "/mnt/c/   /file.txt"
    }
)

# --- Test runner ---
$passed = 0
$failed = 0
$results = @()

Write-Host ""
Write-Host "=== wslp CLI Test Suite ===" -ForegroundColor Cyan
Write-Host "Script: $wslpScript" -ForegroundColor Gray
Write-Host ""

foreach ($test in $tests) {
    $testName = $test.Name
    $testPath = $test.Path
    $expected = $test.Expected

    try {
        $output = & powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive `
            -File $wslpScript -RawPath $testPath 2>&1

        # Output contains status messages + the path on the last line.
        # Extract only the last non-empty line (the converted path).
        $lines = $output | ForEach-Object { $_.ToString().Trim() } |
            Where-Object { $_ -ne "" }
        $result = if ($lines -is [array]) { $lines[-1] } else { $lines }

        if ($result -eq $expected) {
            Write-Host "  PASS  $testName" -ForegroundColor Green
            $results += "PASS  $testName"
            $passed++
        } else {
            Write-Host "  FAIL  $testName" -ForegroundColor Red
            # Hex dump for debugging encoding issues
            $expBytes = [System.Text.Encoding]::UTF8.GetBytes($expected)
            $gotBytes = [System.Text.Encoding]::UTF8.GetBytes($result)
            $expHex = ($expBytes | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
            $gotHex = ($gotBytes | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
            Write-Host "        Expected: [$expected]" -ForegroundColor Gray
            Write-Host "        Got:      [$result]" -ForegroundColor Gray
            Write-Host "        Exp hex:  $expHex" -ForegroundColor DarkGray
            Write-Host "        Got hex:  $gotHex" -ForegroundColor DarkGray
            $results += "FAIL  $testName"
            $failed++
        }
    } catch {
        Write-Host "  FAIL  $testName (exception: $_)" -ForegroundColor Red
        $results += "FAIL  $testName (exception)"
        $failed++
    }
}

# --- No-argument test ---
Write-Host ""
Write-Host "--- Edge cases ---" -ForegroundColor Cyan

try {
    $output = & powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive `
        -File $wslpScript 2>&1
    $text = ($output | ForEach-Object { $_.ToString() }) -join " "
    if ($text -match "Usage") {
        Write-Host "  PASS  No argument shows usage" -ForegroundColor Green
        $results += "PASS  No argument shows usage"
        $passed++
    } else {
        Write-Host "  FAIL  No argument: unexpected output" -ForegroundColor Red
        $results += "FAIL  No argument"
        $failed++
    }
} catch {
    Write-Host "  FAIL  No argument (exception: $_)" -ForegroundColor Red
    $results += "FAIL  No argument (exception)"
    $failed++
}

# --- Summary ---
Write-Host ""
$color = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "=== Results: $passed passed, $failed failed ===" -ForegroundColor $color

# Save results
$resultsFile = Join-Path $PSScriptRoot "test-wslp-results.log"
$results | Out-File -FilePath $resultsFile -Encoding UTF8
Write-Host "Results saved to: $resultsFile" -ForegroundColor Gray

# Restore encoding
[Console]::OutputEncoding = $savedEncoding

exit $failed
