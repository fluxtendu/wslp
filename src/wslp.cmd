@echo off
setlocal DisableDelayedExpansion
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0wslp.ps1" -RawPath "%~1"
