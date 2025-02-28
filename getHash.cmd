@echo off
C:\windows\system32\WindowsPowerShell\v1.0\powerShell.exe -ExecutionPolicy Bypass -File Get-WindowsAutoPilotInfo.ps1 -outputFile device.csv %*
echo Created the device hash in the current folder.
echo Look for a file with a .csv extension.