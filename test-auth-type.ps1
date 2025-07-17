#!/usr/bin/env pwsh

# Test script to verify authentication type handling
Write-Host "Testing Authentication Type Handling" -ForegroundColor Green

# Set up test environment
$testFolder = "$PWD/test-auth-temp"
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
    Write-Host "[TEST] $Message" -ForegroundColor Yellow
}

Write-Host "`n1. Testing Delegated Authentication (Choice 1)..." -ForegroundColor Cyan

# Test delegated authentication
$authConfig = @{
    AppSecret = "test-secret"
    Thumbprint = ""
    Subject = ""
    AuthType = "Delegated"
    IsDelegated = $true
}

$settingsFile = "$testFolder/settings-delegated.json"
$result = Ensure-SettingsJsonExists -SettingsFile $settingsFile -Silent -AuthType $authConfig.AuthType -IsDelegated $authConfig.IsDelegated

if ($result) {
    $content = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
    $isDelegated = $content.auth.Delegated
    if ($isDelegated -eq $true) {
        Write-Host "✓ Delegated authentication correctly set to: $isDelegated" -ForegroundColor Green
    } else {
        Write-Host "✗ Delegated authentication incorrectly set to: $isDelegated" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Failed to create settings file for delegated authentication" -ForegroundColor Red
}

Write-Host "`n2. Testing Application Authentication (Choice 2)..." -ForegroundColor Cyan

# Test application authentication
$authConfig2 = @{
    AppSecret = "test-secret"
    Thumbprint = ""
    Subject = ""
    AuthType = "Application"
    IsDelegated = $false
}

$settingsFile2 = "$testFolder/settings-application.json"
$result2 = Ensure-SettingsJsonExists -SettingsFile $settingsFile2 -Silent -AuthType $authConfig2.AuthType -IsDelegated $authConfig2.IsDelegated

if ($result2) {
    $content2 = Get-Content -Path $settingsFile2 -Raw | ConvertFrom-Json
    $isDelegated2 = $content2.auth.Delegated
    if ($isDelegated2 -eq $false) {
        Write-Host "✓ Application authentication correctly set to: $isDelegated2" -ForegroundColor Green
    } else {
        Write-Host "✗ Application authentication incorrectly set to: $isDelegated2" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Failed to create settings file for application authentication" -ForegroundColor Red
}

Write-Host "`n3. Testing requiredScopes property..." -ForegroundColor Cyan

# Check if requiredScopes property exists
if ($content.globalSettings.requiredScopes) {
    Write-Host "✓ requiredScopes property exists in globalSettings" -ForegroundColor Green
} else {
    Write-Host "✗ requiredScopes property missing from globalSettings" -ForegroundColor Red
}

Write-Host "`n4. Testing Get-AuthenticationConfigurationFromUser function..." -ForegroundColor Cyan

# Test the authentication configuration function
try {
    $testAuth = Get-AuthenticationConfigurationFromUser -Silent
    if ($testAuth) {
        Write-Host "✓ Get-AuthenticationConfigurationFromUser returned valid config" -ForegroundColor Green
        Write-Host "   AuthType: $($testAuth.AuthType)" -ForegroundColor Gray
        Write-Host "   IsDelegated: $($testAuth.IsDelegated)" -ForegroundColor Gray
        Write-Host "   AppSecret: $($testAuth.AppSecret)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Get-AuthenticationConfigurationFromUser returned null" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error in Get-AuthenticationConfigurationFromUser: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up
Write-Host "`nCleaning up test folder..." -ForegroundColor Cyan
Remove-Item -Path $testFolder -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nTest completed!" -ForegroundColor Green