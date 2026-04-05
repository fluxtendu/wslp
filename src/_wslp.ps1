Param(
    [string]$RawPath,
    [string]$EncodedPath
)

# -EncodedPath is sent by wslp.vbs: the path is base64-encoded UTF-16LE,
# which guarantees no special character can corrupt the command line.
if ($EncodedPath) {
    $bytes     = [Convert]::FromBase64String($EncodedPath)
    $inputPath = [Text.Encoding]::Unicode.GetString($bytes).Trim()
} elseif ($RawPath) {
    $inputPath = $RawPath.Trim()
} else {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
    Write-Host "Converts a Windows path to its WSL equivalent and copies it to the clipboard."
    exit 0
}

if (-not $inputPath) {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
    exit 0
}

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
        $result = & wsl.exe wslpath -u $path 2>$null
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike '*wslpath:*') {
            return $result.Trim()
        }
    } catch {
        # wsl.exe not found or failed — fall through to manual conversion
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
