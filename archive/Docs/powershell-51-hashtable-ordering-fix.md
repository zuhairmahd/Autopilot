# PowerShell 5.1 Hashtable Ordering Fix

**Date:** October 10, 2025  
**Issue:** ResolveDirectoryObject tests failing in PowerShell 5.1 but passing in PowerShell 7+  
**Status:** ✅ Resolved

---

## Problem

The `ResolveDirectoryObject.Tests.ps1` test suite was exhibiting different behavior between PowerShell versions:

- ✅ **PowerShell 7+**: All tests passing
- ❌ **PowerShell 5.1**: Multiple test failures in "Multiple Fuzzy Matches with Menu Selection" context

### Example Failures (PowerShell 5.1)

```
Context Multiple Fuzzy Matches with Menu Selection
  [-] Returns selected user from multiple fuzzy matches
    Expected: 'john.doe@contoso.com'
    But was:  'john.admin@contoso.com'
    
  [-] Calls menu system once for multiple user matches
    Expected 1, but got 0.
    
  [-] Returns selected group from multiple fuzzy matches
    Expected: 'Marketing Support'
    But was:  'Marketing Team'
```

The tests expected specific users/groups but received different ones, and expected multiple matches but only got single matches (hence MenuCallCount = 0).

## Root Cause

### PowerShell Hashtable Ordering Differences

**PowerShell 7+:**
- Hashtables are ordered by default (insertion order preserved)
- Iterating over `.Values` returns items in predictable order

**PowerShell 5.1:**
- Hashtables are **unordered** by default
- Iterating over `.Keys` or `.Values` returns items in **arbitrary, non-deterministic order**
- Order can vary between script executions

### Impact on Mock Infrastructure

The `AutopilotGraphMocks.psm1` module stores mock data in hashtables:

```powershell
$script:DefaultMockUsers = @{
    "john.doe@contoso.com"   = @{ ... }
    "jane.smith@contoso.com" = @{ ... }
    "john.admin@contoso.com" = @{ ... }
}
```

Fuzzy search operations returned results via hashtable iteration:

```powershell
# Before fix - non-deterministic order in PS 5.1
$matching = $script:MockUsers.Values | Where-Object { 
    $_.givenName -like "$searchTerm*" -or $_.surname -like "$searchTerm*" 
}
```

In PS 5.1, this could return users in **any order**, causing tests to receive unexpected results.

### Missing Mock Data

Additionally, tests expected users/groups that didn't exist in the mock data:
- Expected: `john.johnson@contoso.com` (missing - only had john.doe and john.admin)
- Expected: `Marketing Support` group (missing - only had Marketing Team and Archive Marketing)

This caused "multiple match" scenarios to become "single match" scenarios, changing code paths and breaking test assertions.

## Solution

### 1. Add Consistent Sorting to Mock Results

Modified `AutopilotGraphMocks.psm1` to sort fuzzy search results, ensuring consistent ordering across PowerShell versions:

```powershell
# User fuzzy search - now sorted by userPrincipalName
$matching = $script:MockUsers.Values | Where-Object { 
    $_.givenName -like "$searchTerm*" -or $_.surname -like "$searchTerm*" 
} | Sort-Object userPrincipalName

# Group fuzzy searches - now sorted by displayName  
$matching = $script:MockGroups.Values | Where-Object { 
    $_.displayName -like "*$searchTerm*" 
} | Sort-Object displayName
```

**Applied to all fuzzy search operations:**
- User search: `users?$filter=startswith(givenName, 'term') or startswith(surname, 'term')`
- Group search: `groups?$search="displayName:term"`
- Group startsWith: `groups?$filter=startsWith(displayName, 'term')`
- Group contains: `groups?$filter=contains(displayName, 'term')`

### 2. Add Missing Mock Data

Added the mock users and groups that tests expected:

```powershell
# Added john.johnson to provide multiple "john" matches
"john.johnson@contoso.com" = @{
    userPrincipalName = "john.johnson@contoso.com"
    displayName       = "John Johnson"
    givenName         = "John"
    surname           = "Johnson"
    mail              = "john.johnson@contoso.com"
    id                = "user-005"
}

# Added Marketing Support to provide multiple "Marketing" matches
"Marketing Support" = @{
    displayName  = "Marketing Support"
    id           = "group-005"
    mailNickname = "marketing-support"
}
```

## Changes Made

**File:** `tests/Helpers/AutopilotGraphMocks.psm1`

### User Mock Data (Lines ~23-52)
- Added `john.johnson@contoso.com` user entry

### Group Mock Data (Lines ~54-79)
- Added `Marketing Support` group entry

### User Fuzzy Search (Lines ~373-394)
- Added `| Sort-Object userPrincipalName` to result pipeline

### Group Fuzzy Searches (Lines ~398-440)
- Added `| Sort-Object displayName` to all three group search patterns:
  - `$search` parameter search
  - `startsWith` filter search  
  - `contains` filter search

## Validation

### PowerShell 5.1 Test Results

```powershell
PS C:\Users\zuhai\code\Autopilot> .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\ResolveDirectoryObject.Tests.ps1"

Running single test file: tests\Unit\ResolveDirectoryObject.Tests.ps1

Tests Passed: 28, Failed: 0, Skipped: 0
Duration: 0.35s
```

### Full Test Suite Results

```powershell
# Unit tests
.\Invoke-PesterTests.ps1 -TestType Unit
# Result: 136/136 passing

# Integration tests  
.\Invoke-PesterTests.ps1 -TestType Integration
# Result: 19/19 passing

# Complete test suite
.\Invoke-PesterTests.ps1 -TestType All
# Result: 155/155 passing
```

### Output Confirmation

Tests now show correct multi-match behavior in PS 5.1:

```
Context Multiple Fuzzy Matches with Menu Selection
  Could not find an exact match for User john.
  Found 3 User entities with similar names:  ← Now shows 3 users
  Displaying all 3 matches:
  [+] Returns selected user from multiple fuzzy matches 9ms
  [+] Calls menu system once for multiple user matches 6ms
  
  Could not find an exact match for Group Marketing.
  Found 3 Group entities with similar names:  ← Now shows 3 groups
  Displaying all 3 matches:
  [+] Returns selected group from multiple fuzzy matches 7ms
  [+] Calls menu system once for multiple group matches 7ms
```

## Technical Details

### Why Sorting Matters

Graph API responses are typically ordered, so this change also makes mocks more realistic. The sorting keys align with how users/groups are naturally identified:

- **Users**: Sorted by `userPrincipalName` (primary identifier)
- **Groups**: Sorted by `displayName` (primary identifier)

### Performance Impact

Minimal - sorting small result sets (typically 1-10 items) has negligible performance overhead in test scenarios.

### Alternative Solutions Considered

1. **Use `[ordered]` hashtables** - Only available in PS 3.0+, but doesn't guarantee iteration order in PS 5.1
2. **Convert to arrays with fixed order** - Would require significant refactoring of mock infrastructure
3. **Use `Sort-Object` on results** ✅ - **Selected**: Minimal changes, works across all PS versions, realistic behavior

## Best Practices Applied

1. **Cross-version compatibility** - Code works identically on PS 5.1 and PS 7+
2. **Predictable behavior** - Sorted results eliminate non-determinism
3. **Complete test coverage** - All expected mock data present
4. **Realistic mocking** - Sorted results mirror real Graph API behavior
5. **Minimal changes** - Solution requires only adding `| Sort-Object` to pipelines

## Related Files

- **Mock Infrastructure:** `tests/Helpers/AutopilotGraphMocks.psm1`
- **Test File:** `tests/Unit/ResolveDirectoryObject.Tests.ps1`
- **Functions Under Test:**
  - `functions/UserAndGroupFunctions/Resolve-DirectoryObject.ps1`
  - `functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1`
  - `functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1`

## Prevention

To prevent similar issues in future:

1. **Always sort mock data collections** when returning from hashtables
2. **Test on PowerShell 5.1** before marking tests complete (project requirement)
3. **Document version differences** in mock module comments
4. **Complete mock data** - ensure all entities referenced in tests exist in mocks
5. **Use `Sort-Object` consistently** in mock infrastructure for deterministic behavior

## Impact

- ✅ **155/155 tests passing** on both PowerShell 5.1 and 7+
- ✅ **Cross-version compatibility** verified and working
- ✅ **Mock infrastructure improved** with more realistic behavior
- ✅ **Phase 2 validation complete** with full PS 5.1 support
- ✅ **Foundation established** for Phase 3 integration test migration

## Additional Enhancements

This session also completed:

1. **Invoke-PesterTests.ps1 Enhancement**: Added `-TestFile` parameter to run single test files
   ```powershell
   .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\ResolveDirectoryObject.Tests.ps1"
   ```

2. **SettingsFunctions.Tests.ps1 Fix**: Fixed `.psd1` file generation to quote keys with special characters (dots, spaces, etc.)
   - Issue: Domain names like `contoso.com` caused parse errors
   - Fix: Modified `ConvertTo-Psd1String` to quote keys matching `[.\s\-@]` pattern
   - Result: 11/11 tests passing

---

**Status:** Issue resolved, all tests passing on PowerShell 5.1 and 7+, cross-version compatibility validated.
