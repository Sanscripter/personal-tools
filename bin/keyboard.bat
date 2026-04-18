@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\system\keyboard-language.ps1" %*
set "RESULT=%errorlevel%"
endlocal & exit /b %RESULT%
