# C# Migration Quick Reference

**📍 START HERE**: [C# Migration Master Plan](CSHARP_MIGRATION_MASTER_PLAN.md)

## Current Status (October 17, 2025)

| Phase | Status | Impact |
|-------|--------|--------|
| Phase 1: Infrastructure | ✅ 100% | 4 DLLs, build system, testing |
| Phase 2: Initial Integrations | ✅ 100% | Caching, logging, initialization |
| Phase 3: High-Yield Integrations | ⚪ 0% | Device filtering, Graph batching |
| **Overall Progress** | **60%** | **15-20% speedup achieved** |

## Performance Improvements Achieved

- ✅ **Logging**: 10-20x faster (LogCore.dll - **INTEGRATED into Write-Log**)
- ✅ **Device Filtering**: 3.6x faster (DeviceCore.dll - helper ready)
- ✅ **Device Grouping**: 5.8x faster (DeviceCore.dll - helper ready)
- ✅ **Caching**: Thread-safe + LRU (CacheCore.dll - integrated)

## Next Priorities (Phase 3)

### 1. Device Filtering Integration (1-2 hours)
**Files**: `ShowDeviceReport.ps1`, `GetDeviceByUser.ps1`  
**Pattern**: Replace `Where-Object` with `Invoke-DeviceFilter`  
**Impact**: 3-6x faster, LOW risk

### 2. Graph API Batching (3-4 hours)
**File**: `CallGraphAPI.ps1`  
**Pattern**: Use `BatchProcessor` for multiple requests  
**Impact**: 5-10x faster, MEDIUM risk

### 3. Release Process (30 minutes)
**File**: `CreateRelease.ps1`  
**Pattern**: Add DLL compilation step  
**Impact**: Users get performance benefits, LOW risk

### 4. CI/CD Integration (30 minutes)
**File**: `.github/workflows/*.yml`  
**Pattern**: Add .NET SDK setup and DLL build  
**Impact**: Automated testing, LOW risk

## Quick Commands

```powershell
# Build DLLs
.\Build-NativeDlls.ps1 -Configuration Release

# Run tests
.\Invoke-PesterTests.ps1 -TestType Unit

# Verify DLL loading
.\tools\Verify-DotNetSetup.ps1

# Benchmark performance
.\tools\Benchmark-DllPerformance.ps1
```

## Integration Pattern (Copy-Paste Template)

```powershell
# Check if DLL available
$useCSharp = $global:AutopilotDllStatus -and $global:AutopilotDllStatus.FeatureLoaded

if ($useCSharp) {
    Write-Verbose "Using C# implementation (optimized)"
    # C# code here
    $result = [Autopilot.Feature]::Method($input)
} else {
    Write-Verbose "Using PowerShell implementation"
    # PowerShell fallback here
    $result = # Original code
}

return $result
```

## Testing Checklist

- [ ] Test with DLLs present (`.\Build-NativeDlls.ps1`)
- [ ] Test without DLLs (`Remove-Item bin\Release -Recurse`)
- [ ] Both tests pass with identical results
- [ ] Performance improvement measured
- [ ] Verbose logging added
- [ ] All 443 unit tests passing

## Documentation Quick Links

| Need | Read |
|------|------|
| **Strategy & Roadmap** | [Master Plan](CSHARP_MIGRATION_MASTER_PLAN.md) |
| **API Reference** | [DLL Reference](dotnet/DLL_REFERENCE.md) |
| **Build Instructions** | [Build Guide](dotnet/BUILD_GUIDE.md) |
| **Troubleshooting** | [Troubleshooting](dotnet/TROUBLESHOOTING.md) |
| **LogCore Usage** | [LogCore Wrappers](dotnet/LOGCORE_WRAPPER_FUNCTIONS.md) |
| **Code Examples** | [examples/DLL-Integration-Examples.psm1](../examples/DLL-Integration-Examples.psm1) |

## Key Performance Targets

| Phase | Timeline | Effort | Speedup |
|-------|----------|--------|---------|
| Phases 1-2 (Done) | ✅ Complete | 8 hours | 15-20% |
| Phase 3 (Next) | Week 1 | 4-6 hours | **40-50%** |
| Phase 4 (Future) | Week 2+ | 8-12 hours | 60-80% |

## AI Agent Instructions

1. **Read**: [Master Plan](CSHARP_MIGRATION_MASTER_PLAN.md) → AI Agent Guidelines section
2. **Search**: Use grep patterns to find candidate functions
3. **Replace**: Follow before/after patterns with fallback logic
4. **Test**: Both C# and PowerShell paths must pass
5. **Validate**: Run checklist before submitting

## Questions?

- **Technical details**: See [Master Plan](CSHARP_MIGRATION_MASTER_PLAN.md)
- **API usage**: See [DLL Reference](dotnet/DLL_REFERENCE.md)
- **Build issues**: See [Troubleshooting](dotnet/TROUBLESHOOTING.md)

---

**Last Updated**: October 17, 2025  
**Status**: Active Development (Phase 3 Next)
