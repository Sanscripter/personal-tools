@echo off
set "TARGET_DIR=%~dp0"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$target = $env:TARGET_DIR.TrimEnd('\\'); $userPath = [Environment]::GetEnvironmentVariable('Path','User'); $parts = @(); if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_.Trim() -ne '' } }; $exists = $parts | Where-Object { $_.TrimEnd('\\') -ieq $target } | Select-Object -First 1; if (-not $exists) { $parts += $target; [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User'); 'ADDED' } else { 'EXISTS' }"`) do set "RESULT=%%I"

echo ;%PATH%; | findstr /i /c:";%TARGET_DIR%;" >nul
if errorlevel 1 set "PATH=%PATH%;%TARGET_DIR%"

if /i "%RESULT%"=="ADDED" (
    echo Added %TARGET_DIR% to your user PATH.
) else (
    echo %TARGET_DIR% is already in your user PATH.
)

echo Commands are available in this cmd session now and in new terminals.
exit /b 0
