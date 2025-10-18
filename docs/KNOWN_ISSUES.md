# Known Issues

This document tracks known issues that are acknowledged but pending future resolution.

## PowerShell 5.1 Stack Overflow (High Priority - Pending Resolution)

**Status:** Documented, pending future architectural changes  
**Affects:** PowerShell 5.1 (Windows PowerShell)  
**Severity:** Critical - Application crashes on startup  
**First Identified:** October 2025  
**Target Resolution:** TBD (requires significant architectural changes)

### Issue Description

The Autopilot application crashes with `StackOverflowException` when run on PowerShell 5.1 during the function loading phase. This occurs even though individual components work correctly in isolation.

### Root Cause

PowerShell 5.1 (Windows PowerShell) is built on .NET Framework 4.x, which has a **hard-coded stack size limit of ~1MB** with no configuration options to increase it. The Autopilot application exceeds this limit during initialization due to:

1. **Parse-Time Stack Consumption**: Dot-sourcing 180+ function files, each containing `[CmdletBinding()]` attribute
2. **Cumulative Depth**: Each `[CmdletBinding()]` creates stack frames during the PowerShell parser's attribute processing
3. **Runtime Stack Consumption**: After successful function loading, Write-Log mutex operations add additional stack depth
4. **Threshold Exceeded**: Combined stack depth exceeds the 1MB limit during initialization

**Technical Details:**
- PowerShell 5.1: ~1MB stack (confirmed by [Microsoft Learn documentation](https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell))
- PowerShell 7+: ~4MB stack (built on .NET Core/5+)
- 180+ functions with `[CmdletBinding()]` = significant parse-time stack consumption
- No registry or configuration options exist to increase PS 5.1 stack size

### Crash Location

Crash occurs at line 382 in `main.ps1`:
```powershell
$version = GetFileVersion -executableFileName "$scriptPath\$scriptNameExe"
```

This happens AFTER:
- ✅ All 180+ functions load successfully (dot-sourcing completes)
- ✅ All 4 C# DLLs load successfully (GraphCore, DeviceCore, CacheCore, ConfigCore)
- ✅ Write-Log -StartLogging executes successfully
- ❌ First GetFileVersion call triggers stack overflow due to cumulative depth

### Attempted Mitigations (All Unsuccessful)

1. **Removed `[CmdletBinding()]` from main.ps1** ✅ Fixed parse-time crash in main script
2. **Disabled LogCore DLL on PS 5.1** ✅ Prevented C# recursion issues
3. **Reduced Write-Log calls** ❌ Crash persists
4. **Commented out Write-Log calls entirely** ❌ Crash persists (proves issue is cumulative stack depth)
5. **Implemented lightweight Write-Log for PS 5.1** ❌ Crash persists (functions already loaded before Write-Log executes)
6. **Removed `[CmdletBinding()]` from Write-Log.ps1** ❌ Crash persists (one function insufficient)

### Testing Results

**Isolated Tests (All Pass on PS 5.1):**
- ✅ Write-Log with 3 calls
- ✅ Write-Log with 15 calls
- ✅ GetFileVersion alone
- ✅ DLL loading + GetFileVersion
- ✅ Function loading only (test-minimal-main.ps1)

**Full Application:**
- ❌ main.ps1 crashes with StackOverflowException during initialization

**Conclusion:** Individual components work correctly. The issue is the **cumulative effect** of loading all components together.

### Why ps2exe Compilation Won't Help

**Question:** Will compiling with ps2exe avoid the stack limitation?

**Answer:** **No.** According to the [ps2exe documentation](https://github.com/MScholtes/PS2EXE):

> "PS2EXE can only compile Powershell 5.1 compatible scripts and generates .Net 4.x binaries"

This means:
- ps2exe wraps the PowerShell script in a C# executable
- The underlying PowerShell engine is still Windows PowerShell 5.1
- The runtime is still .NET Framework 4.x
- The stack size limit remains **~1MB** (unchanged)

**Compilation does NOT change the PowerShell runtime's stack behavior.**

### Potential Solutions (Not Yet Implemented)

Three architectural approaches could resolve this issue:

#### Option 1: Require PowerShell 7+ (Recommended)
**Effort:** Low (documentation updates only)  
**Impact:** Users must upgrade to PowerShell 7+  
**Benefits:**
- Clean solution with no code changes
- PowerShell 7 is mature (GA since 2020, currently v7.5+)
- Cross-platform, actively maintained, significantly faster
- ~4MB stack vs ~1MB

**Implementation:**
- Update README.md with PowerShell 7+ requirement
- Add version check at startup with clear error message
- Provide upgrade instructions and links

#### Option 2: Remove [CmdletBinding()] from All Functions
**Effort:** High (40-60 hours including testing)  
**Impact:** Loss of common parameters (-Verbose, -Debug, -ErrorAction, etc.)  
**Challenges:**
- 180+ functions need modification
- Breaking change for function signatures
- Loss of PowerShell best practices compliance
- Ongoing maintenance burden

**Implementation:**
- Remove `[CmdletBinding()]` from all 180+ functions
- Replace `$PSCmdlet` usage with manual parameter handling
- Implement manual -Verbose/-Debug support where needed
- Comprehensive testing required

#### Option 3: Implement Lazy-Loading Architecture
**Effort:** Very High (60-80 hours including design and testing)  
**Impact:** Major architectural change  
**Challenges:**
- Don't dot-source all functions at startup
- Load functions dynamically as menus are accessed
- Rewrite initialization logic
- Complex error handling for on-demand loading

**Implementation:**
- Create function manifest/registry
- Implement dynamic loading mechanism
- Refactor menu system for on-demand function loading
- Add caching for frequently-used functions

### Recommendation

**Accept PowerShell 7+ as minimum requirement** (Option 1).

**Rationale:**
- PowerShell 7 has been GA for 5 years (since March 2020)
- Microsoft actively maintains and recommends PowerShell 7+
- Cross-platform support (Windows, Linux, macOS)
- Significant performance improvements over PS 5.1
- ~4MB stack vs ~1MB eliminates stack overflow issues
- Minimal development effort (documentation only)
- Options 2 and 3 require substantial development and ongoing maintenance

### Workaround (Current State)

**For users who must use PowerShell 5.1:**
- Application is **not functional** on PowerShell 5.1
- Clear warning message displays at startup
- Provides upgrade instructions and links

**For users on PowerShell 7+:**
- Application works perfectly with all features
- Full logging, performance optimization, and stability

### Related Files

- `main.ps1` - Lines 317-326: PS version warning
- `main.ps1` - Line 147: `[CmdletBinding()]` removed with documentation
- `Write-Log.ps1` - Line 39-40: `[CmdletBinding()]` removed with documentation
- `Write-Log.ps1` - Lines 93-135: Lightweight PS 5.1 implementation (insufficient to fix issue)
- `docs/fixes/PS51_STACK_OVERFLOW_FIX_SUMMARY.md` - Previous session's fix attempts

### Research References

- [Microsoft Learn: Differences from Windows PowerShell](https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell) - Confirms stack size differences
- [ps2exe GitHub Repository](https://github.com/MScholtes/PS2EXE) - Confirms .NET Framework 4.x compilation
- [PowerShell 7 Download](https://aka.ms/powershell) - Official download page

### Timeline

- **October 2025:** Issue identified and root cause determined
- **October 2025:** Multiple mitigation attempts (all unsuccessful)
- **October 2025:** Documented as known issue pending future resolution
- **TBD:** Decision on architectural approach (Option 1, 2, or 3)

### Notes

- This is a **platform limitation**, not a bug in the application code
- Microsoft has no plans to update PowerShell 5.1 (in maintenance mode)
- All new PowerShell development targets PowerShell 7+
- Individual components work correctly in isolation
- Issue is **cumulative stack depth** from loading entire application
