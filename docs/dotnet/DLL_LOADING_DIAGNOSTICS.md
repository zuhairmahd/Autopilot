# DLL Loading Diagnostics Guide

## Overview

The Autopilot C# DLL loading system has been enhanced with comprehensive diagnostic capabilities to help troubleshoot loading issues and understand the performance optimization status.

## Enhanced Initialize-AutopilotDlls Function

### Return Value Structure

The function now returns a detailed hashtable with the following properties:

```powershell
@{
    Success          = $true/$false  # True if all 3 DLLs loaded
    GraphCoreLoaded  = $true/$false  # Graph API optimization status
    DeviceCoreLoaded = $true/$false  # Device filtering optimization status
    CacheCoreLoaded  = $true/$false  # Caching optimization status
    LoadedCount      = 0-3           # Number of DLLs successfully loaded
    Errors           = @()           # Array of error details (see below)
    DllPath          = "path"        # Path that was searched
    LoadedAssemblies = @()           # Array of loaded assembly names
}
```

### Error Detail Structure

Each error in the `Errors` array contains:

```powershell
@{
    Dll              = "Autopilot.GraphCore"           # DLL name that failed
    Path             = "C:\path\to\dll"                # Full path attempted
    ErrorType        = "Exception.Type.FullName"       # .NET exception type
    Message          = "Error description"             # Error message
    InnerException   = "Inner error details"           # Inner exception message (if any)
    StackTrace       = "Stack trace"                   # PowerShell stack trace
    Exception        = [Exception]                     # Full exception object
    Timestamp        = [DateTime]                      # When error occurred
    LoaderExceptions = @()                             # ReflectionTypeLoadException details (if applicable)
}
```

## Usage Examples

### Basic Usage

```powershell
# Initialize DLLs
$status = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"

# Check overall success
if ($status.Success) {
    Write-Host "All performance optimizations enabled" -ForegroundColor Green
} elseif ($status.LoadedCount -gt 0) {
    Write-Host "Partial optimizations enabled ($($status.LoadedCount)/3)" -ForegroundColor Yellow
} else {
    Write-Host "Using PowerShell fallback implementations" -ForegroundColor Yellow
}
```

### Checking Specific Components

```powershell
# Use C# cache if available
if ($status.CacheCoreLoaded) {
    # Use [DirectoryObjectCache] class
} else {
    # Use PowerShell hashtable
}

# Use C# device filtering if available
if ($status.DeviceCoreLoaded) {
    # Call DeviceFilter static methods
} else {
    # Use PowerShell Where-Object
}
```

### Diagnostic Display

```powershell
# Simple status display
Show-DllLoadStatus -DllStatus $status

# Detailed error information
Show-DllLoadStatus -DllStatus $status -ShowErrors

# Quiet mode (errors only)
Show-DllLoadStatus -DllStatus $status -Quiet
```

### Error Analysis

```powershell
# Check for errors
if ($status.Errors.Count -gt 0) {
    Write-Host "Encountered $($status.Errors.Count) error(s):" -ForegroundColor Red
    
    foreach ($errorDetail in $status.Errors) {
        Write-Host "  DLL: $($errorDetail.Dll)"
        Write-Host "  Type: $($errorDetail.ErrorType)"
        Write-Host "  Message: $($errorDetail.Message)"
        
        # Check for specific error types
        if ($errorDetail.ErrorType -eq "PathNotFound") {
            Write-Host "  => DLL files need to be built (run Build-NativeDlls.ps1)"
        } elseif ($errorDetail.ErrorType -like "*FileNotFoundException*") {
            Write-Host "  => DLL file is missing from expected location"
        } elseif ($errorDetail.ErrorType -like "*ReflectionTypeLoadException*") {
            Write-Host "  => Dependency issue - check .deps.json files"
            # Show loader exceptions
            $errorDetail.LoaderExceptions | ForEach-Object {
                Write-Host "    Loader: $($_.Message)"
            }
        }
    }
}
```

## Common Error Scenarios

### 1. DLL Directory Not Found

**Symptom:**
```
Error Type: PathNotFound
Message: DLL directory not found: C:\path\to\bin\Release
```

**Solution:**
- Run `Build-NativeDlls.ps1` to compile the C# projects
- Or run `CreateRelease.ps1 -Stage Build` which includes DLL compilation

### 2. DLL File Not Found

**Symptom:**
```
Error Type: FileNotFound
Message: DLL file not found: C:\path\to\Autopilot.GraphCore.dll
```

**Solution:**
- Run `Build-NativeDlls.ps1 -Configuration Release`
- Verify all 3 DLLs exist in the bin\Release folder

### 3. ReflectionTypeLoadException

**Symptom:**
```
Error Type: System.Reflection.ReflectionTypeLoadException
LoaderExceptions: Could not load file or assembly 'System.Runtime'
```

**Solution:**
- Check that .NET SDK 9.0 is installed
- Verify .deps.json files are present alongside DLLs
- Ensure correct target framework (net9.0) in .csproj files

### 4. Assembly Already Loaded

**Note:** This is not an error - the function handles it gracefully:

```
VERBOSE: Assembly Autopilot.GraphCore already loaded in AppDomain
VERBOSE: Using existing Autopilot.GraphCore assembly
```

The function detects when assemblies are already loaded and reuses them.

## Troubleshooting Workflow

### Step 1: Enable Verbose Output

```powershell
$VerbosePreference = 'Continue'
$status = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release" -Verbose
```

### Step 2: Display Diagnostic Information

```powershell
Show-DllLoadStatus -DllStatus $status -ShowErrors
```

### Step 3: Analyze Error Details

```powershell
# Export error details for analysis
$status.Errors | ConvertTo-Json -Depth 5 | Out-File "dll-errors.json"

# Check specific error types
$status.Errors | Group-Object ErrorType | Format-Table Count, Name
```

### Step 4: Verify DLL Files

```powershell
# Check if DLLs exist
$dllPath = "C:\Users\zuhai\code\Autopilot\bin\Release"
@("Autopilot.GraphCore", "Autopilot.DeviceCore", "Autopilot.CacheCore") | ForEach-Object {
    $file = Join-Path $dllPath "$_.dll"
    [PSCustomObject]@{
        DLL    = $_
        Exists = Test-Path $file
        Size   = if (Test-Path $file) { (Get-Item $file).Length } else { "N/A" }
    }
} | Format-Table -AutoSize
```

### Step 5: Test Manual Load

```powershell
# Try loading DLLs manually to see raw errors
try {
    Add-Type -Path "$dllPath\Autopilot.CacheCore.dll" -ErrorAction Stop
    Write-Host "Manual load successful"
} catch {
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Message: $($_.Exception.Message)"
    Write-Host "Inner: $($_.Exception.InnerException.Message)"
}
```

## Integration with main.ps1

The main application initialization now includes:

```powershell
# Initialize C# DLLs
$global:AutopilotDllStatus = Initialize-AutopilotDlls -DLLPath "$scriptPath\bin\Release" -Verbose

# Display status based on results
if ($global:AutopilotDllStatus.Success) {
    Write-Host "Performance DLLs loaded: $($global:AutopilotDllStatus.LoadedAssemblies -join ', ')" -ForegroundColor Green
} elseif ($global:AutopilotDllStatus.LoadedCount -gt 0) {
    Write-Host "Performance DLLs partially loaded ($($global:AutopilotDllStatus.LoadedCount)/3)" -ForegroundColor Yellow
} else {
    Write-Host "Using PowerShell implementations (DLLs not found)" -ForegroundColor Yellow
}

# Show detailed errors in verbose mode
if ($VerbosePreference -eq 'Continue' -and $global:AutopilotDllStatus.Errors.Count -gt 0) {
    Show-DllLoadStatus -DllStatus $global:AutopilotDllStatus -ShowErrors
}
```

## Performance Impact

| Scenario | Performance | Functionality |
|----------|-------------|---------------|
| All 3 DLLs loaded | ✅ Optimal (3-6x faster) | ✅ Full |
| 1-2 DLLs loaded | ⚡ Partial optimization | ✅ Full |
| 0 DLLs loaded | ⏱️ Standard PowerShell | ✅ Full |

**Key Point:** DLL loading failures do not impact functionality - the tool gracefully falls back to PowerShell implementations.

## CI/CD Integration

GitHub workflows now build DLLs automatically:

```yaml
- name: Setup .NET SDK
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '9.0.x'

- name: Build C# DLLs
  shell: pwsh
  run: |
    .\Build-NativeDlls.ps1 -Configuration Release
```

If DLL build fails in CI/CD, tests still run with PowerShell fallback.

## Best Practices

1. **Always check `LoadedCount`** - Don't assume all-or-nothing loading
2. **Use component-specific flags** - Check `CacheCoreLoaded` when using cache features
3. **Enable verbose logging** during troubleshooting
4. **Export error details** for complex issues (`ConvertTo-Json`)
5. **Don't fail hard** - DLL loading errors should not stop the application
6. **Log errors** - Use `Show-DllLoadStatus` or custom logging
7. **Test fallback paths** - Ensure PowerShell implementations work

## Related Files

- `functions/utilityFunctions/Initialize-AutopilotDlls.ps1` - DLL loader
- `functions/utilityFunctions/Show-DllLoadStatus.ps1` - Diagnostic display
- `Build-NativeDlls.ps1` - DLL compilation script
- `main.ps1` - Application initialization
- `docs/CSHARP_DLL_INTEGRATION_GUIDE.md` - Integration patterns

## Support

For issues with DLL loading:

1. Review verbose output from `Initialize-AutopilotDlls -Verbose`
2. Run `Show-DllLoadStatus -ShowErrors`
3. Check `docs/CSHARP_DLL_INTEGRATION_GUIDE.md`
4. Verify .NET SDK 9.0 is installed: `dotnet --version`
5. Rebuild DLLs: `.\Build-NativeDlls.ps1 -Configuration Release`
