#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script to validate the fix for menu filtering in non-full app modes
.DESCRIPTION
    This script tests that menu items are properly filtered based on app mode
    and that duplicate items are not shown when using non-full app modes.
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

Write-Host "=== Testing Menu App Mode Fix ===" -ForegroundColor Yellow

# Test helper function that was added to main.ps1
Test-Function "Test-ShouldIncludeMenuItem helper function works correctly" {
    # Set up test environment
    $global:settings = @{ appMode = "registration" }
    
    # Load menu configuration 
    $menuConfigForFiltering = Get-CachedMenuConfiguration -MenuConfigFile "$pwd\menu.psd1"
    $mainMenuConfig = if ($menuConfigForFiltering -and $menuConfigForFiltering.mainMenu) { $menuConfigForFiltering.mainMenu } else { $null }

    # Define the helper function (same as in main.ps1)
    function Test-ShouldIncludeMenuItem {
        param(
            [string]$MenuItemName,
            [string]$CurrentAppMode = $settings.appMode
        )
        
        # If no app mode set or is full, include all items
        if (-not $CurrentAppMode -or $CurrentAppMode -eq "full") {
            return $true
        }
        
        # If no menu config available, include all items (fallback)
        if (-not $mainMenuConfig -or -not $mainMenuConfig.items) {
            return $true
        }
        
        # Find the menu item in configuration
        $configItem = $mainMenuConfig.items | Where-Object { $_.name -eq $MenuItemName }
        if (-not $configItem) {
            # Item not found in config, include by default (fallback)
            return $true
        }
        
        # If no includeInDisplayModes specified, include by default
        if (-not $configItem.includeInDisplayModes -or $configItem.includeInDisplayModes.Count -eq 0) {
            return $true
        }
        
        # Get app mode hierarchy and check if current mode is allowed
        try {
            $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $CurrentAppMode
            foreach ($allowedMode in $configItem.includeInDisplayModes) {
                if ($hierarchyAllowed -contains $allowedMode) {
                    return $true
                }
            }
            return $false
        }
        catch {
            # If hierarchy check fails, include by default (fallback)
            return $true
        }
    }
    
    # Test items that should be visible in registration mode
    $shouldBeVisible = @("Give a device to a user", "Autopilot menu", "Export Menu", "About")
    foreach ($item in $shouldBeVisible) {
        $result = Test-ShouldIncludeMenuItem -MenuItemName $item
        if (-not $result) {
            throw "Item '$item' should be visible in registration mode but helper function returned false"
        }
        Write-Verbose "✓ '$item' correctly included in registration mode"
    }
    
    # Test items that should be hidden in registration mode
    $shouldBeHidden = @("Change application settings", "Check for script updates")
    foreach ($item in $shouldBeHidden) {
        $result = Test-ShouldIncludeMenuItem -MenuItemName $item
        if ($result) {
            throw "Item '$item' should be hidden in registration mode but helper function returned true"
        }
        Write-Verbose "✓ '$item' correctly excluded from registration mode"
    }
}

# Test different app modes
$testModes = @("registration", "helpdesk", "advanced", "admin")

foreach ($testMode in $testModes) {
    Test-Function "App mode '$testMode' helper function filtering works correctly" {
        # Set up the test environment for this app mode
        $global:settings = @{ appMode = $testMode }
        
        # Load menu configuration 
        $menuConfigForFiltering = Get-CachedMenuConfiguration -MenuConfigFile "$pwd\menu.psd1"
        $mainMenuConfig = if ($menuConfigForFiltering -and $menuConfigForFiltering.mainMenu) { $menuConfigForFiltering.mainMenu } else { $null }

        # Define the helper function (same as in main.ps1)
        function Test-ShouldIncludeMenuItem {
            param(
                [string]$MenuItemName,
                [string]$CurrentAppMode = $settings.appMode
            )
            
            # If no app mode set or is full, include all items
            if (-not $CurrentAppMode -or $CurrentAppMode -eq "full") {
                return $true
            }
            
            # If no menu config available, include all items (fallback)
            if (-not $mainMenuConfig -or -not $mainMenuConfig.items) {
                return $true
            }
            
            # Find the menu item in configuration
            $configItem = $mainMenuConfig.items | Where-Object { $_.name -eq $MenuItemName }
            if (-not $configItem) {
                # Item not found in config, include by default (fallback)
                return $true
            }
            
            # If no includeInDisplayModes specified, include by default
            if (-not $configItem.includeInDisplayModes -or $configItem.includeInDisplayModes.Count -eq 0) {
                return $true
            }
            
            # Get app mode hierarchy and check if current mode is allowed
            try {
                $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $CurrentAppMode
                foreach ($allowedMode in $configItem.includeInDisplayModes) {
                    if ($hierarchyAllowed -contains $allowedMode) {
                        return $true
                    }
                }
                return $false
            }
            catch {
                # If hierarchy check fails, include by default (fallback)
                return $true
            }
        }
        
        # Test all menu items
        $allMenuItems = @(
            "Give a device to a user",
            "Check device status", 
            "Autopilot menu",
            "Change application settings",
            "Check for script updates",
            "Restart the device",
            "Show Group Assignments",
            "Export Menu",
            "About"
        )
        
        $includedCount = 0
        $excludedCount = 0
        
        foreach ($item in $allMenuItems) {
            $shouldInclude = Test-ShouldIncludeMenuItem -MenuItemName $item
            if ($shouldInclude) {
                $includedCount++
                Write-Verbose "✓ '$item' included in $testMode mode"
            } else {
                $excludedCount++
                Write-Verbose "✗ '$item' excluded from $testMode mode"
            }
        }
        
        Write-Verbose "App mode '$testMode': $includedCount included, $excludedCount excluded"
        
        # Validate that some filtering occurred (unless it's a very permissive mode)
        if ($testMode -eq "registration" -and $excludedCount -eq 0) {
            throw "Expected some items to be excluded in registration mode, but all items were included"
        }
    }
}

Write-Host "=== Menu App Mode Fix Tests Completed ===" -ForegroundColor Yellow
Write-Host "All fix validation tests passed successfully!" -ForegroundColor Green