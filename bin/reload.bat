@echo off
setlocal EnableExtensions

if not defined CMDER_ROOT if exist "%USERPROFILE%\Desktop\cmder\vendor\init.bat" set "CMDER_ROOT=%USERPROFILE%\Desktop\cmder"
if not defined CMDER_ROOT if exist "%USERPROFILE%\cmder\vendor\init.bat" set "CMDER_ROOT=%USERPROFILE%\cmder"
if not defined CMDER_ROOT if exist "C:\tools\cmder\vendor\init.bat" set "CMDER_ROOT=C:\tools\cmder"
if not defined CMDER_ROOT if exist "%LOCALAPPDATA%\cmder\vendor\init.bat" set "CMDER_ROOT=%LOCALAPPDATA%\cmder"

if not defined CMDER_ROOT (
    echo CMDER_ROOT is not set. Run: tools-setup commander
    exit /b 1
)

call "%CMDER_ROOT%\vendor\init.bat"
