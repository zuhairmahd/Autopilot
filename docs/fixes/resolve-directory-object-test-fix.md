# ResolveDirectoryObject.Tests.ps1 User Prompt Fix

**Date:** October 10, 2025  
**Issue:** Test file prompting for user input during execution  
**Status:** ✅ Resolved

---

## Problem

The `ResolveDirectoryObject.Tests.ps1` test file was prompting for user input during test execution, causing tests to hang and requiring manual intervention. This violated the principle of automated, unattended test execution.

## Root Cause

The `Show-DirectoryObjectList` function (called by `Resolve-DirectoryObject`) uses `Read-Host` to prompt for Y/N confirmation when displaying a single entity without the `-NoPrompt` switch:

```powershell
# In Show-DirectoryObjectList.ps1, lines 120-130
if ($EntityList.Count -eq 1)
{
    # ... display entity ...
    
    # Get Y/N confirmation
    $choice = Read-Host "(Y/N)"
    while ($choice -notin @('Y', 'N', 'y', 'n'))
    {
        Write-Host "Please enter Y or N." -ForegroundColor Red
        [console]::beep(1000, 500)
        $choice = Read-Host "(Y/N)"
    }
    # ...
}
```

The test file was not mocking `Read-Host`, so when tests triggered this code path, PowerShell waited for actual user input.

## Solution

Added a `Read-Host` mock to the test file's `BeforeAll` block to automatically return "Y" for confirmation prompts:

```powershell
# Mock Read-Host to prevent user prompts during tests
function global:Read-Host {
    param([string]$Prompt)
    # Default to "Y" for confirmation prompts
    return "Y"
}
```

Additionally fixed the `NewMenu` mock to accept the `$MenuName` parameter used by the actual function:

```powershell
function global:NewMenu {
    param($Title, $Description, $MenuName)  # Added $MenuName
    return @{
        Title = $Title
        Description = $Description
        MenuName = $MenuName  # Added to return object
        Items = @()
    }
}
```

## Changes Made

**File:** `tests\Unit\ResolveDirectoryObject.Tests.ps1`

1. Added `Read-Host` mock function that returns "Y" by default
2. Updated `NewMenu` mock to accept and return `$MenuName` parameter

## Validation

After applying the fix:

```powershell
# Single test file - no prompts, all pass
Invoke-Pester -Path ".\tests\Unit\ResolveDirectoryObject.Tests.ps1" -Output Normal
# Result: 28 tests passed

# Full unit test suite - no prompts, all pass
.\Invoke-PesterTests.ps1 -TestType Unit
# Result: 137 tests passed, 0 failed
```

## Test Coverage

The ResolveDirectoryObject test suite covers:
- **28 test cases** across multiple contexts:
  - Input Validation (4 tests)
  - Exact Match Scenarios (2 tests)
  - Fuzzy Match with NoPrompt (2 tests)
  - Multiple Fuzzy Matches with Menu Selection (6 tests)
  - No Match Scenarios (3 tests)
  - Navigation Scenarios (6 tests)
  - Settings Validation (2 tests)
  - Backward Compatibility (3 tests)

## Best Practices Applied

1. **Mock all external interactions** - `Read-Host`, `Write-Host`, menu functions, and Graph API calls
2. **Use BeforeAll for global mocks** - Ensures mocks are available for all tests
3. **Mock at appropriate scope** - Used `function global:` to ensure mocks override the actual functions
4. **Default to success path** - Mock returns "Y" to allow tests to proceed through happy paths
5. **Reset state between tests** - BeforeEach blocks reset mock counters and cache

## Related Files

- **Test File:** `tests\Unit\ResolveDirectoryObject.Tests.ps1`
- **Function Under Test:** `functions\UserAndGroupFunctions\Resolve-DirectoryObject.ps1`
- **Helper Functions:**
  - `functions\UserAndGroupFunctions\Show-DirectoryObjectList.ps1`
  - `functions\UserAndGroupFunctions\Get-EntraDirectoryObject.ps1`
  - `functions\UserAndGroupFunctions\ConvertFrom-DirectoryObjectSelection.ps1`

## Prevention

To prevent similar issues in future test files:

1. **Always mock interactive functions:**
   - `Read-Host`
   - `Write-Host` (if output matters)
   - Menu functions (`NewMenu`, `AddMenuItem`, `ShowMenu`)
   - Confirmation prompts

2. **Use test template** - The `tests\Template.Tests.ps1` should be updated to include common mocks

3. **Code review checklist** - Verify all user interaction points are mocked before merging

4. **Automated detection** - Consider adding a pre-commit hook that fails if tests timeout (indicating likely user prompt)

## Impact

- ✅ All 137 unit tests now run unattended
- ✅ Test execution time reduced (no waiting for timeouts)
- ✅ CI/CD pipeline can run tests without manual intervention
- ✅ Phase 2 of Pester migration fully validated
- ✅ Pattern established for future test conversions

---

**Status:** Issue resolved, all tests passing, ready for Phase 3 integration test migration.
