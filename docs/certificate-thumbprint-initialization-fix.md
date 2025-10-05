# Certificate Thumbprint Initialization Fix

## Issue
When calling `GetGraphAccessToken.ps1`, users encountered the following error:

```
Get-ClientCredentialsToken : [Get-ClientCredentialsToken] Certificate authentication failed: You cannot call a method
on a null-valued expression.
At C:\Users\zuhai\code\Autopilot\functions\graphFunctions\GetGraphAccessToken.ps1:380 char:20
+             return Get-ClientCredentialsToken @params
+                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## Root Cause
The `$certificateThumbprint` variable was not initialized before the `try-catch` block that retrieves it from the config. If the `Get-DecryptedConfigValue` function threw an exception (which it does when a property doesn't exist), the variable remained undefined rather than being set to `$null`.

When this undefined variable was later checked in conditional statements and passed to `Get-ClientCredentialsToken`, it could cause null reference errors.

## Fix Applied
**File**: `functions/graphFunctions/GetGraphAccessToken.ps1`

**Change**: Initialize `$certificateThumbprint` to `$null` before attempting to retrieve it, and explicitly set it to `$null` in the catch block.

### Before:
```powershell
# Check for certificate thumbprint
try
{
    $certificateThumbprint = Get-DecryptedConfigValue -PropertyPath "thumbprint"
    if ($certificateThumbprint)
    {
        Write-Verbose "[$functionName] Certificate thumbprint found in config: $certificateThumbprint"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Certificate thumbprint found in config: $certificateThumbprint" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] Certificate thumbprint not found in config."
    }
}
catch
{
    Write-Verbose "[$functionName] Certificate thumbprint not found in config."
}
```

### After:
```powershell
# Check for certificate thumbprint
$certificateThumbprint = $null
try
{
    $certificateThumbprint = Get-DecryptedConfigValue -PropertyPath "thumbprint"
    if ($certificateThumbprint)
    {
        Write-Verbose "[$functionName] Certificate thumbprint found in config: $certificateThumbprint"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Certificate thumbprint found in config: $certificateThumbprint" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] Certificate thumbprint not found in config."
    }
}
catch
{
    Write-Verbose "[$functionName] Certificate thumbprint not found in config."
    $certificateThumbprint = $null
}
```

## Impact
This fix ensures that:
1. The `$certificateThumbprint` variable is always defined (either with a value or as `$null`)
2. Subsequent conditional checks work correctly: `if ($clientSecret -or $certificateThumbprint)`
3. When only client secret is available, authentication proceeds correctly without attempting certificate auth
4. No null reference exceptions occur when checking the variable's value

## Testing
Created test: `TestScripts/test-certificate-thumbprint-initialization.ps1`

Test verifies that when:
- Config contains client secret
- Config does NOT contain certificate thumbprint
- GetGraphAccessToken is called

Then:
- ✓ No null reference exceptions occur
- ✓ Client secret authentication is used successfully
- ✓ Token is obtained correctly

**Result**: Test passes successfully

## Configuration Notes
The function looks for certificate thumbprint in config using the property path: `"thumbprint"`

Example configuration with only client secret (no certificate):
```powershell
@{
    tenantId = "your-tenant-id"
    appId = "your-app-id"
    domain = "yourdomain.onmicrosoft.com"
    AppSecret = "your-client-secret"
    # No thumbprint property - this is now handled correctly
}
```

Example configuration with certificate:
```powershell
@{
    tenantId = "your-tenant-id"
    appId = "your-app-id"
    domain = "yourdomain.onmicrosoft.com"
    thumbprint = "ABCD1234567890EFABCD1234567890EFABCD1234"
    # Optional: AppSecret = "..." for fallback
}
```

## Related Files
- `functions/graphFunctions/GetGraphAccessToken.ps1` - Fixed file
- `functions/graphFunctions/Get-ClientCredentialsToken.ps1` - Called function
- `TestScripts/test-certificate-thumbprint-initialization.ps1` - Verification test

## Date
October 4, 2025
