@echo off
pwsh\pwsh.exe -ExecutionPolicy Bypass -File Register-Device.ps1 -UpdateOnly -NoSignatureVerify -NoHashVerify %*
