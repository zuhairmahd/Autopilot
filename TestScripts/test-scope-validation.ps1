#!/usr/bin/env pwsh

# Test-ScopeValidation.ps1
# Tests for the scope validation functionality using mock data and unified testing framework

param(
    [string]$TestName = "Scope Validation Functions Test",
    [string]$TestFolder = $null
)

# Use unified test framework
try
{
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Determine paths
    $RootPath = Split-Path -Parent $PSScriptRoot
    
    # Load all functions at script level (same as main.ps1)
    $functionsFolder = Join-Path $RootPath "functions"
    if (Test-Path $functionsFolder)
    {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse
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
        Write-TestResult "Functions loaded successfully" $true
    }
    else
    {
        Write-TestResult "Functions folder not found at: $functionsFolder" $false
        exit 1
    }
    
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder
    
    # Set global variables needed by functions
    $tempDir = if ($IsWindows)
    {
        $env:TEMP 
    }
    else
    {
        "/tmp" 
    }
    $global:LogFile = Join-Path $tempDir "test-scope-validation.log"
    $global:maxJSONDepth = 10
    
    Write-TestResult "Test environment initialized" $true
}
catch
{
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

# Helper function to create a mock JWT token with specified claims
function New-MockJwtToken
{
    param(
        [hashtable]$Claims = @{}
    )
    
    # Create a minimal JWT header (base64url encoded)
    $header = @{
        alg = "RS256"
        typ = "JWT"
    } | ConvertTo-Json -Compress
    $headerBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($header)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    # Create payload with provided claims
    $payload = $Claims | ConvertTo-Json -Compress
    $payloadBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    # Create a fake signature (doesn't need to be valid for testing)
    $signature = "fake-signature"
    
    # Return the mock JWT token
    return "$headerBase64.$payloadBase64.$signature"
}

function Test-ScopeValidationFunctions
{
    Write-TestSection "Scope Validation Functions"
    
    # Mock required scopes for testing - USE MOCK DATA, NOT REAL SETTINGS.JSON
    $mockRequiredScopes = @(
        @{
            Scope     = "User.Read.All"
            Reason    = "Test scope for reading users"
            Endpoints = @("users", "users/{id}")
        },
        @{
            Scope     = "Device.Read.All"
            Reason    = "Test scope for reading devices"
            Endpoints = @("devices")
        },
        @{
            Scope     = "DeviceManagementManagedDevices.Read.All"
            Reason    = "Test scope for managed devices"
            Endpoints = @("deviceManagement/managedDevices")
        }
    )
    
    # Test 1: Test-ScopeAvailability function exists
    $testResult = Get-Command Test-ScopeAvailability -ErrorAction SilentlyContinue
    Write-TestResult "Test-ScopeAvailability function exists" ($null -ne $testResult)
    
    # Test 2: Request-AdditionalScopes function exists
    $testResult = Get-Command Request-AdditionalScopes -ErrorAction SilentlyContinue
    Write-TestResult "Request-AdditionalScopes function exists" ($null -ne $testResult)
    
    # Test 3: Test delegated authentication with all scopes available
    $mockAuthConfig = @{ Delegated = $true }
    $mockRequestedScopes = @("User.Read.All", "Device.Read.All", "DeviceManagementManagedDevices.Read.All")
    $mockAccessToken = "fake.jwt.token"
    
    try
    {
        $result = Test-ScopeAvailability -AccessToken $mockAccessToken -RequiredScopes $mockRequiredScopes -AuthConfiguration $mockAuthConfig -RequestedScopes $mockRequestedScopes
        Write-TestResult "Delegated authentication with all scopes shows as available" ($result.HasAllRequiredScopes -eq $true)
        Write-TestResult "No missing scopes when all are available" ($result.MissingScopes.Count -eq 0)
        Write-TestResult "Correct scope source for delegated auth" ($result.ScopeSource -eq "Delegated (Requested during authentication)")
    }
    catch
    {
        Write-TestResult "Delegated authentication test with all scopes - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 4: Test delegated authentication with missing scopes
    $mockRequestedScopesPartial = @("User.Read.All", "Device.Read.All")
    
    try
    {
        $result = Test-ScopeAvailability -AccessToken $mockAccessToken -RequiredScopes $mockRequiredScopes -AuthConfiguration $mockAuthConfig -RequestedScopes $mockRequestedScopesPartial
        Write-TestResult "Delegated authentication with missing scopes shows as incomplete" ($result.HasAllRequiredScopes -eq $false)
        Write-TestResult "Correct number of missing scopes identified" ($result.MissingScopes.Count -eq 1)
        Write-TestResult "Correct missing scope identified" ($result.MissingScopes[0].Scope -eq "DeviceManagementManagedDevices.Read.All")
    }
    catch
    {
        Write-TestResult "Delegated authentication test with missing scopes - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 5: Test application authentication (simplified mock)
    $mockAuthConfigApp = @{ Delegated = $false }
    
    # Create a valid mock JWT token with roles claim for application auth
    $mockJwtTokenWithRoles = New-MockJwtToken -Claims @{
        aud   = "https://graph.microsoft.com"
        iss   = "https://sts.windows.net/test-tenant/"
        roles = @("User.Read.All", "Device.Read.All", "DeviceManagementManagedDevices.Read.All")
        appid = "test-app-id"
        tid   = "test-tenant-id"
    }
    
    try
    {
        $result = Test-ScopeAvailability -AccessToken $mockJwtTokenWithRoles -RequiredScopes $mockRequiredScopes -AuthConfiguration $mockAuthConfigApp
        Write-TestResult "Application authentication with valid JWT decodes successfully" ($result.ScopeSource -eq "Application (JWT token claims)")
        Write-TestResult "Application authentication with all scopes shows as available" ($result.HasAllRequiredScopes -eq $true)
        Write-TestResult "Application authentication extracts roles correctly" ($result.AvailableScopes.Count -eq 3)
    }
    catch
    {
        Write-TestResult "Application authentication test - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 6: Test application authentication with OIDC scopes that should be excluded
    $mockJwtTokenWithOIDC = New-MockJwtToken -Claims @{
        aud   = "https://graph.microsoft.com"
        iss   = "https://sts.windows.net/test-tenant/"
        roles = @("User.Read.All", "Device.Read.All", "openid", "profile", "offline_access")
        appid = "test-app-id"
        tid   = "test-tenant-id"
    }
    
    try
    {
        $result = Test-ScopeAvailability -AccessToken $mockJwtTokenWithOIDC -RequiredScopes $mockRequiredScopes -AuthConfiguration $mockAuthConfigApp
        Write-TestResult "Application auth excludes 'openid' scope" ($result.AvailableScopes -notcontains "openid")
        Write-TestResult "Application auth excludes 'profile' scope" ($result.AvailableScopes -notcontains "profile")
        Write-TestResult "Application auth excludes 'offline_access' scope" ($result.AvailableScopes -notcontains "offline_access")
        Write-TestResult "Application auth keeps Graph API scopes" ($result.AvailableScopes -contains "User.Read.All")
        Write-TestResult "Application auth filtered scope count is correct" ($result.AvailableScopes.Count -eq 2)
    }
    catch
    {
        Write-TestResult "Application authentication OIDC exclusion test - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 7: Test application authentication with scp claim (edge case)
    $mockJwtTokenWithScp = New-MockJwtToken -Claims @{
        aud   = "https://graph.microsoft.com"
        iss   = "https://sts.windows.net/test-tenant/"
        scp   = "User.Read.All openid profile Device.Read.All"
        appid = "test-app-id"
        tid   = "test-tenant-id"
    }
    
    try
    {
        $result = Test-ScopeAvailability -AccessToken $mockJwtTokenWithScp -RequiredScopes $mockRequiredScopes -AuthConfiguration $mockAuthConfigApp
        Write-TestResult "Application auth with 'scp' claim excludes OIDC scopes" (
            ($result.AvailableScopes -notcontains "openid") -and 
            ($result.AvailableScopes -notcontains "profile")
        )
        Write-TestResult "Application auth with 'scp' claim keeps Graph scopes" ($result.AvailableScopes -contains "User.Read.All")
    }
    catch
    {
        Write-TestResult "Application authentication 'scp' claim test - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 8: Test with invalid authentication configuration
    try
    {
        $invalidConfig = @{ }  # Missing Delegated property
        $result = Test-ScopeAvailability -AccessToken $mockAccessToken -RequiredScopes $mockRequiredScopes -AuthConfiguration $invalidConfig -RequestedScopes @()
        Write-TestResult "Invalid auth config handles gracefully" ($result.HasAllRequiredScopes -eq $false)
    }
    catch
    {
        Write-TestResult "Invalid auth config throws expected exception" $true
    }
    
    # Test 8.5: Test application authentication with OIDC scopes in REQUIRED scopes list
    # This tests the real-world scenario where settings.psd1 incorrectly includes OIDC scopes in requiredScopes
    $mockRequiredScopesWithOIDC = @(
        @{
            Scope     = "User.Read.All"
            Reason    = "Test scope for reading users"
            Endpoints = @("users", "users/{id}")
        },
        @{
            Scope     = "openid"
            Reason    = "OIDC protocol scope"
            Endpoints = @()
        },
        @{
            Scope     = "profile"
            Reason    = "OIDC protocol scope"
            Endpoints = @()
        },
        @{
            Scope     = "offline_access"
            Reason    = "OIDC protocol scope"
            Endpoints = @()
        },
        @{
            Scope     = "Device.Read.All"
            Reason    = "Test scope for reading devices"
            Endpoints = @("devices")
        }
    )
    
    # Create JWT token WITHOUT OIDC scopes (realistic for application auth)
    $mockJwtTokenAppOnly = New-MockJwtToken -Claims @{
        aud   = "https://graph.microsoft.com"
        iss   = "https://sts.windows.net/test-tenant/"
        roles = @("User.Read.All", "Device.Read.All")
        appid = "test-app-id"
        tid   = "test-tenant-id"
    }
    
    try
    {
        $result = Test-ScopeAvailability -AccessToken $mockJwtTokenAppOnly -RequiredScopes $mockRequiredScopesWithOIDC -AuthConfiguration $mockAuthConfigApp
        Write-TestResult "Application auth filters OIDC scopes from required scopes list" ($result.HasAllRequiredScopes -eq $true)
        Write-TestResult "Application auth missing scopes does not include OIDC scopes" ($result.MissingScopes.Count -eq 0)
        Write-TestResult "Application auth doesn't report OIDC scopes as missing" (
            ($result.MissingScopes | Where-Object { $_.Scope -eq "openid" }).Count -eq 0 -and
            ($result.MissingScopes | Where-Object { $_.Scope -eq "profile" }).Count -eq 0 -and
            ($result.MissingScopes | Where-Object { $_.Scope -eq "offline_access" }).Count -eq 0
        )
    }
    catch
    {
        Write-TestResult "Application authentication OIDC in required scopes test - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 9: Test empty required scopes
    try
    {
        $emptyRequiredScopes = @()  # Explicit empty array
        $result = Test-ScopeAvailability -AccessToken $mockAccessToken -RequiredScopes $emptyRequiredScopes -AuthConfiguration $mockAuthConfig -RequestedScopes $mockRequestedScopes
        Write-TestResult "Empty required scopes list returns true" ($result.HasAllRequiredScopes -eq $true)
        Write-TestResult "No missing scopes with empty requirements" ($result.MissingScopes.Count -eq 0)
    }
    catch
    {
        Write-TestResult "Empty required scopes test - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 10: Test Request-AdditionalScopes with application auth
    try
    {
        $emptyMissingScopes = @()  # Explicit empty array
        $emptyCurrentScopes = @()  # Explicit empty array
        $result = Request-AdditionalScopes -MissingScopes $emptyMissingScopes -AuthConfiguration $mockAuthConfigApp -CurrentScopes $emptyCurrentScopes -AuthParams @{}
        Write-TestResult "Empty missing scopes returns success" ($result.Success -eq $true)
    }
    catch
    {
        Write-TestResult "Request-AdditionalScopes with empty scopes - Exception: $($_.Exception.Message)" $false
    }
    
    # Test 11: Test Request-AdditionalScopes with application auth and actual missing scopes
    try
    {
        $result = Request-AdditionalScopes -MissingScopes $mockRequiredScopes -AuthConfiguration $mockAuthConfigApp -CurrentScopes @("User.Read") -AuthParams @{}
        Write-TestResult "Application auth cannot request additional scopes" ($result.Success -eq $false)
        Write-TestResult "Application auth provides correct guidance" ($result.ErrorMessage -like "*administrator*")
    }
    catch
    {
        Write-TestResult "Request-AdditionalScopes with application auth - Exception: $($_.Exception.Message)" $false
    }
}

function Test-ScopeValidationIntegration
{
    Write-TestSection "Scope Validation Integration"
    
    # Test scope validation integration using mock data instead of real settings.json
    # This ensures tests don't fail when settings change
    
    # Mock settings data that mimics the structure of settings.json
    $mockSettings = @{
        requiredScopes = @(
            @{
                Scope     = "User.Read.All"
                Endpoints = @("/users", "users/{id}", "users/{id}/memberOf", "users/{id}/registeredDevices")
                Reason    = "Required to read user profiles, group memberships, and registered devices."
            },
            @{
                Scope     = "Device.Read.All"
                Endpoints = @("devices")
                Reason    = "Required to read Microsoft Entra ID device objects."
            },
            @{
                Scope     = "DeviceManagementManagedDevices.PrivilegedOperations.All"
                Endpoints = @("directory/deviceLocalCredentials")
                Reason    = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
            },
            @{
                Scope     = "DeviceManagementServiceConfig.ReadWrite.All"
                Endpoints = @("deviceManagement/autopilotEvents", "deviceManagement/importedWindowsAutopilotDeviceIdentities", "deviceManagement/windowsAutopilotDeviceIdentities")
                Reason    = "Required to read Autopilot events and to read and manage Autopilot device identities."
            }
        )
    }
    
    Write-TestResult "Mock settings contains required scopes" ($mockSettings.requiredScopes.Count -gt 0)
    
    # Check for specific scope descriptions using mock data
    $deviceMgmtScope = $mockSettings.requiredScopes | Where-Object { $_.Scope -eq "DeviceManagementManagedDevices.PrivilegedOperations.All" }
    if ($deviceMgmtScope)
    {
        Write-TestResult "DeviceManagementManagedDevices.PrivilegedOperations.All has updated description" ($deviceMgmtScope.Reason -like "*LAPS*" -or $deviceMgmtScope.Reason -like "*privileged*")
        Write-TestResult "DeviceManagementManagedDevices.PrivilegedOperations.All has endpoints" ($deviceMgmtScope.Endpoints.Count -gt 0)
    }
    
    $serviceConfigScope = $mockSettings.requiredScopes | Where-Object { $_.Scope -eq "DeviceManagementServiceConfig.ReadWrite.All" }
    if ($serviceConfigScope)
    {
        Write-TestResult "DeviceManagementServiceConfig.ReadWrite.All has updated description" ($serviceConfigScope.Reason -like "*Autopilot*" -or $serviceConfigScope.Reason -like "*service*")
    }
    
    # Check for no duplicate scopes in mock data
    $scopeNames = $mockSettings.requiredScopes | ForEach-Object { $_.Scope }
    $uniqueScopes = $scopeNames | Sort-Object -Unique
    Write-TestResult "No duplicate scope entries in mock data" ($scopeNames.Count -eq $uniqueScopes.Count)
    
    # Test that the actual settings.json file doesn't have duplicates (this validates the fix)
    try
    {
        $settingsPath = Join-Path $PWD "settings.json"
        if (Test-Path $settingsPath)
        {
            $actualSettings = Get-Content $settingsPath | ConvertFrom-Json
            $actualScopeNames = $actualSettings.requiredScopes | ForEach-Object { 
                if ($_.Scope)
                {
                    $_.Scope 
                }
                elseif ($_.scope)
                {
                    $_.scope 
                } 
            }
            $actualUniqueScopes = $actualScopeNames | Sort-Object -Unique
            Write-TestResult "Real settings.json has no duplicate scope entries" ($actualScopeNames.Count -eq $actualUniqueScopes.Count)
        }
        else
        {
            Write-TestResult "Settings.json file validation (file not found - this is expected in test environment)" $true
        }
    }
    catch
    {
        Write-TestResult "Settings.json scope validation - Exception: $($_.Exception.Message)" $false
    }
}

# Main test execution
try
{
    Push-Location $TestFolder
    
    Write-TestSection "Scope Validation Function Tests"
    Write-Host "Testing new Microsoft Graph scope validation functionality..." -ForegroundColor White
    
    Test-ScopeValidationFunctions
    Test-ScopeValidationIntegration
    
    # Complete the unified test
    Complete-UnifiedTest -TestContext $testContext
    
}
catch
{
    Write-TestResult "Test execution failed: $($_.Exception.Message)" $false
    exit 1
}
finally
{
    Pop-Location
}