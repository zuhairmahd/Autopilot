#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test for missing configuration files fix (Issue #104)
.DESCRIPTION
    This test validates that when .secrets\config.json exists but strings.json or settings.json 
    are missing, the script recreates those files using Test-StringsJsonExists and Test-SettingsJsonExists.
.NOTES
    Author: Copilot
    Version: 1.0.0
    Purpose: Validate fix for Issue #104 - missing files recreation
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
    $testContext = Start-UnifiedTest -TestName "Missing Files Fix Test (Issue #104)" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Initialize test tracking
$passedTests = 0
$failedTests = 0

Write-TestSection "Test 1: Validate Test-SettingsJsonExists Function"

# Test 1: Ensure Test-SettingsJsonExists function exists and works
if (Get-Command "Test-SettingsJsonExists" -ErrorAction SilentlyContinue) {
    Write-Host "Testing Test-SettingsJsonExists function..." -ForegroundColor Cyan
    
    try {
        # Create a test settings file path
        $testSettingsFile = "$PWD\test-settings-temp.json"
        
        # Remove file if it exists
        if (Test-Path $testSettingsFile) {
            Remove-Item $testSettingsFile -Force
        }
        
        # Call the function to create the file
        $result = Test-SettingsJsonExists -SettingsFile $testSettingsFile -Silent -DomainName "test.com"
        
        if ($result -and (Test-Path $testSettingsFile)) {
            Write-TestResult "Test-SettingsJsonExists creates missing settings file" $true
            $passedTests++
            
            # Clean up
            if (Test-Path $testSettingsFile) {
                Remove-Item $testSettingsFile -Force
            }
        } else {
            Write-TestResult "Test-SettingsJsonExists failed to create settings file" $false
            $failedTests++
        }
    }
    catch {
        Write-TestResult "Test-SettingsJsonExists function test failed: $($_.Exception.Message)" $false
        $failedTests++
    }
} else {
    Write-TestResult "Test-SettingsJsonExists function not available" $false
    $failedTests++
}

Write-TestSection "Test 2: Validate Test-StringsJsonExists Function"

# Test 2: Ensure Test-StringsJsonExists function exists and works
if (Get-Command "Test-StringsJsonExists" -ErrorAction SilentlyContinue) {
    Write-Host "Testing Test-StringsJsonExists function..." -ForegroundColor Cyan
    
    try {
        # Create a test strings file path
        $testStringsFile = "$PWD\test-strings-temp.json"
        
        # Remove file if it exists
        if (Test-Path $testStringsFile) {
            Remove-Item $testStringsFile -Force
        }
        
        # Call the function to create the file
        $result = Test-StringsJsonExists -StringsFile $testStringsFile -Silent
        
        if ($result -and (Test-Path $testStringsFile)) {
            Write-TestResult "Test-StringsJsonExists creates missing strings file" $true
            $passedTests++
            
            # Validate the file contains expected content
            $stringsContent = Get-Content -Path $testStringsFile -Raw | ConvertFrom-Json
            if ($stringsContent.returnValues -and $stringsContent.deviceStates -and $stringsContent.deviceActions) {
                Write-TestResult "Created strings file contains expected sections" $true
                $passedTests++
            } else {
                Write-TestResult "Created strings file missing expected sections" $false
                $failedTests++
            }
            
            # Clean up
            if (Test-Path $testStringsFile) {
                Remove-Item $testStringsFile -Force
            }
        } else {
            Write-TestResult "Test-StringsJsonExists failed to create strings file" $false
            $failedTests++
        }
    }
    catch {
        Write-TestResult "Test-StringsJsonExists function test failed: $($_.Exception.Message)" $false
        $failedTests++
    }
} else {
    Write-TestResult "Test-StringsJsonExists function not available" $false
    $failedTests++
}

Write-TestSection "Test 3: Validate main.ps1 Logic Fix"

# Test 3: Validate that main.ps1 contains the fix for missing strings.json
Write-Host "Checking main.ps1 for Test-StringsJsonExists call in else block..." -ForegroundColor Cyan

try {
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Check if the fix is present: Test-StringsJsonExists should be called after Test-SettingsJsonExists in the else block
    $hasSettingsCall = $mainContent -match 'Test-SettingsJsonExists.*-SettingsFile.*-Silent.*-AuthType.*-IsDelegated.*-DomainName'
    $hasStringsCall = $mainContent -match 'Test-StringsJsonExists.*-StringsFile.*-Silent'
    
    if ($hasSettingsCall -and $hasStringsCall) {
        # Check that strings call comes after settings call
        $settingsCallIndex = $mainContent.IndexOf('Test-SettingsJsonExists')
        $stringsCallIndex = $mainContent.IndexOf('Test-StringsJsonExists')
        
        if ($stringsCallIndex -gt $settingsCallIndex) {
            Write-TestResult "main.ps1 contains both Test-SettingsJsonExists and Test-StringsJsonExists calls in correct order" $true
            $passedTests++
        } else {
            Write-TestResult "main.ps1 contains calls but in wrong order" $false
            $failedTests++
        }
    } else {
        Write-TestResult "main.ps1 missing required function calls in else block" $false
        $failedTests++
        Write-Host "  Settings call found: $hasSettingsCall" -ForegroundColor Red
        Write-Host "  Strings call found: $hasStringsCall" -ForegroundColor Red
    }
}
catch {
    Write-TestResult "Failed to check main.ps1 content: $($_.Exception.Message)" $false
    $failedTests++
}

Write-TestSection "Test 4: Integration Test Simulation"

# Test 4: Simulate the scenario where config.json exists but other files don't
Write-Host "Simulating scenario where only .secrets\config.json exists..." -ForegroundColor Cyan

try {
    # Create test directory structure
    $testDir = "$PWD\test-scenario"
    $secretsDir = "$testDir\.secrets"
    
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
    
    # Create a minimal config.json file
    $testConfig = @{
        domain = "test.com"
        authType = "PublicAuthFlow"
        delegated = $true
    }
    $testConfig | ConvertTo-Json | Set-Content -Path "$secretsDir\config.json" -Force
    
    # Test settings file creation
    $testSettingsFile = "$testDir\settings.json"
    $testStringsFile = "$testDir\strings.json"
    
    # Both files should be missing initially
    if (-not (Test-Path $testSettingsFile) -and -not (Test-Path $testStringsFile)) {
        # Test that both functions can create their respective files
        $settingsResult = Test-SettingsJsonExists -SettingsFile $testSettingsFile -Silent -DomainName "test.com"
        $stringsResult = Test-StringsJsonExists -StringsFile $testStringsFile -Silent
        
        if ($settingsResult -and $stringsResult -and (Test-Path $testSettingsFile) -and (Test-Path $testStringsFile)) {
            Write-TestResult "Integration test: Both missing files were created successfully" $true
            $passedTests++
        } else {
            Write-TestResult "Integration test: Failed to create missing files" $false
            $failedTests++
            Write-Host "  Settings result: $settingsResult, file exists: $(Test-Path $testSettingsFile)" -ForegroundColor Red
            Write-Host "  Strings result: $stringsResult, file exists: $(Test-Path $testStringsFile)" -ForegroundColor Red
        }
    } else {
        Write-TestResult "Integration test setup failed: Files already exist" $false
        $failedTests++
    }
    
    # Clean up
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force
    }
}
catch {
    Write-TestResult "Integration test failed: $($_.Exception.Message)" $false
    $failedTests++
}

# Summary
Write-TestSection "Test Summary"
$totalTests = $passedTests + $failedTests
Write-Host "Total tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { 'Green' } else { 'Red' })

if ($failedTests -eq 0) {
    Write-Host "`nAll tests passed! The fix for Issue #104 is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed. Please review the issues above." -ForegroundColor Red
    exit 1
}