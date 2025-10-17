# Troubleshooting Guide - Autopilot C# DLLs

**Last Updated**: October 17, 2025

## Overview

This guide helps diagnose and resolve common issues with Autopilot C# DLL loading, building, and runtime errors.

## Quick Diagnostics

### Check DLL Status

```powershell
# Load DLLs
. "$PSScriptRoot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1"
$global:AutopilotDllStatus = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"

# Display detailed status
Show-DllLoadStatus -Status $global:AutopilotDllStatus -ShowErrors

# Check individual components
$global:AutopilotDllStatus | Format-List
```

### Status Object Structure

The status object returned by `Initialize-AutopilotDlls` contains:

```powershell
@{
    Success          = $true/$false        # Overall success
    LoadedCount      = 0-4                 # Number loaded
    GraphCoreLoaded  = $true/$false        # Graph API status
    DeviceCoreLoaded = $true/$false        # Device filtering status
    CacheCoreLoaded  = $true/$false        # Caching status
    LogCoreLoaded    = $true/$false        # Logging status
    LoadedAssemblies = @("Names")          # Loaded assembly list
    DllPath          = "C:\path"           # Search path
    Errors           = @(...)              # Error details array
}
```

### Error Detail Structure

Each error includes:

```powershell
@{
    Dll              = "Autopilot.GraphCore"
    Path             = "C:\full\path\to\dll"
    ErrorType        = "System.IO.FileNotFoundException"
    Message          = "Could not load file or assembly..."
    InnerException   = "Inner error details"
    StackTrace       = "at line 123..."
    Exception        = [Exception object]
    Timestamp        = [DateTime]
    LoaderExceptions = @(...)  # For ReflectionTypeLoadException
}
```

## Common Issues

### Issue 1: DLLs Not Found

**Symptoms**:
```
Error: DLL files not found in path
Success: False
LoadedCount: 0
```

**Causes**:
1. DLLs not built yet
2. Wrong path specified
3. Using wrong framework directory

**Solutions**:

```powershell
# 1. Build DLLs
.\Build-And-Publish-Dlls.ps1 -Configuration Release

# 2. Verify DLL files exist
$psVersion = if ($PSVersionTable.PSVersion.Major -ge 6) { "net9.0" } else { "netstandard2.0" }
Test-Path "bin\Release\$psVersion\Autopilot.GraphCore.dll"
Test-Path "bin\Release\$psVersion\Autopilot.DeviceCore.dll"
Test-Path "bin\Release\$psVersion\Autopilot.CacheCore.dll"
Test-Path "bin\Release\$psVersion\Autopilot.LogCore.dll"

# 3. Use correct path in Initialize-AutopilotDlls
$dllPath = Join-Path $PSScriptRoot "bin\Release"
$status = Initialize-AutopilotDlls -DLLPath $dllPath  # Auto-detects framework
```

### Issue 2: Wrong Framework Target

**Symptoms**:
```
ErrorType: System.BadImageFormatException
Message: Could not load file or assembly... incorrect format
```

**Causes**:
- PowerShell 5.1 trying to load net9.0 DLLs
- PowerShell 7+ loading incompatible binary

**Solution**:

```powershell
# Let Initialize-AutopilotDlls auto-detect
$status = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"

# Or manually specify correct framework
$framework = if ($PSVersionTable.PSVersion.Major -ge 6) { "net9.0" } else { "netstandard2.0" }
$dllPath = Join-Path "$PSScriptRoot\bin\Release" $framework
$status = Initialize-AutopilotDlls -DLLPath $dllPath
```

### Issue 3: Missing Dependencies (PowerShell 5.1)

**Symptoms**:
```
ErrorType: System.IO.FileNotFoundException
Message: Could not load file or assembly 'System.Text.Json, Version=8.0.0.0'
```

**Causes**:
- System.Text.Json.dll not in output directory
- Built with `dotnet build` instead of `dotnet publish`

**Solutions**:

```powershell
# 1. Use Build-And-Publish-Dlls.ps1 (includes dependencies)
.\Build-And-Publish-Dlls.ps1 -Configuration Release

# 2. Verify dependencies exist (PowerShell 5.1 only)
Test-Path "bin\Release\netstandard2.0\System.Text.Json.dll"
Test-Path "bin\Release\netstandard2.0\System.Memory.dll"

# 3. Check dependency count
$dllCount = (Get-ChildItem "bin\Release\netstandard2.0\*.dll").Count
# Should be 12 DLLs for netstandard2.0
# Should be 4 DLLs for net9.0
```

### Issue 4: Assembly Already Loaded

**Symptoms**:
```
ErrorType: System.Reflection.ReflectionTypeLoadException
Message: Unable to load one or more of the requested types
```

**Causes**:
- Trying to load same DLL twice
- Different versions of DLL in memory

**Solution**:

```powershell
# Check if already loaded
$alreadyLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | 
    Where-Object { $_.GetName().Name -like "Autopilot.*" }

if ($alreadyLoaded) {
    Write-Host "DLLs already loaded:"
    $alreadyLoaded | ForEach-Object { Write-Host "  - $($_.GetName().Name)" }
    
    # Restart PowerShell session to reload fresh
    Write-Host "Restart PowerShell to reload different version"
} else {
    # Safe to load
    $status = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"
}
```

### Issue 5: .NET SDK Not Found

**Symptoms**:
```
Build fails with "dotnet: command not found"
```

**Solution**:

```powershell
# 1. Check if .NET SDK installed
try {
    dotnet --version
} catch {
    Write-Host "Install .NET SDK 9.0 from: https://dotnet.microsoft.com/download"
}

# 2. Run verification script
.\tools\Verify-DotNetSetup.ps1

# 3. Check PATH environment variable
$env:PATH -split ';' | Where-Object { $_ -like "*dotnet*" }
```

### Issue 6: NuGet Package Restore Failures

**Symptoms**:
```
error NU1301: Unable to load the service index for source
Build fails with missing package references
```

**Solutions**:

```powershell
# 1. Clear NuGet cache
dotnet nuget locals all --clear

# 2. Force restore
dotnet restore Autopilot.sln --force --verbosity detailed

# 3. Check NuGet sources
dotnet nuget list source

# 4. Add official NuGet source if missing
dotnet nuget add source https://api.nuget.org/v3/index.json --name nuget.org

# 5. Check network connectivity
Test-NetConnection -ComputerName api.nuget.org -Port 443
```

See [NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md#troubleshooting) for more NuGet troubleshooting.

### Issue 7: Type Not Found After Loading

**Symptoms**:
```powershell
[Autopilot.GraphCore.GraphHttpClient]
# Returns: Unable to find type [Autopilot.GraphCore.GraphHttpClient]
```

**Causes**:
- DLL loaded but type is in different namespace
- DLL failed to load silently

**Solutions**:

```powershell
# 1. Check DLL actually loaded
$loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | 
    Where-Object { $_.GetName().Name -eq "Autopilot.GraphCore" }

if ($loaded) {
    # List all types in assembly
    $loaded.GetTypes() | Select-Object FullName
} else {
    Write-Host "DLL not loaded - check Initialize-AutopilotDlls errors"
}

# 2. Use full namespace
$type = [Autopilot.GraphCore.GraphHttpClient]
if ($type) {
    Write-Host "Type found: $($type.FullName)"
}
```

### Issue 8: Performance Not Improving

**Symptoms**:
- DLLs load successfully
- Operations still slow

**Causes**:
- Debug build instead of Release
- Not actually using C# code
- Excessive data conversion overhead

**Solutions**:

```powershell
# 1. Verify Release build
Get-ChildItem bin\Release\net9.0\Autopilot.*.dll | Select-Object Name, Length

# Release DLLs should be smaller (optimized)
# Debug DLLs are larger (include debug symbols)

# 2. Verify C# code is being called
if ($global:AutopilotDllStatus.GraphCoreLoaded) {
    Write-Host "Using C# optimization"
} else {
    Write-Host "Falling back to PowerShell - check why DLL didn't load"
}

# 3. Profile both approaches
$psTime = Measure-Command {
    $devices | Where-Object { $_.manufacturer -eq "Dell" }
}

$csTime = Measure-Command {
    [DeviceFilter]::FilterByVendor($devices, $vendors)
}

Write-Host "PowerShell: $($psTime.TotalMilliseconds)ms"
Write-Host "C#: $($csTime.TotalMilliseconds)ms"
Write-Host "Improvement: $([math]::Round($psTime.TotalMilliseconds / $csTime.TotalMilliseconds, 1))x faster"
```

## Diagnostic Tools

### Show-DllLoadStatus Function

```powershell
# Basic status display
Show-DllLoadStatus -Status $global:AutopilotDllStatus

# Show detailed errors
Show-DllLoadStatus -Status $global:AutopilotDllStatus -ShowErrors

# Quiet mode (errors only)
Show-DllLoadStatus -Status $global:AutopilotDllStatus -Quiet
```

**Output Example**:
```
=== C# DLL Load Status ===
Overall Success: YES
DLLs Loaded: 4 of 4
Search Path: C:\code\Autopilot\bin\Release\net9.0

Loaded Assemblies:
  - Autopilot.GraphCore
  - Autopilot.DeviceCore
  - Autopilot.CacheCore
  - Autopilot.LogCore

Component Status:
  Graph API Optimization:  ✅ AVAILABLE
  Device Filtering:        ✅ AVAILABLE
  Directory Caching:       ✅ AVAILABLE
  High-Performance Logging:✅ AVAILABLE
```

### Manual Diagnostic Steps

```powershell
# 1. Check PowerShell version
$PSVersionTable

# 2. Determine expected framework
$expectedFramework = if ($PSVersionTable.PSVersion.Major -ge 6) {
    "net9.0"
} else {
    "netstandard2.0"
}
Write-Host "Expected framework: $expectedFramework"

# 3. Check DLL files
$dllPath = "bin\Release\$expectedFramework"
$dlls = @(
    "Autopilot.GraphCore.dll",
    "Autopilot.DeviceCore.dll",
    "Autopilot.CacheCore.dll",
    "Autopilot.LogCore.dll"
)

foreach ($dll in $dlls) {
    $path = Join-Path $dllPath $dll
    if (Test-Path $path) {
        $file = Get-Item $path
        Write-Host "[OK] $dll ($($file.Length / 1KB) KB)"
    } else {
        Write-Host "[MISSING] $dll"
    }
}

# 4. Try manual load
foreach ($dll in $dlls) {
    $path = Join-Path $dllPath $dll
    try {
        Add-Type -Path $path -ErrorAction Stop
        Write-Host "[LOADED] $dll"
    } catch {
        Write-Host "[FAILED] $dll - $($_.Exception.Message)"
    }
}

# 5. List loaded assemblies
[System.AppDomain]::CurrentDomain.GetAssemblies() | 
    Where-Object { $_.GetName().Name -like "Autopilot.*" } |
    ForEach-Object {
        Write-Host "Loaded: $($_.GetName().Name) v$($_.GetName().Version)"
    }
```

## Error Messages Reference

### FileNotFoundException
```
Could not load file or assembly 'XXX' or one of its dependencies. 
The system cannot find the file specified.
```

**Causes**:
- DLL file missing
- Dependency DLL missing (System.Text.Json for PS 5.1)
- Wrong framework directory

**Fix**: Build with `Build-And-Publish-Dlls.ps1` to include dependencies

### BadImageFormatException
```
Could not load file or assembly 'XXX'. An attempt was made to load 
a program with an incorrect format.
```

**Causes**:
- 32-bit vs 64-bit mismatch (rare)
- Wrong .NET framework target
- Corrupted DLL file

**Fix**: Use correct framework directory (netstandard2.0 for PS 5.1, net9.0 for PS 7+)

### ReflectionTypeLoadException
```
Unable to load one or more of the requested types. Retrieve the 
LoaderExceptions property for more information.
```

**Causes**:
- Missing dependency DLLs
- Assembly version conflicts
- Trying to reload already-loaded assembly

**Fix**: Check `LoaderExceptions` property in error details, restart PowerShell session

### TypeLoadException
```
Could not load type 'XXX' from assembly 'YYY'.
```

**Causes**:
- Type renamed or moved
- Namespace mismatch
- Using wrong version of DLL

**Fix**: Rebuild DLLs, ensure using latest version

## PowerShell 5.1 Specific Issues

### Issue: System.Runtime Not Found

**Error**:
```
Could not load file or assembly 'System.Runtime, Version=9.0.0.0'
```

**Cause**: DLL compiled for net9.0 instead of netstandard2.0

**Fix**:
```powershell
# Verify multi-targeting in .csproj
<TargetFrameworks>netstandard2.0;net9.0</TargetFrameworks>

# Rebuild with correct target
.\Build-And-Publish-Dlls.ps1 -Configuration Release

# Verify netstandard2.0 DLLs exist
Test-Path "bin\Release\netstandard2.0\*.dll"
```

### Issue: JSON Serialization Fails

**Error**:
```
Could not load file or assembly 'System.Text.Json'
```

**Cause**: System.Text.Json dependency not deployed

**Fix**:
```powershell
# Use Build-And-Publish-Dlls.ps1 (not Build-NativeDlls.ps1)
.\Build-And-Publish-Dlls.ps1 -Configuration Release

# Verify System.Text.Json.dll exists
Test-Path "bin\Release\netstandard2.0\System.Text.Json.dll"  # Should be True
```

See [PS51_COMPATIBILITY.md](PS51_COMPATIBILITY.md) for more PowerShell 5.1 details.

## Build Issues

### Issue: Build Fails with Compilation Errors

**Check**:
```powershell
# Verbose build to see full errors
.\Build-NativeDlls.ps1 -Verbose -Configuration Release

# Or manually
dotnet build Autopilot.sln --verbosity detailed
```

**Common Fixes**:
- Update .NET SDK: `dotnet --version` (should be 9.0+)
- Clean and rebuild: `.\Build-NativeDlls.ps1 -Clean`
- Check for syntax errors in C# code

### Issue: Build Succeeds but Output Missing

**Check**:
```powershell
# Verify output directories created
Test-Path "bin\Release\netstandard2.0"
Test-Path "bin\Release\net9.0"

# Count DLL files
(Get-ChildItem "bin\Release\netstandard2.0\*.dll").Count  # Should be 12
(Get-ChildItem "bin\Release\net9.0\*.dll").Count          # Should be 4
```

**Fix**: Use `Build-And-Publish-Dlls.ps1` instead of `Build-NativeDlls.ps1` for complete output

## Getting Help

### Collect Diagnostic Information

```powershell
# 1. Create diagnostic report
$diagnostics = @{
    PowerShellVersion = $PSVersionTable.PSVersion
    DotNetVersion = (dotnet --version)
    DLLStatus = $global:AutopilotDllStatus
    LoadedAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies() | 
        Where-Object { $_.GetName().Name -like "Autopilot.*" } |
        ForEach-Object { $_.GetName().Name }
    DLLFiles = Get-ChildItem "bin\Release\*\*.dll" | Select-Object FullName, Length
}

# 2. Export to file
$diagnostics | ConvertTo-Json -Depth 10 | Out-File "dll-diagnostics.json"

# 3. Display errors
if ($global:AutopilotDllStatus.Errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    $global:AutopilotDllStatus.Errors | Format-List
}
```

### Support Checklist

When asking for help, provide:
- [ ] PowerShell version (`$PSVersionTable`)
- [ ] .NET SDK version (`dotnet --version`)
- [ ] DLL status output (`Show-DllLoadStatus -ShowErrors`)
- [ ] Build script used
- [ ] Output directory contents
- [ ] Full error messages
- [ ] Steps to reproduce

## Advanced Troubleshooting

### Enable Fusion Logging (Windows)

Track detailed assembly loading events:

```powershell
# Enable fusion logging (requires admin)
New-Item -Path "HKLM:\Software\Microsoft\Fusion" -Force
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Fusion" -Name "LogFailures" -Value 1
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Fusion" -Name "LogPath" -Value "C:\FusionLogs"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Fusion" -Name "ForceLog" -Value 1

# Create log directory
New-Item -Path "C:\FusionLogs" -ItemType Directory -Force

# Try loading DLLs
$status = Initialize-AutopilotDlls -DLLPath "$PSScriptRoot\bin\Release"

# Check logs
Get-ChildItem "C:\FusionLogs" | Sort-Object LastWriteTime -Descending | Select-Object -First 10

# Disable fusion logging when done
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Fusion" -Name "LogFailures"
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Fusion" -Name "LogPath"
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Fusion" -Name "ForceLog"
```

### Check Assembly Dependencies

```powershell
# Use ILSpy or similar tool to inspect DLL dependencies
# Or use PowerShell reflection:

$assembly = [System.Reflection.Assembly]::LoadFile(
    "C:\full\path\to\Autopilot.GraphCore.dll"
)

$assembly.GetReferencedAssemblies() | ForEach-Object {
    Write-Host "$($_.Name) v$($_.Version)"
}
```

## Related Documentation

- **[DLL_REFERENCE.md](DLL_REFERENCE.md)** - Usage and API reference
- **[BUILD_GUIDE.md](BUILD_GUIDE.md)** - Building and compilation
- **[NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md)** - Package management
- **[PS51_COMPATIBILITY.md](PS51_COMPATIBILITY.md)** - PowerShell 5.1 specifics

## References

- [.NET Assembly Loading](https://learn.microsoft.com/en-us/dotnet/core/dependency-loading/overview)
- [Fusion Log Viewer](https://learn.microsoft.com/en-us/dotnet/framework/tools/fuslogvw-exe-assembly-binding-log-viewer)
- [Add-Type Cmdlet](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type)
