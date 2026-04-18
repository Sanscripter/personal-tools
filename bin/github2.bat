@echo off
setlocal enabledelayedexpansion

REM Check for gh CLI
where gh >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: GitHub CLI not found
    exit /b 1
)

REM Check authentication
gh auth status >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Not authenticated
    exit /b 1
)

set "CMD=%1"

if "%CMD%"=="config" goto config
if "%CMD%"=="init" goto init
if "%CMD%"=="help" goto help
if "%CMD%"=="" goto help
echo Unknown command
goto help

:config
    echo Configuring repository...
    
    git rev-parse --git-dir 1>nul 2>nul
    if errorlevel 1 (
        echo Not a git repository
        exit /b 1
    )
    
    echo Current repository:
    gh repo view
    echo.
    
    echo Options:
    echo 1. Change visibility
    echo 2. Update description
    set /p "CHOICE=Choose (1-2): "
    
    if "%CHOICE%"=="1" (
        echo Change visibility:
        echo 1. Public
        echo 2. Private
        set /p "VIS=Choose (1-2): "
        if "!VIS!"=="1" gh repo edit --visibility public
        if "!VIS!"=="2" gh repo edit --visibility private
    )
    
    if "%CHOICE%"=="2" (
        set /p "DESC=New description: "
        if not "!DESC!"=="" gh repo edit --description "!DESC!"
    )
    
    echo Done!
    exit /b 0

:init
    echo Initializing repository...
    
    for %%I in (.) do set "NAME=%%~nxI"
    
    set /p "REPONAME=Repository name [!NAME!]: "
    if "!REPONAME!"=="" set "REPONAME=!NAME!"
    
    set /p "DESC=Description (optional): "
    
    echo Visibility:
    echo 1. Public
    echo 2. Private (default)
    set /p "VIS=Choose (1-2) [2]: "
    if "!VIS!"=="" set "VIS=2"
    
    if "!VIS!"=="1" (
        set "VISFLAG=--public"
    ) else (
        set "VISFLAG=--private"
    )
    
    if not exist ".git" git init
    
    if not exist "README.md" (
        echo # !REPONAME!> README.md
        if not "!DESC!"=="" echo.>> README.md && echo !DESC!>> README.md
        git add README.md
        git commit -m "Initial commit"
    )
    
    set "GHCMD=gh repo create !REPONAME! !VISFLAG! --source=. --push"
    if not "!DESC!"=="" set "GHCMD=!GHCMD! --description=!DESC!"
    
    !GHCMD!
    
    if %errorlevel% equ 0 (
        echo Success!
        gh repo view --web
    )
    
    exit /b 0

:help
    echo Usage: github2 [command]
    echo.
    echo Commands:
    echo   init    - Create new GitHub repository
    echo   config  - Configure existing repository
    echo   help    - Show this help
    exit /b 0
