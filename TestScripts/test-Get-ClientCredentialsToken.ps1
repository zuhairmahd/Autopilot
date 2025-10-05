# Test-Get-ClientCredentialsToken.ps1
# Comprehensive tests for Get-ClientCredentialsToken certificate authentication

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

# Set global $LogFile variable as expected by Get-ClientCredentialsToken
$global:LogFile = "$PSScriptRoot\test-get-clientcredentialstoken.log"

# Import required functions
$rootPath = Split-Path -Parent $PSScriptRoot
. "$rootPath\functions\graphFunctions\Get-ClientCredentialsToken.ps1"

# Mock helper functions that Get-ClientCredentialsToken depends on
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
    # No-op for tests
}

function Format-TokenOutput
{ 
    param($token, $secureString)
    if ($secureString)
    {
        return ($token | ConvertTo-SecureString -AsPlainText -Force)
    }
    return $token
}

function Write-Log
{
    param($LogFile, $Module, $Message, $LogLevel = "Info")
    # No-op for tests
}

# Test counters
$testsPassed = 0
$testsFailed = 0
$testsTotal = 0

function Test-Assertion
{
    param(
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    $script:testsTotal++
    Write-Host "`n[Test $script:testsTotal] $TestName" -ForegroundColor Cyan
    
    try
    {
        & $TestBlock
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        $script:testsPassed++
    }
    catch
    {
        Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
        Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        $script:testsFailed++
    }
}

# ============================================================================
# Test 1: Parameter Validation - Missing Both Secret and Certificate
# ============================================================================
Test-Assertion "Parameter validation should fail when neither secret nor certificate provided" {
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result when neither secret nor certificate provided, got: $result"
    }
}

# ============================================================================
# Test 2: Client Secret Authentication - Success
# ============================================================================
Test-Assertion "Client secret authentication should succeed with valid credentials" {
    # Mock Invoke-RestMethod for successful token response
    function Invoke-RestMethod
    {
        param($Method, $Uri, $ContentType, $Body, $ErrorAction)
        
        # Verify request structure
        if ($Body.grant_type -ne "client_credentials")
        {
            throw "Invalid grant_type: $($Body.grant_type)"
        }
        if ($Body.client_secret -ne "test-secret")
        {
            throw "Invalid client_secret"
        }
        if ($Body.client_id -ne "test-client")
        {
            throw "Invalid client_id"
        }
        
        return @{
            access_token = "mock-access-token-secret"
            expires_in   = 3600
            token_type   = "Bearer"
        }
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -clientSecret "test-secret" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder ""
    
    if ($result -ne "mock-access-token-secret")
    {
        throw "Expected access token 'mock-access-token-secret', got: $result"
    }
}

# ============================================================================
# Test 3: Client Secret Authentication - Failure
# ============================================================================
Test-Assertion "Client secret authentication should handle token endpoint errors gracefully" {
    # Mock Invoke-RestMethod to throw error
    function Invoke-RestMethod
    {
        param($Method, $Uri, $ContentType, $Body, $ErrorAction)
        
        $response = New-Object System.Net.Http.HttpResponseMessage
        $response.StatusCode = [System.Net.HttpStatusCode]::Unauthorized
        
        $errorJson = @{
            error             = "invalid_client"
            error_description = "Client credentials are invalid"
        } | ConvertTo-Json
        
        $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($errorJson))
        $response.Content = New-Object System.Net.Http.StreamContent($stream)
        
        $exception = New-Object System.Net.Http.HttpRequestException("Unauthorized")
        $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response -Force
        
        throw $exception
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -clientSecret "wrong-secret" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result on authentication failure, got: $result"
    }
}

# ============================================================================
# Test 4: Certificate Authentication - Certificate Not Found
# ============================================================================
Test-Assertion "Certificate authentication should fail gracefully when certificate not found" {
    # Mock Get-ChildItem to return no certificates
    function Get-ChildItem
    {
        param($Path, $Recurse)
        return @()
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -certificateThumbprint "ABCDEF1234567890" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -secureString $false `
        -LogFile "test.log" `
        -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result when certificate not found, got: $result"
    }
}

# ============================================================================
# Test 5: Certificate Authentication - Certificate Has No Private Key
# ============================================================================
Test-Assertion "Certificate authentication should fail when certificate has no private key" {
    # Mock Get-ChildItem to return certificate without private key
    function Get-ChildItem
    {
        param($Path, $Recurse)
        
        $mockCert = New-Object PSObject -Property @{
            Thumbprint    = "ABCDEF1234567890"
            Subject       = "CN=Test Certificate"
            NotAfter      = (Get-Date).AddYears(1)
            HasPrivateKey = $false
        }
        
        return @($mockCert)
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -certificateThumbprint "ABCDEF1234567890" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result when certificate has no private key, got: $result"
    }
}

# ============================================================================
# Test 6: Certificate Authentication - Certificate Expired
# ============================================================================
Test-Assertion "Certificate authentication should fail when certificate has expired" {
    # Mock Get-ChildItem to return expired certificate
    function Get-ChildItem
    {
        param($Path, $Recurse)
        
        $mockCert = New-Object PSObject -Property @{
            Thumbprint    = "ABCDEF1234567890"
            Subject       = "CN=Test Certificate"
            NotAfter      = (Get-Date).AddYears(-1)  # Expired
            HasPrivateKey = $true
        }
        
        return @($mockCert)
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -certificateThumbprint "ABCDEF1234567890" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result when certificate expired, got: $result"
    }
}

# ============================================================================
# Test 7: Certificate Authentication - Success
# ============================================================================
Test-Assertion "Certificate authentication should succeed with valid certificate" {
    # Create a self-signed test certificate in memory
    $certParams = @{
        Subject           = "CN=Test Certificate"
        CertStoreLocation = "Cert:\CurrentUser\My"
        KeyExportPolicy   = "Exportable"
        KeySpec           = "Signature"
        KeyLength         = 2048
        KeyAlgorithm      = "RSA"
        HashAlgorithm     = "SHA256"
        NotAfter          = (Get-Date).AddYears(1)
        Type              = "Custom"
    }
    
    try
    {
        $testCert = New-SelfSignedCertificate @certParams
        $thumbprint = $testCert.Thumbprint
        
        # Mock Invoke-RestMethod for successful certificate auth
        function Invoke-RestMethod
        {
            param($Method, $Uri, $ContentType, $Body, $ErrorAction)
            
            # Verify certificate authentication parameters
            if ($Body.grant_type -ne "client_credentials")
            {
                throw "Invalid grant_type: $($Body.grant_type)"
            }
            if (-not $Body.client_assertion)
            {
                throw "Missing client_assertion"
            }
            if ($Body.client_assertion_type -ne "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
            {
                throw "Invalid client_assertion_type"
            }
            
            return @{
                access_token = "mock-access-token-certificate"
                expires_in   = 3600
                token_type   = "Bearer"
            }
        }
        
        $result = Get-ClientCredentialsToken `
            -tenantId "test-tenant" `
            -clientId "test-client" `
            -certificateThumbprint $thumbprint `
            -domain "test.onmicrosoft.com" `
            -cacheType "memory" `
            -cacheTokenFile "" `
            -cacheFolder ""
        
        if ($result -ne "mock-access-token-certificate")
        {
            throw "Expected access token 'mock-access-token-certificate', got: $result"
        }
    }
    finally
    {
        # Clean up test certificate
        if ($testCert)
        {
            Remove-Item -Path "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# Test 8: Fallback - Certificate Auth Fails, Secret Auth Succeeds
# ============================================================================
Test-Assertion "Should fall back to client secret when certificate auth fails (both provided)" {
    # Create a test certificate
    $certParams = @{
        Subject           = "CN=Test Certificate"
        CertStoreLocation = "Cert:\CurrentUser\My"
        KeyExportPolicy   = "Exportable"
        KeySpec           = "Signature"
        KeyLength         = 2048
        KeyAlgorithm      = "RSA"
        HashAlgorithm     = "SHA256"
        NotAfter          = (Get-Date).AddYears(1)
        Type              = "Custom"
    }
    
    try
    {
        $testCert = New-SelfSignedCertificate @certParams
        $thumbprint = $testCert.Thumbprint
        
        $script:invokeCount = 0
        
        # Mock Invoke-RestMethod to fail certificate auth, succeed on secret auth
        function Invoke-RestMethod
        {
            param($Method, $Uri, $ContentType, $Body, $ErrorAction)
            
            $script:invokeCount++
            
            # First call (certificate auth) should fail
            if ($Body.client_assertion)
            {
                throw "Certificate authentication failed (simulated)"
            }
            
            # Second call (client secret auth) should succeed
            if ($Body.client_secret)
            {
                return @{
                    access_token = "mock-access-token-fallback"
                    expires_in   = 3600
                    token_type   = "Bearer"
                }
            }
            
            throw "Unexpected authentication method"
        }
        
        # Suppress warnings for this test
        $WarningPreference = 'SilentlyContinue'
        
        $result = Get-ClientCredentialsToken `
            -tenantId "test-tenant" `
            -clientId "test-client" `
            -certificateThumbprint $thumbprint `
            -clientSecret "fallback-secret" `
            -domain "test.onmicrosoft.com" `
            -cacheType "memory" `
            -cacheTokenFile "" `
            -cacheFolder "" `
            -ErrorAction SilentlyContinue
        
        if ($result -ne "mock-access-token-fallback")
        {
            throw "Expected access token 'mock-access-token-fallback', got: $result"
        }
        
        if ($script:invokeCount -ne 2)
        {
            throw "Expected 2 authentication attempts (cert then secret), got: $script:invokeCount"
        }
    }
    finally
    {
        # Clean up
        if ($testCert)
        {
            Remove-Item -Path "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -ErrorAction SilentlyContinue
        }
        $WarningPreference = 'Continue'
    }
}

# ============================================================================
# Test 9: Certificate-Only Mode - No Fallback
# ============================================================================
Test-Assertion "Certificate-only mode should not fall back when certificate auth fails" {
    # Mock Get-ChildItem to return certificate without private key
    function Get-ChildItem
    {
        param($Path, $Recurse)
        
        $mockCert = New-Object PSObject -Property @{
            Thumbprint    = "ABCDEF1234567890"
            Subject       = "CN=Test Certificate"
            NotAfter      = (Get-Date).AddYears(1)
            HasPrivateKey = $false
        }
        
        return @($mockCert)
    }
    
    # Mock Invoke-RestMethod - should NOT be called
    $script:invokeCount = 0
    function Invoke-RestMethod
    {
        param($Method, $Uri, $ContentType, $Body, $ErrorAction)
        $script:invokeCount++
        throw "Should not attempt token request with invalid certificate"
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -certificateThumbprint "ABCDEF1234567890" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -secureString $false `
        -LogFile "test.log" `
        -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result when certificate-only auth fails, got: $result"
    }
    
    if ($script:invokeCount -ne 0)
    {
        throw "Expected 0 token requests with invalid cert, got: $script:invokeCount"
    }
}

# ============================================================================
# Test 10: SecureString Output
# ============================================================================
Test-Assertion "Should return SecureString when secureString parameter is true" {
    # Mock Invoke-RestMethod
    function Invoke-RestMethod
    {
        param($Method, $Uri, $ContentType, $Body, $ErrorAction)
        return @{
            access_token = "mock-secure-token"
            expires_in   = 3600
            token_type   = "Bearer"
        }
    }
    
    $result = Get-ClientCredentialsToken `
        -tenantId "test-tenant" `
        -clientId "test-client" `
        -clientSecret "test-secret" `
        -domain "test.onmicrosoft.com" `
        -cacheType "memory" `
        -cacheTokenFile "" `
        -cacheFolder "" `
        -secureString
    
    if ($result -isnot [System.Security.SecureString])
    {
        throw "Expected SecureString result, got: $($result.GetType().Name)"
    }
}

# ============================================================================
# Test Results Summary
# ============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host (" Test Results Summary " + "=" * 58) -ForegroundColor Cyan
Write-Host "Total Tests:  $testsTotal"
Write-Host "Passed:       " -NoNewline
Write-Host $testsPassed -ForegroundColor Green
Write-Host "Failed:       " -NoNewline
Write-Host $testsFailed -ForegroundColor $(if ($testsFailed -eq 0)
    {
        "Green" 
    }
    else
    {
        "Red" 
    })
Write-Host "Success Rate: " -NoNewline
$successRate = if ($testsTotal -gt 0)
{
    [math]::Round(($testsPassed / $testsTotal) * 100, 1) 
}
else
{
    0 
}
Write-Host "$successRate%" -ForegroundColor $(if ($successRate -eq 100)
    {
        "Green" 
    }
    elseif ($successRate -ge 70)
    {
        "Yellow" 
    }
    else
    {
        "Red" 
    })
Write-Host ("=" * 80) -ForegroundColor Cyan

if ($testsFailed -gt 0)
{
    exit 1
}
