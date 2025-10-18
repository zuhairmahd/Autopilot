# PowerShell 5.1 Stack Overflow - Quick Reference

**Status:** Known Issue - Documented, Pending Resolution  
**Date:** October 2025  
**Severity:** Critical (Application Non-Functional on PS 5.1)

## TL;DR

**Problem:** Application crashes with `StackOverflowException` on PowerShell 5.1 during initialization.

**Root Cause:** PS 5.1's hard-coded 1MB stack limit + 180+ functions with `[CmdletBinding()]` = stack overflow during dot-sourcing.

**Solution:** **Require PowerShell 7+** (4MB stack, no issues).

**ps2exe Question:** **No, compilation won't help** - ps2exe uses .NET Framework 4.x which has the same 1MB stack limit.

## Why This Happens

```
PowerShell 5.1 Stack Limit: ~1MB (hard-coded, no configuration options)
+ 180+ functions with [CmdletBinding()] being dot-sourced
+ Parse-time attribute processing (stack frames for each function)
+ Runtime Write-Log mutex operations
= Exceeds 1MB → StackOverflowException
```

## What We Tried (All Failed)

1. ❌ Removed `[CmdletBinding()]` from main.ps1
2. ❌ Disabled LogCore DLL on PS 5.1
3. ❌ Reduced Write-Log calls
4. ❌ Commented out ALL Write-Log calls
5. ❌ Implemented lightweight Write-Log for PS 5.1
6. ❌ Removed `[CmdletBinding()]` from Write-Log.ps1

**Conclusion:** Individual mitigations insufficient. Need architectural change.

## What Works

✅ **PowerShell 7+**: All features work perfectly (4MB stack vs 1MB)  
✅ **Individual components**: All tests pass in isolation on PS 5.1  
❌ **Full application**: Crashes due to cumulative stack depth

## ps2exe Compilation

**Question:** Will ps2exe compilation avoid the stack limitation?

**Answer:** **NO**

From [ps2exe documentation](https://github.com/MScholtes/PS2EXE):
> "PS2EXE can only compile Powershell 5.1 compatible scripts and generates .Net 4.x binaries"

- ps2exe = PowerShell 5.1 engine + .NET Framework 4.x
- Same 1MB stack limit as non-compiled PS 5.1
- Compilation just wraps the script, doesn't change runtime

## Solutions (Not Yet Implemented)

### Option 1: Require PowerShell 7+ ⭐ RECOMMENDED
- **Effort:** Low (docs only)
- **Impact:** Users must upgrade
- **Benefit:** Clean solution, no code changes

### Option 2: Remove All [CmdletBinding()]
- **Effort:** High (40-60 hours)
- **Impact:** Lose -Verbose, -Debug, etc.
- **Benefit:** PS 5.1 support maintained

### Option 3: Lazy-Load Functions
- **Effort:** Very High (60-80 hours)
- **Impact:** Major architecture change
- **Benefit:** PS 5.1 support maintained

## Current Workaround

- **PS 5.1:** Warning displayed, application crashes
- **PS 7+:** Full functionality

## Files Modified

- `main.ps1` - Line 147: `[CmdletBinding()]` removed
- `Write-Log.ps1` - Lines 39-40: `[CmdletBinding()]` removed
- `Write-Log.ps1` - Lines 93-135: Lightweight PS 5.1 implementation
- `readme.md` - Updated system requirements
- `docs/KNOWN_ISSUES.md` - Full documentation

## Decision Required

Choose one:
1. ⭐ **Accept PS 7+ requirement** (minimal effort, clean)
2. **Remove all [CmdletBinding()]** (high effort, maintains PS 5.1)
3. **Implement lazy-loading** (very high effort, maintains PS 5.1)

**Recommendation:** Option 1 - PowerShell 7 is mature, actively maintained, and significantly better than PS 5.1.

## References

- [Microsoft Learn: PS Differences](https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell)
- [ps2exe GitHub](https://github.com/MScholtes/PS2EXE)
- [PowerShell 7 Download](https://aka.ms/powershell)
- Full documentation: `docs/KNOWN_ISSUES.md`
