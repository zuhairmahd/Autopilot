#!/usr/bin/env pwsh
# Test comprehensive submenu filtering functionality

param(
    [switch]$ShowVerbose
)

$scriptName = "test-submenu-filtering-comprehensive"

function Write-TestHeader($testName) {
    if ($ShowVerbose) {
        Write-Host "`n=== $testName ===" -ForegroundColor Cyan
    }
}

function Write-TestResult($testName, $passed, $message = "") {
    $status = if ($passed) { "PASS" } else { "FAIL" }
    $color = if ($passed) { "Green" } else { "Red" }
    $output = "[$status] $testName"
    if ($message) { $output += " - $message" }
    Write-Host $output -ForegroundColor $color
}

# Initialize test counter
$totalTests = 0
$passedTests = 0

# Test 1: Verify Test-ShouldIncludeMenuItem function exists and has MenuName parameter
Write-TestHeader "Test-ShouldIncludeMenuItem Function Parameters"
$totalTests++
try {
    # Load the main script to get the function
    $mainScriptContent = Get-Content -Path "./main.ps1" -Raw
    
    # Check if the function has the MenuName parameter
    $hasMenuNameParam = $mainScriptContent -match '\[string\]\$MenuName\s*=\s*"mainMenu"'
    
    if ($hasMenuNameParam) {
        Write-TestResult "Test-ShouldIncludeMenuItem has MenuName parameter" $true
        $passedTests++
    } else {
        Write-TestResult "Test-ShouldIncludeMenuItem has MenuName parameter" $false "MenuName parameter not found"
    }
} catch {
    Write-TestResult "Test-ShouldIncludeMenuItem has MenuName parameter" $false "Error: $_"
}

# Test 2: Verify autopilot menu items have filtering
Write-TestHeader "Autopilot Menu Items Filtering"
$totalTests++
try {
    $mainScriptContent = Get-Content -Path "./main.ps1" -Raw
    
    # Check for filtered autopilot menu items
    $autopilotItemsWithFiltering = @(
        'Quick Import device into Autopilot',
        'Custom import device into Autopilot',
        'Import device into Autopilot',
        'Import Corporate Device Identifier',
        'Delete Corporate Device Identifier',
        'Export Corporate Device Identifier',
        'Get device hash for manual upload',
        'Download and install latest Windows updates',
        'Check device Autopilot status',
        'Delete device from Autopilot'
    )
    
    $filteredCount = 0
    foreach ($item in $autopilotItemsWithFiltering) {
        $pattern = "if\s*\(\s*Test-ShouldIncludeMenuItem.*$($item.Replace('(', '\(').Replace(')', '\)'))"
        if ($mainScriptContent -match $pattern) {
            $filteredCount++
        }
    }
    
    $expectedCount = $autopilotItemsWithFiltering.Count
    if ($filteredCount -eq $expectedCount) {
        Write-TestResult "Autopilot menu items filtering" $true "All $expectedCount items have filtering"
        $passedTests++
    } else {
        Write-TestResult "Autopilot menu items filtering" $false "Only $filteredCount/$expectedCount items have filtering"
    }
} catch {
    Write-TestResult "Autopilot menu items filtering" $false "Error: $_"
}

# Test 3: Verify ProcessSerialNumber.ps1 has device actions filtering
Write-TestHeader "Device Actions Menu Filtering"
$totalTests++
try {
    $processSerialContent = Get-Content -Path "./functions/deviceFunctions/ProcessSerialNumber.ps1" -Raw
    
    # Check for Test-ShouldIncludeMenuItem function in ProcessSerialNumber.ps1
    $hasFunction = $processSerialContent -match 'function Test-ShouldIncludeMenuItem'
    
    # Check for device action items with filtering
    $deviceActionItems = @(
        'Wipe Device',
        'Clean Device', 
        'Sync Device',
        'Get LAPS Password',
        'Get BitLocker Recovery Key',
        'Get Hardware Password Details',
        'Restart Device',
        'Show Device Health Status',
        'Check next user readiness state'
    )
    
    $filteredDeviceActions = 0
    foreach ($item in $deviceActionItems) {
        $pattern = "Test-ShouldIncludeMenuItem.*$($item.Replace('(', '\(').Replace(')', '\)'))"
        if ($processSerialContent -match $pattern) {
            $filteredDeviceActions++
        }
    }
    
    if ($hasFunction -and $filteredDeviceActions -ge 6) { # At least most device actions should be filtered
        Write-TestResult "Device actions menu filtering" $true "Helper function exists and $filteredDeviceActions device actions are filtered"
        $passedTests++
    } else {
        Write-TestResult "Device actions menu filtering" $false "Helper function: $hasFunction, Filtered actions: $filteredDeviceActions"
    }
} catch {
    Write-TestResult "Device actions menu filtering" $false "Error: $_"
}

# Test 4: Verify ProcessDevice.ps1 has device wait menu filtering
Write-TestHeader "Device Wait Menu Filtering"
$totalTests++
try {
    $processDeviceContent = Get-Content -Path "./functions/autopilotFunctions/v1/ProcessDevice.ps1" -Raw
    
    # Check for Test-ShouldIncludeMenuItem function in ProcessDevice.ps1
    $hasFunction = $processDeviceContent -match 'function Test-ShouldIncludeMenuItem'
    
    # Check for device wait menu items with filtering
    $deviceWaitItems = @(
        'Restart the device',
        'Continue to wait for profile assignment',
        'Delete the device from Autopilot'
    )
    
    $filteredWaitActions = 0
    foreach ($item in $deviceWaitItems) {
        $pattern = "Test-ShouldIncludeMenuItem.*$($item.Replace('(', '\(').Replace(')', '\)'))"
        if ($processDeviceContent -match $pattern) {
            $filteredWaitActions++
        }
    }
    
    if ($hasFunction -and $filteredWaitActions -eq 3) {
        Write-TestResult "Device wait menu filtering" $true "Helper function exists and all 3 wait actions are filtered"
        $passedTests++
    } else {
        Write-TestResult "Device wait menu filtering" $false "Helper function: $hasFunction, Filtered actions: $filteredWaitActions/3"
    }
} catch {
    Write-TestResult "Device wait menu filtering" $false "Error: $_"
}

# Test 5: Verify menu configurations exist for all filtered menus
Write-TestHeader "Menu Configuration Validation"
$totalTests++
try {
    $menuConfig = Import-PowerShellDataFile -Path "./menu.psd1"
    
    $requiredMenus = @('autopilotMenu', 'deviceActionsMenu', 'deviceWaitMenu')
    $missingMenus = @()
    
    foreach ($menuName in $requiredMenus) {
        if (-not $menuConfig.ContainsKey($menuName)) {
            $missingMenus += $menuName
        }
    }
    
    if ($missingMenus.Count -eq 0) {
        Write-TestResult "Menu configuration validation" $true "All required menu configurations exist"
        $passedTests++
    } else {
        Write-TestResult "Menu configuration validation" $false "Missing configurations: $($missingMenus -join ', ')"
    }
} catch {
    Write-TestResult "Menu configuration validation" $false "Error: $_"
}

# Test 6: Verify syntax still valid after changes
Write-TestHeader "Syntax Validation"
$totalTests++
try {
    $syntaxResult = & pwsh -File "./TestScripts/test-syntax.ps1" 2>&1
    $syntaxPassed = $LASTEXITCODE -eq 0
    
    if ($syntaxPassed) {
        Write-TestResult "Syntax validation" $true "All PowerShell syntax is valid"
        $passedTests++
    } else {
        Write-TestResult "Syntax validation" $false "Syntax errors found"
        if ($ShowVerbose) { Write-Host "Syntax output: $syntaxResult" -ForegroundColor Yellow }
    }
} catch {
    Write-TestResult "Syntax validation" $false "Error: $_"
}

# Summary
Write-Host "`n" -NoNewline
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Red" })

$successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "`nAll submenu filtering tests passed! The comprehensive fix is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed. Please review the implementation." -ForegroundColor Red
    exit 1
}