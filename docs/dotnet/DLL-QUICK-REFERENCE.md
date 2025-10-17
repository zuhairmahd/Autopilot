# Autopilot C# DLLs - Quick Reference Card

## 🚀 Getting Started

### Build All DLLs
```powershell
.\Build-And-Publish-Dlls.ps1 -Configuration Release
```
**Output**: 12 DLLs (netstandard2.0), 4 DLLs (net9.0)

### Test All DLLs
```powershell
# Current PowerShell version
.\Test-AutopilotDlls.ps1 -Verbose

# Both PS 5.1 and PS 7+
.\Test-AutopilotDlls.ps1 -TestBothVersions
```

---

## 📦 Available DLLs

| DLL | Purpose | Key Classes |
|-----|---------|-------------|
| **Autopilot.GraphCore** | Graph API batch processing | BatchProcessor, GraphHttpClient |
| **Autopilot.DeviceCore** | Device filtering & grouping | DeviceFilter, DeviceGrouper |
| **Autopilot.CacheCore** | Directory object caching | DirectoryObjectCache |
| **Autopilot.LogCore** | High-performance logging | Logger, LogLevel, LogStatistics |

---

## 🔧 Initialize DLLs in Your Script

```powershell
# Dot-source the initialization function
. "$PSScriptRoot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1"
. "$PSScriptRoot\functions\utilityFunctions\Write-LogCore.ps1"

# Load DLLs (automatic PS version detection)
$dllPath = Join-Path $PSScriptRoot "bin\Release"
$global:AutopilotDllStatus = Initialize-AutopilotDlls -DLLPath $dllPath

# Check status
Write-Host "GraphCore: $(if ($global:AutopilotDllStatus.GraphCoreLoaded) {'✅'} else {'❌'})"
Write-Host "DeviceCore: $(if ($global:AutopilotDllStatus.DeviceCoreLoaded) {'✅'} else {'❌'})"
Write-Host "CacheCore: $(if ($global:AutopilotDllStatus.CacheCoreLoaded) {'✅'} else {'❌'})"
Write-Host "LogCore: $(if ($global:AutopilotDllStatus.LogCoreLoaded) {'✅'} else {'❌'})"
```

---

## 📝 LogCore Usage

### Basic Logging
```powershell
# Information level (default)
Write-LogCore -Message "Operation completed successfully"

# Error level
Write-LogCore -Message "Failed to connect" -Level Error -Component "Get-GraphToken"

# Verbose level
Write-LogCore -Message "Processing 100 devices" -Level Verbose
```

### Async Logging (Non-Blocking)
```powershell
# For high-volume logging
Write-LogCore -Message "Batch processing started" -Async
Write-LogCore -Message "Processing device 1/1000" -Async -Level Verbose
```

### Log Separators
```powershell
# Simple separator
Write-LogCoreSeparator

# Separator with text
Write-LogCoreSeparator -Text "New Session Started"
```

### Shutdown & Statistics
```powershell
# Graceful shutdown (flushes async queue)
Stop-LogCore -TimeoutSeconds 5

# Get performance metrics
$stats = Get-LogCoreStatistics
Write-Host "Total entries: $($stats.TotalEntriesWritten)"
Write-Host "Async entries: $($stats.AsyncEntriesWritten)"
Write-Host "Log size: $($stats.CurrentLogSizeMB) MB"
Write-Host "Rotations: $($stats.RotationCount)"
```

---

## 🎯 GraphCore Usage

### Batch Processing
```powershell
if ($global:AutopilotDllStatus.GraphCoreLoaded) {
    $batchProcessor = New-Object Autopilot.GraphCore.BatchProcessor($accessToken, "https://graph.microsoft.com/v1.0")
    
    # Process batch of requests
    $requests = @(
        @{ id = "1"; method = "GET"; url = "/users/user1@contoso.com" }
        @{ id = "2"; method = "GET"; url = "/users/user2@contoso.com" }
    )
    
    $results = $batchProcessor.ProcessBatch($requests)
}
```

---

## 🖥️ DeviceCore Usage

### Filter Devices
```powershell
if ($global:AutopilotDllStatus.DeviceCoreLoaded) {
    $deviceFilter = New-Object Autopilot.DeviceCore.DeviceFilter
    
    # Filter by vendor
    $surfaceDevices = $deviceFilter.FilterByVendor($allDevices, "Microsoft Corporation")
    
    # Filter by enrollment status
    $enrolledDevices = $deviceFilter.FilterByEnrollmentStatus($allDevices, "Enrolled")
    
    # Search by serial number
    $device = $deviceFilter.SearchBySerialNumber($allDevices, "ABC123")
}
```

### Group Devices
```powershell
$deviceGrouper = New-Object Autopilot.DeviceCore.DeviceGrouper

# Group by manufacturer
$groupedDevices = $deviceGrouper.GroupByManufacturer($allDevices)

# Sort devices
$sortedDevices = $deviceGrouper.SortDevices($allDevices, "displayName")
```

---

## 💾 CacheCore Usage

### Directory Object Caching
```powershell
if ($global:AutopilotDllStatus.CacheCoreLoaded) {
    # Create cache (max 1000 entries)
    $cache = New-Object Autopilot.CacheCore.DirectoryObjectCache(1000)
    
    # Add to cache
    $cache.Add("User", "user@contoso.com", $userObject)
    
    # Get from cache
    $cachedUser = $cache.Get("User", "user@contoso.com")
    
    # Check if exists
    if ($cache.Contains("User", "user@contoso.com")) {
        # Use cached value
    }
    
    # Clear cache
    $cache.Clear()
}
```

---

## 🔍 Troubleshooting

### Check DLL Status
```powershell
# View global status
$global:AutopilotDllStatus | Format-List

# Check specific DLL
if ($global:AutopilotDllStatus.LogCoreLoaded) {
    Write-Host "LogCore is available" -ForegroundColor Green
} else {
    Write-Host "LogCore not loaded, using fallback" -ForegroundColor Yellow
}
```

### View Errors
```powershell
# Check for load errors
if ($global:AutopilotDllStatus.Errors.Count -gt 0) {
    foreach ($err in $global:AutopilotDllStatus.Errors) {
        Write-Warning "DLL: $($err.Dll) - $($err.Message)"
    }
}
```

### Force Reload
```powershell
# Remove existing status
$global:AutopilotDllStatus = $null
$global:AutopilotDllsLoaded = $false

# Reload
$dllPath = Join-Path $PSScriptRoot "bin\Release"
$global:AutopilotDllStatus = Initialize-AutopilotDlls -DLLPath $dllPath -Verbose
```

---

## 📊 Performance Tips

### Use Async Logging for High Volume
```powershell
# Good for high-volume scenarios
for ($i = 0; $i -lt 1000; $i++) {
    Write-LogCore -Message "Processing item $i" -Async -Level Verbose
}

# Ensure all entries are written
Stop-LogCore -TimeoutSeconds 10
```

### Use Batch Processing for Graph API
```powershell
# Instead of 100 individual requests...
# Use batch processing (20 requests/batch)
$batchProcessor.ProcessBatch($requests)
```

### Cache Frequently Accessed Objects
```powershell
# Cache user/group lookups
$cache = New-Object Autopilot.CacheCore.DirectoryObjectCache(1000)

foreach ($device in $devices) {
    $userEmail = $device.userPrincipalName
    
    # Check cache first
    if ($cache.Contains("User", $userEmail)) {
        $user = $cache.Get("User", $userEmail)
    } else {
        # Fetch from Graph API
        $user = Get-MgUser -UserId $userEmail
        $cache.Add("User", $userEmail, $user)
    }
}
```

---

## 🎬 Log Levels Reference

| Level | Value | Use Case |
|-------|-------|----------|
| **Error** | 1 | Critical errors, failures |
| **Warning** | 2 | Non-critical issues, deprecations |
| **Information** | 3 | Standard operational messages |
| **Verbose** | 4 | Detailed progress information |
| **Debug** | 5 | Development/troubleshooting details |

**Examples**:
```powershell
Write-LogCore -Message "Critical failure" -Level Error
Write-LogCore -Message "Deprecated parameter used" -Level Warning
Write-LogCore -Message "Application started" -Level Information
Write-LogCore -Message "Processing 50 devices" -Level Verbose
Write-LogCore -Message "Variable value: $myVar" -Level Debug
```

---

## 🏗️ CMTrace Format

LogCore uses CMTrace format by default (compatible with Microsoft Configuration Manager Log Viewer):

**Sample Entry**:
```
<![LOG[Application started]LOG]!><time="14:30:45.123+000" date="01-15-2025" component="main.ps1" context="" type="1" thread="12345" file="main.ps1:42">
```

**View Logs**:
- Download: [CMTrace](https://docs.microsoft.com/en-us/mem/configmgr/core/support/cmtrace)
- Alternative: Notepad++, Visual Studio Code, any text editor

---

## 📐 Best Practices

### 1. Always Initialize DLLs Early
```powershell
# At the top of main.ps1
. "$PSScriptRoot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1"
$global:AutopilotDllStatus = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"
```

### 2. Use Fallback for Critical Functions
```powershell
# Write-LogCore automatically falls back to Write-Log
Write-LogCore -Message "Important message"  # Works even if DLL not loaded
```

### 3. Check DLL Availability for Optional Features
```powershell
if ($global:AutopilotDllStatus.GraphCoreLoaded) {
    # Use high-performance batch processing
    $results = $batchProcessor.ProcessBatch($requests)
} else {
    # Fall back to individual requests
    $results = foreach ($req in $requests) { Invoke-MgGraphRequest -Uri $req.url }
}
```

### 4. Always Shutdown LogCore Before Exit
```powershell
# At the end of main.ps1 or in error handler
try {
    # Application logic
} finally {
    Stop-LogCore -TimeoutSeconds 5
}
```

---

## 🔗 Related Documentation

- **Complete Integration Guide**: `docs/dll-integration-complete-summary.md`
- **Root Cause Analysis**: `docs/powershell-5-1-dll-loading-failure-analysis.md`
- **LogCore Implementation**: `docs/dll-loading-and-logging-consolidation-complete.md`

---

## ✅ Checklist for New Developers

- [ ] Run `.\Build-And-Publish-Dlls.ps1 -Configuration Release`
- [ ] Run `.\Test-AutopilotDlls.ps1 -TestBothVersions` (if both PS versions installed)
- [ ] Read `docs/dll-integration-complete-summary.md`
- [ ] Review `functions/utilityFunctions/Initialize-AutopilotDlls.ps1`
- [ ] Review `functions/utilityFunctions/Write-LogCore.ps1`
- [ ] Test in your script: dot-source Initialize-AutopilotDlls, call it, check status
- [ ] Replace Write-Log with Write-LogCore in new code
- [ ] Use async logging for high-volume scenarios
- [ ] Always call Stop-LogCore before application exit

---

**Need Help?** Check the comprehensive documentation in `docs/dll-integration-complete-summary.md`
