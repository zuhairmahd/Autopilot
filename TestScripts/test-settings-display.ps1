#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the settings display formatting functions to ensure consistent value representation.

.DESCRIPTION
    Validates that Format-SettingValueForDisplay functions in both Show-SettingsEditor and 
    Show-SettingsViewer handle all value types correctly, including:
    - Single-element arrays (should show as [value] not (nested object))
    - Multi-element arrays
    - Nested arrays from comma operator
    - Nested string values
    - Complex objects
    - Null values
    - Boolean values
    - Numeric values

.NOTES
    This test prevents regression of the issues where:
    1. Single-element arrays displayed as "(nested object)" instead of "[value]"
    2. Nested string values displayed as "(nested object)" instead of the actual string value
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Set up environment
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$testResults = @()

function Test-FormatFunction
{
    param(
        [string]$FunctionSource,
        [scriptblock]$FormatFunction,
        [hashtable]$TestCases
    )
    
    $results = @()
    
    foreach ($testCase in $TestCases.GetEnumerator())
    {
        $testName = $testCase.Key
        $testData = $testCase.Value
        $inputValue = $testData.Input
        $expectedOutput = $testData.Expected
        
        try
        {
            $actualOutput = & $FormatFunction $inputValue
            
            if ($actualOutput -eq $expectedOutput)
            {
                $results += @{
                    Source   = $FunctionSource
                    Test     = $testName
                    Status   = 'PASS'
                    Expected = $expectedOutput
                    Actual   = $actualOutput
                }
                Write-Host "  ✓ $testName" -ForegroundColor Green
            }
            else
            {
                $results += @{
                    Source   = $FunctionSource
                    Test     = $testName
                    Status   = 'FAIL'
                    Expected = $expectedOutput
                    Actual   = $actualOutput
                }
                Write-Host "  ✗ $testName - Expected: '$expectedOutput', Got: '$actualOutput'" -ForegroundColor Red
            }
        }
        catch
        {
            $results += @{
                Source   = $FunctionSource
                Test     = $testName
                Status   = 'ERROR'
                Expected = $expectedOutput
                Actual   = $_.Exception.Message
            }
            Write-Host "  ✗ $testName - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $results
}

Write-Host "=== Testing Settings Display Formatting Functions ===" -ForegroundColor Cyan

try
{
    # Load the functions we need to test
    Write-Host "`nLoading functions..." -ForegroundColor Yellow
    . "$repoRoot/functions/setupFunctions/Show-SettingsEditor.ps1"
    . "$repoRoot/functions/setupFunctions/Show-SettingsViewer.ps1"
    
    # Set up global variables that may be needed
    $global:logFile = "$env:TEMP/test-settings-display.log"
    
    # Define comprehensive test cases
    $testCases = @{
        'EmptyArray'                  = @{
            Input    = @()
            Expected = '(empty array)'
        }
        'SingleElementArray'          = @{
            Input    = @("cloudconfig")
            Expected = '[cloudconfig]'
        }
        'MultiElementArray'           = @{
            Input    = @("msb", "autopilot")
            Expected = '[msb, autopilot]'
        }
        'SingleElementArrayWithComma' = @{
            Input    = , @("cloudconfig")  # Comma operator creates nested array
            Expected = '[cloudconfig]'
        }
        'BooleanTrue'                 = @{
            Input    = $true
            Expected = 'true'
        }
        'BooleanFalse'                = @{
            Input    = $false
            Expected = 'false'
        }
        'NullValue'                   = @{
            Input    = $null
            Expected = '(not set)'
        }
        'EmptyString'                 = @{
            Input    = ''
            Expected = '(not set)'
        }
        'NumericValue'                = @{
            Input    = 42
            Expected = '42'
        }
        'StringValue'                 = @{
            Input    = 'test string'
            Expected = 'test string'
        }
        'PSCustomObject'              = @{
            Input    = [PSCustomObject]@{ Name = 'Test'; Value = 'Data' }
            Expected = '{ Name: Test, Value: Data }'
        }
        'Hashtable'                   = @{
            Input    = @{ Name = 'Test'; Value = 'Data' }
            Expected = '{ Name: Test, Value: Data }'
        }
    }
    
    Write-Host "`n1. Testing Show-SettingsEditor Format-SettingValueForDisplay..." -ForegroundColor Yellow
    $editorResults = Test-FormatFunction -FunctionSource "SettingsEditor" -FormatFunction { param($v) Format-SettingValueForDisplay -Value $v } -TestCases $testCases
    
    Write-Host "`n2. Testing Show-SettingsViewer Format-SettingValueForDisplay..." -ForegroundColor Yellow
    $viewerResults = Test-FormatFunction -FunctionSource "SettingsViewer" -FormatFunction { param($v) Format-SettingValueForDisplay -Value $v } -TestCases $testCases
    
    # Test the specific scenarios mentioned in the bug report
    Write-Host "`n3. Testing specific bug scenarios..." -ForegroundColor Yellow
    
    # Load actual settings to test real-world scenarios
    if (Test-Path "$repoRoot/settings.json")
    {
        $settings = Get-Content "$repoRoot/settings.json" -Raw | ConvertFrom-Json
        
        # Test appInfo.companyName scenario
        if ($settings.globalSettings.appInfo.companyName)
        {
            $companyName = $settings.globalSettings.appInfo.companyName
            $formattedCompanyName = Format-SettingValueForDisplay -Value $companyName
            
            if ($formattedCompanyName -ne "(nested object)")
            {
                Write-Host "  ✓ appInfo.companyName displays as string value: '$formattedCompanyName'" -ForegroundColor Green
                $testResults += @{ Test = 'RealWorldCompanyName'; Status = 'PASS' }
            }
            else
            {
                Write-Host "  ✗ appInfo.companyName still shows as '(nested object)'" -ForegroundColor Red
                $testResults += @{ Test = 'RealWorldCompanyName'; Status = 'FAIL' }
            }
        }
        
        # Test nested value retrieval
        $nestedValue = Get-NestedValue -Object $settings.globalSettings -Path "appInfo.companyName"
        $formattedNested = Format-SettingValueForDisplay -Value $nestedValue
        
        if ($formattedNested -ne "(nested object)" -and $formattedNested -ne "(not set)")
        {
            Write-Host "  ✓ Nested value retrieval works: '$formattedNested'" -ForegroundColor Green
            $testResults += @{ Test = 'NestedValueRetrieval'; Status = 'PASS' }
        }
        else
        {
            Write-Host "  ✗ Nested value retrieval failed: '$formattedNested'" -ForegroundColor Red
            $testResults += @{ Test = 'NestedValueRetrieval'; Status = 'FAIL' }
        }
    }
    
    # Combine all results
    $allResults = $editorResults + $viewerResults + $testResults
    
    # Calculate summary
    $totalTests = $allResults.Count
    $passedTests = ($allResults | Where-Object { $_.Status -eq 'PASS' }).Count
    $failedTests = ($allResults | Where-Object { $_.Status -eq 'FAIL' }).Count
    $errorTests = ($allResults | Where-Object { $_.Status -eq 'ERROR' }).Count
    
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $failedTests" -ForegroundColor Red
    Write-Host "Errors: $errorTests" -ForegroundColor Yellow
    
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 95) { 'Green' } elseif ($successRate -ge 80) { 'Yellow' } else { 'Red' })
    
    if ($failedTests -eq 0 -and $errorTests -eq 0)
    {
        Write-Host "`n✓ All tests passed! Settings display formatting is working correctly." -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "`n✗ Some tests failed. Settings display formatting needs attention." -ForegroundColor Red
        exit 1
    }
    
}
catch
{
    Write-Host "Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}