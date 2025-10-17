# Build Guide - Autopilot C# DLLs

**Last Updated**: October 17, 2025  
**Status**: ✅ Production Ready

## Overview

This guide covers building the Autopilot C# DLLs for both PowerShell 5.1 and PowerShell 7+.

## Prerequisites

### Required Software
- **.NET SDK 9.0+** - Download from https://dotnet.microsoft.com/download
- **PowerShell 5.1 or 7+** - For testing
- **Git** - For source control

### Verify Setup

```powershell
# Check .NET SDK version
dotnet --version
# Expected: 9.0.x or higher

# Check PowerShell version
$PSVersionTable.PSVersion
# Expected: 5.1.x or 7.x+

# Verify .NET runtimes
dotnet --list-runtimes
# Should show both .NET Framework and .NET 9.0 runtimes

# Run verification script
.\tools\Verify-DotNetSetup.ps1
```

## Project Structure

```
Autopilot/
├── src/                                    # C# source code
│   ├── Autopilot.GraphCore/
│   │   ├── GraphHttpClient.cs             # HTTP operations
│   │   ├── BatchProcessor.cs              # Batch processing
│   │   └── Autopilot.GraphCore.csproj     # Project file
│   ├── Autopilot.DeviceCore/
│   │   ├── DeviceFilter.cs                # LINQ filtering
│   │   └── Autopilot.DeviceCore.csproj
│   ├── Autopilot.CacheCore/
│   │   ├── DirectoryObjectCache.cs        # Thread-safe cache
│   │   └── Autopilot.CacheCore.csproj
│   ├── Autopilot.LogCore/
│   │   ├── Logger.cs                      # High-performance logging
│   │   └── Autopilot.LogCore.csproj
│   └── README.md                          # Documentation
├── bin/Release/                           # Compiled output
│   ├── netstandard2.0/                    # PowerShell 5.1 DLLs
│   │   ├── Autopilot.*.dll                # 4 main DLLs
│   │   ├── System.Text.Json.dll           # Dependencies
│   │   ├── System.Memory.dll
│   │   └── ... (12 DLLs total)
│   └── net9.0/                            # PowerShell 7+ DLLs
│       └── Autopilot.*.dll                # 4 DLLs (no separate dependencies)
├── Build-NativeDlls.ps1                   # Multi-target build script
└── nuget.config                           # NuGet configuration
```

## Build Script

### Build-NativeDlls.ps1 (Multi-Target Build)

**Primary build tool**: Handles all build scenarios with multi-target support

```powershell
# Standard release build (both frameworks)
.\Build-NativeDlls.ps1 -Configuration Release

# Debug build with symbols
.\Build-NativeDlls.ps1 -Configuration Debug

# Clean build (removes bin/obj folders first)
.\Build-NativeDlls.ps1 -Clean -Configuration Release

# Verbose output for troubleshooting
.\Build-NativeDlls.ps1 -Verbose -Configuration Release
```

**Output**:
- `bin\Release\netstandard2.0\` - 12+ DLLs (PS 5.1 + all dependencies)
- `bin\Release\net9.0\` - 12+ DLLs (PS 7+ + all dependencies)

**Features**:
- ✅ Multi-target support (netstandard2.0 + net9.0)
- ✅ Includes all NuGet dependencies via `dotnet publish`
- ✅ Auto-discovers all C# projects in `src/`
- ✅ `-Clean` switch for fresh builds
- ✅ `-Verbose` switch for detailed output
- ✅ Works in both PowerShell 5.1 and 7+

**When to use**:
- ✅ All scenarios (development, testing, production)
- ✅ Quick iteration during development
- ✅ Production releases
- ✅ CI/CD pipelines
- ✅ Testing both PowerShell versions

## Multi-Targeting Architecture

### Target Frameworks

All projects use multi-targeting in their `.csproj` files:

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

### Framework Selection

| Framework | Compatible With | Used By |
|-----------|----------------|---------|
| **netstandard2.0** | .NET Framework 4.7.2+, .NET Core 2.0+, .NET 5+ | PowerShell 5.1 |
| **net9.0** | .NET 9.0 only | PowerShell 7.5+ |

### Why Multi-Targeting?

**PowerShell 5.1 (.NET Framework 4.8)**:
- Cannot load assemblies targeting net6.0+
- Requires netstandard2.0 target
- Needs explicit NuGet dependencies (System.Text.Json)

**PowerShell 7+ (.NET 9.0)**:
- Can load both netstandard2.0 and net9.0
- Prefers net9.0 for better performance
- Has dependencies built-in (no separate DLLs needed)

## Dependency Management

### NuGet Configuration

The repository includes `nuget.config` for package management:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
  <config>
    <add key="globalPackagesFolder" value=".nuget/packages" />
  </config>
</configuration>
```

See [NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md) for complete NuGet documentation.

### Package Restoration

Both build scripts automatically restore packages:

```powershell
dotnet restore Autopilot.sln --verbosity minimal
```

### Required Packages

#### Autopilot.GraphCore (netstandard2.0 only)
```xml
<ItemGroup Condition="'$(TargetFramework)' == 'netstandard2.0'">
  <PackageReference Include="System.Text.Json" Version="8.0.5" />
</ItemGroup>
```

**Why**: System.Text.Json is not included in .NET Framework 4.8 but is needed for JSON operations.

#### Other Projects
No external packages required—use only built-in .NET libraries.

## Build Process Details

### What Happens During Build

1. **Package Restore**
   ```
   dotnet restore Autopilot.sln
   ```
   - Downloads NuGet packages to `.nuget/packages/`
   - Reads dependencies from `.csproj` files
   - Creates restore lock files

2. **Compilation** (for each target framework)
   ```
   dotnet build <project.csproj> --configuration Release --framework netstandard2.0
   dotnet build <project.csproj> --configuration Release --framework net9.0
   ```
   - Compiles C# source to IL (Intermediate Language)
   - Creates `.dll` files
   - Generates debug symbols (`.pdb` files in Debug mode)

3. **Publishing** (Build-And-Publish-Dlls.ps1 only)
   ```
   dotnet publish <project.csproj> --configuration Release --framework netstandard2.0 --output bin/Release/netstandard2.0
   dotnet publish <project.csproj> --configuration Release --framework net9.0 --output bin/Release/net9.0
   ```
   - Copies compiled DLLs to output directory
   - Includes all dependencies (for netstandard2.0)
   - Creates self-contained deployment layout

### Build Output

#### netstandard2.0 (PowerShell 5.1)
```
bin\Release\netstandard2.0\
├── Autopilot.GraphCore.dll
├── Autopilot.DeviceCore.dll
├── Autopilot.CacheCore.dll
├── Autopilot.LogCore.dll
├── System.Text.Json.dll          # Dependency
├── System.Memory.dll              # Dependency
├── System.Buffers.dll             # Dependency
├── System.Runtime.CompilerServices.Unsafe.dll
└── ... (12 DLLs total)
```

#### net9.0 (PowerShell 7+)
```
bin\Release\net9.0\
├── Autopilot.GraphCore.dll
├── Autopilot.DeviceCore.dll
├── Autopilot.CacheCore.dll
└── Autopilot.LogCore.dll
(4 DLLs - dependencies built into runtime)
```

## Manual Build Commands

### Single Framework Build

```powershell
# Build only netstandard2.0 (PowerShell 5.1)
dotnet build src/Autopilot.GraphCore/Autopilot.GraphCore.csproj `
    --configuration Release `
    --framework netstandard2.0 `
    --output bin/Release/netstandard2.0

# Build only net9.0 (PowerShell 7+)
dotnet build src/Autopilot.GraphCore/Autopilot.GraphCore.csproj `
    --configuration Release `
    --framework net9.0 `
    --output bin/Release/net9.0
```

### Build All Projects

```powershell
# Using solution file
dotnet build Autopilot.sln --configuration Release

# Publish with dependencies
dotnet publish Autopilot.sln --configuration Release --output bin/Release
```

### Clean Build

```powershell
# Clean all projects
dotnet clean Autopilot.sln

# Or manually remove build artifacts
Remove-Item -Path src/*/bin, src/*/obj, bin -Recurse -Force
```

## Testing Builds

### Verify DLL Loading

```powershell
# Test in current PowerShell version
.\Test-AutopilotDlls.ps1 -Verbose

# Test in both PowerShell 5.1 and 7+
.\Test-AutopilotDlls.ps1 -TestBothVersions
```

### Manual Load Test

```powershell
# PowerShell 5.1
Add-Type -Path "bin\Release\netstandard2.0\Autopilot.GraphCore.dll"
Add-Type -Path "bin\Release\netstandard2.0\Autopilot.DeviceCore.dll"
Add-Type -Path "bin\Release\netstandard2.0\Autopilot.CacheCore.dll"
Add-Type -Path "bin\Release\netstandard2.0\Autopilot.LogCore.dll"

# PowerShell 7+
Add-Type -Path "bin\Release\net9.0\Autopilot.GraphCore.dll"
Add-Type -Path "bin\Release\net9.0\Autopilot.DeviceCore.dll"
Add-Type -Path "bin\Release\net9.0\Autopilot.CacheCore.dll"
Add-Type -Path "bin\Release\net9.0\Autopilot.LogCore.dll"

# Verify types loaded
[Autopilot.GraphCore.GraphHttpClient]
[Autopilot.DeviceCore.DeviceFilter]
[Autopilot.CacheCore.DirectoryObjectCache]
[Autopilot.LogCore.Logger]
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Setup .NET SDK
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: "9.0.x"

- name: Build C# DLLs
  shell: pwsh
  run: |
    .\Build-And-Publish-Dlls.ps1 -Configuration Release

- name: Test DLL Loading
  shell: pwsh
  run: |
    .\Test-AutopilotDlls.ps1 -TestBothVersions
```

### Azure DevOps Example

```yaml
- task: UseDotNet@2
  inputs:
    version: '9.0.x'

- powershell: |
    .\Build-And-Publish-Dlls.ps1 -Configuration Release
  displayName: 'Build C# DLLs'

- powershell: |
    .\Test-AutopilotDlls.ps1 -TestBothVersions
  displayName: 'Test DLL Loading'
```

## Troubleshooting

### Build Failures

**Issue**: "Could not load file or assembly 'System.Text.Json'"
```powershell
# Solution: Clear NuGet cache and restore
dotnet nuget locals all --clear
dotnet restore Autopilot.sln --force
.\Build-And-Publish-Dlls.ps1 -Configuration Release
```

**Issue**: "The type or namespace name 'Json' does not exist"
```powershell
# Solution: Ensure System.Text.Json package reference exists
# Check src/Autopilot.GraphCore/Autopilot.GraphCore.csproj
# Should contain:
# <PackageReference Include="System.Text.Json" Version="8.0.5" />
```

**Issue**: Build succeeds but DLLs won't load
```powershell
# Solution: Verify correct framework directory
# PowerShell 5.1 → bin/Release/netstandard2.0/
# PowerShell 7+  → bin/Release/net9.0/

# Or use Initialize-AutopilotDlls which auto-detects
```

### Package Restore Failures

See [NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md#troubleshooting) for complete troubleshooting.

Quick fixes:
```powershell
# Clear cache
dotnet nuget locals all --clear

# Force restore
dotnet restore Autopilot.sln --force --verbosity detailed

# Check NuGet sources
dotnet nuget list source
```

## Performance Optimization

### Release vs Debug Builds

| Aspect | Debug | Release |
|--------|-------|---------|
| **Optimization** | None | Full IL optimization |
| **Symbols** | Full (.pdb) | Portable or none |
| **Size** | Larger | Smaller |
| **Performance** | Slower | 2-5x faster |
| **Use Case** | Development | Production |

**Recommendation**: Always use Release builds for production and performance testing.

### Build Performance Tips

1. **Use solution-level builds** - Faster than individual project builds
2. **Skip tests during build** - Use `--no-build` flag for test runs
3. **Parallel builds** - .NET SDK automatically parallelizes
4. **Incremental builds** - Only rebuild changed projects

```powershell
# Fast incremental build
dotnet build Autopilot.sln --configuration Release --no-restore

# Full clean build
dotnet clean Autopilot.sln
dotnet build Autopilot.sln --configuration Release
```

## Adding New DLLs

To add a new C# DLL project:

1. **Create Project**
   ```powershell
   cd src
   dotnet new classlib -n Autopilot.NewCore -f net9.0
   ```

2. **Configure Multi-Targeting**
   Edit `src/Autopilot.NewCore/Autopilot.NewCore.csproj`:
   ```xml
   <TargetFrameworks>netstandard2.0;net9.0</TargetFrameworks>
   ```

3. **Add to Solution**
   ```powershell
   dotnet sln add src/Autopilot.NewCore/Autopilot.NewCore.csproj
   ```

4. **Update Build Scripts**
   Add to `$projects` array in both build scripts:
   ```powershell
   $projects = @(
       'Autopilot.GraphCore',
       'Autopilot.DeviceCore',
       'Autopilot.CacheCore',
       'Autopilot.LogCore',
       'Autopilot.NewCore'  # New project
   )
   ```

5. **Update Initialize-AutopilotDlls.ps1**
   Add new DLL to loading logic

6. **Build and Test**
   ```powershell
   .\Build-And-Publish-Dlls.ps1 -Configuration Release
   .\Test-AutopilotDlls.ps1 -Verbose
   ```

## Related Documentation

- **[DLL_REFERENCE.md](DLL_REFERENCE.md)** - Usage and API reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Diagnostic guides
- **[NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md)** - Package management
- **[PS51_COMPATIBILITY.md](PS51_COMPATIBILITY.md)** - PowerShell 5.1 specifics

## References

- [.NET Multi-Targeting](https://learn.microsoft.com/en-us/dotnet/standard/frameworks)
- [.NET Standard Compatibility](https://learn.microsoft.com/en-us/dotnet/standard/net-standard)
- [dotnet build Command](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-build)
- [dotnet publish Command](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-publish)
