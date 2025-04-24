@echo off
REM VERSION 2.3.0
REM This script is used to update the script components and skips the integrity and signature checks.
REM It uses PowerShell to execute the Register-Device.ps1 script with the specified parameters.
REM It is part of the Device Registration process for Windows Autopilot.
C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe Register-Device.ps1 -UpdateOnly -Release main -NoHashVerify -NoSignatureVerify -NoAdminCheck -NoModuleCheck
