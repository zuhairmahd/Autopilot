# PowerShell 5.1 DLL Loading Failure - Root Cause Analysis

## Date: October 17, 2025

##Issue Summary

C# DLLs compiled for the Autopilot project load successfully under PowerShell 7+ but fail under PowerShell 5.1 with `ReflectionTypeLoadException`.

## Root Cause

**Target Framework Incompatibility**

- **Problem**: DLLs were compiled targeting `net9.0` framework
- **PowerShell 7+**: Runs on .NET Core/.NET 5+/6+/7+/8+/9+ → Has `System.Runtime 9.0.0.0` ✅
- **PowerShell 5.1**: Runs on .NET Framework 4.8 (max) → Does NOT have `System.Runtime 9.0.0.0` ❌

### Error Details (from errors.json)

```
System.IO.FileNotFoundException: Could not load file or assembly 
'System.Runtime, Version=9.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a' 
or one of its dependencies. The system cannot find the file specified.
```

**Error Type**: `System.Reflection.ReflectionTypeLoadException`  
**Affected DLLs**: All three (GraphCore, DeviceCore, CacheCore)  
**Loader Exceptions**: 14 instances of `FileNotFoundException` for `System.Runtime 9.0.0.0`

## Solution: Multi-Targeting

### Approach

Change from single-target (`net9.0`) to multi-target (`netstandard2.0;net9.0`):

- **netstandard2.0**: Compatible with:
  - .NET Framework 4.7.2+  (PowerShell 5.1)
  - .NET Core 2.0+
  - .NET 5+/6+/7+/8+/9+

- **net9.0**: Optimized for:
  - .NET 9.0 (PowerShell 7.5+)
  - Access to latest C# features

### Implementation Steps

#### 1. Update Project Files

**Before** (Autopilot.*.csproj):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
```

**After** (Multi-targeting):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>netstandard2.0;net9.0</TargetFrameworks>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <!-- Conditional ImplicitUsings only for net9.0 -->
  <PropertyGroup Condition="'$(TargetFramework)' == 'net9.0'">
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
```

**Key Changes**:
- `<TargetFramework>` → `<TargetFrameworks>` (plural)
- Value: `net9.0` → `netstandard2.0;net9.0`
- Added `<LangVersion>latest</LangVersion>` for C# 12 features in netstandard2.0
- Conditional `ImplicitUsings` (only supported in net9.0)

#### 2. Add System.Text.Json for GraphCore (netstandard2.0)

GraphCore uses `System.Text.Json` which is not included in netstandard2.0 by default.

Add to `Autopilot.GraphCore.csproj`:
```xml
  <ItemGroup Condition="'$(TargetFramework)' == 'netstandard2.0'">
    <PackageReference Include="System.Text.Json" Version="8.0.0" />
  </ItemGroup>
```

#### 3. Configure NuGet Source

```powershell
# Add official NuGet source if missing
dotnet nuget add source https://api.nuget.org/v3/index.json --name nuget.org
```

#### 4. Rebuild DLLs

```powershell
# Build multi-targeted DLLs
.\Build-NativeDlls.ps1 -Configuration Release
```

This creates:
```
bin/Release/
  netstandard2.0/
    Autopilot.GraphCore.dll
    Autopilot.DeviceCore.dll
    Autopilot.CacheCore.dll
  net9.0/
    Autopilot.GraphCore.dll
    Autopilot.DeviceCore.dll
    Autopilot.CacheCore.dll
```

#### 5. Update DLL Loader (Initialize-AutopilotDlls.ps1)

Enhance loader to detect PowerShell version and load appropriate DLL:

```powershell
# Detect PowerShell version and select appropriate DLL path
$psVersion = $PSVersionTable.PSVersion.Major
$targetFramework = if ($psVersion -ge 7) {
    "net9.0"  # PowerShell 7+ uses .NET 9
} else {
    "netstandard2.0"  # PowerShell 5.1 uses .NET Framework 4.x
}

$dllFile = Join-Path $DLLPath $targetFramework "$($dll.Name).dll"
```

### Build Output Structure

After multi-targeting build:

```
bin/Release/
├── netstandard2.0/          # For PowerShell 5.1
│   ├── Autopilot.GraphCore.dll
│   ├── Autopilot.DeviceCore.dll
│   ├── Autopilot.CacheCore.dll
│   └── *.deps.json files
└── net9.0/                  # For PowerShell 7+
    ├── Autopilot.GraphCore.dll
    ├── Autopilot.DeviceCore.dll
    ├── Autopilot.CacheCore.dll
    └── *.deps.json files
```

## Testing Under PowerShell 5.1

### Command Pattern

```powershell
# Execute scripts under PowerShell 5.1
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "<script>"

# Example: Test DLL loading
powershell.exe -ExecutionPolicy Bypass -Command ". .\functions\utilityFunctions\Initialize-AutopilotDlls.ps1; Initialize-AutopilotDlls -DLLPath 'bin\Release' -Verbose"
```

### Verification Steps

1. **Check PowerShell Version**:
   ```powershell
   powershell.exe -Command "$PSVersionTable"
   # Should show PSVersion 5.1.x
   # CLRVersion 4.0.30319.x
   ```

2. **Test DLL Load**:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -Command ". .\functions\utilityFunctions\Initialize-AutopilotDlls.ps1; $status = Initialize-AutopilotDlls -DLLPath 'bin\Release\netstandard2.0'; $status | ConvertTo-Json"
   ```

3. **Expected Result**:
   ```json
   {
     "Success": true,
     "LoadedCount": 3,
     "GraphCoreLoaded": true,
     "DeviceCoreLoaded": true,
     "CacheCoreLoaded": true,
     "Errors": []
   }
   ```

## Known Issues During Implementation

### Issue 1: NuGet Package Restore Failure

**Error**:
```
error NU1100: Unable to resolve 'NETStandard.Library (>= 2.0.3)' for '.NETStandard,Version=v2.0'
```

**Root Cause**: No NuGet sources configured

**Solution**:
```powershell
dotnet nuget add source https://api.nuget.org/v3/index.json --name nuget.org
dotnet nuget locals all --clear  # Clear cache if needed
```

### Issue 2: DLL File Locking

**Error**:
```
error MSB3027: Could not copy "obj\Release\netstandard2.0\Autopilot.*.dll" 
to "bin\Release\Autopilot.*.dll". Exceeded retry count of 10. 
Failed. The file is locked by: "PowerShell 7 (24964)"
```

**Root Cause**: PowerShell has already loaded the DLLs (via `Add-Type`), preventing overwrite

**Solution**:
```powershell
# Close/restart PowerShell session before rebuilding
# Or use a new terminal
```

### Issue 3: System.Text.Json Missing in netstandard2.0

**Error**:
```
error CS0234: The type or namespace name 'Json' does not exist 
in the namespace 'System.Text'
```

**Root Cause**: `System.Text.Json` not included in netstandard2.0 by default

**Solution**: Add package reference for netstandard2.0 target only
```xml
<ItemGroup Condition="'$(TargetFramework)' == 'netstandard2.0'">
  <PackageReference Include="System.Text.Json" Version="8.0.0" />
</ItemGroup>
```

## Performance Impact

| Scenario | Framework | Performance | Compatibility |
|----------|-----------|-------------|---------------|
| PS 5.1 | netstandard2.0 | ⚡ Good | ✅ Full |
| PS 7+ | net9.0 | ⚡⚡⚡ Optimal | ✅ Full |
| PS 7+ | netstandard2.0 | ⚡⚡ Very Good | ✅ Full |

**Note**: Both frameworks provide significant performance improvements over PowerShell. net9.0 may have slight edge due to newer runtime optimizations.

## Files Modified

1. `src/Autopilot.GraphCore/Autopilot.GraphCore.csproj`
2. `src/Autopilot.DeviceCore/Autopilot.DeviceCore.csproj`
3. `src/Autopilot.CacheCore/Autopilot.CacheCore.csproj`
4. `functions/utilityFunctions/Initialize-AutopilotDlls.ps1` (to be updated)
5. `Build-NativeDlls.ps1` (may need updates for multi-target copy)

## References

- **.NET Standard**: https://learn.microsoft.com/en-us/dotnet/standard/net-standard
- **Multi-targeting**: https://learn.microsoft.com/en-us/dotnet/standard/frameworks
- **PowerShell Host**: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell
- **System.Text.Json**: https://learn.microsoft.com/en-us/dotnet/api/system.text.json

## Next Steps

1. ✅ Identify root cause (net9.0 incompatibility)
2. ✅ Update .csproj files for multi-targeting
3. ✅ Configure NuGet source
4. ⏳ Add System.Text.Json package to GraphCore
5. ⏳ Update Initialize-AutopilotDlls.ps1 for framework detection
6. ⏳ Update Build-NativeDlls.ps1 for multi-target copy
7. ⏳ Rebuild DLLs successfully
8. ⏳ Test under PowerShell 5.1
9. ⏳ Test under PowerShell 7+
10. ⏳ Update documentation

## Conclusion

The DLL loading failure under PowerShell 5.1 was caused by target framework incompatibility. Multi-targeting to `netstandard2.0` (PS 5.1) and `net9.0` (PS 7+) provides compatibility across all PowerShell versions while maintaining optimal performance.

**Key Takeaway**: When building .NET libraries for PowerShell consumption, always consider PowerShell 5.1 compatibility by targeting netstandard2.0 alongside modern frameworks.
