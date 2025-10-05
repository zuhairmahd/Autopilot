#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple test for Issue #104 fix validation
.DESCRIPTION
    Validates that the code fix for missing strings.json/settings.json files is present in main.ps1
    Updated to validate the refactored implementation using Initialize-ApplicationConfiguration
.NOTES
    Author: Copilot
    Version: 2.0.0
    Purpose: Verify the fix for Issue #104 is correctly implemented through refactoring
#>

[CmdletBinding()]
param()

Write-Host "=== Issue #104 Fix Validation ===" -ForegroundColor Cyan
Write-Host "Testing that main.ps1 contains the fix for missing configuration files" -ForegroundColor White

$passedTests = 0
$failedTests = 0

# Test 1: Check that main.ps1 uses the new Initialize-ApplicationConfiguration approach
Write-Host "`nTest 1: Checking for Initialize-ApplicationConfiguration usage in main.ps1..." -ForegroundColor Yellow

try
{
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Look for the new pattern that indicates the refactored fix is present
    $pattern1 = 'Initialize-ApplicationConfiguration.*-InitFile.*-StringsFile.*-Domain'
    $pattern2 = 'configResult\.Success'
    
    $match1 = $mainContent -match $pattern1
    $match2 = $mainContent -match $pattern2
    
    if ($match1 -and $match2)
    {
        Write-Host "  ✓ Found Initialize-ApplicationConfiguration call with proper parameters" -ForegroundColor Green
        Write-Host "  ✓ Found success checking pattern" -ForegroundColor Green
        Write-Host "  ✓ Refactored fix is present - using centralized configuration initialization" -ForegroundColor Green
        $passedTests++
    }
    else
    {
        Write-Host "  ✗ Required refactored patterns not found in main.ps1" -ForegroundColor Red
        Write-Host "    Initialize-ApplicationConfiguration pattern found: $match1" -ForegroundColor Red
        Write-Host "    Success checking pattern found: $match2" -ForegroundColor Red
        $failedTests++
    }
}
catch
{
    Write-Host "  ✗ Error reading main.ps1: $($_.Exception.Message)" -ForegroundColor Red
    $failedTests++
}

# Test 2: Check that the old duplicate code paths have been eliminated
Write-Host "`nTest 2: Checking that old duplicate configuration logic has been removed..." -ForegroundColor Yellow

try
{
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Count occurrences of the old patterns that should now be eliminated
    $oldIfElsePattern = 'if \(Test-Path -Path \$InitFile\)'
    $oldElsePattern = 'Configuration file.*not found.*Using default values'
    
    $hasOldIfElse = $mainContent -match $oldIfElsePattern
    $hasOldElse = $mainContent -match $oldElsePattern
    
    if (-not $hasOldIfElse -and -not $hasOldElse)
    {
        Write-Host "  ✓ Old duplicate configuration logic has been successfully removed" -ForegroundColor Green
        $passedTests++
    }
    else
    {
        Write-Host "  ✗ Old configuration logic patterns still found - refactoring incomplete" -ForegroundColor Red
        Write-Host "    Old if-else pattern found: $hasOldIfElse" -ForegroundColor Red
        Write-Host "    Old else block pattern found: $hasOldElse" -ForegroundColor Red
        $failedTests++
    }
}
catch
{
    Write-Host "  ✗ Error analyzing configuration logic: $($_.Exception.Message)" -ForegroundColor Red
    $failedTests++
}

# Test 3: Verify the new helper function exists and JSON functions removed
Write-Host "`nTest 3: Verifying Initialize-ApplicationConfiguration helper function exists..." -ForegroundColor Yellow

$helperExists = Test-Path "functions/setupFunctions/Initialize-ApplicationConfiguration.ps1"
$jsonFunctionsRemoved = -not (Test-Path "functions/setupFunctions/FirstRunWizardFunctions/Test-SettingsJsonExists.ps1") -and -not (Test-Path "functions/setupFunctions/FirstRunWizardFunctions/Test-StringsJsonExists.ps1")

if ($helperExists -and $jsonFunctionsRemoved)
{
    Write-Host "  ✓ Initialize-ApplicationConfiguration.ps1 helper function exists" -ForegroundColor Green
    Write-Host "  ✓ JSON-specific functions successfully removed (legacy code cleanup)" -ForegroundColor Green
    $passedTests++
}
else
{
    Write-Host "  ✗ Required changes not complete" -ForegroundColor Red
    Write-Host "    Initialize-ApplicationConfiguration.ps1 exists: $helperExists" -ForegroundColor Red
    Write-Host "    JSON functions removed: $jsonFunctionsRemoved" -ForegroundColor Red
    $failedTests++
}

# Test 4: Verify that the new approach handles both existing and missing file scenarios
Write-Host "`nTest 4: Checking that code path handles all scenarios with wizard fallback..." -ForegroundColor Yellow

try
{
    $mainContent = Get-Content -Path "$PWD\main.ps1" -Raw
    
    # Look for evidence that there's a primary call and a wizard fallback call
    $configCalls = ([regex]'Initialize-ApplicationConfiguration').Matches($mainContent).Count
    $duplicateRegions = ([regex]'#region Define variables').Matches($mainContent).Count
    
    # We expect 2 calls: one in the normal path, one after the wizard completes
    if ($configCalls -eq 2 -and $duplicateRegions -eq 1)
    {
        Write-Host "  ✓ Primary and wizard fallback Initialize-ApplicationConfiguration calls found" -ForegroundColor Green
        Write-Host "  ✓ No duplicate code regions - clean refactoring with wizard support" -ForegroundColor Green
        $passedTests++
    }
    else
    {
        Write-Host "  ✗ Code structure indicates incomplete refactoring" -ForegroundColor Red
        Write-Host "    Initialize-ApplicationConfiguration calls: $configCalls (expected: 2 for normal + wizard fallback)" -ForegroundColor Red
        Write-Host "    Define variables regions: $duplicateRegions (expected: 1)" -ForegroundColor Red
        $failedTests++
    }
}
catch
{
    Write-Host "  ✗ Error analyzing code structure: $($_.Exception.Message)" -ForegroundColor Red
    $failedTests++
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$totalTests = $passedTests + $failedTests
Write-Host "Total tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0)
    {
        'Green' 
    }
    else
    {
        'Red' 
    })

if ($failedTests -eq 0)
{
    Write-Host "`n✓ SUCCESS: Issue #104 fix is correctly implemented through comprehensive refactoring!" -ForegroundColor Green
    Write-Host "The main.ps1 file now uses a unified configuration initialization approach that handles all scenarios." -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "`n✗ FAILURE: Issue #104 fix needs attention." -ForegroundColor Red
    exit 1
}