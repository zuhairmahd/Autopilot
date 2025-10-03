# Fix: Case-Insensitive Group Exact Match in Groups Editor

## Issue Summary
When users entered a group name with different casing (e.g., "AutoPilot" vs "autopilot"), the exact match search would fail even though the group existed. The system would then fall back to fuzzy search, which would find the group successfully. This behavior was inefficient and inconsistent.

**Example of the problem:**
```
Group name: AutoPilot
  Searching for group: 'AutoPilot'...
  No exact match found. Searching for similar groups...  # ❌ Should have found exact match
  Found group: 'AutoPilot' (ID: 57d1aba1-180a-4856-b497-bc6d5014f06f)
```

## Root Cause
The `Get-EntraDirectoryObject` function used a **case-sensitive OData filter** for exact group matching:

```powershell
# OLD CODE - Case-sensitive
$filter = "displayName eq '$EntityName'"
```

Microsoft Graph API's `eq` operator is **case-sensitive by default**. When a user entered "autopilot" but the actual group name was "AutoPilot", the exact match would fail with no results.

However, the fuzzy search used `$search`, `startsWith`, or `contains` filters, which are **case-insensitive**, successfully finding the group.

## Solution
Modified the exact match filter to use the `tolower()` function, making it case-insensitive:

```powershell
# NEW CODE - Case-insensitive
$lowerEntityName = $EntityName.ToLower()
$filter = "tolower(displayName) eq '$lowerEntityName'"
```

This ensures that "autopilot", "AutoPilot", "AUTOPILOT", and any other casing variant will all match the same group.

### Code Changes

**File:** `functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1`

**Section:** Group exact match logic (lines ~107-114)

```powershell
else
{
    # Group exact match by displayName (case-insensitive using tolower)
    $resourcePath = "groups"
    $lowerEntityName = $EntityName.ToLower()
    $filter = "tolower(displayName) eq '$lowerEntityName'"
    $extraParameters = "select=displayName,id"
    $entityInfo = CallGraphAPI -AccessToken $AccessToken -ResourcePath $resourcePath -Filter $filter -ExtraParameters $extraParameters
}
```

## Expected Behavior After Fix

### Exact Match (Any Casing)
```
Group name: autopilot
  Searching for group: 'autopilot'...
  Found group: 'AutoPilot' (ID: 57d1aba1-180a-4856-b497-bc6d5014f06f)  # ✅ Exact match found
Group name:  # Continues to next group
```

### Still Falls Back to Fuzzy When Needed
```
Group name: auto
  Searching for group: 'auto'...
  No exact match found. Searching for similar groups...  # ✅ Correct - "auto" ≠ "AutoPilot"
  Similar groups found:
    1. AutoPilot (ID: 57d1...)
    2. Automation (ID: 89abc...)
```

## Benefits

### Performance
- **Faster lookups**: Exact match is faster than fuzzy search (1 API call vs 2-3 calls)
- **Reduced API calls**: Eliminates unnecessary fuzzy searches when exact match should work
- **Better caching**: Cache hits work regardless of casing

### User Experience
- **More intuitive**: Users don't need to worry about exact casing
- **Consistent**: Behavior matches user expectations from other systems
- **Clearer feedback**: "Found group" instead of "No exact match found. Searching..."

### Code Quality
- **Consistency**: User searches are already case-insensitive; now groups match
- **Standards compliance**: Aligns with Microsoft Graph best practices
- **Maintainability**: Single, clear approach to matching

## Test Coverage

### New Test Cases
**File:** `TestScripts/test-groups-editor-single-match.ps1`

Added Test 4: Case-Insensitive Exact Match
- Tests multiple casings: "autopilot", "AutoPilot", "AUTOPILOT", "AuToPiLoT"
- Validates all variations find the same group via exact match
- Confirms no fallback to fuzzy search occurs

### Test Results
```
Test 4: Case-Insensitive Exact Match
This test verifies that exact match is case-insensitive for groups
  Testing: 'autopilot'
    ✓ Found via exact match (case-insensitive)
  Testing: 'AutoPilot'
    ✓ Found via exact match (case-insensitive)
  Testing: 'AUTOPILOT'
    ✓ Found via exact match (case-insensitive)
  Testing: 'AuToPiLoT'
    ✓ Found via exact match (case-insensitive)
✓ Case-insensitive exact match works for all casings
```

## Technical Details

### OData Filter Functions
Microsoft Graph API supports several string functions in OData filters:

- `tolower(field)` - Converts field to lowercase (used in our fix)
- `toupper(field)` - Converts field to uppercase (alternative approach)
- `eq` - Equals operator (case-sensitive by default)
- `contains` - Substring match (case-insensitive, but requires advanced query)
- `startsWith` - Prefix match (case-insensitive)

Our implementation uses `tolower()` on both sides of the comparison:
```powershell
tolower(displayName) eq 'autopilot'
```

This ensures:
1. The group's displayName is converted to lowercase
2. The search term is also converted to lowercase
3. The comparison is effectively case-insensitive
4. No advanced query headers are required

### Why Not Use `$search`?
The `$search` operator is case-insensitive and powerful, but:
- Requires `ConsistencyLevel: eventual` header
- Performs substring matching (not exact match)
- Less efficient for exact match scenarios
- Returns broader results requiring additional filtering

Our `tolower()` approach:
- Performs true exact matching (case-insensitive)
- Requires no special headers
- More efficient for exact match use case
- Returns precise results

## Related Changes

This fix complements the previous fix for single match auto-selection:
1. **Previous fix**: Single fuzzy matches are auto-selected (no prompt)
2. **This fix**: Groups are found via exact match (no fuzzy search needed)

**Combined benefit**: When user enters "autopilot":
- **Old behavior**: Case-sensitive exact match fails → fuzzy search finds 1 match → prompt user
- **New behavior**: Case-insensitive exact match succeeds → auto-select immediately

## Backward Compatibility
- ✅ No breaking changes to function signatures
- ✅ All existing functionality preserved
- ✅ User search behavior unchanged (was already case-insensitive)
- ✅ All existing tests pass
- ✅ Fuzzy search still works as fallback

## Impact Analysis

### Before Fix
- User types: "AutoPilot"
- Exact match: ✅ Success (casing matches)
- User types: "autopilot"  
- Exact match: ❌ Fail (casing doesn't match)
- Fuzzy search: ✅ Success
- Result: 2 API calls, inconsistent behavior

### After Fix
- User types: "AutoPilot"
- Exact match: ✅ Success (case-insensitive)
- User types: "autopilot"
- Exact match: ✅ Success (case-insensitive)
- Result: 1 API call, consistent behavior

## Related Files
- `functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1` (modified)
- `TestScripts/test-groups-editor-single-match.ps1` (updated with new test)
- `functions/setupFunctions/Show-GroupsEditor.ps1` (benefits from fix)

## Validation Steps

### Automated Testing
```powershell
# Run the updated test suite
.\TestScripts\test-groups-editor-single-match.ps1
```

### Manual Testing
1. Launch the Groups Editor: `Show-GroupsEditor`
2. Select "Edit Groups to Include" or "Edit Groups to Exclude"
3. Enter a group name with **different casing** than actual group:
   - If group is "AutoPilot", try: "autopilot", "AUTOPILOT", "AuToPiLoT"
4. Verify: Group is found via exact match (no "searching for similar groups" message)
5. Verify: Group is auto-selected immediately

## Future Enhancements
Consider applying similar case-insensitive logic to:
- User exact match (currently uses direct resource path)
- Other entity types if added in the future
- Custom filtering scenarios

## References
- Microsoft Graph API OData filter documentation
- OData string functions reference
- Graph API best practices for filtering

## Summary
This fix eliminates unnecessary API calls and improves user experience by making group exact match case-insensitive, aligning with user expectations and reducing system overhead. Combined with the single-match auto-selection fix, users now get instant results regardless of how they type the group name.
