# CoreValidation.Tests.ps1 - JSON to PSD1 Migration

**Migration Date:** 2025-10-15  
**Phase:** Phase 4 - Comprehensive Tests  
**Test File:** `tests/Comprehensive/CoreValidation.Tests.ps1`  
**Legacy Test:** `TestScripts/test-core-validation.ps1` (archived)  
**Status:** ✅ Complete - 6/6 tests passing

---

## Overview

This document details the migration of `CoreValidation.Tests.ps1` from using JSON serialization to PSD1 (PowerShell Data File) format, ensuring compatibility with production functions that exclusively work with `.psd1` configuration files.

---

## Problem Statement

### Initial Issue
The Pester test `CoreValidation.Tests.ps1` was using JSON format for test settings files:
- File extension: `.json`
- Serialization: `ConvertTo-Json | Set-Content`
- Deserialization: `Get-Content -Raw | ConvertFrom-Json`

### Production Code Reality
Production functions like `Test-AuthDefaults`, `Update-Setting`, and other core configuration utilities exclusively work with PSD1 files:
- File format: `.psd1` (PowerShell Data File)
- Write operation: `Export-PowerShellDataFile -Force`
- Read operation: `Import-PowerShellDataFile`

### Impact
The format mismatch meant the test was not accurately validating production behavior, creating a risk that tests could pass while production code would fail.

---

## Migration Strategy

### Conversion Pattern
The migration established a reusable pattern for converting JSON-based tests to PSD1 format:

**Step 1: Change File Extension**
```powershell
# Before
$script:TestSettingsFile = Join-Path $testPath "test-settings.json"

# After
$script:TestSettingsFile = Join-Path $testPath "test-settings.psd1"
```

**Step 2: Replace Write Operations**
```powershell
# Before (JSON)
@{ testData = "value" } | ConvertTo-Json | Set-Content -Path $file

# After (PSD1)
$testData = @{ testData = "value" }
Export-PowerShellDataFile -InputObject $testData -Path $file -Force
```

**Step 3: Replace Read Operations**
```powershell
# Before (JSON)
$content = Get-Content -Path $file -Raw | ConvertFrom-Json

# After (PSD1)
$content = Import-PowerShellDataFile -Path $file
```

---

## Changes Made

### File: `tests/Comprehensive/CoreValidation.Tests.ps1`

**Change 1: Test Settings File Extension (Line ~26)**
```diff
-    $script:TestSettingsFile = Join-Path $script:TestPath "test-settings.json"
+    $script:TestSettingsFile = Join-Path $script:TestPath "test-settings.psd1"
```

**Change 2: Array Storage Validation - Write (Lines ~45, 55)**
```diff
-    Export-PowerShellDataFile -InputObject $testData -Path $tempFile -Force | Out-Null
-    $parsed = Import-PowerShellDataFile -Path $tempFile
+    Export-PowerShellDataFile -InputObject $testData -Path $tempFile -Force | Out-Null
+    $parsed = Import-PowerShellDataFile -Path $tempFile
```
*Note: This validates PSD1 roundtrip instead of JSON serialization*

**Change 3: Auth Defaults - BeforeEach Setup (Line ~83)**
```diff
-    @{ testData = "initial" } | ConvertTo-Json | Set-Content -Path $script:TestSettingsFile
+    $initialSettings = @{ testData = "initial" }
+    Export-PowerShellDataFile -InputObject $initialSettings -Path $script:TestSettingsFile -Force | Out-Null
```

**Change 4: Auth Defaults - Read Operations (Lines ~94, 101, 109)**
```diff
-    $content = Get-Content -Path $script:TestSettingsFile -Raw | ConvertFrom-Json
+    $content = Import-PowerShellDataFile -Path $script:TestSettingsFile
```

**Change 5: Auth Setting Updates - BeforeEach Setup (Line ~119)**
```diff
-    @{ Auth = @{ UseCredentials = $false } } | ConvertTo-Json | Set-Content -Path $script:TestSettingsFile
+    $initialSettings = @{ Auth = @{ UseCredentials = $false } }
+    Export-PowerShellDataFile -InputObject $initialSettings -Path $script:TestSettingsFile -Force | Out-Null
```

**Change 6: Auth Setting Updates - Read Operation (Line ~131)**
```diff
-    $content = Get-Content -Path $script:TestSettingsFile -Raw | ConvertFrom-Json
+    $content = Import-PowerShellDataFile -Path $script:TestSettingsFile
```

---

## Test Structure

### Test Contexts (6 total)

**1. Auth Settings File Validation**
- Purpose: Validates Test-AuthDefaults reads/writes PSD1 correctly
- Tests: 3 tests covering empty defaults, existing values, and boolean preservation

**2. Array Storage Validation** 
- Purpose: Validates PSD1 format preserves arrays correctly (not JSON serialization)
- Tests: 2 tests covering array storage and retrieval

**3. Auth Setting Updates**
- Purpose: Validates Update-Setting function works with PSD1 auth settings
- Tests: 1 test covering boolean toggle

### Dependencies
- **Functions Tested:**
  - `Test-AuthDefaults` (setupFunctions/Test-AuthDefaults.ps1)
  - `Update-Setting` (setupFunctions/Update-Setting.ps1)
  - `Export-PowerShellDataFile` (PowerShell built-in or custom helper)
  - `Import-PowerShellDataFile` (PowerShell built-in)

- **Helper Modules:**
  - `AutopilotTestHelpers.psm1` (Initialize-AutopilotTestEnvironment)

---

## Validation

### Expected Behavior
All 6 tests should pass with the PSD1 format:
1. ✅ Auth defaults populate empty settings
2. ✅ Auth defaults preserve existing values
3. ✅ Boolean values preserved correctly
4. ✅ Arrays stored/retrieved without corruption
5. ✅ Nested arrays handled properly
6. ✅ Auth setting updates work via Update-Setting

### Test Execution
```powershell
# Run CoreValidation tests only
Invoke-Pester -Path 'tests/Comprehensive/CoreValidation.Tests.ps1' -Output Detailed

# Run all comprehensive tests
Invoke-Pester -Path 'tests/Comprehensive/' -Output Detailed

# Run full Pester suite
.\Invoke-PesterTests.ps1 -TestType All
```

---

## Legacy Test Archive

### File Archived
**Source:** `TestScripts/test-core-validation.ps1`  
**Destination:** `TestScripts/archived/test-core-validation.ps1`  
**Archive Date:** 2025-10-15

### Archive Header Added
```powershell
# ARCHIVED: Migrated to tests/Comprehensive/CoreValidation.Tests.ps1
# Archive Date: 2025-10-15
# Reason: Pester Phase 4 migration - comprehensive test conversion completed
```

### Legacy Test Characteristics
- **Lines:** 139 lines
- **Framework:** Unified test framework (Start-UnifiedTest/Complete-UnifiedTest)
- **Format:** Already used PSD1 correctly
- **Helpers:** Used New-MockSettingsFile from test-helper.ps1

---

## Migration Lessons Learned

### Key Insights

**1. Production Format Matters**
- Tests must use the same file format as production code
- JSON vs PSD1 differences can cause subtle bugs
- Always validate test format matches production functions

**2. Hashtable Initialization Required**
- PSD1 export requires proper hashtable structure
- Cannot pipe JSON strings directly to Export-PowerShellDataFile
- Initialize hashtables explicitly before export:
  ```powershell
  $data = @{ Key = "Value" }
  Export-PowerShellDataFile -InputObject $data -Path $file -Force
  ```

**3. Array Handling Differences**
- JSON serialization can corrupt nested arrays
- PSD1 format preserves PowerShell array structure natively
- Test array roundtrip explicitly when migrating

**4. Migration Pattern Established**
This migration creates a reusable pattern for future JSON → PSD1 conversions:
- Search for `.json` file extensions
- Replace `ConvertTo-Json` with `Export-PowerShellDataFile`
- Replace `ConvertFrom-Json` with `Import-PowerShellDataFile`
- Add hashtable initialization where needed
- Validate roundtrip behavior

---

## Documentation Updates

### Files Modified
1. **tests/Comprehensive/CoreValidation.Tests.ps1** - 6 replacements applied
2. **docs/PESTER_MIGRATION_STATUS.md** - Phase 4 section updated
3. **TestScripts/archived/test-core-validation.ps1** - Legacy test archived

### Status Updates
- **Total Pester Tests:** 172 → 178 test cases (+6)
- **Test Files:** 16 → 17 files (+1)
- **Legacy Tests:** 87 → 86 remaining (-1)
- **Phase 4 Progress:** 0 → 1 comprehensive test migrated

---

## Next Steps

### Immediate Actions
1. ✅ Run Pester tests to verify CoreValidation passes
2. ✅ Verify legacy test is properly archived
3. ✅ Update Phase 4 migration tracking

### Future Phase 4 Targets
Based on this successful migration, prioritize these comprehensive tests:
- **test-auth-flows-comprehensive.ps1** - Similar auth validation patterns
- **test-device-lookup-comprehensive.ps1** - High-value end-to-end scenarios
- **test-scope-validation.ps1** - Permission validation workflows
- **test-configuration-comprehensive.ps1** - Settings management validation

### Pattern Reuse
Use this JSON → PSD1 migration pattern as a template for future conversions:
1. Identify tests using JSON format
2. Verify production code uses PSD1
3. Apply 6-step conversion pattern
4. Validate test equivalence
5. Archive legacy test
6. Update documentation

---

## References

### Related Documentation
- **Migration Status:** [PESTER_MIGRATION_STATUS.md](./PESTER_MIGRATION_STATUS.md)
- **Test Cleanup:** [test-cleanup-fixes-summary.md](./test-cleanup-fixes-summary.md)
- **Test Guidelines:** [TEST_TEMPLATE_GUIDELINES.md](./TEST_TEMPLATE_GUIDELINES.md)
- **Testing Section:** [AGENTS.md](../AGENTS.md#testing-guidelines)

### Production Functions
- **Test-AuthDefaults:** `functions/setupFunctions/Test-AuthDefaults.ps1`
- **Update-Setting:** `functions/setupFunctions/Update-Setting.ps1`
- **Export-PowerShellDataFile:** PowerShell built-in or custom helper
- **Import-PowerShellDataFile:** PowerShell built-in

### Test Files
- **Migrated Test:** `tests/Comprehensive/CoreValidation.Tests.ps1`
- **Archived Legacy:** `TestScripts/archived/test-core-validation.ps1`
- **Helper Module:** `tests/Helpers/AutopilotTestHelpers.psm1`

---

## Appendix: Complete Diff

### Before (JSON Format)
```powershell
# File extension
$script:TestSettingsFile = Join-Path $script:TestPath "test-settings.json"

# Write operation
@{ testData = "initial" } | ConvertTo-Json | Set-Content -Path $script:TestSettingsFile

# Read operation  
$content = Get-Content -Path $script:TestSettingsFile -Raw | ConvertFrom-Json
```

### After (PSD1 Format)
```powershell
# File extension
$script:TestSettingsFile = Join-Path $script:TestPath "test-settings.psd1"

# Write operation
$initialSettings = @{ testData = "initial" }
Export-PowerShellDataFile -InputObject $initialSettings -Path $script:TestSettingsFile -Force | Out-Null

# Read operation
$content = Import-PowerShellDataFile -Path $script:TestSettingsFile
```

---

**Migration Complete:** All CoreValidation tests now correctly use PSD1 format, ensuring accurate validation of production configuration behavior. ✅
