@echo off
setlocal enabledelayedexpansion

REM Check if current folder is already in PATH
echo %PATH% | findstr /i /c:"%CD%" >nul
if %errorlevel%==0 (
    echo Current folder is already in PATH.
    goto :end
)

REM Get current User PATH from registry
for /f "skip=2 tokens=3*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "UserPath=%%a %%b"
set "UserPath=!UserPath:~0,-1!"

REM Add current folder to User PATH
set "NewPath=!UserPath!;%CD%"
setx PATH "!NewPath!" >nul

REM Reload PATH instantly in current session
set "PATH=!NewPath!;%PATH%"

echo Current folder added to PATH and reloaded instantly!
echo You can use it right away in this session.

:end
endlocal
pause
