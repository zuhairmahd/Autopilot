# OIDC Scope Filtering Fix - Quick Reference

**Date:** November 5, 2025  
**Issue:** False "missing scopes" warnings for OIDC protocol scopes  
**Status:** ✅ FIXED

---

## The Problem

Users were seeing incorrect warnings like:
```
The following delegated permissions are missing:
  - openid
  - profile
  - offline_access
```

Even though these scopes were:
1. Automatically granted during authentication
2. Not Microsoft Graph API scopes
3. Already filtered out of the available scopes list

---

## Root Cause

In `Test-ScopeAvailability.ps1`:
- OIDC scopes were being filtered from the **available** scopes list (correct)
- BUT they were only filtered from the **required** scopes list for **application** auth
- For **delegated** auth, OIDC scopes remained in the required list
- Result: Validation compared Graph API scopes (available) vs Graph + OIDC scopes (required) → false "missing" warnings

---

## The Fix

**File:** `functions/graphFunctions/Test-ScopeAvailability.ps1`  
**Lines:** 60-86

Changed from:
```powershell
# Only filter for application auth
$filteredRequiredScopes = $RequiredScopes
if (-not $isDelegated) {
    $filteredRequiredScopes = $RequiredScopes | Where-Object { 
        $excludedScopesForApplication -notcontains $_.Scope
    }
}
```

To:
```powershell
# Filter for BOTH delegated and application auth
$filteredRequiredScopes = $RequiredScopes | Where-Object { 
    $scopeName = $_.Scope
    $excludedScopesForApplication -notcontains $scopeName
}
```

**Key Change:** Removed the `if (-not $isDelegated)` condition, so OIDC scopes are always filtered from the required list, regardless of auth type.

---

## Why This Works

**OIDC Protocol Scopes:**
- `openid` - OpenID Connect authentication
- `profile` - Basic user profile info
- `offline_access` - Refresh token issuance

**These are NOT Microsoft Graph API scopes:**
- They're OAuth2/OIDC protocol scopes
- Automatically granted by the authorization server
- Don't require explicit admin consent
- Not part of Graph API permission model

**Validation Logic:**
1. Filter OIDC scopes from **available** list (extract from token, remove OIDC)
2. Filter OIDC scopes from **required** list (remove before validation)
3. Compare: Graph API scopes (available) vs Graph API scopes (required)
4. Result: Only Graph API scopes are validated, no false warnings

---

## Test Coverage

**File:** `tests/Unit/graphFunctions/Test-ScopeAvailability-OIDCFilter.Tests.ps1`

**5 Tests - All Passing:**
1. ✅ Filters OIDC scopes from required list (delegated auth)
2. ✅ Reports all scopes satisfied when only Graph scopes needed
3. ✅ Only reports missing Graph API scopes, not OIDC scopes
4. ✅ Excludes OIDC scopes from available scopes list
5. ✅ Filters OIDC scopes from required list (application auth)

---

## User Impact

**Before Fix:**
```
The following delegated permissions are missing:
  - openid
  - profile  
  - offline_access
  - User.Read.All
```

**After Fix:**
```
The following delegated permissions are missing:
  - User.Read.All
```

**Result:** Users only see warnings for actual Graph API scopes they need to consent to.

---

## Related Documentation

- Full details: `docs/fixes/scope-validation-token-cache-fix.md`
- Settings file: `settings.psd1` (lines 91-115 - OIDC scopes still documented)
- Request scopes: `Request-AdditionalScopes.ps1` (adds OIDC scopes to auth requests)
