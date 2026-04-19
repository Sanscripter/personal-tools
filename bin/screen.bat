@echo off
setlocal EnableExtensions

set "SCREEN_SCRIPT=%~dp0..\scripts\media\screen-record.ps1"
if not exist "%SCREEN_SCRIPT%" (
    echo Screen recorder script was not found.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCREEN_SCRIPT%" %*
exit /b %errorlevel%
