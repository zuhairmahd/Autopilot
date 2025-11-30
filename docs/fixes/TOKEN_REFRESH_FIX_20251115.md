# Token Refresh Issue Fix - November 15, 2025

## Issue Summary
Users were being prompted to sign in again every time they restarted the application, despite the access token and refresh token acquisition flow appearing to work correctly during the initial authentication.

## Root Cause Analysis

### Investigation Process
1. **Examined log files** (`Logs/Autopilot.log`) for token acquisition flow
2. **Reviewed code** in `GetGraphAccessToken.ps1`, `Get-DelegatedToken.ps1`, and `Save-TokenToCache.ps1`
3. **Identified the problem**: Token response from Microsoft did not include a `refresh_token`

### Root Cause
The Microsoft OAuth2 device code flow was NOT returning a refresh token because the `offline_access` scope was missing from the token request. 

**Key Finding from Logs:**
```
2025-11-15 23:31:38.234 [Information] [Get-DelegatedToken] Token response property: token_type = Bearer
2025-11-15 23:31:38.236 [Information] [Get-DelegatedToken] Token response property: scope = openid profile email https://graph.microsoft.com/...
2025-11-15 23:31:38.238 [Information] [Get-DelegatedToken] Token response property: expires_in = 4973
2025-11-15 23:31:38.241 [Information] [Get-DelegatedToken] Token response contains access_token of length 4896
```

**Notice:** No `refresh_token` property in the response!

Without a refresh token, the application cannot refresh the access token when it expires (typically after ~1 hour), requiring the user to re-authenticate.

### Bug in FormatScopes Function
The `FormatScopes` function in `functions/graphFunctions/FormatScopes.ps1` had a logic error that prevented `offline_access` and `openid` scopes from being properly added to the token request:

**Original Buggy Code (lines 85-98):**
```powershell
$scopesFormatted = $formattedScopesArray -join ' '
Write-Verbose "[$functionName] Adding default scopes (openid and offline_access)"
#If the $scopesFormatted does not contain a scope in the $openIdScopes, add the missing scope.
foreach ($defaultScope in $openIdScopes)
{
    if (-not $scopesFormatted.Contains($defaultScope))  # ❌ Checking wrong variable
    {
        Write-Verbose "[$functionName] Adding default scope: $defaultScope"
        $scopesFormatted += " $defaultScope"  # ❌ Appending to string
    }
    else
    {
        Write-Verbose "[$functionName] Default scope already present: $defaultScope"
    }
}
$scopesFormatted = $formattedScopesArray -join ' '  # ❌ Overwrites previous additions
```

**Problems:**
1. Checked `$scopesFormatted` (already joined string) instead of `$formattedScopesArray` (array being built)
2. Appended to `$scopesFormatted` string but then immediately overwrote it with the array join
3. Result: `offline_access` and `openid` were never actually added to the final scope list

## Solution

### Code Changes

**File:** `functions/graphFunctions/FormatScopes.ps1`

**Fixed Code (lines 85-98):**
```powershell
Write-Verbose "[$functionName] Count of scopes with prefixes added: $($formattedScopesArray.count)"
Write-Verbose "[$functionName] Adding default scopes (openid and offline_access)"
#If the $formattedScopesArray does not contain a scope in the $openIdScopes, add the missing scope.
foreach ($defaultScope in $openIdScopes)
{
    if ($formattedScopesArray -notcontains $defaultScope)  # ✅ Check array
    {
        Write-Verbose "[$functionName] Adding default scope: $defaultScope"
        $formattedScopesArray += $defaultScope  # ✅ Add to array
    }
    else
    {
        Write-Verbose "[$functionName] Default scope already present: $defaultScope"
    }
}
$scopesFormatted = $formattedScopesArray -join ' '  # ✅ Join array once
```

**Key Improvements:**
1. ✅ Check `$formattedScopesArray` instead of `$scopesFormatted`
2. ✅ Use `-notcontains` operator (proper array operator)
3. ✅ Append to `$formattedScopesArray` array
4. ✅ Join array to string only once at the end

## Expected Behavior After Fix

### First Run (Initial Authentication)
1. User launches application
2. User authenticates via device code flow
3. Microsoft returns:
   - `access_token` (valid for ~1 hour)
   - **`refresh_token`** (can be used to get new access tokens) ✅
4. Both tokens are saved:
   - Access token → Memory cache (via `Save-TokenToCache`)
   - Refresh token → Config file (via `Save-RefreshTokenToConfig`)

### Subsequent Runs
1. User launches application
2. Application checks cache for valid access token
3. If access token expired:
   - Uses refresh token to get new access token
   - Saves new access token to cache
4. **No user interaction required!** ✅

## Verification Steps

### 1. Check Scope Formatting
Run the application with verbose logging and verify that scopes include `offline_access`:
```powershell
.\main.ps1 -Verbose -LogLevel "Debug"
```

Look for log entries like:
```
[FormatScopes] Adding default scope: offline_access
[FormatScopes] Adding default scope: openid
```

### 2. Verify Token Response
Check `Logs/Autopilot.log` for the token response after authentication:
```
[Get-DelegatedToken] Token response contains refresh_token of length [some number]
```

### 3. Test Token Persistence
1. Launch the application and authenticate
2. Close the application
3. Relaunch the application
4. **Expected:** No authentication prompt (uses cached/refreshed token)

### 4. Run Pester Tests
```powershell
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed
```

## Impact Assessment

### Affected Components
- ✅ **FormatScopes function** - Core fix applied
- ✅ **Get-DelegatedToken** - Will now receive refresh tokens
- ✅ **Save-RefreshTokenToConfig** - Will now be called successfully
- ✅ **Token refresh flow** - Will work as designed

### User Experience Improvements
- ✅ No repeated authentication prompts
- ✅ Seamless token refresh
- ✅ Better application performance (no auth delays)
- ✅ Improved security (refresh tokens properly handled)

### Backward Compatibility
- ✅ No breaking changes
- ✅ Existing configurations work unchanged
- ✅ Users with old tokens will simply re-authenticate once

## Testing Recommendations

### Manual Testing
1. Delete any existing tokens:
   ```powershell
   Remove-Item -Path ".secrets\accessToken.json" -ErrorAction SilentlyContinue
   ```
2. Launch application with verbose logging
3. Complete authentication flow
4. Verify refresh token saved to config
5. Restart application
6. Verify no authentication prompt

### Automated Testing
Consider adding unit tests for `FormatScopes`:
```powershell
Describe "FormatScopes" {
    It "Should add offline_access scope when missing" {
        $result = FormatScopes -scopes "Device.ReadWrite.All"
        $result | Should -Match "offline_access"
    }
    
    It "Should add openid scope when missing" {
        $result = FormatScopes -scopes "Device.ReadWrite.All"
        $result | Should -Match "openid"
    }
    
    It "Should not duplicate offline_access if already present" {
        $result = FormatScopes -scopes "Device.ReadWrite.All offline_access"
        ($result -split ' ' | Where-Object { $_ -eq "offline_access" }).Count | Should -Be 1
    }
}
```

## References

### Microsoft Documentation
- [OAuth 2.0 device code flow](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-device-code)
- [Microsoft identity platform scopes](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent)
- [Refresh tokens in Microsoft identity platform](https://learn.microsoft.com/en-us/azure/active-directory/develop/refresh-tokens)

### Related Files
- `functions/graphFunctions/FormatScopes.ps1` (fixed)
- `functions/graphFunctions/GetGraphAccessToken.ps1`
- `functions/graphFunctions/Get-DelegatedToken.ps1`
- `functions/graphFunctions/Save-TokenToCache.ps1`
- `functions/graphFunctions/Save-RefreshTokenToConfig.ps1`
- `Logs/Autopilot.log` (diagnostic logs)

## Author
Fix implemented by: GitHub Copilot
Date: November 15, 2025
Issue reported by: User

## Change Log
- **2025-11-15**: Initial fix - Corrected FormatScopes function logic to properly add offline_access scope
