@echo off
setlocal DisableDelayedExpansion
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0_wslp.ps1" -RawPath "%~1"
