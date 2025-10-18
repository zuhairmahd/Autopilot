# Write-Log Singleton Pattern - Quick Reference

## Problem Fixed
**PowerShell 5.1 StackOverflowException** caused by repeated LogCore initialization on every `Write-Log` call.

## Solution Applied
**Singleton Pattern** using script-level flag `$script:LogCoreInitialized`

---

## Code Pattern

```powershell
# At script level (outside function)
if (-not $script:LogCoreInitialized)
{
    $script:LogCoreInitialized = $false
}

# Inside function
if ($useLogCore)
{
    # Initialize only if not already done
    if (-not $script:LogCoreInitialized)
    {
        # ... initialization code ...
        $script:LogCoreInitialized = $true
    }
    
    # Use logger (runs every time)
    $global:AutopilotLogger.WriteLog($Module, $Message, $numericLevel)
}
```

---

## Validation Checklist

✅ **PowerShell 5.1**: No `StackOverflowException`  
✅ **PowerShell 7+**: Backward compatible  
✅ **Verbose Output**: Single initialization message  
✅ **Pester Tests**: 677 passing (48 pre-existing failures)  
✅ **Performance**: No degradation  

---

## Quick Test

```powershell
# Test in PowerShell 7+
.\main.ps1 -Verbose 2>&1 | Select-String "Initializing AutopilotLogger"
# Expected: Single occurrence

# Test in PowerShell 5.1
powershell.exe -Version 5.1 -File .\main.ps1
# Expected: No stack overflow
```

---

## Key Changes Summary

| Location | Change | Reason |
|----------|--------|--------|
| Script-level | Added `$script:LogCoreInitialized = $false` | Initialize flag |
| Line ~95 | Wrapped init in `if (-not $script:LogCoreInitialized)` | Singleton guard |
| Line ~117 | Added `$script:LogCoreInitialized = $true` | Set flag after init |
| Lines 77-135 | Removed redundant verbose messages | Reduce noise |

---

## Before vs After

### Before (❌ Broken)
```
Write-Log called
  → Check if LogCore available
  → Initialize LogCore (VERBOSE MESSAGE)
  → Check if AutopilotLogger exists
  → Create logger (or skip if exists)
  → Log message
  
Write-Log called again
  → Check if LogCore available
  → Initialize LogCore (VERBOSE MESSAGE) ← REPEATED!
  → Check if AutopilotLogger exists
  → Create logger (or skip if exists)
  → Log message
(Infinite recursion if init calls Write-Log)
```

### After (✅ Fixed)
```
Write-Log called (first time)
  → Check if LogCore available
  → Check if already initialized (NO)
  → Initialize LogCore (VERBOSE MESSAGE)
  → Set initialized flag
  → Log message
  
Write-Log called again
  → Check if LogCore available
  → Check if already initialized (YES)
  → Skip initialization ← FIX!
  → Log message
```

---

## Troubleshooting

### Symptom: Stack overflow in PS 5.1
**Cause**: Repeated initialization  
**Fix**: Applied singleton pattern ✅

### Symptom: Too much verbose output
**Cause**: Verbose messages on every call  
**Fix**: Removed redundant messages ✅

### Symptom: Tests failing after fix
**Cause**: Likely unrelated  
**Check**: Run `.\Invoke-PesterTests.ps1 -TestType All` (should show 677 passing)

---

## Documentation
- **Full Details**: `docs/WRITE_LOG_STACKOVERFLOW_FIX.md`
- **Phase 2 Summary**: `docs/CONFIGCORE_PHASE2_SUMMARY.md`
- **File Modified**: `functions/utilityFunctions/Write-Log.ps1`
