@echo off
setlocal EnableExtensions DisableDelayedExpansion

if "%~1"=="" goto :usageError

set "MODE=speak"
set "SAY_LANG="
set "SAY_VOICE="
set "SAY_RATE="
set "SAY_VOLUME="
set "TEXT="
for %%I in ("%~dp0..\scripts\system\say.ps1") do set "SAY_SCRIPT=%%~fI"

:parse
if "%~1"=="" goto :dispatch

if /I "%~1"=="help" goto :help
if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help

if /I "%~1"=="list" (
    set "MODE=list"
    shift
    goto :parse
)
if /I "%~1"=="-list" (
    set "MODE=list"
    shift
    goto :parse
)
if /I "%~1"=="--list" (
    set "MODE=list"
    shift
    goto :parse
)
if /I "%~1"=="languages" (
    set "MODE=languages"
    shift
    goto :parse
)
if /I "%~1"=="-languages" (
    set "MODE=languages"
    shift
    goto :parse
)
if /I "%~1"=="--languages" (
    set "MODE=languages"
    shift
    goto :parse
)
if /I "%~1"=="-probe" (
    if "%~2"=="" goto :usageError
    set "MODE=probe"
    set "SAY_LANG=%~2"
    shift
    shift
    goto :parse
)
if /I "%~1"=="--probe" (
    if "%~2"=="" goto :usageError
    set "MODE=probe"
    set "SAY_LANG=%~2"
    shift
    shift
    goto :parse
)

if /I "%~1"=="-lang" (
    if "%~2"=="" goto :usageError
    set "SAY_LANG=%~2"
    shift
    shift
    goto :parse
)
if /I "%~1"=="--lang" (
    if "%~2"=="" goto :usageError
    set "SAY_LANG=%~2"
    shift
    shift
    goto :parse
)

if /I "%~1"=="-voice" (
    if "%~2"=="" goto :usageError
    set "SAY_VOICE=%~2"
    shift
    shift
    goto :parse
)
if /I "%~1"=="--voice" (
    if "%~2"=="" goto :usageError
    set "SAY_VOICE=%~2"
    shift
    shift
    goto :parse
)

if /I "%~1"=="-rate" (
    if "%~2"=="" goto :usageError
    set "SAY_RATE=%~2"
    shift
    shift
    goto :parse
)
if /I "%~1"=="--rate" (
    if "%~2"=="" goto :usageError
    set "SAY_RATE=%~2"
    shift
    shift
    goto :parse
)

if /I "%~1"=="-volume" (
    if "%~2"=="" goto :usageError
    set "SAY_VOLUME=%~2"
    shift
    shift
    goto :parse
)
if /I "%~1"=="--volume" (
    if "%~2"=="" goto :usageError
    set "SAY_VOLUME=%~2"
    shift
    shift
    goto :parse
)

if "%~1"=="--" (
    shift
)
goto :collect

:collect
if "%~1"=="" goto :dispatch
if defined TEXT (
    call set "TEXT=%%TEXT%% %~1"
) else (
    set "TEXT=%~1"
)
shift
goto :collect

:dispatch
if /I "%MODE%"=="list" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SAY_SCRIPT%" -ListVoices
    exit /b %errorlevel%
)

if /I "%MODE%"=="languages" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SAY_SCRIPT%" -ListLanguages
    exit /b %errorlevel%
)

if /I "%MODE%"=="probe" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SAY_SCRIPT%" -ProbeLanguage "%SAY_LANG%"
    exit /b %errorlevel%
)

if not defined TEXT goto :usageError

set "SAY_TEXT=%TEXT%"
start "" /b powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SAY_SCRIPT%"
endlocal
exit /b 0

:help
echo Usage:
echo   say message text
echo   say -lang pt-BR message text
echo   say -lang "Japanese" こんにちは
echo   say -voice "Microsoft Zira" message text
echo   say -rate 2 -volume 80 message text
echo   say -list
echo   say -languages
echo   say -probe japanese
echo.
echo Notes:
echo   - Use -languages to browse all recognized Windows language names and tags.
echo   - Use -probe to see which installed voice best matches a requested language.
echo   - Speaking another language depends on the matching voice being installed.
endlocal
exit /b 0

:usageError
echo Usage: say ^<message^>
echo Try:   say -list
endlocal
exit /b 1
