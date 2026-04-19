@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "MORGAN_CONTEXT=%~dp0..\scripts\system\morgan-context.ps1"

if "%~1"=="" goto :help

if /i "%~1"=="hey" if /i "%~2"=="morgan" (
    shift
    shift
    goto :dispatch
)
if /i "%~1"=="hi" if /i "%~2"=="morgan" (
    shift
    shift
    goto :dispatch
)
if /i "%~1"=="ok" if /i "%~2"=="morgan" (
    shift
    shift
    goto :dispatch
)
if /i "%~1"=="okay" if /i "%~2"=="morgan" (
    shift
    shift
    goto :dispatch
)
if /i "%~1"=="morgan" (
    shift
)

:dispatch
set "CMD=%~1"
if "%CMD%"=="" goto :help

if /i "%CMD%"=="help" goto :help
if /i "%CMD%"=="say" goto :say
if /i "%CMD%"=="speak" goto :say
if /i "%CMD%"=="status" goto :status
if /i "%CMD%"=="context" goto :context
if /i "%CMD%"=="sites" goto :sites
if /i "%CMD%"=="site" goto :site
if /i "%CMD%"=="tabs" goto :tabs
if /i "%CMD%"=="tab" goto :tab
if /i "%CMD%"=="switch" goto :switch
if /i "%CMD%"=="computers" goto :computers
if /i "%CMD%"=="computer" goto :computer
if /i "%CMD%"=="pc" goto :computer
if /i "%CMD%"=="open" goto :open
if /i "%CMD%"=="search" goto :search
if /i "%CMD%"=="find" goto :search
if /i "%CMD%"=="google" goto :google
if /i "%CMD%"=="lucky" goto :lucky
if /i "%CMD%"=="play" goto :play
if /i "%CMD%"=="pause" goto :pause
if /i "%CMD%"=="toggle" goto :toggle
if /i "%CMD%"=="next" goto :next
if /i "%CMD%"=="previous" goto :previous
if /i "%CMD%"=="prev" goto :previous
if /i "%CMD%"=="shuffle" goto :shuffle
if /i "%CMD%"=="music" goto :music
if /i "%CMD%"=="media" goto :media
if /i "%CMD%"=="spotify" goto :spotify
if /i "%CMD%"=="steam" goto :steam
if /i "%CMD%"=="game" goto :games
if /i "%CMD%"=="games" goto :games
if /i "%CMD%"=="chrome" goto :chrome
if /i "%CMD%"=="browser" goto :chrome
if /i "%CMD%"=="youtube" goto :youtube
if /i "%CMD%"=="video" goto :youtube
if /i "%CMD%"=="whatsapp" goto :whatsapp
if /i "%CMD%"=="chat" goto :chat
if /i "%CMD%"=="message" goto :message
if /i "%CMD%"=="text" goto :message
if /i "%CMD%"=="setup" goto :setup
if /i "%CMD%"=="install" goto :install
if /i "%CMD%"=="diag" goto :diag
if /i "%CMD%"=="diagnostics" goto :diag
if /i "%CMD%"=="disk" goto :disk
if /i "%CMD%"=="space" goto :disk
if /i "%CMD%"=="ram" goto :ram
if /i "%CMD%"=="memory" goto :ram
if /i "%CMD%"=="net" goto :net
if /i "%CMD%"=="network" goto :net
if /i "%CMD%"=="ip" goto :net
if /i "%CMD%"=="mac" goto :net
if /i "%CMD%"=="taskmgr" goto :taskmgr
if /i "%CMD%"=="tasks" goto :taskmgr
if /i "%CMD%"=="processes" goto :taskmgr
if /i "%CMD%"=="github" goto :github
if /i "%CMD%"=="repo" goto :github

echo Morgan did not understand that request yet.
echo.
goto :help

:say
shift
if "%~1"=="" (
    call "%~dp0say.bat" Morgan is ready.
) else (
    call "%~dp0say.bat" %1 %2 %3 %4 %5 %6 %7 %8 %9
)
exit /b %errorlevel%

:status
echo Morgan status
echo -------------
call "%~dp0media.bat" status
echo.
call "%~dp0steam.bat" status
echo.
call "%~dp0tools-setup.bat" status
if exist "!MORGAN_CONTEXT!" (
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action status
)
exit /b %errorlevel%

:context
shift
if not exist "!MORGAN_CONTEXT!" (
    echo Morgan context helper is missing.
    exit /b 1
)
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action status
    exit /b %errorlevel%
)
if /i "%~1"=="init" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action init
    exit /b %errorlevel%
)
if /i "%~1"=="edit" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action init >nul
    start "" notepad.exe "%~dp0..\setup\security\morgan-context.local.json"
    exit /b 0
)
if /i "%~1"=="sites" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action sites
    exit /b %errorlevel%
)
if /i "%~1"=="computers" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action computers
    exit /b %errorlevel%
)
if /i "%~1"=="tabs" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action tabs
    exit /b %errorlevel%
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action status
exit /b %errorlevel%

:sites
shift
if not exist "!MORGAN_CONTEXT!" (
    echo Morgan context helper is missing.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action sites
exit /b %errorlevel%

:site
shift
if "%~1"=="" (
    goto :sites
)
call :tryOpenContextTarget %1 %2 %3 %4 %5 %6 %7 %8 %9
if "%CONTEXT_OPENED%"=="1" exit /b 0
echo No saved site matched that name yet.
exit /b 1

:tabs
shift
if not exist "!MORGAN_CONTEXT!" (
    echo Morgan context helper is missing.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action tabs
exit /b %errorlevel%

:tab
shift
if not exist "!MORGAN_CONTEXT!" (
    echo Morgan context helper is missing.
    exit /b 1
)
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action tabs
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action focus-tab %*
)
exit /b %errorlevel%

:switch
shift
if "%~1"=="" (
    echo Use: morgan switch ^<tab title^|computer name^>
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action focus-tab %* >nul 2>nul
if not errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action focus-tab %*
    exit /b %errorlevel%
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action computer %1 open
exit /b %errorlevel%

:computers
shift
if not exist "!MORGAN_CONTEXT!" (
    echo Morgan context helper is missing.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action computers
exit /b %errorlevel%

:computer
shift
if not exist "!MORGAN_CONTEXT!" (
    echo Morgan context helper is missing.
    exit /b 1
)
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action computers
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action computer %*
)
exit /b %errorlevel%

:open
shift
if "%~1"=="" (
    call "%~dp0chrome.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="spotify" (
    call "%~dp0spotify.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="chrome" (
    call "%~dp0chrome.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="browser" (
    call "%~dp0chrome.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="youtube" (
    call "%~dp0youtube.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="whatsapp" (
    call "%~dp0whatsapp.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="steam" (
    call "%~dp0steam.bat" open
    exit /b %errorlevel%
)
call :tryOpenContextTarget %1 %2 %3 %4 %5 %6 %7 %8 %9
if "%CONTEXT_OPENED%"=="1" exit /b 0
call :isLikelyUrl "%~1"
if "%IS_URL%"=="1" (
    call "%~dp0chrome.bat" open %1 %2 %3 %4 %5 %6 %7 %8 %9
) else (
    call "%~dp0chrome.bat" google %1 %2 %3 %4 %5 %6 %7 %8 %9
)
exit /b %errorlevel%

:search
shift
if "%~1"=="" (
    echo Please provide something to search for.
    exit /b 1
)
call "%~dp0google.bat" results %1 %2 %3 %4 %5 %6 %7 %8 %9
exit /b %errorlevel%

:google
shift
if "%~1"=="" (
    call "%~dp0google.bat" help
    exit /b %errorlevel%
)
call "%~dp0google.bat" %1 %2 %3 %4 %5 %6 %7 %8 %9
exit /b %errorlevel%

:lucky
shift
if "%~1"=="" (
    echo Please provide a search query.
    exit /b 1
)
call "%~dp0google.bat" lucky %1 %2 %3 %4 %5 %6 %7 %8 %9
exit /b %errorlevel%

:play
shift
if "%~1"=="" (
    call "%~dp0media.bat" play
) else (
    call "%~dp0spotify.bat" search %*
)
exit /b %errorlevel%

:pause
call "%~dp0media.bat" pause
exit /b %errorlevel%

:toggle
call "%~dp0media.bat" toggle
exit /b %errorlevel%

:next
call "%~dp0media.bat" next
exit /b %errorlevel%

:previous
call "%~dp0media.bat" previous
exit /b %errorlevel%

:shuffle
shift
call "%~dp0spotify.bat" shuffle %*
exit /b %errorlevel%

:music
shift
if "%~1"=="" (
    call "%~dp0spotify.bat" open
    exit /b %errorlevel%
)
if /i "%~1"=="play" (
    shift
    if "%~1"=="" (
        call "%~dp0media.bat" play
    ) else (
        call "%~dp0spotify.bat" search %*
    )
    exit /b %errorlevel%
)
if /i "%~1"=="pause" (
    call "%~dp0media.bat" pause
    exit /b %errorlevel%
)
if /i "%~1"=="next" (
    call "%~dp0media.bat" next
    exit /b %errorlevel%
)
if /i "%~1"=="previous" (
    call "%~dp0media.bat" previous
    exit /b %errorlevel%
)
if /i "%~1"=="prev" (
    call "%~dp0media.bat" previous
    exit /b %errorlevel%
)
if /i "%~1"=="status" (
    call "%~dp0media.bat" status
    exit /b %errorlevel%
)
call "%~dp0spotify.bat" search %*
exit /b %errorlevel%

:media
shift
if "%~1"=="" (
    call "%~dp0media.bat" help
) else (
    call "%~dp0media.bat" %*
)
exit /b %errorlevel%

:spotify
shift
if "%~1"=="" (
    call "%~dp0spotify.bat" help
) else (
    call "%~dp0spotify.bat" %*
)
exit /b %errorlevel%

:steam
shift
if "%~1"=="" (
    call "%~dp0steam.bat" help
) else (
    call "%~dp0steam.bat" %1 %2 %3 %4 %5 %6 %7 %8 %9
)
exit /b %errorlevel%

:games
shift
if "%~1"=="" (
    call "%~dp0steam.bat" list
) else (
    call "%~dp0steam.bat" search %1 %2 %3 %4 %5 %6 %7 %8 %9
)
exit /b %errorlevel%

:chrome
shift
if "%~1"=="" (
    call "%~dp0chrome.bat" help
) else (
    call "%~dp0chrome.bat" %*
)
exit /b %errorlevel%

:youtube
shift
if "%~1"=="" (
    call "%~dp0youtube.bat" help
) else (
    call "%~dp0youtube.bat" %*
)
exit /b %errorlevel%

:whatsapp
shift
if "%~1"=="" (
    call "%~dp0whatsapp.bat" help
) else (
    call "%~dp0whatsapp.bat" %*
)
exit /b %errorlevel%

:chat
shift
if "%~1"=="" (
    echo Please provide a chat name.
    exit /b 1
)
call "%~dp0whatsapp.bat" chat %*
exit /b %errorlevel%

:message
shift
if "%~1"=="" (
    echo Use: morgan message ^<chat name^> -- ^<message^>
    exit /b 1
)
call "%~dp0whatsapp.bat" send %*
exit /b %errorlevel%

:setup
shift
if "%~1"=="" (
    call "%~dp0tools-setup.bat"
) else (
    call "%~dp0tools-setup.bat" %*
)
exit /b %errorlevel%

:install
shift
set "TARGET=%~1"
if /i "%TARGET%"=="node" set "TARGET=nvm-node"
if /i "%TARGET%"=="nvm" set "TARGET=nvm-node"
if /i "%TARGET%"=="nvm-node" set "TARGET=nvm-node"
if /i "%TARGET%"=="angular" set "TARGET=angular"
if /i "%TARGET%"=="podman" set "TARGET=podman"
if /i "%TARGET%"=="godot" set "TARGET=godot"
if not defined TARGET (
    call "%~dp0tools-setup.bat"
) else (
    call "%~dp0tools-setup.bat" !TARGET!
)
exit /b %errorlevel%

:diag
shift
if "%~1"=="" (
    call "%~dp0diag.bat" all
) else (
    call "%~dp0diag.bat" %*
)
exit /b %errorlevel%

:disk
call "%~dp0diag.bat" disk
exit /b %errorlevel%

:ram
call "%~dp0diag.bat" ram
exit /b %errorlevel%

:net
call "%~dp0diag.bat" net
exit /b %errorlevel%

:taskmgr
call "%~dp0diag.bat" taskmgr
exit /b %errorlevel%

:github
shift
if "%~1"=="" (
    call "%~dp0github.bat" help
) else (
    call "%~dp0github.bat" %*
)
exit /b %errorlevel%

:tryOpenContextTarget
set "CONTEXT_OPENED=0"
if not exist "!MORGAN_CONTEXT!" exit /b 0
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "!MORGAN_CONTEXT!" -Action resolve-site %1 %2 %3 %4 %5 %6 %7 %8 %9 2^>nul`) do (
    set "CONTEXT_OPENED=1"
    call "%~dp0chrome.bat" open "%%~I"
)
exit /b 0

:isLikelyUrl
set "IS_URL=0"
set "TARGET=%~1"
if /i "%TARGET:~0,7%"=="http://" set "IS_URL=1"
if /i "%TARGET:~0,8%"=="https://" set "IS_URL=1"
if /i "%TARGET:~0,4%"=="www." set "IS_URL=1"
if not "%TARGET%"=="%TARGET:.=%" set "IS_URL=1"
exit /b 0

:help
echo Morgan toolbox helper
echo.
echo Simple examples:
echo   morgan play daft punk
echo   morgan pause
echo   morgan media next
echo   morgan youtube search coding music
echo   morgan open spotify
echo   morgan open https://www.google.com
echo   morgan open work
echo   morgan search best mechanical keyboard switches
echo   morgan context
echo   morgan context edit
echo   morgan sites
echo   morgan tabs
echo   morgan tab github
echo   morgan computers
echo   morgan computer office-pc open
echo   morgan setup status
echo   morgan disk
echo   morgan net
echo   morgan ram
echo   morgan taskmgr
echo   morgan install podman
echo   morgan github init
echo   morgan say Hello there
echo.
echo You can also say:
echo   hey morgan play lo fi beats
echo   morgan music status
echo   morgan switch github
exit /b 0
