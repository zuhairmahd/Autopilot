# Apply-WindowsUpdates Integration Testing

## Summary

Integration tests for the `Apply-WindowsUpdates` function validate the workflow orchestration, parameter handling, result structures, and error resilience **without requiring actual Windows Update COM objects**.

**Status: ✅ ALL 15 TESTS PASSING**

## Test Approach

These tests focus on:
- Multi-iteration update processing workflows
- Parameter validation and configuration handling  
- Result structure and statistics aggregation
- Error recovery and resilience patterns

**Note:** This approach tests business logic and orchestration without the complexity of full COM object mocking. For actual Windows Update service interaction testing, manual testing or VM-based approaches are recommended.

## What We Learned & Fixed

### PowerShell Collection Enumeration Issues

**Problem:** PowerShell's `foreach` loop will enumerate ANY object, even PSCustomObjects, unless it recognizes the object as a proper collection type. Simply having `Count=0` is NOT sufficient to prevent enumeration.

**Solution:** Use `System.Collections.ArrayList` (or other recognized collection types) instead of PSCustomObjects for COM mock collections. This ensures PowerShell's `foreach` correctly handles empty collections without trying to enumerate the collection object itself.

```powershell
# ❌ WRONG: PowerShell may enumerate the PSCustomObject itself
$emptyCollection = [PSCustomObject]@{ Count = 0 }

# ✅ CORRECT: ArrayList is recognized as a proper collection type
$emptyCollection = New-Object System.Collections.ArrayList
```

### Hashtable Property Access in Tests

**Problem:** Tests used `$result.PSObject.Properties.Name` to check hashtable keys, which doesn't work on PowerShell hashtables (returns internal properties like 'IsReadOnly', 'IsSynchronized', etc.).

**Solution:** Use `$result.Keys` for hashtables or `$result.PSObject.Properties.Name` for PSCustomObjects.

```powershell
# ❌ WRONG: Doesn't work on hashtables
$result.PSObject.Properties.Name | Should -Contain 'ExitCode'

# ✅ CORRECT: Use .Keys for hashtables
$result.Keys | Should -Contain 'ExitCode'
```

### Statistics Property Names

**Problem:** Tests checked for `Iterations` property, but function uses `TotalIterations`.

**Solution:** Updated tests to use correct property name from actual function implementation.

```powershell
# ❌ WRONG: Property doesn't exist
$result.Statistics.Iterations

# ✅ CORRECT: Use actual property name
$result.Statistics.TotalIterations
```

### Error Handling with Write-Error

**Problem:** Function's catch block calls `Write-Error` which throws a terminating error in Pester tests, preventing validation of the returned error result.

**Solution:** Add `-ErrorAction SilentlyContinue` to test invocations that expect errors, and validate the returned hashtable with `ExitCode = 999`.

```powershell
# ✅ CORRECT: Suppress Write-Error termination to test error results
$result = Apply-WindowsUpdates -MaxIterations 1 -Reboot None -ErrorAction SilentlyContinue

$result.ExitCode | Should -Be 999
$result.Error | Should -Not -BeNullOrEmpty
```

### Non-Existent Return Properties

**Problem:** Test checked for `ProcessedUpdates` in return value, but function doesn't return this (it's an internal variable).

**Solution:** Replaced with test for `RebootNeeded` property which the function actually returns.

## Test Coverage

### Basic Workflow Execution (3 tests)
✅ Completes successfully with no updates  
✅ Executes multiple iterations  
✅ Initializes statistics structure correctly

### Parameter Handling (4 tests)
✅ Accepts SkipPreview parameter  
✅ Accepts SkipFeature parameter  
✅ Accepts different Reboot modes (None, Soft, Hard)  
✅ Accepts noOptIn switch

### Result Structure Validation (3 tests)
✅ Returns required result properties (ExitCode, Statistics, RebootNeeded)  
✅ Returns statistics with all counters (TotalIterations, TotalUpdatesFound, etc.)  
✅ Returns RebootNeeded property as boolean

### Error Handling and Resilience (2 tests)
✅ Handles COM object creation failures gracefully (returns ExitCode 999)  
✅ Completes iteration even with search errors (returns ExitCode 999)

### Logging and Output (3 tests)
✅ Completes with configuration parameters  
✅ Completes multiple iterations  
✅ Generates final statistics

## Mock Structure

The tests use `System.Collections.ArrayList`-based mocks for COM objects:

```powershell
Mock New-Object {
    if ($ComObject -eq "Microsoft.Update.Session") {
        $mockSession = New-Object PSObject
        $mockSession | Add-Member -MemberType ScriptMethod -Name CreateUpdateSearcher -Value {
            $searcher = New-Object PSObject
            $searcher | Add-Member -MemberType ScriptMethod -Name Search -Value {
                # Return ArrayList which PowerShell recognizes as proper collection
                $emptyCollection = New-Object System.Collections.ArrayList
                
                $searchResult = [PSCustomObject]@{
                    ResultCode = 2
                    Updates    = $emptyCollection  # ArrayList directly
                }
                return $searchResult
            }
            return $searcher
        }
        # ... CreateUpdateDownloader, CreateUpdateInstaller methods
        return $mockSession
    }
    # ... Other COM object mocks
} -ParameterFilter { $ComObject -like "Microsoft.Update.*" }
```

## Running the Tests

```powershell
# Run integration tests only
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 `
    -TestFile "tests/Integration/Apply-WindowsUpdates.Tests.ps1" `
    -OutputVerbosity Detailed

# Run with unit tests  
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 `
    -TestType Integration -OutputVerbosity Detailed
```

**Expected Result:** All 15 tests passing in ~2-3 seconds

## Alternative Testing Approaches

While these integration tests validate business logic effectively, testing actual Windows Update COM interactions requires:

### 1. Manual Testing on Real Systems
Run `Apply-WindowsUpdates` on actual Windows machines to validate:
- Real update detection and installation
- EULA acceptance flows
- Reboot handling
- Feature/preview update filtering

### 2. VM-Based Automated Testing
- Hyper-V/VMware test VMs with clean Windows installations
- Snapshot/restore for repeatability
- PowerShell Remoting for remote execution
- Azure DevOps or GitHub Actions with Windows runners

### 3. Test Harness Script
Create manual validation script for common scenarios:

```powershell
# tests/Integration/Test-ApplyWindowsUpdates-Manual.ps1
Write-Host "Test 1: Basic execution" -ForegroundColor Cyan
$result1 = Apply-WindowsUpdates -MaxIterations 1 -Reboot None
if ($result1.ExitCode -eq 0) {
    Write-Host "✓ PASS" -ForegroundColor Green
}

Write-Host "`nTest 2: Skip preview updates" -ForegroundColor Cyan
$result2 = Apply-WindowsUpdates -MaxIterations 1 -SkipPreview $true -Reboot None
Write-Host "Skipped Preview: $($result2.Statistics.SkippedPreview)" -ForegroundColor Yellow
```

## Key Takeaways

### ✅ What Works
- **Unit tests** (25 tests) validate parameter structure, update tracking, and business logic (100% pass rate)
- **Integration tests** (15 tests) validate workflow orchestration without COM dependencies (100% pass rate)  
- **ArrayList-based mocks** prevent PowerShell enumeration issues
- **Error handling tests** with `-ErrorAction SilentlyContinue` validate exception paths

### ⚠️ What Doesn't Work
- **Complex COM object mocking** is fragile and unmaintainable due to PowerShell scoping limitations
- Helper functions cannot be called inside Mock scriptblocks
- Fully mocking Windows Update COM API requires deeply nested structures

### 🎯 Recommended Strategy
1. **Unit tests** → Business logic (tracking, filtering, statistics)
2. **Integration tests** → Workflow orchestration (iteration loops, parameter handling)  
3. **Manual/VM tests** → Actual COM interactions with real Windows Update service

This two-tier automated testing plus manual validation provides comprehensive coverage without the fragility of complex COM mocking.
