# Fix: Single Group Match Auto-Selection in Groups Editor

## Issue Summary
When users entered a partial group name in the Groups Editor that resulted in a single fuzzy match, they were being prompted to select from a list of one option. This was confusing and unnecessary since there was only one choice.

**Example of the problem:**
```
Group name: autopilot
  Searching for group: 'autopilot'...
  No exact match found. Searching for similar groups...
  Similar groups found:
    1. AutoPilot (ID: 57d1aba1-180a-4856-b497-bc6d5014f06f)
    0. Enter different group name
    00. Skip this group
  Select group, try different name, or skip (0/00/1-1):  # ❌ Unnecessary prompt
```

## Root Cause
The `Resolve-SingleGroupInteractive` function in `Show-GroupsEditor.ps1` had inconsistent behavior:
- ✅ Single **exact** matches were auto-selected without prompting
- ❌ Single **fuzzy** matches still prompted the user for selection

## Solution
Modified the fuzzy search logic to auto-select when only one match is found, making it consistent with exact match behavior.

### Code Changes

**File:** `functions/setupFunctions/Show-GroupsEditor.ps1`

**Function:** `Resolve-SingleGroupInteractive`

Added auto-selection logic for single fuzzy matches:

```powershell
if ($similarResult -and $similarResult.value -and $similarResult.value.Count -gt 0)
{
    # Auto-select if only one match found
    if ($similarResult.value.Count -eq 1)
    {
        $group = $similarResult.value[0]
        Write-Host "  Found group: '$($group.displayName)' (ID: $($group.id))" -ForegroundColor Green
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Auto-selected single fuzzy match: '$($group.displayName)' (ID: $($group.id))" -LogLevel "Verbose"
        return @{
            name = $group.displayName
            id   = $group.id
        }
    }
    
    # Multiple matches found, let user choose
    # ... (existing multi-select code)
}
```

## Expected Behavior After Fix

### Single Match (Exact or Fuzzy)
```
Group name: autopilot
  Searching for group: 'autopilot'...
  No exact match found. Searching for similar groups...
  Found group: 'AutoPilot' (ID: 57d1aba1-180a-4856-b497-bc6d5014f06f)  # ✅ Auto-selected
Group name:  # Continues to next group
```

### Multiple Matches
```
Group name: auto
  Searching for group: 'auto'...
  No exact match found. Searching for similar groups...
  Similar groups found:
    1. AutoPilot (ID: 12345...)
    2. AutoPilot-Group2 (ID: 67890...)
    0. Enter different group name
    00. Skip this group
  Select group, try different name, or skip (0/00/1-2):  # ✅ User must choose
```

## Test Coverage

### New Test File
**Created:** `TestScripts/test-groups-editor-single-match.ps1`

Tests the following scenarios:
1. ✅ Single exact match auto-selection
2. ✅ Single fuzzy match auto-selection (validates the fix)
3. ✅ Multiple matches still require user selection
4. ✅ Auto-selection events are logged

### Test Results
```
✓ Single exact matches are auto-selected
✓ Single fuzzy matches are auto-selected (FIX VALIDATED)
✓ Multiple matches still require user selection
✓ Auto-selection events are logged
```

### Updated Existing Tests
**Modified Files:**
1. `TestScripts/test-groups-editor.ps1`
   - Updated function names from `Compare-ArrayContents` to `Compare-EditorArrayContents`
   - Updated function names from `Update-DomainGroupSetting` to `Update-DomainArraySetting`
   - Added `Resolve-SingleGroupInteractive` to helper function checks

2. `TestScripts/test-groups-editor-hashtable-format.ps1`
   - Updated all `Compare-ArrayContents` calls to `Compare-EditorArrayContents`

All existing tests continue to pass with the changes.

## User Experience Improvements

### Before Fix
- Users had to press a key to select the obvious single choice
- Added unnecessary friction to the workflow
- Inconsistent with exact match behavior
- Extra steps for every single-match group

### After Fix
- Single matches are automatically selected
- Consistent behavior for exact and fuzzy matches
- Faster workflow with fewer interactions
- Only prompts when there's actually a choice to make

## Backward Compatibility
- ✅ No breaking changes to function signatures
- ✅ Maintains all existing functionality
- ✅ Multiple match selection still works as before
- ✅ All existing tests pass

## Related Files
- `functions/setupFunctions/Show-GroupsEditor.ps1` (modified)
- `TestScripts/test-groups-editor-single-match.ps1` (new)
- `TestScripts/test-groups-editor.ps1` (updated)
- `TestScripts/test-groups-editor-hashtable-format.ps1` (updated)

## Validation Steps

### Automated Testing
```powershell
# Run the new single-match test
.\TestScripts\test-groups-editor-single-match.ps1

# Run existing groups editor tests
.\TestScripts\test-groups-editor.ps1
.\TestScripts\test-groups-editor-hashtable-format.ps1
```

### Manual Testing
1. Launch the Groups Editor: `Show-GroupsEditor`
2. Select "Edit Groups to Include" or "Edit Groups to Exclude"
3. Enter a partial group name that matches only one group
4. Verify: Group is auto-selected without prompting
5. Enter a partial group name that matches multiple groups
6. Verify: User is prompted to select from the list

## Logging
Auto-selection events are logged at Verbose level:
```
Auto-selected single fuzzy match: 'AutoPilot' (ID: 57d1aba1-180a-4856-b497-bc6d5014f06f)
```

## Impact
- **Affected Function:** `Resolve-SingleGroupInteractive`
- **User-Facing:** Yes - improved UX
- **Breaking Change:** No
- **Test Coverage:** Full

## Summary
This fix eliminates unnecessary user prompts when only one group matches the search criteria, making the Groups Editor more efficient and providing a consistent user experience for both exact and fuzzy matches.
