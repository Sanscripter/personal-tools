@echo off
setlocal EnableExtensions

set "MEDIA_SCRIPT=%~dp0..\scripts\media\media-control.ps1"
if not exist "%MEDIA_SCRIPT%" (
    echo Media helper script was not found.
    exit /b 1
)

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=status"
if /i "%ACTION%"=="prev" set "ACTION=previous"
if /i "%ACTION%"=="playpause" set "ACTION=toggle"
if /i "%ACTION%"=="help" goto :help

powershell -NoProfile -ExecutionPolicy Bypass -File "%MEDIA_SCRIPT%" -Action "%ACTION%"
exit /b %errorlevel%

:help
echo Global media helper
echo.
echo Usage:
echo   media status
echo   media play
echo   media pause
echo   media toggle
echo   media next
echo   media previous
echo   media prev
echo.
echo What it does:
echo   - controls the current Windows media session
echo   - works with Spotify, Chrome, YouTube, and other supported players
exit /b 0
