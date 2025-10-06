# Test-GetGraphAccessToken-Certificate.ps1
# Integration test for GetGraphAccessToken with certificate authentication support

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

# Set global $LogFile variable
$global:LogFile = "$PSScriptRoot\test-getgraphaccesstoken-certificate.log"

# Import required functions
$rootPath = Split-Path -Parent $PSScriptRoot
. "$rootPath\functions\graphFunctions\GetGraphAccessToken.ps1"
. "$rootPath\functions\graphFunctions\Get-ClientCredentialsToken.ps1"

# Mock helper functions
function Get-DecryptedConfigValue
{ 
    param($PropertyPath)
    
    # Simulate config values based on property path
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
        "certificateThumbprint"
        {
            return "ABCD1234567890EFABCD1234567890EFABCD1234" 
        }
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
# Test 1: Certificate-Only Configuration
# ============================================================================
Test-Assertion "Should use certificate authentication when only certificate thumbprint is in config" {
    # Override Get-DecryptedConfigValue to only return certificate, no secret
    function Get-DecryptedConfigValue
    { 
        param($PropertyPath)
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
                return $null 
            }  # No secret
            "certificateThumbprint"
            {
                return "ABCD1234567890EFABCD1234567890EFABCD1234" 
            }
            default
            {
                return $null 
            }
        }
    }
    
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
        
        # Override Get-DecryptedConfigValue to use our test certificate
        function Get-DecryptedConfigValue
        { 
            param($PropertyPath)
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
                    return $null 
                }  # No secret
                "certificateThumbprint"
                {
                    return $testCert.Thumbprint 
                }
                default
                {
                    return $null 
                }
            }
        }
        
        # Mock Invoke-RestMethod for certificate auth
        function Invoke-RestMethod
        {
            param($Method, $Uri, $ContentType, $Body, $ErrorAction)
            
            if ($Body.client_assertion)
            {
                return @{
                    access_token = "mock-token-cert-only"
                    expires_in   = 3600
                    token_type   = "Bearer"
                }
            }
            throw "Expected certificate authentication"
        }
        
        $result = GetGraphAccessToken -configFile "test-config.psd1"
        
        if ($result -ne "mock-token-cert-only")
        {
            throw "Expected token from certificate auth, got: $result"
        }
    }
    finally
    {
        if ($testCert)
        {
            Remove-Item -Path "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# Test 2: Client Secret Only Configuration
# ============================================================================
Test-Assertion "Should use client secret authentication when only secret is in config" {
    # Override Get-DecryptedConfigValue to only return secret, no certificate
    function Get-DecryptedConfigValue
    { 
        param($PropertyPath)
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
                return "test-secret" 
            }
            "certificateThumbprint"
            {
                return $null 
            }  # No certificate
            default
            {
                return $null 
            }
        }
    }
    
    # Mock Invoke-RestMethod for secret auth
    function Invoke-RestMethod
    {
        param($Method, $Uri, $ContentType, $Body, $ErrorAction)
        
        if ($Body.client_secret -eq "test-secret")
        {
            return @{
                access_token = "mock-token-secret-only"
                expires_in   = 3600
                token_type   = "Bearer"
            }
        }
        throw "Expected client secret authentication"
    }
    
    $result = GetGraphAccessToken -configFile "test-config.psd1"
    
    if ($result -ne "mock-token-secret-only")
    {
        throw "Expected token from secret auth, got: $result"
    }
}

# ============================================================================
# Test 3: Both Certificate and Secret in Config (Certificate Priority)
# ============================================================================
Test-Assertion "Should try certificate first when both certificate and secret are in config" {
    # Create a test certificate
    $certParams = @{
        Subject           = "CN=Test Certificate Both"
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
        
        # Override Get-DecryptedConfigValue to return both
        function Get-DecryptedConfigValue
        { 
            param($PropertyPath)
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
                    return "test-secret" 
                }
                "certificateThumbprint"
                {
                    return $testCert.Thumbprint 
                }
                default
                {
                    return $null 
                }
            }
        }
        
        $script:authMethodUsed = $null
        
        # Mock Invoke-RestMethod to track which method was used
        function Invoke-RestMethod
        {
            param($Method, $Uri, $ContentType, $Body, $ErrorAction)
            
            if ($Body.client_assertion)
            {
                $script:authMethodUsed = "certificate"
                return @{
                    access_token = "mock-token-cert-priority"
                    expires_in   = 3600
                    token_type   = "Bearer"
                }
            }
            if ($Body.client_secret)
            {
                $script:authMethodUsed = "secret"
                return @{
                    access_token = "mock-token-secret-fallback"
                    expires_in   = 3600
                    token_type   = "Bearer"
                }
            }
            throw "No valid authentication method"
        }
        
        $result = GetGraphAccessToken -configFile "test-config.psd1"
        
        if ($script:authMethodUsed -ne "certificate")
        {
            throw "Expected certificate authentication to be tried first, but '$script:authMethodUsed' was used"
        }
        
        if ($result -ne "mock-token-cert-priority")
        {
            throw "Expected token from certificate auth, got: $result"
        }
    }
    finally
    {
        if ($testCert)
        {
            Remove-Item -Path "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# Test 4: Neither Certificate nor Secret Available
# ============================================================================
Test-Assertion "Should fail gracefully when neither certificate nor secret is available" {
    # Override Get-DecryptedConfigValue to return neither
    function Get-DecryptedConfigValue
    { 
        param($PropertyPath)
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
                return $null 
            }
            "certificateThumbprint"
            {
                return $null 
            }
            default
            {
                return $null 
            }
        }
    }
    
    $result = GetGraphAccessToken -configFile "test-config.psd1" -ErrorAction SilentlyContinue
    
    if ($result -ne $null)
    {
        throw "Expected null result when no authentication method available, got: $result"
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
