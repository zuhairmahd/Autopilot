#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests menu filtering with multiple app modes to ensure proper menu item visibility
.DESCRIPTION
    This script validates that menu items are properly filtered based on app modes,
    ensuring that users only see menu items appropriate for their assigned modes.
#>

# Test configuration
$testName = "Menu Filtering with Multiple App Modes"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath

# Test results tracking
$testResults = @()

function Write-TestSection {
    param([string]$SectionName)
    Write-Host "`n=== $SectionName ===" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Result,
        [string]$Details = ""
    )
    $status = if ($Result) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($Result) { "Green" } else { "Red" }
    Write-Host "$status - $TestName" -ForegroundColor $color
    if ($Details) { Write-Host "    $Details" -ForegroundColor Gray }
    
    $script:testResults += @{
        TestName = $TestName
        Result = $Result
        Details = $Details
    }
}

function Test-MenuFiltering {
    param(
        [array]$AppModes,
        [array]$ExpectedVisibleItems,
        [array]$ExpectedHiddenItems,
        [string]$TestDescription
    )
    
    Write-TestSection "Testing: $TestDescription"
    Write-Host "App Modes: [$($AppModes -join ', ')]" -ForegroundColor Yellow
    
    # Mock the settings and menu configuration
    $mockSettings = @{
        appModes = $AppModes
        appMode = $AppModes[0]
        domain = "test.com"
    }
    
    # Mock the global settings variable that main.ps1 expects
    $global:settings = $mockSettings
    
    # Load required functions
    try {
        . "$rootPath/functions/menuFunctions/Get-EffectiveAppModes.ps1"
        . "$rootPath/functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1"
        . "$rootPath/functions/menuFunctions/Get-AppModeHierarchy.ps1"
    } catch {
        Write-TestResult "Load dependencies for $TestDescription" $false "Failed to load required functions: $($_.Exception.Message)"
        return
    }
    
    # Test menu item visibility for each expected visible item
    $allVisibleCorrect = $true
    $allHiddenCorrect = $true
    
    foreach ($visibleItem in $ExpectedVisibleItems) {
        $mockMenuConfig = @{
            mainMenu = @{
                items = @(
                    @{
                        name = $visibleItem
                        includeInDisplayModes = Get-ExpectedModesForMenuItem $visibleItem
                    }
                )
            }
        }
        
        # Mock the menu configuration file
        $mockMenuFile = "$rootPath/menu.psd1"
        if (Test-Path $mockMenuFile) {
            $realMenuConfig = Get-Content $mockMenuFile -Raw | Invoke-Expression
            $menuItem = $realMenuConfig.mainMenu.items | Where-Object { $_.name -eq $visibleItem }
            
            if ($menuItem) {
                # Test if this item should be visible
                $shouldBeVisible = Test-AppModeAllowsMenuItem -AppModes $AppModes -RequiredModes $menuItem.includeInDisplayModes
                
                if ($shouldBeVisible) {
                    Write-TestResult "Menu item '$visibleItem' correctly visible" $true "Required modes: [$($menuItem.includeInDisplayModes -join ', ')], User modes: [$($AppModes -join ', ')]"
                } else {
                    Write-TestResult "Menu item '$visibleItem' incorrectly hidden" $false "Required modes: [$($menuItem.includeInDisplayModes -join ', ')], User modes: [$($AppModes -join ', ')]"
                    $allVisibleCorrect = $false
                }
            }
        }
    }
    
    foreach ($hiddenItem in $ExpectedHiddenItems) {
        $mockMenuFile = "$rootPath/menu.psd1"
        if (Test-Path $mockMenuFile) {
            $realMenuConfig = Get-Content $mockMenuFile -Raw | Invoke-Expression
            $menuItem = $realMenuConfig.mainMenu.items | Where-Object { $_.name -eq $hiddenItem }
            
            if ($menuItem) {
                # Test if this item should be hidden
                $shouldBeVisible = Test-AppModeAllowsMenuItem -AppModes $AppModes -RequiredModes $menuItem.includeInDisplayModes
                
                if (-not $shouldBeVisible) {
                    Write-TestResult "Menu item '$hiddenItem' correctly hidden" $true "Required modes: [$($menuItem.includeInDisplayModes -join ', ')], User modes: [$($AppModes -join ', ')]"
                } else {
                    Write-TestResult "Menu item '$hiddenItem' incorrectly visible" $false "Required modes: [$($menuItem.includeInDisplayModes -join ', ')], User modes: [$($AppModes -join ', ')]"
                    $allHiddenCorrect = $false
                }
            }
        }
    }
    
    $overallResult = $allVisibleCorrect -and $allHiddenCorrect
    Write-TestResult "Overall filtering for $TestDescription" $overallResult
    
    return $overallResult
}

function Test-AppModeAllowsMenuItem {
    param(
        [array]$AppModes,
        [array]$RequiredModes
    )
    
    # Use the same logic as Get-CombinedAppModeHierarchy
    try {
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes $AppModes -ResolutionStrategy 'Additive'
        $effectivePermissions = $combinedResult.AllowedModes
        
        # Check if any effective permission is in the required modes
        foreach ($permission in $effectivePermissions) {
            if ($permission -in $RequiredModes) {
                return $true
            }
        }
        return $false
    } catch {
        # Fallback to basic check
        foreach ($mode in $AppModes) {
            if ($mode -in $RequiredModes) {
                return $true
            }
        }
        return $false
    }
}

# Start testing
Write-Host "Starting $testName" -ForegroundColor Green
Write-Host "Root Path: $rootPath" -ForegroundColor Gray

# Test 1: Help Desk + Registration modes (user's reported issue)
$testResult1 = Test-MenuFiltering -AppModes @('helpDesk', 'registration') -TestDescription "Help Desk + Registration (User Issue)" `
    -ExpectedVisibleItems @('Give a device to a user', 'Check device status', 'Autopilot menu', 'Check for script updates', 'Restart the device', 'About') `
    -ExpectedHiddenItems @('Change application settings', 'Show Group Assignments', 'Export Menu')

# Test 2: Admin mode (should see everything except custom-specific items)
$testResult2 = Test-MenuFiltering -AppModes @('admin') -TestDescription "Admin Mode (Full Access)" `
    -ExpectedVisibleItems @('Give a device to a user', 'Check device status', 'Autopilot menu', 'Change application settings', 'Check for script updates', 'Restart the device', 'Show Group Assignments', 'Export Menu', 'About') `
    -ExpectedHiddenItems @()

# Test 3: Registration only mode
$testResult3 = Test-MenuFiltering -AppModes @('registration') -TestDescription "Registration Only Mode" `
    -ExpectedVisibleItems @('Give a device to a user', 'Autopilot menu', 'Check for script updates', 'Export Menu', 'About') `
    -ExpectedHiddenItems @('Check device status', 'Change application settings', 'Restart the device', 'Show Group Assignments')

# Test 4: Full mode (should see everything)
$testResult4 = Test-MenuFiltering -AppModes @('full') -TestDescription "Full Mode (All Access)" `
    -ExpectedVisibleItems @('Give a device to a user', 'Check device status', 'Autopilot menu', 'Change application settings', 'Check for script updates', 'Restart the device', 'Show Group Assignments', 'Export Menu', 'About') `
    -ExpectedHiddenItems @()

# Test 5: Advanced + Registration combination
$testResult5 = Test-MenuFiltering -AppModes @('advanced', 'registration') -TestDescription "Advanced + Registration Combination" `
    -ExpectedVisibleItems @('Give a device to a user', 'Check device status', 'Autopilot menu', 'Change application settings', 'Check for script updates', 'Restart the device', 'Show Group Assignments', 'Export Menu', 'About') `
    -ExpectedHiddenItems @()

# Summary
Write-TestSection "Test Summary"
$passedTests = ($testResults | Where-Object { $_.Result }).Count
$totalTests = $testResults.Count
$passRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }

Write-Host "Tests Passed: $passedTests / $totalTests ($passRate%)" -ForegroundColor $(if ($passRate -eq 100) { "Green" } else { "Yellow" })

if ($passRate -lt 100) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Result } | ForEach-Object {
        Write-Host "  ✗ $($_.TestName)" -ForegroundColor Red
        if ($_.Details) { Write-Host "    $($_.Details)" -ForegroundColor Gray }
    }
}

# Exit with appropriate code
exit $(if ($passRate -eq 100) { 0 } else { 1 })