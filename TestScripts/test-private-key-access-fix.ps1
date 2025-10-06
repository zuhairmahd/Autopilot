# Test for Private Key Access Fix in Get-ClientCredentialsToken
# This test verifies the fix for the null-valued expression error when accessing certificate.PrivateKey

# Setup test environment
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot

# Import required functions
. "$projectRoot\functions\graphFunctions\Get-ClientCredentialsToken.ps1"

# Set up global LogFile variable (required by Write-Log)
$global:LogFile = Join-Path $scriptRoot "test-private-key-access.log"

# Mock helper functions
function Get-TokenFromResponse
{
    param($tokenResponse, $domain) return @{ access_token = $tokenResponse.access_token } 
}
function Save-TokenToCache
{
    param($cachedToken, $cacheType, $cacheTokenFile, $cacheFolder) 
}
function Format-TokenOutput
{
    param($token, $secureString) return $token 
}
function Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel) 
}

Write-Host "`nTesting private key access fix..." -ForegroundColor Cyan

# Test 1: Certificate with null PrivateKey property (certificate-only mode)
Write-Host "`nTest 1: Certificate with null PrivateKey (certificate-only mode)" -ForegroundColor Yellow

# Mock Get-ChildItem to return a certificate with null PrivateKey
function Get-ChildItem
{
    param([string[]]$Path, [switch]$Recurse)
    
    # Create a mock certificate object with null PrivateKey
    $mockCert = [PSCustomObject]@{
        Thumbprint    = "1BBACACD50A9B83E93A4305257A983367C8812D4"
        Subject       = "CN=Test Certificate"
        NotAfter      = (Get-Date).AddYears(1)
        HasPrivateKey = $true  # Property says it has a key
        PrivateKey    = $null     # But PrivateKey accessor returns null
    }
    
    # Add the GetCertHash method
    $mockCert | Add-Member -MemberType ScriptMethod -Name GetCertHash -Value {
        return [byte[]](1..20)
    } -Force
    
    return $mockCert
}

# Mock Invoke-RestMethod (should not be called in this scenario)
function Invoke-RestMethod
{
    param($Method, $Uri, $ContentType, $Body, $ErrorAction)
    throw "Invoke-RestMethod should not be called when PrivateKey is null"
}

try
{
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant-id" `
        -clientId "test-client-id" `
        -certificateThumbprint "1BBACACD50A9B83E93A4305257A983367C8812D4" `
        -ErrorAction SilentlyContinue
    
    if ($null -eq $result)
    {
        Write-Host "✓ PASSED - Function returned null when PrivateKey is inaccessible (certificate-only mode)" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ FAILED - Expected null result but got: $result" -ForegroundColor Red
    }
}
catch
{
    Write-Host "✗ FAILED - Unexpected exception: $_" -ForegroundColor Red
}

# Test 2: Certificate with null PrivateKey property (fallback mode with client secret)
Write-Host "`nTest 2: Certificate with null PrivateKey (fallback to client secret)" -ForegroundColor Yellow

# Mock Invoke-RestMethod to succeed for client secret authentication
function Invoke-RestMethod
{
    param($Method, $Uri, $ContentType, $Body, $ErrorAction)
    
    # Verify we're using client secret (not certificate)
    if ($Body.client_secret)
    {
        return @{
            access_token = "mock-token-from-client-secret"
            expires_in   = 3600
        }
    }
    else
    {
        throw "Expected client_secret authentication after certificate failure"
    }
}

try
{
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant-id" `
        -clientId "test-client-id" `
        -certificateThumbprint "1BBACACD50A9B83E93A4305257A983367C8812D4" `
        -clientSecret "test-client-secret" `
        -ErrorAction SilentlyContinue
    
    if ($result -eq "mock-token-from-client-secret")
    {
        Write-Host "✓ PASSED - Function fell back to client secret when PrivateKey is inaccessible" -ForegroundColor Green
        Write-Host "  Result: $result" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ FAILED - Expected token from client secret but got: $result" -ForegroundColor Red
    }
}
catch
{
    Write-Host "✗ FAILED - Unexpected exception: $_" -ForegroundColor Red
}

# Test 3: Certificate with accessible PrivateKey (normal operation)
Write-Host "`nTest 3: Certificate with accessible PrivateKey (normal operation)" -ForegroundColor Yellow

# Mock Get-ChildItem to return a certificate with working PrivateKey
function Get-ChildItem
{
    param([string[]]$Path, [switch]$Recurse)
    
    # Create a mock RSA object
    $mockRsa = [PSCustomObject]@{
        KeySize = 2048
    }
    
    # Add SignData method
    $mockRsa | Add-Member -MemberType ScriptMethod -Name SignData -Value {
        param($data, $hashAlgorithm, $padding)
        return [byte[]](1..256)  # Return a mock signature
    } -Force
    
    # Create a mock certificate object with working PrivateKey
    $mockCert = [PSCustomObject]@{
        Thumbprint    = "1BBACACD50A9B83E93A4305257A983367C8812D4"
        Subject       = "CN=Test Certificate"
        NotAfter      = (Get-Date).AddYears(1)
        HasPrivateKey = $true
        PrivateKey    = $mockRsa
    }
    
    # Add the GetCertHash method
    $mockCert | Add-Member -MemberType ScriptMethod -Name GetCertHash -Value {
        return [byte[]](1..20)
    } -Force
    
    return $mockCert
}

# Mock Invoke-RestMethod to succeed for certificate authentication
function Invoke-RestMethod
{
    param($Method, $Uri, $ContentType, $Body, $ErrorAction)
    
    # Verify we're using certificate authentication
    if ($Body.client_assertion)
    {
        return @{
            access_token = "mock-token-from-certificate"
            expires_in   = 3600
        }
    }
    else
    {
        throw "Expected certificate authentication (client_assertion)"
    }
}

try
{
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant-id" `
        -clientId "test-client-id" `
        -certificateThumbprint "1BBACACD50A9B83E93A4305257A983367C8812D4" `
        -ErrorAction SilentlyContinue
    
    if ($result -eq "mock-token-from-certificate")
    {
        Write-Host "✓ PASSED - Function successfully authenticated with certificate when PrivateKey is accessible" -ForegroundColor Green
        Write-Host "  Result: $result" -ForegroundColor Gray
    }
    else
    {
        Write-Host "✗ FAILED - Expected token from certificate but got: $result" -ForegroundColor Red
    }
}
catch
{
    Write-Host "✗ FAILED - Unexpected exception: $_" -ForegroundColor Red
}

Write-Host "`n✓ All private key access tests completed!" -ForegroundColor Green
