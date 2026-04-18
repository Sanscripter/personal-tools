@echo off
if not defined CMDER_ROOT (
    echo CMDER_ROOT is not set.
    exit /b 1
)
call "%CMDER_ROOT%\vendor\init.bat"
