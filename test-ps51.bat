@echo off
cd /d c:\Users\zuhai\code\Autopilot
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\main.ps1" -showVersion
echo.
echo Exit code: %ERRORLEVEL%
pause
