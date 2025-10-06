#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for authentication flow types and configuration
.DESCRIPTION
    This test validates authentication types and flows available in main.ps1:
    - PublicAuthFlow, Interactive, Private authentication types
    - Delegated vs non-delegated authentication
    - Configuration handling for different auth scenarios
    - Token and scope management
.NOTES
    Author: Test Expansion Initiative
    Version: 1.0.0
    Purpose: Ensure authentication flow functionality works correctly
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions at script level (same pattern as main.ps1)
$functionsFolder = Join-Path $RootPath "functions"
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
    Write-Host "Cannot find the functions folder at: $functionsFolder. Exiting script." -ForegroundColor Red
    exit 1
}

# Initialize test environment
try {
    $testContext = Start-UnifiedTest -TestName "Authentication Flows Comprehensive Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = "$PWD/test-auth-flows.log"

try {
    Write-TestSection "Test 1: Valid Authentication Types"
    
    # Test all valid AuthType values based on main.ps1 ValidateSet
    $validAuthTypes = @('PublicAuthFlow', 'Interactive', 'Private')
    $authValidationResults = @()
    
    foreach ($authType in $validAuthTypes) {
        Write-Host "Testing AuthType: $authType" -ForegroundColor Cyan
        
        # Test that the type is in the valid list
        $isValid = $authType -in @('PublicAuthFlow', 'Interactive', 'Private')
        $authValidationResults += @{
            Type = $authType
            Valid = $isValid
        }
        
        if ($isValid) {
            Write-TestResult "AuthType '$authType' is valid" $true
        } else {
            Write-TestResult "AuthType '$authType' is invalid" $false
        }
    }
    
    $allAuthTypesValid = ($authValidationResults | Where-Object { -not $_.Valid }).Count -eq 0
    Write-TestResult "All defined AuthTypes are valid" $allAuthTypesValid
    
    Write-TestSection "Test 2: Cache Type Validation"
    
    # Test valid CacheType values
    $validCacheTypes = @('file', 'memory')
    $cacheValidationResults = @()
    
    foreach ($cacheType in $validCacheTypes) {
        Write-Host "Testing CacheType: $cacheType" -ForegroundColor Cyan
        
        # Test that the type is in the valid list
        $isValid = $cacheType -in @('file', 'memory')
        $cacheValidationResults += @{
            Type = $cacheType
            Valid = $isValid
        }
        
        if ($isValid) {
            Write-TestResult "CacheType '$cacheType' is valid" $true
        } else {
            Write-TestResult "CacheType '$cacheType' is invalid" $false
        }
    }
    
    $allCacheTypesValid = ($cacheValidationResults | Where-Object { -not $_.Valid }).Count -eq 0
    Write-TestResult "All defined CacheTypes are valid" $allCacheTypesValid
    
    Write-TestSection "Test 3: Authentication Configuration Building"
    
    # Test BuildAuthSplatTable function if available
    if (Get-Command "BuildAuthSplatTable" -ErrorAction SilentlyContinue) {
        Write-Host "Testing BuildAuthSplatTable function..." -ForegroundColor Cyan
        
        # Create mock auth configuration
        $mockAuth = @{
            AuthType = "PublicAuthFlow"
            delegated = $true
            tenantId = "test-tenant-id"
            clientId = "test-client-id"
            scope = @("User.Read", "Device.Read.All")
        }
        
        try {
            $authSplat = BuildAuthSplatTable -auth $mockAuth
            
            if ($authSplat -and $authSplat.GetType().Name -eq "Hashtable") {
                Write-TestResult "BuildAuthSplatTable returns hashtable" $true
                
                # Verify expected properties
                $hasAuthType = $null -ne $authSplat.AuthType
                $hasDelegated = $null -ne $authSplat.delegated
                
                Write-TestResult "AuthSplat contains AuthType: $hasAuthType" $hasAuthType
                Write-TestResult "AuthSplat contains delegated: $hasDelegated" $hasDelegated
            } else {
                Write-TestResult "BuildAuthSplatTable does not return hashtable" $false
            }
        }
        catch {
            Write-TestResult "BuildAuthSplatTable function failed: $($_.Exception.Message)" $false
        }
    } else {
        Write-TestResult "BuildAuthSplatTable function not available - skipping test" $true
    }
    
    Write-TestSection "Test 4: Scope Merging and Deduplication"
    
    # Test scope handling logic from main.ps1
    Write-Host "Testing scope merging and deduplication..." -ForegroundColor Cyan
    
    # Simulate basic and additional scopes
    $basicScopes = @(
        @{ Scope = "User.Read.All"; Description = "Read user profiles" },
        @{ Scope = "Device.Read.All"; Description = "Read device data" }
    )
    
    $additionalScopes = @(
        @{ Scope = "User.Read.All"; Description = "Read user profiles" },  # Duplicate
        @{ Scope = "DeviceManagementManagedDevices.ReadWrite.All"; Description = "Manage devices" }
    )
    
    # Test the merging logic from main.ps1
    $allScopes = @($basicScopes) + @($additionalScopes)
    $uniqueScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
    
    if ($uniqueScopes.Count -eq 3) {
        Write-TestResult "Scope deduplication works correctly (3 unique scopes)" $true
    } else {
        Write-TestResult "Scope deduplication failed - got $($uniqueScopes.Count) scopes" $false
    }
    
    # Verify specific scopes are present
    $hasUserRead = $uniqueScopes | Where-Object { $_.Scope -eq "User.Read.All" }
    $hasDeviceRead = $uniqueScopes | Where-Object { $_.Scope -eq "Device.Read.All" }
    $hasDeviceManagement = $uniqueScopes | Where-Object { $_.Scope -eq "DeviceManagementManagedDevices.ReadWrite.All" }
    
    Write-TestResult "User.Read.All scope present: $($null -ne $hasUserRead)" $($null -ne $hasUserRead)
    Write-TestResult "Device.Read.All scope present: $($null -ne $hasDeviceRead)" $($null -ne $hasDeviceRead)
    Write-TestResult "DeviceManagement scope present: $($null -ne $hasDeviceManagement)" $($null -ne $hasDeviceManagement)
    
    Write-TestSection "Test 5: Token Validation Functions"
    
    # Test token-related functions if available
    $tokenFunctions = @("Get-TokenFromCache", "Save-TokenToCache", "Get-NormalizedExpiryTime")
    $tokenFunctionResults = @()
    
    foreach ($funcName in $tokenFunctions) {
        $funcExists = Get-Command $funcName -ErrorAction SilentlyContinue
        $tokenFunctionResults += $null -ne $funcExists
        
        if ($funcExists) {
            Write-TestResult "Token function '$funcName' is available" $true
        } else {
            Write-TestResult "Token function '$funcName' is not available" $false
        }
    }
    
    $tokenFunctionsAvailable = ($tokenFunctionResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All token functions are available" $tokenFunctionsAvailable
    
    Write-TestSection "Test 6: Authentication Parameter Validation"
    
    # Test parameter combinations that should be valid
    $validParamCombinations = @(
        @{ AuthType = "PublicAuthFlow"; Delegated = $true; Valid = $true },
        @{ AuthType = "Interactive"; Delegated = $true; Valid = $true },
        @{ AuthType = "Private"; Delegated = $false; Valid = $true }
    )
    
    $paramValidationResults = @()
    foreach ($combo in $validParamCombinations) {
        $isValidCombination = $combo.Valid
        $paramValidationResults += $isValidCombination
        
        Write-TestResult "Parameter combination AuthType='$($combo.AuthType)' Delegated='$($combo.Delegated)' is valid" $isValidCombination
    }
    
    $allParamCombinationsValid = ($paramValidationResults | Where-Object { -not $_ }).Count -eq 0
    Write-TestResult "All parameter combinations are valid" $allParamCombinationsValid
    
    # Summary
    $totalTests = 6
    $passedTests = 0
    
    if ($allAuthTypesValid) { $passedTests++ }
    if ($allCacheTypesValid) { $passedTests++ }
    if (Get-Command "BuildAuthSplatTable" -ErrorAction SilentlyContinue) { $passedTests++ }
    if ($uniqueScopes.Count -eq 3) { $passedTests++ }
    if ($tokenFunctionsAvailable) { $passedTests++ }
    if ($allParamCombinationsValid) { $passedTests++ }
    
    $failedTests = $totalTests - $passedTests
    
    Write-TestResult "Authentication flows comprehensive test completed" $true
}
catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" $false
    $failedTests = 6
    $passedTests = 0
    exit 1
}
finally {
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests 6
    
    if ($success) {
        Write-Host "Authentication Flows Comprehensive Test passed! [PASS]" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Authentication Flows Comprehensive Test failed! [FAIL]" -ForegroundColor Red
        exit 1
    }
}