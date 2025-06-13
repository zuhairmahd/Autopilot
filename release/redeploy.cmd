@echo off
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -NoUpdateCheck -NoSignatureVerify -NoHashVerify -redeploy %*
