#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for Initialize-StringsConfiguration function
.DESCRIPTION
    This test validates the Initialize-StringsConfiguration function including:
    - Strings file loading and processing
    - Missing key detection and merging with defaults
    - Preservation of existing values
    - Error handling for missing or invalid files
    - Return value structure (Strings and Changed properties)
.NOTES
    Author: Test Suite
    Version: 1.0.0
    Purpose: Ensure Initialize-StringsConfiguration works correctly across all scenarios
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions at script level (same pattern as main.ps1)
$functionsFolder = Join-Path $RootPath "functions"
if (Test-Path $functionsFolder)
{
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions)
    {
        try
        {
            . $function.FullName
        }
        catch
        {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
}
else
{
    Write-Host "Cannot find the functions folder at: $functionsFolder. Exiting script." -ForegroundColor Red
    exit 1
}

# Initialize test environment
try
{
    $testContext = Start-UnifiedTest -TestName "Initialize-StringsConfiguration Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = Join-Path $testContext.TestFolder "test-strings-config.log"

# Track test results
$script:passedTests = 0
$script:failedTests = 0

try
{
    Write-TestSection "Test 1: Function Availability and Parameter Validation"
    
    $funcExists = Get-Command "Initialize-StringsConfiguration" -ErrorAction SilentlyContinue
    if ($funcExists)
    {
        Write-TestResult "Initialize-StringsConfiguration function is available" $true
        $script:passedTests++
        
        # Verify required parameters
        $params = $funcExists.Parameters
        if ($params.ContainsKey('StringsFilePath'))
        {
            Write-TestResult "StringsFilePath parameter exists" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "StringsFilePath parameter missing" $false
            $script:failedTests++
        }
    }
    else
    {
        Write-TestResult "Initialize-StringsConfiguration function not found" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 2: Loading Strings with Missing Keys"
    
    try
    {
        # Create a test strings file with missing keys
        $testStringsFile = Join-Path $testContext.TestFolder "test-strings.psd1"
        $testStrings = @{
            Description   = "Test strings file"
            deviceActions = @{
                none = "No action"
            }
        }
        
        # Export to file
        $testStrings | Export-PowerShellDataFile -Path $testStringsFile -Force
        
        # Initialize strings configuration
        $result = Initialize-StringsConfiguration -StringsFilePath $testStringsFile
        
        # Verify result structure
        if ($result.ContainsKey('Strings') -and $result.ContainsKey('Changed'))
        {
            Write-TestResult "Result contains expected properties (Strings, Changed)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Result missing expected properties" $false
            $script:failedTests++
        }
        
        # Verify that missing keys were detected and merged
        if ($result.Changed -eq $true)
        {
            Write-TestResult "Missing keys detected and merged (Changed = true)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Missing keys not detected (Changed = false)" $false
            $script:failedTests++
        }
        
        # Verify that existing values were preserved
        if ($result.Strings.deviceActions.none -eq "No action")
        {
            Write-TestResult "Existing values preserved" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Existing values not preserved" $false
            $script:failedTests++
        }
        
        # Verify that new keys were added from defaults
        if ($result.Strings.ContainsKey('returnValues'))
        {
            Write-TestResult "Missing keys added from defaults (returnValues exists)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Missing keys not added from defaults" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during strings loading test: $($_.Exception.Message)" $false
        $script:failedTests += 5
    }
    
    Write-TestSection "Test 3: Loading Complete Strings (No Missing Keys)"
    
    try
    {
        # Get complete default strings
        $defaultStrings = Get-ApplicationDefaults -DefaultType "Strings"
        
        # Create a test strings file with all keys
        $testStringsFile = Join-Path $testContext.TestFolder "test-strings-complete.psd1"
        $defaultStrings | Export-PowerShellDataFile -Path $testStringsFile -Force
        
        # Initialize strings configuration
        $result = Initialize-StringsConfiguration -StringsFilePath $testStringsFile
        
        # Verify no changes were needed
        if ($result.Changed -eq $false)
        {
            Write-TestResult "No changes needed for complete strings (Changed = false)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Unexpected changes detected for complete strings" $false
            $script:failedTests++
        }
        
        # Verify all keys are present
        if ($result.Strings.Keys.Count -eq $defaultStrings.Keys.Count)
        {
            Write-TestResult "All keys present in loaded strings" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Key count mismatch: Expected $($defaultStrings.Keys.Count), Got $($result.Strings.Keys.Count)" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during complete strings test: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 4: Handling Missing Strings File"
    
    try
    {
        $nonExistentFile = Join-Path $testContext.TestFolder "non-existent-strings.psd1"
        
        # Initialize with non-existent file
        $result = Initialize-StringsConfiguration -StringsFilePath $nonExistentFile
        
        # Verify empty strings returned
        if ($result.Strings.Keys.Count -eq 0)
        {
            Write-TestResult "Empty strings returned for missing file" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Non-empty strings returned for missing file" $false
            $script:failedTests++
        }
        
        # Verify Changed is false
        if ($result.Changed -eq $false)
        {
            Write-TestResult "Changed = false for missing file" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Changed = true for missing file (unexpected)" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during missing file test: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 5: Nested Hashtable Merging"
    
    try
    {
        # Create strings with nested missing keys
        $testStringsFile = Join-Path $testContext.TestFolder "test-strings-nested.psd1"
        $testStrings = @{
            Description   = "Test strings file"
            deviceActions = @{
                none = "No action"
                # Missing: contactAdmin, contactHelpdesk, WipeOrClean
            }
            deviceStates  = @{
                Ready = "Device is ready"
                # Missing: NotReady
            }
        }
        
        $testStrings | Export-PowerShellDataFile -Path $testStringsFile -Force
        
        # Initialize strings configuration
        $result = Initialize-StringsConfiguration -StringsFilePath $testStringsFile
        
        # Verify nested keys were added
        if ($result.Strings.deviceActions.ContainsKey('contactAdmin'))
        {
            Write-TestResult "Nested missing keys added (deviceActions.contactAdmin)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Nested missing keys not added" $false
            $script:failedTests++
        }
        
        if ($result.Strings.deviceStates.ContainsKey('NotReady'))
        {
            Write-TestResult "Nested missing keys added (deviceStates.NotReady)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Nested missing keys not added" $false
            $script:failedTests++
        }
        
        # Verify existing nested values preserved
        if ($result.Strings.deviceActions.none -eq "No action")
        {
            Write-TestResult "Nested existing values preserved" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Nested existing values not preserved" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during nested hashtable test: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test Summary"
    $totalTests = $script:passedTests + $script:failedTests
    Write-TestResult "Tests Passed: $($script:passedTests)/$totalTests" ($script:failedTests -eq 0)
    Write-TestResult "Tests Failed: $($script:failedTests)/$totalTests" ($script:failedTests -eq 0)
}
catch
{
    Write-Host "Unexpected error during test execution: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
finally
{
    # Clean up
    try
    {
        Stop-UnifiedTest -TestContext $testContext
    }
    catch
    {
        Write-Warning "Error during test cleanup: $($_.Exception.Message)"
    }
}

# Exit with appropriate code
if ($script:failedTests -eq 0)
{
    exit 0
}
else
{
    exit 1
}
