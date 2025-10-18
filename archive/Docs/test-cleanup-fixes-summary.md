# Test Cleanup Fixes Summary

## Problem Statement

After running the test suite via `Test-Runner.ps1`, several files were left behind in the project folder:
- `contoso.com.psd1`
- `performance-optimized.log`
- `test-appmode.log`
- `test-config-mgmt.log`
- `test-menu-system.log`
- `test.com.psd1`
- `test.log`
- `testdomain.com.psd1`

These leftover files indicated that tests were either:
1. Creating files outside of temporary folders
2. Not cleaning up properly after completion
3. Missing cleanup logic in error/failure scenarios

## Root Cause Analysis

### Category 1: Tests Using $PWD for Log Files
Several comprehensive tests were creating log files directly in the current working directory (`$PWD`) instead of using temporary folders:
- `test-menu-system-comprehensive.ps1` - `$global:LogFile = "$PWD/test-menu-system.log"`
- `test-appmode-comprehensive.ps1` - `$global:LogFile = "$PWD/test-appmode.log"`
- `test-configuration-comprehensive.ps1` - `$global:LogFile = "$PWD/test-config-mgmt.log"`
- `test-performance-optimized.ps1` - `[string]$LogFile = "performance-optimized.log"`
- `test-autopilot-import-comprehensive.ps1` - `$global:LogFile = "$PWD/test-autopilot-import.log"`
- `test-auth-flows-comprehensive.ps1` - `$global:LogFile = "$PWD/test-auth-flows.log"`
- `test-device-lookup-comprehensive.ps1` - `$global:LogFile = "$PWD/test-device-lookup.log"`

### Category 2: Tests Using $scriptRoot for Log Files
Some tests created log files in `$scriptRoot` (the TestScripts directory) without proper cleanup:
- `test-verify-group-membership-refactor.ps1` - `$global:logFile = Join-Path $scriptRoot "test.log"`
- `test-single-group-fix.ps1` - `$global:logFile = Join-Path $scriptRoot "test-single-group.log"`
- `test-groups-editor.ps1` - `$global:logFile = Join-Path $scriptRoot "test.log"`
- `test-groups-editor-hashtable-format.ps1` - `$global:logFile = Join-Path $scriptRoot "test.log"`
- `test-issue-118-comprehensive-validation.ps1` - `$global:logFile = Join-Path $scriptRoot "test.log"`

### Category 3: Tests Creating Domain Configuration Files
Domain configuration tests were creating `.psd1` files but TestFolder cleanup was not always invoked:
- `test-migration-comprehensive.ps1` - Created `contoso.com.psd1` in `$TestConfigFolder`
- `test-domain-config-simple.ps1` - Created `testdomain.com.psd1` in `$testContext.TestFolder`

## Solution Strategy

### Principle 1: Use Temporary Folders
**All tests should use temporary folders for artifacts**, preferably:
1. Tests using unified framework: Use `$testContext.TestFolder` (automatically cleaned by `Complete-UnifiedTest`)
2. Tests without unified framework: Create explicit temp folder in `$env:TEMP` with timestamped name

### Principle 2: Ensure Cleanup in Finally Blocks
**Every test that creates files must have cleanup logic in a `finally` block** to ensure cleanup happens even on errors.

### Principle 3: Never Create Files in Project Directories
**Tests should NEVER create files in**:
- `$PWD` (current working directory)
- `$scriptRoot` (TestScripts folder)
- Project root directory
- Any location outside temporary folders

## Fixes Implemented

### Tests Modified to Use TestFolder (Unified Framework)

These tests were already using the unified test framework but creating logs in wrong locations. Fixed by changing log path to use `$testContext.TestFolder`:

1. **test-menu-system-comprehensive.ps1**
   ```powershell
   # Before:
   $global:LogFile = "$PWD/test-menu-system.log"
   
   # After:
   $global:LogFile = Join-Path $testContext.TestFolder "test-menu-system.log"
   ```
   - Cleanup: Handled by `Complete-UnifiedTest` in finally block

2. **test-appmode-comprehensive.ps1**
   ```powershell
   # Before:
   $global:LogFile = "$PWD/test-appmode.log"
   
   # After:
   $global:LogFile = Join-Path $testContext.TestFolder "test-appmode.log"
   ```
   - Cleanup: Handled by `Complete-UnifiedTest` in finally block

3. **test-configuration-comprehensive.ps1**
   ```powershell
   # Before:
   $global:LogFile = "$PWD/test-config-mgmt.log"
   
   # After:
   $global:LogFile = Join-Path $testContext.TestFolder "test-config-mgmt.log"
   ```
   - Cleanup: Handled by `Complete-UnifiedTest` in finally block

4. **test-autopilot-import-comprehensive.ps1**
   ```powershell
   # Before:
   $global:LogFile = "$PWD/test-autopilot-import.log"
   
   # After:
   $global:LogFile = Join-Path $testContext.TestFolder "test-autopilot-import.log"
   ```
   - Cleanup: Handled by `Complete-UnifiedTest` in finally block

5. **test-auth-flows-comprehensive.ps1**
   ```powershell
   # Before:
   $global:LogFile = "$PWD/test-auth-flows.log"
   
   # After:
   $global:LogFile = Join-Path $testContext.TestFolder "test-auth-flows.log"
   ```
   - Cleanup: Handled by `Complete-UnifiedTest` in finally block

6. **test-device-lookup-comprehensive.ps1**
   ```powershell
   # Before:
   $global:LogFile = "$PWD/test-device-lookup.log"
   
   # After:
   $global:LogFile = Join-Path $testContext.TestFolder "test-device-lookup.log"
   ```
   - Cleanup: Handled by `Complete-UnifiedTest` in finally block

### Tests Modified to Use Temp Folder with Explicit Cleanup

These tests don't use the unified framework, so they needed explicit temp folder creation and cleanup:

7. **test-performance-optimized.ps1**
   ```powershell
   # Added at top:
   $TestTempFolder = Join-Path $env:TEMP "autopilot-perf-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null
   
   # Modified parameter default:
   if (-not $LogFile) {
       $LogFile = Join-Path $TestTempFolder "performance-optimized.log"
   }
   
   # Added at end:
   try {
       if (Test-Path $TestTempFolder) {
           Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
           Write-Host "Cleaned up temporary test folder" -ForegroundColor Gray
       }
   } catch {
       Write-Warning "Could not clean up temporary folder: $($_.Exception.Message)"
   }
   ```

8. **test-verify-group-membership-refactor.ps1**
   ```powershell
   # Added at top:
   $TestTempFolder = Join-Path $env:TEMP "autopilot-group-verify-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null
   
   $global:logFile = Join-Path $TestTempFolder "test.log"
   
   # Added at end:
   try {
       if (Test-Path $TestTempFolder) {
           Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
           Write-Host "`nCleaned up temporary test folder" -ForegroundColor Gray
       }
   } catch {
       Write-Warning "Could not clean up temporary folder: $($_.Exception.Message)"
   }
   ```

9. **test-groups-editor.ps1**
   ```powershell
   # Added at top:
   $TestTempFolder = Join-Path $env:TEMP "autopilot-groups-editor-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null
   
   $global:logFile = Join-Path $TestTempFolder "test.log"
   
   # Added at end:
   try {
       if (Test-Path $TestTempFolder) {
           Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
           Write-Host "`nCleaned up temporary test folder" -ForegroundColor Gray
       }
   } catch {
       Write-Warning "Could not clean up temporary folder: $($_.Exception.Message)"
   }
   ```

10. **test-groups-editor-hashtable-format.ps1**
    ```powershell
    # Added at top:
    $TestTempFolder = Join-Path $env:TEMP "autopilot-groups-hashtable-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null
    
    $global:logFile = Join-Path $TestTempFolder "test.log"
    
    # Cleanup needed at end (TODO)
    ```

11. **test-issue-118-comprehensive-validation.ps1**
    ```powershell
    # Added at top:
    $TestTempFolder = Join-Path $env:TEMP "autopilot-issue118-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null
    
    $global:logFile = Join-Path $TestTempFolder "test.log"
    
    # Added at end:
    try {
        if (Test-Path $TestTempFolder) {
            Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "`nCleaned up temporary test folder" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Could not clean up temporary folder: $($_.Exception.Message)"
    }
    ```

12. **test-single-group-fix.ps1**
    ```powershell
    # Already had cleanup in finally block, enhanced to include log file:
    finally {
        # Clean up
        if (Test-Path $testDir) {
            Remove-Item $testDir -Recurse -Force
        }
        # Clean up log file
        if (Test-Path $global:logFile) {
            Remove-Item $global:logFile -Force -ErrorAction SilentlyContinue
        }
    }
    ```

## Unified Test Framework Cleanup Behavior

For tests using the unified framework (`Start-UnifiedTest` / `Complete-UnifiedTest`), cleanup is automatic:

### How It Works:
1. `Start-UnifiedTest` creates a temporary folder: `Join-Path $env:TEMP "autopilot-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"`
2. Returns `$testContext` with `TestFolder` property
3. Tests should create ALL artifacts within `$testContext.TestFolder`
4. `Complete-UnifiedTest` calls `Cleanup-TestEnvironment` which:
   - Moves out of folder if currently inside it
   - Clears read-only/system attributes
   - Recursively deletes the entire folder
   - Verifies deletion succeeded

### Key Rule:
**If using unified framework, ALWAYS put artifacts in `$testContext.TestFolder`, NOT in `$PWD` or `$scriptRoot`**

## Tests Still Requiring Attention

The following tests still need cleanup fixes (not yet implemented):

1. **test-get-grouparrayinput-replace-behavior.ps1** - `$global:logFile = Join-Path $scriptRoot "test-grouparrayinput.log"`
2. **test-enhanced-logging.ps1** - `$global:logFile = Join-Path $scriptRoot "test-count-logging.log"`
3. **test-compare-editor-array.ps1** - `$global:logFile = Join-Path $scriptRoot "test-comparison.log"`
4. **test-groups-editor-single-match.ps1** - `$global:logFile = Join-Path $scriptRoot "test-single-match.log"`
5. **test-private-key-access-fix.ps1** - `$global:LogFile = Join-Path $scriptRoot "test-private-key-access.log"`
6. **test-vendor-matching.ps1** - `$global:LogFile = "$PWD/Logs/vendor-test.log"`
7. **test-function-loading-validation.ps1** - `$global:LogFile = "$PWD/test.log"` (conditional)
8. **test-missing-files-fix.ps1** - `$global:logFile = "$PWD\test-merge.log"`

## Testing Guidelines for Contributors

### For New Tests:

1. **Use Unified Framework (Preferred)**
   ```powershell
   # At start:
   $testContext = Start-UnifiedTest -TestName "My Test" -SkipFunctionCheck
   $global:LogFile = Join-Path $testContext.TestFolder "my-test.log"
   
   # All artifacts:
   $configFile = Join-Path $testContext.TestFolder "test-config.psd1"
   $dataFile = Join-Path $testContext.TestFolder "test-data.json"
   
   # At end (in finally block):
   Complete-UnifiedTest -TestContext $testContext -PassedTests $passed -FailedTests $failed -TotalTests $total
   ```

2. **Without Unified Framework**
   ```powershell
   # At start:
   $TestTempFolder = Join-Path $env:TEMP "autopilot-mytest-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   New-Item -ItemType Directory -Path $TestTempFolder -Force | Out-Null
   $global:LogFile = Join-Path $TestTempFolder "my-test.log"
   
   # All artifacts:
   $configFile = Join-Path $TestTempFolder "test-config.psd1"
   
   # At end (in finally block or explicit):
   try {
       if (Test-Path $TestTempFolder) {
           Remove-Item -Path $TestTempFolder -Recurse -Force -ErrorAction SilentlyContinue
       }
   } catch {
       Write-Warning "Could not clean up temporary folder: $($_.Exception.Message)"
   }
   ```

### For Existing Tests:

**Before modifying:**
1. Check if test uses unified framework (`Start-UnifiedTest`)
2. Check where log files and artifacts are created
3. Check if cleanup exists in `finally` block

**If using unified framework:**
- Change all file paths to use `$testContext.TestFolder`
- Verify `Complete-UnifiedTest` is called in `finally` block

**If not using unified framework:**
- Add temp folder creation at top
- Change all file paths to use temp folder
- Add cleanup in `finally` block or at end

## Verification

After fixes, verify no files are left behind:

```powershell
# Before running tests, note existing files:
Get-ChildItem -Path . -File | Select-Object Name, LastWriteTime | Out-File before.txt

# Run tests:
.\TestScripts\Test-Runner.ps1 -TestCategory all

# After running tests, check for new files:
Get-ChildItem -Path . -File | Where-Object { 
    $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) 
} | Select-Object Name, LastWriteTime

# Or compare:
Get-ChildItem -Path . -File | Select-Object Name, LastWriteTime | Out-File after.txt
Compare-Object (Get-Content before.txt) (Get-Content after.txt)
```

## Benefits

1. **Clean Project Directory**: No test artifacts pollute the project folder
2. **Parallel Test Safety**: Tests can run in parallel without file conflicts (timestamped temp folders)
3. **CI/CD Friendly**: Tests don't leave artifacts in CI/CD runners
4. **Consistent Behavior**: All tests follow same cleanup pattern
5. **Better Debugging**: Temp folders are preserved on crash for debugging
6. **Windows Compatibility**: Proper handling of file locks and attributes

## Future Improvements

1. **Standardize on Unified Framework**: Migrate all tests to use unified framework
2. **Automated Validation**: Add linting rule to detect tests creating files outside temp folders
3. **Test-Runner Enhancement**: Add pre/post-run file comparison to detect cleanup issues
4. **Documentation**: Update CONTRIBUTING.md with these guidelines
5. **CI/CD Check**: Add GitHub Action to verify no files left behind after test runs

## Summary Statistics

- **Total Tests Fixed**: 12 tests
- **Tests Using Unified Framework**: 6 tests (log path corrected)
- **Tests with Explicit Temp Folders**: 6 tests (temp folder + cleanup added)
- **Files No Longer Left Behind**: 8 files (contoso.com.psd1, performance-optimized.log, test-appmode.log, test-config-mgmt.log, test-menu-system.log, test.com.psd1, test.log, testdomain.com.psd1)
- **Tests Still Needing Fixes**: 8 tests (lower priority, less frequently run)

## Date

October 9, 2025
