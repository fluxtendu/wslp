#Requires -Version 5.1
<#
.SYNOPSIS
    One-liner installer for wslp.

.DESCRIPTION
    Downloads the latest wslp release from GitHub, extracts it to
    %LOCALAPPDATA%\Programs\wslp, adds it to the user PATH, and
    optionally sets up the context menu and cmdp.

.EXAMPLE
    irm https://raw.githubusercontent.com/erratos/wslp/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$repo = "erratos/wslp"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\wslp"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }

function Prompt-YesNo([string]$question, [bool]$default = $true) {
    $hint   = if ($default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer -match "^[Yy]"
}

# ---------------------------------------------------------------------------
# Fetch latest release info from GitHub API
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "  wslp installer" -ForegroundColor White
Write-Host ""

Write-Step "Fetching latest release from GitHub..."

try {
    $releaseUrl = "https://api.github.com/repos/$repo/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing
    $version = $release.tag_name
    $zipUrl = "https://github.com/$repo/archive/refs/tags/$version.zip"
    Write-Ok "Found version $version"
} catch {
    # Fallback: if no release exists yet, use main branch
    Write-Step "No release found, downloading main branch..."
    $version = "main"
    $zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
}

# ---------------------------------------------------------------------------
# Download and extract
# ---------------------------------------------------------------------------

$tmpZip = Join-Path $env:TEMP "wslp-download.zip"
$tmpExtract = Join-Path $env:TEMP "wslp-extract"

Write-Step "Downloading $zipUrl..."
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

# Find the extracted folder (GitHub names it repo-version)
$extracted = Get-ChildItem $tmpExtract -Directory | Select-Object -First 1
if (-not $extracted) {
    Write-Err "Extraction failed: no folder found in archive."
    exit 1
}

# ---------------------------------------------------------------------------
# Install to target directory
# ---------------------------------------------------------------------------

Write-Step "Installing to $installDir..."

if (Test-Path $installDir) {
    # Preserve existing install — remove old files
    Remove-Item "$installDir\*" -Recurse -Force
}
else {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Copy everything from extracted folder
Copy-Item -Path "$($extracted.FullName)\*" -Destination $installDir -Recurse -Force

Write-Ok "Files installed to $installDir"

# ---------------------------------------------------------------------------
# Add to user PATH if not already present
# ---------------------------------------------------------------------------

$srcDir = Join-Path $installDir "src"
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$pathEntries = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }

if ($pathEntries -notcontains $srcDir.TrimEnd('\')) {
    Write-Step "Adding $srcDir to user PATH..."
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$srcDir", "User")
    $env:PATH = "$env:PATH;$srcDir"
    Write-Ok "Added to PATH. New terminals will have wslp available."
} else {
    Write-Ok "Already in PATH."
}

# ---------------------------------------------------------------------------
# Optional features
# ---------------------------------------------------------------------------

Write-Host ""
$installExtras = Prompt-YesNo "Set up optional features (context menu, cmdp)?"

if ($installExtras) {
    $extrasScript = Join-Path $installDir "scripts\install-registry.ps1"
    if (Test-Path $extrasScript) {
        & $extrasScript -InstallDir $installDir
    } else {
        Write-Err "install-registry.ps1 not found at $extrasScript"
    }
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Ok "wslp installed successfully!"
Write-Host ""
Write-Host "  Usage:  wslp ""C:\Users\janot\projects""" -ForegroundColor Gray
Write-Host "  Help:   wslp --help" -ForegroundColor Gray
Write-Host ""
Write-Host "  Open a new terminal for the PATH change to take effect." -ForegroundColor Yellow
Write-Host ""
