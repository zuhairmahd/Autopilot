@echo off
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -GetDeviceHash
-Check %*
