@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "CMD=%~1"
if "%CMD%"=="" goto :openNoArgs
if /i "%CMD%"=="help" goto :help
if /i "%CMD%"=="install" goto :install
if /i "%CMD%"=="get" goto :install
if /i "%CMD%"=="open" (
    shift
    goto :openWithTarget
)
if /i "%CMD%"=="url" (
    shift
    goto :openWithTarget
)
if /i "%CMD%"=="google" (
    shift
    call "%~dp0google.bat" lucky %1 %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %errorlevel%
)
if /i "%CMD%"=="search" (
    shift
    call "%~dp0google.bat" results %1 %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %errorlevel%
)
if /i "%CMD:~0,5%"=="open " (
    set "TARGET=%CMD:~5%"
    goto :openResolved
)
if /i "%CMD:~0,4%"=="url " (
    set "TARGET=%CMD:~4%"
    goto :openResolved
)

goto :openWithTarget

:openNoArgs
set "TARGET="
goto :openResolved

:openWithTarget
set "TARGET=%~1"
if not "%~2"=="" set "TARGET=%TARGET% %~2"
if not "%~3"=="" set "TARGET=%TARGET% %~3"
if not "%~4"=="" set "TARGET=%TARGET% %~4"
if not "%~5"=="" set "TARGET=%TARGET% %~5"
if not "%~6"=="" set "TARGET=%TARGET% %~6"
if not "%~7"=="" set "TARGET=%TARGET% %~7"
if not "%~8"=="" set "TARGET=%TARGET% %~8"
if not "%~9"=="" set "TARGET=%TARGET% %~9"
if "%TARGET%"=="" if defined CHROME_TARGET set "TARGET=%CHROME_TARGET%"
goto :openResolved

:openResolved
call :findChrome
if not defined CHROME_EXE (
    call :installChrome
    if errorlevel 1 exit /b 1
    call :findChrome
)

if not defined CHROME_EXE (
    echo Chrome was installed, but it could not be located automatically.
    exit /b 1
)

if "%TARGET%"=="" (
    start "" "!CHROME_EXE!"
) else (
    start "" "!CHROME_EXE!" "%TARGET%"
)
exit /b 0

:install
call :installChrome
exit /b %errorlevel%

:findChrome
set "CHROME_EXE="
for %%P in (
    "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
    "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
    "%LocalAppData%\Google\Chrome\Application\chrome.exe"
) do (
    if exist %%~P (
        set "CHROME_EXE=%%~P"
        goto :eof
    )
)
where chrome >nul 2>nul
if not errorlevel 1 (
    for /f "delims=" %%I in ('where chrome ^| findstr /i /c:"chrome.exe"') do (
        set "CHROME_EXE=%%I"
        goto :eof
    )
)
goto :eof

:installChrome
call :findChrome
if defined CHROME_EXE (
    echo Chrome is already installed.
    exit /b 0
)

echo.
echo =============================================================
echo WARNING: Chrome installation may request Administrator access.
echo If you want a fresh elevated shell first, run: admin
echo =============================================================
choice /C YN /N /M "Continue with Chrome installation now? [Y/N]: "
if errorlevel 2 exit /b 1
echo.
echo Installing Google Chrome...
where winget >nul 2>nul
if not errorlevel 1 (
    winget install -e --id Google.Chrome --accept-package-agreements --accept-source-agreements --silent
    exit /b %errorlevel%
)

set "INSTALLER=%TEMP%\chrome_installer.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing 'https://dl.google.com/chrome/install/latest/chrome_installer.exe' -OutFile $env:TEMP\chrome_installer.exe"
if errorlevel 1 (
    echo Failed to download the Chrome installer.
    exit /b 1
)

start /wait "" "%INSTALLER%" /install /silent /do-not-launch-chrome
set "RESULT=%errorlevel%"
if exist "%INSTALLER%" del /q "%INSTALLER%" >nul 2>nul
exit /b %RESULT%

:help
echo Chrome helper
echo.
echo Usage:
echo   chrome
echo   chrome open
echo   chrome open https://www.google.com
echo   chrome google best ramen in tokyo
echo   chrome search cafes near me
echo   chrome install
echo   chrome get
echo   chrome url https://www.google.com
echo.
echo What it does:
echo   - Launches Chrome if it is already installed
echo   - Installs Chrome automatically if it is missing
echo   - Optionally opens a URL after launch
exit /b 0
