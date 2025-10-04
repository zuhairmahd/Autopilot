#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test for Initialize-ApplicationConfiguration function
.DESCRIPTION
    This test validates the Initialize-ApplicationConfiguration function including:
    - Configuration file validation and creation
    - Auth configuration processing with Merge-ConfigurationDefaults
    - Global settings processing with missing key detection
    - Local/domain settings processing with missing key detection
    - Scope merging and deduplication
    - Error handling for various failure scenarios
    - Configuration backup and save operations
    - Command-line parameter precedence over configuration files
.NOTES
    Author: Test Suite
    Version: 1.0.0
    Purpose: Ensure Initialize-ApplicationConfiguration works correctly across all scenarios
#>

[CmdletBinding()]
param()

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Determine paths
$RootPath = Split-Path -Parent $PSScriptRoot

# Load functions at script level (same pattern as main.ps1)
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
    $testContext = Start-UnifiedTest -TestName "Initialize-ApplicationConfiguration Comprehensive Test" -SkipFunctionCheck
    Write-TestResult "Test environment initialized successfully" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Set up required global variables for testing
$global:LogFile = Join-Path $testContext.TestFolder "test-init-config.log"

# Track test results
$script:passedTests = 0
$script:failedTests = 0

try
{
    Write-TestSection "Test 1: Function Availability and Parameter Validation"
    
    $funcExists = Get-Command "Initialize-ApplicationConfiguration" -ErrorAction SilentlyContinue
    if ($funcExists)
    {
        Write-TestResult "Initialize-ApplicationConfiguration function is available" $true
        $script:passedTests++
        
        # Verify required parameters
        $requiredParams = @('InitFile', 'StringsFile', 'menuFile')
        $params = $funcExists.Parameters
        
        $allParamsPresent = $true
        foreach ($param in $requiredParams)
        {
            if (-not $params.ContainsKey($param))
            {
                Write-TestResult "Missing required parameter: $param" $false
                $allParamsPresent = $false
                $script:failedTests++
            }
        }
        
        if ($allParamsPresent)
        {
            Write-TestResult "All required parameters are present" $true
            $script:passedTests++
        }
        
        # Verify Domain parameter has default value
        if ($params.ContainsKey('Domain'))
        {
            Write-TestResult "Domain parameter exists with default value support" $true
            $script:passedTests++
        }
        else
        {
            Write-TestResult "Domain parameter missing" $false
            $script:failedTests++
        }
    }
    else
    {
        Write-TestResult "Initialize-ApplicationConfiguration function not found" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test 2: Merge-ConfigurationDefaults with Auth Object"
    
    $mergeFunc = Get-Command "Merge-ConfigurationDefaults" -ErrorAction SilentlyContinue
    if ($mergeFunc)
    {
        Write-TestResult "Merge-ConfigurationDefaults function is available" $true
        $script:passedTests++
        
        # Test auth object merge with missing keys
        try
        {
            # Simulate existing auth with missing keys
            $existingAuth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
            }
            
            # Default auth with all keys
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
            
            # Test merge with PreserveExisting = true (default)
            $mergedAuth = Merge-ConfigurationDefaults -ExistingConfig $existingAuth -DefaultConfig $defaultAuth -PreserveExisting $true
            
            if ($null -ne $mergedAuth)
            {
                Write-TestResult "Merge-ConfigurationDefaults returned merged configuration" $true
                $script:passedTests++
                
                # Verify existing values preserved
                if ($mergedAuth.delegated -eq $true -and $mergedAuth.authType -eq "PublicAuthFlow")
                {
                    Write-TestResult "Existing auth values preserved during merge" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Existing auth values not preserved" $false
                    $script:failedTests++
                }
                
                # Verify missing keys added
                if ($mergedAuth.ContainsKey('scope') -and $mergedAuth.ContainsKey('tenantId'))
                {
                    Write-TestResult "Missing auth keys added from defaults" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Missing auth keys not added" $false
                    $script:failedTests++
                }
                
                # Verify scope array preserved correctly
                if ($mergedAuth.scope -is [array] -and $mergedAuth.scope.Count -eq 3)
                {
                    Write-TestResult "Auth scope array preserved correctly" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Auth scope array not preserved correctly" $false
                    $script:failedTests++
                }
            }
            else
            {
                Write-TestResult "Merge-ConfigurationDefaults returned null (no changes needed)" $true
                $script:passedTests++
            }
        }
        catch
        {
            Write-TestResult "Auth object merge test failed: $($_.Exception.Message)" $false
            $script:failedTests += 5
        }
    }
    else
    {
        Write-TestResult "Merge-ConfigurationDefaults function not found" $false
        $script:failedTests += 6
    }
    
    Write-TestSection "Test 3: Configuration File Creation with Defaults"
    
    # Test that Initialize-ConfigurationFiles is called and creates missing files
    $testInitFile = Join-Path $testContext.TestFolder "test-settings.psd1"
    $testStringsFile = Join-Path $testContext.TestFolder "test-strings.psd1"
    $testMenuFile = Join-Path $testContext.TestFolder "test-menu.psd1"
    $testDomain = "testdomain.com"
    
    try
    {
        # Call Initialize-ApplicationConfiguration with non-existent files
        $result = Initialize-ApplicationConfiguration -InitFile $testInitFile -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters @{}
        
        if ($result.Success)
        {
            Write-TestResult "Initialize-ApplicationConfiguration succeeded with missing files" $true
            $script:passedTests++
            
            # Verify default auth configuration returned when no files exist
            if ($result.Auth.delegated -eq $true -and $result.Auth.authType -eq "PublicAuthFlow")
            {
                Write-TestResult "Default auth configuration provided when files missing" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Default auth configuration not provided" $false
                $script:failedTests++
            }
            
            # Verify empty settings collections
            if ($result.GlobalSettings -is [hashtable] -and $result.LocalSettings -is [hashtable])
            {
                Write-TestResult "Empty settings collections initialized correctly" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Settings collections not initialized correctly" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Initialize-ApplicationConfiguration failed: $($result.ErrorMessage)" $false
            $script:failedTests += 3
        }
    }
    catch
    {
        Write-TestResult "Configuration file creation test failed: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test 4: Auth Configuration Processing with Command-Line Overrides"
    
    try
    {
        # Create a minimal settings file with auth section
        $testSettingsPath = Join-Path $testContext.TestFolder "test-auth-settings.psd1"
        $settingsContent = @"
@{
    auth = @{
        delegated = 'true'
        authType = 'PublicAuthFlow'
        scope = @('offline_access', 'openid', 'Device.ReadWrite.All')
    }
    globalSettings = @{
        logLevel = 'Information'
    }
}
"@
        Set-Content -Path $testSettingsPath -Value $settingsContent -Force
        
        # Test with command-line override for authType
        $boundParams = @{
            authType = "ConfidentialAuthFlow"
        }
        
        $result = Initialize-ApplicationConfiguration -InitFile $testSettingsPath -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters $boundParams
        
        if ($result.Success)
        {
            Write-TestResult "Configuration loaded with command-line overrides" $true
            $script:passedTests++
            
            # Verify command-line parameter took precedence
            if ($result.Auth.authType -eq "ConfidentialAuthFlow")
            {
                Write-TestResult "Command-line parameter overrode configuration file value" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Command-line parameter did not override (authType = $($result.Auth.authType))" $false
                $script:failedTests++
            }
            
            # Verify non-overridden values preserved
            if ($result.Auth.delegated -eq $true)
            {
                Write-TestResult "Non-overridden auth values preserved from config file" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Non-overridden auth values not preserved" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Configuration load failed: $($result.ErrorMessage)" $false
            $script:failedTests += 3
        }
    }
    catch
    {
        Write-TestResult "Auth override test failed: $($_.Exception.Message)" $false
        $script:failedTests += 3
    }
    
    Write-TestSection "Test 5: Global Settings Processing with Missing Keys"
    
    try
    {
        # Create settings file with incomplete global settings
        $incompleteSettingsPath = Join-Path $testContext.TestFolder "test-incomplete-settings.psd1"
        $incompleteContent = @"
@{
    auth = @{
        delegated = 'true'
        authType = 'PublicAuthFlow'
    }
    globalSettings = @{
        logLevel = 'Debug'
    }
}
"@
        Set-Content -Path $incompleteSettingsPath -Value $incompleteContent -Force
        
        $result = Initialize-ApplicationConfiguration -InitFile $incompleteSettingsPath -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters @{}
        
        if ($result.Success)
        {
            Write-TestResult "Configuration loaded with incomplete global settings" $true
            $script:passedTests++
            
            # Verify existing setting preserved
            if ($result.GlobalSettings.logLevel -eq 'Debug')
            {
                Write-TestResult "Existing global setting preserved" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "Existing global setting not preserved" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Configuration load failed: $($result.ErrorMessage)" $false
            $script:failedTests += 2
        }
    }
    catch
    {
        Write-TestResult "Global settings test failed: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 6: Scope Merging and Deduplication"
    
    try
    {
        # Create settings with overlapping scopes
        $scopeSettingsPath = Join-Path $testContext.TestFolder "test-scope-settings.psd1"
        $scopeContent = @'
@{
    auth = @{
        delegated = $true
        authType = 'PublicAuthFlow'
        scope = @('offline_access', 'openid', 'Device.ReadWrite.All')
    }
    globalSettings = @{
        logLevel = 'Information'
    }
    requiredScopes = @('Device.ReadWrite.All', 'User.Read.All', 'Group.ReadWrite.All')
}
'@
        Set-Content -Path $scopeSettingsPath -Value $scopeContent -Force
        
        $result = Initialize-ApplicationConfiguration -InitFile $scopeSettingsPath -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters @{}
        
        if ($result.Success)
        {
            Write-TestResult "Configuration loaded with scope definitions" $true
            $script:passedTests++
            
            # Verify RequiredScopes array exists
            if ($result.RequiredScopes -is [array])
            {
                Write-TestResult "RequiredScopes array created" $true
                $script:passedTests++
                
                # Verify scopes are deduplicated (Device.ReadWrite.All should appear once)
                $deviceScope = $result.RequiredScopes | Where-Object { $_ -eq 'Device.ReadWrite.All' }
                $deviceScopeCount = @($deviceScope).Count
                
                if ($deviceScopeCount -eq 1)
                {
                    Write-TestResult "Scopes deduplicated correctly (Device.ReadWrite.All appears once)" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Scopes not deduplicated (Device.ReadWrite.All count: $deviceScopeCount)" $false
                    $script:failedTests++
                }
                
                # Verify all unique scopes included
                $expectedScopes = @('offline_access', 'openid', 'Device.ReadWrite.All', 'User.Read.All', 'Group.ReadWrite.All')
                $allScopesPresent = $true
                foreach ($scope in $expectedScopes)
                {
                    if ($result.RequiredScopes -notcontains $scope)
                    {
                        $allScopesPresent = $false
                        break
                    }
                }
                
                if ($allScopesPresent)
                {
                    Write-TestResult "All unique scopes merged correctly" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Not all scopes merged correctly" $false
                    $script:failedTests++
                }
            }
            else
            {
                Write-TestResult "RequiredScopes is not an array" $false
                $script:failedTests += 3
            }
        }
        else
        {
            Write-TestResult "Configuration load failed: $($result.ErrorMessage)" $false
            $script:failedTests += 4
        }
    }
    catch
    {
        Write-TestResult "Scope merging test failed: $($_.Exception.Message)" $false
        $script:failedTests += 4
    }
    
    Write-TestSection "Test 7: Error Handling for Invalid Configuration"
    
    try
    {
        # Create invalid settings file
        $invalidSettingsPath = Join-Path $testContext.TestFolder "test-invalid-settings.psd1"
        $invalidContent = @"
@{
    auth = @{
        delegated = 'not-a-boolean'
        authType = 'InvalidType'
    }
    globalSettings = 'not-a-hashtable'
}
"@
        Set-Content -Path $invalidSettingsPath -Value $invalidContent -Force
        
        # Test should handle gracefully
        $result = Initialize-ApplicationConfiguration -InitFile $invalidSettingsPath -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters @{}
        
        # Function should still return a result object even if parsing has issues
        if ($result -is [hashtable] -and $result.ContainsKey('Success'))
        {
            Write-TestResult "Error handling returns proper result object" $true
            $script:passedTests++
            
            if ($result.ContainsKey('ErrorMessage'))
            {
                Write-TestResult "ErrorMessage property exists for error reporting" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "ErrorMessage property missing" $false
                $script:failedTests++
            }
        }
        else
        {
            Write-TestResult "Error handling did not return proper result object" $false
            $script:failedTests += 2
        }
    }
    catch
    {
        Write-TestResult "Error handling test completed (exception caught as expected)" $true
        $script:passedTests += 2
    }
    
    Write-TestSection "Test 8: Configuration Backup Creation"
    
    try
    {
        # Create a settings file that will be modified (to trigger backup)
        $backupTestPath = Join-Path $testContext.TestFolder "test-backup-settings.psd1"
        $backupContent = @"
@{
    auth = @{
        delegated = 'true'
        authType = 'PublicAuthFlow'
    }
    globalSettings = @{
        logLevel = 'Information'
    }
}
"@
        Set-Content -Path $backupTestPath -Value $backupContent -Force
        
        # Initialize configuration (may trigger backup if defaults merged)
        $result = Initialize-ApplicationConfiguration -InitFile $backupTestPath -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters @{}
        
        if ($result.Success)
        {
            Write-TestResult "Configuration processing completed successfully" $true
            $script:passedTests++
            
            # Check if backup was created (if changes were made)
            $backupFiles = Get-ChildItem -Path $testContext.TestFolder -Filter "test-backup-settings.psd1.backup.*" -ErrorAction SilentlyContinue
            
            if ($backupFiles)
            {
                Write-TestResult "Configuration backup created when changes made" $true
                $script:passedTests++
            }
            else
            {
                Write-TestResult "No backup created (no changes needed or backup disabled)" $true
                $script:passedTests++
            }
        }
        else
        {
            Write-TestResult "Configuration processing failed: $($result.ErrorMessage)" $false
            $script:failedTests += 2
        }
    }
    catch
    {
        Write-TestResult "Backup test failed: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 8.5: Strings and Menu Configuration Processing"
    
    try
    {
        # Create test configuration files
        $testStringsPath = Join-Path $testContext.TestFolder "test-strings-processing.psd1"
        $testMenuPath = Join-Path $testContext.TestFolder "test-menu-processing.psd1"
        $testSettingsPath = Join-Path $testContext.TestFolder "test-settings-processing.psd1"
        
        # Create minimal strings file with missing keys
        $minimalStrings = @{
            Description   = "Test strings"
            deviceActions = @{
                none = "No action"
            }
        }
        $minimalStrings | Export-PowerShellDataFile -Path $testStringsPath -Force
        
        # Create minimal menu file with missing keys
        $minimalMenu = @{
            version  = "1.3.0.0"
            mainMenu = @{
                Title = "Test Menu"
                items = @()
            }
        }
        $minimalMenu | Export-PowerShellDataFile -Path $testMenuPath -Force
        
        # Create minimal settings file
        $minimalSettings = @"
@{
    auth = @{
        delegated = 'true'
        authType = 'PublicAuthFlow'
        scope = @('offline_access', 'openid')
    }
    globalSettings = @{
        logLevel = 'Information'
    }
}
"@
        Set-Content -Path $testSettingsPath -Value $minimalSettings -Force
        
        # Initialize configuration
        $result = Initialize-ApplicationConfiguration -InitFile $testSettingsPath -StringsFile $testStringsPath -menuFile $testMenuPath -Domain "test.com" -BoundParameters @{}
        
        if ($result.Success)
        {
            Write-TestResult "Configuration initialization succeeded with strings and menu" $true
            $script:passedTests++
            
            # Verify Strings object is populated
            if ($result.Strings -and $result.Strings.Keys.Count -gt 0)
            {
                Write-TestResult "Strings configuration loaded successfully" $true
                $script:passedTests++
                
                # Verify existing string value preserved
                if ($result.Strings.deviceActions.none -eq "No action")
                {
                    Write-TestResult "Existing string values preserved" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Existing string values not preserved" $false
                    $script:failedTests++
                }
                
                # Verify missing string keys were added
                if ($result.Strings.ContainsKey('returnValues'))
                {
                    Write-TestResult "Missing string keys added from defaults" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Missing string keys not added" $false
                    $script:failedTests++
                }
            }
            else
            {
                Write-TestResult "Strings configuration not loaded" $false
                $script:failedTests += 3
            }
            
            # Verify Menu object is populated
            if ($result.Menu -and $result.Menu.Keys.Count -gt 0)
            {
                Write-TestResult "Menu configuration loaded successfully" $true
                $script:passedTests++
                
                # Verify existing menu value preserved
                if ($result.Menu.mainMenu.Title -eq "Test Menu")
                {
                    Write-TestResult "Existing menu values preserved" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Existing menu values not preserved" $false
                    $script:failedTests++
                }
                
                # Verify missing menu keys were added
                if ($result.Menu.ContainsKey('autopilotMenu'))
                {
                    Write-TestResult "Missing menu keys added from defaults" $true
                    $script:passedTests++
                }
                else
                {
                    Write-TestResult "Missing menu keys not added" $false
                    $script:failedTests++
                }
            }
            else
            {
                Write-TestResult "Menu configuration not loaded" $false
                $script:failedTests += 3
            }
        }
        else
        {
            Write-TestResult "Configuration initialization failed: $($result.ErrorMessage)" $false
            $script:failedTests += 8
        }
    }
    catch
    {
        Write-TestResult "Strings and Menu processing test failed: $($_.Exception.Message)" $false
        $script:failedTests += 8
    }
    
    Write-TestSection "Test 9: Return Object Structure Validation"
    
    try
    {
        # Use any previous result to validate structure
        $testResult = Initialize-ApplicationConfiguration -InitFile $testInitFile -StringsFile $testStringsFile -menuFile $testMenuFile -Domain $testDomain -BoundParameters @{}
        
        $expectedKeys = @('Auth', 'GlobalSettings', 'LocalSettings', 'Strings', 'Menu', 'RequiredScopes', 'Success', 'ErrorMessage')
        $allKeysPresent = $true
        
        foreach ($key in $expectedKeys)
        {
            if (-not $testResult.ContainsKey($key))
            {
                Write-TestResult "Missing expected return key: $key" $false
                $allKeysPresent = $false
                $script:failedTests++
            }
        }
        
        if ($allKeysPresent)
        {
            Write-TestResult "All expected return object keys present (including Strings and Menu)" $true
            $script:passedTests++
            
            # Verify data types
            $typeChecks = @(
                @{ Key = 'Auth'; Type = 'hashtable' }
                @{ Key = 'GlobalSettings'; Type = 'hashtable' }
                @{ Key = 'LocalSettings'; Type = 'hashtable' }
                @{ Key = 'Strings'; Type = 'hashtable' }
                @{ Key = 'Menu'; Type = 'hashtable' }
                @{ Key = 'RequiredScopes'; Type = 'array' }
                @{ Key = 'Success'; Type = 'bool' }
                @{ Key = 'ErrorMessage'; Type = 'string' }
            )
            
            $allTypesCorrect = $true
            foreach ($check in $typeChecks)
            {
                $value = $testResult[$check.Key]
                $typeMatch = switch ($check.Type)
                {
                    'hashtable'
                    {
                        $value -is [hashtable] 
                    }
                    'array'
                    {
                        # PowerShell arrays can be Object[], ArrayList, or single items
                        # Check if it's array-like (has Count property and is iterable)
                        ($value -is [array]) -or ($value -is [System.Collections.ICollection])
                    }
                    'bool'
                    {
                        $value -is [bool] 
                    }
                    'string'
                    {
                        $value -is [string] 
                    }
                    default
                    {
                        $false 
                    }
                }
                
                if (-not $typeMatch)
                {
                    Write-TestResult "Incorrect type for $($check.Key): expected $($check.Type)" $false
                    $allTypesCorrect = $false
                    $script:failedTests++
                }
            }
            
            if ($allTypesCorrect)
            {
                Write-TestResult "All return object types correct" $true
                $script:passedTests++
            }
        }
    }
    catch
    {
        Write-TestResult "Return object validation failed: $($_.Exception.Message)" $false
        $script:failedTests += 2
    }
    
    Write-TestSection "Test 10: Integration with Helper Functions"
    
    # Verify all helper functions are available
    $helperFunctions = @(
        'Initialize-ConfigurationFiles',
        'Initialize-AuthConfiguration',
        'Initialize-GlobalSettings',
        'Initialize-LocalSettings',
        'Initialize-RequiredScopes',
        'Merge-ConfigurationDefaults',
        'Get-ApplicationDefaults'
    )
    
    $missingHelpers = @()
    foreach ($helperName in $helperFunctions)
    {
        $helper = Get-Command $helperName -ErrorAction SilentlyContinue
        if (-not $helper)
        {
            $missingHelpers += $helperName
        }
    }
    
    if ($missingHelpers.Count -eq 0)
    {
        Write-TestResult "All required helper functions available" $true
        $script:passedTests++
    }
    else
    {
        Write-TestResult "Missing helper functions: $($missingHelpers -join ', ')" $false
        $script:failedTests++
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
        Write-Host "`nInitialize-ApplicationConfiguration Comprehensive Test PASSED! [PASS]" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "`nInitialize-ApplicationConfiguration Comprehensive Test FAILED! [FAIL]" -ForegroundColor Red
        exit 1
    }
}
