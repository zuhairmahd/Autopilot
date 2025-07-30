# Test script for autoUpdate functionality in First Run Wizard
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-autoupdate-temp"
)

Write-Host "Testing autoUpdate First Run Wizard Integration" -ForegroundColor Green
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Set up test environment
$LogFile = "$TestFolder\test.log"
$configFile = "$TestFolder\.secrets\config.json"
$settingsFile = "$TestFolder\settings.json"
$stringsFile = "$TestFolder\strings.json"

try {
    # Load the functions
    Write-Host "`n1. Loading functions..." -ForegroundColor Cyan
    
    # Load all functions from the functions directory
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions) {
            . $function.FullName
        }
        Write-Host "✓ Functions loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Functions folder not found: $functionsFolder" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n2. Testing Get-AutoUpdateConfigurationFromUser function..." -ForegroundColor Cyan
    
    # Test the autoUpdate function in silent mode
    $autoUpdateConfig = Get-AutoUpdateConfigurationFromUser -Silent
    
    if ($autoUpdateConfig -and $autoUpdateConfig.ContainsKey('autoUpdate')) {
        Write-Host "✓ Get-AutoUpdateConfigurationFromUser works in silent mode" -ForegroundColor Green
        Write-Host "  - autoUpdate setting: $($autoUpdateConfig.autoUpdate)" -ForegroundColor White
        
        if ($autoUpdateConfig.autoUpdate -eq $true) {
            Write-Host "✓ Default autoUpdate value is correct (true)" -ForegroundColor Green
        } else {
            Write-Host "✗ Default autoUpdate value is incorrect (should be true)" -ForegroundColor Red
            throw "Default autoUpdate value validation failed"
        }
    } else {
        Write-Host "✗ Get-AutoUpdateConfigurationFromUser failed" -ForegroundColor Red
        throw "Get-AutoUpdateConfigurationFromUser test failed"
    }

    Write-Host "`n3. Testing full wizard with autoUpdate in silent mode..." -ForegroundColor Cyan
    
    # Test the wizard in silent mode
    $success = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $settingsFile -StringsFile $stringsFile -Silent
    
    if ($success) {
        Write-Host "✓ First Run Wizard completed successfully" -ForegroundColor Green
        
        # Check if settings.json was created and contains autoUpdate
        if (Test-Path $settingsFile) {
            Write-Host "✓ Settings file was created" -ForegroundColor Green
            
            # Load and check the settings file
            $settingsContent = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            
            if ($settingsContent.PSObject.Properties.Name -contains 'globalSettings') {
                Write-Host "✓ Settings file contains globalSettings section" -ForegroundColor Green
                
                if ($settingsContent.globalSettings.PSObject.Properties.Name -contains 'autoUpdate') {
                    Write-Host "✓ Settings file contains autoUpdate setting" -ForegroundColor Green
                    Write-Host "  - autoUpdate value: $($settingsContent.globalSettings.autoUpdate)" -ForegroundColor White
                    
                    if ($settingsContent.globalSettings.autoUpdate -eq $true) {
                        Write-Host "✓ autoUpdate setting is correctly set to true" -ForegroundColor Green
                    } else {
                        Write-Host "✗ autoUpdate setting is not true" -ForegroundColor Red
                        throw "autoUpdate setting validation failed"
                    }
                } else {
                    Write-Host "✗ Settings file does not contain autoUpdate setting" -ForegroundColor Red
                    throw "autoUpdate setting not found in settings.json"
                }
            } else {
                Write-Host "✗ Settings file does not contain globalSettings section" -ForegroundColor Red
                throw "globalSettings section not found"
            }
        } else {
            Write-Host "✗ Settings file was not created" -ForegroundColor Red
            throw "Settings file creation failed"
        }
        
        # Check other expected files
        if (Test-Path $configFile) {
            Write-Host "✓ Config file was created" -ForegroundColor Green
        } else {
            Write-Host "✗ Config file was not created" -ForegroundColor Red
        }
        
        if (Test-Path $stringsFile) {
            Write-Host "✓ Strings file was created" -ForegroundColor Green
        } else {
            Write-Host "✗ Strings file was not created" -ForegroundColor Red
        }
        
    } else {
        Write-Host "✗ First Run Wizard failed" -ForegroundColor Red
        throw "First Run Wizard test failed"
    }

    Write-Host "`n4. Testing Update-GlobalSetting function with autoUpdate..." -ForegroundColor Cyan
    
    # Test updating the autoUpdate setting to false
    $updateSuccess = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $false
    
    if ($updateSuccess) {
        Write-Host "✓ Update-GlobalSetting function works" -ForegroundColor Green
        
        # Verify the update
        $updatedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($updatedSettings.globalSettings.autoUpdate -eq $false) {
            Write-Host "✓ autoUpdate setting was successfully updated to false" -ForegroundColor Green
        } else {
            Write-Host "✗ autoUpdate setting was not updated correctly" -ForegroundColor Red
            throw "autoUpdate setting update validation failed"
        }
        
        # Test updating back to true
        $updateSuccess2 = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $true
        if ($updateSuccess2) {
            $finalSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            if ($finalSettings.globalSettings.autoUpdate -eq $true) {
                Write-Host "✓ autoUpdate setting was successfully updated back to true" -ForegroundColor Green
            } else {
                Write-Host "✗ autoUpdate setting was not updated back to true correctly" -ForegroundColor Red
                throw "autoUpdate setting final update validation failed"
            }
        }
    } else {
        Write-Host "✗ Update-GlobalSetting function failed" -ForegroundColor Red
        throw "Update-GlobalSetting test failed"
    }

    Write-Host "`n✓ All autoUpdate tests passed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`n✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force
        Write-Host "✓ Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nTest completed successfully!" -ForegroundColor Green