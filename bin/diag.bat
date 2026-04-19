@echo off
setlocal

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=all"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\system\diagnostics.ps1" -Action "%ACTION%"
set "RESULT=%errorlevel%"
endlocal & exit /b %RESULT%
