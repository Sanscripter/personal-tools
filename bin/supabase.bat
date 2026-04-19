@echo off
setlocal EnableExtensions

set "SUPABASE_EXE=%LOCALAPPDATA%\Programs\Supabase\bin\supabase.exe"

if exist "%SUPABASE_EXE%" (
    "%SUPABASE_EXE%" %*
    exit /b %errorlevel%
)

call "%~dp0install-supabase.bat" >nul
if exist "%SUPABASE_EXE%" (
    "%SUPABASE_EXE%" %*
    exit /b %errorlevel%
)

echo Supabase CLI is not installed yet.
echo Run: tools-setup supabase
exit /b 1
