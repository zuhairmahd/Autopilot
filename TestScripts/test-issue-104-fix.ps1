#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple test for Issue #104 fix validation
.DESCRIPTION
    Validates that the code fix for missing strings.json/settings.json files is present in main.ps1
.NOTES
    Author: Copilot
    Version: 1.0.0
    Purpose: Verify the fix for Issue #104 is correctly implemented
#>

[CmdletBinding()]
param()

Write-Host "=== Issue #104 Fix Validation ===" -ForegroundColor Cyan
Write-Host "Testing that main.ps1 contains the fix for missing configuration files" -ForegroundColor White

$passedTests = 0
$failedTests = 0

# Test 1: Check that main.ps1 contains the necessary Test-StringsJsonExists call
Write-Host "`nTest 1: Checking for Test-StringsJsonExists call in main.ps1..." -ForegroundColor Yellow

try {
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Look for the specific pattern that indicates the fix is present
    # We should find Test-StringsJsonExists being called after Test-SettingsJsonExists in the else block
    $pattern1 = 'Test-SettingsJsonExists.*-SettingsFile.*\$initFile.*-Silent'
    $pattern2 = 'Test-StringsJsonExists.*-StringsFile.*\$stringsFile.*-Silent'
    
    $match1 = $mainContent -match $pattern1
    $match2 = $mainContent -match $pattern2
    
    if ($match1 -and $match2) {
        # Find the positions to ensure correct order
        $pos1 = $mainContent.IndexOf('Test-SettingsJsonExists')
        $pos2 = $mainContent.IndexOf('Test-StringsJsonExists')
        
        # There should be at least two occurrences - one in the if block and one in the else block
        $settingsMatches = ([regex]'Test-SettingsJsonExists').Matches($mainContent)
        $stringsMatches = ([regex]'Test-StringsJsonExists').Matches($mainContent)
        
        if ($settingsMatches.Count -ge 2 -and $stringsMatches.Count -ge 2) {
            Write-Host "  ✓ Found Test-SettingsJsonExists calls: $($settingsMatches.Count)" -ForegroundColor Green
            Write-Host "  ✓ Found Test-StringsJsonExists calls: $($stringsMatches.Count)" -ForegroundColor Green
            Write-Host "  ✓ Fix is present - both functions are called in multiple places" -ForegroundColor Green
            $passedTests++
        } else {
            Write-Host "  ✗ Insufficient function calls found" -ForegroundColor Red
            Write-Host "    Settings calls: $($settingsMatches.Count), Strings calls: $($stringsMatches.Count)" -ForegroundColor Red
            $failedTests++
        }
    } else {
        Write-Host "  ✗ Required function calls not found in main.ps1" -ForegroundColor Red
        Write-Host "    Test-SettingsJsonExists pattern found: $match1" -ForegroundColor Red
        Write-Host "    Test-StringsJsonExists pattern found: $match2" -ForegroundColor Red
        $failedTests++
    }
}
catch {
    Write-Host "  ✗ Error reading main.ps1: $($_.Exception.Message)" -ForegroundColor Red
    $failedTests++
}

# Test 2: Check the specific else block contains both calls
Write-Host "`nTest 2: Checking else block specifically..." -ForegroundColor Yellow

try {
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Find the else block that handles missing settings file
    $elseBlockRegex = '(?s)else\s*\{[^}]*Configuration file.*not found[^}]*\}'
    $elseBlockMatch = [regex]::Match($mainContent, $elseBlockRegex)
    
    if ($elseBlockMatch.Success) {
        $elseBlockContent = $elseBlockMatch.Value
        
        $hasSettingsCall = $elseBlockContent -match 'Test-SettingsJsonExists'
        $hasStringsCall = $elseBlockContent -match 'Test-StringsJsonExists'
        
        if ($hasSettingsCall -and $hasStringsCall) {
            Write-Host "  ✓ Else block contains both Test-SettingsJsonExists and Test-StringsJsonExists calls" -ForegroundColor Green
            $passedTests++
        } else {
            Write-Host "  ✗ Else block missing required function calls" -ForegroundColor Red
            Write-Host "    Has Test-SettingsJsonExists: $hasSettingsCall" -ForegroundColor Red
            Write-Host "    Has Test-StringsJsonExists: $hasStringsCall" -ForegroundColor Red
            $failedTests++
        }
    } else {
        Write-Host "  ✗ Could not find the expected else block in main.ps1" -ForegroundColor Red
        $failedTests++
    }
}
catch {
    Write-Host "  ✗ Error analyzing else block: $($_.Exception.Message)" -ForegroundColor Red
    $failedTests++
}

# Test 3: Verify the functions themselves exist
Write-Host "`nTest 3: Verifying required functions exist..." -ForegroundColor Yellow

$settingsExists = Test-Path "functions/setupFunctions/FirstRunWizardFunctions/Test-SettingsJsonExists.ps1"
$stringsExists = Test-Path "functions/setupFunctions/FirstRunWizardFunctions/Test-StringsJsonExists.ps1"

if ($settingsExists -and $stringsExists) {
    Write-Host "  ✓ Both Test-SettingsJsonExists.ps1 and Test-StringsJsonExists.ps1 files exist" -ForegroundColor Green
    $passedTests++
} else {
    Write-Host "  ✗ Required function files missing" -ForegroundColor Red
    Write-Host "    Test-SettingsJsonExists.ps1 exists: $settingsExists" -ForegroundColor Red
    Write-Host "    Test-StringsJsonExists.ps1 exists: $stringsExists" -ForegroundColor Red
    $failedTests++
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$totalTests = $passedTests + $failedTests
Write-Host "Total tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { 'Green' } else { 'Red' })

if ($failedTests -eq 0) {
    Write-Host "`n✓ SUCCESS: Issue #104 fix is correctly implemented!" -ForegroundColor Green
    Write-Host "The main.ps1 file now includes Test-StringsJsonExists call when settings.json is missing." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ FAILURE: Issue #104 fix needs attention." -ForegroundColor Red
    exit 1
}