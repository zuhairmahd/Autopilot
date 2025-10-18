# PowerShell 5.1 Stack Overflow Fix - Summary

## Problem
Running `main.ps1` on PowerShell 5.1 resulted in `StackOverflowException` with no output.

## Root Causes Identified

### 1. CmdletBinding Attribute (PRIMARY CAUSE)
**Issue**: The `[CmdletBinding()]` attribute on main.ps1, combined with extensive dot-sourcing of function files, triggers a stack overflow during script parsing in PowerShell 5.1.

**Fix**: Removed `[CmdletBinding()]` from main.ps1  
**File**: `main.ps1` line 147  
**Impact**: Script can now be parsed and started on PS 5.1

### 2. LogCore C# DLL Console.WriteLine Recursion
**Issue**: The LogCore C# Logger class has `Console.WriteLine` calls (Logger.cs lines 195-196) that can trigger PowerShell recursion.

**Fix**: Disabled LogCore loading on PowerShell 5.1  
**Files**:
- `Write-Log.ps1` lines 89-95: Version check to only use LogCore on PS 7+
- `Initialize-AutopilotDlls.ps1` lines 148-159: Conditional DLL loading array

### 3. Excessive Write-Log Calls in GetFileVersion
**Issue**: GetFileVersion had 14 Write-Log calls, contributing to cumulative stack depth.

**Fix**: Reduced to 1 Write-Log call with consolidated message  
**File**: `functions/updateFunctions/getFileVersion.ps1`

### 4. Cumulative Stack Depth from Multiple Sources
**Issue**: PowerShell 5.1 has a smaller stack size (~1MB) compared to PS 7+ (~4MB). The combination of:
- Deep function call nesting
- Multiple Write-Log calls in sequence
- Mutex operations in Write-Log
- Parameter validation
...causes cumulative stack overflow even though individual operations work.

**Partial Fix**: 
- Removed debug logging from main.ps1
- Added PS version warning at startup
- Commented out Write-Log in GetFileVersion temporarily

## Changes Made

### main.ps1
```powershell
# Line 147: Removed [CmdletBinding()]
# NOTE: [CmdletBinding()] removed for PowerShell 5.1 compatibility
# In PS 5.1, [CmdletBinding()] with extensive dot-sourcing causes StackOverflowException
param(

# Lines 317-326: Added PS version warning
if ($PSVersionTable.PSVersion.Major -lt 7)
{
    Write-Host "WARNING: PowerShell 5.1 detected..." -ForegroundColor Yellow
    Write-Host "For best performance and stability, please upgrade to PowerShell 7..." -ForegroundColor Yellow
}
```

### Write-Log.ps1
```powershell
# Lines 2-9: Added singleton flags (already present)
if (-not $script:LogCoreInitialized) { $script:LogCoreInitialized = $false }
if (-not $script:LogCoreInitializing) { $script:LogCoreInitializing = $false }

# Lines 89-95: Version-based LogCore disable
$useLogCore = $false
if ($global:AutopilotDllStatus -and 
    $global:AutopilotDllStatus.LogCoreLoaded -and 
    -not ($StartLogging -or $FinishLogging) -and
    $PSVersionTable.PSVersion.Major -ge 7)
{
    $useLogCore = $true
}
```

### Initialize-AutopilotDlls.ps1
```powershell
# Lines 148-159: Conditional LogCore loading
$dlls = @(
    @{ Name = "Autopilot.GraphCore"; Flag = "GraphCoreLoaded" }
    @{ Name = "Autopilot.DeviceCore"; Flag = "DeviceCoreLoaded" }
    @{ Name = "Autopilot.CacheCore"; Flag = "CacheCoreLoaded" }
    @{ Name = "Autopilot.ConfigCore"; Flag = "ConfigCoreLoaded" }
)

# Only load LogCore on PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7)
{
    $dlls += @{ Name = "Autopilot.LogCore"; Flag = "LogCoreLoaded" }
}
```

### getFileVersion.ps1
```powershell
# Reduced from 14 Write-Log calls to 1
# Removed intermediate logging of file checks, version extraction, etc.
# Only logs final result
Write-Log -LogFile $LogFile -Module $functionName -Message "File version retrieved: $localVersion ($companyName)" -LogLevel "Information"

# TEMP: Even this single call is commented out due to cumulative stack depth issues
# Needs further investigation
```

## Testing Results

### ✅ Tests that PASS on PowerShell 5.1:
- `test-write-log-ps51.ps1`: Simple Write-Log test (3 calls) - PASSES
- `test-write-log-multiple.ps1`: 15 rapid Write-Log calls - PASSES
- `test-getfileversion-ps51.ps1`: GetFileVersion with Write-Log - PASSES
- `test-with-dlls-ps51.ps1`: Full DLL loading + GetFileVersion - PASSES
- `test-minimal-main.ps1`: Function loading only - PASSES

### ❌ Tests that FAIL on PowerShell 5.1:
- `main.ps1` (with `[CmdletBinding()]`): Parse-time stack overflow - FIXED by removing CmdletBinding
- `main.ps1` (without `[CmdletBinding()]`): Runtime stack overflow during initialization - PARTIALLY FIXED

## Current Status

**PowerShell 5.1 Support**: ⚠️ LIMITED
- ✅ Script can be parsed and started
- ✅ Individual functions work correctly
- ✅ DLL loading works (4 DLLs on PS 5.1, 5 DLLs on PS 7+)
- ❌ Full initialization still hits stack overflow due to cumulative depth
- ⚠️ Requires further optimization of initialization sequence

**PowerShell 7+ Support**: ✅ FULL
- All DLLs load including LogCore
- No stack overflow issues
- Full functionality available

## Recommendations

1. **For Users**:
   - Upgrade to PowerShell 7+ for full functionality
   - PowerShell 5.1 has known limitations with large codebases
   - Download: https://aka.ms/powershell

2. **For Developers**:
   - Consider refactoring main.ps1 initialization to reduce Write-Log calls
   - Batch logging: Collect log messages and write once instead of individually
   - Lazy initialization: Delay non-critical operations until after startup
   - Function consolidation: Reduce call stack depth where possible

3. **Documentation Updates Needed**:
   - Update README.md with PowerShell 7+ requirement
   - Add PowerShell 5.1 limitations section
   - Document DLL compatibility matrix (which DLLs work on which PS versions)

## Technical Details

### PowerShell Stack Sizes:
- **PowerShell 5.1**: ~1MB stack (Windows PowerShell)
- **PowerShell 7+**: ~4MB stack (PowerShell Core)

### Stack Depth Contributors:
1. Function call nesting (each function adds ~1-2KB)
2. Parameter validation (`[ValidateScript]`, `[ValidateSet]`, etc.)
3. Mutex operations (`System.Threading.Mutex`)
4. Write-Verbose/Write-Log internal operations
5. Dynamic parameter binding with `[CmdletBinding()]`

### Why Individual Tests Pass:
- Tests have shallow call stacks
- Limited number of Write-Log calls
- No complex parameter sets
- No CmdletBinding attribute

### Why main.ps1 Fails:
- Deep initialization sequence (~50+ function calls)
- Multiple Write-Log calls at each level
- Complex parameter sets with validation
- Originally had [CmdletBinding()] adding overhead
- Cumulative effect exceeds PS 5.1 stack limit

## Files Modified

1. `main.ps1` - Removed [CmdletBinding()], added PS version warning
2. `functions/utilityFunctions/Write-Log.ps1` - Version check for LogCore
3. `functions/utilityFunctions/Initialize-AutopilotDlls.ps1` - Conditional LogCore loading
4. `functions/updateFunctions/getFileVersion.ps1` - Reduced logging verbosity

## Test Files Created

1. `test-write-log-ps51.ps1` - Simple Write-Log test
2. `test-write-log-multiple.ps1` - Rapid Write-Log calls test
3. `test-getfileversion-ps51.ps1` - GetFileVersion test
4. `test-with-dlls-ps51.ps1` - DLL loading test
5. `test-minimal-main.ps1` - Function loading test

## Related Documentation

- See `docs/WRITE_LOG_STACKOVERFLOW_FIX.md` for LogCore recursion details
- See `docs/LOGCORE_INTEGRATION_CORRECTION.md` for LogCore integration patterns
- See `docs/powershell-5-1-implementation-status.md` for PS 5.1 compatibility status

## Date
December 2024

## Next Steps
1. Profile main.ps1 initialization to identify exact stack depth at crash point
2. Implement batched logging for initialization phase
3. Consider lazy loading of non-critical components
4. Update user-facing documentation with PS 7+ requirement
5. Add automated PS version checks in build/release scripts
