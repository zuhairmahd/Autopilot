# Test Artifact Cleanup Fix

## Issue Summary

When running tests, a file named `nonexistent.psd1` was being created in the project root directory (`c:\Users\zuhai\code\Autopilot\`). This document describes the investigation and fixes applied.

## Root Cause Analysis

The issue was traced to multiple test scripts that were not properly using temporary directories for test artifacts:

### 1. `test-function-loading-validation.ps1`

**Problem**: The test was calling `Get-ConfigurationData` with a relative path:
```powershell
$testResult = Get-ConfigurationData -ConfigurationPath "nonexistent" -DefaultValues @{test = "value"}
```

**Why it created the file**: The `Get-ConfigurationData` function has a feature where it automatically creates missing configuration files from defaults (lines 90-151 in `Get-ConfigurationData.ps1`):

```powershell
if (-not $createdFromDefaults -and $DefaultValues -and $DefaultValues.Count -gt 0)
{
    $null = Export-PowerShellDataFile -InputObject $DefaultValues -Path $psd1Path -Force
    Write-Host "Created missing $psd1Path from provided defaults" -ForegroundColor Yellow
    $createdFromDefaults = $true
}
```

Since the test passed a relative path, it created `nonexistent.psd1` in the current working directory (project root).

**Fix Applied**: Modified the test to use an absolute path within the test's temporary directory:
```powershell
$tempConfigPath = Join-Path $testContext.TestFolder "test-nonexistent"
$testResult = Get-ConfigurationData -ConfigurationPath $tempConfigPath -DefaultValues @{test = "value"}
# Clean up any created file
$createdFile = "$tempConfigPath.psd1"
if (Test-Path $createdFile) {
    Remove-Item $createdFile -Force -ErrorAction SilentlyContinue
}
```

### 2. `test-update-setting-unified.ps1`

**Problem**: The test was passing relative paths to `Update-Setting`:
```powershell
$result = Update-Setting -SettingType "Global" -SettingsFile "nonexistent.psd1"
```

**Why it was problematic**: Although `Update-Setting` doesn't create files when they don't exist, using relative paths could cause issues depending on the current working directory.

**Fix Applied**: Modified to use absolute paths within the test folder:
```powershell
$nonexistentFile = Join-Path $TestConfigFolder "nonexistent.psd1"
$result = Update-Setting -SettingType "Global" -SettingsFile $nonexistentFile
```

### 3. `test-target-build-functionality.ps1`

**Problem**: Similar to above, passing relative path to `CreateRelease.ps1`:
```powershell
& '$createReleaseScript' -TargetsFile 'nonexistent.psd1' -TargetName 'test'
```

**Fix Applied**: Changed to use absolute path in test directory:
```powershell
$nonexistentTargetsFile = Join-Path $testDir "nonexistent.psd1"
& '$createReleaseScript' -TargetsFile '$nonexistentTargetsFile' -TargetName 'test'
```

### 4. `test-array-replace-add-behavior.ps1`

**Problem**: Creating test folder in project root:
```powershell
$TestFolder = Join-Path $RootPath "test-temp-$(Get-Random)"
```

**Fix Applied**: Changed to use system temp directory:
```powershell
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestFolder = Join-Path $tempPath "test-temp-$(Get-Random)"
```

## Best Practices Established

### For Test Scripts

1. **Always use absolute paths** when creating or accessing files, especially in functions that might create missing files
2. **Use temporary directories** for all test artifacts - the `test-helper.ps1` provides `Start-UnifiedTest` which automatically creates temp folders
3. **Clean up after yourself** - remove any created files in the test cleanup phase
4. **Avoid relative paths** in test scripts, as the current working directory may vary

### Pattern to Follow

```powershell
# Load test helper at script level
. "$PSScriptRoot\test-helper.ps1"

# Use temp directory
$tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TestFolder = Join-Path $tempPath "my-test-$(Get-Random)"

# OR use the unified test framework
$testContext = Start-UnifiedTest -TestName "My Test Name"
# TestFolder is available in $testContext.TestFolder

# Use absolute paths for all file operations
$testFile = Join-Path $TestFolder "test-file.psd1"
```

## Verification

After applying the fixes:

1. Removed existing `nonexistent.psd1` from project root
2. Ran `test-function-loading-validation.ps1` - ✅ No artifacts created in project root
3. Ran `test-update-setting-unified.ps1` - ✅ No artifacts created in project root
4. Verified files were created in temp directories as expected

## Files Modified

- `TestScripts/test-function-loading-validation.ps1`
- `TestScripts/test-update-setting-unified.ps1`
- `TestScripts/test-target-build-functionality.ps1`
- `TestScripts/test-array-replace-add-behavior.ps1`

## Future Recommendations

1. **Add a test lint rule** to check for relative paths in test scripts
2. **Document test-helper.ps1 patterns** more prominently
3. **Consider adding a GitHub Actions check** to verify no artifacts are left in the project root after test runs
4. **Update CONTRIBUTING.md** with test artifact best practices

## Related Functions

- `Get-ConfigurationData` (`functions/setupFunctions/Get-ConfigurationData.ps1`) - Creates missing configuration files from defaults
- `Export-PowerShellDataFile` (`functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1`) - Creates directories as needed
- `Start-UnifiedTest` (`TestScripts/test-helper.ps1`) - Provides unified test initialization with temp directory setup

## Date

October 3, 2025
