#Requires -Version 5.1
<#
.SYNOPSIS
    Installs wslp — Windows/WSL path converter.

.DESCRIPTION
    This script handles both remote and local installation:

    Remote (one-liner):
      irm https://raw.githubusercontent.com/erratos/wslp/main/install.ps1 | iex

      Downloads the latest release, extracts to %LOCALAPPDATA%\Programs\wslp,
      adds the install directory to the user PATH, and offers optional features.

    Local (from project directory or Scoop post-install):
      .\install.ps1 [-InstallDir <path>] [-Silent]

      Skips download, sets up optional features (context menu, cmdp).

.PARAMETER InstallDir
    Override the install directory. Defaults to the script's parent folder
    (local mode) or %LOCALAPPDATA%\Programs\wslp (remote mode).

.PARAMETER Silent
    Non-interactive mode: install context menu, skip cmdp. Used by Scoop.
#>

param(
    [string]$InstallDir,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

$repo = "erratos/wslp"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Write-Warn([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }

function Prompt-YesNo([string]$question, [bool]$default = $true) {
    $hint   = if ($default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer -match "^[Yy]"
}

# ---------------------------------------------------------------------------
# Detect mode: remote (piped via irm | iex) or local
# ---------------------------------------------------------------------------

$isRemote = [string]::IsNullOrEmpty($PSScriptRoot) -or
    -not (Test-Path (Join-Path $PSScriptRoot "src\wslp.cmd") -ErrorAction SilentlyContinue)

Write-Host ""
Write-Host "  wslp installer" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# Install directory
# ---------------------------------------------------------------------------

$defaultDir = if ($isRemote) {
    Join-Path $env:LOCALAPPDATA "Programs\wslp"
} else {
    $PSScriptRoot
}

if (-not $InstallDir) {
    if ($Silent) {
        $InstallDir = $defaultDir
    } else {
        $answer = Read-Host "  Install directory [$defaultDir]"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            $InstallDir = $defaultDir
        } else {
            $InstallDir = $answer.Trim()
        }
    }
}

Write-Host "  -> $InstallDir" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Remote mode: download and extract
# ---------------------------------------------------------------------------

if ($isRemote) {
    Write-Step "Fetching latest release from GitHub..."
    try {
        $releaseUrl = "https://api.github.com/repos/$repo/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing
        $version = $release.tag_name
        $zipUrl = "https://github.com/$repo/archive/refs/tags/$version.zip"
        Write-Ok "Found version $version"
    } catch {
        Write-Step "No release found, downloading main branch..."
        $version = "main"
        $zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
    }

    $tmpZip = Join-Path $env:TEMP "wslp-download.zip"
    $tmpExtract = Join-Path $env:TEMP "wslp-extract"

    Write-Step "Downloading..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
    } catch {
        Write-Err "Download failed: $_"
        exit 1
    }

    Write-Step "Extracting..."
    if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

    $extracted = Get-ChildItem $tmpExtract -Directory | Select-Object -First 1
    if (-not $extracted) {
        Write-Err "Extraction failed: no folder found in archive."
        exit 1
    }

    if (Test-Path $InstallDir) {
        Remove-Item "$InstallDir\*" -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Copy only the needed files (flat layout: src/* → root, + scripts)
    $extractedSrc = Join-Path $extracted.FullName "src"
    if (Test-Path $extractedSrc) {
        Copy-Item -Path "$extractedSrc\*" -Destination $InstallDir -Force
    }
    foreach ($file in @("install.ps1", "uninstall.ps1", "install.cmd", "uninstall.cmd")) {
        $filePath = Join-Path $extracted.FullName $file
        if (Test-Path $filePath) {
            Copy-Item -Path $filePath -Destination $InstallDir -Force
        }
    }
    Write-Ok "Files installed to $InstallDir"

    # Cleanup temp files
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue

    # Add install dir to user PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $pathEntries = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }

    if ($pathEntries -notcontains $InstallDir.TrimEnd('\')) {
        Write-Step "Adding $InstallDir to user PATH..."
        [Environment]::SetEnvironmentVariable("PATH", "$userPath;$InstallDir", "User")
        $env:PATH = "$env:PATH;$InstallDir"
        Write-Ok "Added to PATH. New terminals will have wslp available."
    } else {
        Write-Ok "Already in PATH."
    }
}

# ---------------------------------------------------------------------------
# Resolve required files
# ---------------------------------------------------------------------------

# Remote install = flat layout (files at root), local = project layout (src\)
if ($isRemote) {
    $ubpPath = Join-Path $InstallDir "ubp.exe"
    $ps1Path = Join-Path $InstallDir "_wslp.ps1"
    $cmdpSrc = Join-Path $InstallDir "cmdp.sh"
    $icoPath = Join-Path $InstallDir "wslp.ico"
} else {
    $ubpPath = Join-Path $InstallDir "src\ubp.exe"
    $ps1Path = Join-Path $InstallDir "src\_wslp.ps1"
    $cmdpSrc = Join-Path $InstallDir "src\cmdp.sh"
    $icoPath = Join-Path $InstallDir "src\wslp.ico"
}

if (-not (Test-Path -LiteralPath $ubpPath)) {
    Write-Err "Cannot find ubp.exe at: $ubpPath"
    Write-Err "Please specify the correct install directory with -InstallDir."
    exit 1
}

# ---------------------------------------------------------------------------
# Registry helpers
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
        [string]$ps1Path,
        [string]$icoPath
    )

    $hive = [Microsoft.Win32.Registry]::CurrentUser
    $cmd = "`"$ubpPath`" `"powershell.exe`" `"-ExecutionPolicy`" `"Bypass`" `"-NoProfile`" `"-NonInteractive`" `"-File`" `"$ps1Path`" `"-RawPath`" `"%V`" `"-Quiet`""

    # Use wslp.ico if available, fallback to wsl.exe
    $icon = if ($icoPath -and (Test-Path -LiteralPath $icoPath)) { $icoPath } else { "wsl.exe" }

    $entries = @(
        "Software\Classes\*\shell\CopyWSLPath",
        "Software\Classes\Directory\shell\CopyWSLPath"
    )

    foreach ($entry in $entries) {
        Set-RegistryEntry -hive $hive -subKeyPath $entry `
            -defaultValue "Copy WSL path" -properties @{ Icon = $icon }
        Set-RegistryEntry -hive $hive -subKeyPath "$entry\command" `
            -defaultValue $cmd
    }

    $hive.Close()
}

# ---------------------------------------------------------------------------
# Context menu
# ---------------------------------------------------------------------------

Write-Host ""
$installMenu = if ($Silent) { $true } else {
    Prompt-YesNo "Install 'Copy WSL path' context menu entry (Shift+right-click)?"
}

if ($installMenu) {
    Write-Step "Writing registry keys (HKCU)..."
    try {
        Set-ContextMenuEntries -ubpPath $ubpPath -ps1Path $ps1Path -icoPath $icoPath
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
        $tmpSh = Join-Path $env:TEMP "wslp-cmdp-install.sh"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tmpSh, ($installScript -replace "`r`n", "`n"), $utf8NoBom)
        $tmpDrive = $tmpSh.Substring(0, 1).ToLower()
        $tmpRest  = $tmpSh.Substring(2).Replace('\', '/')
        $tmpShWsl = "/mnt/$tmpDrive$tmpRest"
        $output = & wsl.exe bash $tmpShWsl 2>&1
        Remove-Item $tmpSh -Force -ErrorAction SilentlyContinue
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Write-Ok "cmdp copied to ~/.local/share/cmdp/cmdp.sh"
        # Remove cmdp.sh from Windows install dir (only needed as source for WSL copy)
        if ($isRemote -and (Test-Path $cmdpSrc)) {
            Remove-Item $cmdpSrc -Force -ErrorAction SilentlyContinue
        }
        Write-Host ""
        Write-Host "  To activate cmdp, add this line to your shell config" -ForegroundColor White
        Write-Host "  before any prompt initializer [starship, oh-my-zsh...]:" -ForegroundColor White
        Write-Host ""
        Write-Host '    source "$HOME/.local/share/cmdp/cmdp.sh"  # cmdp: convert WSL path -> Windows path + clipboard' -ForegroundColor Cyan
        Write-Host ""
    } catch {
        Write-Err "Failed to install cmdp in WSL: $_"
    } finally {
        Remove-Item Env:\WSLP_CMDP_SRC -ErrorAction SilentlyContinue
        Remove-Item Env:\WSLENV        -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Ok "wslp installed successfully!"
Write-Host ""
Write-Host "  Usage:  wslp ""C:\Users\janot\projects""" -ForegroundColor Gray
Write-Host "  Help:   wslp --help" -ForegroundColor Gray
Write-Host ""
if ($isRemote) {
    Write-Host "  Open a new terminal for the PATH change to take effect." -ForegroundColor Yellow
    Write-Host ""
}
