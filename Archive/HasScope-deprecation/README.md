# HasScope Deprecation Archive

## Why Archived?

HasScope.ps1 was deprecated as part of the scope validation refactoring (Option 1 from HasScope-Refactoring-Plan.md).

**Key Findings:**
- **Not used in production**: Only called from tests, never from main application code
- **Duplicate logic**: ~120 lines of code duplicated from Test-ScopeAvailability.ps1
- **Less comprehensive**: Test-ScopeAvailability handles delegated/application auth better
- **Maintainability**: Two functions doing similar things increased complexity

## Replaced By

The composition pattern using two focused functions:

1. **Get-RequiredScopesForEndpoints.ps1** (NEW)
   - Maps Graph API endpoints → required scopes
   - Handles URI normalization (GUIDs, IDs, UPNs)
   - Strips query parameters
   - Returns scope objects for validation

2. **Test-ScopeAvailability.ps1** (EXISTING)
   - Validates JWT token has required scopes
   - Handles delegated (scp) vs application (roles) auth
   - Filters OAuth/OIDC protocol scopes
   - Provides hierarchical permission checking
   - Returns detailed validation results

## New Test Coverage

**Original:** HasScope.Tests.ps1 (26 tests)
**Migrated To:** EndpointScopeValidation.Tests.ps1 (21 tests, 17 passing, 4 skipped)

**Skipped Tests:**
- Hierarchical scope tests (4 tests) - require full scope hierarchy configuration
- These scenarios are better tested in Test-ScopeAvailability.Tests.ps1 directly

## Migration Date

November 5, 2025

## Files Archived

- `functions/graphFunctions/HasScope.ps1` (349 lines)
- `tests/Unit/graphFunctions/HasScope.Tests.ps1` (367 lines)

## Related Documentation

- `/docs/refactoring/HasScope-Refactoring-Plan.md` - Full analysis and decision rationale
- `/tests/Unit/graphFunctions/Get-RequiredScopesForEndpoints.Tests.ps1` - Helper function tests (22/22 passing)
- `/tests/Unit/graphFunctions/EndpointScopeValidation.Tests.ps1` - Composition pattern integration tests

## Usage Pattern (Before → After)

### Before (HasScope)
```powershell
$scopeCheck = HasScope -ResourcePath @('users/{id}', 'groups') `
    -requiredScopes $settings.requiredScopes `
    -accessToken $accessToken

if (-not $scopeCheck.OverallAuthorized) {
    Write-Warning "Missing scopes for: $($scopeCheck.Details.Uri -join ', ')"
}
```

### After (Composition Pattern)
```powershell
# Step 1: Map endpoints to required scopes
$endpointScopes = Get-RequiredScopesForEndpoints `
    -ResourcePaths @('users/{id}', 'groups') `
    -RequiredScopes $settings.requiredScopes

# Step 2: Validate token has those scopes
$scopeCheck = Test-ScopeAvailability -AccessToken $accessToken `
    -RequiredScopes $endpointScopes `
    -AuthConfiguration $auth

if (-not $scopeCheck.HasAllRequiredScopes) {
    Write-Warning "Missing scopes: $($scopeCheck.MissingScopes.Scope -join ', ')"
    Write-Host $scopeCheck.RecommendedAction -ForegroundColor Yellow
}
```

## Restoration

If needed, these files can be restored from this archive directory. However, we recommend using the new composition pattern instead.
