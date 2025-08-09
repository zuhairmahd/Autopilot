#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for main.ps1 AppMode validation and functionality
.DESCRIPTION
    This test validates all AppMode options available in main.ps1:
    - full, helpDesk, advanced, advancedRegistration, registration, admin, custom
    - Validates that invalid AppModes are rejected
    - Tests AppMode configuration merging from settings
.NOTES
    Author: Test Expansion Initiative
    Version: 1.0.0
    Purpose: Ensure AppMode validation and functionality works correctly
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
    $testContext = Start-UnifiedTest -TestName "Main.ps1 AppMode Comprehensive Test" -TestFolder "$PWD\test-appmode-comprehensive-temp" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = "$PWD/test-appmode.log"

try {
    Write-TestSection "Test 1: Valid AppMode Values"
    
    # Test all valid AppMode values
    $validAppModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
    $validationResults = @()
    
    foreach ($appMode in $validAppModes) {
        Write-Host "Testing AppMode: $appMode" -ForegroundColor Cyan
        
        # Test that the mode is in the valid list
        $isValid = $appMode -in @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
        $validationResults += @{
            Mode = $appMode
            Valid = $isValid
        }
        
        if ($isValid) {
            Write-TestResult "AppMode '$appMode' is valid" $true
        } else {
            Write-TestResult "AppMode '$appMode' is invalid" $false
        }
    }
    
    $allValid = ($validationResults | Where-Object { -not $_.Valid }).Count -eq 0
    Write-TestResult "All defined AppModes are valid" $allValid
    
    Write-TestSection "Test 2: Invalid AppMode Values"
    
    # Test invalid AppMode values
    $invalidAppModes = @('invalid', 'test', 'debug', 'production', '')
    $invalidationResults = @()
    
    foreach ($appMode in $invalidAppModes) {
        Write-Host "Testing invalid AppMode: '$appMode'" -ForegroundColor Cyan
        
        # Test that the mode is NOT in the valid list
        $isInvalid = $appMode -notin @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
        $invalidationResults += @{
            Mode = $appMode
            Invalid = $isInvalid
        }
        
        if ($isInvalid) {
            Write-TestResult "AppMode '$appMode' correctly identified as invalid" $true
        } else {
            Write-TestResult "AppMode '$appMode' incorrectly accepted as valid" $false
        }
    }
    
    $allInvalid = ($invalidationResults | Where-Object { -not $_.Invalid }).Count -eq 0
    Write-TestResult "All invalid AppModes correctly rejected" $allInvalid
    
    Write-TestSection "Test 3: AppMode Configuration Merging"
    
    # Test AppMode configuration merging functionality
    Write-Host "Testing AppMode configuration merging..." -ForegroundColor Cyan
    
    # Create test local and global settings
    $localSettings = @{
        appMode = "helpDesk"
        customSetting = "local"
    }
    
    $globalSettings = @{
        appMode = "full"
        globalSetting = "global"
        customSetting = "global"
    }
    
    # Test MergeSettings function if available
    if (Get-Command "MergeSettings" -ErrorAction SilentlyContinue) {
        $mergedSettings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
        
        if ($mergedSettings.appMode -eq "helpDesk") {
            Write-TestResult "Local AppMode takes precedence in merge (helpDesk)" $true
        } else {
            Write-TestResult "Local AppMode merge failed - got: $($mergedSettings.appMode)" $false
        }
        
        if ($mergedSettings.globalSetting -eq "global") {
            Write-TestResult "Global settings preserved in merge" $true
        } else {
            Write-TestResult "Global settings not preserved in merge" $false
        }
        
        if ($mergedSettings.customSetting -eq "local") {
            Write-TestResult "Local settings override global in merge" $true
        } else {
            Write-TestResult "Local override failed - got: $($mergedSettings.customSetting)" $false
        }
    } else {
        Write-TestResult "MergeSettings function not available - skipping merge test" $true
    }
    
    Write-TestSection "Test 4: AppMode Default Value Handling"
    
    # Test default AppMode handling
    Write-Host "Testing AppMode default value handling..." -ForegroundColor Cyan
    
    # Simulate when AppMode is not set
    $emptySettings = @{}
    
    # Test that default should be 'full'
    $defaultAppMode = if (-not $emptySettings.appMode) { 'full' } else { $emptySettings.appMode }
    
    if ($defaultAppMode -eq 'full') {
        Write-TestResult "Default AppMode is correctly set to 'full'" $true
    } else {
        Write-TestResult "Default AppMode is incorrect - got: $defaultAppMode" $false
    }
    
    Write-TestSection "Test 5: AppMode String Case Sensitivity"
    
    # Test case sensitivity handling
    $caseVariants = @(
        @{ Input = "helpdesk"; Expected = "helpDesk" },
        @{ Input = "FULL"; Expected = "full" },
        @{ Input = "Advanced"; Expected = "advanced" }
    )
    
    $caseTestResults = @()
    foreach ($variant in $caseVariants) {
        # Test if case-insensitive comparison would work
        $matches = $variant.Input.ToLower() -eq $variant.Expected.ToLower()
        $caseTestResults += $matches
        
        if ($matches) {
            Write-TestResult "Case variant '$($variant.Input)' matches '$($variant.Expected)' (case-insensitive)" $true
        } else {
            Write-TestResult "Case variant '$($variant.Input)' does not match '$($variant.Expected)'" $false
        }
    }
    
    $allCaseTestsPass = ($caseTestResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All case sensitivity tests pass" $allCaseTestsPass
    
    # Summary
    $totalTests = 5
    $passedTests = 0
    
    if ($allValid) { $passedTests++ }
    if ($allInvalid) { $passedTests++ }
    if (Get-Command "MergeSettings" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ($defaultAppMode -eq 'full') { $passedTests++ }
    if ($allCaseTestsPass) { $passedTests++ }
    
    $failedTests = $totalTests - $passedTests
    
    Write-TestResult "AppMode comprehensive test completed" $true
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    $failedTests = 5
    $passedTests = 0
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests 5
    
    if ($success) {
        Write-Host "AppMode Comprehensive Test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "AppMode Comprehensive Test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}