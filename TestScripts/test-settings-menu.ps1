# Test script for Settings Menu AutoUpdate functionality
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-settings-menu-temp"
)

Write-Host "Testing Settings Menu AutoUpdate Integration" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Set up test environment
$LogFile = "$TestFolder\test.log"
$settingsFile = "$TestFolder\settings.json"

try {
    # Load the functions
    Write-TestSection "`n1. Loading functions..."
    
    # Load all functions from the functions directory
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-Host "[PASS] Functions loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Functions folder not found: $functionsFolder" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n2. Creating test settings.json file..." -ForegroundColor Cyan
    
    # Create a test settings file
    $testSettings = @{
        "description" = "Test configuration for settings menu"
        "version" = "1.0.0.0"
        "globalSettings" = @{
            "autoUpdate" = $true
            "configFile" = ".\\.secrets\\config.json"
            "maxWaitTime" = "30"
            "timeInSeconds" = "60"
            "appMode" = "full"
            "testMode" = $true
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Encoding UTF8
    Write-Host "[PASS] Test settings file created" -ForegroundColor Green
    
    Write-Host "`n3. Testing Update-GlobalSetting function..." -ForegroundColor Cyan
    
    # Test updating autoUpdate setting to false
    $result = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $false
    
    if ($result) {
        Write-Host "[PASS] Update-GlobalSetting works for autoUpdate = false" -ForegroundColor Green
        
        # Verify the setting was actually changed
        $updatedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($updatedSettings.globalSettings.autoUpdate -eq $false) {
            Write-Host "[PASS] Settings file correctly updated with autoUpdate = false" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Settings file not correctly updated" -ForegroundColor Red
            throw "Settings verification failed"
        }
    } else {
        Write-Host "[FAIL] Update-GlobalSetting failed for autoUpdate = false" -ForegroundColor Red
        throw "Update-GlobalSetting test failed"
    }
    
    Write-Host "`n4. Testing Update-GlobalSetting function with true value..." -ForegroundColor Cyan
    
    # Test updating autoUpdate setting back to true
    $result = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $true
    
    if ($result) {
        Write-Host "[PASS] Update-GlobalSetting works for autoUpdate = true" -ForegroundColor Green
        
        # Verify the setting was actually changed back
        $updatedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($updatedSettings.globalSettings.autoUpdate -eq $true) {
            Write-Host "[PASS] Settings file correctly updated with autoUpdate = true" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Settings file not correctly updated back to true" -ForegroundColor Red
            throw "Settings verification failed"
        }
    } else {
        Write-Host "[FAIL] Update-GlobalSetting failed for autoUpdate = true" -ForegroundColor Red
        throw "Update-GlobalSetting test failed"
    }
    
    Write-Host "`n5. Testing settings toggle logic..." -ForegroundColor Cyan
    
    # Simulate the settings menu toggle logic
    $settings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
    $originalValue = $settings.globalSettings.autoUpdate
    Write-Host "  Original autoUpdate value: $originalValue" -ForegroundColor White
    
    # Toggle the value (similar to what the settings menu does)
    $newValue = -not $originalValue
    Write-Host "  Toggled autoUpdate value: $newValue" -ForegroundColor White
    
    # Update using the helper function
    $updateResult = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $newValue
    
    if ($updateResult) {
        Write-Host "[PASS] Settings toggle logic works correctly" -ForegroundColor Green
        
        # Verify the final state
        $finalSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($finalSettings.globalSettings.autoUpdate -eq $newValue) {
            Write-Host "[PASS] Final settings verification passed" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Final settings verification failed" -ForegroundColor Red
            throw "Final verification failed"
        }
    } else {
        Write-Host "[FAIL] Settings toggle logic failed" -ForegroundColor Red
        throw "Toggle logic test failed"
    }
    
    Write-Host "`n6. Testing backup file cleanup simulation..." -ForegroundColor Cyan
    
    # Create some mock backup files to test cleanup logic
    $backupFiles = @(
        "$TestFolder\settings.json.backup.20231201",
        "$TestFolder\config.json.backup.20231202",
        "$TestFolder\test.backup.20231203"
    )
    
    foreach ($backupFile in $backupFiles) {
        "test backup content" | Set-Content -Path $backupFile
    }
    
    Write-Host "  Created $($backupFiles.Count) mock backup files" -ForegroundColor White
    
    # Test the backup cleanup logic (simulate what's in main.ps1)
    $foundBackups = Get-ChildItem "$TestFolder\*.backup.*" -ErrorAction SilentlyContinue
    if ($foundBackups.Count -eq $backupFiles.Count) {
        Write-Host "[PASS] Backup files detected correctly ($($foundBackups.Count) files)" -ForegroundColor Green
        
        # Clean up the backup files
        foreach ($backup in $foundBackups) {
            Remove-Item -Path $backup.FullName -Force
        }
        
        # Verify cleanup
        $remainingBackups = Get-ChildItem "$TestFolder\*.backup.*" -ErrorAction SilentlyContinue
        if ($remainingBackups.Count -eq 0) {
            Write-Host "[PASS] Backup file cleanup works correctly" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Backup file cleanup failed - $($remainingBackups.Count) files remaining" -ForegroundColor Red
        }
    } else {
        Write-Host "[FAIL] Backup file detection failed" -ForegroundColor Red
    }
    
    Write-Host "`n✅ All Settings Menu AutoUpdate tests passed!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    exit 1
} finally {
    # Clean up test folder
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`nTest folder cleaned up." -ForegroundColor Gray
    }
}

Write-Host "`n🎉 Settings Menu AutoUpdate Integration test completed successfully!" -ForegroundColor Green
