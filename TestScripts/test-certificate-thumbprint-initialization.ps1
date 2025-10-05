# Test-Certificate-Thumbprint-Initialization.ps1
# Quick test to verify that GetGraphAccessToken handles missing certificate thumbprint correctly

Write-Host "Testing certificate thumbprint initialization fix..." -ForegroundColor Cyan

# Set global $LogFile variable
$global:LogFile = "$PSScriptRoot\test-cert-init.log"

# Import required functions
$rootPath = Split-Path -Parent $PSScriptRoot
. "$rootPath\functions\graphFunctions\GetGraphAccessToken.ps1"
. "$rootPath\functions\graphFunctions\Get-ClientCredentialsToken.ps1"

# Mock helper functions
function Get-DecryptedConfigValue
{ 
    param($PropertyPath)
    
    # Simulate config values - return null for thumbprint to trigger the error scenario
    switch ($PropertyPath)
    {
        "tenantId"
        {
            return "test-tenant-id" 
        }
        "domain"
        {
            return "test.onmicrosoft.com" 
        }
        "appId"
        {
            return "test-client-id" 
        }
        "AppSecret"
        {
            return "test-client-secret" 
        }
        "thumbprint"
        {
            return $null 
        }  # Simulate missing thumbprint
        default
        {
            return $null 
        }
    }
}

function Get-AuthConfigValue
{ 
    param($PropertyPath)
    return $null
}

function Get-TokenFromCache
{
    param($cacheType, $domain, $renewalLeadTime, $clientId, $clientSecret, 
        $tenantId, $scopes, $delegated, $cacheFolder, $cacheTokenFile, 
        $secureString, $configFilePath, $configRefreshToken)
    return $null  # Force new token
}

function Get-TokenFromResponse
{ 
    param($tokenResponse, $domain)
    return @{
        access_token = $tokenResponse.access_token
        expires_in   = $tokenResponse.expires_in
        domain       = $domain
        timestamp    = Get-Date
    }
}

function Save-TokenToCache
{ 
    param($cachedToken, $cacheType, $cacheTokenFile, $cacheFolder)
    # No-op
}

function Format-TokenOutput
{ 
    param($token, $secureString)
    return $token
}

function Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel = "Info")
    # No-op
}

# Mock Invoke-RestMethod for client secret auth
function Invoke-RestMethod
{
    param($Method, $Uri, $ContentType, $Body, $ErrorAction)
    
    if ($Body.client_secret)
    {
        return @{
            access_token = "mock-token-from-secret"
            expires_in   = 3600
            token_type   = "Bearer"
        }
    }
    throw "Unexpected authentication method"
}

Write-Host "`nTest: GetGraphAccessToken with missing certificate thumbprint (should use client secret)" -ForegroundColor Yellow

try
{
    # Use a valid config file path for the test
    $testConfigPath = Join-Path $PSScriptRoot "test-config.psd1"
    $result = GetGraphAccessToken -configFile $testConfigPath -ErrorAction Stop
    
    if ($result -eq "mock-token-from-secret")
    {
        Write-Host "✓ PASSED - Token obtained using client secret when certificate thumbprint is null" -ForegroundColor Green
        Write-Host "  Result: $result" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ FAILED - Expected 'mock-token-from-secret', got: $result" -ForegroundColor Red
        exit 1
    }
}
catch
{
    Write-Host "✗ FAILED - Exception occurred: $_" -ForegroundColor Red
    Write-Host "  Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✓ All tests passed!" -ForegroundColor Green
