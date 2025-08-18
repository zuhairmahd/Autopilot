#!/usr/bin/env pwsh
# Test for Remove-MenuItem functionality and conditional device action menu display

Write-Host "Testing Remove-MenuItem function and conditional device action menu display" -ForegroundColor Cyan

# Load the required functions
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionFiles = Get-ChildItem -Path "$projectRoot/functions" -Filter "*.ps1" -Recurse

# Initialize globals to prevent errors
$global:LogFile = ""

Write-Host "Loading functions..." -ForegroundColor Gray
foreach ($file in $functionFiles) {
    try {
        . $file.FullName
        Write-Host "  ✓ Loaded: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to load: $($file.Name) - $_" -ForegroundColor Red
        exit 1
    }
}

# Test counter
$testCount = 0
$passedTests = 0

function Test-Assert {
    param($Condition, $TestName)
    
    $script:testCount++
    if ($Condition) {
        Write-Host "✓ Test $script:testCount PASSED: $TestName" -ForegroundColor Green
        $script:passedTests++
    } else {
        Write-Host "✗ Test $script:testCount FAILED: $TestName" -ForegroundColor Red
    }
}

# Test 1: Remove-MenuItem function basic functionality
Write-Host "`nTest 1: Remove-MenuItem basic functionality" -ForegroundColor Yellow

# Create a test menu with sample items
$testMenu = @{
    Title = "Test Menu"
    Items = @(
        @{ Name = "Item 1"; Description = "First item" },
        @{ Name = "Item 2"; Description = "Second item" },
        @{ Name = "Item 3"; Description = "Third item" }
    )
}

$originalCount = $testMenu.Items.Count
Test-Assert ($originalCount -eq 3) "Initial menu has 3 items"

# Remove an item
$testMenu = Remove-MenuItem -Menu $testMenu -ItemName "Item 2"

$newCount = $testMenu.Items.Count
Test-Assert ($newCount -eq 2) "Menu has 2 items after removal"

$remainingNames = $testMenu.Items | ForEach-Object { $_.Name }
Test-Assert ("Item 2" -notin $remainingNames) "Item 2 was successfully removed"
Test-Assert ("Item 1" -in $remainingNames -and "Item 3" -in $remainingNames) "Other items remain"

# Test 2: Remove non-existent item
Write-Host "`nTest 2: Remove non-existent item" -ForegroundColor Yellow

$countBeforeRemoval = $testMenu.Items.Count
$testMenu = Remove-MenuItem -Menu $testMenu -ItemName "Non-existent Item"
$countAfterRemoval = $testMenu.Items.Count

Test-Assert ($countBeforeRemoval -eq $countAfterRemoval) "Menu unchanged when removing non-existent item"

# Test 3: NewMenu loads items from menu.json correctly
Write-Host "`nTest 3: NewMenu loads deviceActionsMenu correctly" -ForegroundColor Yellow

try {
    # Check if menu.json exists first
    $menuJsonPath = Join-Path $projectRoot "menu.json"
    if (Test-Path $menuJsonPath) {
        $deviceActionsMenu = NewMenu -MenuName "deviceActionsMenu"
        Test-Assert ($null -ne $deviceActionsMenu) "deviceActionsMenu created successfully"
        Test-Assert ($deviceActionsMenu.Items.Count -gt 0) "deviceActionsMenu has items"
        
        # Check if conditional items are present in the default menu
        $itemNames = $deviceActionsMenu.Items | ForEach-Object { $_.Name }
        Test-Assert ("Get LAPS Password" -in $itemNames) "LAPS Password item exists in default menu"
        Test-Assert ("Get BitLocker Recovery Key" -in $itemNames) "BitLocker Recovery Key item exists in default menu"
        Test-Assert ("Get Hardware Password Details" -in $itemNames) "Hardware Password Details item exists in default menu"
    } else {
        Test-Assert $false "menu.json file not found at $menuJsonPath"
    }
}
catch {
    Test-Assert $false "Failed to create deviceActionsMenu: $_"
}

# Test 4: Conditional removal works correctly
Write-Host "`nTest 4: Conditional item removal works correctly" -ForegroundColor Yellow

try {
    $menuJsonPath = Join-Path $projectRoot "menu.json"
    if (Test-Path $menuJsonPath) {
        $testDeviceMenu = NewMenu -MenuName "deviceActionsMenu"
        
        # Simulate device without LAPS credentials
        $testDeviceMenu = Remove-MenuItem -Menu $testDeviceMenu -ItemName "Get LAPS Password"
        $itemNamesAfterLAPSRemoval = $testDeviceMenu.Items | ForEach-Object { $_.Name }
        Test-Assert ("Get LAPS Password" -notin $itemNamesAfterLAPSRemoval) "LAPS Password item removed when not available"
        
        # Simulate device without BitLocker keys
        $testDeviceMenu = Remove-MenuItem -Menu $testDeviceMenu -ItemName "Get BitLocker Recovery Key"
        $itemNamesAfterBitLockerRemoval = $testDeviceMenu.Items | ForEach-Object { $_.Name }
        Test-Assert ("Get BitLocker Recovery Key" -notin $itemNamesAfterBitLockerRemoval) "BitLocker Recovery Key item removed when not available"
        
        # Simulate device without Hardware Password
        $testDeviceMenu = Remove-MenuItem -Menu $testDeviceMenu -ItemName "Get Hardware Password Details"
        $itemNamesAfterHardwarePasswordRemoval = $testDeviceMenu.Items | ForEach-Object { $_.Name }
        Test-Assert ("Get Hardware Password Details" -notin $itemNamesAfterHardwarePasswordRemoval) "Hardware Password Details item removed when not available"
        
        # Check that other items remain
        Test-Assert ("Wipe Device" -in $itemNamesAfterHardwarePasswordRemoval) "Wipe Device item remains"
        Test-Assert ("Sync Device" -in $itemNamesAfterHardwarePasswordRemoval) "Sync Device item remains"
        Test-Assert ("Restart Device" -in $itemNamesAfterHardwarePasswordRemoval) "Restart Device item remains"
    } else {
        Test-Assert $false "menu.json file not found for conditional removal test"
    }
}
catch {
    Test-Assert $false "Failed to test conditional removal: $_"
}

# Test 5: Menu ordering is preserved after removal
Write-Host "`nTest 5: Menu ordering preserved after removal" -ForegroundColor Yellow

try {
    $menuJsonPath = Join-Path $projectRoot "menu.json"
    if (Test-Path $menuJsonPath) {
        $orderTestMenu = NewMenu -MenuName "deviceActionsMenu"
        $originalOrder = $orderTestMenu.Items | ForEach-Object { $_.Name }
        
        # Remove an item from the middle
        $orderTestMenu = Remove-MenuItem -Menu $orderTestMenu -ItemName "Get LAPS Password"
        $newOrder = $orderTestMenu.Items | ForEach-Object { $_.Name }
        
        # Check that the relative order of remaining items is preserved
        $expectedOrder = $originalOrder | Where-Object { $_ -ne "Get LAPS Password" }
        $orderMatches = $true
        for ($i = 0; $i -lt $newOrder.Count; $i++) {
            if ($newOrder[$i] -ne $expectedOrder[$i]) {
                $orderMatches = $false
                break
            }
        }
        
        Test-Assert $orderMatches "Menu item order preserved after removal"
    } else {
        Test-Assert $false "menu.json file not found for ordering test"
    }
}
catch {
    Test-Assert $false "Failed to test menu ordering: $_"
}

# Test Results Summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "Test Results:" -ForegroundColor Cyan
Write-Host "Passed: $passedTests/$testCount" -ForegroundColor $(if ($passedTests -eq $testCount) { 'Green' } else { 'Red' })

if ($passedTests -eq $testCount) {
    Write-Host "✓ All Remove-MenuItem and conditional menu display tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests FAILED" -ForegroundColor Red
    exit 1
}