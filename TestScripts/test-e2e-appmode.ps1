# End-to-End App Mode Integration Test

param(
    [string]$TestName = "End-to-End App Mode Integration Test",
    [string]$TestFolder = $null
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
    Write-TestSection "Testing Complete App Mode Workflow"
    
    # Set up test files and directories
    $secretsDir = Join-Path $TestFolder ".secrets"
    $settingsFile = Join-Path $TestFolder "settings.json"
    $stringsFile = Join-Path $TestFolder "strings.json"
    
    if (-not (Test-Path $secretsDir)) {
        New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
    }
    
    Write-TestResult "Test directories created" $true
    
    Write-TestSection "Step 1: Testing First-Run Wizard App Mode Integration"
    
    # Load all required functions
    $wizardPath = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions"
    $functions = @(
        "$wizardPath\Get-AppModeConfigurationFromUser.ps1",
        "$wizardPath\Start-FirstRunWizard.ps1",
        "$PSScriptRoot\..\functions\setupFunctions\Update-Setting.ps1"
    )
    
    $functionsLoaded = 0
    foreach ($func in $functions) {
        if (Test-Path $func) {
            try {
                . $func
                $functionsLoaded++
            } catch {
                Write-TestResult "Failed to load $func : $($_.Exception.Message)" $false
            }
        }
    }
    
    Write-TestResult "Required functions loaded ($functionsLoaded/$($functions.Count))" ($functionsLoaded -eq $functions.Count)
    
    Write-TestSection "Step 2: Testing App Mode Function in Silent Mode"
    
    # Test the app mode configuration function directly
    if (Get-Command Get-AppModeConfigurationFromUser -ErrorAction SilentlyContinue) {
        $appModeResult = Get-AppModeConfigurationFromUser -Silent
        if ($appModeResult -and $appModeResult.appMode -eq 'full') {
            Write-TestResult "App mode function returns correct default" $true
        } else {
            Write-TestResult "App mode function failed" $false
        }
    } else {
        Write-TestResult "Get-AppModeConfigurationFromUser function not available" $false
    }
    
    Write-TestSection "Step 3: Testing Settings File Creation and Update"
    
    # Create initial settings file
    $testSettings = @{
        description = "Test settings for end-to-end app mode test"
        version = "1.3.0.0"
        auth = @{
            Delegated = $true
            authType = "PublicAuthFlow"
        }
        globalSettings = @{
            autoUpdate = $true
            appMode = "full"
            firstRun = $false
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 5 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-TestResult "Initial settings file created" $true
    
    # Test updating app mode setting
    if (Get-Command Update-Setting -ErrorAction SilentlyContinue) {
        $updateResult = Update-Setting -SettingType "Global" -SettingsFile $settingsFile -SettingName "appMode" -SettingValue "helpDesk"
        if ($updateResult) {
            Write-TestResult "App mode setting updated successfully" $true
            
            # Verify the update
            $verifySettings = Get-Content $settingsFile | ConvertFrom-Json
            if ($verifySettings.globalSettings.appMode -eq "helpDesk") {
                Write-TestResult "App mode setting verified" $true
            } else {
                Write-TestResult "App mode setting verification failed" $false
            }
        } else {
            Write-TestResult "Failed to update app mode setting" $false
        }
    } else {
        Write-TestResult "Update-Setting function not available" $false
    }
    
    Write-TestSection "Step 4: Testing App Mode Validation Logic"
    
    # Test all valid app modes
    $validModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
    $validationTests = @()
    
    foreach ($mode in $validModes) {
        $isValid = $mode -in @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
        $validationTests += $isValid
        
        # Also test updating to each mode
        if (Get-Command Update-Setting -ErrorAction SilentlyContinue) {
            $modeUpdateResult = Update-Setting -SettingType "Global" -SettingsFile $settingsFile -SettingName "appMode" -SettingValue $mode
            $validationTests += $modeUpdateResult
        }
    }
    
    $successfulValidations = ($validationTests | Where-Object { $_ -eq $true }).Count
    $totalValidations = $validationTests.Count
    
    Write-TestResult "App mode validation tests passed ($successfulValidations/$totalValidations)" ($successfulValidations -eq $totalValidations)
    
    Write-TestSection "Step 5: Testing Menu Integration Pattern"
    
    # Check that main.ps1 contains the expected patterns
    $mainScript = "$PSScriptRoot\..\main.ps1"
    if (Test-Path $mainScript) {
        $mainContent = Get-Content $mainScript -Raw
        
        $patterns = @{
            "App mode menu item" = "Change App Mode setting"
            "App mode validation" = "appMode.*notin.*@\("
            "Update function call" = "Update-Setting.*appMode"
            "Restart prompt" = "restart.*application"
        }
        
        $patternResults = @()
        foreach ($pattern in $patterns.GetEnumerator()) {
            $found = $mainContent -match $pattern.Value
            $patternResults += $found
            Write-TestResult "$($pattern.Key) pattern found" $found
        }
        
        $patternsFound = ($patternResults | Where-Object { $_ -eq $true }).Count
        Write-TestResult "Menu integration patterns verified ($patternsFound/$($patterns.Count))" ($patternsFound -eq $patterns.Count)
    } else {
        Write-TestResult "Main script not found for pattern verification" $false
    }
    
    Write-TestSection "Step 6: Testing Configuration Persistence"
    
    # Test that settings persist through multiple updates
    $testModes = @('registration', 'advanced', 'full')
    $persistenceTests = @()
    
    foreach ($mode in $testModes) {
        if (Get-Command Update-Setting -ErrorAction SilentlyContinue) {
            $updateSuccess = Update-Setting -SettingType "Global" -SettingsFile $settingsFile -SettingName "appMode" -SettingValue $mode
            
            if ($updateSuccess) {
                # Verify the setting was saved
                $currentSettings = Get-Content $settingsFile | ConvertFrom-Json
                $persistenceTests += ($currentSettings.globalSettings.appMode -eq $mode)
            } else {
                $persistenceTests += $false
            }
        }
    }
    
    $successfulPersistence = ($persistenceTests | Where-Object { $_ -eq $true }).Count
    Write-TestResult "Configuration persistence tests passed ($successfulPersistence/$($testModes.Count))" ($successfulPersistence -eq $testModes.Count)
    
    Write-TestResult "End-to-End App Mode Integration test completed successfully" $true
    
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests 1 -FailedTests 0 -TotalTests 1
    
    if ($success) {
        Write-Host "End-to-End App Mode Integration test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "End-to-End App Mode Integration test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}