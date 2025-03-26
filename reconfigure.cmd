@echo off
rem VERSION 2.2.0
rem This script is used to reconfigure the derfault parameters of the script.
rem It uses PowerShell to execute the Register-Device.ps1 script with the provided arguments.
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -Reconfigure %*
