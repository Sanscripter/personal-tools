@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\setup\installers\install-cmder.ps1" %*
