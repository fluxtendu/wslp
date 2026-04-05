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
    # Non-interactive mode: skip all prompts and install with defaults
    [switch]$Silent,
    # Install path of wslp (defaults to the directory containing this script's parent)
    [string]$InstallDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$msg) {
    Write-Host "  $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "  [!]  $msg" -ForegroundColor Yellow
}

function Write-Err([string]$msg) {
    Write-Host "  [X]  $msg" -ForegroundColor Red
}

function Prompt-YesNo([string]$question, [bool]$default = $true) {
    $hint = if ($default) { "[Y/n]" } else { "[y/N]" }
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
    $args = "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
    if ($installDir) { $args += " -InstallDir `"$installDir`"" }
    Start-Process powershell.exe -ArgumentList $args -Verb RunAs -Wait
}

# ---------------------------------------------------------------------------
# Resolve install directory
# ---------------------------------------------------------------------------

if (-not $InstallDir) {
    # When called by Scoop, this script lives in <scoop>/apps/wslp/current/scripts/
    # The binaries are in <scoop>/apps/wslp/current/src/
    $InstallDir = Split-Path -Parent $PSScriptRoot
}

$vbsPath = Join-Path $InstallDir "src\wslp.vbs"

if (-not (Test-Path $vbsPath)) {
    Write-Err "Cannot find wslp.vbs at: $vbsPath"
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
    Write-Host "       → No admin required" -ForegroundColor DarkGray
    Write-Host "    2. Modern   (always visible in Win11 right-click menu)" -ForegroundColor Gray
    Write-Host "       → Requires admin rights" -ForegroundColor DarkGray
    Write-Host ""

    $menuStyle = if ($Silent) {
        "classic"
    } else {
        $choice = Read-Host "  Your choice [1/2] (default: 1)"
        if ($choice -eq "2") { "modern" } else { "classic" }
    }

    $wscriptCmd = "wscript.exe `"$vbsPath`" `"%1`""
    $wscriptCmdBg = "wscript.exe `"$vbsPath`" `"%V`""

    if ($menuStyle -eq "modern") {
        if (-not (Test-IsAdmin)) {
            Write-Warn "Modern menu requires admin rights."
            $restart = Prompt-YesNo "Restart this script as administrator?"
            if ($restart) {
                Restart-AsAdmin $PSCommandPath $InstallDir
                exit 0
            } else {
                Write-Warn "Skipping modern menu. Falling back to classic."
                $menuStyle = "classic"
            }
        }
    }

    if ($menuStyle -eq "modern") {
        # Write to HKCR (requires admin) — visible in Win11 modern menu
        $roots = @(
            @{ key = "Registry::HKEY_CLASSES_ROOT\*\shell\CopyWSLPath\command";                    cmd = $wscriptCmd   },
            @{ key = "Registry::HKEY_CLASSES_ROOT\Directory\shell\CopyWSLPath\command";            cmd = $wscriptCmd   },
            @{ key = "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CopyWSLPath\command"; cmd = $wscriptCmdBg }
        )
        $parentKeys = @(
            "Registry::HKEY_CLASSES_ROOT\*\shell\CopyWSLPath",
            "Registry::HKEY_CLASSES_ROOT\Directory\shell\CopyWSLPath",
            "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CopyWSLPath"
        )
    } else {
        # Write to HKCU\Software\Classes (no admin) — visible with Shift+right-click on Win11
        $roots = @(
            @{ key = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\CopyWSLPath\command";                    cmd = $wscriptCmd   },
            @{ key = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\CopyWSLPath\command";            cmd = $wscriptCmd   },
            @{ key = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\CopyWSLPath\command"; cmd = $wscriptCmdBg }
        )
        $parentKeys = @(
            "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\CopyWSLPath",
            "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\CopyWSLPath",
            "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\CopyWSLPath"
        )
    }

    Write-Step "Writing registry keys ($menuStyle)..."

    try {
        foreach ($i in 0..($parentKeys.Length - 1)) {
            $parentKey = $parentKeys[$i]
            $entry     = $roots[$i]

            if (-not (Test-Path -LiteralPath $parentKey)) {
                New-Item -Path $parentKey -Force | Out-Null
            }
            Set-ItemProperty -LiteralPath $parentKey -Name "(default)" -Value "Copy WSL path"
            Set-ItemProperty -LiteralPath $parentKey -Name "Icon"      -Value "wsl.exe"

            if (-not (Test-Path -LiteralPath $entry.key)) {
                New-Item -Path $entry.key -Force | Out-Null
            }
            Set-ItemProperty -LiteralPath $entry.key -Name "(default)" -Value $entry.cmd
        }
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
    # Check WSL is available
    $wslCheck = & wsl.exe --status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "WSL does not appear to be installed or running. Skipping cmdp."
    } else {
        $cmdpSrc = Join-Path $InstallDir "scripts\cmdp.sh"
        # Convert to WSL path
        $cmdpWslSrc = (& wsl.exe wslpath -u "$cmdpSrc" 2>$null).Trim()

        $installScript = @"
set -e
DEST="\$HOME/.local/share/wslp"
mkdir -p "\$DEST"
cp "$cmdpWslSrc" "\$DEST/cmdp.sh"
chmod +x "\$DEST/cmdp.sh"

SOURCE_LINE="[ -f \"\$HOME/.local/share/wslp/cmdp.sh\" ] && source \"\$HOME/.local/share/wslp/cmdp.sh\""

for RC in "\$HOME/.zshrc" "\$HOME/.bashrc"; do
    if [ -f "\$RC" ] && ! grep -qF "wslp/cmdp.sh" "\$RC"; then
        echo "" >> "\$RC"
        echo "# wslp - Windows path converter" >> "\$RC"
        echo "\$SOURCE_LINE" >> "\$RC"
        echo "Added to \$RC"
    fi
done
echo "cmdp installed. Restart your WSL shell or run: source ~/.local/share/wslp/cmdp.sh"
"@

        Write-Step "Installing cmdp in WSL..."
        try {
            $output = $installScript | & wsl.exe bash 2>&1
            $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            Write-Ok "cmdp installed in WSL."
        } catch {
            Write-Err "Failed to install cmdp in WSL: $_"
        }
    }
}

Write-Host ""
Write-Host "  Done." -ForegroundColor White
Write-Host ""
