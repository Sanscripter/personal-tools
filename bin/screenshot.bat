@echo off
setlocal EnableExtensions

set "SCREENSHOT_SCRIPT=%~dp0..\scripts\media\screenshot.ps1"
if not exist "%SCREENSHOT_SCRIPT%" (
    echo Screenshot helper script was not found.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCREENSHOT_SCRIPT%" %*
exit /b %errorlevel%
