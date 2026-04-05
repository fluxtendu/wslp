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
    # Strip a single wrapping pair of quotes if present (e.g. from CMD expansion),
    # but never strip quotes that are not symmetrically wrapping the whole string.
    $inputPath = $RawPath.Trim()
    if (($inputPath.StartsWith('"') -and $inputPath.EndsWith('"')) -or
        ($inputPath.StartsWith("'") -and $inputPath.EndsWith("'"))) {
        $inputPath = $inputPath.Substring(1, $inputPath.Length - 2)
    }
} else {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
    Write-Host "Converts a Windows path to its WSL equivalent and copies it to the clipboard."
    exit 0
}

if (-not $inputPath) {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
    exit 0
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
    $finalPath = $finalPath.Trim() -replace '//+', '/'

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
