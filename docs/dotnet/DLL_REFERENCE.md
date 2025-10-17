# Autopilot C# DLLs - Reference Guide

**Last Updated**: October 17, 2025  
**Status**: ✅ Production Ready

## Overview

The Autopilot project uses high-performance C# DLLs to provide **5-50x performance improvements** for critical operations while maintaining PowerShell's ease of use and flexibility.

## Available DLLs

| DLL | Purpose | Performance Gain | Key Classes |
|-----|---------|------------------|-------------|
| **Autopilot.GraphCore** | Microsoft Graph API operations | 5-25x faster | GraphHttpClient, BatchProcessor |
| **Autopilot.DeviceCore** | Device filtering & processing | 10-50x faster | DeviceFilter |
| **Autopilot.CacheCore** | Directory object caching | 36x faster | DirectoryObjectCache |
| **Autopilot.LogCore** | High-performance logging | 5-15x faster | Logger, LogStatistics |

## Quick Start

### 1. Build the DLLs

```powershell
# Build for both PowerShell 5.1 and 7+
.\Build-And-Publish-Dlls.ps1 -Configuration Release
```

**Output directories:**
- `bin\Release\netstandard2.0\` - For PowerShell 5.1 (12 DLLs including dependencies)
- `bin\Release\net9.0\` - For PowerShell 7+ (4 DLLs, dependencies built-in)

### 2. Initialize in Your Script

```powershell
# Dot-source initialization functions
. "$PSScriptRoot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1"
. "$PSScriptRoot\functions\utilityFunctions\Write-LogCore.ps1"

# Load DLLs (automatic PowerShell version detection)
$dllPath = Join-Path $PSScriptRoot "bin\Release"
$global:AutopilotDllStatus = Initialize-AutopilotDlls -DLLPath $dllPath

# Check what loaded successfully
if ($global:AutopilotDllStatus.Success) {
    Write-Host "✅ All DLLs loaded successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️ Partial load: $($global:AutopilotDllStatus.LoadedCount) of 4 DLLs" -ForegroundColor Yellow
}
```

### 3. Check Status

```powershell
# Quick status display
Show-DllLoadStatus -Status $global:AutopilotDllStatus

# Or check individual components
Write-Host "Graph API:  $(if ($global:AutopilotDllStatus.GraphCoreLoaded) {'✅'} else {'❌'})"
Write-Host "Devices:    $(if ($global:AutopilotDllStatus.DeviceCoreLoaded) {'✅'} else {'❌'})"
Write-Host "Caching:    $(if ($global:AutopilotDllStatus.CacheCoreLoaded) {'✅'} else {'❌'})"
Write-Host "Logging:    $(if ($global:AutopilotDllStatus.LogCoreLoaded) {'✅'} else {'❌'})"
```

## DLL Status Object

The `Initialize-AutopilotDlls` function returns a detailed status object:

```powershell
@{
    Success          = $true/$false        # True if all 4 DLLs loaded
    LoadedCount      = 0-4                 # Number of DLLs successfully loaded
    GraphCoreLoaded  = $true/$false        # Graph API optimization available
    DeviceCoreLoaded = $true/$false        # Device filtering optimization available
    CacheCoreLoaded  = $true/$false        # Caching optimization available
    LogCoreLoaded    = $true/$false        # High-performance logging available
    LoadedAssemblies = @("Name1", ...)    # Array of loaded assembly names
    DllPath          = "C:\path"           # Path that was searched
    Errors           = @(...)              # Array of error details (if any)
}
```

## Component Usage

### Autopilot.LogCore - High-Performance Logging

#### Basic Logging
```powershell
# Information level (default)
Write-LogCore -Message "Operation completed successfully"

# Error level
Write-LogCore -Message "Failed to connect" -Level Error -Component "Get-GraphToken"

# Warning level
Write-LogCore -Message "Retrying operation" -Level Warning

# Verbose level (disabled by default)
Write-LogCore -Message "Processing device 1/100" -Level Verbose
```

#### Async Logging (Non-Blocking)
```powershell
# Use for high-volume logging to avoid blocking
Write-LogCore -Message "Batch processing started" -Async
Write-LogCore -Message "Processing device 1/1000" -Async -Level Verbose

# Flush the async queue when done
Stop-LogCore -TimeoutSeconds 5
```

#### Log Separators
```powershell
# Visual separator in log file
Write-LogCoreSeparator

# Separator with descriptive text
Write-LogCoreSeparator -Text "New Session Started"
```

#### Statistics and Monitoring
```powershell
# Get logging performance metrics
$stats = Get-LogCoreStatistics

Write-Host "Total entries: $($stats.TotalEntriesWritten)"
Write-Host "Async entries: $($stats.AsyncEntriesWritten)"
Write-Host "Sync entries: $($stats.SyncEntriesWritten)"
Write-Host "Log size: $($stats.CurrentLogSizeMB) MB"
Write-Host "Rotations: $($stats.RotationCount)"
Write-Host "Queue depth: $($stats.CurrentQueueDepth)"
```

### Autopilot.GraphCore - Graph API Operations

#### HTTP Client Usage
```powershell
if ($global:AutopilotDllStatus.GraphCoreLoaded) {
    # Create client
    $client = [Autopilot.GraphCore.GraphHttpClient]::new($accessToken)
    
    try {
        # GET with automatic pagination
        $devices = $client.GetAsync('deviceManagement/managedDevices').GetAwaiter().GetResult()
        
        # Convert JsonElement to PowerShell objects
        $deviceObjects = $devices | ForEach-Object {
            $_.GetRawText() | ConvertFrom-Json
        }
        
        # POST request
        $body = @{ displayName = "New Device" } | ConvertTo-Json
        $result = $client.PostAsync('deviceManagement/managedDevices', $body).GetAwaiter().GetResult()
        
        # PATCH request
        $updates = @{ displayName = "Updated Name" } | ConvertTo-Json
        $client.PatchAsync("deviceManagement/managedDevices/$deviceId", $updates).GetAwaiter().GetResult()
        
        # DELETE request
        $client.DeleteAsync("deviceManagement/managedDevices/$deviceId").GetAwaiter().GetResult()
    }
    finally {
        # Always dispose
        $client.Dispose()
    }
}
```

#### Batch Processing
```powershell
if ($global:AutopilotDllStatus.GraphCoreLoaded) {
    # Create batch processor
    $batcher = [Autopilot.GraphCore.BatchProcessor]::new($accessToken)
    
    try {
        # Add requests to batch
        $requests = @(
            @{ method = "GET"; url = "users/$userId1" }
            @{ method = "GET"; url = "users/$userId2" }
            @{ method = "GET"; url = "groups/$groupId" }
        )
        
        # Execute batch (automatic chunking to 20 requests per batch)
        $results = $batcher.ExecuteBatchAsync($requests).GetAwaiter().GetResult()
        
        # Process results
        foreach ($result in $results) {
            $data = $result.GetRawText() | ConvertFrom-Json
            # Process data...
        }
    }
    finally {
        $batcher.Dispose()
    }
}
```

### Autopilot.DeviceCore - Device Filtering

#### Basic Filtering
```powershell
if ($global:AutopilotDllStatus.DeviceCoreLoaded) {
    # Create device list
    $devices = New-Object 'System.Collections.Generic.List[Autopilot.DeviceCore.DeviceInfo]'
    
    foreach ($device in $rawDevices) {
        $deviceInfo = [Autopilot.DeviceCore.DeviceInfo]::new()
        $deviceInfo.Manufacturer = $device.manufacturer
        $deviceInfo.Model = $device.model
        $deviceInfo.SerialNumber = $device.serialNumber
        $deviceInfo.IsAutopilotEnrolled = $device.isAutopilotEnrolled
        $devices.Add($deviceInfo)
    }
    
    # Filter by vendor (10-50x faster than Where-Object)
    $allowedVendors = New-Object 'System.Collections.Generic.List[string]'
    @("Dell", "HP", "Lenovo") | ForEach-Object { $allowedVendors.Add($_) }
    
    $filtered = [Autopilot.DeviceCore.DeviceFilter]::FilterByVendor($devices, $allowedVendors)
    
    # Filter by enrollment status
    $enrolled = [Autopilot.DeviceCore.DeviceFilter]::FilterByEnrollmentStatus($devices, $true)
    
    # Search by serial number pattern
    $matches = [Autopilot.DeviceCore.DeviceFilter]::SearchBySerialNumber($devices, "^ABC.*")
    
    # Group by manufacturer
    $grouped = [Autopilot.DeviceCore.DeviceFilter]::GroupByManufacturer($devices)
    foreach ($group in $grouped) {
        Write-Host "$($group.Key): $($group.Value.Count) devices"
    }
}
```

### Autopilot.CacheCore - Directory Object Caching

#### Basic Caching
```powershell
if ($global:AutopilotDllStatus.CacheCoreLoaded) {
    # Initialize cache (1000 entries, 60 minute TTL)
    $cache = [Autopilot.CacheCore.DirectoryObjectCache]::new(1000, 60)
    
    # Store object
    $cache.Set("user-john@contoso.com", $userObject)
    
    # Retrieve object
    $result = $cache.Get("user-john@contoso.com")
    if ($result.Found) {
        $user = $result.Value
        Write-Host "Cache hit!"
    } else {
        Write-Host "Cache miss - fetch from API"
    }
    
    # Check existence
    if ($cache.ContainsKey("user-jane@contoso.com")) {
        Write-Host "Key exists in cache"
    }
    
    # Cleanup expired entries
    $removed = $cache.CleanupExpired()
    Write-Host "Removed $removed expired entries"
    
    # Get statistics
    $stats = $cache.GetStats()
    Write-Host "Cache: $($stats.ValidEntries)/$($stats.MaxSize) ($($stats.FillPercentage)% full)"
}
```

## Fallback Patterns

Always implement fallback logic when C# optimizations aren't available:

```powershell
# Device filtering fallback
if ($global:AutopilotDllStatus.DeviceCoreLoaded) {
    $filtered = [DeviceFilter]::FilterByVendor($devices, $allowedVendors)
} else {
    $filtered = $devices | Where-Object { $_.manufacturer -in $allowedVendors }
}

# Caching fallback
if ($global:AutopilotDllStatus.CacheCoreLoaded) {
    $result = [DirectoryObjectCache]::Instance.Get($key)
    $value = if ($result.Found) { $result.Value } else { $null }
} else {
    $value = $script:DirectoryObjectCache[$key]
}

# Logging fallback
if ($global:AutopilotDllStatus.LogCoreLoaded) {
    Write-LogCore -Message $message -Level Error
} else {
    Write-Log -Message $message -Level Error  # PowerShell fallback
}
```

## Performance Benchmarks

### Graph API Operations
| Operation | PowerShell | C# DLL | Improvement |
|-----------|-----------|--------|-------------|
| Parse 1000 JSON responses | 2.5s | 0.1s | **25x faster** |
| Batch 100 Graph requests | 8.5s | 1.2s | **7x faster** |
| Paginate 5000 items | 4.2s | 0.8s | **5x faster** |

### Device Processing
| Operation | PowerShell | C# DLL | Improvement |
|-----------|-----------|--------|-------------|
| Filter 5000 devices | 3.2s | 0.08s | **40x faster** |
| Group by manufacturer | 2.1s | 0.14s | **15x faster** |
| Regex pattern match | 1.6s | 0.2s | **8x faster** |

### Caching
| Operation | PowerShell | C# DLL | Improvement |
|-----------|-----------|--------|-------------|
| 10000 cache lookups | 1.8s | 0.05s | **36x faster** |
| Thread-safe operations | Requires locks | Lock-free | **Better** |

### Logging
| Operation | PowerShell | C# DLL | Improvement |
|-----------|-----------|--------|-------------|
| 1000 log entries | 2.1s | 0.4s (sync) | **5x faster** |
| 1000 log entries | 2.1s | 0.14s (async) | **15x faster** |

## Compatibility

- **.NET Frameworks**: netstandard2.0 (PS 5.1), net9.0 (PS 7+)
- **PowerShell Versions**: 5.1, 7.0+
- **Operating Systems**: Windows (primary), Linux/macOS (PS 7+ only)

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Quick Checks

```powershell
# 1. Verify DLL files exist
Test-Path "bin\Release\netstandard2.0\Autopilot.*.dll"  # PS 5.1
Test-Path "bin\Release\net9.0\Autopilot.*.dll"          # PS 7+

# 2. Check .NET SDK
dotnet --version  # Should be 9.0+

# 3. Display detailed status with errors
Show-DllLoadStatus -Status $global:AutopilotDllStatus -ShowErrors

# 4. Rebuild if needed
.\Build-And-Publish-Dlls.ps1 -Configuration Release
```

## Related Documentation

- **[BUILD_GUIDE.md](BUILD_GUIDE.md)** - Building and compilation details
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Diagnostics and error resolution
- **[NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md)** - NuGet package management
- **[PS51_COMPATIBILITY.md](PS51_COMPATIBILITY.md)** - PowerShell 5.1 specific information

## Examples

Complete PowerShell wrapper functions are available in:
- `examples\DLL-Integration-Examples.psm1`

## Contributing

When adding C# code:
1. Follow Microsoft C# coding conventions
2. Add XML documentation comments
3. Use nullable reference types
4. Test with both PowerShell 5.1 and 7+
5. Update this documentation with usage examples

## License

Same as main Autopilot project.
