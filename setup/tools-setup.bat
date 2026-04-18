@echo off
setlocal EnableExtensions

set "ACTION=%~1"
if "%ACTION%"=="" goto :catalog
if /i "%ACTION%"=="help" goto :catalog
if /i "%ACTION%"=="list" goto :catalog
if /i "%ACTION%"=="catalog" goto :catalog
if /i "%ACTION%"=="status" goto :status
if /i "%ACTION%"=="all" goto :all
if /i "%ACTION%"=="spotify" goto :spotify
if /i "%ACTION%"=="vscode" goto :vscode
if /i "%ACTION%"=="nvm-node" goto :nvmnode
if /i "%ACTION%"=="node" goto :nvmnode
if /i "%ACTION%"=="angular" goto :angular
if /i "%ACTION%"=="podman" goto :podman
if /i "%ACTION%"=="godot" goto :godot
if /i "%ACTION%"=="keyboard" goto :keyboard

echo Unknown action: %ACTION%
echo.
goto :catalog

:catalog
echo Tools setup catalog
echo.
echo Available items:
echo   spotify   - Install or verify Spotify for the command-line media helper
echo   keyboard  - Set up quick switching for Portuguese and English International
echo   vscode    - Install Visual Studio Code and the code command-line launcher
echo   nvm-node  - Install NVM for Windows, latest Node.js, and npm
echo   angular   - Install Angular CLI and confirm its version
echo   podman    - Install Podman as the open-source Docker-compatible alternative
echo   godot     - Install Godot Engine
echo   all       - Run the full setup sequence
echo   status    - Show currently detected versions
echo.
echo Recommended order:
echo   1. tools-setup keyboard
echo   2. tools-setup spotify
echo   3. tools-setup vscode
echo   4. tools-setup nvm-node
echo   5. tools-setup angular
echo   6. tools-setup podman
echo   7. tools-setup godot
echo.
echo Examples:
echo   tools-setup vscode
echo   tools-setup all
echo   tools-setup status
echo.
echo Note: machine-level installs may open a clearly warned Administrator window when needed.
exit /b 0

:status
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-spotify.ps1" -Status
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-keyboard-language.ps1" -Status
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-vscode.ps1" -Status
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-nvm-node.ps1" -Status
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-angular-cli.ps1" -Status
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-podman.ps1" -Status
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-godot.ps1" -Status
exit /b %errorlevel%

:all
call :spotify
if errorlevel 1 exit /b 1
call :vscode
if errorlevel 1 exit /b 1
call :nvmnode
if errorlevel 1 exit /b 1
call :angular
if errorlevel 1 exit /b 1
call :podman
if errorlevel 1 exit /b 1
call :godot
if errorlevel 1 exit /b 1
echo.
echo All requested setup steps finished.
exit /b 0

:vscode
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-vscode.ps1"
exit /b %errorlevel%

:spotify
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-spotify.ps1"
exit /b %errorlevel%

:keyboard
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-keyboard-language.ps1"
exit /b %errorlevel%

:nvmnode
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-nvm-node.ps1"
exit /b %errorlevel%

:angular
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-angular-cli.ps1"
exit /b %errorlevel%

:podman
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-podman.ps1"
exit /b %errorlevel%

:godot
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-godot.ps1"
exit /b %errorlevel%
