# GroupAssignments Refactoring - Error Handling Fix

## Problem Statement
The `FailedResources` error tracking was not working properly because:
1. Nested helper functions (`Get-IndirectResourceAssignments` and `Get-ResourceAssignments`) were trying to access parent function variables directly
2. PowerShell nested functions don't automatically have write access to parent scope variables when using `+=` operator on arrays
3. Error objects were being created locally but not propagating back to the parent function's result object

## Root Cause
When you use `$parentVariable.Property += $value` inside a nested function in PowerShell, it creates a **local copy** of the parent variable rather than modifying the original. This is due to PowerShell's scoping rules.

## Solution: Refactoring with Common Module

### 1. Created Get-GroupAssignments-Common.ps1
New common module file containing shared functions:
- **Initialize-AssignmentResultObject**: Creates standardized result object structure
- **Get-ResourceListEndpoints**: Defines standard API endpoints (v1.0 + beta)
- **Add-FailedResourceError**: Standardized error object creation and tracking
- **Apply-PlatformFilter**: Platform-based resource filtering (uses Test-ResourcePlatformMatch)
- **New-AssignmentObject**: Creates standardized assignment objects
- **Add-AssignmentToCategory**: Routes assignments to correct category arrays

### 2. Updated Get-IndirectResourceAssignments.ps1
**Key Changes:**
- Added `ResultObject`, `AccessToken`, and `ApiVersion` as required parameters
- Removed dependency on parent function variables (`$indirectAssignments`, `$AccessToken`, `$apiVersion`)
- Changed from inline PSCustomObject creation to `New-AssignmentObject` function
- Changed from switch statement to `Add-AssignmentToCategory` function
- Added try-catch around `CallGraphAPI` with proper error tracking using `Add-FailedResourceError`

**Before:**
```powershell
function Get-IndirectResourceAssignments()
{
    param(
        [array]$Resources,
        [string]$ResourceType,
        [string]$BaseUri,
        [string]$AssignmentCategory
    )
    # ... code that accessed $indirectAssignments, $AccessToken, $apiVersion from parent scope
    $indirectAssignments.AppAssignments += $assignmentObject  # Didn't work!
}
```

**After:**
```powershell
function Get-IndirectResourceAssignments()
{
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ResultObject,  # Pass by reference!
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,           # Explicit parameter
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,            # Explicit parameter
        [array]$Resources,
        [string]$ResourceType,
        [string]$BaseUri,
        [string]$AssignmentCategory
    )
    # ... code that uses $ResultObject explicitly
    Add-AssignmentToCategory -ResultObject $ResultObject -Assignment $assignmentObject -AssignmentCategory $AssignmentCategory  # Works!
}
```

### 3. Updated GetGroupIndirectAssignments.ps1
**Key Changes:**
- Changed to use `Initialize-AssignmentResultObject` instead of inline PSCustomObject
- Updated all `Get-IndirectResourceAssignments` calls to pass `-ResultObject $indirectAssignments -AccessToken $AccessToken -ApiVersion $apiVersion`
- Changed error tracking from inline PSCustomObject to `Add-FailedResourceError` function

**Example Call:**
```powershell
Get-IndirectResourceAssignments -ResultObject $indirectAssignments `
                                -AccessToken $AccessToken `
                                -ApiVersion $apiVersion `
                                -Resources $mobileApps `
                                -ResourceType "Mobile Apps" `
                                -BaseUri "deviceAppManagement/mobileApps" `
                                -AssignmentCategory "Application"
```

### 4. Updated Get-GroupDirectAssignments.ps1
**Key Changes:**
- Changed to use `Initialize-AssignmentResultObject -GroupName ... -GroupId ...`
- Updated nested `Get-ResourceAssignments` function to accept `ResultObject` and `GroupIdValue` parameters
- Changed from inline PSCustomObject creation to `New-AssignmentObject` function
- Changed from switch statement to `Add-AssignmentToCategory` function
- Updated all `Get-ResourceAssignments` calls to pass `-ResultObject $assignments -GroupIdValue $groupIdValue`
- Changed error tracking to use `Add-FailedResourceError` function

**Example Call:**
```powershell
Get-ResourceAssignments -ResultObject $assignments `
                        -GroupIdValue $groupIdValue `
                        -Resources $mobileApps `
                        -ResourceType "Mobile Apps" `
                        -BaseUri "deviceAppManagement/mobileApps" `
                        -AssignmentCategory "Application"
```

## Technical Benefits

### 1. Explicit Parameter Passing
- **Before**: Relied on parent scope variable access (fragile, implicit dependencies)
- **After**: Explicit parameters make dependencies clear and testable

### 2. Pass-by-Reference Pattern
- PowerShell PSCustomObjects are reference types
- Passing `$ResultObject` as a parameter allows nested functions to modify the original object
- Changes made inside nested functions are visible to the caller

### 3. Code Reusability
- Common functions reduce duplication between Get-GroupDirectAssignments and GetGroupIndirectAssignments
- `Test-ResourcePlatformMatch` already existed as a separate function (good pattern to follow)
- Consistent error handling across all assignment functions

### 4. Maintainability
- Single source of truth for assignment object structure
- Changes to error tracking only need to happen in one place (`Add-FailedResourceError`)
- Easier to add new assignment categories (update `Add-AssignmentToCategory` once)

### 5. Testability
- Helper functions can now be tested independently
- Clear input/output contracts with explicit parameters
- No hidden dependencies on parent scope variables

## PowerShell Scoping Lesson Learned

**The Problem:**
```powershell
function Parent {
    $result = [PSCustomObject]@{ Items = @() }

    function Nested {
        $result.Items += "Item1"  # Creates LOCAL copy of $result!
    }

    Nested
    Write-Host $result.Items.Count  # Still 0! 😱
}
```

**The Solution:**
```powershell
function Parent {
    $result = [PSCustomObject]@{ Items = @() }

    function Nested {
        param([PSCustomObject]$ResultObject)  # Explicit parameter
        $ResultObject.Items += "Item1"  # Modifies the passed reference
    }

    Nested -ResultObject $result
    Write-Host $result.Items.Count  # Now 1! ✅
}
```

## Testing Validation

### Unit Tests Status
- **Show-GroupAssignments.Tests.ps1**: 18/18 passing ✅
- **Get-GroupDirectAssignments.Tests.ps1**: Some pre-existing failures (unrelated to refactoring)
- **GetGroupIndirectAssignments.Tests.ps1**: Some pre-existing failures (unrelated to refactoring)

### Integration Testing Needed
1. Run application with a group that has assignments
2. Trigger a 400 error (e.g., call resourceAccessProfiles with v1.0 API)
3. Verify `$global:as.FailedResources` contains error objects
4. Verify Show-GroupAssignments displays yellow warning message
5. Check logs for detailed error information

## Files Modified
1. **Created**: `functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1` (NEW)
2. **Modified**: `functions/UserAndGroupFunctions/Get-IndirectResourceAssignments.ps1`
3. **Modified**: `functions/UserAndGroupFunctions/GetGroupIndirectAssignments.ps1`
4. **Modified**: `functions/UserAndGroupFunctions/Get-GroupDirectAssignments.ps1`
5. **Modified**: `functions/UserAndGroupFunctions/Show-GroupAssignments.ps1` (from previous iteration)

## Migration Path for Other Functions
This pattern can be applied to other nested functions in the codebase:

1. Identify nested functions that modify parent scope variables
2. Add explicit parameters for parent variables (pass by reference)
3. Update all call sites to pass the required parameters
4. Consider extracting to common module if used in multiple places

## Documentation References
- PowerShell Scoping: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes
- Pass by Reference: PowerShell objects (PSCustomObject, hashtables, arrays) are reference types
- Test-ResourcePlatformMatch: `functions/UserAndGroupFunctions/Test-ResourcePlatformMatch.ps1`
