# DLL Status Quick Reference

## Quick Status Check

```powershell
# One-liner status check
$global:AutopilotDllStatus | Select-Object Success, LoadedCount, @{N='Loaded';E={$_.LoadedAssemblies -join ', '}}
```

## Return Value Properties

| Property | Type | Description |
|----------|------|-------------|
| `Success` | Boolean | `$true` if all 3 DLLs loaded |
| `LoadedCount` | Integer | Number of DLLs loaded (0-3) |
| `GraphCoreLoaded` | Boolean | Graph API optimization available |
| `DeviceCoreLoaded` | Boolean | Device filtering optimization available |
| `CacheCoreLoaded` | Boolean | Caching optimization available |
| `LoadedAssemblies` | String[] | Array of loaded assembly names |
| `DllPath` | String | Path that was searched |
| `Errors` | Hashtable[] | Array of error details |

## Component Usage Patterns

```powershell
# Cache Component
if ($global:AutopilotDllStatus.CacheCoreLoaded) {
    [DirectoryObjectCache]::Instance.Set($key, $value)
} else {
    $script:DirectoryObjectCache[$key] = $value
}

# Device Filtering Component
if ($global:AutopilotDllStatus.DeviceCoreLoaded) {
    $result = [DeviceFilter]::FilterByVendor($devices, $vendor)
} else {
    $result = $devices | Where-Object { $_.manufacturer -eq $vendor }
}

# Graph Component
if ($global:AutopilotDllStatus.GraphCoreLoaded) {
    $batch = [GraphBatcher]::CreateBatch($requests)
} else {
    # Use sequential PowerShell approach
}
```

## Error Analysis

```powershell
# Check for errors
if ($global:AutopilotDllStatus.Errors.Count -gt 0) {
    $global:AutopilotDllStatus.Errors | Format-Table Dll, ErrorType, Message -Wrap
}

# Export for analysis
$global:AutopilotDllStatus.Errors | Export-Clixml "dll-errors.xml"
```

## Diagnostic Commands

```powershell
# Full diagnostic output
Show-DllLoadStatus -DllStatus $global:AutopilotDllStatus -ShowErrors

# Verify DLL files exist
Get-ChildItem "bin\Release\*.dll" | Select-Object Name, Length, LastWriteTime

# Check AppDomain for loaded assemblies
[System.AppDomain]::CurrentDomain.GetAssemblies() | 
    Where-Object { $_.GetName().Name -like "Autopilot.*" } |
    Select-Object @{N='Name';E={$_.GetName().Name}}, @{N='Version';E={$_.GetName().Version}}

# Manual load test
Add-Type -Path "bin\Release\Autopilot.CacheCore.dll" -PassThru | 
    Select-Object Name, Namespace
```

## Common Error Types

| Error Type | Meaning | Fix |
|------------|---------|-----|
| `PathNotFound` | DLL directory missing | Run `Build-NativeDlls.ps1` |
| `FileNotFound` | DLL file missing | Rebuild specific project |
| `ReflectionTypeLoadException` | Dependency missing | Check .NET SDK version |
| `FileLoadException` | Version conflict | Clear bin folder and rebuild |
| `BadImageFormatException` | Architecture mismatch | Rebuild for correct platform |

## Rebuild Commands

```powershell
# Rebuild all DLLs
.\Build-NativeDlls.ps1 -Configuration Release

# Clean and rebuild
Remove-Item "bin\Release\*.dll" -Force
.\Build-NativeDlls.ps1 -Configuration Release

# Full release build (includes DLLs)
.\CreateRelease.ps1 -Stage Build
```

## Status in main.ps1 Initialization

```powershell
# DLLs are initialized automatically after function loading
# Available globally as: $global:AutopilotDllStatus

# Success message
"Performance DLLs loaded: Autopilot.GraphCore, Autopilot.DeviceCore, Autopilot.CacheCore"

# Partial load message
"Performance DLLs partially loaded (2/3): Autopilot.GraphCore, Autopilot.DeviceCore"

# Fallback message
"Using PowerShell implementations (DLLs not found)"
```

## Testing DLL Status

```powershell
# Test status in unit tests
BeforeAll {
    Mock Initialize-AutopilotDlls {
        @{
            Success          = $true
            LoadedCount      = 3
            GraphCoreLoaded  = $true
            DeviceCoreLoaded = $true
            CacheCoreLoaded  = $true
            LoadedAssemblies = @("Autopilot.GraphCore", "Autopilot.DeviceCore", "Autopilot.CacheCore")
            DllPath          = "bin\Release"
            Errors           = @()
        }
    }
}

# Test fallback scenario
BeforeAll {
    Mock Initialize-AutopilotDlls {
        @{
            Success          = $false
            LoadedCount      = 0
            GraphCoreLoaded  = $false
            DeviceCoreLoaded = $false
            CacheCoreLoaded  = $false
            LoadedAssemblies = @()
            DllPath          = "bin\Release"
            Errors           = @(
                @{
                    Dll       = "Directory"
                    ErrorType = "PathNotFound"
                    Message   = "DLL directory not found"
                }
            )
        }
    }
}
```

## Performance Expectations

| Component | Operation | With DLL | Without DLL | Improvement |
|-----------|-----------|----------|-------------|-------------|
| DeviceCore | Filter 1000 devices by vendor | ~8ms | ~29ms | **3.6x** |
| DeviceCore | Group 1000 devices by manufacturer | ~12ms | ~70ms | **5.8x** |
| CacheCore | Cache operations | ~0.1ms | ~0.2ms | **2x** |
| GraphCore | Batch API requests | TBD | TBD | TBD |

## References

- Full documentation: `docs/DLL_LOADING_DIAGNOSTICS.md`
- Integration guide: `docs/CSHARP_DLL_INTEGRATION_GUIDE.md`
- Source code: `functions/utilityFunctions/Initialize-AutopilotDlls.ps1`
