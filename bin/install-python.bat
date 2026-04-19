@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\setup\installers\install-python.ps1" %*
