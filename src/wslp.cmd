@echo off
setlocal DisableDelayedExpansion

:: %~1 strips surrounding quotes but "C:\foo\" leaves a trailing " because
:: the backslash before the closing quote acts as an escape in CMD parsing.
:: We strip that spurious trailing quote here before passing to PowerShell.
set "ARG=%~1"
if defined ARG if "%ARG:~-1%"==^""  set "ARG=%ARG:~0,-1%"

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0_wslp.ps1" -RawPath "%ARG%"
