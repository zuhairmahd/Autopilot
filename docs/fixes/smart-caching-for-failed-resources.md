# Smart Caching Implementation for Failed Resources

## Problem Statement
User reported that error warnings for failed resources (e.g., `resourceAccessProfiles`) appeared only on the first run of the application. Subsequent runs did not show warnings even though the resources continued to fail, because both successful and failed resources were being cached together.

**User Quote:**
> "I do see the yellow warning about the failing resource when I run the application for the first time. Subsequent runs, however, do not include the warning, and I suspect that this is happening because the resources are being pulled from cache"

## Root Cause
The caching system (`Get-CachedData` / `Set-CachedData`) was storing both successful and failed resource fetches in the cache. On subsequent runs:
1. Cache hit would return all cached data
2. Failed resources would appear as empty arrays `@()`
3. No retry would be attempted
4. Error tracking logic wouldn't trigger
5. Users wouldn't see warnings

## Solution Design
**User's Suggestion:**
> "My thought is that if an error is detected that particular should not be cached but rather should be pulled from the API. Only valid resources should go to the cache."

**Implementation Strategy:**
- **Cache successful resources** normally
- **Mark failed resources as `$null`** in the cache (not empty array)
- **Store failed resource IDs** in cache metadata for debugging
- **On cache hit**, identify resources marked as `$null` and retry them
- **Continue tracking errors** for resources that still fail after retry

This approach ensures:
- ✅ Successful resources remain cached (performance optimization)
- ✅ Failed resources are retried on every run (visibility)
- ✅ Users consistently see warnings for failing resources
- ✅ Cache metadata provides debugging visibility

## Implementation Details

### Files Modified
1. **`GetGroupIndirectAssignments.ps1`** - Fully implemented
2. **`Get-GroupDirectAssignments.ps1`** - Fully implemented

Both files follow the same pattern with 4 key changes each.

### Change Pattern (4 Steps per File)

#### Step 1: Initialize Failed Resource Tracking Array
**Location:** After resource variable initialization (before batch request)

```powershell
# Track failed resource IDs to exclude from cache
$failedResourceIds = @()
```

#### Step 2: Track Failed Resources During Batch Processing
**Location:** In batch response error handling (within batch foreach loop)

```powershell
# Track failed resource for retry on next run
$failedResourceIds += $response.id

# Add to FailedResources collection
Add-FailedResourceError -FailedResources $FailedResources `
    -ResourceType $response.id `
    -ErrorMessage $errorMsg `
    -StatusCode $response.status `
    -ApiVersion $apiVersionKey
```

#### Step 3: Exclude Failed Resources from Cache
**Location:** Before `Set-CachedData` call (in cache-miss branch)

```powershell
# Exclude failed resources from cache by setting them to $null
# They will be retried on the next run
foreach ($failedId in $failedResourceIds)
{
    $resourceListsToCache[$failedId] = $null
    Write-Log -logFile $LogFile -module $functionName `
        -Message "Excluding failed resource '$failedId' from cache (will retry next time)" `
        -logLevel "Verbose"
}

# Calculate counts
$successCount = ($resourceListsToCache.Keys | Where-Object { $null -ne $resourceListsToCache[$_] }).Count
$failedCount = $failedResourceIds.Count

# Cache the resource lists with metadata including failed resources
$cacheMetadata = @{
    ApiVersion = $apiVersionKey
    FetchedAt = (Get-Date).ToString("o")
    Type = "ResourceLists"
    FailedResources = $failedResourceIds
}

Set-CachedData -CacheKey $cacheKey -CacheType Configuration `
    -Data $resourceListsToCache -Metadata $cacheMetadata

Write-Log -logFile $LogFile -module $functionName `
    -Message "Cached $successCount resource lists (excluded $failedCount failed)" `
    -logLevel "Verbose"
```

#### Step 4: Retry Failed Resources on Cache Hit
**Location:** After cache extraction (in cache-hit branch)

```powershell
# Check for resources marked as $null (previously failed) and retry them
$resourcesToRetry = @()
$resourceRetryMap = @{
    'mobileApps' = @{
        endpoint = "deviceAppManagement/mobileApps?`$filter=isAssigned eq true&`$select=id,displayName,description"
        variable = 'mobileApps'
    }
    # ... (all other resource types)
}

foreach ($resourceId in $resourceRetryMap.Keys)
{
    if ($null -eq $cachedResourceLists[$resourceId])
    {
        $resourcesToRetry += $resourceId
    }
}

if ($resourcesToRetry.Count -gt 0)
{
    Write-Log -logFile $LogFile -module $functionName `
        -Message "Retrying $($resourcesToRetry.Count) previously failed resources" `
        -logLevel "Info"

    # Build batch request for retry
    $retryBatchBody = @{ requests = @() }
    foreach ($resourceId in $resourcesToRetry)
    {
        $retryBatchBody.requests += @{
            id     = $resourceId
            method = "GET"
            url    = $resourceRetryMap[$resourceId].endpoint
        }
    }

    # Send retry batch request
    $retryBatchResponse = CallGraphAPI -AccessToken $AccessToken `
        -Uri 'https://graph.microsoft.com/beta/$batch' `
        -Method "POST" -Body $retryBatchBody -LogFile $LogFile

    if ($retryBatchResponse -and $retryBatchResponse.responses)
    {
        foreach ($response in $retryBatchResponse.responses)
        {
            if ($response.status -eq 200 -and $response.body.value)
            {
                # Retry successful - update the variable
                $varName = $resourceRetryMap[$response.id].variable
                Set-Variable -Name $varName -Value $response.body.value -Scope Local
                Write-Log -logFile $LogFile -module $functionName `
                    -Message "Retry successful for '$($response.id)' - retrieved $($response.body.value.Count) items" `
                    -logLevel "Verbose"
            }
            else
            {
                # Retry failed - track error again
                $failedResourceIds += $response.id
                $errorMsg = if ($response.body.error.message) {
                    $response.body.error.message
                } else {
                    "Unknown error (Status: $($response.status))"
                }
                Add-FailedResourceError -FailedResources $FailedResources `
                    -ResourceType $response.id `
                    -ErrorMessage $errorMsg `
                    -StatusCode $response.status `
                    -ApiVersion $apiVersionKey
                Write-Log -logFile $LogFile -module $functionName `
                    -Message "Retry failed for '$($response.id)': $errorMsg" `
                    -logLevel "Warning"
            }
        }
    }
}
```

## Cache Structure

### Cache Key
```powershell
# Indirect assignments
$cacheKey = "IndirectResourceLists_${apiVersionKey}"

# Direct assignments
$cacheKey = "ResourceLists_${apiVersionKey}"
```

### Cache Data
```powershell
@{
    mobileApps = @([...])              # Success: array of resources
    deviceConfigs = @([...])           # Success: array of resources
    resourceAccessProfiles = $null     # Failed: marked as $null for retry
    compliancePolicies = @([...])      # Success: array of resources
    # ... other resource types
}
```

### Cache Metadata
```powershell
@{
    ApiVersion = "beta"
    FetchedAt = "2025-10-15T14:30:00Z"
    Type = "ResourceLists"
    FailedResources = @('resourceAccessProfiles')  # IDs of failed resources
}
```

## Testing Recommendations

### Test Scenario 1: First Run with Failed Resource
1. **Setup:** Ensure `resourceAccessProfiles` endpoint will fail (or use actual failing resource)
2. **Action:** Run application with a group that has assignments
3. **Expected:**
   - Yellow warning displays: "Warning: Failed to retrieve some resources"
   - Log shows: "Failed to retrieve 'resourceAccessProfiles': [error message]"
   - Log shows: "Excluding failed resource 'resourceAccessProfiles' from cache"
   - `$global:as.FailedResources` contains error object
   - Cache contains `resourceAccessProfiles = $null`

### Test Scenario 2: Second Run with Cached Data
1. **Setup:** Run immediately after Test Scenario 1
2. **Action:** Run application again with same group
3. **Expected:**
   - Log shows: "Using cached resource lists (API: beta)"
   - Log shows: "Retrying 1 previously failed resources"
   - Yellow warning displays again (resource still fails)
   - `$global:as.FailedResources` contains error object
   - Cache remains unchanged (resourceAccessProfiles still $null)

### Test Scenario 3: Resource Recovery
1. **Setup:** Fix the failing resource endpoint (or mock recovery)
2. **Action:** Run application with same group
3. **Expected:**
   - Log shows: "Retrying 1 previously failed resources"
   - Log shows: "Retry successful for 'resourceAccessProfiles' - retrieved X items"
   - No yellow warning displays (all resources succeeded)
   - `$global:as.FailedResources` is empty
   - Next run will cache resourceAccessProfiles successfully

### Validation Commands
```powershell
# Check FailedResources collection
$global:as.FailedResources | Format-Table

# Check log for retry messages
Get-Content Logs\Autopilot.log | Select-String "Retrying"
Get-Content Logs\Autopilot.log | Select-String "Excluding failed resource"

# Inspect cache manually (requires cache inspection function)
Get-CachedData -CacheKey "ResourceLists_beta" -CacheType Configuration
```

## Benefits
1. **User Visibility**: Error warnings appear consistently across runs
2. **Performance**: Successful resources remain cached (not re-fetched)
3. **Self-Healing**: Resources automatically recover when API issues resolve
4. **Debugging**: Cache metadata shows which resources failed and when
5. **Minimal Overhead**: Only failed resources trigger additional API calls

## Related Changes
- **Previous Session:** Implemented error tracking in `Get-ResourceAssignments`, `Add-FailedResourceError`, and display logic in `Show-GroupAssignments.ps1`
- **This Session:** Extended error tracking to resource list caching layer

## Files Validation
- ✅ `GetGroupIndirectAssignments.ps1` - Syntax validated
- ✅ `Get-GroupDirectAssignments.ps1` - Syntax validated
- ✅ Both files follow identical 4-step pattern
- ✅ All 8 changes applied successfully (4 per file)

## Next Steps
1. **Test with real data** using the scenarios above
2. **Monitor logs** for "Retrying" and "Excluding" messages
3. **Verify user experience** - warnings appear on all runs for failing resources
4. **Consider applying pattern** to other caching scenarios if similar issues arise
