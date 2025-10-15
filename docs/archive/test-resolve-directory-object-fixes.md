# Test Fixes for Resolve-DirectoryObject

**Date:** October 1, 2025  
**Test File:** `TestScripts/test-resolve-directory-object.ps1`  
**Issue:** Three tests were failing due to incorrect mock function behavior

## Failing Tests

1. **Test 3.1** - Single user fuzzy match with NoPrompt auto-accepts
2. **Test 3.2** - Single group fuzzy match with NoPrompt auto-accepts  
3. **Test 5.4** - Null selection returns EXIT_APPLICATION

## Root Cause Analysis

### Issue 1: Incorrect Property Access in Mock (Tests 3.1 & 3.2)

**Problem:**
The mocked `Show-DirectoryObjectList` function was checking `$EntityList.value.Count` when testing for single-item auto-acceptance with `-NoPrompt`.

**Why it failed:**
In `Resolve-DirectoryObject.ps1`, the function calls `Show-DirectoryObjectList` like this:
```powershell
$possibleEntityName = Show-DirectoryObjectList -EntityList $entityInfo[0].value -EntityType $EntityType ...
```

The `$entityInfo[0].value` is already an **array of entities**, not an object with a `.value` property. The mock was trying to access `.value.Count` on an array, which would return `$null`, so the condition `$NoPrompt -and $EntityList.value.Count -eq 1` would always fail.

**Fix:**
Changed the mock to check `$EntityList.Count` instead:
```powershell
if ($NoPrompt -and $EntityList.Count -eq 1)
{
    if ($EntityType -eq "User")
    {
        return $EntityList[0].userPrincipalName
    }
    else
    {
        return $EntityList[0].displayName
    }
}
```

### Issue 2: Null Response Not Converted to 0 (Test 5.4)

**Problem:**
When `$script:MockShowDirectoryObjectListResponse` was set to `$null`, the mock function would fall through to the default behavior of returning the first item from the list, instead of returning `0` (exit).

**Why it failed:**
The real `Show-DirectoryObjectList` function has this logic:
```powershell
if ($null -eq $selectedEntity)
{
    # Return 0 to signal exit, which ConvertFrom-DirectoryObjectSelection will handle
    return 0
}
```

But the mock only returned the mocked response "if not null":
```powershell
if ($null -ne $script:MockShowDirectoryObjectListResponse)
{
    return $script:MockShowDirectoryObjectListResponse
}
```

This meant when the mock response was explicitly `$null`, it would skip this check and return the first item instead.

**Fix:**
Changed the mock to check if mocking is enabled (not just if response is non-null), and explicitly convert `$null` to `0`:
```powershell
if ($script:MockShowDirectoryObjectListEnabled)
{
    # If response is explicitly null, convert to 0 (exit) like the real function does
    if ($null -eq $script:MockShowDirectoryObjectListResponse)
    {
        return 0
    }
    return $script:MockShowDirectoryObjectListResponse
}
```

## Changes Made

### Change 1: Fix EntityList Property Access
**File:** `TestScripts/test-resolve-directory-object.ps1`  
**Lines:** ~667-682

**Before:**
```powershell
# For single item with NoPrompt, auto-return it
if ($NoPrompt -and $EntityList.value.Count -eq 1)
{
    if ($EntityType -eq "User")
    {
        return $EntityList.value[0].userPrincipalName
    }
    else
    {
        return $EntityList.value[0].displayName
    }
}
```

**After:**
```powershell
# For single item with NoPrompt, auto-return it
# Note: EntityList is passed as an array directly, not wrapped in .value property
if ($NoPrompt -and $EntityList.Count -eq 1)
{
    if ($EntityType -eq "User")
    {
        return $EntityList[0].userPrincipalName
    }
    else
    {
        return $EntityList[0].displayName
    }
}
```

### Change 2: Fix Null Response Handling
**File:** `TestScripts/test-resolve-directory-object.ps1`  
**Lines:** ~684-703

**Before:**
```powershell
# For multiple items or non-NoPrompt scenarios, use the mocked response
# This prevents ShowMenu from being called, which would prompt for input
if ($null -ne $script:MockShowDirectoryObjectListResponse)
{
    return $script:MockShowDirectoryObjectListResponse
}

# Default: return first item to avoid prompting
if ($EntityList.value.Count -gt 0)
{
    if ($EntityType -eq "User")
    {
        return $EntityList.value[0].userPrincipalName
    }
    else
    {
        return $EntityList.value[0].displayName
    }
}
```

**After:**
```powershell
# For multiple items or non-NoPrompt scenarios, use the mocked response
# This prevents ShowMenu from being called, which would prompt for input
# Check if MockShowDirectoryObjectListEnabled is set (not just if response is not null)
if ($script:MockShowDirectoryObjectListEnabled)
{
    # If response is explicitly null, convert to 0 (exit) like the real function does
    if ($null -eq $script:MockShowDirectoryObjectListResponse)
    {
        return 0
    }
    return $script:MockShowDirectoryObjectListResponse
}

# Default: return first item to avoid prompting (when mocking is disabled)
if ($EntityList.Count -gt 0)
{
    if ($EntityType -eq "User")
    {
        return $EntityList[0].userPrincipalName
    }
    else
    {
        return $EntityList[0].displayName
    }
}
```

## Test Results

### Before Fixes
```
Passed:  25
Failed:  3
Skipped: 0
Total:   28
```

**Failed tests:**
- [FAIL] 3.1 - Single user fuzzy match with NoPrompt auto-accepts
- [FAIL] 3.2 - Single group fuzzy match with NoPrompt auto-accepts
- [FAIL] 5.4 - Null selection returns EXIT_APPLICATION

### After Fixes
```
Passed:  28
Failed:  0
Skipped: 0
Total:   28
```

✅ **All tests passed successfully!**

## Key Lessons

### 1. Understand Data Structures Passed to Functions
Mock functions must match the exact data structures used by the real code. In this case, understanding that `$entityInfo[0].value` extracts the array directly was critical.

### 2. Mock Null Handling Explicitly
When mocking functions that handle null values specially (like converting to exit codes), the mock must replicate this behavior exactly. Don't rely on implicit null handling.

### 3. Test Mocks Should Mirror Real Implementation
The mock `Show-DirectoryObjectList` should behave identically to the real function for all test scenarios, including:
- Single item with `-NoPrompt` (auto-accept)
- Multiple items (return mocked selection)
- Null/exit selection (return 0)
- Empty lists (return appropriate message)

### 4. Comments are Critical in Test Code
The added comments explain WHY the mock behaves in certain ways (e.g., "EntityList is passed as an array directly, not wrapped in .value property"), making future debugging much easier.

## Impact

These fixes ensure that:
- ✅ The `-NoPrompt` parameter works correctly for automated testing
- ✅ Exit/null handling matches production behavior
- ✅ All 28 tests pass reliably
- ✅ The test suite accurately validates `Resolve-DirectoryObject` functionality

## Related Files

- **Implementation:** `functions/UserAndGroupFunctions/Resolve-DirectoryObject.ps1`
- **Dependencies:** 
  - `functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1`
  - `functions/UserAndGroupFunctions/Show-DirectoryObjectList.ps1`
  - `functions/UserAndGroupFunctions/ConvertFrom-DirectoryObjectSelection.ps1`
- **Documentation:** `docs/directory-object-optimization.md`
