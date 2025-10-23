# Array Save Issue Fix - Demonstration

This document demonstrates the fix for the autopilotProfilesToInclude and appModes array save issues.

## Problem Scenario

When domain configuration files contained arrays with PSCustomObject items, they would be saved incorrectly, causing data loss.

### Before the Fix

```powershell
# Original configuration with PSCustomObject arrays
$config = @{
    autopilotProfilesToInclude = @(
        [PSCustomObject]@{ id = 'guid1'; name = 'Profile 1' }
    )
}

# After Export-PowerShellDataFile
```
**Saved file content (BROKEN):**
```powershell
@{
    autopilotProfilesToInclude = ,@('')  # Empty string - data lost!
}
```

### After the Fix

```powershell
# Same configuration
$config = @{
    autopilotProfilesToInclude = @(
        [PSCustomObject]@{ id = 'guid1'; name = 'Profile 1' }
    )
}

# After Export-PowerShellDataFile
```
**Saved file content (FIXED):**
```powershell
@{
    autopilotProfilesToInclude = @(@{
        id = 'guid1'
        name = 'Profile 1'
    })
}
```

## Technical Details

### Root Cause
The `ConvertTo-Psd1String` function didn't handle PSCustomObject items within arrays. When it encountered a PSCustomObject, it called `.ToString()` which returns an empty string for PSCustomObjects.

### Solution
Added explicit PSCustomObject handling in the array processing logic:

```powershell
elseif ($item -is [PSCustomObject]) {
    # Convert PSCustomObject to Hashtable first
    $itemAsHashtable = ConvertTo-HashtableFromPSCustomObject -InputObject $item
    # Then convert to PSD1 string format
    $result += (ConvertTo-Psd1String -Configuration $itemAsHashtable -IndentLevel ($IndentLevel + 2))
}
```

### Additional Fix: Single-Item Array Syntax
Changed from `,@()` to `@()` to prevent nested arrays:

**Before:**
- Syntax: `,@(@{ id='1' })`
- Result after import: Nested array `[[@{...}]]`

**After:**
- Syntax: `@(@{ id='1' })`
- Result after import: Single-item array `[@{...}]`

## Test Results

All tests pass:
- ✅ 8 new unit tests for PSCustomObject arrays
- ✅ 32 existing tests for autopilot profiles
- ✅ 7 existing tests for domain configuration
- ✅ End-to-end workflow test
- ✅ CodeQL security check

## Real-World Impact

This fix ensures that domain configurations like this work correctly:

```powershell
@{
    domain = 'contoso.com'
    autopilotProfilesToInclude = @(
        @{
            id = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
            name = 'windowsCloudConfig Autopilot profile'
        },
        @{
            id = '78a4c8b8-c7fb-4fbb-9db6-7c91eb1db7d1'
            name = 'Hybrid join profile'
        }
    )
    appModes = @('full', 'registration')
    groupsToInclude = @(
        @{
            id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
            name = 'Cloud Managed PC User'
        }
    )
}
```

The configuration can now be:
1. Saved to a .psd1 file
2. Loaded back without data loss
3. Modified
4. Re-saved without corruption

## Files Changed
- `functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-Psd1String.ps1`
- `tests/Unit/utilityFunctions/Export-PowerShellDataFile-PSCustomObject.Tests.ps1` (new)
