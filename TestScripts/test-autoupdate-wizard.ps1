# Test script for autoUpdate functionality in First Run Wizard
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-autoupdate-temp"
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-TestSection "Auto Update First Run Wizard Integration Test"
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
    Write-TestSection "1. Loading functions"
    
    $rootPath = Split-Path -Parent $PSScriptRoot
    $loadSuccess = Load-AllFunctions -RootPath $rootPath
    
    if ($loadSuccess) {
        Write-TestResult "Functions loaded successfully" -Success $true
    } else {
        Write-TestResult "Failed to load functions" -Success $false
        exit 1
    }
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

    Write-Host "`n2. Testing Get-AutoUpdateConfigurationFromUser function..." -ForegroundColor Cyan
    
    # Test the autoUpdate function in silent mode
    $autoUpdateConfig = Get-AutoUpdateConfigurationFromUser -Silent
    
    if ($autoUpdateConfig -and $autoUpdateConfig.ContainsKey('autoUpdate')) {
        Write-Host "[PASS] Get-AutoUpdateConfigurationFromUser works in silent mode" -ForegroundColor Green
        Write-Host "  - autoUpdate setting: $($autoUpdateConfig.autoUpdate)" -ForegroundColor White
        
        if ($autoUpdateConfig.autoUpdate -eq $true) {
            Write-Host "[PASS] Default autoUpdate value is correct (true)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Default autoUpdate value is incorrect (should be true)" -ForegroundColor Red
            throw "Default autoUpdate value validation failed"
        }
    } else {
        Write-Host "[FAIL] Get-AutoUpdateConfigurationFromUser failed" -ForegroundColor Red
        throw "Get-AutoUpdateConfigurationFromUser test failed"
    }

    Write-Host "`n3. Testing full wizard with autoUpdate in silent mode..." -ForegroundColor Cyan
    
    # Test the wizard in silent mode
    $success = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $settingsFile -StringsFile $stringsFile -Silent
    
    if ($success) {
        Write-Host "[PASS] First Run Wizard completed successfully" -ForegroundColor Green
        
        # Check if settings.json was created and contains autoUpdate
        if (Test-Path $settingsFile) {
            Write-Host "[PASS] Settings file was created" -ForegroundColor Green
            
            # Load and check the settings file
            $settingsContent = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            
            if ($settingsContent.PSObject.Properties.Name -contains 'globalSettings') {
                Write-Host "[PASS] Settings file contains globalSettings section" -ForegroundColor Green
                
                if ($settingsContent.globalSettings.PSObject.Properties.Name -contains 'autoUpdate') {
                    Write-Host "[PASS] Settings file contains autoUpdate setting" -ForegroundColor Green
                    Write-Host "  - autoUpdate value: $($settingsContent.globalSettings.autoUpdate)" -ForegroundColor White
                    
                    if ($settingsContent.globalSettings.autoUpdate -eq $true) {
                        Write-Host "[PASS] autoUpdate setting is correctly set to true" -ForegroundColor Green
                    } else {
                        Write-Host "[FAIL] autoUpdate setting is not true" -ForegroundColor Red
                        throw "autoUpdate setting validation failed"
                    }
                } else {
                    Write-Host "[FAIL] Settings file does not contain autoUpdate setting" -ForegroundColor Red
                    throw "autoUpdate setting not found in settings.json"
                }
            } else {
                Write-Host "[FAIL] Settings file does not contain globalSettings section" -ForegroundColor Red
                throw "globalSettings section not found"
            }
        } else {
            Write-Host "[FAIL] Settings file was not created" -ForegroundColor Red
            throw "Settings file creation failed"
        }
        
        # Check other expected files
        if (Test-Path $configFile) {
            Write-Host "[PASS] Config file was created" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Config file was not created" -ForegroundColor Red
        }
        
        if (Test-Path $stringsFile) {
            Write-Host "[PASS] Strings file was created" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Strings file was not created" -ForegroundColor Red
        }
        
    } else {
        Write-Host "[FAIL] First Run Wizard failed" -ForegroundColor Red
        throw "First Run Wizard test failed"
    }

    Write-Host "`n4. Testing Update-GlobalSetting function with autoUpdate..." -ForegroundColor Cyan
    
    # Test updating the autoUpdate setting to false
    $updateSuccess = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $false
    
    if ($updateSuccess) {
        Write-Host "[PASS] Update-GlobalSetting function works" -ForegroundColor Green
        
        # Verify the update
        $updatedSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        if ($updatedSettings.globalSettings.autoUpdate -eq $false) {
            Write-Host "[PASS] autoUpdate setting was successfully updated to false" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] autoUpdate setting was not updated correctly" -ForegroundColor Red
            throw "autoUpdate setting update validation failed"
        }
        
        # Test updating back to true
        $updateSuccess2 = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "autoUpdate" -SettingValue $true
        if ($updateSuccess2) {
            $finalSettings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            if ($finalSettings.globalSettings.autoUpdate -eq $true) {
                Write-Host "[PASS] autoUpdate setting was successfully updated back to true" -ForegroundColor Green
            } else {
                Write-Host "[FAIL] autoUpdate setting was not updated back to true correctly" -ForegroundColor Red
                throw "autoUpdate setting final update validation failed"
            }
        }
    } else {
        Write-Host "[FAIL] Update-GlobalSetting function failed" -ForegroundColor Red
        throw "Update-GlobalSetting test failed"
    }

    Write-Host "`n[PASS] All autoUpdate tests passed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`n[FAIL] Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    if (Test-Path $TestFolder) {
        Remove-Item -Path $TestFolder -Recurse -Force
        Write-Host "[PASS] Test folder cleaned up" -ForegroundColor Green
    }
}

Write-Host "`nTest completed successfully!" -ForegroundColor Green
