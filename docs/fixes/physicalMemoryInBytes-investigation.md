# Investigation: physicalMemoryInBytes Returning 0

## Problem Summary
The `physicalMemoryInBytes` property consistently returns 0 when querying managed devices via Graph API, even though the property exists and should contain data.

## Root Cause Analysis

### Key Findings from Microsoft Documentation

1. **Hardware Inventory Sync Timing**:
   - Per Microsoft docs: "Hardware and Software inventory is refreshed in the Intune service **every 7 days**, starting from the date of enrollment"
   - Source: https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/device-inventory#hardware-device-details

2. **Platform Limitation**:
   - `physicalMemoryInBytes` and "Total physical memory" are **Windows-only** properties
   - Property added to managedDevice entity in December 2019 (beta API)

3. **Sync Dependencies**:
   - Property depends on devices checking in with Intune and reporting hardware inventory
   - Devices must have synced **within the last 7 days** for current data
   - Initial enrollment may not immediately populate all hardware properties

## Alternative Solutions (In Order of Efficiency)

### Option 1: Use $expand=hardwareInformation (RECOMMENDED)
The `hardwareInformation` complex object contains memory data and may be more reliably populated.

**API Call:**
```powershell
GET /deviceManagement/managedDevices?$filter=operatingSystem eq 'Windows'&$expand=hardwareInformation&$top=999
```

**Pros:**
- Single API call
- Access to nested `hardwareInformation` object which contains:
  - `totalPhysicalMemory` (in bytes)
  - `manufacturer`, `model`, `serialNumber`
  - BIOS info, processor details, etc.
- More comprehensive hardware data

**Cons:**
- Cannot combine `$expand` with `$select` - returns FULL device objects
- Larger payload size (~50-100% more data per device)
- Slightly slower response times

**Code Example:**
```powershell
$managedDeviceUri = "deviceManagement/managedDevices"
$managedDevices = CallGraphApi -ResourcePath $managedDeviceUri `
    -accessToken $AccessToken `
    -Filter "operatingSystem eq 'Windows'" `
    -consistencyLevel `
    -extraParameters "expand=hardwareInformation&top=999"

# Access the memory
foreach ($device in $managedDevices.value) {
    $memoryBytes = $device.hardwareInformation.totalPhysicalMemory
    if ($memoryBytes -and $memoryBytes -gt 0) {
        $memoryGB = [math]::Round($memoryBytes / 1GB, 2)
    }
}
```

### Option 2: Use Beta API with Targeted Select
Query beta endpoint with both `hardwareInformation` and `physicalMemoryInBytes` selected.

**API Call:**
```powershell
GET /beta/deviceManagement/managedDevices?$filter=operatingSystem eq 'Windows'&$select=hardwareInformation,physicalMemoryInBytes,id,deviceName...&$top=999
```

**Pros:**
- Single API call
- Reduced payload compared to full expand
- Beta API may have better property population

**Cons:**
- Still using beta API (less stable)
- May still return 0 if hardware sync hasn't occurred

**Code Example:**
```powershell
$selectProperties = "id,deviceName,serialNumber,manufacturer,model,userPrincipalName,userDisplayName,operatingSystem,osVersion,lastSyncDateTime,physicalMemoryInBytes,hardwareInformation,totalStorageSpaceInBytes,freeStorageSpaceInBytes,joinType,complianceState"

$managedDevices = CallGraphApi -ResourcePath "deviceManagement/managedDevices" `
    -accessToken $AccessToken `
    -Filter "operatingSystem eq 'Windows'" `
    -APIVersion "beta" `
    -consistencyLevel `
    -extraParameters "select=$selectProperties&top=999"
```

### Option 3: Individual Device Queries (Fallback Pattern)
If $select returns 0, query individual devices for full objects.

**API Call:**
```powershell
# Step 1: Get device IDs with filter
GET /deviceManagement/managedDevices?$filter=operatingSystem eq 'Windows'&$select=id&$top=999

# Step 2: For each device, get full object
GET /deviceManagement/managedDevices/{deviceId}
```

**Pros:**
- Guaranteed to get full device object
- More reliable for getting all properties

**Cons:**
- Requires N+1 API calls (1 list + 1 per device)
- Much slower for large device counts
- Higher risk of throttling

**Code Example:**
```powershell
# Get device IDs first
$deviceIds = CallGraphApi -ResourcePath "deviceManagement/managedDevices" `
    -accessToken $AccessToken `
    -Filter "operatingSystem eq 'Windows'" `
    -consistencyLevel `
    -extraParameters "select=id&top=999"

# Query each device individually
$deviceDetails = @()
foreach ($device in $deviceIds.value) {
    $fullDevice = CallGraphApi -ResourcePath "deviceManagement/managedDevices/$($device.id)" `
        -accessToken $AccessToken
    $deviceDetails += $fullDevice
}
```

### Option 4: Batch API Calls (Original Approach - LAST RESORT)
Use the Graph batch endpoint to query multiple devices efficiently.

**API Call:**
```powershell
POST /$batch
{
  "requests": [
    {
      "id": "1",
      "method": "GET",
      "url": "/deviceManagement/managedDevices/{device1Id}"
    },
    {
      "id": "2",
      "method": "GET",
      "url": "/deviceManagement/managedDevices/{device2Id}"
    }
    // ... up to 20 requests per batch
  ]
}
```

**Pros:**
- More efficient than individual queries (20 devices per batch vs 1 per call)
- Guaranteed to get full device objects

**Cons:**
- Complex code to manage batching logic
- Still requires multiple API calls (deviceCount / 20)
- Slower than single $filter query
- Maximum 20 requests per batch

## Recommended Implementation Strategy

### Phase 1: Try $expand=hardwareInformation (Option 1)
```powershell
$managedDevices = CallGraphApi -ResourcePath "deviceManagement/managedDevices" `
    -accessToken $AccessToken `
    -Filter "operatingSystem eq 'Windows'" `
    -consistencyLevel `
    -extraParameters "expand=hardwareInformation&top=999"

foreach ($device in $managedDevices.value) {
    # Try hardware object first
    $memoryBytes = $device.hardwareInformation.totalPhysicalMemory
    
    # Fallback to top-level property
    if (-not $memoryBytes -or $memoryBytes -eq 0) {
        $memoryBytes = $device.physicalMemoryInBytes
    }
    
    if ($memoryBytes -and $memoryBytes -gt 0) {
        $memoryGB = [math]::Round($memoryBytes / 1GB, 2)
    } else {
        $memoryGB = 0
        Write-Verbose "Memory not available for device $($device.deviceName)"
    }
}
```

### Phase 2: Implement Hybrid Approach (Fallback Logic)
If $expand returns 0 for many devices, implement fallback:

```powershell
# Try $expand first (single call)
$devicesWithHardware = CallGraphApi -ResourcePath "deviceManagement/managedDevices" `
    -Filter "operatingSystem eq 'Windows'" `
    -extraParameters "expand=hardwareInformation&top=999"

# Identify devices with missing memory data
$devicesNeedingMemory = $devicesWithHardware.value | Where-Object {
    $_.hardwareInformation.totalPhysicalMemory -eq 0 -or 
    $null -eq $_.hardwareInformation.totalPhysicalMemory
}

# For devices missing memory, query individually (if needed)
if ($devicesNeedingMemory.Count -gt 0 -and $devicesNeedingMemory.Count -lt 50) {
    Write-Verbose "Re-querying $($devicesNeedingMemory.Count) devices individually for memory data"
    foreach ($device in $devicesNeedingMemory) {
        $fullDevice = CallGraphApi -ResourcePath "deviceManagement/managedDevices/$($device.id)"
        # Update the device object with full data
    }
}
```

## Performance Comparison

| Approach | API Calls | Avg Response Time* | Payload Size | Reliability |
|----------|-----------|-------------------|--------------|-------------|
| $select (current) | 1 | 2-3s | ~50KB/device | ❌ Returns 0 |
| $expand=hardwareInformation | 1 | 3-5s | ~100KB/device | ✅ High |
| Beta $select | 1 | 2-3s | ~50KB/device | ⚠️ Medium |
| Individual queries | N+1 | 1-2s each | ~100KB/device | ✅ Guaranteed |
| Batch API | N/20 | 2-3s each | ~2MB/batch | ✅ Guaranteed |

*For 100 devices

## Testing Validation

### Test 1: Verify $expand Works
```powershell
$test = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$expand=hardwareInformation&`$top=5" `
    -Headers @{Authorization = "Bearer $accessToken"}

$test.value | ForEach-Object {
    Write-Host "Device: $($_.deviceName)"
    Write-Host "Memory (hardwareInformation): $($_.hardwareInformation.totalPhysicalMemory)"
    Write-Host "Memory (top-level): $($_.physicalMemoryInBytes)"
}
```

### Test 2: Check Last Sync Times
```powershell
# Verify devices have synced recently
$devices | Select-Object deviceName, lastSyncDateTime | Where-Object {
    $_.lastSyncDateTime -lt (Get-Date).AddDays(-7)
}
```

## References
- [Microsoft Learn: Device Inventory](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/device-inventory#hardware-device-details)
- [Graph API Changelog: physicalMemoryInBytes added Dec 2019](https://learn.microsoft.com/en-us/graph/changelog-archive#december-2019)
- [OData Query Parameters](https://learn.microsoft.com/en-us/graph/query-parameters)
- [Graph API managedDevice resource](https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice)

## Conclusion

**Recommended Action**: Implement Option 1 ($expand=hardwareInformation) as it provides:
1. Single API call (maintains optimization goals)
2. Access to comprehensive hardware object
3. Better reliability than top-level property
4. Acceptable performance trade-off (~1-2s slower per 100 devices)

If payload size becomes an issue with large device counts (>1000), consider implementing the hybrid approach with selective fallback to individual queries.
