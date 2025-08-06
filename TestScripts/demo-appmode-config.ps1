# Demo App Mode Configuration
Write-Host "Demo: App Mode Configuration" -ForegroundColor Green

# Load required functions
$functionPath = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions"
. "$functionPath\Get-AppModeConfigurationFromUser.ps1"

Write-Host "`nTesting silent mode..." -ForegroundColor Cyan
$silentResult = Get-AppModeConfigurationFromUser -Silent
if ($silentResult) {
    Write-Host "Silent mode result: $($silentResult.appMode)" -ForegroundColor Green
} else {
    Write-Host "Silent mode failed" -ForegroundColor Red
}

Write-Host "`nDemo completed!" -ForegroundColor Green