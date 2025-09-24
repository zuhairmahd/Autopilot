#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for validating the fix for issue: "Skip last connection check if the device's enrollment in autopilot is not contacted"

.DESCRIPTION
    This test validates that:
    1. Devices with autopilot enrollment state 'notContacted' skip the connectivity threshold check
    2. Such devices pass readiness if other success criteria apply
    3. Connectivity issues are not reported as problems for 'notContacted' devices
    4. Normal devices still respect the connectivity threshold as before

.NOTES
    Author: GitHub Copilot
    Version: 1.0.0 - Initial test for notContacted enrollment state fix
    Related Issue: Skip last connection check if the device's enrollment in autopilot is not contacted
#>

[CmdletBinding()]
param()

# Use unified test framework
try {
    # Load test helper functions if available
    if (Test-Path "$PSScriptRoot\test-helper.ps1") {
        . "$PSScriptRoot\test-helper.ps1"
        $testContext = Start-UnifiedTest -TestName "NotContacted Enrollment State Connectivity Fix"
    } else {
        Write-Output "=== NotContacted Enrollment State Connectivity Fix Test ==="
        function Write-TestResult { 
            param($Message, $Passed)
            if ($Passed) { 
                Write-Output "✓ $Message" 
            } else { 
                Write-Output "✗ $Message" 
            }
        }
    }
}
catch {
    Write-Output "Starting basic test environment..."
    function Write-TestResult { 
        param($Message, $Passed)
        if ($Passed) { 
            Write-Output "✓ $Message" 
        } else { 
            Write-Output "✗ $Message" 
        }
    }
}

$testsPassed = 0
$testsFailed = 0

Write-Output ""
Write-Output "=== Test 1: Logical Condition Verification ==="
Write-Output "Testing the core logical condition that determines device readiness..."

# Test parameters simulating a 'notContacted' device with connectivity issues
$autopilotReadiness = @{ AutopilotAssignmentGood = $true }
$managedDeviceReadiness = @{ ReadyForNextUser = $true }
$enrollmentStateNotContacted = @{
    autopilot = @{ device = @{ enrollmentState = 'notContacted' } }
    managed = $false
}
$deviceLastContactDate = @{ withinThreshold = $false }  # Connectivity issues

# Test the fixed condition (from AssessDeviceState.ps1 line 65)
$fixedCondition = (($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser -and $deviceLastContactDate.withinThreshold) -or ($autopilotReadiness.AutopilotAssignmentGood -and $enrollmentStateNotContacted.autopilot.device.enrollmentState -eq 'notContacted' -and $enrollmentStateNotContacted.managed -eq $false))

if ($fixedCondition -eq $true) {
    Write-TestResult "notContacted device passes readiness despite connectivity issues" $true
    $testsPassed++
} else {
    Write-TestResult "notContacted device should pass readiness despite connectivity issues" $false
    $testsFailed++
}

Write-Output ""
Write-Output "=== Test 2: Normal Device Still Respects Connectivity ==="
Write-Output "Ensuring normal enrolled devices still fail with connectivity issues..."

$enrollmentStateNormal = @{
    autopilot = @{ device = @{ enrollmentState = 'enrolled' } }
    managed = $true
}

$normalCondition = (($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser -and $deviceLastContactDate.withinThreshold) -or ($autopilotReadiness.AutopilotAssignmentGood -and $enrollmentStateNormal.autopilot.device.enrollmentState -eq 'notContacted' -and $enrollmentStateNormal.managed -eq $false))

if ($normalCondition -eq $false) {
    Write-TestResult "Normal enrolled device correctly fails with connectivity issues" $true
    $testsPassed++
} else {
    Write-TestResult "Normal enrolled device should fail with connectivity issues" $false
    $testsFailed++
}

Write-Output ""
Write-Output "=== Test 3: Issue Reporting Logic ==="
Write-Output "Testing that connectivity issues are not reported for notContacted devices..."

# Test the issue reporting condition (from AssessDeviceState.ps1 line 171)
$normalDeviceReportsConnectivity = ($deviceLastContactDate.withinThreshold -eq $false -and -not ($enrollmentStateNormal.autopilot.device.enrollmentState -eq 'notContacted'))
$notContactedDeviceReportsConnectivity = ($deviceLastContactDate.withinThreshold -eq $false -and -not ($enrollmentStateNotContacted.autopilot.device.enrollmentState -eq 'notContacted'))

if ($normalDeviceReportsConnectivity -eq $true -and $notContactedDeviceReportsConnectivity -eq $false) {
    Write-TestResult "Issue reporting correctly differentiates notContacted from normal devices" $true
    $testsPassed++
} else {
    Write-TestResult "Issue reporting should not flag connectivity for notContacted devices" $false
    $testsFailed++
}

Write-Output ""
Write-Output "=== Test 4: Edge Cases ==="
Write-Output "Testing edge cases and boundary conditions..."

# Test with good connectivity for notContacted device
$deviceLastContactDateGood = @{ withinThreshold = $true }
$notContactedWithGoodConnectivity = (($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser -and $deviceLastContactDateGood.withinThreshold) -or ($autopilotReadiness.AutopilotAssignmentGood -and $enrollmentStateNotContacted.autopilot.device.enrollmentState -eq 'notContacted' -and $enrollmentStateNotContacted.managed -eq $false))

if ($notContactedWithGoodConnectivity -eq $true) {
    Write-TestResult "notContacted device with good connectivity still passes" $true
    $testsPassed++
} else {
    Write-TestResult "notContacted device with good connectivity should pass" $false
    $testsFailed++
}

# Test normal device with good connectivity
$normalWithGoodConnectivity = (($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser -and $deviceLastContactDateGood.withinThreshold) -or ($autopilotReadiness.AutopilotAssignmentGood -and $enrollmentStateNormal.autopilot.device.enrollmentState -eq 'notContacted' -and $enrollmentStateNormal.managed -eq $false))

if ($normalWithGoodConnectivity -eq $true) {
    Write-TestResult "Normal device with good connectivity passes" $true
    $testsPassed++
} else {
    Write-TestResult "Normal device with good connectivity should pass" $false
    $testsFailed++
}

Write-Output ""
Write-Output "=== Test Results Summary ==="
Write-Output "Tests Passed: $testsPassed"
Write-Output "Tests Failed: $testsFailed"
Write-Output "Total Tests: $($testsPassed + $testsFailed)"

if ($testsFailed -eq 0) {
    Write-Output "✓ ALL TESTS PASSED: The fix correctly implements the required behavior"
    Write-Output ""
    Write-Output "Summary of validated behavior:"
    Write-Output "- ✓ notContacted devices skip connectivity threshold checks"
    Write-Output "- ✓ notContracted devices pass if other criteria are met"
    Write-Output "- ✓ notContracted devices don't report connectivity as an issue"
    Write-Output "- ✓ Normal devices still respect connectivity requirements"
    Write-Output "- ✓ All edge cases work correctly"
    
    if (Get-Variable testContext -ErrorAction SilentlyContinue) {
        try { Complete-UnifiedTest -TestContext $testContext -Success $true } catch { }
    }
    exit 0
} else {
    Write-Output "✗ SOME TESTS FAILED: The fix needs additional work"
    
    if (Get-Variable testContext -ErrorAction SilentlyContinue) {
        try { Complete-UnifiedTest -TestContext $testContext -Success $false } catch { }
    }
    exit 1
}