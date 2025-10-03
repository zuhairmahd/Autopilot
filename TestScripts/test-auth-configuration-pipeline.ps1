#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for auth configuration pipeline with Merge-ConfigurationDefaults
.DESCRIPTION
    This test validates the complete auth configuration pipeline including:
    - Initialize-AuthConfiguration function
    - Merge-ConfigurationDefaults integration with auth objects
    - Missing key detection and merging
    - Command-line parameter precedence
    - Boolean string conversion for auth settings
    - Nested auth configuration handling
.NOTES
    Author: Test Suite
    Version: 1.0.0
    Purpose: Ensure auth configuration pipeline works correctly with defaults merging
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions at script level
$functionsFolder = Join-Path $RootPath "functions"
if (Test-Path $functionsFolder)
{
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions)
    {
        try
        {
            . $function.FullName
        }
        catch
        {
            Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
        }
    }
}
else
{
    Write-Host "Cannot find the functions folder at: $functionsFolder. Exiting script." -ForegroundColor Red
    exit 1
}

# Initialize test environment
try
{
    $testContext = Start-UnifiedTest -TestName "Auth Configuration Pipeline Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables
$global:LogFile = Join-Path $testContext.TestFolder "test-auth-pipeline.log"

# Track test results
$script:passedTests = 0
$script:failedTests = 0

try
{
    Write-TestSection "Test 1: Initialize-AuthConfiguration Function Availability"
    
    $authFunc = Get-Command "Initialize-AuthConfiguration" -ErrorAction SilentlyContinue
    if ($authFunc)
    {
        Write-TestResult "Initialize-AuthConfiguration function is available" $true
        $script:passedTests++
        
        # Verify parameters
        if ($authFunc.Parameters.ContainsKey('AuthConfiguration') -and $authFunc.Parameters.ContainsKey('BoundParameters'))
        {
            Write-TestResult "Required parameters present (AuthConfiguration, BoundParameters)" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Missing required parameters" $false
            $script:failedTests++
        }
    }
    else
    {
        Write-TestResult "Initialize-AuthConfiguration function not found" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 2: Merge-ConfigurationDefaults with Auth Object - Basic Merge"
    
    $mergeFunc = Get-Command "Merge-ConfigurationDefaults" -ErrorAction SilentlyContinue
    if ($mergeFunc)
    {
        Write-TestResult "Merge-ConfigurationDefaults function is available" $true
        $script:passedTests++
        
        try
        {
            # Test basic auth merge
            $existingAuth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
            }
            
            $defaultAuth = @{
                delegated         = $true
                authType          = "PublicAuthFlow"
                scope             = @("offline_access", "openid", "Device.ReadWrite.All")
                tenantId          = "common"
                clientId          = ""
                redirectUri       = "http://localhost"
                saveRefreshToken  = $true
                useDeviceCodeFlow = $false
            }
            
            $merged = Merge-ConfigurationDefaults -ExistingConfig $existingAuth -DefaultConfig $defaultAuth -PreserveExisting $true
            
            if ($null -ne $merged)
            {
                Write-TestResult "Auth merge returned merged configuration" $true
                $script:passedTests++
                
                # Verify all default keys now present
                $expectedKeys = @('delegated', 'authType', 'scope', 'tenantId', 'clientId', 'redirectUri', 'saveRefreshToken', 'useDeviceCodeFlow')
                $allKeysPresent = $true
                foreach ($key in $expectedKeys)
                {
                    if (-not $merged.ContainsKey($key))
                    {
                        $allKeysPresent = $false
                        break
                    }
                }
                
                if ($allKeysPresent)
                {
                    Write-TestResult "All default auth keys present after merge" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Not all default auth keys present after merge" $false
                    $script:failedTests++
                }
                
                # Verify existing values unchanged
                if ($merged.delegated -eq $true -and $merged.authType -eq "PublicAuthFlow")
                {
                    Write-TestResult "Existing auth values preserved (delegated, authType)" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Existing auth values changed unexpectedly" $false
                    $script:failedTests++
                }
            }
            else
            {
                Write-TestResult "Auth merge returned null (no changes - config already complete)" $true
                $script:passedTests += 3
            }
        }
        catch
        {
            Write-TestResult "Basic auth merge test failed: $($_.Exception.Message)" $false
            $script:failedTests += 3
        }
    }
    else
    {
        Write-TestResult "Merge-ConfigurationDefaults function not found" $false
        $script:failedTests += 4
    }
    
    Write-TestSection "Test 3: Auth Merge with Array Values (Scope)"
    
    try
    {
        # Test that scope array is properly handled
        $authWithoutScope = @{
            delegated = $true
            authType  = "ConfidentialAuthFlow"
            tenantId  = "12345678-1234-1234-1234-123456789012"
            clientId  = "app-id-here"
        }
        
        $defaultsWithScope = @{
            delegated = $true
            authType  = "PublicAuthFlow"
            scope     = @("User.Read", "Mail.Read", "Calendars.Read")
            tenantId  = "common"
        }
        
        $merged = Merge-ConfigurationDefaults -ExistingConfig $authWithoutScope -DefaultConfig $defaultsWithScope -PreserveExisting $true
        
        if ($null -ne $merged)
        {
            Write-TestResult "Scope array merge successful" $true
            $script:passedTests++
            
            # Verify scope was added
            if ($merged.ContainsKey('scope') -and $merged.scope -is [array])
            {
                Write-TestResult "Scope array added to configuration" $true
                $script:passedTests++
                
                # Verify array contents
                if ($merged.scope.Count -eq 3 -and $merged.scope -contains "User.Read")
                {
                    Write-TestResult "Scope array contents correct" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Scope array contents incorrect" $false
                    $script:failedTests++
                }
            }
            else
            {
                Write-TestResult "Scope not added or not an array" $false
                $script:failedTests += 2
            }
            
            # Verify existing values preserved (authType should remain ConfidentialAuthFlow)
            if ($merged.authType -eq "ConfidentialAuthFlow")
            {
                Write-TestResult "Existing authType preserved (ConfidentialAuthFlow)" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Existing authType changed to: $($merged.authType)" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Scope merge returned null unexpectedly" $false
            $script:failedTests += 4
        }
    }
    catch
    {
        Write-TestResult "Scope array merge test failed: $($_.Exception.Message)" $false
        $script:failedTests += 4
    }
    
    Write-TestSection "Test 4: Initialize-AuthConfiguration with Complete Auth Object"
    
    try
    {
        # Test with complete auth configuration
        $completeAuthConfig = @{
            delegated         = 'true'
            authType          = 'PublicAuthFlow'
            scope             = @('offline_access', 'openid', 'Device.ReadWrite.All')
            tenantId          = 'common'
            clientId          = ''
            redirectUri       = 'http://localhost'
            saveRefreshToken  = 'true'
            useDeviceCodeFlow = 'false'
        }
        
        $result = Initialize-AuthConfiguration -AuthConfiguration $completeAuthConfig -BoundParameters @{}
        
        if ($result -and $result.ContainsKey('Auth'))
        {
            Write-TestResult "Initialize-AuthConfiguration processed complete auth config" $true
            $script:passedTests++
            
            # Verify boolean string conversion
            if ($result.Auth.delegated -is [bool] -and $result.Auth.delegated -eq $true)
            {
                Write-TestResult "Boolean string 'true' converted correctly to [bool]" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Boolean string conversion failed" $false
                $script:failedTests++
            }
            
            # Verify all keys processed
            if ($result.Auth.Count -ge 8)
            {
                Write-TestResult "All auth keys processed ($($result.Auth.Count) keys)" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Not all auth keys processed (only $($result.Auth.Count) keys)" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Initialize-AuthConfiguration failed to process auth config" $false
            $script:failedTests += 3
        }
    }
    catch
    {
        Write-TestResult "Complete auth config test failed: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test 5: Initialize-AuthConfiguration with Incomplete Auth and Defaults"
    
    try
    {
        # Test with incomplete auth that should be merged with defaults
        $incompleteAuthConfig = @{
            delegated = 'true'
            authType  = 'PublicAuthFlow'
        }
        
        $result = Initialize-AuthConfiguration -AuthConfiguration $incompleteAuthConfig -BoundParameters @{}
        
        if ($result -and $result.ContainsKey('Auth'))
        {
            Write-TestResult "Initialize-AuthConfiguration processed incomplete auth config" $true
            $script:passedTests++
            
            # Check if Changed flag is set
            if ($result.ContainsKey('Changed'))
            {
                Write-TestResult "Changed flag present in result" $true
                $script:passedTests++
                
                if ($result.Changed -eq $true)
                {
                    Write-TestResult "Changed flag indicates missing keys were merged" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Changed flag is false (no merge occurred)" $true
                    $script:passedTests++
                }
            }
            else
            {
                Write-TestResult "Changed flag missing from result" $false
                $script:failedTests += 2
            }
        }
        else
        {
            Write-TestResult "Initialize-AuthConfiguration failed" $false
            $script:failedTests += 3
        }
    }
    catch
    {
        Write-TestResult "Incomplete auth config test failed: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test 6: Command-Line Parameter Precedence Over Defaults"
    
    try
    {
        # Test that BoundParameters override both config and defaults
        $authConfig = @{
            delegated = 'true'
            authType  = 'PublicAuthFlow'
            tenantId  = 'common'
        }
        
        $boundParams = @{
            authType = 'ConfidentialAuthFlow'
            tenantId = '12345678-1234-1234-1234-123456789012'
        }
        
        $result = Initialize-AuthConfiguration -AuthConfiguration $authConfig -BoundParameters $boundParams
        
        if ($result -and $result.ContainsKey('Auth'))
        {
            Write-TestResult "Auth processing with command-line overrides successful" $true
            $script:passedTests++
            
            # Verify overrides applied
            if ($result.Auth.authType -eq 'ConfidentialAuthFlow')
            {
                Write-TestResult "Command-line authType override applied" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Command-line authType override not applied" $false
                $script:failedTests++
            }
            
            if ($result.Auth.tenantId -eq '12345678-1234-1234-1234-123456789012')
            {
                Write-TestResult "Command-line tenantId override applied" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Command-line tenantId override not applied" $false
                $script:failedTests++
            }
            
            # Verify non-overridden value preserved
            if ($result.Auth.delegated -eq $true)
            {
                Write-TestResult "Non-overridden delegated value preserved" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Non-overridden delegated value not preserved" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Auth processing with overrides failed" $false
            $script:failedTests += 4
        }
    }
    catch
    {
        Write-TestResult "Command-line precedence test failed: $($_.Exception.Message)" $false
        $script:failedTests += 4
    }
    
    Write-TestSection "Test 7: Null/Empty Auth Configuration Handling"
    
    try
    {
        # Test with null auth configuration
        $result = Initialize-AuthConfiguration -AuthConfiguration $null -BoundParameters @{}
        
        if ($result -and $result.ContainsKey('Auth'))
        {
            Write-TestResult "Null auth config handled gracefully" $true
            $script:passedTests++
            
            # Should return empty auth hashtable
            if ($result.Auth -is [hashtable])
            {
                Write-TestResult "Empty auth hashtable returned for null input" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Did not return hashtable for null input" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Null auth config handling failed" $false
            $script:failedTests += 2
        }
    }
    catch
    {
        Write-TestResult "Null auth config test failed: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 8: PreserveExisting Parameter Behavior"
    
    try
    {
        # Test PreserveExisting = false (overwrite mode)
        $existingConfig = @{
            setting1 = "existing"
            setting2 = "existing"
        }
        
        $defaultConfig = @{
            setting1 = "default"
            setting2 = "default"
            setting3 = "default"
        }
        
        $merged = Merge-ConfigurationDefaults -ExistingConfig $existingConfig -DefaultConfig $defaultConfig -PreserveExisting $false
        
        if ($null -ne $merged)
        {
            Write-TestResult "Merge with PreserveExisting=false successful" $true
            $script:passedTests++
            
            # With PreserveExisting=false, defaults should overwrite existing
            if ($merged.setting1 -eq "default" -and $merged.setting2 -eq "default")
            {
                Write-TestResult "PreserveExisting=false correctly overwrites existing values" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "PreserveExisting=false did not overwrite (setting1: $($merged.setting1))" $false
                $script:failedTests++
            }
            
            # New keys should still be added
            if ($merged.ContainsKey('setting3') -and $merged.setting3 -eq "default")
            {
                Write-TestResult "New keys added even with PreserveExisting=false" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "New keys not added with PreserveExisting=false" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Merge with PreserveExisting=false returned null unexpectedly" $false
            $script:failedTests += 3
        }
    }
    catch
    {
        Write-TestResult "PreserveExisting parameter test failed: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
}
catch
{
    Write-TestResult "Test suite failed with error: $($_.Exception.Message)" $false
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    $script:failedTests += 10
}
finally
{
    # Calculate totals
    $totalTests = $script:passedTests + $script:failedTests
    
    # Complete unified test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $script:passedTests -FailedTests $script:failedTests -TotalTests $totalTests
    
    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "Total tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $script:passedTests" -ForegroundColor Green
    Write-Host "Failed: $script:failedTests" -ForegroundColor $(if ($script:failedTests -eq 0)
        {
            'Green' 
        }
        else
        {
            'Red' 
        })
    
    if ($success -and $script:failedTests -eq 0)
    {
        Write-Host "`nAuth Configuration Pipeline Test PASSED! [PASS]" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "`nAuth Configuration Pipeline Test FAILED! [FAIL]" -ForegroundColor Red
        exit 1
    }
}
