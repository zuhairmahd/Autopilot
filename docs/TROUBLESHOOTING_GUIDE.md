# Intune Configuration Assignment Export - Troubleshooting Guide

## Quick Reference

### Common Issues and Solutions

| Issue | Category | Solution |
|-------|----------|----------|
| PolicySet assignments missing | Known Limitation | See [PolicySet Workaround](#policyset-assignments-not-available) |
| App protection errors | Resolved | Update to latest version (alternative endpoints implemented) |
| NULL response errors | Fixed | Batch ID collision resolved in v2.0+ |
| Slow export performance | Expected | Batch processing optimized, 240 resources ~10-15s |

---

## Issue #1: PolicySet Assignments Not Available

### Symptoms
- PolicySet resources show "Known API Limitation" in Classification column
- Assignment count shows as -1 or N/A
- ErrorCategory shows "API_DESIGN_LIMITATION"

### Root Cause
Microsoft Graph API's OData routing doesn't support GET operations on `/deviceAppManagement/policySets/{id}/assignments` despite the endpoint existing in metadata.

### Solution Options

**Option 1: Manual Portal Lookup** (Recommended)
1. Open [Microsoft Endpoint Manager Admin Center](https://endpoint.microsoft.com)
2. Navigate to: **Apps** → **Policy Sets**
3. Select the policy set by name
4. Click the **Assignments** tab
5. View groups and inclusion/exclusion rules

**Option 2: PowerShell SDK**
```powershell
# Install module if needed
Install-Module Microsoft.Graph.DeviceManagement.Actions -Scope CurrentUser

# Connect
Connect-MgGraph -Scopes "DeviceManagementApps.Read.All"

# Get PolicySet assignments
$policySets = Get-MgBetaDeviceAppManagementPolicySet
foreach ($ps in $policySets) {
    $assignments = Get-MgBetaDeviceAppManagementPolicySetAssignment -PolicySetId $ps.Id
    Write-Host "$($ps.DisplayName): $($assignments.Count) assignments"
}
```

**Option 3: Accept Limitation**
- PolicySets are rare (typically 0-2 per tenant)
- Assignment data not critical for most use cases
- Document as known limitation in reports

### Expected Behavior
```csv
ResourceName,Classification,ErrorCategory,KnownLimitation
"Cloud-Managed PC Policy Set","Known API Limitation",API_DESIGN_LIMITATION,TRUE
```

---

## Issue #2: App Protection Policy Assignment Errors (RESOLVED)

### Symptoms (Pre-v2.0)
- Errors like "Resource not found for the segment 'assignments'"
- Affects androidManagedAppProtection, iosManagedAppProtection, targetedManagedAppConfiguration
- ErrorCode: BadRequest

### Root Cause
App protection policies require resource-type-SPECIFIC endpoints:
- ❌ `/deviceAppManagement/managedAppPolicies/{id}/assignments` (doesn't work)
- ✅ `/deviceAppManagement/iosManagedAppProtections/{id}/assignments` (works)

### Solution
**Update to latest version** - Alternative endpoints automatically implemented

**Verification**:
```powershell
# Check version includes alternative endpoint support
Get-Content .\functions\UserAndGroupFunctions\Export-ConfigurationAssignments.ps1 | Select-String "Get-AppProtectionPolicyAssignments"

# Should return the helper function definition
```

**Post-Update Behavior**:
- App protection policies retrieved using correct endpoints
- No errors logged
- Full assignment data available
- Success rate: 100%

---

## Issue #3: NULL Response Errors (RESOLVED)

### Symptoms (Pre-v1.5)
- Large number of NULL errors (200-300+)
- Error message: "No response returned from API"
- Assignments appear missing despite resources existing

### Root Cause
Batch ID collision - CallGraphAPI returns responses with IDs 1-20 per batch, but script expected globally unique IDs 1-240.

### Solution
**Fixed in v1.5+** - Global ID renumbering implemented

**Verification**:
```powershell
# Check for batch ID fix
Get-Content .\functions\graphFunctions\CallGraphAPI.ps1 | Select-String "globalIdOffset"

# Should return lines showing: $globalIdOffset = $batchIndex * $maxBatchSize
```

**Expected Behavior**:
- All 240 resources have unique response IDs
- No NULL errors from batch collision
- Proper error messages for legitimate failures

---

## Issue #4: Export Taking Too Long

### Symptoms
- Export runs for several minutes
- Console shows "waiting" or appears frozen

### Expected Performance
- **Standard Resources (234)**: 5-10 seconds (batch processing)
- **App Protection (6)**: 3-6 seconds (individual calls)
- **Total Time**: 10-15 seconds for 240 resources

### Performance Breakdown
```
Resource Fetch (12 batches):        ~3-5s
Standard Assignment Batch (240):     ~5-7s
App Protection Individual (6):       ~3-6s
Processing & Export:                 ~2-3s
--------------------------------------------
Total Expected:                      ~13-21s
```

### Troubleshooting Slow Performance

**Check Network Latency**:
```powershell
Measure-Command {
    Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers @{Authorization = "Bearer $token"}
}
# Should complete in < 1 second
```

**Check Token Validity**:
```powershell
# Expired tokens cause auth delays
$cred = Get-StoredCredential -Target 'AutopilotGraphAPI'
$token = $cred.GetNetworkCredential().Password

# Decode token (check expiry)
# Token should be valid for at least 5 minutes
```

**Enable Verbose Logging**:
```powershell
$result = Export-ConfigurationAssignments -AccessToken $token -OutputPath "./logs" `
    -IncludeBeta -CreateErrorExportFile -Verbose

# Check log file for slow operations
Get-Content ./logs/Autopilot.log -Tail 100
```

**Common Bottlenecks**:
1. **First Run**: Slower due to metadata caching (adds ~5-10s)
2. **Many App Protection Policies**: Each requires individual call (~0.5s each)
3. **Network Throttling**: ISP or corporate proxy rate limiting
4. **Graph API Throttling**: Rare but possible under heavy load

---

## Issue #5: Permission Denied Errors

### Symptoms
- Errors with status code 403 or "Forbidden"
- ErrorCategory: PERMISSION_DENIED
- Some resources work, others don't

### Root Cause
Insufficient API permissions for Graph API app registration

### Required Permissions
**Microsoft Graph API**:
- `DeviceManagementApps.Read.All`
- `DeviceManagementConfiguration.Read.All`
- `DeviceManagementManagedDevices.Read.All`
- `DeviceManagementServiceConfig.Read.All`

### Solution

**Option 1: Update App Registration** (Recommended)
1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Select your app registration
4. Click **API permissions**
5. Add missing permissions:
   - Click **Add a permission**
   - Select **Microsoft Graph**
   - Choose **Application permissions**
   - Search and add each required permission
6. Click **Grant admin consent**

**Option 2: Use Delegated Permissions**
```powershell
# Connect with interactive login (delegated permissions)
Connect-MgGraph -Scopes "DeviceManagementApps.Read.All", "DeviceManagementConfiguration.Read.All"
$accessToken = (Get-MgContext).TokenCache.AccessToken

Export-ConfigurationAssignments -AccessToken $accessToken -OutputPath "./logs"
```

**Verification**:
```powershell
# Check current token permissions
$token = "your-token-here"
$tokenParts = $token.Split('.')
$payload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($tokenParts[1] + "=="))
$payloadJson = $payload | ConvertFrom-Json

# Check roles/scopes
$payloadJson.roles  # Application permissions
$payloadJson.scp    # Delegated permissions
```

---

## Issue #6: Errors Exported to CSV but Not Categorized

### Symptoms
- Error CSV created with errors
- ErrorCategory column is blank or shows "UNKNOWN"
- RemediationGuidance column is empty

### Root Cause
Using old version without error categorization

### Solution
**Update to v2.0+** which includes error categorization system

**Verification**:
```powershell
# Check for categorization functions
Get-Content .\functions\UserAndGroupFunctions\Export-ConfigurationAssignments.ps1 | Select-String "Get-ErrorCategory"

# Should return function definition
```

**Expected CSV Format** (v2.0+):
```csv
Timestamp,ErrorType,ErrorCategory,KnownLimitation,ResourceName,ErrorCode,ErrorMessage,RemediationGuidance
2025-11-10 12:00:00,ASSIGNMENT_CHECK_FAILED,API_DESIGN_LIMITATION,TRUE,"Cloud-Managed PC Policy Set",API_DESIGN_LIMITATION,"PolicySets use non-standard OData routing","Consider implementing alternative query method..."
```

---

## Issue #7: Unable to Run Export - Module Errors

### Symptoms
- Error: "The term 'Export-ConfigurationAssignments' is not recognized"
- Import-Module failures
- Function dependencies missing

### Root Cause
Functions not properly loaded or missing dependencies

### Solution

**Option 1: Use main.ps1** (Recommended)
```powershell
# This loads all dependencies automatically
. .\main.ps1

# Then run export
Export-ConfigurationAssignments -AccessToken $token -OutputPath "./logs" -IncludeBeta
```

**Option 2: Manual Import**
```powershell
# Import all required modules
Import-Module .\functions\graphFunctions\CallGraphAPI.ps1 -Force
Import-Module .\functions\graphFunctions\GetGraphObjectMetadata.ps1 -Force
Import-Module .\functions\autopilotFunctions\Get-ResourceListEndpoints.ps1 -Force
Import-Module .\functions\UserAndGroupFunctions\Export-ConfigurationAssignments.ps1 -Force

# Get credentials
$cred = Get-StoredCredential -Target 'AutopilotGraphAPI'
$token = $cred.GetNetworkCredential().Password

# Run export
Export-ConfigurationAssignments -AccessToken $token -OutputPath "./logs" -IncludeBeta
```

**Verify Dependencies**:
```powershell
# Check all required functions loaded
Get-Command Export-ConfigurationAssignments
Get-Command CallGraphAPI
Get-Command GetGraphObjectMetadata
Get-Command Get-ResourceListEndpoints
```

---

## Diagnostic Commands

### Quick Health Check
```powershell
# Test basic functionality
. .\main.ps1

# Check token
$cred = Get-StoredCredential -Target 'AutopilotGraphAPI'
if ($cred) { Write-Host "✓ Credentials found" } else { Write-Host "✗ No credentials" }

# Test Graph API connectivity
$token = $cred.GetNetworkCredential().Password
$result = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$top=1" `
    -Headers @{Authorization = "Bearer $token"}
if ($result) { Write-Host "✓ Graph API accessible" } else { Write-Host "✗ Graph API failed" }

# Check function availability
if (Get-Command Export-ConfigurationAssignments -ErrorAction SilentlyContinue) {
    Write-Host "✓ Export function loaded"
} else {
    Write-Host "✗ Export function not found"
}
```

### Detailed Diagnostic Export
```powershell
# Run with maximum logging
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$result = Export-ConfigurationAssignments -AccessToken $token -OutputPath "./logs" `
    -IncludeBeta -CreateErrorExportFile -Verbose -Debug

# Review results
Write-Host "`n=== Diagnostic Results ===" -ForegroundColor Cyan
Write-Host "Success: $($result.Success)"
Write-Host "Resources: $($result.ResourceCount)"
Write-Host "Errors: $($result.ErrorCount)"
Write-Host "Output: $($result.OutputFile)"
Write-Host "Error File: $($result.ErrorFile)"

# Check log file
if (Test-Path "./logs/Autopilot.log") {
    Write-Host "`nLast 20 log entries:"
    Get-Content "./logs/Autopilot.log" -Tail 20
}
```

### Error Analysis
```powershell
# Analyze error patterns
if ($result.ErrorFile -and (Test-Path $result.ErrorFile)) {
    $errors = Import-Csv $result.ErrorFile
    
    Write-Host "`n=== Error Analysis ===" -ForegroundColor Yellow
    Write-Host "Total Errors: $($errors.Count)"
    
    # Group by category
    $errorGroups = $errors | Group-Object ErrorCategory | Sort-Object Count -Descending
    Write-Host "`nBy Category:"
    foreach ($group in $errorGroups) {
        $isKnown = $group.Name -in @('API_DESIGN_LIMITATION', 'UNSUPPORTED_ENDPOINT')
        $label = if ($isKnown) { "[Known]" } else { "[Error]" }
        Write-Host "  $label $($group.Name): $($group.Count)"
    }
    
    # Show sample remediation
    Write-Host "`nSample Remediation Guidance:"
    $errors | Select-Object -First 3 | ForEach-Object {
        Write-Host "  - $($_.ResourceName): $($_.RemediationGuidance)"
    }
}
```

---

## Getting Help

### Log Files
All operations logged to: `./logs/Autopilot.log`

**Useful filters**:
```powershell
# Errors only
Get-Content ./logs/Autopilot.log | Select-String "ERROR"

# Warnings only
Get-Content ./logs/Autopilot.log | Select-String "WARNING"

# Specific resource
Get-Content ./logs/Autopilot.log | Select-String "PolicySet"

# Today's entries
Get-Content ./logs/Autopilot.log | Select-String (Get-Date -Format "yyyy-MM-dd")
```

### Support Resources
- **Documentation**: See `./docs/` folder
  - `KNOWN_API_LIMITATIONS.md` - Known issues and workarounds
  - `ERROR_CATEGORIZATION_IMPLEMENTATION_REPORT.md` - Error handling details
  - `TECHNICAL_DOCUMENTATION.md` - System architecture
- **Issue Tracker**: GitHub repository issues
- **Microsoft Graph API**: [Microsoft Learn Documentation](https://learn.microsoft.com/en-us/graph/)

---

## Version Compatibility

| Feature | Version | Status |
|---------|---------|--------|
| Basic export | 1.0+ | ✅ Supported |
| Batch ID fix | 1.5+ | ✅ Required for reliability |
| Error categorization | 2.0+ | ✅ Recommended |
| App protection workaround | 2.1+ | ✅ Recommended |
| PolicySet handling | 2.1+ | ✅ Recommended |

**Recommended Version**: 2.1+ (includes all fixes and workarounds)

---

*Last Updated: November 10, 2025*
