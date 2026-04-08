@echo off
setlocal DisableDelayedExpansion

:: Check for flags
set "WSLP_QUIET="
set "WSLP_ARG="

if /i "%~1"=="-q"       (set "WSLP_QUIET=-Quiet" & set "WSLP_ARG=%~2" & goto run)
if /i "%~1"=="--quiet"   (set "WSLP_QUIET=-Quiet" & set "WSLP_ARG=%~2" & goto run)
if /i "%~2"=="-q"       (set "WSLP_QUIET=-Quiet" & set "WSLP_ARG=%~1" & goto run)
if /i "%~2"=="--quiet"   (set "WSLP_QUIET=-Quiet" & set "WSLP_ARG=%~1" & goto run)
set "WSLP_ARG=%~1"

:run
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0_wslp.ps1" -RawPath "%WSLP_ARG%" %WSLP_QUIET%
