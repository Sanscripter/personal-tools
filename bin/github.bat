@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "COMMAND=%~1"

if "%COMMAND%"=="" goto show_help
if /i "%COMMAND%"=="help" goto show_help
if /i "%COMMAND%"=="init" goto init_repo
if /i "%COMMAND%"=="create" goto init_repo
if /i "%COMMAND%"=="config" goto config_repo

echo Unknown command: %COMMAND%
echo.
goto show_help

:require_gh
where gh >nul 2>nul
if errorlevel 1 (
    echo Error: GitHub CLI ^(gh^) is not installed or not in PATH.
    echo Please install it from: https://cli.github.com/
    exit /b 1
)

gh auth status >nul 2>nul
if errorlevel 1 (
    echo You are not authenticated with GitHub CLI.
    echo Please run: gh auth login
    exit /b 1
)
exit /b 0

:init_repo
call :require_gh
if errorlevel 1 exit /b 1

echo ========================================
echo GitHub Repository Initializer
echo ========================================
echo.

git rev-parse --git-dir >nul 2>nul
if not errorlevel 1 (
    echo Warning: This directory is already a git repository.
    set /p "CONTINUE=Do you want to continue anyway? [y/n] [n]: "
    if /i not "!CONTINUE!"=="y" (
        echo Cancelled.
        exit /b 0
    )
)

for %%I in (.) do set "SUGGESTED_NAME=%%~nxI"

echo Current directory: %CD%
echo.
set /p "REPO_NAME=Repository name [!SUGGESTED_NAME!]: "
if "!REPO_NAME!"=="" set "REPO_NAME=!SUGGESTED_NAME!"

echo.
set /p "DESCRIPTION=Repository description (optional): "

echo.
echo Visibility options:
echo   1. Public
echo   2. Private ^(default^)
set /p "VISIBILITY_CHOICE=Choose visibility [1 or 2] [2]: "
if "!VISIBILITY_CHOICE!"=="1" (
    set "VISIBILITY=--public"
    set "VISIBILITY_NAME=Public"
) else (
    set "VISIBILITY=--private"
    set "VISIBILITY_NAME=Private"
)

echo.
set /p "ADD_README=Add README.md? [y/n] [y]: "
if "!ADD_README!"=="" set "ADD_README=y"

echo.
set /p "ADD_GITIGNORE=Add .gitignore template ^(e.g. Python, Node, VisualStudio^) or leave blank: "

echo.
echo ========================================
echo Summary
echo ========================================
echo Repository name: !REPO_NAME!
if not "!DESCRIPTION!"=="" echo Description: !DESCRIPTION!
echo Visibility: !VISIBILITY_NAME!
if /i "!ADD_README!"=="y" echo README: yes
if not "!ADD_GITIGNORE!"=="" echo .gitignore: !ADD_GITIGNORE!
echo ========================================
echo.

set /p "CONFIRM=Create repository? [y/n] [y]: "
if "!CONFIRM!"=="" set "CONFIRM=y"
if /i not "!CONFIRM!"=="y" (
    echo Cancelled.
    exit /b 0
)

if not exist ".git" (
    echo.
    echo Initializing git repository...
    git init
    if errorlevel 1 (
        echo Failed to initialize git repository.
        exit /b 1
    )
)

if /i "!ADD_README!"=="y" (
    if not exist "README.md" (
        echo Creating README.md...
        > README.md (
            echo # !REPO_NAME!
            echo.
            if not "!DESCRIPTION!"=="" echo !DESCRIPTION!
        )
    )
)

if not "!ADD_GITIGNORE!"=="" (
    echo Creating .gitignore from template !ADD_GITIGNORE!...
    gh api "gitignore/templates/!ADD_GITIGNORE!" --jq .source > .gitignore 2>nul
    if errorlevel 1 (
        echo Warning: Could not fetch that .gitignore template. Skipping.
        if exist ".gitignore" del ".gitignore" >nul 2>nul
    )
)

git add . >nul 2>nul
git diff --cached --quiet >nul 2>nul
if errorlevel 1 (
    echo Creating initial commit...
    git commit -m "Initial commit"
)

echo.
echo Creating GitHub repository...
if not "!DESCRIPTION!"=="" (
    gh repo create "!REPO_NAME!" !VISIBILITY! --source=. --remote=origin --push --description "!DESCRIPTION!"
) else (
    gh repo create "!REPO_NAME!" !VISIBILITY! --source=. --remote=origin --push
)

if errorlevel 1 (
    echo.
    echo Failed to create repository.
    exit /b 1
)

echo.
echo Success! Repository created and pushed.
gh repo view --web
exit /b 0

:config_repo
call :require_gh
if errorlevel 1 exit /b 1

echo ========================================
echo Configure GitHub Repository
echo ========================================
echo.

git rev-parse --git-dir >nul 2>nul
if errorlevel 1 (
    echo Error: Not in a git repository.
    echo Please run this command from within a git repository.
    exit /b 1
)

gh repo view >nul 2>nul
if errorlevel 1 (
    echo Error: Could not identify the current GitHub repository.
    echo Make sure this folder has a GitHub remote configured.
    exit /b 1
)

echo Current repository information:
echo.
echo Repository:
gh repo view --json nameWithOwner --jq .nameWithOwner
echo Visibility:
gh repo view --json isPrivate --jq .isPrivate
echo Description:
gh repo view --json description --jq ".description // \"(none)\""
echo URL:
gh repo view --json url --jq .url
echo.
echo What would you like to configure?
echo   1. Change visibility
echo   2. Update description
echo   3. Add topics/tags
echo   4. All of the above
set /p "CONFIG_CHOICE=Choose option [1-4]: "

if "!CONFIG_CHOICE!"=="1" (
    call :change_visibility
    goto config_done
)
if "!CONFIG_CHOICE!"=="2" (
    call :update_description
    goto config_done
)
if "!CONFIG_CHOICE!"=="3" (
    call :add_topics
    goto config_done
)
if "!CONFIG_CHOICE!"=="4" (
    call :change_visibility
    call :update_description
    call :add_topics
    goto config_done
)

echo Invalid choice.
exit /b 1

:change_visibility
echo.
echo Change visibility:
echo   1. Public
echo   2. Private ^(default^)
set /p "NEW_VISIBILITY=Choose visibility [1 or 2] [2]: "
if "!NEW_VISIBILITY!"=="1" (
    echo Changing to public...
    gh repo edit --visibility public --accept-visibility-change-consequences
) else (
    echo Changing to private...
    gh repo edit --visibility private --accept-visibility-change-consequences
)
goto :eof

:update_description
echo.
set /p "NEW_DESC=New description [leave blank to skip]: "
if "!NEW_DESC!"=="" (
    echo Skipping description update.
) else (
    echo Updating description...
    gh repo edit --description "!NEW_DESC!"
)
goto :eof

:add_topics
echo.
echo Enter topics separated by commas.
set /p "NEW_TOPICS=Topics [leave blank to skip]: "
if "!NEW_TOPICS!"=="" (
    echo Skipping topics update.
    goto :eof
)
set "TOPIC_LIST=!NEW_TOPICS:,= !"
echo Adding topics...
for %%T in (!TOPIC_LIST!) do gh repo edit --add-topic %%~T
goto :eof

:config_done
echo.
echo ========================================
echo Configuration step complete.
echo ========================================
echo Repository URL:
gh repo view --json url --jq .url
exit /b 0

:show_help
echo Usage: github [command]
echo.
echo Commands:
echo   init      Initialize a new GitHub repository in the current directory
echo   create    Alias for init
echo   config    Configure the current GitHub repository
echo   help      Show this help message
echo.
echo Examples:
echo   github init
echo   github config
exit /b 0
