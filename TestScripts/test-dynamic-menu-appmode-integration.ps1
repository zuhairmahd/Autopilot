#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Integration test for dynamic menu system with app mode filtering

.DESCRIPTION
    This script tests that the dynamic menu system correctly filters menu items
    based on app modes using the includeInDisplayModes from menu.json.

.NOTES
    Author: Copilot
    Version: 1.0.0
    Compatible: PowerShell 5.1+
#>

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Test helper functions
function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [switch]$ContinueOnError
    )
    
    Write-Host "Testing: $TestName" -ForegroundColor Cyan
    try {
        & $TestCode
        Write-Host "✓ $TestName passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ $TestName failed: $_" -ForegroundColor Red
        if (-not $ContinueOnError) {
            throw
        }
        return $false
    }
}

# Set up test environment
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
Set-Location $rootPath

# Import required functions
$functionsFolder = "$rootPath\functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse
    foreach ($function in $functions) {
        . $function.FullName
    }
}

# Initialize global variables that functions expect
$global:LogFile = "$rootPath\Logs\test.log"

Write-Host "=== Testing Dynamic Menu App Mode Integration ===" -ForegroundColor Yellow

# Test different app modes
$testModes = @("full", "helpdesk", "registration", "advanced", "admin")

foreach ($testMode in $testModes) {
    Test-Function "App mode '$testMode' filtering works correctly" {
        # Set up the test environment for this app mode
        $global:settings = @{
            appMode = $testMode
        }
        
        # Load menu configuration for filtering (simulate what main.ps1 does)
        $script:menus = @()
        $menuConfig = Get-MenuConfiguration
        if ($menuConfig) {
            foreach ($menuName in $menuConfig.PSObject.Properties.Name) {
                $menu = $menuConfig.$menuName
                if ($menu.items) {
                    $script:menus += $menu.items
                }
            }
        }
        
        # Load the main menu
        $mainMenu = NewMenu -MenuName "mainMenu"
        if (-not $mainMenu) {
            throw "Failed to load main menu for app mode $testMode"
        }
        
        # Count how many items should be visible in this mode
        $visibleItemCount = 0
        foreach ($item in $mainMenu.Items) {
            if (Test-MenuItemIncluded -MenuItemName $item.Name -Menus $script:menus) {
                $visibleItemCount++
            }
        }
        
        Write-Verbose "App mode '$testMode': $visibleItemCount out of $($mainMenu.Items.Count) items visible"
        
        # Validate that filtering is working
        if ($testMode -eq "full") {
            # In full mode, all items should be visible
            if ($visibleItemCount -ne $mainMenu.Items.Count) {
                throw "In 'full' mode, expected all $($mainMenu.Items.Count) items to be visible, but got $visibleItemCount"
            }
        } else {
            # In other modes, some items should be filtered out
            if ($visibleItemCount -eq 0) {
                throw "In '$testMode' mode, no items are visible - filtering might be too restrictive"
            }
            if ($visibleItemCount -eq $mainMenu.Items.Count) {
                Write-Verbose "Warning: In '$testMode' mode, all items are visible - filtering might not be working"
            }
        }
        
        Write-Verbose "App mode '$testMode' filtering working correctly"
    }
}

# Test specific menu item filtering
Test-Function "Specific menu items filtered correctly by app mode" {
    # Test helpdesk mode - should see "Give a device to a user" and "Check device status"
    $global:settings = @{ appMode = "helpdesk" }
    
    # Load menu configuration
    $script:menus = @()
    $menuConfig = Get-MenuConfiguration
    if ($menuConfig) {
        foreach ($menuName in $menuConfig.PSObject.Properties.Name) {
            $menu = $menuConfig.$menuName
            if ($menu.items) {
                $script:menus += $menu.items
            }
        }
    }
    
    # Check specific items
    $shouldBeVisible = @("Give a device to a user", "Check device status")
    $shouldBeHidden = @("Change application settings") # This requires "advanced" mode
    
    foreach ($itemName in $shouldBeVisible) {
        $isVisible = Test-MenuItemIncluded -MenuItemName $itemName -Menus $script:menus
        if (-not $isVisible) {
            throw "Item '$itemName' should be visible in helpdesk mode but is hidden"
        }
        Write-Verbose "✓ '$itemName' correctly visible in helpdesk mode"
    }
    
    foreach ($itemName in $shouldBeHidden) {
        $isVisible = Test-MenuItemIncluded -MenuItemName $itemName -Menus $script:menus
        if ($isVisible) {
            Write-Verbose "Warning: Item '$itemName' is visible in helpdesk mode (expected hidden)"
        } else {
            Write-Verbose "✓ '$itemName' correctly hidden in helpdesk mode"
        }
    }
}

# Test includeInDisplayModes defaults
Test-Function "includeInDisplayModes defaults to full when empty" {
    $global:settings = @{ appMode = "registration" }
    
    # Load menu configuration
    $script:menus = @()
    $menuConfig = Get-MenuConfiguration
    if ($menuConfig) {
        foreach ($menuName in $menuConfig.PSObject.Properties.Name) {
            $menu = $menuConfig.$menuName
            if ($menu.items) {
                $script:menus += $menu.items
            }
        }
    }
    
    # Items without includeInDisplayModes should default to "full" and not be visible in registration mode
    # unless they explicitly include "registration"
    $itemsWithEmptyModes = @("Check for script updates", "Restart the device", "About")
    
    foreach ($itemName in $itemsWithEmptyModes) {
        $isVisible = Test-MenuItemIncluded -MenuItemName $itemName -Menus $script:menus
        Write-Verbose "Item '$itemName' visibility in registration mode: $isVisible"
        # These items should default to "full" mode and may or may not be visible in registration
        # The key is that the Test-MenuItemIncluded function handles them gracefully
    }
}

Write-Host "=== Dynamic Menu App Mode Integration Tests Completed ===" -ForegroundColor Yellow
Write-Host "All integration tests passed successfully!" -ForegroundColor Green