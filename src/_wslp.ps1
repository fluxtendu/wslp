Param(
    [string]$RawPath
)

if ($RawPath) {
    # %~1 in CMD strips surrounding quotes, but "C:\foo\" leaves a spurious
    # trailing " because the backslash escapes the closing quote at parse time.
    $inputPath = $RawPath.Trim().TrimEnd('"')
} else {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
    Write-Host "Converts a Windows path to its WSL equivalent and copies it to the clipboard."
    exit 0
}

if (-not $inputPath) {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
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

if ($finalPath) {
    $finalPath = $finalPath.Trim()

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetText($finalPath)
    } catch {
        $finalPath | & "$env:SystemRoot\System32\clip.exe"
    }

    Write-Host $finalPath -ForegroundColor Cyan
} else {
    Write-Host "Cannot convert: $inputPath" -ForegroundColor Red
    exit 1
}
