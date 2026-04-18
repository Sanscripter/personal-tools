@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "GOOGLE_RAW_ARGS=%*"

set "GOOGLE_SCRIPT=%~dp0..\scripts\web\google-search.ps1"
if not exist "%GOOGLE_SCRIPT%" set "GOOGLE_SCRIPT=%~dp0..\compat\google-search.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%GOOGLE_SCRIPT%"
exit /b %errorlevel%
