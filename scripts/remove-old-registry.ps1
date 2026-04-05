#Requires -RunAsAdministrator
# Removes the old wslp context menu entries installed under HKCR.

$keys = @(
    "Registry::HKEY_CLASSES_ROOT\*\shell\CopyWSLPath",
    "Registry::HKEY_CLASSES_ROOT\Directory\shell\CopyWSLPath",
    "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CopyWSLPath"
)

foreach ($key in $keys) {
    if (Test-Path -LiteralPath $key) {
        Remove-Item -LiteralPath $key -Recurse -Force
        Write-Host "Removed: $key" -ForegroundColor Green
    } else {
        Write-Host "Not found: $key" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Done. Old context menu entries removed." -ForegroundColor White
