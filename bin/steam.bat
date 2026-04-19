@echo off
setlocal DisableDelayedExpansion

set "STEAM_SCRIPT=%~dp0..\scripts\media\steam-control.ps1"
if not exist "%STEAM_SCRIPT%" (
    echo Steam helper script was not found.
    exit /b 1
)

set "PS_ARGS=@("
:collectArgs
if "%~1"=="" goto runSteam
set "ARG=%~1"
set "ARG=%ARG:'=''%"
set "PS_ARGS=%PS_ARGS%'%ARG%',"
shift
goto collectArgs

:runSteam
if "%PS_ARGS%"=="@(" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%STEAM_SCRIPT%"
    exit /b %errorlevel%
)

set "PS_ARGS=%PS_ARGS:~0,-1%)"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$argsList = %PS_ARGS%; & '%STEAM_SCRIPT%' @argsList"
exit /b %errorlevel%
