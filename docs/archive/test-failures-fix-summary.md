# Test Failures Fix Summary

## Date
October 1, 2025

## Overview
Fixed three failing tests in `test-resolve-user-matching.ps1` by identifying and correcting issues in both the function code and test implementation.

## Failing Tests
- Test 1.1: Empty username returns noUserFoundInDirectoryMessage
- Test 1.2: Empty access token returns noAccessTokenMessage  
- Test 5.4: Null from DisplayUserList returns backoutText

## Root Cause Analysis

### Tests 1.1 & 1.2: Parameter Validation Issue
**Problem**: The `Resolve-UserWithMatching` function had `[Parameter(Mandatory = $true)]` attributes on `UserName` and `AccessToken` parameters without the `[AllowEmptyString()]` attribute. PowerShell's parameter binding rejected empty strings before the function's validation logic could execute.

**Error Message**:
```
Cannot bind argument to parameter 'UserName' because it is an empty string.
Cannot bind argument to parameter 'AccessToken' because it is an empty string.
```

**Impact**: Tests couldn't verify that the function properly validates and handles empty string inputs.

### Test 5.4: Mock Function Logic Flaw
**Problem**: The mock `DisplayUserList` function checked `if ($null -ne $script:MockDisplayUserListResponse)` to determine whether to use the mocked value. When test 5.4 set `$script:MockDisplayUserListResponse = $null` to test null handling, the condition evaluated to `false`, causing the function to fall through to its default behavior of returning the first user's UPN instead of null.

**Observed Behavior**:
```
DEBUG: Result = 'john.johnson@contoso.com', Expected = 'BACK_NAVIGATION', Match = False
```

**Impact**: The test was checking for null handling but the mock wasn't actually returning null.

## Fixes Applied

### Fix 1: Add `[AllowEmptyString()]` Attribute
**File**: `functions/UserAndGroupFunctions/Resolve-UserWithMatching.ps1`

**Change**:
```powershell
# Before
[Parameter(Mandatory = $true)]
[string]$UserName,

[Parameter(Mandatory = $true)]
[string]$AccessToken,

# After
[Parameter(Mandatory = $true)]
[AllowEmptyString()]
[string]$UserName,

[Parameter(Mandatory = $true)]
[AllowEmptyString()]
[string]$AccessToken,
```

**Rationale**: The `[AllowEmptyString()]` attribute allows empty strings to pass parameter binding validation, enabling the function's internal validation logic (using `[string]::IsNullOrWhiteSpace()`) to execute and return appropriate error messages.

### Fix 2: Implement Mock Control Flag
**File**: `TestScripts/test-resolve-user-matching.ps1`

**Changes**:

1. **Added mock control variable** (line ~130):
```powershell
# Mock response control - use a flag to indicate if we want to use the mock
$script:UseMockResponse = $false
$script:MockDisplayUserListResponse = $null
```

2. **Updated mock function logic** (line ~227):
```powershell
# Before
if ($null -ne $script:MockDisplayUserListResponse)
{
    return $script:MockDisplayUserListResponse
}

# After  
if ($script:UseMockResponse)
{
    return $script:MockDisplayUserListResponse
}
```

3. **Added flag activation in all relevant tests**:
   - Test 3.1, 3.2, 3.3: Fuzzy match scenarios
   - Test 5.1, 5.2, 5.3, 5.4: Navigation scenarios
   - Test 6.4: E2E fuzzy match
   - Test 8.1, 8.2, 8.3: Settings validation

**Example**:
```powershell
# Before
$script:MockDisplayUserListResponse = $null

# After
$script:UseMockResponse = $true
$script:MockDisplayUserListResponse = $null
```

**Rationale**: Using an explicit boolean flag (`UseMockResponse`) decouples the "should I use the mock?" decision from the mock value itself, allowing tests to properly mock null returns.

### Fix 3: Updated Test Expectation
**File**: `TestScripts/test-resolve-user-matching.ps1`

**Change**: Updated the comment to clarify expected behavior:
```powershell
# When DisplayUserList returns null directly (mock bypasses conversion), ConvertFrom-UserSelection returns backoutText
# In real code, DisplayUserList converts null from ShowMenu to 0, but the mock returns null directly
Write-TestResult "5.4 - Null from DisplayUserList returns backoutText" ($result -eq $global:returnValues.backoutText)
```

**Rationale**: This documents that the test validates the edge case where `DisplayUserList` returns null directly, which shouldn't happen in production (since the real `DisplayUserList` converts null to 0), but the behavior must still be correct.

## Behavior Flow

### Production Flow (Exit via 0)
```
ShowMenu returns null (user pressed 0)
  ↓
DisplayUserList converts null → integer 0
  ↓
ConvertFrom-UserSelection receives 0
  ↓
Returns "EXIT_APPLICATION"
```

### Test 5.4 Flow (Null bypass for testing)
```
Mock directly returns null
  ↓
ConvertFrom-UserSelection receives null
  ↓
Returns backoutText ("BACK_NAVIGATION")
```

## Test Results

### Before Fixes
```
Passed:  30
Failed:  3
Skipped: 0
Total:   33
```

### After Fixes
```
Passed:  33
Failed:  0
Skipped: 0
Total:   33
```

## Files Modified

1. **`functions/UserAndGroupFunctions/Resolve-UserWithMatching.ps1`**
   - Added `[AllowEmptyString()]` attribute to parameters

2. **`TestScripts/test-resolve-user-matching.ps1`**
   - Added `$script:UseMockResponse` flag
   - Updated mock function logic
   - Enabled mock flag in 13 test cases
   - Updated test 5.4 comment

## Lessons Learned

1. **Parameter Attributes Matter**: `[Parameter(Mandatory = $true)]` rejects empty strings by default. Use `[AllowEmptyString()]` when you need to validate empty inputs within the function.

2. **Mock Design**: When mocking functions that can return null, avoid checking `if ($null -ne $mockValue)` to determine mock usage. Use an explicit flag instead.

3. **Test Documentation**: Comments explaining why a test expects certain behavior (especially edge cases) are crucial for maintenance.

4. **Test Isolation**: Tests should validate both production flows and edge cases (like the mock returning null directly), even if those edge cases shouldn't occur in production.

## Validation

All 33 tests now pass successfully:
- ✅ Input validation (3 tests)
- ✅ Exact match scenarios (2 tests)  
- ✅ Fuzzy match scenarios (5 tests)
- ✅ No match scenarios (2 tests)
- ✅ Navigation scenarios (4 tests)
- ✅ Integration tests (9 tests)
- ✅ Edge cases (5 tests)
- ✅ Settings validation (3 tests)
