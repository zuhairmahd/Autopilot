#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script to validate function loading in test environment
.DESCRIPTION
    This test validates that the test framework properly loads functions and 
    that they can be called within test scripts. This test helps diagnose
    function loading issues before running more complex tests.
.NOTES
    Author: Test Expansion Initiative
    Version: 1.0.0
    Purpose: Validate basic function loading for test framework reliability
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions at script level (same pattern as main.ps1)
Write-Host "=== Loading Functions at Script Level ===" -ForegroundColor Cyan
$functionsFolder = Join-Path $RootPath "functions"
if (Test-Path $functionsFolder)
{
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    $loadedCount = 0
    foreach ($function in $functions)
    {
        try
        {
            . $function.FullName
            $loadedCount++
        }
        catch
        {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "Loaded $loadedCount functions successfully" -ForegroundColor Green
}
else
{
    Write-Host "Cannot find the functions folder at: $functionsFolder. Exiting script." -ForegroundColor Red
    exit 1
}

# Use unified test framework (without function loading)
try
{
    # Initialize unified test environment (skip function loading as we did it above)
    $testContext = Start-UnifiedTest -TestName "Function Loading Validation Test" -SkipFunctionCheck
    
    Write-TestResult "Test environment initialized successfully" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try
{
    Write-TestSection "Test 1: Core Utility Functions"
    
    # Test Write-Log function
    Write-Host "Testing Write-Log function availability..." -ForegroundColor Cyan
    $writeLogAvailable = Get-Command "Write-Log" -ErrorAction SilentlyContinue
    if ($writeLogAvailable)
    {
        Write-TestResult "Write-Log function is available" $true
        
        # Test actual function call with safe parameters
        try
        {
            $testLogFile = "$PWD/test-function-loading.log"
            Write-Log -LogFile $testLogFile -Module "Test" -Message "Function loading test" -LogLevel "Information"
            Write-TestResult "Write-Log function executed successfully" $true
            
            # Clean up test log
            if (Test-Path $testLogFile)
            {
                Remove-Item $testLogFile -Force -ErrorAction SilentlyContinue
            }
        }
        catch
        {
            Write-TestResult "Write-Log function failed to execute: $($_.Exception.Message)" $false
        }
    }
    else
    {
        Write-TestResult "Write-Log function is not available" $false
    }
    
    Write-TestSection "Test 2: Setup Functions"
    
    # Test Get-ConfigurationData function (replacement for JSON functions) 
    Write-Host "Testing Get-ConfigurationData function availability..." -ForegroundColor Cyan
    $configDataAvailable = Get-Command "Get-ConfigurationData" -ErrorAction SilentlyContinue
    if ($configDataAvailable)
    {
        Write-TestResult "Get-ConfigurationData function is available" $true
        # Test basic execution
        try
        {
            $testResult = Get-ConfigurationData -ConfigurationPath "nonexistent" -DefaultValues @{test = "value"} -ErrorAction SilentlyContinue
            if ($testResult.test -eq "value")
            {
                Write-TestResult "Get-ConfigurationData function executed successfully" $true
            }
            else
            {
                Write-TestResult "Get-ConfigurationData function did not return expected defaults" $false
            }
        }
        catch
        {
            Write-TestResult "Get-ConfigurationData function execution failed: $($_.Exception.Message)" $false
        }
    }
    else
    {
        Write-TestResult "Get-ConfigurationData function is not available" $false
    }
    
    Write-TestSection "Test 3: Menu Functions"
    
    # Test Test-MenuItemIncluded function
    Write-Host "Testing Test-MenuItemIncluded function availability..." -ForegroundColor Cyan
    $menuTestAvailable = Get-Command "Test-MenuItemIncluded" -ErrorAction SilentlyContinue
    if ($menuTestAvailable)
    {
        Write-TestResult "Test-MenuItemIncluded function is available" $true
        
        # Test actual function call with proper global variables
        try
        {
            # Set up required global variables for the function
            $global:settings = @{ appMode = "full" }
            $global:LogFile = "$PWD/test.log"
            $result = Test-MenuItemIncluded -MenuItemName "Test Item" -Menus $null
            Write-TestResult "Test-MenuItemIncluded function executed successfully (returned: $result)" $true
        }
        catch
        {
            Write-TestResult "Test-MenuItemIncluded function failed to execute: $($_.Exception.Message)" $false
        }
    }
    else
    {
        Write-TestResult "Test-MenuItemIncluded function is not available" $false
    }
    
    Write-TestSection "Test 4: Function Loading Summary"
    
    # Get a count of loaded functions
    $totalFunctions = Get-Command -CommandType Function | Where-Object { $_.Source -eq "" -or $_.Source -like "*Autopilot*" }
    Write-Host "Total functions loaded: $($totalFunctions.Count)" -ForegroundColor Cyan
    
    # Test critical functions from each category
    $criticalFunctions = @(
        "Write-Log",
        "Get-ConfigurationData", 
        "Test-MenuItemIncluded",
        "MergeSettings",
        "GetNextUserReadinessReport",
        "Start-FirstRunWizard"
    )
    
    $availableFunctions = 0
    $missingFunctions = @()
    
    foreach ($functionName in $criticalFunctions)
    {
        $isAvailable = Get-Command $functionName -ErrorAction SilentlyContinue
        if ($isAvailable)
        {
            $availableFunctions++
            Write-Host "  ✓ $functionName" -ForegroundColor Green
        }
        else
        {
            $missingFunctions += $functionName
            Write-Host "  ✗ $functionName" -ForegroundColor Red
        }
    }
    
    Write-TestResult "Functions available: $availableFunctions/$($criticalFunctions.Count)" ($availableFunctions -eq $criticalFunctions.Count)
    
    if ($missingFunctions.Count -gt 0)
    {
        Write-Host "Missing functions:" -ForegroundColor Yellow
        foreach ($missing in $missingFunctions)
        {
            Write-Host "  - $missing" -ForegroundColor Red
        }
    }
    
    # Overall test result
    $testsPassed = if ($availableFunctions -eq $criticalFunctions.Count)
    {
        4 
    }
    else
    {
        3 
    }
    $testsFailed = 4 - $testsPassed
    
    Write-TestResult "Function loading validation completed" $true
}
catch
{
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    exit 1
}
finally
{
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $testsPassed -FailedTests $testsFailed -TotalTests 4
    
    if ($success)
    {
        Write-Host "Function Loading Validation Test passed! [PASS]" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "Function Loading Validation Test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}