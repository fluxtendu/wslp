Param([string]$RawPath)

if (-not $RawPath) { $RawPath = $args -join " " }
$inputPath = $RawPath.Trim().Trim('"').Trim("'")

if (-not $inputPath) {
    Write-Host "Usage: wslp <path>" -ForegroundColor Yellow
    Write-Host "Converts a Windows path to its WSL equivalent and copies it to the clipboard."
    exit 0
}

function Convert-ToWslPath($path) {
    # UNC WSL path: \\wsl.localhost\distro\... or \\wsl$\distro\...
    if ($path -like "\\wsl.localhost\*" -or $path -like "\\wsl$\*") {
        $parts = $path.Split('\')
        if ($parts.Length -ge 4) {
            return "/" + ($parts[4..($parts.Length-1)] -join "/")
        }
        return "/"
    }

    # Physical drive path: try wslpath first
    $result = & wsl.exe wslpath -u "$path" 2>$null
    if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*wslpath:*") {
        return $result.Trim()
    }

    # Fallback: manual reconstruction (handles cases where the shell ate backslashes)
    if ($path -match "^([A-Za-z]):(.*)") {
        $drive = $Matches[1].ToLower()
        $rest  = $Matches[2].Replace('\', '/')
        if (-not $rest.StartsWith("/")) { $rest = "/$rest" }
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
