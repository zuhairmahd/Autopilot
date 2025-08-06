# Debug script to check function output
. "$PSScriptRoot\test-helper.ps1"

# Load all functions
$testContext = Start-UnifiedTest -TestName "Debug" -TestFolder "$PWD\debug-temp"

# Load the function
$functionPath = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Get-AppModeConfigurationFromUser.ps1"
. $functionPath

# Test the function
$result = Get-AppModeConfigurationFromUser -Silent

Write-Host "Result type: $($result.GetType().FullName)" -ForegroundColor Yellow
Write-Host "Is hashtable: $($result -is [hashtable])" -ForegroundColor Yellow
Write-Host "Properties:" -ForegroundColor Yellow
$result.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor Cyan }

Write-Host "`nKeys (if hashtable):" -ForegroundColor Yellow
if ($result -is [hashtable]) {
    $result.Keys | ForEach-Object { Write-Host "  $_`: $($result[$_])" -ForegroundColor Cyan }
}

Complete-UnifiedTest $testContext