@echo off
setlocal EnableDelayedExpansion

set "SPOTIFY_CONTROL=%~dp0..\scripts\media\spotify-control.ps1"
set "SPOTIFY_SETUP=%~dp0..\setup\installers\install-spotify.ps1"

set "CMD=%~1"
if "%CMD%"=="" goto :help
if /i "%CMD%"=="help" goto :help
if /i "%CMD%"=="status" goto :status
if /i "%CMD%"=="setup" goto :setup
if /i "%CMD%"=="install" goto :setup
if /i "%CMD%"=="open" goto :open
if /i "%CMD%"=="play" goto :play
if /i "%CMD%"=="pause" goto :pause
if /i "%CMD%"=="toggle" goto :toggle
if /i "%CMD%"=="next" goto :next
if /i "%CMD%"=="previous" goto :previous
if /i "%CMD%"=="prev" goto :previous
if /i "%CMD%"=="previoius" goto :previous
if /i "%CMD%"=="shuffle" goto :shuffle
if /i "%CMD%"=="random" goto :shuffle
if /i "%CMD%"=="search" goto :search
if /i "%CMD%"=="track" goto :track
if /i "%CMD%"=="album" goto :album
if /i "%CMD%"=="artist" goto :artist
if /i "%CMD%"=="playlist" goto :playlist
if /i "%CMD%"=="uri" goto :uri

echo Unknown command: %CMD%
echo.
goto :help

:status
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_SETUP!" -Status
set "SPOTIFY_STATUS=Unknown"
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action status`) do set "SPOTIFY_STATUS=%%I"
echo Playback: %SPOTIFY_STATUS%
exit /b 0

:setup
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_SETUP!"
exit /b %errorlevel%

:checkSetup
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_SETUP!" -CheckOnly >nul 2>nul
exit /b %errorlevel%

:ensureSetup
call :checkSetup
if not errorlevel 1 exit /b 0

echo Spotify is not set up on this machine.
choice /C YN /N /M "Run Spotify setup now? [Y/N]: "
if errorlevel 2 exit /b 1
call :setup
exit /b %errorlevel%

:open
call :ensureSetup
if errorlevel 1 exit /b 1
start "" "spotify:"
if errorlevel 1 start "" "https://open.spotify.com/"
exit /b 0

:play
call :ensureSetup
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action play >nul 2>nul
if errorlevel 1 start "" "spotify:play"
exit /b 0

:pause
call :ensureSetup
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action pause >nul 2>nul
exit /b 0

:toggle
call :ensureSetup
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action toggle >nul 2>nul
exit /b 0

:next
call :ensureSetup
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action next >nul 2>nul
exit /b 0

:previous
call :ensureSetup
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action previous >nul 2>nul
exit /b 0

:shuffle
call :ensureSetup
if errorlevel 1 exit /b 1
set "MODE=%~2"
if /i "%MODE%"=="on" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action shuffle-on >nul 2>nul
    exit /b 0
)
if /i "%MODE%"=="off" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action shuffle-off >nul 2>nul
    exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action shuffle-toggle >nul 2>nul
exit /b 0

:search
shift
set "QUERY=%*"
if "%QUERY%"=="" (
    echo Please provide a search query.
    echo Example: spotify search daft punk
    exit /b 1
)
set "SPOTIFY_QUERY=%QUERY%"
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "[uri]::EscapeDataString($env:SPOTIFY_QUERY)"`) do set "ENCODED=%%I"
call :checkSetup
if errorlevel 1 (
    start "" "https://open.spotify.com/search/!ENCODED!"
    exit /b 0
)
start "" "spotify:search:!ENCODED!"
if errorlevel 1 start "" "https://open.spotify.com/search/!ENCODED!"
exit /b 0

:track
call :openItem track %2
exit /b %errorlevel%

:album
call :openItem album %2
exit /b %errorlevel%

:artist
call :openItem artist %2
exit /b %errorlevel%

:playlist
call :openItem playlist %2
exit /b %errorlevel%

:uri
set "VALUE=%~2"
if "%VALUE%"=="" (
    echo Please provide a Spotify URI or URL.
    exit /b 1
)
start "" "%VALUE%"
exit /b 0

:openItem
set "TYPE=%~1"
set "VALUE=%~2"
if "%VALUE%"=="" (
    echo Please provide a %TYPE% ID, URL, or Spotify URI.
    echo Example: spotify %TYPE% 4uLU6hMCjMI75M1A2tKUQC
    exit /b 1
)

if /i "%VALUE:~0,8%"=="spotify:" (
    start "" "%VALUE%"
    exit /b 0
)

if /i "%VALUE:~0,4%"=="http" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='%VALUE%'; if ($u -match 'open\.spotify\.com/([^/?]+)/([^?&#/]+)') { Start-Process ('spotify:' + $matches[1] + ':' + $matches[2]) } else { Start-Process $u }" >nul 2>nul
    exit /b 0
)

call :checkSetup
if errorlevel 1 (
    start "" "https://open.spotify.com/%TYPE%/%VALUE%"
    exit /b 0
)

start "" "spotify:%TYPE%:%VALUE%"
if errorlevel 1 start "" "https://open.spotify.com/%TYPE%/%VALUE%"
exit /b 0

:getStatus
set "SPOTIFY_STATUS=Unknown"
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action status`) do set "SPOTIFY_STATUS=%%I"
exit /b 0

:sendMediaToggle
powershell -NoProfile -ExecutionPolicy Bypass -File "!SPOTIFY_CONTROL!" -Action toggle >nul 2>nul
exit /b 0

:help
echo Spotify CLI helper
echo.
echo Usage:
echo   spotify status
echo   spotify setup
echo   spotify install
echo   spotify open
echo   spotify play
echo   spotify pause
echo   spotify toggle
echo   spotify next
echo   spotify previous
echo   spotify prev
echo   spotify shuffle [on^|off]   ^(toggles if omitted^)
echo   spotify random [on^|off]    ^(toggles if omitted^)
echo   spotify search ^<query^>
echo   spotify track ^<id^|url^|uri^>
echo   spotify album ^<id^|url^|uri^>
echo   spotify artist ^<id^|url^|uri^>
echo   spotify playlist ^<id^|url^|uri^>
echo   spotify uri ^<spotify:...^>
echo.
echo Examples:
echo   spotify status
echo   spotify setup
echo   spotify play
echo   spotify pause
echo   spotify next
echo   spotify previous
echo   spotify random on
echo   spotify random off
echo   spotify search lo fi beats
echo   spotify track 4uLU6hMCjMI75M1A2tKUQC
echo   spotify playlist 37i9dQZF1DXcBWIGoYBM5M
exit /b 0
