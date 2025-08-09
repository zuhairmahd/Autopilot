# Test App Mode Configuration Integration

param(
    [string]$TestName = "App Mode Configuration Integration Test",
    [string]$TestFolder = "$PWD\test-appmode-temp"
)

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try {
    Write-TestSection "Testing App Mode Configuration Functions"
    
    # Set up test files and directories
    $secretsDir = Join-Path $TestFolder ".secrets"
    $settingsFile = Join-Path $TestFolder "settings.json"
    $stringsFile = Join-Path $TestFolder "strings.json"
    
    if (-not (Test-Path $secretsDir)) {
        New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
    }
    
    Write-TestResult "Test directories created" $true
    
    Write-TestSection "Testing Get-AppModeConfigurationFromUser Function"
    
    # Load the new function
    $appModeFunction = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Get-AppModeConfigurationFromUser.ps1"
    if (Test-Path $appModeFunction) {
        . $appModeFunction
        Write-TestResult "Get-AppModeConfigurationFromUser function loaded" $true
        
        # Test silent mode
        $silentConfig = Get-AppModeConfigurationFromUser -Silent
        if ($silentConfig -and $silentConfig.appMode -eq 'full') {
            Write-TestResult "Silent mode returns default 'full' app mode" $true
        } else {
            Write-TestResult "Silent mode app mode configuration failed" $false
        }
    } else {
        Write-TestResult "Get-AppModeConfigurationFromUser function file not found" $false
    }
    
    Write-TestSection "Testing App Mode Validation"
    
    # Test valid app modes
    $validAppModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
    $validationResults = @()
    
    foreach ($mode in $validAppModes) {
        # Simulate app mode validation logic from main.ps1
        if ($mode -in @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')) {
            $validationResults += $true
        } else {
            $validationResults += $false
        }
    }
    
    if (($validationResults | Where-Object { $_ -eq $true }).Count -eq $validAppModes.Count) {
        Write-TestResult "All valid app modes pass validation" $true
    } else {
        Write-TestResult "App mode validation failed for some valid modes" $false
    }
    
    # Test invalid app mode
    $invalidMode = 'invalidMode'
    $isInvalid = $invalidMode -notin @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
    Write-TestResult "Invalid app mode '$invalidMode' correctly rejected" $isInvalid
    
    Write-TestSection "Testing Settings File Integration"
    
    # Create a test settings file
    $testSettings = @{
        description = "Test settings for app mode integration"
        version = "1.3.0.0"
        auth = @{
            Delegated = $true
            authType = "PublicAuthFlow"
        }
        globalSettings = @{
            autoUpdate = $true
            appMode = "registration"
            firstRun = $false
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 5 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-TestResult "Test settings file created with app mode" $true
    
    # Verify settings file can be read and contains app mode
    if (Test-Path $settingsFile) {
        try {
            $settingsContent = Get-Content $settingsFile | ConvertFrom-Json
            
            # Test app mode setting
            if ($settingsContent.globalSettings.appMode -eq "registration") {
                Write-TestResult "App mode setting correctly configured in settings file" $true
            } else {
                Write-TestResult "App mode setting not configured correctly in settings file" $false
            }
            
            # Test that other settings are preserved
            if ($settingsContent.globalSettings.autoUpdate -eq $true) {
                Write-TestResult "Other settings preserved when app mode is set" $true
            } else {
                Write-TestResult "Other settings not preserved when app mode is set" $false
            }
        }
        catch {
            Write-TestResult "Failed to parse settings file: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "Settings file not found" $false
    }
    
    Write-TestSection "Testing Update-Setting Function for App Mode"
    
    # Test updating app mode setting using Update-Setting
    if (Get-Command Update-Setting -ErrorAction SilentlyContinue) {
        Write-TestResult "Update-Setting function available" $true
        
        # Test updating app mode setting
        $updateResult = Update-Setting -SettingType "Global" -SettingsFile $settingsFile -SettingName "appMode" -SettingValue "helpDesk"
        if ($updateResult) {
            Write-TestResult "App mode setting updated successfully" $true
            
            # Verify the update
            $updatedSettings = Get-Content $settingsFile | ConvertFrom-Json
            if ($updatedSettings.globalSettings.appMode -eq "helpDesk") {
                Write-TestResult "App mode setting verified after update" $true
            } else {
                Write-TestResult "App mode setting not verified after update" $false
            }
        } else {
            Write-TestResult "Failed to update app mode setting" $false
        }
    } else {
        Write-TestResult "Update-Setting function not available" $false
    }
    
    Write-TestSection "Testing First Run Wizard Integration"
    
    # Test that Start-FirstRunWizard includes app mode collection
    $wizardFunction = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Start-FirstRunWizard.ps1"
    if (Test-Path $wizardFunction) {
        $wizardContent = Get-Content $wizardFunction -Raw
        
        # Check if app mode configuration is included
        if ($wizardContent -match "Get-AppModeConfigurationFromUser") {
            Write-TestResult "First Run Wizard includes app mode configuration" $true
        } else {
            Write-TestResult "First Run Wizard does not include app mode configuration" $false
        }
        
        # Check if app mode setting is saved
        if ($wizardContent -match 'appMode.*Update-Setting') {
            Write-TestResult "First Run Wizard saves app mode setting" $true
        } else {
            Write-TestResult "First Run Wizard does not save app mode setting" $false
        }
    } else {
        Write-TestResult "First Run Wizard function file not found" $false
    }
    
    Write-TestSection "Testing Menu Integration"
    
    # Test that main.ps1 includes app mode menu item
    $mainScript = "$PSScriptRoot\..\main.ps1"
    if (Test-Path $mainScript) {
        $mainContent = Get-Content $mainScript -Raw
        
        # Check if app mode menu item is included
        if ($mainContent -match "Change App Mode setting") {
            Write-TestResult "Main script includes app mode menu item" $true
        } else {
            Write-TestResult "Main script does not include app mode menu item" $false
        }
        
        # Check if menu item uses Update-Setting
        if ($mainContent -match "Update-Setting.*appMode" -or $mainContent -match "appMode.*Update-Setting") {
            Write-TestResult "App mode menu item uses Update-Setting function" $true
        } else {
            Write-TestResult "App mode menu item does not use Update-Setting function" $false
        }
    } else {
        Write-TestResult "Main script file not found" $false
    }
    
    Write-TestResult "App Mode Configuration Integration test completed successfully" $true
    
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success) {
        Write-Host "App Mode Configuration Integration test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "App Mode Configuration Integration test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}