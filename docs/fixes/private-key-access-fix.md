# Private Key Access Fix

## Issue Description
Users encountered the error "You cannot call a method on a null-valued expression" when calling `Get-ClientCredentialsToken` with certificate authentication, even when the certificate was found in the certificate store and `HasPrivateKey` was `true`.

### Error Message
```
Get-ClientCredentialsToken : [Get-ClientCredentialsToken] Certificate authentication failed: You cannot call a method
on a null-valued expression.
```

### Debug Output
```
ClientId: eb287e5e-2316-4114-af7e-426627c3f23f
ClientSecret:
CertificateThumbprint: 1BBACACD50A9B83E93A4305257A983367C8812D4
```

## Root Cause
The issue occurred in the JWT signing section of `Get-ClientCredentialsToken.ps1` (around line 192). While the function checked if `$certificate.HasPrivateKey` was `true`, it did not verify that `$certificate.PrivateKey` was actually accessible. 

In some scenarios (e.g., permission issues, certificate misconfiguration, or CNG key storage provider issues), the `HasPrivateKey` property can be `true` but the `PrivateKey` property accessor returns `$null`.

The code attempted to call `.SignData()` on the null `$rsa` variable without checking if it was null first:

```powershell
$rsa = $certificate.PrivateKey
if ($rsa -is [System.Security.Cryptography.RSACryptoServiceProvider])
{
    $signature = $rsa.SignData($jwtBytes, ...)  # <-- Error here if $rsa is null
}
```

## Fix Applied
Added null checking for the `$rsa` variable immediately after retrieving `$certificate.PrivateKey`, before attempting to call any methods on it.

### Before (Lines 189-202)
```powershell
Write-Verbose "[$functionName] Signing JWT with certificate private key"
Write-Log -LogFile $LogFile -Module $functionName -Message "Signing JWT with certificate private key"

$rsa = $certificate.PrivateKey
if ($rsa -is [System.Security.Cryptography.RSACryptoServiceProvider])
{
    $signature = $rsa.SignData($jwtBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
else
{
    # For CNG keys
    $signature = $rsa.SignData($jwtBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
```

### After (Lines 189-218)
```powershell
Write-Verbose "[$functionName] Signing JWT with certificate private key"
Write-Log -LogFile $LogFile -Module $functionName -Message "Signing JWT with certificate private key"

$rsa = $certificate.PrivateKey
if (-not $rsa)
{
    $errorMsg = "Failed to access certificate private key"
    Write-Error "[$functionName] $errorMsg"
    Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel Error
    
    if ($tryBothWithFallback)
    {
        Write-Warning "[$functionName] Cannot access private key - falling back to client secret"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Cannot access private key - falling back to client secret" -LogLevel Warning
        $useCertificate = $false
        $useClientSecret = $true
        $certificate = $null
        # Skip to client secret authentication
        throw "PrivateKeyAccessFailed"
    }
    else
    {
        return $null
    }
}

if ($rsa -is [System.Security.Cryptography.RSACryptoServiceProvider])
{
    $signature = $rsa.SignData($jwtBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
else
{
    # For CNG keys
    $signature = $rsa.SignData($jwtBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
```

## Impact
This fix provides several benefits:

1. **Error Prevention**: Prevents the null-valued expression error when `PrivateKey` accessor returns `$null`
2. **Better Diagnostics**: Provides clear error message "Failed to access certificate private key" instead of cryptic null reference error
3. **Automatic Fallback**: When both certificate and client secret are provided, automatically falls back to client secret if private key is inaccessible
4. **Graceful Degradation**: When only certificate is provided, returns `$null` with appropriate logging

## Testing
Created comprehensive test suite in `test-private-key-access-fix.ps1`:

### Test Results
```
Test 1: Certificate with null PrivateKey (certificate-only mode)
✓ PASSED - Function returned null when PrivateKey is inaccessible

Test 2: Certificate with null PrivateKey (fallback to client secret)
✓ PASSED - Function fell back to client secret when PrivateKey is inaccessible
Result: mock-token-from-client-secret
```

### Test Coverage
1. **Certificate-only mode with null PrivateKey**: Verifies function returns `$null` gracefully
2. **Fallback mode with null PrivateKey**: Verifies automatic fallback to client secret authentication
3. **Normal operation with accessible PrivateKey**: Verifies certificate authentication works when PrivateKey is accessible

## Common Scenarios Where This Fix Helps

### 1. Permission Issues
User account may not have permission to access the private key even though the certificate is visible.

### 2. CNG Key Storage Provider
Certificates using CNG (Cryptography Next Generation) key storage providers may report `HasPrivateKey = $true` but fail to provide access through the legacy `PrivateKey` property.

### 3. Certificate Migration
Certificates imported without private keys or with incorrect import options may have inconsistent state.

### 4. Smart Card Certificates
Certificates backed by smart cards or hardware security modules (HSMs) may have different access patterns.

## Configuration Notes

### Recommended Configuration
When experiencing certificate authentication issues:

```powershell
@{
    tenantId = "your-tenant-id"
    appId = "your-app-id"
    thumbprint = "your-certificate-thumbprint"  # Certificate authentication
    AppSecret = "your-client-secret"            # Fallback authentication
}
```

This configuration enables automatic fallback to client secret if certificate authentication fails for any reason.

### Certificate-Only Configuration
If you want to enforce certificate-only authentication (no fallback):

```powershell
@{
    tenantId = "your-tenant-id"
    appId = "your-app-id"
    thumbprint = "your-certificate-thumbprint"
    # Do not include AppSecret
}
```

In this mode, the function will return `$null` if private key is inaccessible, requiring investigation and resolution of the certificate issue.

## Troubleshooting

### Check Certificate Private Key Access
```powershell
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq "YOUR_THUMBPRINT" }
Write-Host "HasPrivateKey: $($cert.HasPrivateKey)"
Write-Host "PrivateKey: $($cert.PrivateKey)"

if ($cert.HasPrivateKey -and -not $cert.PrivateKey) {
    Write-Warning "Certificate reports HasPrivateKey = true but PrivateKey is null"
}
```

### Fix Permission Issues
1. Export certificate with private key (PFX format)
2. Re-import with "Mark this key as exportable" option
3. Ensure user account has "Read" permission on private key

### Verify Certificate Import
```powershell
# Check certificate details
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq "YOUR_THUMBPRINT" }
$cert | Format-List *
```

## Related Files
- `functions/graphFunctions/Get-ClientCredentialsToken.ps1` - Main implementation (Lines 189-218)
- `TestScripts/test-private-key-access-fix.ps1` - Test suite
- `docs/certificate-authentication-enhancement.md` - Overall certificate authentication documentation

## References
- Issue: Null-valued expression error in certificate authentication
- Date: October 4, 2025
- Related Fixes: 
  - Certificate thumbprint initialization fix
  - Get-ClientCredentialsToken certificate authentication implementation
