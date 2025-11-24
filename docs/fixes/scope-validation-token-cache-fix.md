# Scope Validation and Token Cache Fix

**Date:** November 5, 2025  
**Issue:** Users prompted to re-authenticate for scopes, but still seeing "missing scopes" error after restart  
**Root Cause:** Two critical bugs in scope validation and token caching logic

---

## Problems Identified

### Problem 1: Delegated Auth Scope Validation Bug (CRITICAL) ❌

**Location:** `Test-ScopeAvailability.ps1` lines 104-125 (original)

**Issue:** For delegated authentication, the function was checking what scopes were **REQUESTED** (`$AuthConfiguration.scope`), not what scopes were actually **GRANTED** by the user during consent.

**Why This Failed:**
1. User authenticates and consents to scopes → JWT token issued with `scp` claim containing **granted** scopes
2. Test-ScopeAvailability checks `$AuthConfiguration.scope` (what app requested)
3. If user denied some scopes during consent, they'd still show as "available" incorrectly
4. Conversely, if user granted more scopes than requested, they wouldn't be recognized

**Analogy:** It's like checking your grocery list (what you wanted to buy) instead of checking your shopping cart (what you actually bought).

**Impact:**
- False negatives: Features disabled even though user granted the scope
- False positives: Features enabled even though user denied the scope
- Incorrect "missing scopes" messages after re-authentication

---

### Problem 2: Token Cache Doesn't Validate Scopes ❌

**Location:** `Test-CachedTokenValidity.ps1` lines 1-31 (original)

**Issue:** Cached tokens were only validated for expiry time, not for scope coverage. When application scope requirements changed, old tokens with insufficient scopes would still be used.

**Why This Failed:**
1. User authenticates with scopes [A, B, C] → token cached
2. Application updated to require scopes [A, B, C, D, E]
3. Cached token is not expired, so it's returned
4. Scope validation runs and reports D and E are missing
5. User re-authenticates and consents to [A, B, C, D, E]
6. **BUG**: Old cached token with [A, B, C] is still used because cache doesn't check scopes!

**Impact:**
- Users stuck in re-authentication loop
- Cached tokens with insufficient scopes block new tokens from being used
- "Missing scopes" error persists even after successful re-authentication

---

## Solutions Implemented

### Fix 1: Read Actual Granted Scopes from JWT Token ✅

**File:** `Test-ScopeAvailability.ps1`

**Change:** For delegated authentication, decode the JWT access token and read the `scp` claim to get the **actual granted scopes**, not the requested scopes.

**Code Change:**
```powershell
# BEFORE (WRONG - checks requested scopes):
if ($isDelegated) {
    $result.AvailableScopes = $RequestedScopes  # From $AuthConfiguration.scope
}

# AFTER (CORRECT - checks granted scopes):
if ($isDelegated) {
    $decodedToken = DecodeJwtToken -Token $AccessToken -raw
    $scpScopes = $decodedToken.scp -split ' '  # Space-separated string
    $result.AvailableScopes = $scpScopes | Where-Object { $excludedScopes -notcontains $_ }
}
```

**Benefits:**
- ✅ Accurate scope validation based on actual user consent
- ✅ Detects partial consent (user denied some scopes)
- ✅ Recognizes additional scopes granted beyond what was requested
- ✅ Consistent behavior between delegated and application auth (both read from token)

---

### Fix 2: Validate Cached Token Scopes ✅

**File:** `Test-CachedTokenValidity.ps1`

**Change:** Added scope validation to cached tokens. Before returning a cached token, decode it and verify all requested scopes are present in the granted scopes.

**Code Change:**
```powershell
# Added parameter:
param(
    [string[]]$requestedScopes = @()  # NEW: Pass in required scopes
)

# Added scope validation:
if ($requestedScopes -and $requestedScopes.Count -gt 0) {
    $decodedToken = DecodeJwtToken -Token $accessTokenObject.access_token -raw
    $grantedScopes = $decodedToken.scp -split ' '  # or $decodedToken.roles for app auth
    
    # Check if all requested scopes are present
    $missingScopes = $requestedScopes | Where-Object { $grantedScopes -notcontains $_ }
    
    if ($missingScopes.Count -gt 0) {
        Write-Verbose "Cached token missing scopes: $($missingScopes -join ', ') - invalidating"
        return $null  # Force new token acquisition
    }
}
```

**Benefits:**
- ✅ Cached tokens automatically invalidated when scope requirements change
- ✅ Re-authentication immediately effective (new token replaces old in cache)
- ✅ Prevents "missing scopes" loop after successful consent
- ✅ Supports both delegated (`scp`) and application (`roles`) auth

---

## JWT Token Claims Reference

### Delegated Authentication (User + App)
- **Claim:** `scp` (scopes)
- **Format:** Space-separated string
- **Example:** `"User.Read.All Group.Read.All Device.Read.All"`
- **Contains:** Scopes the user consented to for the app

### Application Authentication (App-only)
- **Claim:** `roles` (application permissions)
- **Format:** Array of strings
- **Example:** `["User.Read.All", "Group.Read.All"]`
- **Contains:** Permissions granted by admin in app registration

### Protocol Scopes (Excluded from Graph API validation)
- `openid` - OpenID Connect authentication
- `profile` - Basic user profile info
- `offline_access` - Refresh token issuance

---

## Testing & Verification

### Test Scenario 1: User Denies Some Scopes
1. App requests: `User.Read.All`, `Group.Read.All`, `Device.Read.All`
2. User consents only: `User.Read.All`, `Group.Read.All`
3. Token `scp` claim: `"User.Read.All Group.Read.All"`
4. **Expected:** Missing scopes reported: `Device.Read.All` ✅
5. **Before Fix:** All three scopes shown as available ❌

### Test Scenario 2: Scope Requirements Change
1. User authenticates with scopes: `User.Read.All`, `Group.Read.All`
2. Token cached
3. Application updated to also require: `DeviceManagementApps.ReadWrite.All`
4. **Expected:** Cached token invalidated, user re-authenticates ✅
5. **Before Fix:** Cached token used, "missing scopes" error persists ❌

### Test Scenario 3: Re-authentication After Consent
1. User sees "missing scopes" error
2. User consents to additional scopes
3. New token acquired
4. **Expected:** All scopes now available, no error ✅
5. **Before Fix:** Old cached token still used, error remains ❌

---

## Migration Notes

### No Breaking Changes
- ✅ Backward compatible - existing code continues to work
- ✅ No changes to function signatures or return types
- ✅ No changes to calling code required

### Enhanced Behavior
- Scope validation is now accurate for delegated auth
- Token cache automatically invalidates when scopes change
- Users no longer stuck in re-authentication loops

### Performance Impact
- **Minimal** - Token decode already happens for application auth
- **Benefit** - Fewer unnecessary re-authentications
- **Cache hits** - Still return instantly when token valid and scopes match

---

## Related Documentation

- **JWT Token Structure:** https://jwt.io
- **Microsoft Identity Platform Tokens:** https://learn.microsoft.com/en-us/entra/identity-platform/access-tokens
- **Graph API Permissions:** https://learn.microsoft.com/en-us/graph/permissions-reference

---

## Files Modified

1. **functions/graphFunctions/Test-ScopeAvailability.ps1**
   - Lines 104-125: Changed delegated auth to decode JWT token and read `scp` claim
   - Added token decoding logic matching application auth pattern
   - Improved logging and error handling
   - **Lines 62-86: Fixed OIDC scope filtering** - Now filters OIDC protocol scopes (`openid`, `profile`, `offline_access`) from required scopes for BOTH delegated and application auth (previously only filtered for application auth)

2. **functions/graphFunctions/Test-CachedTokenValidity.ps1**
   - Added `requestedScopes` parameter
   - Added scope validation logic before returning cached token
   - Invalidates cache when scopes don't match

3. **functions/graphFunctions/Get-TokenFromCache.ps1**
   - Line 35: Pass `requestedScopes` to `Test-CachedTokenValidity`

---

## Additional Fix: OIDC Scope False Positives (November 5, 2025)

### Problem 3: OIDC Scopes Incorrectly Flagged as Missing ❌

**Issue:** Even though OIDC protocol scopes (`openid`, `profile`, `offline_access`) were being filtered out of the **available scopes** list (correctly), they were NOT being filtered out of the **required scopes** list for delegated authentication. This caused the validation logic to report them as "missing" even though:
1. They're automatically granted during OAuth authentication flow
2. They're not Microsoft Graph API scopes
3. They should never be validated

**Why This Failed:**
1. `settings.psd1` includes OIDC scopes in `requiredScopes` array (for documentation purposes)
2. `Test-ScopeAvailability` filtered OIDC scopes from available scopes (correct)
3. **BUG**: OIDC scopes were only filtered from required scopes for **application** auth, not **delegated** auth
4. Result: Delegated auth showed false "missing scopes" warnings for `openid`, `profile`, `offline_access`

**User Impact:**
```
The following delegated permissions are missing:
  - openid
    Reason: Standard scope required for user sign-in with OpenID Connect.
  - profile
    Reason: Standard scope to get basic user profile information during sign-in.
  - offline_access
    Reason: Standard scope that provides refresh tokens to maintain access when the user is not active.
```

### Fix 3: Filter OIDC Scopes from Required Scopes (Both Auth Types) ✅

**File:** `Test-ScopeAvailability.ps1`

**Change:** Lines 62-86 now filter OIDC protocol scopes from the required scopes list for **BOTH** delegated and application authentication (previously only filtered for application auth).

**Code Change:**
```powershell
# BEFORE (WRONG - only filtered for application auth):
$filteredRequiredScopes = $RequiredScopes
if (-not $isDelegated) {
    $filteredRequiredScopes = $RequiredScopes | Where-Object { 
        $excludedScopesForApplication -notcontains $_.Scope
    }
}

# AFTER (CORRECT - filters for both auth types):
$filteredRequiredScopes = $RequiredScopes | Where-Object { 
    $scopeName = $_.Scope
    $excludedScopesForApplication -notcontains $scopeName
}
# Always filter, regardless of auth type
```

**Benefits:**
- ✅ No false "missing scopes" warnings for OIDC protocol scopes
- ✅ Consistent behavior: OIDC scopes excluded from both available and required lists
- ✅ Cleaner validation output focused on actual Graph API scopes
- ✅ User experience: Only see warnings for scopes they actually need to consent to

**Logic:**
- OIDC scopes are automatically granted during authentication flow
- They're not Graph API permissions that need explicit consent
- Filtering them from both lists ensures they're never compared/validated
- Settings file can still document them for reference without causing false warnings

---

## Rollback Plan

If issues arise, revert changes with:

```bash
git checkout HEAD~1 -- functions/graphFunctions/Test-ScopeAvailability.ps1
git checkout HEAD~1 -- functions/graphFunctions/Test-CachedTokenValidity.ps1
git checkout HEAD~1 -- functions/graphFunctions/Get-TokenFromCache.ps1
```

Original behavior:
- Delegated auth checks requested scopes (from `$AuthConfiguration.scope`)
- Cache validates only expiry time, not scopes
