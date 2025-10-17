# NuGet Quick Reference

## Build Commands

### Standard Build (with auto-restore)
```powershell
.\Build-NativeDlls.ps1 -Configuration Release
```

### Multi-Target Publish (with auto-restore)
```powershell
.\Build-And-Publish-Dlls.ps1 -Configuration Release
```

### Clean Build
```powershell
.\Build-NativeDlls.ps1 -Clean -Configuration Release
```

## Manual Package Management

### Restore Packages
```powershell
dotnet restore Autopilot.sln
```

### Clear Package Cache
```powershell
dotnet nuget locals all --clear
```

### Force Restore
```powershell
dotnet restore Autopilot.sln --force
```

### Restore with Verbose Output
```powershell
dotnet restore Autopilot.sln --verbosity detailed
```

## Package Locations

| Item | Location | Committed? |
|------|----------|------------|
| Configuration | `nuget.config` | ✅ Yes |
| Local Cache | `.nuget/packages/` | ❌ No (gitignored) |
| Project Files | `src/**/*.csproj` | ✅ Yes |

## Current Dependencies

| Package | Version | Target | Purpose |
|---------|---------|--------|---------|
| System.Text.Json | 8.0.5 | netstandard2.0 | JSON serialization for PS 5.1 |

## Troubleshooting

### Build fails with "package not found"
```powershell
dotnet nuget locals all --clear
dotnet restore Autopilot.sln --force
.\Build-NativeDlls.ps1 -Clean
```

### Restore fails with network error
1. Check internet connection
2. Verify nuget.org is accessible
3. Check corporate firewall/proxy settings

### Wrong package version downloaded
```powershell
# Clear cache and restore
dotnet nuget locals all --clear
dotnet restore Autopilot.sln --force
```

## CI/CD Notes

- ✅ All workflows automatically restore packages via build scripts
- ✅ No manual restore steps needed in workflow files
- ✅ GitHub Actions may cache packages for faster builds
- ✅ First build may take longer (downloading packages)

## Adding New Packages

1. Edit appropriate `.csproj` file:
   ```xml
   <ItemGroup>
     <PackageReference Include="PackageName" Version="1.0.0" />
   </ItemGroup>
   ```

2. Run restore:
   ```powershell
   dotnet restore Autopilot.sln
   ```

3. Build to verify:
   ```powershell
   .\Build-NativeDlls.ps1 -Configuration Release
   ```

## Configuration File

**Location**: `nuget.config` (repository root)

**Package Source**: https://api.nuget.org/v3/index.json

**Local Cache**: `.nuget/packages`

## Best Practices

✅ **DO**:
- Commit `nuget.config` changes
- Pin package versions in `.csproj`
- Use build scripts (auto-restore)
- Clear cache if build issues occur

❌ **DON'T**:
- Commit `.nuget/packages/` folder
- Use floating package versions
- Manually download packages
- Skip restore before building

## Help Resources

- Full documentation: `docs/NUGET_CONFIGURATION.md`
- Fix summary: `docs/NUGET_PACKAGE_FIX_SUMMARY.md`
- .NET CLI reference: https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-restore
