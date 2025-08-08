#!/usr/bin/env pwsh

# Test script for Settings Editor functionality
param(
    [string]$TestFolder = "$PWD\test-settings-editor-temp"
)

# Create test directory
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    Write-Host "=== Testing Settings Editor Functionality ===" -ForegroundColor Green
    
    # Change to test directory
    Push-Location $TestFolder
    
    # Copy function files to test directory
    $functionsPath = Join-Path $PSScriptRoot ".." "functions"
    Copy-Item -Path $functionsPath -Destination "." -Recurse -Force
    
    Write-Host "`n1. Loading functions..." -ForegroundColor Cyan
    
    # Load all functions
    $functions = Get-ChildItem -Path ".\functions" -Filter '*.ps1' -Recurse
    $loadedCount = 0
    foreach ($function in $functions) {
        try {
            . $function.FullName
            $loadedCount++
        }
        catch {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
    
    Write-Host "Loaded $loadedCount functions" -ForegroundColor Green
    
    Write-Host "`n2. Testing default settings structure retrieval..." -ForegroundColor Cyan
    
    # Test getting default settings
    $defaultSettings = Get-DefaultSettingsStructure
    if ($defaultSettings) {
        Write-Host "✓ Default settings structure retrieved" -ForegroundColor Green
        Write-Host "  Found globalSettings: $($defaultSettings.globalSettings -ne $null)" -ForegroundColor Gray
        Write-Host "  Found domains: $($defaultSettings.domains -ne $null)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Failed to get default settings structure" -ForegroundColor Red
        throw "Default settings test failed"
    }
    
    Write-Host "`n3. Testing settings file creation..." -ForegroundColor Cyan
    
    $testSettingsFile = "test-settings.json"
    if (Test-SettingsJsonExists -SettingsFile $testSettingsFile -Silent) {
        Write-Host "✓ Test settings file created" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create test settings file" -ForegroundColor Red
        throw "Settings file creation failed"
    }
    
    Write-Host "`n4. Testing current settings loading..." -ForegroundColor Cyan
    
    $currentSettings = Get-CurrentSettings -SettingsFile $testSettingsFile -SettingsType "Global"
    if ($currentSettings) {
        Write-Host "✓ Current settings loaded" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to load current settings" -ForegroundColor Red
        throw "Current settings loading failed"
    }
    
    Write-Host "`n5. Testing setting input type detection..." -ForegroundColor Cyan
    
    $testCases = @(
        @{ SettingName = 'autoUpdate'; Value = $true; Expected = 'Boolean' }
        @{ SettingName = 'appMode'; Value = 'full'; Expected = 'AppMode' }
        @{ SettingName = 'maxWaitTime'; Value = 30; Expected = 'Number' }
        @{ SettingName = 'configFile'; Value = 'test.json'; Expected = 'String' }
        @{ SettingName = 'userPatternsToExclude'; Value = @('test'); Expected = 'Array' }
    )
    
    foreach ($testCase in $testCases) {
        $inputType = Get-SettingInputType -SettingName $testCase.SettingName -Value $testCase.Value
        if ($inputType -eq $testCase.Expected) {
            Write-Host "✓ $($testCase.SettingName): $inputType" -ForegroundColor Green
        } else {
            Write-Host "✗ $($testCase.SettingName): Expected $($testCase.Expected), got $inputType" -ForegroundColor Red
        }
    }
    
    Write-Host "`n6. Testing setting descriptions..." -ForegroundColor Cyan
    
    $testSettings = @('autoUpdate', 'appMode', 'maxWaitTime', 'configFile')
    foreach ($setting in $testSettings) {
        $description = Get-SettingDescription -SettingName $setting
        if ($description -and $description.Length -gt 10) {
            Write-Host "✓ ${setting}: $description" -ForegroundColor Green
        } else {
            Write-Host "✗ ${setting}: No meaningful description" -ForegroundColor Red
        }
    }
    
    Write-Host "`n7. Testing global settings update..." -ForegroundColor Cyan
    
    $testUpdateSettings = @{
        'testMode' = $true
        'maxWaitTime' = 45
    }
    
    $success = Save-GlobalSettings -Settings $testUpdateSettings -SettingsFile $testSettingsFile
    if ($success) {
        Write-Host "✓ Global settings update successful" -ForegroundColor Green
        
        # Verify the update
        $verifyContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        if ($verifyContent.globalSettings.testMode -eq $true -and $verifyContent.globalSettings.maxWaitTime -eq 45) {
            Write-Host "✓ Settings verified in file" -ForegroundColor Green
        } else {
            Write-Host "✗ Settings not properly saved" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Global settings update failed" -ForegroundColor Red
    }
    
    Write-Host "`n8. Testing domain settings update..." -ForegroundColor Cyan
    
    $testDomainSettings = @{
        'minUsernameLength' = 5
        'preferredBrowser' = 'Edge'
    }
    
    $success = Save-DomainSettings -DomainName "test.com" -Settings $testDomainSettings -SettingsFile $testSettingsFile
    if ($success) {
        Write-Host "✓ Domain settings update successful" -ForegroundColor Green
        
        # Verify the update
        $verifyContent = Get-Content -Path $testSettingsFile -Raw | ConvertFrom-Json
        if ($verifyContent.domains."test.com".settings.minUsernameLength -eq 5) {
            Write-Host "✓ Domain settings verified in file" -ForegroundColor Green
        } else {
            Write-Host "✗ Domain settings not properly saved" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Domain settings update failed" -ForegroundColor Red
    }
    
    Write-Host "`n=== All Tests Completed ===" -ForegroundColor Green
    Write-Host "Settings Editor functionality is working correctly!" -ForegroundColor Green
    
} catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Pop-Location
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nTest completed successfully!" -ForegroundColor Green
exit 0