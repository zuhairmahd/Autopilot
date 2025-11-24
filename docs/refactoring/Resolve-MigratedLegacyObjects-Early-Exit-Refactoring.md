# Resolve-MigratedLegacyObjects Early Exit Refactoring

## Date
October 17, 2025

## Overview
Refactored `Resolve-MigratedLegacyObjects` function to determine whether object resolution is needed before displaying the introduction message to users, improving user experience by avoiding unnecessary prompts.

## Problem Statement
The original implementation:
1. Displayed the introduction banner immediately
2. Prompted user to proceed or defer
3. Then normalized arrays and checked if objects needed ID resolution

This resulted in users being shown the resolution wizard even when:
- No legacy objects existed in their configuration
- All objects already had resolved IDs

## Solution
Moved the normalization and resolution check logic to the beginning of the function, before displaying any user interface elements.

### New Flow
1. **Extract and normalize arrays** from settings (autopilotProfilesToInclude, groupsToInclude, groupsToExclude)
2. **Count objects needing resolution** (those with null or empty IDs)
3. **Early exit conditions:**
   - If no objects exist → return success with `resolutionNeeded = false`
   - If all objects already have IDs → return success with `resolutionNeeded = false`
4. **Display introduction only if resolution is needed** → show banner with summary statistics
5. **Prompt user** to proceed or defer
6. **Continue with resolution workflow** if user confirms

## Changes Made

### 1. Moved Helper Function Declaration
- Moved `ConvertTo-NormalizedArray` helper function before it's used
- This allows normalization to happen before user interaction

### 2. Added Early Exit Logic
Added two early return scenarios:

#### Scenario A: No Objects Found
```powershell
if ($totalObjects -eq 0)
{
    return @{
        success = $true
        resolutionNeeded = $false
        # ... empty statistics
    }
}
```

#### Scenario B: All Objects Have IDs
```powershell
if ($objectsNeedingResolution -eq 0)
{
    return @{
        success = $true
        resolutionNeeded = $false
        # ... statistics showing all objects in alreadyHadIdItems
    }
}
```

### 3. Enhanced Introduction Banner
When resolution is needed, the banner now includes a summary:
```
Summary:
  - Total objects found: 15
  - Objects needing resolution: 8
  - Objects already resolved: 7
```

This gives users immediate context about what will happen.

### 4. Added New Return Property
Added `resolutionNeeded` boolean to all return objects:
- `true`: Objects needed ID resolution and process ran
- `false`: No resolution needed, early exit occurred

### 5. Updated Documentation
Updated `.OUTPUTS` section to document:
- New `resolutionNeeded` property
- Enhanced explanation of return object structure
- Clarified when `userDeferred` property is present

## Return Object Structure

### When No Objects Exist (Early Exit)
```powershell
@{
    success = $true
    resolutionNeeded = $false
    # All statistics set to 0
}
```

### When All Objects Have IDs (Early Exit)
```powershell
@{
    success = $true
    resolutionNeeded = $false
    # Statistics populated with existing objects
    # All items in alreadyHadIdItems arrays
}
```

### When User Defers Resolution
```powershell
@{
    success = $false
    userDeferred = $true
    resolutionNeeded = $true
    # All statistics set to 0
}
```

### When Resolution Completes
```powershell
@{
    success = $true/$false
    resolutionNeeded = $true
    # Detailed statistics for all object types
    # Lists of resolved, skipped, and existing items
}
```

## Benefits

### User Experience
- **No unnecessary prompts**: Users with fully resolved configurations skip the wizard entirely
- **Clear statistics**: Users see exactly what needs resolution before committing
- **Faster startup**: Early exits avoid Graph API preparation and user interaction

### Code Quality
- **Single Responsibility**: Function checks if work is needed before starting
- **Better logging**: Clear log messages indicate why function returned early
- **Predictable behavior**: Calling code can check `resolutionNeeded` property

### Performance
- **Reduced API calls**: No Graph API interaction when resolution isn't needed
- **Faster returns**: Early exits avoid unnecessary processing

## Integration Points

### Calling Function (main.ps1)
The calling function should check the return object:

```powershell
$resolutionResult = Resolve-MigratedLegacyObjects -accessToken $token -settings $domainSettings -domain $domain

if ($resolutionResult.resolutionNeeded -eq $false)
{
    # No resolution was needed, continue silently
    Write-Verbose "No legacy object resolution required"
}
elseif ($resolutionResult.userDeferred)
{
    # User chose to defer, may need to prompt again later
    Write-Warning "Legacy object resolution deferred by user"
}
elseif ($resolutionResult.success)
{
    # Resolution completed successfully
    Write-Host "Legacy objects resolved successfully"
}
else
{
    # Resolution failed
    Write-Error "Legacy object resolution failed"
}
```

## Testing Recommendations

### Test Cases
1. **No objects in settings** → Should return early with `resolutionNeeded = false`
2. **All objects have IDs** → Should return early with `resolutionNeeded = false`
3. **Mix of resolved and unresolved** → Should show banner with correct counts
4. **User defers resolution** → Should return with `userDeferred = true`
5. **Successful resolution** → Should show progress and return success

### Validation
- Verify no introduction banner shown for early exits
- Verify correct object counts in banner summary
- Verify return object properties match expected structure
- Verify logging captures reason for early exits

## Backward Compatibility
The refactoring maintains full backward compatibility:
- All existing return object properties preserved
- New `resolutionNeeded` property is additive
- Function signature unchanged
- Calling code works with or without checking new property

## Future Enhancements
Potential improvements for future consideration:
1. Add `-Force` parameter to skip early exits and force resolution check
2. Add `-Quiet` parameter to suppress all user prompts (auto-accept)
3. Cache resolution results to avoid repeated Graph API calls
4. Add detailed validation of existing IDs (verify they still exist in tenant)

## Related Files
- **Modified**: `functions/setupFunctions/Resolve-MigratedLegacyObjects.ps1`
- **Documentation**: `docs/refactoring/Resolve-MigratedLegacyObjects-Early-Exit-Refactoring.md` (this file)
- **Integration Point**: `main.ps1` (migration block around line 370)

## Coding Standards Compliance
- ✅ Four-space indentation maintained
- ✅ Comment-based help updated
- ✅ Write-Log statements added for early exits
- ✅ Write-Verbose statements for diagnostic info
- ✅ No Unicode characters used (ASCII only)
- ✅ Separate Write-Host calls for newlines
- ✅ PascalCase for function names
- ✅ camelCase for variables

## Conclusion
This refactoring significantly improves user experience by eliminating unnecessary prompts while maintaining all existing functionality and backward compatibility. The function now intelligently determines whether resolution work is needed before engaging the user, resulting in a smoother startup experience for users with properly configured systems.
