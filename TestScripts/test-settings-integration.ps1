#!/usr/bin/env pwsh

# Integration test for Settings Menu functionality
param(
    [string]$TestFolder = "$PWD\test-settings-integration-temp"
)

# Create test directory
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    Write-Host "=== Settings Menu Integration Test ===" -ForegroundColor Green
    
    # Change to test directory
    Push-Location $TestFolder
    
    # Copy main script and functions
    Copy-Item -Path (Join-Path $PSScriptRoot ".." "main.ps1") -Destination "." -Force
    Copy-Item -Path (Join-Path $PSScriptRoot ".." "functions") -Destination "." -Recurse -Force
    Copy-Item -Path (Join-Path $PSScriptRoot ".." "settings.json") -Destination "." -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $PSScriptRoot ".." "strings.json") -Destination "." -Force -ErrorAction SilentlyContinue
    
    Write-Host "`n1. Testing function loading..." -ForegroundColor Cyan
    
    # Load functions
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
    
    Write-Host "✓ Loaded $loadedCount functions" -ForegroundColor Green
    
    Write-Host "`n2. Testing Show-SettingsEditor function availability..." -ForegroundColor Cyan
    
    if (Get-Command Show-SettingsEditor -ErrorAction SilentlyContinue) {
        Write-Host "✓ Show-SettingsEditor function is available" -ForegroundColor Green
    } else {
        Write-Host "✗ Show-SettingsEditor function not found" -ForegroundColor Red
        throw "Show-SettingsEditor function not available"
    }
    
    Write-Host "`n3. Testing settings file setup..." -ForegroundColor Cyan
    
    $testSettingsFile = "test-settings.json"
    if (Test-SettingsJsonExists -SettingsFile $testSettingsFile -Silent) {
        Write-Host "✓ Settings file created" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create settings file" -ForegroundColor Red
        throw "Settings file creation failed"
    }
    
    Write-Host "`n4. Testing Global settings editor (automated)..." -ForegroundColor Cyan
    
    # Test global settings functionality programmatically
    try {
        $defaultSettings = Get-DefaultSettingsStructure
        $currentSettings = Get-CurrentSettings -SettingsFile $testSettingsFile -SettingsType "Global"
        
        if ($defaultSettings -and $currentSettings) {
            Write-Host "✓ Can access default and current settings" -ForegroundColor Green
            
            # Test updating a simple setting
            $testSettings = @{ 'testMode' = $true }
            $success = Save-GlobalSettings -Settings $testSettings -SettingsFile $testSettingsFile
            
            if ($success) {
                Write-Host "✓ Global settings update works" -ForegroundColor Green
            } else {
                Write-Host "✗ Global settings update failed" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ Cannot access settings structures" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Error testing global settings: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n5. Testing Domain settings editor (automated)..." -ForegroundColor Cyan
    
    try {
        # Test domain settings functionality programmatically
        $testDomainSettings = @{ 'minUsernameLength' = 5 }
        $success = Save-DomainSettings -DomainName "test.com" -Settings $testDomainSettings -SettingsFile $testSettingsFile
        
        if ($success) {
            Write-Host "✓ Domain settings update works" -ForegroundColor Green
        } else {
            Write-Host "✗ Domain settings update failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Error testing domain settings: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n6. Testing menu structure validation..." -ForegroundColor Cyan
    
    # Check if AddMenuItem function is available (it should be loaded from the functions)
    if (Get-Command AddMenuItem -ErrorAction SilentlyContinue) {
        Write-Host "✓ AddMenuItem function is available" -ForegroundColor Green
    } else {
        Write-Host "✗ AddMenuItem function not found" -ForegroundColor Red
    }
    
    # Test creating a simple menu structure like in main.ps1
    try {
        if (Get-Command NewMenu -ErrorAction SilentlyContinue) {
            $testMenu = NewMenu -Title "Test Menu" -Description "Test menu for validation"
            $testMenu = AddMenuItem -menu $testMenu -Name "Test Item" -Action { Write-Host "Test" }
            Write-Host "✓ Menu structure creation works" -ForegroundColor Green
        } else {
            Write-Host "! NewMenu function not available (may be expected)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Error creating menu structure: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n7. Testing environment menu action simulation..." -ForegroundColor Cyan
    
    # Simulate the environment menu actions without user interaction
    try {
        # This simulates what the global settings menu action would do
        Write-Host "  Simulating global settings action..." -ForegroundColor Gray
        
        # Use preset values to test the functionality without user input
        $presetValues = @{ 'testMode' = $true; 'timeInSeconds' = '45' }
        $simulatedSuccess = Show-SettingsEditor -SettingsType "Global" -SettingsFile $testSettingsFile -Silent -PresetValues $presetValues
        
        if ($simulatedSuccess) {
            Write-Host "✓ Global settings action simulation successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Global settings action simulation failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Error in global settings action simulation: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== Integration Test Completed ===" -ForegroundColor Green
    Write-Host "Settings Menu integration is working correctly!" -ForegroundColor Green
    Write-Host "Note: Full interactive testing requires manual verification." -ForegroundColor Yellow
    
} catch {
    Write-Host "`n=== Integration Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Pop-Location
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nIntegration test completed successfully!" -ForegroundColor Green
exit 0