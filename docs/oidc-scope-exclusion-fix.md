# OIDC Scope Exclusion Fix

## Issue
OpenID Connect (OIDC) protocol scopes (`openid`, `profile`, `offline_access`) were incorrectly appearing as **missing required scopes** when using application (non-delegated) authentication, even though:
1. These are OAuth2/OIDC protocol scopes, not Microsoft Graph API permissions
2. They don't apply to application authentication at all
3. They were correctly being filtered from the available scopes

## Root Cause Analysis

### Primary Issue
The OIDC scopes were incorrectly included in the `requiredScopes` array in `settings.psd1` (lines 92-100 and 123-125). When using application authentication, these scopes were:
- Being checked as required Graph API permissions (which they are not)
- Reported as "missing" even though they don't apply to application auth
- Causing confusing error messages asking admins to add non-existent permissions

### Secondary Issue (Test Coverage)
The original test suite was using invalid JWT tokens that couldn't be decoded, preventing proper testing of the filtering logic.

## Solution

### 1. Filter Required Scopes for Application Authentication
Modified `Test-ScopeAvailability.ps1` to filter OIDC scopes from the required scopes list when using application authentication:

```powershell
# Filter required scopes for application authentication - exclude OIDC protocol scopes
# These scopes only apply to delegated authentication and should not be validated for application auth
$filteredRequiredScopes = $RequiredScopes
if (-not $isDelegated)
{
    $originalCount = $RequiredScopes.Count
    $filteredRequiredScopes = $RequiredScopes | Where-Object { 
        $scopeName = $_.Scope
        $excludedScopesForApplication -notcontains $scopeName
    }
    $excludedFromRequired = $originalCount - $filteredRequiredScopes.Count
    if ($excludedFromRequired -gt 0)
    {
        $excludedScopeNames = $RequiredScopes | Where-Object { 
            $excludedScopesForApplication -contains $_.Scope 
        } | ForEach-Object { $_.Scope }
        Write-Verbose "[$functionName] Excluded $excludedFromRequired OIDC scope(s) from required scopes for application auth: $($excludedScopeNames -join ', ')"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Excluded $excludedFromRequired OIDC scope(s) from required scopes: $($excludedScopeNames -join ', ')" -LogLevel "Information"
    }
}

# Update RequiredScopes to use the filtered list
$RequiredScopes = $filteredRequiredScopes
```

This ensures that when using application authentication:
- OIDC scopes are removed from the required scopes list **before** validation
- They won't be reported as missing
- They won't cause confusion in error messages

### 1. Created Mock JWT Token Generator
Added a helper function `New-MockJwtToken` to generate properly formatted JWT tokens for testing:

```powershell
function New-MockJwtToken {
    param([hashtable]$Claims = @{})
    
    # Create properly formatted JWT with base64url-encoded header and payload
    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $headerBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($header))
        .TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    $payload = $Claims | ConvertTo-Json -Compress
    $payloadBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload))
        .TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    return "$headerBase64.$payloadBase64.fake-signature"
}
```

### 2. Added Comprehensive OIDC Exclusion Tests

#### Test 6: Application Authentication with OIDC Scopes in Available Scopes
Tests that OIDC scopes in the `roles` claim are excluded from available scopes:
- Creates JWT token with: `["User.Read.All", "Device.Read.All", "openid", "profile", "offline_access"]`
- Verifies that only Graph API scopes are retained: `["User.Read.All", "Device.Read.All"]`
- Confirms filtered scope count is correct (2 instead of 5)

#### Test 7: Application Authentication with 'scp' Claim
Tests OIDC exclusion when scopes are in the `scp` claim (space-delimited string):
- Creates JWT token with: `"User.Read.All openid profile Device.Read.All"`
- Verifies OIDC scopes are excluded from the space-delimited string
- Confirms Graph API scopes are preserved

#### Test 8.5: Application Authentication with OIDC Scopes in Required Scopes (Real-World Scenario)
Tests the actual problem reported - OIDC scopes incorrectly in the required scopes list:
- Creates required scopes list with: `["User.Read.All", "openid", "profile", "offline_access", "Device.Read.All"]`
- Creates JWT token with only Graph scopes: `["User.Read.All", "Device.Read.All"]`
- Verifies that validation passes (OIDC scopes filtered from required list)
- Confirms no OIDC scopes appear in missing scopes
- **This is the key test that validates the fix for the reported issue**

## Test Results
All tests now pass successfully:

```
✓ Application auth excludes 'openid' scope (from available scopes)
✓ Application auth excludes 'profile' scope (from available scopes)
✓ Application auth excludes 'offline_access' scope (from available scopes)
✓ Application auth keeps Graph API scopes
✓ Application auth filtered scope count is correct
✓ Application auth with 'scp' claim excludes OIDC scopes
✓ Application auth with 'scp' claim keeps Graph scopes
✓ Application auth filters OIDC scopes from required scopes list (KEY TEST)
✓ Application auth missing scopes does not include OIDC scopes (KEY TEST)
✓ Application auth doesn't report OIDC scopes as missing (KEY TEST)
```

## Before and After

### Before Fix
```
Microsoft Graph Scope Validation Results:
Some required permissions are missing. This may limit functionality.

Missing permissions:
  - User.Read.All
  - BitlockerKey.Read.All
  - openid ❌ (incorrectly reported as missing)
  - profile ❌ (incorrectly reported as missing)
  - offline_access ❌ (incorrectly reported as missing)
```

### After Fix
```
Microsoft Graph Scope Validation Results:
Some required permissions are missing. This may limit functionality.

Missing permissions:
  - User.Read.All
  - BitlockerKey.Read.All

(OIDC scopes are no longer reported as missing for application auth)
```

## Files Modified
1. `functions/graphFunctions/Test-ScopeAvailability.ps1`: Added required scope filtering for application auth
2. `TestScripts/test-scope-validation.ps1`: Added `New-MockJwtToken` helper and Test 8.5

## Implementation Details

### Two-Layer Filtering Approach

The fix implements filtering at two different stages:

#### 1. Filter Available Scopes (Already existed, lines 136-149)
When extracting scopes from the JWT token for application authentication:

```powershell
$unfilteredScopes = $tokenScopes | Where-Object { $_ -and $_.Trim() }
$filteredScopes = $unfilteredScopes | Where-Object { $excludedScopesForApplication -notcontains $_ }
```

This ensures OIDC scopes in the token are excluded from available scopes.

#### 2. Filter Required Scopes (New fix, lines 56-78)
Before validation begins for application authentication:

```powershell
if (-not $isDelegated)
{
    $filteredRequiredScopes = $RequiredScopes | Where-Object { 
        $scopeName = $_.Scope
        $excludedScopesForApplication -notcontains $scopeName
    }
    $RequiredScopes = $filteredRequiredScopes
}
```

This ensures OIDC scopes in the required scopes list are excluded from validation.

**Why both layers are needed:**
- Layer 1 prevents OIDC scopes from being counted as available permissions
- Layer 2 prevents OIDC scopes from being checked as required permissions
- Together, they ensure OIDC scopes are completely ignored for application auth

### Excluded Scopes Definition
The exclude list is defined once at the function start (lines 20-26):

```powershell
$excludedScopesForApplication = @(
    'openid',
    'profile',
    'offline_access'
    # Additional non-Graph scopes can be added here in the future
)
```

This single list is used for both filtering operations, ensuring consistency.

## Verification

### Test Suite
Run the test suite to verify the fix:

```powershell
.\TestScripts\test-scope-validation.ps1
```

Expected output: All 37 tests pass, including the 3 new OIDC-specific tests that validate both available scope filtering and required scope filtering.

### Real Application Test
Run the application with application authentication:

```powershell
.\main.ps1 -OverwriteLogs
```

**Before fix:** Scope validation reports `openid`, `profile`, and `offline_access` as missing permissions

**After fix:** These OIDC scopes are filtered out and not reported as missing

## Notes on settings.psd1

While the OIDC scopes are now properly excluded from validation for application authentication, they remain in `settings.psd1` because:

1. **They're valid for delegated authentication** - When users sign in interactively, these OIDC protocol scopes are needed
2. **The fix handles both scenarios** - The function automatically filters them out for application auth but allows them for delegated auth
3. **No settings file changes needed** - The fix is backward compatible with existing configuration

If you want to clean up `settings.psd1`, you could:
- Remove OIDC scopes from `requiredScopes` array (they'll be automatically requested for delegated auth anyway)
- Keep them in the `auth.scope` array where they belong for delegated authentication

## Related Documentation
- [Scope Hierarchy Implementation](scope-hierarchy-implementation.md)
- [Scope Validation Documentation](SCOPE_VALIDATION.md)
- [OAuth 2.0 and OpenID Connect on Microsoft identity platform](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols)
