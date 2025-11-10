# Configuration Assignment Export Error Analysis
**Date**: November 9, 2025  
**Error File**: ConfigurationAssignments-20251109-221754-error.csv  
**Total Errors**: 238 lines (330+ NULL response failures)

## Executive Summary
All 330+ assignment API calls returned NULL responses due to **incorrect endpoint mapping**. Resources are being queried against wrong base URIs, causing Graph API to return NULL instead of assignment data.

## Error Pattern Analysis

### Primary Error Pattern
- **ErrorType**: ASSIGNMENT_CHECK_FAILED (100% of errors)
- **StatusCode**: NULL (all instances)
- **ErrorMessage**: "No response returned from API" (all instances)
- **Root Cause**: Endpoint mismatches between resource type and query endpoint

### Endpoint Mismatch Examples

| Resource ODataType | Actual Endpoint Used (WRONG) | Correct Endpoint |
|-------------------|------------------------------|------------------|
| `#microsoft.graph.androidManagedStoreApp` | `deviceManagement/windowsQualityUpdateProfiles/{id}/assignments` | `deviceAppManagement/mobileApps/{id}/assignments` |
| `#microsoft.graph.iosVppApp` | `deviceManagement/windowsQualityUpdateProfiles/{id}/assignments` | `deviceAppManagement/mobileApps/{id}/assignments` |
| `#microsoft.graph.win32LobApp` | `deviceManagement/windowsQualityUpdateProfiles/{id}/assignments` | `deviceAppManagement/mobileApps/{id}/assignments` |
| `#microsoft.graph.androidWorkProfileCompliancePolicy` | `deviceManagement/groupPolicyConfigurations/{id}/assignments` | `deviceManagement/deviceCompliancePolicies/{id}/assignments` |
| `#microsoft.graph.windows10CompliancePolicy` | `deviceManagement/groupPolicyConfigurations/{id}/assignments` | `deviceManagement/deviceCompliancePolicies/{id}/assignments` |
| `#microsoft.graph.windowsInformationProtectionPolicy` | `deviceAppManagement/windowsInformationProtectionPolicies/{id}/assignments` | `deviceAppManagement/windowsInformationProtectionPolicies/{id}/assignments` *(correct)* |
| `#microsoft.graph.androidManagedAppProtection` | `deviceManagement/windowsDriverUpdateProfiles/{id}/assignments` | `deviceAppManagement/managedAppPolicies/{id}/assignments` |

### Error Distribution by Category (from CSV)
- **WindowsQualityUpdate** (wrong): 200+ errors - majority are apps misclassified
- **Application**: 20+ errors - some legitimate apps also showing wrong endpoints
- **WindowsDriverUpdate**: 5 errors - managed app protections misclassified
- **Configuration**: Multiple errors - configs using wrong update profile endpoints

## Technical Investigation

### Code Analysis
**File**: `functions/UserAndGroupFunctions/Export-ConfigurationAssignments.ps1`

**Lines 132-156**: Resource collection loop
```powershell
for ($i = 0; $i < $resourceResults.value.Count; $i++)
{
    $endpointInfo = $resourceEndpoints[$i]
    $resources = $resourceResults.value[$i].value
    
    foreach ($resource in $resources)
    {
        $resourceType = $endpointInfo.id
        $category = Get-ResourceCategory -Resource $resource -EndpointId $resourceType
        
        $allResources += [PSCustomObject]@{
            BaseUri = $endpointInfo.url   # <--- THIS LINE ASSIGNS BASE URI
            Category = $category            # <--- Category from Get-ResourceCategory
            ...
        }
    }
}
```

**Issue Identified**: The loop correctly assigns `BaseUri = $endpointInfo.url`, BUT the error CSV shows resources with **incorrect BaseUri values**. This suggests either:
1. Data corruption during batch API processing
2. Index misalignment between `$resourceEndpoints[$i]` and `$resourceResults.value[$i]`
3. Batch API returning responses out of order

### Batch API Response Structure
Batch API should return responses in same order as requests, but error CSV shows systematic misalignment suggesting responses are shifted or merged incorrectly.

## Correlation with Autopilot.log
**Log File**: `logs/Autopilot.log`  
**Relevant Timeframe**: 2025-11-09 22:17:00 - 22:18:00

Log shows normal initialization but no specific Graph API errors logged during the problematic export run. This suggests:
- Batch API silently returned NULL responses
- Error detection logic caught NULLs but didn't log detailed Graph API failures
- No network-level errors occurred (would show in logs)

## Microsoft Graph API Documentation Review
Researched parameters: `$expand`, `$select`, `consistencyLevel`

**Findings**:
- **DO NOT** add `$expand` to `/assignments` calls - assignments already returns full collection
- `$select` can reduce payload but NOT required and won't fix NULL responses
- `consistencyLevel` only needed for `$count` or advanced `$filter` - NOT relevant here

**Conclusion**: Missing parameters are NOT the root cause. Endpoint mapping is the issue.

## Proposed Solutions

### 1. Primary Fix: Add BaseUri Validation and Correction
**Priority**: CRITICAL  
**Location**: Export-ConfigurationAssignments.ps1, lines 140-156

Add validation to ensure `BaseUri` matches resource `@odata.type`:

```powershell
# After assigning BaseUri, validate it matches resource type
$correctBaseUri = Get-CorrectBaseUriForResource -Resource $resource -ODataType $resource.'@odata.type'
if ($correctBaseUri -and $correctBaseUri -ne $endpointInfo.url) {
    Write-Log "WARNING: BaseUri mismatch for $($resource.displayName). Expected: $correctBaseUri, Got: $($endpointInfo.url)"
    $actualBaseUri = $correctBaseUri  # Use corrected value
} else {
    $actualBaseUri = $endpointInfo.url
}
```

### 2. Secondary Fix: Pre-Validation Using GetGraphObjectMetadata
**Priority**: HIGH  
**Location**: Export-ConfigurationAssignments.ps1, before assignment queries

Add function to validate resources support `/assignments` endpoint:

```powershell
function Test-ResourceSupportsAssignments {
    # Check known supported types first (fast path)
    # Fall back to GetGraphObjectMetadata for unknown types
    # Return boolean
}
```

Filter resources before building assignment paths:
```powershell
$validatedResources = $allResources | Where-Object { 
    Test-ResourceSupportsAssignments -Resource $_ -AccessToken $AccessToken 
}
```

### 3. Tertiary Fix: Enhanced Error Categorization
**Priority**: MEDIUM  
**Location**: Export-ConfigurationAssignments.ps1, lines 270-303

Add detailed error categories:
- `ENDPOINT_NOT_SUPPORTED` - Resource type doesn't support assignments
- `RESOURCE_NOT_FOUND` - Resource deleted or ID incorrect  
- `PERMISSION_DENIED` - Insufficient Graph API permissions
- `NETWORK_TIMEOUT` - Request timeout
- `ENDPOINT_MISMATCH` - Wrong BaseUri used (new)

Add correlation tracking:
- `CorrelationId` - GUID per request
- `RequestDurationMs` - Timing metrics
- `Recommendation` - Actionable guidance per error type

## Implementation Plan

### Phase 1: Immediate Fixes (Today)
1. ✅ Analyze error patterns - COMPLETED
2. ✅ Review code logic - COMPLETED
3. ✅ Research Graph API docs - COMPLETED
4. ⏳ Create Get-CorrectBaseUriForResource helper function
5. ⏳ Add BaseUri validation and correction logic
6. ⏳ Implement Test-ResourceSupportsAssignments with metadata validation
7. ⏳ Add pre-validation filter before assignment queries

### Phase 2: Enhanced Error Handling (Today)
1. ⏳ Extend error categorization with specific error types
2. ⏳ Add CorrelationId and timing metrics
3. ⏳ Add Recommendation field to error log
4. ⏳ Update error CSV export with new columns

### Phase 3: Testing & Validation (Today)
1. ⏳ Test with sample resources
2. ⏳ Verify endpoint corrections eliminate NULL responses
3. ⏳ Confirm pre-validation catches unsupported types
4. ⏳ Review error log for improved diagnostics
5. ⏳ Validate backwards compatibility

## Expected Outcomes
- **Primary**: Eliminate 330+ NULL response errors by fixing endpoint mapping
- **Secondary**: Prevent future errors via pre-validation of resource support
- **Tertiary**: Improve error diagnostics for faster troubleshooting

## Files to Modify
1. `functions/UserAndGroupFunctions/Export-ConfigurationAssignments.ps1` - Primary changes
2. `functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1` - Add helper functions (optional)
3. Error CSV export logic - Add new columns

## Testing Checklist
- [ ] Run export with `-IncludeBeta` flag
- [ ] Verify apps use `deviceAppManagement/mobileApps` endpoint
- [ ] Verify compliance uses `deviceManagement/deviceCompliancePolicies` endpoint
- [ ] Confirm unsupported resource types are skipped with proper logging
- [ ] Check error CSV has enhanced fields (CorrelationId, ErrorCategory, Recommendation)
- [ ] Validate timing metrics are captured
- [ ] Test backwards compatibility with existing error processing

## References
- Microsoft Graph API Docs: https://learn.microsoft.com/en-us/graph/api/intune-shared-devicemanagement-list-mobileapps
- Error CSV: ConfigurationAssignments-20251109-221754-error.csv
- Implementation: Export-ConfigurationAssignments.ps1
- Metadata Helper: GetGraphObjectMetadata.ps1
- Log File: logs/Autopilot.log
