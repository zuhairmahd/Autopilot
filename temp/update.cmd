@echo off
REM VERSION 2.2.0
REM This script is used to update the script components.
REM It uses PowerShell to execute the Register-Device.ps1 script with the specified parameters.
REM It is part of the Device Registration process for Windows Autopilot.
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -UpdateOnly %*
