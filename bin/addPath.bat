@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "TARGET_DIR=%~dp0"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"
set "WINDOWS_APPS=%LOCALAPPDATA%\Microsoft\WindowsApps"
set "WINGET_LINKS=%LOCALAPPDATA%\Microsoft\WinGet\Links"

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$targets = New-Object System.Collections.Generic.List[string]; $targets.Add($env:TARGET_DIR.TrimEnd('\')) | Out-Null; if (Test-Path $env:WINDOWS_APPS) { $targets.Add($env:WINDOWS_APPS.TrimEnd('\')) | Out-Null }; if (Test-Path $env:WINGET_LINKS) { $targets.Add($env:WINGET_LINKS.TrimEnd('\')) | Out-Null }; $userPath = [Environment]::GetEnvironmentVariable('Path','User'); $parts = @(); if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_.Trim() -ne '' } }; $added = New-Object System.Collections.Generic.List[string]; foreach ($target in ($targets | Select-Object -Unique)) { $exists = $parts | Where-Object { $_.TrimEnd('\') -ieq $target } | Select-Object -First 1; if (-not $exists) { $parts += $target; $added.Add($target) | Out-Null } }; [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User'); if ($added.Count -gt 0) { 'ADDED:' + ($added -join '|') } else { 'EXISTS' }"`) do set "RESULT=%%I"

echo ;!PATH!; | findstr /i /c:";%TARGET_DIR%;" >nul
if errorlevel 1 set "PATH=!PATH!;%TARGET_DIR%"

if exist "%WINDOWS_APPS%" (
    echo ;!PATH!; | findstr /i /c:";%WINDOWS_APPS%;" >nul
    if errorlevel 1 set "PATH=!PATH!;%WINDOWS_APPS%"
)

if exist "%WINGET_LINKS%" (
    echo ;!PATH!; | findstr /i /c:";%WINGET_LINKS%;" >nul
    if errorlevel 1 set "PATH=!PATH!;%WINGET_LINKS%"
)

set "UPDATED_PATH=!PATH!"

if /i "!RESULT:~0,6!"=="ADDED:" (
    echo Updated your user PATH with repo and Windows app launcher entries.
) else (
    echo PATH entries were already present.
)

echo Commands are available in this cmd session now and in new terminals.
endlocal & set "PATH=%UPDATED_PATH%"
exit /b 0
