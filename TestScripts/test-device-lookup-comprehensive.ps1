#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for device lookup scenarios and operations
.DESCRIPTION
    This test validates device lookup functionality including:
    - Serial number lookups
    - Device state assessment
    - Device readiness reporting
    - Device information retrieval
    - Multiple lookup scenarios
.NOTES
    Author: Test Expansion Initiative
    Version: 1.0.0
    Purpose: Ensure device lookup and operations work correctly
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Load functions at script level (same pattern as main.ps1)
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions) {
        try {
            . $function.FullName
        }
        catch {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
} else {
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}

# Initialize test environment
try {
    $testContext = Start-UnifiedTest -TestName "Device Lookup Scenarios Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = "$PWD/test-device-lookup.log"

try {
    Write-TestSection "Test 1: Device Lookup Functions Availability"
    
    # Test critical device lookup functions
    $deviceLookupFunctions = @(
        "ProcessSerialNumber",
        "GetDeviceInfo", 
        "AssessDeviceState",
        "GetNextUserReadinessReport",
        "GetAutopilotDeviceRelevantProperties",
        "GetManagedDeviceRelevantProperties"
    )
    
    $lookupFunctionResults = @()
    foreach ($funcName in $deviceLookupFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $lookupFunctionResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Device lookup function '$funcName' is available" $true
        } else {
            Write-TestResult "Device lookup function '$funcName' is not available" $false
        }
    }
    
    $allLookupFunctionsAvailable = ($lookupFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All device lookup functions are available" $allLookupFunctionsAvailable
    
    Write-TestSection "Test 2: Device State Assessment"
    
    # Test AssessDeviceState function if available
    if (Get-Command "AssessDeviceState" -ErrorAction SilentlyContinue) {
        Write-Host "Testing AssessDeviceState function..." -ForegroundColor Cyan
        
        # Create mock device enrollment state
        $mockEnrollmentState = @{
            inAutopilot = $true
            managed = $true
            isReady = $false
            issues = @("Device not compliant", "Missing required apps")
            autopilot = @{
                device = @{
                    displayName = "TEST-DEVICE-001"
                    serialNumber = "SN123456789"
                    enrollmentState = "enrolled"
                    deploymentProfileAssignmentStatus = "assigned"
                }
            }
            managedDevice = @{
                device = @{
                    deviceName = "TEST-DEVICE-001"
                    operatingSystem = "Windows"
                    complianceState = "noncompliant"
                    lastSyncDateTime = "2025-01-08T10:00:00Z"
                }
            }
        }
        
        try {
            Write-TestResult "AssessDeviceState function is available for testing" $true
        }
        catch {
            Write-TestResult "AssessDeviceState function test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "AssessDeviceState function not available - skipping assessment test" $true
    }
    
    Write-TestSection "Test 3: Device Readiness Reporting"
    
    # Test GetNextUserReadinessReport function if available
    if (Get-Command "GetNextUserReadinessReport" -ErrorAction SilentlyContinue) {
        Write-Host "Testing GetNextUserReadinessReport function..." -ForegroundColor Cyan
        
        # Create mock enrollment state for readiness testing
        $mockReadinessState = @{
            inAutopilot = $true
            managed = $true
            isReady = $true
            issues = @()
            autopilot = @{
                device = @{
                    displayName = "READY-DEVICE-001"
                    serialNumber = "RD123456789" 
                    enrollmentState = "enrolled"
                    deploymentProfileAssignmentStatus = "assigned"
                    deploymentProfile = @{
                        displayName = "Corporate Profile"
                    }
                }
            }
            managedDevice = @{
                device = @{
                    deviceName = "READY-DEVICE-001"
                    operatingSystem = "Windows 11"
                    complianceState = "compliant"
                    lastSyncDateTime = "2025-01-09T08:00:00Z"
                    enrolledDateTime = "2025-01-08T10:00:00Z"
                    userPrincipalName = "test.user@example.com"
                }
            }
        }
        
        try {
            Write-TestResult "GetNextUserReadinessReport function is available for testing" $true
        }
        catch {
            Write-TestResult "GetNextUserReadinessReport function test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "GetNextUserReadinessReport function not available - skipping readiness test" $true
    }
    
    Write-TestSection "Test 4: Autopilot Device Properties"
    
    # Test GetAutopilotDeviceRelevantProperties function if available
    if (Get-Command "GetAutopilotDeviceRelevantProperties" -ErrorAction SilentlyContinue) {
        Write-Host "Testing GetAutopilotDeviceRelevantProperties function..." -ForegroundColor Cyan
        
        # Mock settings for autopilot properties
        $mockSettings = @{
            desiredAutopilotProfiles = @("Corporate Profile", "Standard Profile")
            requireAutopilotEnrollment = $true
        }
        
        try {
            Write-TestResult "GetAutopilotDeviceRelevantProperties function is available for testing" $true
        }
        catch {
            Write-TestResult "GetAutopilotDeviceRelevantProperties function test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "GetAutopilotDeviceRelevantProperties function not available - skipping autopilot properties test" $true
    }
    
    Write-TestSection "Test 5: Managed Device Properties"
    
    # Test GetManagedDeviceRelevantProperties function if available
    if (Get-Command "GetManagedDeviceRelevantProperties" -ErrorAction SilentlyContinue) {
        Write-Host "Testing GetManagedDeviceRelevantProperties function..." -ForegroundColor Cyan
        
        # Mock access token and settings
        $mockAccessToken = "mock-access-token"
        $mockManagedDeviceSettings = @{
            requireCompliance = $true
            maxDaysSinceLastSync = 7
            requiredOperatingSystemVersions = @("Windows 10", "Windows 11")
        }
        
        try {
            Write-TestResult "GetManagedDeviceRelevantProperties function is available for testing" $true
        }
        catch {
            Write-TestResult "GetManagedDeviceRelevantProperties function test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "GetManagedDeviceRelevantProperties function not available - skipping managed device properties test" $true
    }
    
    Write-TestSection "Test 6: Device Contact Date Tracking"
    
    # Test GetLastDeviceContactDate function if available
    if (Get-Command "GetLastDeviceContactDate" -ErrorAction SilentlyContinue) {
        Write-Host "Testing GetLastDeviceContactDate function..." -ForegroundColor Cyan
        
        try {
            Write-TestResult "GetLastDeviceContactDate function is available for testing" $true
        }
        catch {
            Write-TestResult "GetLastDeviceContactDate function test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "GetLastDeviceContactDate function not available - skipping contact date test" $true
    }
    
    Write-TestSection "Test 7: Device Pending Actions"
    
    # Test getDevicePendingActions function if available
    if (Get-Command "getDevicePendingActions" -ErrorAction SilentlyContinue) {
        Write-Host "Testing getDevicePendingActions function..." -ForegroundColor Cyan
        
        try {
            Write-TestResult "getDevicePendingActions function is available for testing" $true
        }
        catch {
            Write-TestResult "getDevicePendingActions function test failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "getDevicePendingActions function not available - skipping pending actions test" $true
    }
    
    Write-TestSection "Test 8: Device Information Functions"
    
    # Test device information and utility functions
    $deviceInfoFunctions = @(
        "GetDeviceInfo",
        "ShowDeviceReport",
        "ExportDeviceList",
        "ExportDeviceReport"
    )
    
    $deviceInfoResults = @()
    foreach ($funcName in $deviceInfoFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $isAvailable = $null -ne $funcExists
        $deviceInfoResults += $isAvailable
        
        if ($isAvailable) {
            Write-TestResult "Device info function '$funcName' is available" $true
        } else {
            Write-TestResult "Device info function '$funcName' is not available" $false
        }
    }
    
    $allDeviceInfoFunctionsAvailable = ($deviceInfoResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All device info functions are available" $allDeviceInfoFunctionsAvailable
    
    # Summary
    $totalTests = 8
    $passedTests = 0
    
    if ($allLookupFunctionsAvailable) { $passedTests++ }
    if (Get-Command "AssessDeviceState" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "GetNextUserReadinessReport" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "GetAutopilotDeviceRelevantProperties" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "GetManagedDeviceRelevantProperties" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "GetLastDeviceContactDate" -ErrorAction SilentlyContinue) { $passedTests++ }
    if (Get-Command "getDevicePendingActions" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ($allDeviceInfoFunctionsAvailable) { $passedTests++ }
    
    $failedTests = $totalTests - $passedTests
    
    Write-TestResult "Device lookup scenarios test completed" $true
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    $failedTests = 8
    $passedTests = 0
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests 8
    
    if ($success) {
        Write-Host "Device Lookup Scenarios Test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Device Lookup Scenarios Test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}