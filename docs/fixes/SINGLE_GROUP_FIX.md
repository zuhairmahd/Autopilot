# Single Group Saving Fix

## Issue Description

When editing groups using the Groups Editor, if a user enters only one group, the editor would fail to save the user's entry with a verification error. This issue did not occur when entering multiple groups.

## Root Cause

The issue was caused by PowerShell's JSON serialization behavior:

1. **Single Item Arrays**: When `ConvertTo-Json` processes an array with only one item, it outputs a single JSON object instead of an array containing one object
2. **Deserialization**: When `ConvertFrom-Json` reads this single object back, it creates a `PSCustomObject` instead of an array
3. **Verification Failure**: The verification logic in `Update-DomainGroupSetting` expected arrays and failed when comparing a single object against an array

### Example of the Issue

```powershell
# Original array with one item
$singleGroupArray = @(@{
    name = "Test Group"
    id = "12345678-1234-1234-1234-123456789abc"
})

# JSON serialization
$json = $singleGroupArray | ConvertTo-Json -Depth 10
# Results in: { "id": "...", "name": "Test Group" }  # Not an array!

# Deserialization
$reloaded = $json | ConvertFrom-Json
# Results in: PSCustomObject, not an array
```

## Solution

### 1. Enhanced Array Handling in Verification

Modified the verification logic in `Update-DomainGroupSetting` to properly handle single objects that should be treated as single-item arrays:

```powershell
# Ensure actualGroups is always an array for consistent comparison
$actualGroups = if ($null -eq $rawActualGroups)
{
    @()
}
elseif ($rawActualGroups -is [array])
{
    $rawActualGroups
}
else
{
    # Single item was deserialized as individual object - wrap in array
    @($rawActualGroups)
}
```

### 2. Improved Comparison Logic

Enhanced the hashtable comparison logic to handle both `hashtable` and `PSCustomObject` types:

```powershell
# Handle case where loaded item might be PSCustomObject instead of hashtable
$loadedName = if ($loaded -is [hashtable]) { $loaded.name } else { $loaded.name }
$loadedId = if ($loaded -is [hashtable]) { $loaded.id } else { $loaded.id }
```

### 3. Better Error Reporting

Added more detailed logging and error messages to help diagnose verification issues:

```powershell
Write-Log -LogFile $logFile -Module $functionName -Message "Verification: Saved $($groupsArray.Count) groups, Loaded $($actualGroups.Count) groups" -LogLevel "Verbose"
```

## Testing

Created comprehensive tests to verify the fix:

1. **Single Group Saving**: Verifies that single groups can be saved and verified correctly
2. **Multiple Groups Saving**: Ensures multiple groups still work as expected
3. **Empty Groups Saving**: Confirms empty arrays are handled properly

## Files Modified

1. **`functions/setupFunctions/Show-GroupsEditor.ps1`**:
   - Enhanced verification logic in `Update-DomainGroupSetting` function
   - Improved array handling for single items
   - Better error reporting

2. **`functions/setupFunctions/Save-DomainConfiguration.ps1`**:
   - Minor improvement to JSON formatting

3. **`TestScripts/test-single-group-fix.ps1`**:
   - New test to verify the fix works correctly

## Compatibility

This fix maintains full PowerShell 5.1 compatibility and does not affect any existing functionality. All existing tests continue to pass.

## Benefits

1. **Consistent Behavior**: Single and multiple group scenarios now work identically
2. **Better User Experience**: Users can confidently add single groups without encountering save errors
3. **Robust Error Handling**: Better diagnostics when verification issues occur
4. **Maintains Backward Compatibility**: No breaking changes to existing configurations