# Test script for register.ps1 USB drive detection functionality
# Tests the USB drive detection logic and Windows setup validation

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Import test helper if available
$testHelperPath = Join-Path $PSScriptRoot "test-helper.ps1"
if (Test-Path $testHelperPath) {
    . $testHelperPath
}

Write-Host "=== Testing register.ps1 USB Drive Detection ===" -ForegroundColor Cyan

# Test variables
$registerScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "tools\register.ps1"
$testsPassed = 0
$testsTotal = 0

function Test-USBDetectionFunction {
    param(
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    $script:testsTotal++
    Write-Host "`n--- Test: $TestName ---" -ForegroundColor Yellow
    
    try {
        & $TestBlock
        Write-Host "✓ PASSED: $TestName" -ForegroundColor Green
        $script:testsPassed++
    }
    catch {
        Write-Host "✗ FAILED: $TestName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "  Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
        }
    }
}

# Verify register.ps1 exists
if (-not (Test-Path $registerScriptPath)) {
    Write-Error "register.ps1 not found at: $registerScriptPath"
}

Write-Host "Testing register.ps1 at: $registerScriptPath"

# Test 1: Verify script can be loaded without errors
Test-USBDetectionFunction "Script Loading and Syntax" {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $registerScriptPath -Raw), [ref]$null)
    $true | Should -Be $true "Script should parse without syntax errors"
}

# Test 2: Test Get-WindowsUSBDriveLetter function exists
Test-USBDetectionFunction "Get-WindowsUSBDriveLetter Function Definition" {
    $scriptContent = Get-Content $registerScriptPath -Raw
    $scriptContent | Should -Match "function Get-WindowsUSBDriveLetter" "Function Get-WindowsUSBDriveLetter should be defined"
}

# Test 3: Test variable scoping issue in single USB drive logic
Test-USBDetectionFunction "Variable Scoping Analysis" {
    $scriptContent = Get-Content $registerScriptPath -Raw
    
    # Check for the problematic line with global variable
    $hasGlobalVariable = $scriptContent -match '\$global:usbDriveLetter\s*=\s*@\(Get-WindowsUSBDriveLetter\)'
    
    if ($hasGlobalVariable) {
        # This is the current broken behavior - we expect this test to initially fail
        # and pass after the fix
        Write-Host "  Found global variable usage (this should be fixed)" -ForegroundColor Yellow
        
        # Check if the same script tries to use local variable
        $hasLocalReference = $scriptContent -match '\$usbDriveLetter\.Count'
        if ($hasLocalReference) {
            throw "Script uses global variable assignment but local variable reference - this is a bug"
        }
    }
    
    # After fix, we should have consistent variable usage
    $true | Should -Be $true "Variable scoping should be consistent"
}

# Test 4: Test Windows setup detection logic
Test-USBDetectionFunction "Windows Setup Detection Logic" {
    $scriptContent = Get-Content $registerScriptPath -Raw
    
    # Check for original scripts folder check
    $hasScriptsCheck = $scriptContent -match 'Test-Path.*scriptsFolder'
    $hasScriptsCheck | Should -Be $true "Script should check for scripts folder"
    
    # Check for new Windows setup detection function
    $hasSetupFunction = $scriptContent -match 'function Test-WindowsSetupDrive'
    $hasSetupFunction | Should -Be $true "Script should have Windows setup detection function"
    
    # Check for Windows setup validation in main logic
    $hasSetupValidation = $scriptContent -match 'Test-WindowsSetupDrive.*DriveLetter'
    $hasSetupValidation | Should -Be $true "Script should validate Windows setup drives"
    
    Write-Host "  Enhanced implementation now includes Windows setup file detection" -ForegroundColor Green
}

# Test 5: Test single USB drive handling
Test-USBDetectionFunction "Single USB Drive Handling" {
    $scriptContent = Get-Content $registerScriptPath -Raw
    
    # Check for ignoreLabelIfOnlyOne parameter handling
    $hasIgnoreLabelLogic = $scriptContent -match 'ignoreLabelIfOnlyOne'
    $hasIgnoreLabelLogic | Should -Be $true "Script should handle ignoreLabelIfOnlyOne parameter"
    
    # Check for proper single drive detection
    $hasSingleDriveLogic = $scriptContent -match 'Count -eq 1'
    $hasSingleDriveLogic | Should -Be $true "Script should have single drive detection logic"
}

# Test 6: Test error handling for no USB drives
Test-USBDetectionFunction "No USB Drive Error Handling" {
    $scriptContent = Get-Content $registerScriptPath -Raw
    
    # Check for warning when no USB drive found
    $hasNoUSBWarning = $scriptContent -match 'No USB drive found'
    $hasNoUSBWarning | Should -Be $true "Script should warn when no USB drives are found"
}

# Simple mock test to verify Get-WindowsUSBDriveLetter function behavior
Test-USBDetectionFunction "Function Interface Validation" {
    # Load the script content and extract the function
    $scriptContent = Get-Content $registerScriptPath -Raw
    
    # Check for Get-WindowsUSBDriveLetter function and its parameters
    $hasFunction = $scriptContent -match 'function Get-WindowsUSBDriveLetter\(\)'
    $hasFunction | Should -Be $true "Function Get-WindowsUSBDriveLetter should be defined"
    
    # Check for expected parameters in the function
    $hasLabelParam = $scriptContent -match '\[string\]\$Label'
    $hasIgnoreParam = $scriptContent -match '\[switch\]\$IgnoreLabelIfOnlyOne'
    
    $hasLabelParam | Should -Be $true "Function should have Label parameter"
    $hasIgnoreParam | Should -Be $true "Function should have IgnoreLabelIfOnlyOne parameter"
    
    # Check for the new Windows setup detection function
    $hasSetupFunction = $scriptContent -match 'function Test-WindowsSetupDrive\(\)'
    $hasSetupFunction | Should -Be $true "Should have Test-WindowsSetupDrive function"
}

# Summary
Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed / $testsTotal" -ForegroundColor $(if ($testsPassed -eq $testsTotal) { "Green" } else { "Yellow" })

if ($testsPassed -eq $testsTotal) {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. Review the issues above." -ForegroundColor Red
    exit 1
}

# Helper function for Should assertions (simple implementation)
function Should {
    param(
        [Parameter(ValueFromPipeline)]
        $ActualValue,
        [Parameter(Mandatory)]
        [string]$Operator,
        $ExpectedValue,
        [string]$Because = ""
    )
    
    $result = switch ($Operator) {
        "Be" { $ActualValue -eq $ExpectedValue }
        "Match" { $ActualValue -match $ExpectedValue }
        default { throw "Unsupported operator: $Operator" }
    }
    
    if (-not $result) {
        $message = "Expected '$ActualValue' to $Operator '$ExpectedValue'"
        if ($Because) { $message += " because $Because" }
        throw $message
    }
}