@echo off
setlocal EnableExtensions EnableDelayedExpansion

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
if /i "%CMD%"=="spotify" goto :spotify
if /i "%CMD%"=="chrome" goto :chrome
if /i "%CMD%"=="browser" goto :chrome
if /i "%CMD%"=="whatsapp" goto :whatsapp
if /i "%CMD%"=="chat" goto :chat
if /i "%CMD%"=="message" goto :message
if /i "%CMD%"=="text" goto :message
if /i "%CMD%"=="setup" goto :setup
if /i "%CMD%"=="install" goto :install
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
call "%~dp0spotify.bat" status
echo.
call "%~dp0tools-setup.bat" status
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
if /i "%~1"=="whatsapp" (
    call "%~dp0whatsapp.bat" open
    exit /b %errorlevel%
)
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
    call "%~dp0spotify.bat" play
) else (
    call "%~dp0spotify.bat" search %*
)
exit /b %errorlevel%

:pause
call "%~dp0spotify.bat" pause
exit /b %errorlevel%

:toggle
call "%~dp0spotify.bat" toggle
exit /b %errorlevel%

:next
call "%~dp0spotify.bat" next
exit /b %errorlevel%

:previous
call "%~dp0spotify.bat" previous
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
        call "%~dp0spotify.bat" play
    ) else (
        call "%~dp0spotify.bat" search %*
    )
    exit /b %errorlevel%
)
if /i "%~1"=="pause" (
    call "%~dp0spotify.bat" pause
    exit /b %errorlevel%
)
if /i "%~1"=="next" (
    call "%~dp0spotify.bat" next
    exit /b %errorlevel%
)
if /i "%~1"=="previous" (
    call "%~dp0spotify.bat" previous
    exit /b %errorlevel%
)
if /i "%~1"=="prev" (
    call "%~dp0spotify.bat" previous
    exit /b %errorlevel%
)
if /i "%~1"=="status" (
    call "%~dp0spotify.bat" status
    exit /b %errorlevel%
)
call "%~dp0spotify.bat" search %*
exit /b %errorlevel%

:spotify
shift
if "%~1"=="" (
    call "%~dp0spotify.bat" help
) else (
    call "%~dp0spotify.bat" %*
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

:github
shift
if "%~1"=="" (
    call "%~dp0github.bat" help
) else (
    call "%~dp0github.bat" %*
)
exit /b %errorlevel%

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
echo   morgan open spotify
echo   morgan open https://www.google.com
echo   morgan search best mechanical keyboard switches
echo   morgan setup status
echo   morgan install podman
echo   morgan github init
echo   morgan say Hello there
echo.
echo You can also say:
echo   hey morgan play lo fi beats
echo   morgan music status
exit /b 0
