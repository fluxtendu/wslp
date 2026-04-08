@echo off
title wslp - Uninstall
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0uninstall.ps1"
echo.
pause
