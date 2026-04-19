@echo off
setlocal EnableExtensions
set "YOUTUBE_RAW_ARGS=%*"

set "YOUTUBE_SCRIPT=%~dp0..\scripts\web\youtube-control.ps1"
if not exist "%YOUTUBE_SCRIPT%" (
    echo YouTube helper script was not found.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%YOUTUBE_SCRIPT%"
exit /b %errorlevel%
