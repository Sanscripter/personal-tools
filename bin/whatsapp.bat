@echo off
setlocal EnableExtensions
set "WHATSAPP_RAW_ARGS=%*"

set "WHATSAPP_SCRIPT=%~dp0..\scripts\web\whatsapp-control.ps1"
if not exist "%WHATSAPP_SCRIPT%" (
    echo WhatsApp helper script was not found.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%WHATSAPP_SCRIPT%"
exit /b %errorlevel%
