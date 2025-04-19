@echo off
rem VERSION 2.2.0
REM This script is used to redeploy a device with the specified parameters.
REM It uses PowerShell to execute the Register-Device.ps1 script with the provided arguments.
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Redeploy-Device.ps1 -SerialNumber %*
