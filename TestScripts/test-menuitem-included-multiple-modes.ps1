#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script to validate Test-MenuItemIncluded function with multiple app modes.

.DESCRIPTION
    Simple test to ensure that Test-MenuItemIncluded function properly handles
    multiple app modes as requested by the user, avoiding over-engineering.

.NOTES
    This test validates the core functionality that Test-MenuItemIncluded
    now works with multiple app modes through the enhanced Get-EffectiveAppModes
    and Get-CombinedAppModeHierarchy functions.
#>

param(
    [switch]$Verbose
)

# Test configuration
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rootPath = Split-Path -Parent $scriptPath
$logFile = Join-Path $scriptPath "test-menuitem-included-multiple-modes.log"

# Initialize variables needed by functions
$global:LogFile = $logFile
function Write-TestResult {
    param($TestName, $Result, $Details = "")
    $status = if ($Result) { "PASS" } else { "FAIL" }
    $color = if ($Result) { "Green" } else { "Red" }
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Write-TestSection {
    param($SectionName)
    Write-Host "`n=== $SectionName ===" -ForegroundColor Yellow
}

# Initialize test environment
Write-Host "Test-MenuItemIncluded Multiple App Modes Validation" -ForegroundColor Cyan
Write-Host "Root Path: $rootPath" -ForegroundColor Gray

# Load required functions
Write-TestSection "Loading Required Functions"

$requiredFunctions = @(
    "functions/menuFunctions/Get-EffectiveAppModes.ps1",
    "functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1", 
    "functions/menuFunctions/Test-MenuItemIncluded.ps1",
    "functions/utilityFunctions/Write-Log.ps1"
)

$loadedCount = 0
foreach ($func in $requiredFunctions) {
    $funcPath = Join-Path $rootPath $func
    if (Test-Path $funcPath) {
        try {
            . $funcPath
            $loadedCount++
            Write-TestResult "Loaded $func" $true
        } catch {
            Write-TestResult "Loaded $func" $false "Error: $($_.Exception.Message)"
        }
    } else {
        Write-TestResult "Found $func" $false "File not found"
    }
}

Write-TestResult "All required functions loaded" ($loadedCount -eq $requiredFunctions.Count) "$loadedCount/$($requiredFunctions.Count) loaded"

Write-TestSection "Basic Multiple App Mode Tests"

# Mock settings for testing
$script:settings = @{
    appModes = @('helpDesk', 'registration')
    appMode = 'helpDesk'  # Legacy compatibility
}

# Test 1: Get-EffectiveAppModes with multiple modes
try {
    $effectiveModes = Get-EffectiveAppModes -Settings $script:settings
    $isCorrect = ($effectiveModes -contains 'helpDesk') -and ($effectiveModes -contains 'registration') -and ($effectiveModes.Count -eq 2)
    Write-TestResult "Get-EffectiveAppModes returns multiple modes" $isCorrect "Returned: [$($effectiveModes -join ', ')]"
} catch {
    Write-TestResult "Get-EffectiveAppModes returns multiple modes" $false "Error: $($_.Exception.Message)"
}

# Test 2: Get-EffectiveAppModes with single mode fallback
try {
    $singleSettings = @{ appMode = 'admin' }
    $effectiveModes = Get-EffectiveAppModes -Settings $singleSettings
    $isCorrect = ($effectiveModes -contains 'admin') -and ($effectiveModes.Count -eq 1)
    Write-TestResult "Get-EffectiveAppModes single mode fallback" $isCorrect "Returned: [$($effectiveModes -join ', ')]"
} catch {
    Write-TestResult "Get-EffectiveAppModes single mode fallback" $false "Error: $($_.Exception.Message)"
}

# Test 3: Get-CombinedAppModeHierarchy with multiple modes  
try {
    $combinedHierarchy = Get-CombinedAppModeHierarchy -AppModes @('helpDesk', 'registration')
    $hasExpectedModes = ($combinedHierarchy -contains 'helpDesk') -and ($combinedHierarchy -contains 'registration')
    Write-TestResult "Get-CombinedAppModeHierarchy combines multiple modes" $hasExpectedModes "Combined: [$($combinedHierarchy -join ', ')]"
} catch {
    Write-TestResult "Get-CombinedAppModeHierarchy combines multiple modes" $false "Error: $($_.Exception.Message)"
}

Write-TestSection "Test-MenuItemIncluded Integration Tests"

# Create test menu items
$testMenuItems = @(
    [PSCustomObject]@{
        name = "Test Menu Item - Help Desk Only"
        includeInDisplayModes = @('helpDesk')
    },
    [PSCustomObject]@{
        name = "Test Menu Item - Registration Only" 
        includeInDisplayModes = @('registration')
    },
    [PSCustomObject]@{
        name = "Test Menu Item - Admin Only"
        includeInDisplayModes = @('admin')
    },
    [PSCustomObject]@{
        name = "Test Menu Item - No Restrictions"
    }
)

# Test 4: Help Desk mode item should be visible with helpDesk+registration
try {
    $result = Test-MenuItemIncluded -MenuItemName "Test Menu Item - Help Desk Only" -Menus $testMenuItems
    Write-TestResult "Help Desk only item visible with helpDesk+registration modes" $result
} catch {
    Write-TestResult "Help Desk only item visible with helpDesk+registration modes" $false "Error: $($_.Exception.Message)"
}

# Test 5: Registration mode item should be visible with helpDesk+registration  
try {
    $result = Test-MenuItemIncluded -MenuItemName "Test Menu Item - Registration Only" -Menus $testMenuItems
    Write-TestResult "Registration only item visible with helpDesk+registration modes" $result
} catch {
    Write-TestResult "Registration only item visible with helpDesk+registration modes" $false "Error: $($_.Exception.Message)"
}

# Test 6: Admin only item should NOT be visible with helpDesk+registration
try {
    $result = Test-MenuItemIncluded -MenuItemName "Test Menu Item - Admin Only" -Menus $testMenuItems
    Write-TestResult "Admin only item hidden with helpDesk+registration modes" (-not $result)
} catch {
    Write-TestResult "Admin only item hidden with helpDesk+registration modes" $false "Error: $($_.Exception.Message)"
}

# Test 7: No restrictions item should be visible
try {
    $result = Test-MenuItemIncluded -MenuItemName "Test Menu Item - No Restrictions" -Menus $testMenuItems  
    Write-TestResult "No restrictions item always visible" $result
} catch {
    Write-TestResult "No restrictions item always visible" $false "Error: $($_.Exception.Message)"
}

Write-TestSection "Full Mode Override Test"

# Test 8: Full mode should override and show everything
$script:settings = @{ appMode = 'full' }
try {
    $result = Test-MenuItemIncluded -MenuItemName "Test Menu Item - Admin Only" -Menus $testMenuItems
    Write-TestResult "Full mode shows admin only items" $result "Full mode should override all restrictions"
} catch {
    Write-TestResult "Full mode shows admin only items" $false "Error: $($_.Exception.Message)"
}

Write-TestSection "Test Summary"
Write-Host "Test-MenuItemIncluded multiple app modes validation completed" -ForegroundColor Green
Write-Host "This simplified approach uses the existing Test-MenuItemIncluded function" -ForegroundColor Gray
Write-Host "Enhanced with Get-EffectiveAppModes and Get-CombinedAppModeHierarchy support" -ForegroundColor Gray