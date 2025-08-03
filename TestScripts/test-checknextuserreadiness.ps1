#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for GetNextUserReadinessReport function enhancements
.DESCRIPTION
    This script tests the enhanced GetNextUserReadinessReport function to ensure:
    1. All device issues are captured and returned
    2. Return value properly displays all issues and actions
    3. Backward compatibility is maintained
    4. Error handling works correctly
.NOTES
    Author: Automated Test
    Version: 1.0.0
#>

[CmdletBinding()]
param()

# Set up test environment
$ErrorActionPreference = 'Stop'
$testResults = @()
$testName = "GetNextUserReadinessReport Enhanced Functionality"

Write-Host "Starting tests for $testName" -ForegroundColor Yellow

# Import required functions (simulate the loading process)
try {
    # Get the script directory
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $rootDir = Split-Path -Parent $scriptDir
    
    # Load required functions
    . "$rootDir\functions\DeviceReportingFunctions.ps1"
    
    # Load settings and constants (simulate)
    $loadedStrings = @{
        deviceStates = @{
            ready = "Device ready"
            notReady = "Device not ready"
        }
        deviceActions = @{
            none = "No action"
            contactAdmin = "Contact an Intune administrator"
            WipeOrClean = "Wipe or clean the device"
            connectToNetwork = "Connect the device to the network"
        }
    }
    
    # Set global variables that the function expects
    $global:deviceStates = $loadedStrings.deviceStates
    $global:deviceActions = $loadedStrings.deviceActions
    $global:LogFile = "$env:TEMP\test-checknextuserreadiness.log"
    
    Write-Host "✓ Test environment setup complete" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to set up test environment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Helper function to create mock enrollment states
function New-MockEnrollmentState {
    param(
        [string]$Scenario = "Ready",
        [string]$DeviceName = "TEST-DEVICE-01",
        [string]$SerialNumber = "TEST123456",
        [string]$DeviceId = "test-device-id-123"
    )
    
    $baseState = @{
        inAutopilot = $true
        managed = $true
        autopilot = @{
            device = @{
                displayName = $DeviceName
                serialNumber = $SerialNumber
                id = $DeviceId
                enrollmentState = "enrolled"
                deploymentProfileAssignmentStatus = "assignedInSync"
                remediationState = "noRemediationRequired"
                deploymentProfile = @{
                    displayName = "Corporate Profile"
                }
            }
            events = @()
        }
        managedDevice = @{
            device = @{
                deviceName = $DeviceName
                serialNumber = $SerialNumber
                id = $DeviceId
                userId = $null
            }
            memory = 16
            users = $null
        }
    }
    
    switch ($Scenario) {
        "Ready" {
            # Device is ready - no modifications needed
        }
        "MultipleIssues" {
            # Multiple issues scenario
            $baseState.autopilot.device.deploymentProfileAssignmentStatus = "notAssigned"
            $baseState.autopilot.device.remediationState = "remediationRequired"
            $baseState.managedDevice.device.userId = "user123"
            $baseState.managedDevice.users = @{
                userDisplayName = "Test User"
                userPrincipalName = "test@company.com"
                azureUser = $false  # Invalid user
            }
            $baseState.managedDevice.memory = 8  # Below minimum
        }
        "NotInAutopilot" {
            $baseState.inAutopilot = $false
        }
        "NetworkIssue" {
            # Device hasn't contacted in too long (this would be set by GetLastDeviceContactDate)
        }
    }
    
    return $baseState
}

# Helper function to mock GetLastDeviceContactDate
function GetLastDeviceContactDate {
    param($accessToken, $enrollmentState)
    return @{
        withinThreshold = $true
        numberOfDaysSinceLastContact = 1
        latestContactDate = Get-Date
    }
}

# Helper function to mock Write-Log
function Write-Log {
    param($LogFile, $Module, $Message, $LogLevel)
    # Mock logging function - do nothing for tests
}

# Helper function to mock FormatDateWithTimeZone
function FormatDateWithTimeZone {
    param($DateTime)
    if ($null -eq $DateTime) { return $null }
    if ($DateTime -is [string]) { $DateTime = [System.DateTime]::Parse($DateTime) }
    return $DateTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Helper function to mock GetTimeZoneAbbreviation
function GetTimeZoneAbbreviation {
    param($DateTime)
    return "UTC"
}

# Mock helper functions called by AssessDeviceState
function GetAutopilotDeviceRelevantProperties {
    param($enrollmentState, $settings)
    
    $scenario = if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -eq "notAssigned") { "MultipleIssues" } else { "Ready" }
    
    switch ($scenario) {
        "Ready" {
            return @{
                CorrectProfile = $true
                ProfileAssigned = $true
                RemediationStateGood = $true
                EnrollmentStateGood = $true
                AutopilotAssignmentGood = $true
            }
        }
        "MultipleIssues" {
            return @{
                CorrectProfile = $false
                ProfileAssigned = $false
                RemediationStateGood = $false
                EnrollmentStateGood = $true
                AutopilotAssignmentGood = $false
            }
        }
    }
}

function GetManagedDeviceRelevantProperties {
    param($enrollmentState, $settings)
    
    $hasUser = $null -ne $enrollmentState.managedDevice.device.userId -and $enrollmentState.managedDevice.device.userId -ne ''
    $correctRam = $enrollmentState.managedDevice.memory -ge $settings.MinimumDevicePhysicalMemoryInGB
    $validUser = if ($hasUser -and $enrollmentState.managedDevice.users) { $enrollmentState.managedDevice.users.azureUser } else { $true }
    
    return @{
        OrphanDevice = $false
        CorrectRam = $correctRam
        HasUser = $hasUser
        ValidUser = $validUser
        ReadyForNextUser = (-not $hasUser -and $correctRam)
    }
}

# Mock settings
$global:settings = @{
    MinimumDevicePhysicalMemoryInGB = 16
    DesiredAutopilotProfiles = @("Corporate Profile")
}

# Test 1: Basic functionality - Ready device
Write-Host "`nTest 1: Ready device scenario" -ForegroundColor Cyan
try {
    $enrollmentState = New-MockEnrollmentState -Scenario "Ready"
    $result = GetNextUserReadinessReport -enrollmentState $enrollmentState
    
    if ($result.ReadinessState -eq $deviceStates.ready -and 
        $result.Action -eq $deviceActions.none -and
        $result.IsReady -eq $true -and
        $result.IssueCount -eq 0) {
        Write-Host "✓ Ready device test passed" -ForegroundColor Green
        $testResults += @{ Test = "Ready Device"; Result = "Pass" }
    } else {
        Write-Host "✗ Ready device test failed" -ForegroundColor Red
        Write-Host "  Expected: Ready=true, Issues=0, Action=none" -ForegroundColor Red
        Write-Host "  Actual: Ready=$($result.IsReady), Issues=$($result.IssueCount), Action=$($result.Action)" -ForegroundColor Red
        $testResults += @{ Test = "Ready Device"; Result = "Fail" }
    }
}
catch {
    Write-Host "✗ Ready device test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Ready Device"; Result = "Error: $($_.Exception.Message)" }
}

# Test 2: Multiple issues scenario
Write-Host "`nTest 2: Multiple issues scenario" -ForegroundColor Cyan
try {
    $enrollmentState = New-MockEnrollmentState -Scenario "MultipleIssues"
    $result = GetNextUserReadinessReport -enrollmentState $enrollmentState
    
    if ($result.ReadinessState -eq $deviceStates.notReady -and 
        $result.IssueCount -gt 1 -and
        $result.AllIssues.Count -gt 1 -and
        $result.IsReady -eq $false) {
        Write-Host "✓ Multiple issues test passed - Found $($result.IssueCount) issues" -ForegroundColor Green
        Write-Host "  Issues: $($result.AllIssues -join '; ')" -ForegroundColor Gray
        $testResults += @{ Test = "Multiple Issues"; Result = "Pass" }
    } else {
        Write-Host "✗ Multiple issues test failed" -ForegroundColor Red
        Write-Host "  Expected: Multiple issues captured" -ForegroundColor Red
        Write-Host "  Actual: Issues=$($result.IssueCount), Ready=$($result.IsReady)" -ForegroundColor Red
        $testResults += @{ Test = "Multiple Issues"; Result = "Fail" }
    }
}
catch {
    Write-Host "✗ Multiple issues test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Multiple Issues"; Result = "Error: $($_.Exception.Message)" }
}

# Test 3: Not in Autopilot scenario
Write-Host "`nTest 3: Device not in Autopilot" -ForegroundColor Cyan
try {
    $enrollmentState = New-MockEnrollmentState -Scenario "NotInAutopilot"
    $result = GetNextUserReadinessReport -enrollmentState $enrollmentState
    
    if ($result.ReadinessState -eq $deviceStates.notReady -and 
        $result.Action -eq $deviceActions.contactAdmin -and
        $result.IssueCount -eq 1 -and
        $result.AllIssues[0] -like "*not registered in Autopilot*") {
        Write-Host "✓ Not in Autopilot test passed" -ForegroundColor Green
        $testResults += @{ Test = "Not in Autopilot"; Result = "Pass" }
    } else {
        Write-Host "✗ Not in Autopilot test failed" -ForegroundColor Red
        $testResults += @{ Test = "Not in Autopilot"; Result = "Fail" }
    }
}
catch {
    Write-Host "✗ Not in Autopilot test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Not in Autopilot"; Result = "Error: $($_.Exception.Message)" }
}

# Test 4: Error handling - null enrollment state
Write-Host "`nTest 4: Error handling - null enrollment state" -ForegroundColor Cyan
try {
    $result = GetNextUserReadinessReport -enrollmentState $null
    
    if ($result.ReadinessState -eq 'Error' -and 
        $result.IssueCount -eq 1 -and
        $result.IsReady -eq $false) {
        Write-Host "✗ Null enrollment state test unexpectedly passed - function should have thrown" -ForegroundColor Red
        $testResults += @{ Test = "Error Handling"; Result = "Fail - Should have thrown" }
    }
}
catch {
    Write-Host "✓ Error handling test passed - function properly validates input" -ForegroundColor Green
    $testResults += @{ Test = "Error Handling"; Result = "Pass" }
}

# Test 5: Backward compatibility - ensure original return structure exists
Write-Host "`nTest 5: Backward compatibility check" -ForegroundColor Cyan
try {
    $enrollmentState = New-MockEnrollmentState -Scenario "Ready"
    $result = GetNextUserReadinessReport -enrollmentState $enrollmentState
    
    $hasRequiredProperties = $result.Contains('ReadinessState') -and 
                           $result.Contains('Action') -and 
                           $result.Contains('Device')
    
    $hasEnhancedProperties = $result.Contains('AllIssues') -and 
                           $result.Contains('AllActions') -and 
                           $result.Contains('IssueCount') -and
                           $result.Contains('IsReady')
    
    if ($hasRequiredProperties -and $hasEnhancedProperties) {
        Write-Host "✓ Backward compatibility test passed" -ForegroundColor Green
        $testResults += @{ Test = "Backward Compatibility"; Result = "Pass" }
    } else {
        Write-Host "✗ Backward compatibility test failed" -ForegroundColor Red
        Write-Host "  Required properties: $hasRequiredProperties" -ForegroundColor Red
        Write-Host "  Enhanced properties: $hasEnhancedProperties" -ForegroundColor Red
        $testResults += @{ Test = "Backward Compatibility"; Result = "Fail" }
    }
}
catch {
    Write-Host "✗ Backward compatibility test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "Backward Compatibility"; Result = "Error: $($_.Exception.Message)" }
}

# Display test results summary
Write-Host "`n=== Test Results Summary ===" -ForegroundColor Yellow
$passCount = ($testResults | Where-Object { $_.Result -eq "Pass" }).Count
$totalCount = $testResults.Count

foreach ($result in $testResults) {
    $color = if ($result.Result -eq "Pass") { "Green" } else { "Red" }
    Write-Host "$($result.Test): $($result.Result)" -ForegroundColor $color
}

Write-Host "`nPassed: $passCount/$totalCount tests" -ForegroundColor $(if ($passCount -eq $totalCount) { "Green" } else { "Yellow" })

if ($passCount -eq $totalCount) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. ✗" -ForegroundColor Red
    exit 1
}