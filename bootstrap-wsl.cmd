@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap-wsl.ps1"
if errorlevel 1 pause
