# Microsoft Graph Scope Hierarchy Implementation

## Summary
Enhanced `Test-ScopeAvailability.ps1` to intelligently evaluate Microsoft Graph permission requirements using hierarchical comparison instead of literal string matching. This eliminates false-positive "missing permission" warnings when users have higher-privilege scopes that satisfy lower-privilege requirements.

## Problem Statement
The previous implementation used literal scope comparison (`$result.AvailableScopes -contains $scopeName`), which incorrectly reported missing permissions when:
- User had `Device.ReadWrite.All` but function required `Device.Read.All`
- User had `User.ReadWrite` but function required `User.Read`
- User had broader constraint scopes (`.All`) when narrower scopes (`.OwnedBy`) were required

This created misleading warnings suggesting users lacked necessary permissions when they actually had sufficient (or greater) access.

## Solution Architecture

### New Function: `Test-ScopeHierarchy`
**Location**: `functions\graphFunctions\Test-ScopeHierarchy.ps1`

Implements intelligent scope comparison by parsing Microsoft Graph permission naming patterns and comparing hierarchical privilege levels.

#### Scope Naming Pattern
Microsoft Graph permissions follow the pattern: `{Resource}.{Operation}.{Constraint}`

**Examples:**
- `Device.Read.All` = Device resource, Read operation, All constraint
- `User.ReadWrite` = User resource, ReadWrite operation, no constraint (self)
- `Application.ReadWrite.OwnedBy` = Application resource, ReadWrite operation, OwnedBy constraint

#### Operation Hierarchy
Higher-level operations include capabilities of lower-level operations:

```
ReadBasic < Read < ReadWrite < Manage
  (0)       (1)       (2)        (3)
```

**Rationale:**
- `ReadWrite` includes all `Read` capabilities plus write/update/delete
- `Manage` includes all `ReadWrite` capabilities plus administrative functions
- `ReadBasic` is more restrictive than `Read` (subset of properties)

**Examples:**
- ✅ `User.ReadWrite.All` satisfies `User.Read.All` requirement (2 >= 1)
- ❌ `User.Read.All` does NOT satisfy `User.ReadWrite.All` requirement (1 < 2)
- ✅ `Group.Manage.All` satisfies `Group.ReadWrite.All` requirement (3 >= 2)

#### Constraint Hierarchy
Broader constraints include capabilities of narrower constraints:

```
None < OwnedBy < Selected < Shared < All
 (0)     (1)       (2)       (3)    (4)
```

**Rationale:**
- `None` (no suffix) = User's own resources only
- `OwnedBy` = Resources owned/created by the application
- `Selected` = Specific selected resources
- `Shared` = Shared/delegated resources
- `All` = All resources in the organization

**Examples:**
- ✅ `Application.ReadWrite.All` satisfies `Application.ReadWrite.OwnedBy` (4 >= 1)
- ❌ `Application.ReadWrite.OwnedBy` does NOT satisfy `Application.ReadWrite.All` (1 < 4)
- ✅ `User.Read.All` satisfies `User.Read` (4 >= 0)

#### Combined Hierarchies
For a scope to satisfy a requirement:
- Available operation level ≥ Required operation level **AND**
- Available constraint level ≥ Required constraint level

**Examples:**
- ✅ `Device.ReadWrite.All` satisfies `Device.Read` 
  - Operation: 2 >= 1 ✓
  - Constraint: 4 >= 0 ✓
- ❌ `Device.Read.All` does NOT satisfy `Device.ReadWrite` 
  - Operation: 1 < 2 ✗
  - Constraint: 4 >= 0 ✓

### Modified Function: `Test-ScopeAvailability`
**Location**: `functions\graphFunctions\Test-ScopeAvailability.ps1`

**Change**: Line 111 replaced literal comparison with hierarchical comparison:

**Before:**
```powershell
$isAvailable = $result.AvailableScopes -contains $scopeName
```

**After:**
```powershell
$isAvailable = Test-ScopeHierarchy -RequiredScope $scopeName -AvailableScopes $result.AvailableScopes
```

**Impact:** More accurate scope validation that understands privilege levels and eliminates false warnings.

## Testing

### Test Suite
**Location**: `TestScripts\test-scope-hierarchy.ps1`

Comprehensive validation covering:
1. **Operation Hierarchy (4 tests)**: ReadWrite satisfies Read, Manage satisfies ReadWrite
2. **Constraint Hierarchy (4 tests)**: .All satisfies narrower constraints, .OwnedBy constraints
3. **Combined Hierarchies (3 tests)**: Operation + Constraint combinations
4. **Exact Matches (2 tests)**: Identical scopes, case-insensitive matching
5. **Multiple Scopes (2 tests)**: Finding satisfying scope among multiple available
6. **Edge Cases (4 tests)**: Empty arrays, different resources, ReadBasic vs Read
7. **Real-World Scenarios (3 tests)**: Common application permission patterns

**Results**: 22/22 tests passing

### Sample Test Cases

```powershell
# Operation Hierarchy
Test-ScopeHierarchy -RequiredScope "Device.Read.All" -AvailableScopes @("Device.ReadWrite.All")
# Returns: $true (ReadWrite includes Read)

Test-ScopeHierarchy -RequiredScope "Device.ReadWrite.All" -AvailableScopes @("Device.Read.All")
# Returns: $false (Read does not include Write)

# Constraint Hierarchy
Test-ScopeHierarchy -RequiredScope "User.Read" -AvailableScopes @("User.Read.All")
# Returns: $true (.All includes self-scope)

Test-ScopeHierarchy -RequiredScope "User.Read.All" -AvailableScopes @("User.Read")
# Returns: $false (self-scope does not include .All)

# Combined
Test-ScopeHierarchy -RequiredScope "Device.Read.All" -AvailableScopes @("Device.ReadWrite.All")
# Returns: $true (higher operation + same constraint)

# Real-World
Test-ScopeHierarchy -RequiredScope "Device.Read.All" -AvailableScopes @("Device.ReadWrite.All", "User.Read.All", "Group.Read.All")
# Returns: $true (finds Device.ReadWrite.All among multiple scopes)
```

## Implementation Details

### Algorithm Flow

1. **Early Exit Checks**
   - Return `$false` if no available scopes
   - Return `$true` if exact case-insensitive match found

2. **Scope Parsing**
   - Split scope on `.` delimiter
   - Extract Resource (first part)
   - Extract Operation (second part)
   - Extract Constraint (remaining parts, or "None")

3. **Hierarchy Mapping**
   - Map operation to numeric level (0-3)
   - Map constraint to numeric level (0-4)
   - Unknown operations default to Read level (1)
   - Unknown constraints default to .All level (4)

4. **Comparison**
   - For each available scope:
     - Check resource match (case-insensitive)
     - Parse operation and constraint
     - If `availableOp >= requiredOp` AND `availableConstraint >= requiredConstraint`, return `$true`
   - If no scope satisfies, return `$false`

### Special Cases Handled

1. **Case Insensitivity**
   - `device.read.all` matches `Device.Read.All`
   - Resource comparison uses `-ine` operator

2. **ReadBasic Permissions**
   - Correctly treats `ReadBasic` (level 0) as less privileged than `Read` (level 1)
   - `User.Read.All` satisfies `User.ReadBasic.All` requirement
   - `User.ReadBasic.All` does NOT satisfy `User.Read.All` requirement

3. **Non-Standard Formats**
   - Falls back to exact match for scopes that don't follow standard pattern
   - Handles scopes with missing components gracefully

4. **Empty Arrays**
   - Properly returns `$false` when no scopes available
   - Uses `[AllowEmptyCollection()]` attribute on parameter

## User Impact

### Before Enhancement
```
Missing scopes for delegated authentication. Re-authentication will be required.
Missing required scope: Device.Read.All
```
*(User actually has Device.ReadWrite.All)*

### After Enhancement
```
All required Microsoft Graph API scopes are available.
Required scope satisfied: Device.Read.All
```
*(Correctly recognizes Device.ReadWrite.All satisfies the requirement)*

## Benefits

1. **Reduced False Positives**: Users with adequate permissions no longer see misleading warnings
2. **Better UX**: More accurate feedback about actual permission gaps
3. **Least Privilege Support**: Correctly identifies when broader permissions satisfy specific requirements
4. **Maintenance**: Single source of truth for permission hierarchy rules
5. **Extensibility**: Easy to add new operations or constraints to hierarchy tables

## Documentation References

### Microsoft Graph Permissions Overview
- **URL**: https://learn.microsoft.com/en-us/graph/permissions-reference
- **Key Insights**:
  - ReadWrite permissions include read, create, update, and delete operations
  - .All permissions grant access to all resources in the organization
  - .OwnedBy permissions grant access only to resources owned by the application
  - Permission names are case-insensitive

### Permission Naming Patterns
- `User.Read` vs `User.ReadWrite`: Operation hierarchy
- `User.Read` vs `User.Read.All`: Constraint hierarchy  
- `User.ReadBasic.All` vs `User.Read.All`: Property subset hierarchy
- `Application.ReadWrite.OwnedBy` vs `Application.ReadWrite.All`: Ownership hierarchy

## Future Enhancements

1. **Scope Recommendation Engine**: When scope is missing, suggest equivalent higher-privilege scopes user might already have
2. **Detailed Reporting**: Show which available scope satisfies each requirement
3. **Permission Optimization**: Suggest minimal set of scopes needed based on required functionality
4. **Custom Hierarchies**: Support organization-specific permission patterns
5. **Graph API Validation**: Query Microsoft Graph to validate scope relationships dynamically

## Related Files

- `functions/graphFunctions/Test-ScopeHierarchy.ps1` - New hierarchical comparison function
- `functions/graphFunctions/Test-ScopeAvailability.ps1` - Updated to use hierarchical comparison
- `TestScripts/test-scope-hierarchy.ps1` - Comprehensive test suite
- `main.ps1` (lines 857-900) - Scope validation workflow that consumes these functions

## Version History

- **v1.0** (Initial): Literal scope comparison with `-contains` operator
- **v2.0** (Current): Hierarchical scope comparison with `Test-ScopeHierarchy` function

---

**Author**: GitHub Copilot  
**Date**: January 2025  
**Issue**: Hierarchical scope validation enhancement  
**Test Coverage**: 22/22 tests passing
