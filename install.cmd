@echo off
title wslp - Install
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
echo.
pause
