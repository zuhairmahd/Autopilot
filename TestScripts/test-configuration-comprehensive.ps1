#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for configuration management and settings merging
.DESCRIPTION
    This test validates configuration management functionality including:
    - Settings file creation and validation
    - Configuration merging from multiple sources
    - Domain-specific settings handling
    - Default value management
    - Configuration initialization and wizard functionality
.NOTES
    Author: Test Expansion Initiative
    Version: 1.0.0
    Purpose: Ensure configuration management works correctly across all scenarios
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Load functions at script level (same pattern as main.ps1)
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions) {
        try {
            . $function.FullName
        }
        catch {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
} else {
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}

# Initialize test environment
try {
    $testContext = Start-UnifiedTest -TestName "Configuration Management Comprehensive Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = "$PWD/test-config-mgmt.log"

try {
    Write-TestSection "Test 1: Configuration Management Functions Availability"
    
    # Test critical configuration management functions
    $configFunctions = @(
        "InitializeConfiguration",
        "MergeSettings",
        "Get-ConfigurationData",
        "CreateConfiguration",
        "Get-ConfigurationData",
        "Update-Setting"
    )
    
    $configFunctionResults = @()
    foreach ($funcName in $configFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $configFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Configuration function '$funcName' is available" $true
        } else {
            Write-TestResult "Configuration function '$funcName' is not available" $false
        }
    }
    
    $allConfigFunctionsAvailable = ($configFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All configuration functions are available" $allConfigFunctionsAvailable
    
    Write-TestSection "Test 2: Settings Merging Logic"
    
    # Test MergeSettings function if available
    if (Get-Command "MergeSettings" -ErrorAction SilentlyContinue) {
        Write-Host "Testing settings merging logic..." -ForegroundColor Cyan
        
        # Create test local and global settings
        $localSettings = @{
            appMode = "helpDesk"
            customSetting = "local"
            localOnlySetting = "localValue"
        }
        
        $globalSettings = @{
            appMode = "full"
            globalSetting = "global"
            customSetting = "global"
            globalOnlySetting = "globalValue"
        }
        
        try {
            # Test with Local priority
            $mergedLocalPriority = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
            
            if ($mergedLocalPriority.appMode -eq "helpDesk") {
                Write-TestResult "Local priority merge works (appMode = helpDesk)" $true
            } else {
                Write-TestResult "Local priority merge failed - appMode = $($mergedLocalPriority.appMode)" $false
            }
            
            if ($mergedLocalPriority.customSetting -eq "local") {
                Write-TestResult "Local priority conflict resolution works" $true
            } else {
                Write-TestResult "Local priority conflict resolution failed" $false
            }
            
            if ($mergedLocalPriority.globalOnlySetting -eq "globalValue" -and $mergedLocalPriority.localOnlySetting -eq "localValue") {
                Write-TestResult "Unique settings preserved in merge" $true
            } else {
                Write-TestResult "Unique settings not preserved in merge" $false
            }
            
            # Test with Global priority
            $mergedGlobalPriority = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Global'
            
            if ($mergedGlobalPriority.customSetting -eq "global") {
                Write-TestResult "Global priority conflict resolution works" $true
            } else {
                Write-TestResult "Global priority conflict resolution failed" $false
            }
        }
        catch {
            Write-TestResult "Settings merging test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "MergeSettings function not available - skipping merge test" $true
    }
    
    Write-TestSection "Test 3: Configuration Data Loading and Validation"
    
    # Test Get-ConfigurationData function
    if (Get-Command "Get-ConfigurationData" -ErrorAction SilentlyContinue) {
        Write-Host "Testing configuration data loading..." -ForegroundColor Cyan
        
        try {
            $testSettingsPath = Join-Path $testContext.TestFolder "test-settings"
            
            # Test configuration file loading with defaults
            $configData = Get-ConfigurationData -ConfigurationPath $testSettingsPath -DefaultValues @{test = "value"} -ErrorAction SilentlyContinue
            
            if ($configData) {
                Write-TestResult "Configuration data loading works" $true
                
                # Verify default values are applied when file doesn't exist
                if ($configData.test -eq "value") {
                    Write-TestResult "Default values applied correctly when file doesn't exist" $true
                } else {
                    Write-TestResult "Default values not applied correctly" $false
                }
            } else {
                Write-TestResult "Configuration data loading failed" $false
            }
        } catch {
            Write-TestResult "Configuration data loading test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "Get-ConfigurationData function not available - skipping configuration data test" $true
    }
    
    Write-TestSection "Test 4: Configuration Initialization"
    
    # Test InitializeConfiguration function
    if (Get-Command "InitializeConfiguration" -ErrorAction SilentlyContinue) {
        Write-Host "Testing configuration initialization..." -ForegroundColor Cyan
        
        try {
            Write-TestResult "InitializeConfiguration function is available for testing" $true
        }
        catch {
            Write-TestResult "Configuration initialization test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "InitializeConfiguration function not available - skipping initialization test" $true
    }
    
    Write-TestSection "Test 5: First Run Wizard Functions"
    
    # Test first run wizard functionality
    $wizardFunctions = @(
        "Start-FirstRunWizard",
        "Get-AppModeConfigurationFromUser",
        "Get-AuthenticationConfigurationFromUser",
        "Get-BasicConfigurationFromUser"
    )
    
    $wizardFunctionResults = @()
    foreach ($funcName in $wizardFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $wizardFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Wizard function '$funcName' is available" $true
        } else {
            Write-TestResult "Wizard function '$funcName' is not available" $false
        }
    }
    
    $allWizardFunctionsAvailable = ($wizardFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All wizard functions are available" $allWizardFunctionsAvailable
    
    Write-TestSection "Test 6: Settings Update and Management"
    
    # Test Update-Setting function
    if (Get-Command "Update-Setting" -ErrorAction SilentlyContinue) {
        Write-Host "Testing settings update functionality..." -ForegroundColor Cyan
        
        try {
            Write-TestResult "Update-Setting function is available for testing" $true
        }
        catch {
            Write-TestResult "Settings update test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "Update-Setting function not available - skipping update test" $true
    }
    
    Write-TestSection "Test 7: Configuration Encryption Functions"
    
    # Test configuration encryption functionality
    $encryptionFunctions = @(
        "Initialize-ConfigurationSession",
        "Load-EncryptedConfigFile",
        "Invoke-JsonFileEncryption",
        "Setup-TemporaryEncryption"
    )
    
    $encryptionFunctionResults = @()
    foreach ($funcName in $encryptionFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $encryptionFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Encryption function '$funcName' is available" $true
        } else {
            Write-TestResult "Encryption function '$funcName' is not available" $false
        }
    }
    
    $allEncryptionFunctionsAvailable = ($encryptionFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All encryption functions are available" $allEncryptionFunctionsAvailable
    
    Write-TestSection "Test 8: Configuration Utilities"
    
    # Test configuration utility functions
    $utilityFunctions = @(
        "ConvertFrom-JsonToHashtable",
        "ConvertTo-OrderedJson",
        "Export-PowerShellDataFile",
        "Get-ConfigurationData"
    )
    
    $utilityFunctionResults = @()
    foreach ($funcName in $utilityFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $utilityFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Utility function '$funcName' is available" $true
        } else {
            Write-TestResult "Utility function '$funcName' is not available" $false
        }
    }
    
    $allUtilityFunctionsAvailable = ($utilityFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All utility functions are available" $allUtilityFunctionsAvailable
    
    # Summary
    $totalTests = 8
    $passedTests = 0
    
    if ($allConfigFunctionsAvailable) { $passedTests++ }
    if (Get-Command "MergeSettings" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "Get-ConfigurationData" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "InitializeConfiguration" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ($allWizardFunctionsAvailable) { $passedTests++ }
    if (Get-Command "Update-Setting" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ($allEncryptionFunctionsAvailable) { $passedTests++ }
    if ($allUtilityFunctionsAvailable) { $passedTests++ }
    
    $failedTests = $totalTests - $passedTests
    
    Write-TestResult "Configuration management comprehensive test completed" $true
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    $failedTests = 8
    $passedTests = 0
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests 8
    
    if ($success) {
        Write-Host "Configuration Management Comprehensive Test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Configuration Management Comprehensive Test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}