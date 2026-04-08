Param(
    [string]$RawPath,
    [switch]$Quiet
)

$Version = "1.1.0"

# Handle help/version flags passed as RawPath (from wslp.cmd)
if ($RawPath -in '-h','--help','/?') { $RawPath = '' }
if ($RawPath -in '-V','--version') {
    Write-Output "wslp $Version"
    exit 0
}

if ($RawPath) {
    # %~1 in CMD strips surrounding quotes, but "C:\foo\" leaves a spurious
    # trailing " because the backslash escapes the closing quote at parse time.
    $inputPath = $RawPath.Trim().TrimEnd('"')
} else {
    Write-Host @"
wslp $Version -- Convert Windows paths to WSL paths

Usage:
  wslp <path>
  wslp [options]

Options:
  -q, --quiet      Suppress all output (clipboard only)
  -h, --help       Show this help
  -V, --version    Show version

Examples:
  wslp C:\Users\janot              /mnt/c/Users/janot
  wslp "D:\Bibliotheque calibre"   /mnt/d/Bibliotheque calibre
  wslp \\wsl.localhost\Ubuntu\home  /home
  wslp . | xargs ls                Pipe to other commands

The converted path is copied to the clipboard and printed to stdout.
"@
    exit 0
}

if (-not $inputPath) {
    Write-Host "Usage: wslp <path>"
    exit 0
}

# Normalize bare drive letter "C:" → "C:\" (e.g. from %V on a drive root).
if ($inputPath -match '^[A-Za-z]:$') { $inputPath = $inputPath + '\' }

# Resolve relative paths (., ..\foo, .\file.txt) to absolute Windows paths.
# Only applies to paths that look relative — not UNC, not drive-rooted.
if ($inputPath -notlike '\\*' -and $inputPath -notmatch '^[A-Za-z]:') {
    try {
        $inputPath = [IO.Path]::GetFullPath($inputPath)
    } catch { }
}

function Convert-ToWslPath([string]$path) {
    # UNC WSL path: \\wsl.localhost\distro\... or \\wsl$\distro\...
    if ($path -like '\\wsl.localhost\*' -or $path -like '\\wsl$\*') {
        $parts = $path.Split('\')
        if ($parts.Length -ge 5) {
            return '/' + ($parts[4..($parts.Length - 1)] -join '/')
        }
        return '/'
    }

    # Physical drive path: try wslpath first (most accurate)
    try {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $result = & wsl.exe wslpath -u "$path" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result -and $result.StartsWith('/')) {
            return $result.Trim()
        }
    } catch {
        # wsl.exe not found or failed — fall through to manual conversion
    } finally {
        [Console]::OutputEncoding = $savedEncoding
    }

    # Fallback: manual reconstruction
    if ($path -match '^([A-Za-z]):(.*)') {
        $drive = $Matches[1].ToLower()
        $rest  = $Matches[2].Replace('\', '/')
        if (-not $rest.StartsWith('/')) { $rest = "/$rest" }
        return "/mnt/$drive$rest"
    }

    return $null
}

$finalPath = Convert-ToWslPath $inputPath

if (-not $finalPath) {
    if (-not $Quiet) { Write-Host "Cannot convert: $inputPath" -ForegroundColor Red }
    exit 1
}

$finalPath = $finalPath.Trim()

# Copy to clipboard
try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetText($finalPath)
} catch {
    $finalPath | & "$env:SystemRoot\System32\clip.exe"
}

# Quiet mode: clipboard only, no output at all
if ($Quiet) { exit 0 }

# Status message + path on stdout
$savedEncoding2 = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try {
    & wsl.exe test -e "$finalPath" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "WSL path copied to clipboard (path found)"
    } else {
        Write-Host "WSL path copied to clipboard (path not found)"
    }
} catch {
    Write-Host "WSL path copied to clipboard"
} finally {
    [Console]::OutputEncoding = $savedEncoding2
}

Write-Output $finalPath
