# Autopilot C# DLLs - Documentation Index

**Last Updated**: October 17, 2025

## Overview

This directory contains comprehensive documentation for the Autopilot C# DLL performance optimization system.

**🎯 New to DLL Integration?** Start with **[.NET Migration Plan](../DOTNET_MIGRATION_PLAN.md)** for a complete overview of the migration strategy, current progress, and implementation roadmap.

## Documentation Structure

### 📚 Core Guides

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[DLL_REFERENCE.md](DLL_REFERENCE.md)** | Complete usage guide and API reference | Start here - learn how to use the DLLs |
| **[BUILD_GUIDE.md](BUILD_GUIDE.md)** | Building, compilation, multi-targeting | When building or modifying C# code |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Diagnostics and error resolution | When encountering loading or runtime errors |

### 🔧 Specialized Guides

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md)** | NuGet package management | When dealing with dependencies or packages |
| **[PS51_COMPATIBILITY.md](PS51_COMPATIBILITY.md)** | PowerShell 5.1 specifics | When working with PowerShell 5.1 |
| **[LOGCORE_WRAPPER_FUNCTIONS.md](LOGCORE_WRAPPER_FUNCTIONS.md)** | LogCore wrapper functions | When using high-performance logging in PowerShell |

### 🗺️ Planning & Strategy

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[.NET Migration Plan](../DOTNET_MIGRATION_PLAN.md)** | Complete migration roadmap | For understanding overall strategy and next steps |
| **[Archived Migration Docs](../archive/dotnet-migration/README.md)** | Historical documentation | For reference to original planning documents |

## Quick Navigation

### I want to...

**...get started with the DLLs**
→ Read [DLL_REFERENCE.md](DLL_REFERENCE.md) - Quick Start section

**...build the DLLs**
→ Read [BUILD_GUIDE.md](BUILD_GUIDE.md) - Build Scripts section

**...fix a DLL loading error**
→ Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common Issues section

**...understand multi-targeting**
→ Read [BUILD_GUIDE.md](BUILD_GUIDE.md) - Multi-Targeting Architecture section

**...work with PowerShell 5.1**
→ Read [PS51_COMPATIBILITY.md](PS51_COMPATIBILITY.md)

**...configure NuGet packages**
→ Read [NUGET_CONFIGURATION.md](NUGET_CONFIGURATION.md)

**...see performance benchmarks**
→ Read [DLL_REFERENCE.md](DLL_REFERENCE.md) - Performance Benchmarks section

**...use LogCore wrapper functions**
→ Read [LOGCORE_WRAPPER_FUNCTIONS.md](LOGCORE_WRAPPER_FUNCTIONS.md)

**...understand the migration strategy**
→ Read [C# Migration Master Plan](../CSHARP_MIGRATION_MASTER_PLAN.md)

**...add a new DLL project**
→ Read [BUILD_GUIDE.md](BUILD_GUIDE.md) - Adding New DLLs section

## Documentation Standards

### Maintenance

All documentation files follow these standards:
- **Last Updated date** at the top
- **Status indicator** (✅ Production Ready, ⚠️ In Progress, etc.)
- **Cross-references** to related documents
- **Code examples** with expected output
- **Troubleshooting sections** where applicable

### Updating Documentation

When making changes:
1. Update the "Last Updated" date
2. Update relevant sections
3. Verify all cross-references still work
4. Add code examples for new features
5. Update this index if adding new documents

## File Descriptions

### DLL_REFERENCE.md
**Size**: ~400 lines  
**Audience**: Developers using the DLLs  
**Content**:
- Quick start guide
- DLL status object structure
- Usage examples for all 4 DLLs (GraphCore, DeviceCore, CacheCore, LogCore)
- Fallback patterns
- Performance benchmarks
- Compatibility information

### BUILD_GUIDE.md
**Size**: ~600 lines  
**Audience**: Developers building or modifying the DLLs  
**Content**:
- Prerequisites and setup
- Project structure
- Build scripts (Build-NativeDlls.ps1, Build-And-Publish-Dlls.ps1)
- Multi-targeting architecture
- Dependency management
- Manual build commands
- CI/CD integration
- Adding new DLLs

### TROUBLESHOOTING.md
**Size**: ~550 lines  
**Audience**: Anyone encountering errors  
**Content**:
- Quick diagnostics
- Common issues and solutions
- Diagnostic tools (Show-DllLoadStatus)
- Error message reference
- PowerShell 5.1 specific issues
- Advanced troubleshooting (Fusion logging)
- Support checklist

### NUGET_CONFIGURATION.md
**Size**: ~250 lines  
**Audience**: Developers managing dependencies  
**Content**:
- NuGet configuration file structure
- Package restoration process
- Required packages
- CI/CD integration
- Troubleshooting package issues
- Best practices

### PS51_COMPATIBILITY.md
**Size**: ~450 lines  
**Audience**: PowerShell 5.1 users and developers  
**Content**:
- Technical background (.NET Framework 4.8)
- Multi-targeting explanation
- Building for PowerShell 5.1
- Loading DLLs in PowerShell 5.1
- Common PowerShell 5.1 issues
- Testing procedures
- Migration guide to PowerShell 7+

## Related Documentation

### Main Repository Documentation
- **[../README.md](../README.md)** - Main project documentation
- **[../TECHNICAL_DOCUMENTATION.md](../TECHNICAL_DOCUMENTATION.md)** - Technical architecture
- **[../../src/README.md](../../src/README.md)** - C# source code overview

### External Resources
- [.NET Multi-Targeting](https://learn.microsoft.com/en-us/dotnet/standard/frameworks)
- [PowerShell Add-Type](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type)
- [NuGet Documentation](https://learn.microsoft.com/en-us/nuget/)

## Change History

### October 17, 2025
- ✅ Consolidated 10+ documentation files into 5 core guides
- ✅ Removed redundant/outdated content:
  - DLL_LOADING_DIAGNOSTICS.md (merged into TROUBLESHOOTING.md)
  - DLL_STATUS_QUICK_REFERENCE.md (merged into DLL_REFERENCE.md)
  - dll-diagnostic-enhancement-summary.md (historical, removed)
  - dll-integration-complete-summary.md (historical, removed)
  - dll-loading-and-logging-consolidation-complete.md (historical, removed)
  - DLL-QUICK-REFERENCE.md (merged into DLL_REFERENCE.md)
  - DOTNET_COMPILATION_SUMMARY.md (merged into BUILD_GUIDE.md)
  - powershell-5-1-dll-loading-failure-analysis.md (merged into PS51_COMPATIBILITY.md)
  - NUGET_PACKAGE_FIX_SUMMARY.md (historical, removed)
  - NUGET_QUICK_REFERENCE.md (merged into NUGET_CONFIGURATION.md)
- ✅ Created comprehensive guides with cross-references
- ✅ Updated src/README.md with documentation links
- ✅ Created this index file (README.md)

### Previous Documentation
Historical documentation has been archived or consolidated. The current 5-guide structure provides:
- No duplication
- Clear navigation
- Up-to-date information
- Comprehensive coverage

## Contributing

When adding new C# DLL features:
1. Update [DLL_REFERENCE.md](DLL_REFERENCE.md) with usage examples
2. Update [BUILD_GUIDE.md](BUILD_GUIDE.md) if build process changes
3. Add troubleshooting entries to [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if needed
4. Update this index if adding new documentation files

## Feedback

If you find documentation issues:
- Unclear instructions → Note location and what's confusing
- Missing information → Describe what's needed
- Outdated content → Note what has changed
- Broken links → Identify the broken link

Submit issues or pull requests to improve documentation.

## License

Documentation follows the same license as the Autopilot project.
