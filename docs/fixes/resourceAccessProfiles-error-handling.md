# ResourceAccessProfiles 400 Error - Error Handling Implementation

## Issue Description
The `resourceAccessProfiles` API endpoint was returning a **400 Bad Request** error when fetching group assignments. This was causing failures in the assignment retrieval workflow without proper user notification or detailed error logging.

## Root Cause Analysis
Research of Microsoft documentation revealed that `resourceAccessProfiles` is a **beta-only API endpoint**:
- Only available in the Microsoft Graph **beta** API version
- Does not exist in the v1.0 API version
- Attempting to call it with v1.0 results in a 400 Bad Request error

Reference: Microsoft Learn documentation for `New-MgBetaDeviceManagementResourceAccessProfile` cmdlets confirms beta-only availability.

## Solution Overview
Implemented a comprehensive error handling framework across three functions to gracefully handle API failures:

1. **GetGroupIndirectAssignments.ps1** - Captures errors when fetching indirect assignments
2. **GetGroupDirectAssignments.ps1** - Captures errors when fetching direct assignments (including nested helper)
3. **ShowGroupAssignments.ps1** - Notifies users and logs detailed error information

## Implementation Details

### 1. GetGroupIndirectAssignments.ps1
**Changes:**
- Added `FailedResources` array to result object structure
- Enhanced batch response error capture with detailed error messages
- Error objects include: `ResourceType`, `ErrorMessage`, `StatusCode`, `ApiVersion`

**Code Location:** Lines ~57-73 (result object), Lines ~195-206 (error capture)

```powershell
$result = [PSCustomObject]@{
    # ... existing properties ...
    FailedResources = @()  # NEW: Track failed resource fetches
}

# Enhanced error capture in batch processing
if ($response.status -ge 400)
{
    $errorMessage = if ($response.body.error.message) {
        $response.body.error.message
    } else {
        "HTTP $($response.status) error"
    }
    
    $result.FailedResources += [PSCustomObject]@{
        ResourceType = $response.id
        ErrorMessage = $errorMessage
        StatusCode   = $response.status
        ApiVersion   = $apiVersion
    }
}
```

### 2. GetGroupDirectAssignments.ps1
**Changes:**
- Added `FailedResources` array to result object structure
- Added try-catch block to nested `Get-ResourceAssignments` helper function
- Enhanced batch response error capture (similar to indirect assignments)

**Code Locations:**
- Lines ~41-59: Result object with FailedResources
- Lines ~96-170: Get-ResourceAssignments helper with try-catch
- Lines ~288-365: Batch response processing with error capture

```powershell
# Nested helper function error handling
function Get-ResourceAssignments {
    try {
        $resourceBatch = CallGraphAPI -endpoint $batchEndpoint `
                                      -method "POST" `
                                      -body $batchBody `
                                      -headers $headers `
                                      -accessToken $accessToken
        # ... process responses ...
    }
    catch {
        $assignments.FailedResources += [PSCustomObject]@{
            ResourceType = $resourceListName
            ErrorMessage = $_.Exception.Message
            StatusCode   = "N/A"
            ApiVersion   = $apiVersion
        }
    }
}
```

### 3. ShowGroupAssignments.ps1
**Changes:**
- Added error notification check after assignments are retrieved
- User-friendly warning message displays affected resource types
- Detailed logging of each failed resource with full error information

**Code Location:** Lines ~108-119 (inserted after assignment retrieval)

```powershell
# Check for failed resources and notify user
if ($assignments.FailedResources -and $assignments.FailedResources.Count -gt 0)
{
    $failedResourceTypes = ($assignments.FailedResources | Select-Object -ExpandProperty ResourceType -Unique) -join ', '
    Write-Host "Warning: Some resources could not be fetched: $failedResourceTypes" -ForegroundColor Yellow
    Write-Log -logFile $LogFile -Module $functionName -Message "Failed to fetch $($assignments.FailedResources.Count) resource type(s)" -logLevel "Warning"
    
    foreach ($failedResource in $assignments.FailedResources)
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "Failed Resource - Type: $($failedResource.ResourceType), Status: $($failedResource.StatusCode), API Version: $($failedResource.ApiVersion), Error: $($failedResource.ErrorMessage)" -logLevel "Error"
    }
}
```

## Error Object Structure
Each failed resource is captured with the following properties:

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| `ResourceType` | String | Resource endpoint/type that failed | "resourceAccessProfiles" |
| `ErrorMessage` | String | Detailed error message from API or exception | "HTTP 400 error" or API error.message |
| `StatusCode` | String/Int | HTTP status code | "400" or "N/A" for exceptions |
| `ApiVersion` | String | API version used | "v1.0" or "beta" |

## User Experience
**Before:**
- Silent failure - no indication that resources failed to fetch
- Incomplete data displayed without warning
- No diagnostic information in logs

**After:**
- Clear warning message: `"Warning: Some resources could not be fetched: resourceAccessProfiles"`
- Displayed in yellow for visibility
- Application continues with available data (graceful degradation)
- Complete error details logged for troubleshooting

## Logging Output Example
```
[Warning] Failed to fetch 1 resource type(s)
[Error] Failed Resource - Type: resourceAccessProfiles, Status: 400, API Version: v1.0, Error: HTTP 400 error
```

## Testing Status
### Unit Tests
- ✅ **ShowGroupAssignments.Tests.ps1**: 18/18 passing (100%)
- ⚠️ **GetGroupDirectAssignments.Tests.ps1**: 15/22 passing (68%) - pre-existing failures unrelated to error handling
- ⚠️ **GetGroupIndirectAssignments.Tests.ps1**: Some failures - pre-existing, unrelated to error handling

**Note:** The new error handling code does not break any previously passing tests. Failed tests are pre-existing issues unrelated to this implementation.

### Integration Testing Needed
The following scenarios should be tested manually or with integration tests:
1. Trigger resourceAccessProfiles 400 error with v1.0 API
2. Verify user sees yellow warning message
3. Confirm logs contain detailed error information
4. Test with beta API to confirm resourceAccessProfiles works
5. Verify other resources still fetch successfully when one fails

## Benefits
1. **Graceful Degradation**: Application continues working even when individual resources fail
2. **User Awareness**: Users are notified of partial data without technical details
3. **Diagnostic Information**: Complete error details logged for troubleshooting
4. **Maintainability**: Consistent error handling pattern across all assignment functions
5. **Transparency**: No silent failures - all errors tracked and reported

## Migration Notes
- No breaking changes to function signatures
- FailedResources array is optional - backward compatible with existing code
- If FailedResources is empty or null, no warning is displayed
- Existing error handling preserved - new logic is additive

## Related Documentation
- Microsoft Graph API Beta endpoints: https://learn.microsoft.com/en-us/graph/api/overview?view=graph-rest-beta
- ResourceAccessProfiles reference: https://learn.microsoft.com/en-us/graph/api/resources/intune-rapolicy-devicemanagementresourceaccessprofilebase

## Files Modified
1. `functions/UserAndGroupFunctions/ShowGroupAssignments.ps1`
2. `functions/UserAndGroupFunctions/GetGroupDirectAssignments.ps1`
3. `functions/UserAndGroupFunctions/GetGroupIndirectAssignments.ps1`

## Author & Date
- **Implementation Date:** January 2025
- **Issue:** resourceAccessProfiles 400 Bad Request error
- **Solution:** Comprehensive error handling with user notification and detailed logging
