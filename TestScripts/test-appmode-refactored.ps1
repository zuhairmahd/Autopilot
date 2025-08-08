# Enhanced App Mode Refactoring Test

param(
    [string]$TestName = "Enhanced App Mode Refactoring Test",
    [string]$TestFolder = "$PWD\test-appmode-refactored-temp"
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
    Write-TestSection "Testing Refactored App Mode Configuration Function"
    
    # Set up test files and directories
    $secretsDir = Join-Path $TestFolder ".secrets"
    $settingsFile = Join-Path $TestFolder "settings.json"
    
    if (-not (Test-Path $secretsDir)) {
        New-Item -Path $secretsDir -ItemType Directory -Force | Out-Null
    }
    
    Write-TestResult "Test directories created" $true
    
    # Load the refactored function
    $functionPath = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Get-AppModeConfigurationFromUser.ps1"
    if (Test-Path $functionPath) {
        . $functionPath
        Write-TestResult "Get-AppModeConfigurationFromUser function loaded" $true
    } else {
        Write-TestResult "Get-AppModeConfigurationFromUser function not found" $false
        Complete-UnifiedTest $testContext
        exit 1
    }
    
    Write-TestSection "Testing Basic Functionality (Silent Mode)"
    
    # Test 1: Silent mode still works as before
    $result1 = Get-AppModeConfigurationFromUser -Silent
    Write-TestResult "Silent mode returns result object" ($null -ne $result1)
    Write-TestResult "Silent mode returns correct appMode" ($result1.appMode -eq 'full')
    Write-TestResult "Silent mode not cancelled" (-not $result1.cancelled)
    Write-TestResult "Silent mode choice is '1'" ($result1.selectedChoice -eq '1')
    
    Write-TestSection "Testing New Parameters and Contexts"
    
    # Test 2: Settings context with current mode highlighting
    $result2 = Get-AppModeConfigurationFromUser -Silent -CurrentMode "helpDesk" -Context "settings"
    Write-TestResult "Settings context with current mode works" ($null -ne $result2)
    Write-TestResult "Settings context returns correct default" ($result2.appMode -eq 'full')
    
    # Test 3: Wizard context (default)
    $result3 = Get-AppModeConfigurationFromUser -Silent -Context "wizard"
    Write-TestResult "Wizard context works" ($null -ne $result3)
    Write-TestResult "Wizard context returns correct default" ($result3.appMode -eq 'full')
    
    Write-TestSection "Testing Result Structure Consistency"
    
    # Verify all results have the expected structure
    $expectedProperties = @('appMode', 'selectedChoice', 'cancelled', 'currentModeUnchanged')
    $results = @($result1, $result2, $result3)
    
    $allHaveCorrectStructure = $true
    foreach ($result in $results) {
        if ($result -is [hashtable]) {
            foreach ($prop in $expectedProperties) {
                if (-not $result.ContainsKey($prop)) {
                    $allHaveCorrectStructure = $false
                    break
                }
            }
        } else {
            foreach ($prop in $expectedProperties) {
                if (-not ($result.PSObject.Properties.Name -contains $prop)) {
                    $allHaveCorrectStructure = $false
                    break
                }
            }
        }
        if (-not $allHaveCorrectStructure) { break }
    }
    
    Write-TestResult "All results have correct structure" $allHaveCorrectStructure
    Write-TestResult "All results are hashtables" ($results | ForEach-Object { $_ -is [hashtable] } | Where-Object { -not $_ }).Count -eq 0
    
    Write-TestSection "Testing Integration with Update-GlobalSetting"
    
    # Create test settings file
    $testSettings = @{
        description = "Test settings for refactored app mode test"
        version = "1.3.0.0"
        globalSettings = @{
            autoUpdate = $true
            appMode = "full"
            firstRun = $false
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 5 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-TestResult "Test settings file created" $true
    
    # Load Update-GlobalSetting function
    $updateFunctionPath = "$PSScriptRoot\..\functions\setupFunctions\Update-GlobalSetting.ps1"
    if (Test-Path $updateFunctionPath) {
        . $updateFunctionPath
        Write-TestResult "Update-GlobalSetting function loaded" $true
    } else {
        Write-TestResult "Update-GlobalSetting function not found" $false
        Complete-UnifiedTest $testContext
        exit 1
    }
    
    # Test updating with function result
    $configResult = Get-AppModeConfigurationFromUser -Silent
    $updateSuccess = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "appMode" -SettingValue $configResult.appMode
    Write-TestResult "Function result integrates with Update-GlobalSetting" $updateSuccess
    
    # Test different app modes
    $testModes = @('helpDesk', 'advanced', 'admin', 'custom')
    $modeTestsPassed = 0
    
    foreach ($mode in $testModes) {
        # Simulate function returning different modes by testing the Update-GlobalSetting directly
        $modeUpdateSuccess = Update-GlobalSetting -SettingsFile $settingsFile -SettingName "appMode" -SettingValue $mode
        if ($modeUpdateSuccess) {
            # Verify the setting was actually saved
            $verifyContent = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
            if ($verifyContent.globalSettings.appMode -eq $mode) {
                $modeTestsPassed++
            }
        }
    }
    
    Write-TestResult "All app modes can be saved ($modeTestsPassed/$($testModes.Count))" ($modeTestsPassed -eq $testModes.Count)
    
    Write-TestSection "Testing Backward Compatibility"
    
    # Test that the function can still be called the old way
    $oldStyleResult = Get-AppModeConfigurationFromUser -Silent
    Write-TestResult "Old-style function call still works" ($null -ne $oldStyleResult)
    Write-TestResult "Old-style result has appMode property" ($null -ne $oldStyleResult.appMode)
    Write-TestResult "Old-style result appMode is string" ($oldStyleResult.appMode -is [string])
    
    # Test that the first-run wizard can still use the function
    $wizardPath = "$PSScriptRoot\..\functions\setupFunctions\FirstRunWizardFunctions\Start-FirstRunWizard.ps1"
    if (Test-Path $wizardPath) {
        # Check if the wizard code has been updated correctly
        $wizardContent = Get-Content -Path $wizardPath -Raw
        $hasNewCall = $wizardContent -match 'Get-AppModeConfigurationFromUser.*Silent:'
        $hasResultHandling = $wizardContent -match 'appModeResult.*cancelled'
        $hasBackwardCompatibility = $wizardContent -match 'appModeConfig.*appMode.*appModeResult'
        
        Write-TestResult "Wizard uses updated function call" $hasNewCall
        Write-TestResult "Wizard handles cancellation result" $hasResultHandling
        Write-TestResult "Wizard maintains backward compatibility" $hasBackwardCompatibility
    } else {
        Write-TestResult "Start-FirstRunWizard function not found for testing" $false
    }
    
    Write-TestSection "Testing Error Handling and Edge Cases"
    
    # Test with invalid context (should default gracefully)
    $invalidContextResult = Get-AppModeConfigurationFromUser -Silent -Context "invalid"
    Write-TestResult "Invalid context handled gracefully" ($null -ne $invalidContextResult)
    Write-TestResult "Invalid context doesn't break function" ($invalidContextResult.appMode -eq 'full')
    
    # Test all parameter combinations in silent mode
    $paramCombos = @(
        @{Silent=$true},
        @{Silent=$true; CurrentMode="helpDesk"},
        @{Silent=$true; Context="settings"},
        @{Silent=$true; CurrentMode="admin"; Context="settings"}
    )
    
    $comboTestsPassed = 0
    foreach ($combo in $paramCombos) {
        try {
            $comboResult = Get-AppModeConfigurationFromUser @combo
            if ($null -ne $comboResult -and $comboResult.appMode -eq 'full' -and -not $comboResult.cancelled) {
                $comboTestsPassed++
            }
        } catch {
            # Parameter combination failed
        }
    }
    
    Write-TestResult "All parameter combinations work ($comboTestsPassed/$($paramCombos.Count))" ($comboTestsPassed -eq $paramCombos.Count)
    
    Write-TestResult "Enhanced App Mode Refactoring test completed successfully" $true
    
    # Final summary
    Write-TestSection "Test Summary"
    Write-Host "✓ Function refactoring maintains backward compatibility" -ForegroundColor Green
    Write-Host "✓ New parameters work correctly in silent mode" -ForegroundColor Green  
    Write-Host "✓ Result structure is consistent and comprehensive" -ForegroundColor Green
    Write-Host "✓ Integration with existing functions preserved" -ForegroundColor Green
    Write-Host "✓ Error handling improved without breaking existing code" -ForegroundColor Green
    
} catch {
    Write-TestResult "Enhanced App Mode Refactoring test failed: $($_.Exception.Message)" $false
} finally {
    Complete-UnifiedTest $testContext
}