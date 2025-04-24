@echo off
REM VERSION 2.3.0
REM This script is used to get the device hash with the specified parameters.
REM It uses PowerShell to execute the Register-Device.ps1 script with the provided arguments.
REM This script is part of the Device Registration process for Windows Autopilot.
C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -GetDeviceHash %*
