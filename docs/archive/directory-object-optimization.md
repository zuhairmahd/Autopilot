# Directory Object Function Optimization

**Date:** October 1, 2025  
**Related Issue:** Performance optimization and redundant API call elimination  
**Affected Functions:** `Resolve-DirectoryObject`, "Show Group Assignments" action

## Problem Statement

The codebase had a **redundant API call pattern** in the "Show Group Assignments" menu action where:
1. `Resolve-DirectoryObject` was called to find and validate a group (which internally calls `Get-EntraDirectoryObject`)
2. A second call to `Get-EntraDirectoryObject` was made to retrieve the full group object for `ShowGroupAssignments`

This resulted in:
- **Duplicate Graph API calls** for the same entity
- **Unnecessary network latency** and token consumption
- **Wasted cache benefits** since the data was already retrieved

### Previous Code Flow (Inefficient)
```
User Input → Resolve-DirectoryObject (calls Get-EntraDirectoryObject) → Returns group name
           → Get-EntraDirectoryObject AGAIN with group name → Returns group object
           → ShowGroupAssignments with group object
```

## Architecture Clarification

The directory object functions serve different but complementary purposes:

| Function | Layer | Purpose | Returns |
|----------|-------|---------|---------|
| **`Get-EntraDirectoryObject`** | Data Retrieval | Low-level Graph API calls, caching, filtering | Tuple: (EntityInfo, IsFuzzyMatch) |
| **`Resolve-DirectoryObject`** | Workflow Orchestration | Search + Display + User Selection + Validation | Entity identifier OR full object OR navigation command |
| **`Show-DirectoryObjectList`** | User Interface | Display entities and capture user selection | Selected identifier OR navigation code |
| **`ConvertFrom-DirectoryObjectSelection`** | Result Processing | Map selection to return values | Normalized result for caller |

**These functions are NOT duplicates** - they form a layered architecture where each serves a specific purpose.

## Solution Implemented

Enhanced `Resolve-DirectoryObject` with a **`-ReturnEntity` switch parameter** that returns the full entity object instead of just the identifier. This allows callers to get all the entity data they need in a single workflow.

### New Code Flow (Optimized)
```
User Input → Resolve-DirectoryObject -ReturnEntity → Returns full group object directly
           → ShowGroupAssignments with group object
```

**Result:** 50% reduction in Graph API calls for this workflow.

## Changes Made

### 1. Enhanced `Resolve-DirectoryObject.ps1`

#### Added Parameter
```powershell
[Parameter(Mandatory = $false)]
[switch]$ReturnEntity
```

**Purpose:** When specified, returns the complete entity object from Graph API instead of just the userPrincipalName or displayName.

#### Updated Documentation
- Added `.PARAMETER ReturnEntity` description
- Updated `.OUTPUTS` section to clarify both return modes
- Added example showing entity object return

#### Modified Return Logic

**For Exact Matches:**
```powershell
# Return full entity object if requested, otherwise return name
if ($ReturnEntity)
{
    Write-Verbose "[$functionName] Returning full entity object for $EntityType"
    return $entity
}
return $resolvedName
```

**For Fuzzy Matches:**
```powershell
# If ReturnEntity is specified and result is not a navigation command, 
# find and return the entity object
if ($ReturnEntity -and $result -notin $ReturnValues.Values -and 
    $result -ne "EXIT_APPLICATION" -and $result -ne "Main Menu")
{
    $selectedEntity = $entityInfo[0].value | Where-Object {
        if ($EntityType -eq "User") { $_.userPrincipalName -eq $result }
        else { $_.displayName -eq $result }
    } | Select-Object -First 1
    
    if ($null -ne $selectedEntity)
    {
        return $selectedEntity
    }
}
```

### 2. Updated "Show Group Assignments" Action in `main.ps1`

#### Before (Lines 1909-1953)
```powershell
# Resolve group name
$resolvedGroupName = Resolve-DirectoryObject -EntityName $groupName ...

# Handle navigation...

# REDUNDANT: Get full group object again
$groupInfo = Get-EntraDirectoryObject -EntityName $resolvedGroupName ...

# Extract selected group from results
$selectedGroup = $groupInfo[0].value | Where-Object { 
    $_.displayName -eq $resolvedGroupName 
} | Select-Object -First 1
```

#### After (Optimized)
```powershell
# Get full group object directly with -ReturnEntity
$selectedGroup = Resolve-DirectoryObject -EntityName $groupName -AccessToken $accessToken `
    -Settings $settings -ReturnValues $returnValues -EntityType "Group" -ReturnEntity

# Handle navigation commands...

# Validate group object
if ($null -eq $selectedGroup -or -not $selectedGroup.id -or -not $selectedGroup.displayName)
{
    Write-Host "No group found for the specified group name." -ForegroundColor Red
    return $returnValues.noGroupFoundMessage
}
```

**Key improvements:**
- ✅ Single Graph API call instead of two
- ✅ Cleaner, more readable code
- ✅ Direct object validation without array extraction
- ✅ Maintains all navigation and error handling

## Usage Examples

### Standard Usage (Returns Identifier)
```powershell
# Returns userPrincipalName or displayName as string
$userName = Resolve-DirectoryObject -EntityName "john.doe" -AccessToken $token `
    -Settings $settings -ReturnValues $returnValues -EntityType "User"

if ($userName -notin $returnValues.Values) {
    # Use the username string
    Write-Host "Selected user: $userName"
}
```

### Entity Object Usage (Returns Full Object)
```powershell
# Returns complete user/group object with all properties
$userObject = Resolve-DirectoryObject -EntityName "john.doe" -AccessToken $token `
    -Settings $settings -ReturnValues $returnValues -EntityType "User" -ReturnEntity

if ($userObject -notin $returnValues.Values -and $userObject -ne "EXIT_APPLICATION") {
    # Access all properties
    Write-Host "User: $($userObject.displayName)"
    Write-Host "Email: $($userObject.userPrincipalName)"
    Write-Host "ID: $($userObject.id)"
}
```

### Group Object Usage
```powershell
# Returns complete group object
$groupObject = Resolve-DirectoryObject -EntityName "Marketing" -AccessToken $token `
    -Settings $settings -ReturnValues $returnValues -EntityType "Group" -ReturnEntity

if ($groupObject.id) {
    ShowGroupAssignments -AccessToken $token -Group $groupObject
}
```

## Backward Compatibility

✅ **Fully backward compatible** - The `-ReturnEntity` switch is optional. All existing callers continue to work unchanged.

**Default behavior (without `-ReturnEntity`):**
- Returns string identifier (userPrincipalName or displayName)
- All existing code paths work identically

**New behavior (with `-ReturnEntity`):**
- Returns full PSCustomObject with all Graph API properties
- Navigation commands still returned as strings

## Performance Benefits

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Graph API Calls | 2 per group lookup | 1 per group lookup | **50% reduction** |
| Network Round-trips | 2 | 1 | **50% reduction** |
| Code Complexity | High (multi-step extraction) | Low (direct object) | **Simplified** |
| Cache Efficiency | Partial (second call may miss) | Full (single cached result) | **Improved** |

## Testing Recommendations

### Unit Tests Needed
1. **Test `-ReturnEntity` with exact matches** (user and group)
2. **Test `-ReturnEntity` with fuzzy matches** (user and group)
3. **Test navigation commands with `-ReturnEntity`** (should return strings, not objects)
4. **Test backward compatibility** (existing tests should pass unchanged)

### Integration Tests Needed
1. **"Show Group Assignments" workflow** with various group names
2. **Performance measurement** of Graph API call reduction
3. **Cache hit rate** verification with and without `-ReturnEntity`

### Test Script Example
```powershell
# Test new functionality
$group = Resolve-DirectoryObject -EntityName "TestGroup" -AccessToken $token `
    -Settings $settings -ReturnValues $returnValues -EntityType "Group" -ReturnEntity

# Validate object properties
if ($group.id -and $group.displayName) {
    Write-Host "✅ Group object returned successfully"
} else {
    Write-Host "❌ Expected group object, got: $($group.GetType().Name)"
}

# Test navigation still works
$backResult = Resolve-DirectoryObject -EntityName "NonExistent" -AccessToken $token `
    -Settings $settings -ReturnValues $returnValues -EntityType "Group" -ReturnEntity
# User selects "Back" from menu
# Should return string navigation command, not object
```

## Future Enhancements

### Potential Additional Optimizations
1. **Consider adding `-ReturnEntity` to "Give a device to a user"** if user object properties are needed
2. **Add entity object caching at the workflow level** to further reduce duplicate lookups
3. **Implement batch entity resolution** for bulk operations
4. **Add telemetry to measure Graph API call reduction** in production

### Code Health Improvements
1. **Standardize all menu actions** to use the optimized pattern
2. **Document best practices** for choosing between identifier and entity return modes
3. **Create helper functions** for common entity property access patterns

## Migration Guide

For developers updating code to use the new feature:

### When to Use `-ReturnEntity`
✅ **Use when:**
- You need multiple properties from the entity (id, displayName, etc.)
- You're passing the entity to another function that needs the full object
- You want to avoid redundant Graph API calls

❌ **Don't use when:**
- You only need the identifier (userPrincipalName or displayName)
- You're storing the result in configuration files (use identifiers)
- The entity might be null/navigation command (handle type checking carefully)

### Migration Steps
1. Identify redundant `Get-EntraDirectoryObject` calls after `Resolve-DirectoryObject`
2. Add `-ReturnEntity` to the `Resolve-DirectoryObject` call
3. Update variable names to reflect object vs. identifier (e.g., `$groupName` → `$groupObject`)
4. Add object validation (`if ($obj.id)` instead of string checks)
5. Test navigation commands still work correctly
6. Remove the redundant `Get-EntraDirectoryObject` call

## Conclusion

This optimization demonstrates the **importance of understanding architectural layers** before refactoring. Rather than merging the functions (which would have been inappropriate), we enhanced the orchestration layer to leverage the data layer more efficiently, resulting in:

- ✅ **50% fewer Graph API calls** for entity resolution workflows
- ✅ **Cleaner, more maintainable code**
- ✅ **Full backward compatibility**
- ✅ **Preserved separation of concerns**
- ✅ **Improved performance and user experience**

The layered architecture remains intact, with each function continuing to serve its specific purpose while working together more efficiently.
