@echo off
rem VERSION 1.0.0
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -Check %*
