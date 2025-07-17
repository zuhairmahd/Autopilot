#!/usr/bin/env pwsh

# Debug script to check settings file creation
Write-Host "Debug: Settings File Creation" -ForegroundColor Green

# Set up test environment
$testFolder = "$PWD/debug-auth-temp"
if (Test-Path $testFolder) {
    Remove-Item -Path $testFolder -Recurse -Force
}
New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

# Load functions
. "$PWD/functions/FirstRunWizardFunctions.ps1"
. "$PWD/functions/EncryptionFunctions.ps1"
. "$PWD/functions/SettingsHelperFunctions.ps1"

# Test function definition
function Write-SafeLog {
    param([string]$Message, [string]$LogLevel)
    Write-Host "[DEBUG] $Message" -ForegroundColor Yellow
}

Write-Host "`nTesting settings creation with explicit parameters..." -ForegroundColor Cyan

$settingsFile = "$testFolder/settings-test.json"
$result = Ensure-SettingsJsonExists -SettingsFile $settingsFile -Silent -AuthType "Application" -IsDelegated $false

if ($result) {
    Write-Host "✓ Settings file created successfully" -ForegroundColor Green
    
    # Read and display the raw content
    $rawContent = Get-Content -Path $settingsFile -Raw
    Write-Host "`nRaw content:" -ForegroundColor White
    Write-Host $rawContent -ForegroundColor Gray
    
    # Parse and display the structure
    $parsedContent = ConvertFrom-Json $rawContent
    Write-Host "`nParsed auth section:" -ForegroundColor White
    Write-Host "Delegated: $($parsedContent.auth.Delegated)" -ForegroundColor Gray
    Write-Host "Type: $($parsedContent.auth.Delegated.GetType().Name)" -ForegroundColor Gray
    
    # Check if requiredScopes exists
    if ($parsedContent.globalSettings.requiredScopes) {
        Write-Host "✓ requiredScopes property exists" -ForegroundColor Green
    } else {
        Write-Host "✗ requiredScopes property missing" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Failed to create settings file" -ForegroundColor Red
}

# Clean up
Write-Host "`nCleaning up test folder..." -ForegroundColor Cyan
Remove-Item -Path $testFolder -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nDebug completed!" -ForegroundColor Green