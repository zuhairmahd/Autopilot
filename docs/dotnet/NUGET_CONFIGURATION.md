# NuGet Package Configuration

## Overview
This document describes the NuGet package management configuration for the Autopilot C# DLL projects.

## Configuration Files

### nuget.config
Located in the repository root, this file configures NuGet package sources and behavior:

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

**Key Settings:**
- **Package Source**: Official NuGet.org v3 API endpoint
- **Package Source Mapping**: All packages (`*`) are sourced from nuget.org
- **Global Packages Folder**: `.nuget/packages` (local to repository, gitignored)

## Build Process

### Automatic Restore
Both build scripts now include automatic NuGet package restoration:

1. **Build-NativeDlls.ps1** - Restores before building DLLs
2. **Build-And-Publish-Dlls.ps1** - Restores before publishing multi-target DLLs

### Restore Command
The scripts run:
```powershell
dotnet restore Autopilot.sln --verbosity minimal
```

This ensures all required NuGet packages (like `System.Text.Json` for netstandard2.0) are downloaded before compilation.

## Required Packages

### netstandard2.0 Target
- **System.Text.Json** (v8.0.5): Required for JSON serialization on .NET Standard 2.0 (built into net9.0)

### Package References
Defined in each `.csproj` file with conditional references:

```xml
<ItemGroup Condition="'$(TargetFramework)' == 'netstandard2.0'">
  <PackageReference Include="System.Text.Json" Version="8.0.5" />
</ItemGroup>
```

## CI/CD Integration

All GitHub Actions workflows automatically restore packages via the build scripts:
- **pr-checks.yml**: Unit tests with coverage
- **target-build.yml**: Target-specific builds
- **release.yml**: Release builds
- **publish.yml**: Publishing workflows

No additional workflow steps required—restoration is built into the PowerShell build scripts.

## Troubleshooting

### Package Restore Failures
If restore fails:

1. **Check network connectivity** to nuget.org
2. **Verify .NET SDK version**: Requires .NET 9.0+ SDK
3. **Clear NuGet cache**:
   ```powershell
   dotnet nuget locals all --clear
   ```
4. **Manual restore**:
   ```powershell
   dotnet restore Autopilot.sln --force
   ```

### Missing Packages
If builds fail with missing assembly errors:

1. **Verify nuget.config exists** in repository root
2. **Check .csproj files** for correct PackageReference elements
3. **Run restore explicitly**:
   ```powershell
   dotnet restore Autopilot.sln --verbosity detailed
   ```

### Local vs CI Differences
The `.nuget/packages` folder is:
- **Gitignored**: Not committed to repository
- **Restored on build**: Downloaded fresh in CI/CD pipelines
- **Cached locally**: Reused across builds on developer machines

## Best Practices

1. **Always commit** `nuget.config` changes to version control
2. **Never commit** `.nuget/packages` folder (managed via .gitignore)
3. **Pin package versions** in .csproj files for reproducible builds
4. **Use minimal verbosity** in CI/CD to reduce log noise
5. **Cache packages** in CI/CD workflows when possible (GitHub Actions caching)

## References
- [NuGet Configuration Reference](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file)
- [Package Source Mapping](https://learn.microsoft.com/en-us/nuget/consume-packages/package-source-mapping)
- [.NET CLI Restore](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-restore)
