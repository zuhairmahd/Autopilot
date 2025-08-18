#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests menu order preservation in Test-MenuJsonExists function.

.DESCRIPTION
    Validates that when menu.json is created from defaults, the order of menu items
    matches the expected user experience as demonstrated in the UI screens.
    This addresses the issue where menu items appeared in random order due to
    unordered hashtables being used in PowerShell 5.1.

.NOTES
    Expected main menu order:
    1. Give a device to a user
    2. Check device status  
    3. Autopilot menu
    4. Change application settings
    5. Check for script updates
    6. Restart the device
    7. Show Group Assignments
    8. Export Menu
    9. About

    Expected device actions menu order:
    1. Wipe Device
    2. Clean Device
    3. Sync Device
    4. Get LAPS Password
    5. Get BitLocker Recovery Key
    6. Get Hardware Password Details
    7. Restart Device
    8. Show Device Health Status
    9. Check next user readiness state
#>

# Test configuration
$tempMenuFile = "/tmp/test_menu_order.json"
$testPassed = 0
$testFailed = 0

# Import required functions
try {
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/Test-MenuJsonExists.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertTo-OrderedJson.ps1"  
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/ConvertFrom-JsonToHashtable.ps1"
    . "$PSScriptRoot/../functions/setupFunctions/FirstRunWizardFunctions/Merge-ConfigurationDefaults.ps1"
}
catch {
    Write-Host "Error loading functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Mock required variables
$version = @{ version = @{ toString = { "1.0.0.0" } } }
$maxJSONDepth = 10
$LogFile = "/tmp/test.log"

Write-Host "Testing menu order preservation in Test-MenuJsonExists" -ForegroundColor Cyan

# Test 1: Main Menu Order
Write-Host "Test 1: Verifying main menu item order preservation"
try {
    # Clean up any existing test file
    if (Test-Path $tempMenuFile) { Remove-Item $tempMenuFile -Force }
    
    # Create new menu.json from defaults
    $result = Test-MenuJsonExists -MenuFile $tempMenuFile -Silent
    
    if ($result -and (Test-Path $tempMenuFile)) {
        $menuContent = Get-Content $tempMenuFile -Raw | ConvertFrom-Json
        $mainMenuItems = $menuContent.mainMenu.items
        
        # Expected order from user's screen examples
        $expectedOrder = @(
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
        
        $actualOrder = $mainMenuItems | ForEach-Object { $_.name }
        $orderMatch = $true
        
        for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
            if ($i -ge $actualOrder.Count -or $actualOrder[$i] -ne $expectedOrder[$i]) {
                $orderMatch = $false
                Write-Host "  Mismatch at position $($i + 1): Expected '$($expectedOrder[$i])' but got '$($actualOrder[$i])'" -ForegroundColor Yellow
                break
            }
        }
        
        if ($orderMatch) {
            Write-Host "✓ Test 1 PASSED: Main menu items are in correct order" -ForegroundColor Green
            $testPassed++
        } else {
            Write-Host "✗ Test 1 FAILED: Main menu items are not in expected order" -ForegroundColor Red
            Write-Host "  Expected: $($expectedOrder -join ' -> ')" -ForegroundColor Yellow
            Write-Host "  Actual:   $($actualOrder -join ' -> ')" -ForegroundColor Yellow
            $testFailed++
        }
    } else {
        Write-Host "✗ Test 1 FAILED: Could not create menu.json file" -ForegroundColor Red
        $testFailed++
    }
}
catch {
    Write-Host "✗ Test 1 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
    $testFailed++
}

# Test 2: Device Actions Menu Order
Write-Host "Test 2: Verifying device actions menu item order preservation"
try {
    if (Test-Path $tempMenuFile) {
        $menuContent = Get-Content $tempMenuFile -Raw | ConvertFrom-Json
        $deviceActionsItems = $menuContent.deviceActionsMenu.items
        
        # Expected order from user's screen examples
        $expectedDeviceOrder = @(
            "Wipe Device",
            "Clean Device",
            "Sync Device", 
            "Get LAPS Password",
            "Get BitLocker Recovery Key",
            "Get Hardware Password Details",
            "Restart Device",
            "Show Device Health Status",
            "Check next user readiness state"
        )
        
        $actualDeviceOrder = $deviceActionsItems | ForEach-Object { $_.name }
        $deviceOrderMatch = $true
        
        for ($i = 0; $i -lt $expectedDeviceOrder.Count; $i++) {
            if ($i -ge $actualDeviceOrder.Count -or $actualDeviceOrder[$i] -ne $expectedDeviceOrder[$i]) {
                $deviceOrderMatch = $false
                Write-Host "  Device actions mismatch at position $($i + 1): Expected '$($expectedDeviceOrder[$i])' but got '$($actualDeviceOrder[$i])'" -ForegroundColor Yellow
                break
            }
        }
        
        if ($deviceOrderMatch) {
            Write-Host "✓ Test 2 PASSED: Device actions menu items are in correct order" -ForegroundColor Green  
            $testPassed++
        } else {
            Write-Host "✗ Test 2 FAILED: Device actions menu items are not in expected order" -ForegroundColor Red
            Write-Host "  Expected: $($expectedDeviceOrder -join ' -> ')" -ForegroundColor Yellow
            Write-Host "  Actual:   $($actualDeviceOrder -join ' -> ')" -ForegroundColor Yellow
            $testFailed++
        }
    } else {
        Write-Host "✗ Test 2 FAILED: Menu file not available for device actions test" -ForegroundColor Red
        $testFailed++
    }
}
catch {
    Write-Host "✗ Test 2 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
    $testFailed++
}

# Test 3: Check Menu Order
Write-Host "Test 3: Verifying check menu item order preservation"
try {
    if (Test-Path $tempMenuFile) {
        $menuContent = Get-Content $tempMenuFile -Raw | ConvertFrom-Json
        $checkMenuItems = $menuContent.checkMenu.items
        
        # Expected order from user's screen examples
        $expectedCheckOrder = @(
            "Lookup device by Serial Number",
            "Lookup device by User"
        )
        
        $actualCheckOrder = $checkMenuItems | ForEach-Object { $_.name }
        $checkOrderMatch = $true
        
        for ($i = 0; $i -lt $expectedCheckOrder.Count; $i++) {
            if ($i -ge $actualCheckOrder.Count -or $actualCheckOrder[$i] -ne $expectedCheckOrder[$i]) {
                $checkOrderMatch = $false
                Write-Host "  Check menu mismatch at position $($i + 1): Expected '$($expectedCheckOrder[$i])' but got '$($actualCheckOrder[$i])'" -ForegroundColor Yellow
                break
            }
        }
        
        if ($checkOrderMatch) {
            Write-Host "✓ Test 3 PASSED: Check menu items are in correct order" -ForegroundColor Green
            $testPassed++
        } else {
            Write-Host "✗ Test 3 FAILED: Check menu items are not in expected order" -ForegroundColor Red
            Write-Host "  Expected: $($expectedCheckOrder -join ' -> ')" -ForegroundColor Yellow
            Write-Host "  Actual:   $($actualCheckOrder -join ' -> ')" -ForegroundColor Yellow
            $testFailed++
        }
    } else {
        Write-Host "✗ Test 3 FAILED: Menu file not available for check menu test" -ForegroundColor Red
        $testFailed++
    }
}
catch {
    Write-Host "✗ Test 3 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
    $testFailed++
}

# Test 4: Menu Names and Descriptions Match Expected UI
Write-Host "Test 4: Verifying menu names match expected UI text"
try {
    if (Test-Path $tempMenuFile) {
        $menuContent = Get-Content $tempMenuFile -Raw | ConvertFrom-Json
        $mainMenuItems = $menuContent.mainMenu.items
        
        # Find the "Show Group Assignments" item - this was a specific issue mentioned by user
        $groupAssignmentItem = $mainMenuItems | Where-Object { $_.name -eq "Show Group Assignments" }
        
        if ($groupAssignmentItem) {
            Write-Host "✓ Test 4 PASSED: 'Show Group Assignments' menu item found with correct capitalization" -ForegroundColor Green
            $testPassed++
        } else {
            # Check if it exists with wrong capitalization
            $wrongCapItem = $mainMenuItems | Where-Object { $_.name -like "*group assignments*" }
            if ($wrongCapItem) {
                Write-Host "✗ Test 4 FAILED: Found '$($wrongCapItem.name)' instead of 'Show Group Assignments'" -ForegroundColor Red
            } else {
                Write-Host "✗ Test 4 FAILED: 'Show Group Assignments' menu item not found" -ForegroundColor Red
            }
            $testFailed++
        }
    } else {
        Write-Host "✗ Test 4 FAILED: Menu file not available for name verification test" -ForegroundColor Red
        $testFailed++
    }
}
catch {
    Write-Host "✗ Test 4 FAILED: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
    $testFailed++
}

# Cleanup
if (Test-Path $tempMenuFile) {
    Remove-Item $tempMenuFile -Force
}

# Summary
Write-Host "`nTest Results:" -ForegroundColor Cyan
Write-Host "Passed: $testPassed/4" -ForegroundColor Green
if ($testFailed -eq 0) {
    Write-Host "✓ All menu order preservation tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some menu order preservation tests FAILED" -ForegroundColor Red
    exit 1
}