#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for Initialize-MenuConfiguration function
.DESCRIPTION
    This test validates the Initialize-MenuConfiguration function including:
    - Menu file loading and processing
    - Missing key detection and merging with defaults
    - Preservation of existing menu configurations
    - Error handling for missing or invalid files
    - Return value structure (Menu and Changed properties)
.NOTES
    Author: Test Suite
    Version: 1.0.0
    Purpose: Ensure Initialize-MenuConfiguration works correctly across all scenarios
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
    $testContext = Start-UnifiedTest -TestName "Initialize-MenuConfiguration Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = Join-Path $testContext.TestFolder "test-menu-config.log"

# Track test results
$script:passedTests = 0
$script:failedTests = 0

try
{
    Write-TestSection "Test 1: Function Availability and Parameter Validation"
    
    $funcExists = Get-Command "Initialize-MenuConfiguration" -ErrorAction SilentlyContinue
    if ($funcExists)
    {
        Write-TestResult "Initialize-MenuConfiguration function is available" $true
        $script:passedTests++
        
        # Verify required parameters
        $params = $funcExists.Parameters
        if ($params.ContainsKey('MenuFilePath'))
        {
            Write-TestResult "MenuFilePath parameter exists" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "MenuFilePath parameter missing" $false
            $script:failedTests++
        }
    }
    else
    {
        Write-TestResult "Initialize-MenuConfiguration function not found" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 2: Loading Menu with Missing Keys"
    
    try
    {
        # Create a test menu file with missing keys
        $testMenuFile = Join-Path $testContext.TestFolder "test-menu.psd1"
        $testMenu = @{
            version     = '1.3.0.0'
            description = 'Test menu file'
            mainMenu    = @{
                Title       = 'Main Menu'
                Description = 'Please choose an option'
                items       = @()
                type        = 'static'
            }
        }
        
        # Export to file
        $testMenu | Export-PowerShellDataFile -Path $testMenuFile -Force
        
        # Initialize menu configuration
        $result = Initialize-MenuConfiguration -MenuFilePath $testMenuFile
        
        # Verify result structure
        if ($result.ContainsKey('Menu') -and $result.ContainsKey('Changed'))
        {
            Write-TestResult "Result contains expected properties (Menu, Changed)" $true
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
        if ($result.Menu.mainMenu.Title -eq "Main Menu")
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
        if ($result.Menu.ContainsKey('checkMenu'))
        {
            Write-TestResult "Missing keys added from defaults (checkMenu exists)" $true
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
        Write-TestResult "Error during menu loading test: $($_.Exception.Message)" $false
        $script:failedTests += 5
    }
    
    Write-TestSection "Test 3: Loading Complete Menu (No Missing Keys)"
    
    try
    {
        # Get complete default menu
        $defaultMenu = Get-ApplicationDefaults -DefaultType "Menus"
        
        # Create a test menu file with all keys
        $testMenuFile = Join-Path $testContext.TestFolder "test-menu-complete.psd1"
        $defaultMenu | Export-PowerShellDataFile -Path $testMenuFile -Force
        
        # Initialize menu configuration
        $result = Initialize-MenuConfiguration -MenuFilePath $testMenuFile
        
        # Verify no changes were needed
        if ($result.Changed -eq $false)
        {
            Write-TestResult "No changes needed for complete menu (Changed = false)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Unexpected changes detected for complete menu" $false
            $script:failedTests++
        }
        
        # Verify all keys are present
        if ($result.Menu.Keys.Count -eq $defaultMenu.Keys.Count)
        {
            Write-TestResult "All keys present in loaded menu" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Key count mismatch: Expected $($defaultMenu.Keys.Count), Got $($result.Menu.Keys.Count)" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during complete menu test: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 4: Handling Missing Menu File"
    
    try
    {
        $nonExistentFile = Join-Path $testContext.TestFolder "non-existent-menu.psd1"
        
        # Initialize with non-existent file
        $result = Initialize-MenuConfiguration -MenuFilePath $nonExistentFile
        
        # Verify empty menu returned
        if ($result.Menu.Keys.Count -eq 0)
        {
            Write-TestResult "Empty menu returned for missing file" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Non-empty menu returned for missing file" $false
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
    
    Write-TestSection "Test 5: Nested Menu Structure Merging"
    
    try
    {
        # Create menu with nested missing keys
        $testMenuFile = Join-Path $testContext.TestFolder "test-menu-nested.psd1"
        $testMenu = @{
            version         = '1.3.0.0'
            description     = 'Test menu file'
            mainMenu        = @{
                Title       = 'Main Menu'
                Description = 'Custom description'
                items       = @()
                type        = 'static'
            }
            appModeDefaults = @{
                full = @{
                    capabilities = @('all_menus')
                    # Missing: description
                }
            }
        }
        
        $testMenu | Export-PowerShellDataFile -Path $testMenuFile -Force
        
        # Initialize menu configuration
        $result = Initialize-MenuConfiguration -MenuFilePath $testMenuFile
        
        # Verify nested keys were added
        if ($result.Menu.ContainsKey('autopilotMenu'))
        {
            Write-TestResult "Missing top-level menu keys added (autopilotMenu)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Missing top-level menu keys not added" $false
            $script:failedTests++
        }
        
        # Verify existing nested values preserved
        if ($result.Menu.mainMenu.Description -eq "Custom description")
        {
            Write-TestResult "Nested existing values preserved" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Nested existing values not preserved" $false
            $script:failedTests++
        }
        
        # Verify appModeHierarchy was added (missing from test menu)
        if ($result.Menu.ContainsKey('appModeHierarchy'))
        {
            Write-TestResult "Missing menu sections added (appModeHierarchy)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Missing menu sections not added" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during nested structure test: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test 6: Menu Items Array Preservation"
    
    try
    {
        # Create menu with custom items
        $testMenuFile = Join-Path $testContext.TestFolder "test-menu-items.psd1"
        $testMenu = @{
            version  = '1.3.0.0'
            mainMenu = @{
                Title       = 'Main Menu'
                Description = 'Please choose an option'
                items       = @(
                    @{
                        name        = 'Custom Item 1'
                        description = 'This is custom'
                        blockType   = 'action'
                    }
                )
                type        = 'static'
            }
        }
        
        $testMenu | Export-PowerShellDataFile -Path $testMenuFile -Force
        
        # Initialize menu configuration
        $result = Initialize-MenuConfiguration -MenuFilePath $testMenuFile
        
        # Verify custom menu items preserved
        if ($result.Menu.mainMenu.items.Count -ge 1 -and 
            $result.Menu.mainMenu.items[0].name -eq 'Custom Item 1')
        {
            Write-TestResult "Custom menu items preserved" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Custom menu items not preserved" $false
            $script:failedTests++
        }
    }
    catch
    {
        Write-TestResult "Error during menu items test: $($_.Exception.Message)" $false
        $script:failedTests++
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
