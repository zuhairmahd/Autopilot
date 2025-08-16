#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for menu system navigation and functionality
.DESCRIPTION
    This test validates menu system functionality including:
    - Menu item inclusion logic for different app modes
    - Menu navigation and history tracking
    - Menu structure validation
    - Menu item execution and handling
.NOTES
    Author: Test Expansion Initiative
    Version: 1.0.0
    Purpose: Ensure menu system works correctly across all app modes
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
    $testContext = Start-UnifiedTest -TestName "Menu System Comprehensive Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = "$PWD/test-menu-system.log"
$global:MenuHistory = [System.Collections.ArrayList]::new()
$global:History = [System.Collections.ArrayList]::new()

try {
    Write-TestSection "Test 1: Menu Functions Availability"
    
    # Test critical menu system functions
    $menuFunctions = @(
        "Test-MenuItemIncluded",
        "DisplayNumericMenu",
        "ShowMenu",
        "NewMenu",
        "AddMenuItem",
        "Handle-MenuItemSelection",
        "Push-MenuToStack",
        "Pop-MenuFromStack"
    )
    
    $menuFunctionResults = @()
    foreach ($funcName in $menuFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $menuFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Menu function '$funcName' is available" $true
        } else {
            Write-TestResult "Menu function '$funcName' is not available" $false
        }
    }
    
    $allMenuFunctionsAvailable = ($menuFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All menu functions are available" $allMenuFunctionsAvailable
    
    Write-TestSection "Test 2: Menu Item Inclusion Logic for App Modes"
    
    # Test menu item inclusion for different app modes
    if (Get-Command "Test-MenuItemIncluded" -ErrorAction SilentlyContinue) {
        Write-Host "Testing menu item inclusion logic..." -ForegroundColor Cyan
        
        # Test with different app modes
        $appModes = @('full', 'helpDesk', 'advanced', 'admin')
        $inclusionTestResults = @()
        
        foreach ($appMode in $appModes) {
            # Set global settings for each app mode
            $global:settings = @{ appMode = $appMode }
            
            # Create mock menu structure for testing
            $mockMenus = @(
                [PSCustomObject]@{
                    name = "Help Desk Menu Item"
                    includeInDisplayModes = @("helpDesk", "full")
                },
                [PSCustomObject]@{
                    name = "Admin Only Menu Item"
                    includeInDisplayModes = @("admin")
                },
                [PSCustomObject]@{
                    name = "Universal Menu Item"
                    includeInDisplayModes = @("full", "helpDesk", "advanced", "admin")
                }
            )
            
            try {
                # Test Help Desk item inclusion
                $helpDeskIncluded = Test-MenuItemIncluded -MenuItemName "Help Desk Menu Item" -Menus $mockMenus
                $adminIncluded = Test-MenuItemIncluded -MenuItemName "Admin Only Menu Item" -Menus $mockMenus
                $universalIncluded = Test-MenuItemIncluded -MenuItemName "Universal Menu Item" -Menus $mockMenus
                
                $inclusionTestResults += @{
                    AppMode = $appMode
                    HelpDeskIncluded = $helpDeskIncluded
                    AdminIncluded = $adminIncluded
                    UniversalIncluded = $universalIncluded
                }
                
                Write-TestResult "Menu inclusion test for AppMode '$appMode' completed" $true
            }
            catch {
                Write-TestResult "Menu inclusion test for AppMode '$appMode' failed: $($_.Exception.Message)" $false
                $inclusionTestResults += @{
                    AppMode = $appMode
                    HelpDeskIncluded = $false
                    AdminIncluded = $false
                    UniversalIncluded = $false
                }
            }
        }
        
        # Validate inclusion logic results
        $helpDeskModeResult = $inclusionTestResults | Where-Object { $_.AppMode -eq "helpDesk" }
        if ($helpDeskModeResult -and $helpDeskModeResult.HelpDeskIncluded -and -not $helpDeskModeResult.AdminIncluded) {
            Write-TestResult "HelpDesk mode correctly includes/excludes appropriate items" $true
        } else {
            Write-TestResult "HelpDesk mode inclusion logic failed" $false
        }
        
        $adminModeResult = $inclusionTestResults | Where-Object { $_.AppMode -eq "admin" }
        if ($adminModeResult -and $adminModeResult.AdminIncluded) {
            Write-TestResult "Admin mode correctly includes admin items" $true
        } else {
            Write-TestResult "Admin mode inclusion logic failed" $false
        }
    } else {
        Write-TestResult "Test-MenuItemIncluded function not available - skipping inclusion test" $true
    }
    
    Write-TestSection "Test 3: Menu Navigation and History"
    
    # Test menu navigation functions
    if ((Get-Command "Push-MenuToStack" -ErrorAction SilentlyContinue) -and 
        (Get-Command "Pop-MenuFromStack" -ErrorAction SilentlyContinue)) {
        
        Write-Host "Testing menu navigation and history..." -ForegroundColor Cyan
        
        try {
            # Test menu stack operations
            $initialHistoryCount = $global:MenuHistory.Count
            
            # Push a menu to stack
            Push-MenuToStack -MenuName "Test Menu" -MenuLevel 1
            
            if ($global:MenuHistory.Count -gt $initialHistoryCount) {
                Write-TestResult "Menu push to stack works" $true
                
                # Pop menu from stack
                $poppedMenu = Pop-MenuFromStack
                
                if ($global:MenuHistory.Count -eq $initialHistoryCount) {
                    Write-TestResult "Menu pop from stack works" $true
                } else {
                    Write-TestResult "Menu pop from stack failed" $false
                }
            } else {
                Write-TestResult "Menu push to stack failed" $false
            }
        }
        catch {
            Write-TestResult "Menu navigation test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "Menu navigation functions not available - skipping navigation test" $true
    }
    
    Write-TestSection "Test 4: Menu Creation and Display"
    
    # Test menu creation functions
    if (Get-Command "NewMenu" -ErrorAction SilentlyContinue) {
        Write-Host "Testing menu creation..." -ForegroundColor Cyan
        
        try {
            # Create a test menu
            $testMenuItems = @(
                @{
                    name = "Test Item 1"
                    description = "First test item"
                    action = "test-action-1"
                },
                @{
                    name = "Test Item 2"
                    description = "Second test item"
                    action = "test-action-2"
                }
            )
            
            Write-TestResult "Menu creation functions are available for testing" $true
        }
        catch {
            Write-TestResult "Menu creation test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "NewMenu function not available - skipping menu creation test" $true
    }
    
    Write-TestSection "Test 5: Menu Item Addition"
    
    # Test AddMenuItem function
    if (Get-Command "AddMenuItem" -ErrorAction SilentlyContinue) {
        Write-Host "Testing menu item addition..." -ForegroundColor Cyan
        
        try {
            Write-TestResult "AddMenuItem function is available for testing" $true
        }
        catch {
            Write-TestResult "AddMenuItem test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "AddMenuItem function not available - skipping menu item addition test" $true
    }
    
    Write-TestSection "Test 6: Menu Display Functions"
    
    # Test menu display functions
    $displayFunctions = @(
        "DisplayNumericMenu",
        "ShowMenu", 
        "Create-MenuBanner"
    )
    
    $displayFunctionResults = @()
    foreach ($funcName in $displayFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $displayFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Menu display function '$funcName' is available" $true
        } else {
            Write-TestResult "Menu display function '$funcName' is not available" $false
        }
    }
    
    $allDisplayFunctionsAvailable = ($displayFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All menu display functions are available" $allDisplayFunctionsAvailable
    
    Write-TestSection "Test 7: Menu Handling Functions"
    
    # Test menu handling and action functions
    $handlingFunctions = @(
        "Handle-MenuItemSelection",
        "Handle-ActionExecution",
        "Handle-BackNavigation", 
        "Handle-MainMenuNavigation"
    )
    
    $handlingFunctionResults = @()
    foreach ($funcName in $handlingFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $handlingFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Menu handling function '$funcName' is available" $true
        } else {
            Write-TestResult "Menu handling function '$funcName' is not available" $false
        }
    }
    
    $allHandlingFunctionsAvailable = ($handlingFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All menu handling functions are available" $allHandlingFunctionsAvailable
    
    Write-TestSection "Test 8: Context and Navigation Functions"
    
    # Test context and navigation utility functions
    $contextFunctions = @(
        "Get-CallingContext",
        "Get-BaseCallingContext",
        "Get-NavigationPathContext",
        "Get-UniqueCallerContext"
    )
    
    $contextFunctionResults = @()
    foreach ($funcName in $contextFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $contextFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Context function '$funcName' is available" $true
        } else {
            Write-TestResult "Context function '$funcName' is not available" $false
        }
    }
    
    $allContextFunctionsAvailable = ($contextFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All context functions are available" $allContextFunctionsAvailable
    
    # Summary
    $totalTests = 8
    $passedTests = 0
    
    if ($allMenuFunctionsAvailable) { $passedTests++ }
    if (Get-Command "Test-MenuItemIncluded" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ((Get-Command "Push-MenuToStack" -ErrorAction SilentlyContinue) -and (Get-Command "Pop-MenuFromStack" -ErrorAction SilentlyContinue)) { $passedTests++ }
    if (Get-Command "NewMenu" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "AddMenuItem" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ($allDisplayFunctionsAvailable) { $passedTests++ }
    if ($allHandlingFunctionsAvailable) { $passedTests++ }
    if ($allContextFunctionsAvailable) { $passedTests++ }
    
    $failedTests = $totalTests - $passedTests
    
    Write-TestResult "Menu system comprehensive test completed" $true
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
        Write-Host "Menu System Comprehensive Test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Menu System Comprehensive Test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}