# Exclude Switch Implementation

## Overview
This document describes the implementation of the `-Exclude` switch parameter in `Invoke-PesterTests.ps1`, which inverts the filtering logic for `-Tags`, `-TestFile`, and `-TestType` parameters.

**Date**: October 21, 2025  
**Author**: AI Assistant  
**Status**: ✅ Complete

---

## Feature Description

The `-Exclude` switch allows users to run all tests **except** those matching specified criteria, rather than running **only** matching tests. This is useful for scenarios like:

- Running all tests except slow integration tests during development
- Excluding specific problematic test files while debugging
- Running unit + comprehensive tests but skipping integration tests

---

## Implementation Details

### 1. Parameter Definition

**Location**: `Invoke-PesterTests.ps1` (line ~111)

```powershell
[Parameter(ParameterSetName = 'Default')]
[Parameter(ParameterSetName = 'CodeCoverage')]
[switch]$Exclude
```

The parameter is available in both parameter sets and works with:
- `-Tags`: Excludes tests with specified tags
- `-TestFile`: Excludes specified test files
- `-TestType`: Excludes specified test type category

---

### 2. Tag Exclusion

**Location**: `Invoke-PesterTests.ps1` (lines ~680-690)

```powershell
# Apply tag filter if specified
if ($Tags.Count -gt 0)
{
    if ($Exclude)
    {
        $config.Filter.ExcludeTag = $Tags
    }
    else
    {
        $config.Filter.Tag = $Tags
    }
}
```

**Behavior**:
- Normal mode: Uses `$config.Filter.Tag` to include only tests with specified tags
- Exclude mode: Uses `$config.Filter.ExcludeTag` to exclude tests with specified tags
- Leverages built-in Pester 5 exclusion filtering

**Example**:
```powershell
# Run only slow tests
.\Invoke-PesterTests.ps1 -Tags "Slow"

# Run everything except slow tests
.\Invoke-PesterTests.ps1 -Tags "Slow" -Exclude
```

---

### 3. File Exclusion

**Location**: `Invoke-PesterTests.ps1` (lines ~600-670)

#### 3.1 Fuzzy Search Results (Multiple Files)

```powershell
if ($foundPath -is [array])
{
    Write-Host ""
    Write-Host "Using $($foundPath.Count) selected test file(s)" -ForegroundColor Green
    
    # Handle exclusion mode
    if ($Exclude)
    {
        # Get all test files and exclude the found ones
        $allTestFiles = Get-ChildItem -Path $testsPath -Recurse -Filter "*.Tests.ps1" | 
            Where-Object { $_.FullName -notin $foundPath }
        $config.Run.Path = $allTestFiles.FullName
        Write-Host "Excluding $($foundPath.Count) file(s), running $($allTestFiles.Count) remaining test(s)" -ForegroundColor Yellow
    }
    else
    {
        $config.Run.Path = $foundPath
    }
}
```

#### 3.2 Fuzzy Search Results (Single File)

```powershell
else
{
    $resolvedPath = $foundPath
    Write-Host ""
    Write-Host "Using selected test file: $resolvedPath" -ForegroundColor Green
    
    # Handle exclusion mode
    if ($Exclude)
    {
        # Get all test files and exclude the found one
        $allTestFiles = Get-ChildItem -Path $testsPath -Recurse -Filter "*.Tests.ps1" | 
            Where-Object { $_.FullName -ne $resolvedPath }
        $config.Run.Path = $allTestFiles.FullName
        Write-Host "Excluding this file, running $($allTestFiles.Count) remaining test(s)" -ForegroundColor Yellow
    }
    else
    {
        $config.Run.Path = $resolvedPath
    }
}
```

#### 3.3 Direct File Path

```powershell
else
{
    # Handle exclusion mode for directly specified file
    if ($Exclude)
    {
        # Get all test files and exclude the specified one
        $testsPath = Join-Path $PSScriptRoot "tests"
        $allTestFiles = Get-ChildItem -Path $testsPath -Recurse -Filter "*.Tests.ps1" | 
            Where-Object { $_.FullName -ne $resolvedPath }
        $config.Run.Path = $allTestFiles.FullName
        Write-Host "`nExcluding test file: $(Split-Path -Leaf $resolvedPath)" -ForegroundColor Yellow
        Write-Host "Running $($allTestFiles.Count) remaining test(s)" -ForegroundColor Yellow
    }
    else
    {
        $config.Run.Path = $resolvedPath
        Write-Host "`nRunning single test file: $(Split-Path -Leaf $resolvedPath)" -ForegroundColor Yellow
    }
}
```

**Behavior**:
- Normal mode: Runs only the specified file(s)
- Exclude mode: Gets all `*.Tests.ps1` files in the tests folder, then excludes the specified file(s)
- Works with fuzzy search, multiple file selection, and direct file paths
- Provides clear feedback about exclusion count and remaining tests

**Example**:
```powershell
# Run only Graph API tests
.\Invoke-PesterTests.ps1 -TestFile "GraphAPI"

# Run everything except Graph API tests
.\Invoke-PesterTests.ps1 -TestFile "GraphAPI" -Exclude
```

---

### 4. TestType Exclusion

**Location**: `PesterConfiguration.ps1` (lines ~20-60)

#### 4.1 Configuration Function Update

Added `-Exclude` parameter to `Get-AutopilotPesterConfiguration`:

```powershell
function Get-AutopilotPesterConfiguration
{
    [CmdletBinding()]
    param(
        [ValidateSet('Unit', 'Integration', 'Comprehensive', 'All')]
        [string]$TestType = 'All',
        [ValidateSet('None', 'Minimal', 'Normal', 'Detailed')]
        [string]$OutputVerbosity = 'Normal',
        [switch]$EnableCodeCoverage,
        [switch]$CI,
        [switch]$Exclude  # NEW
    )
```

#### 4.2 Exclusion Logic

```powershell
# Test discovery - handle exclusion mode
if ($Exclude -and $TestType -ne 'All')
{
    # Exclusion mode: run everything EXCEPT the specified type
    switch ($TestType)
    {
        'Unit'
        {
            $config.Run.Path = @('.\tests\Integration', '.\tests\Comprehensive')
            $config.Filter.Tag = @('Integration', 'Comprehensive')
        }
        'Integration'
        {
            $config.Run.Path = @('.\tests\Unit', '.\tests\Comprehensive')
            $config.Filter.Tag = @('Unit', 'Comprehensive')
        }
        'Comprehensive'
        {
            $config.Run.Path = @('.\tests\Unit', '.\tests\Integration')
            $config.Filter.Tag = @('Unit', 'Integration')
        }
    }
    # Note: -TestType All with -Exclude is not meaningful, so it's ignored
    # and behaves the same as -TestType All without -Exclude
}
elseif ($TestType -ne 'All')
{
    # Normal inclusion mode (existing logic)
    switch ($TestType)
    {
        'Unit'
        {
            $config.Run.Path = '.\tests\Unit'
            $config.Filter.Tag = 'Unit'
        }
        # ... etc
    }
}
```

#### 4.3 Function Call Update

**Location**: `Invoke-PesterTests.ps1` (line ~127)

```powershell
# Get Pester configuration
$config = Get-AutopilotPesterConfiguration -TestType $TestType -EnableCodeCoverage:$EnableCodeCoverage -CI:$CI -OutputVerbosity $OutputVerbosity -Exclude:$Exclude
```

**Behavior**:
- Normal mode: Runs only tests of specified type (Unit, Integration, or Comprehensive)
- Exclude mode: Runs all tests **except** the specified type
- Special case: `-TestType All -Exclude` is meaningless and behaves as `-TestType All` (runs everything)

**Exclusion Matrix**:
| Command | Runs |
|---------|------|
| `-TestType Unit -Exclude` | Integration + Comprehensive |
| `-TestType Integration -Exclude` | Unit + Comprehensive |
| `-TestType Comprehensive -Exclude` | Unit + Integration |
| `-TestType All -Exclude` | All tests (same as no -Exclude) |

**Example**:
```powershell
# Run only unit tests
.\Invoke-PesterTests.ps1 -TestType Unit

# Run integration and comprehensive tests (exclude unit)
.\Invoke-PesterTests.ps1 -TestType Unit -Exclude
```

---

### 5. Display Configuration Updates

#### 5.1 TestType Display

**Location**: `Invoke-PesterTests.ps1` (lines ~693-700)

```powershell
# Display configuration
Write-Host "`nTest Configuration:" -ForegroundColor Cyan
if ($Exclude -and $TestType -ne 'All')
{
    Write-Host "  Test Type: $TestType (EXCLUDING)" -ForegroundColor White
}
else
{
    Write-Host "  Test Type: $TestType" -ForegroundColor White
}
```

**Behavior**: Shows "(EXCLUDING)" suffix when `-Exclude` is used with a specific test type

#### 5.2 Tags Display

**Location**: `Invoke-PesterTests.ps1` (lines ~710-720)

```powershell
if ($Tags.Count -gt 0)
{
    if ($Exclude)
    {
        Write-Host "  Excluding Tags: $($Tags -join ', ')" -ForegroundColor White
    }
    else
    {
        Write-Host "  Tags: $($Tags -join ', ')" -ForegroundColor White
    }
}
```

**Behavior**: Shows "Excluding Tags:" prefix when `-Exclude` is used with tags

#### 5.3 File Display

File exclusion feedback is shown inline during file resolution:
- "Excluding this file, running N remaining test(s)"
- "Excluding N file(s), running N remaining test(s)"

---

## Usage Examples

### Example 1: Exclude Slow Tests

```powershell
# Run all tests except those tagged "Slow"
.\Invoke-PesterTests.ps1 -Tags "Slow" -Exclude
```

**Output**:
```
Test Configuration:
  Test Type: All
  Excluding Tags: Slow
```

### Example 2: Exclude Unit Tests

```powershell
# Run integration and comprehensive tests only
.\Invoke-PesterTests.ps1 -TestType Unit -Exclude
```

**Output**:
```
Test Configuration:
  Test Type: Unit (EXCLUDING)
  Test Path: .\tests\Integration, .\tests\Comprehensive
```

### Example 3: Exclude Specific Test File

```powershell
# Run all tests except Graph API tests
.\Invoke-PesterTests.ps1 -TestFile "GraphAPI" -Exclude
```

**Output**:
```
Test file not found: c:\...\Autopilot\GraphAPI
Fuzzy search results:
1. Get-EntraGraphAPI.Tests.ps1 (Score: 450)
2. Invoke-GraphAPIRequest.Tests.ps1 (Score: 380)
Enter choice (1-2, 'a' for all, 'q' to quit): 1

Using selected test file: Get-EntraGraphAPI.Tests.ps1
Excluding this file, running 144 remaining test(s)

Test Configuration:
  Test Type: All
  Test Files: 144 files selected
```

### Example 4: Exclude Multiple Tags

```powershell
# Run all tests except Integration and Slow tests
.\Invoke-PesterTests.ps1 -Tags "Integration","Slow" -Exclude
```

**Output**:
```
Test Configuration:
  Test Type: All
  Excluding Tags: Integration, Slow
```

### Example 5: Combined Exclusions

```powershell
# Exclude unit tests AND slow tests
.\Invoke-PesterTests.ps1 -TestType Unit -Tags "Slow" -Exclude
```

**Output**:
```
Test Configuration:
  Test Type: Unit (EXCLUDING)
  Test Path: .\tests\Integration, .\tests\Comprehensive
  Excluding Tags: Slow
```

**Note**: This runs Integration and Comprehensive tests, but excludes any that are tagged "Slow"

---

## Edge Cases and Validation

### 1. `-TestType All -Exclude`

**Behavior**: Treated as no-op, equivalent to `-TestType All` without `-Exclude`

**Rationale**: Excluding "all" test types is meaningless and would result in running no tests

### 2. `-Exclude` Without Other Parameters

**Behavior**: No effect, runs all tests normally

**Rationale**: `-Exclude` only modifies behavior of `-Tags`, `-TestFile`, or `-TestType`

### 3. Interactive Mode with `-Exclude`

**Example**:
```powershell
.\Invoke-PesterTests.ps1 -Tags "Interactive" -Exclude
```

**Behavior**:
1. Detects "Interactive" keyword
2. Presents tag selection menu
3. User selects tag(s) to exclude
4. Runs all tests except those with selected tags

**Note**: Interactive file selection also works with `-Exclude`

### 4. Fuzzy Search with `-Exclude`

**Example**:
```powershell
.\Invoke-PesterTests.ps1 -TestFile "graph" -Exclude
```

**Behavior**:
1. Fuzzy search finds matching files
2. User selects file(s) to exclude
3. All other tests run

**Note**: Multiple file selection is supported with exclusion

---

## Testing Validation

### Manual Test Cases

#### Test Case 1: Tag Exclusion
```powershell
# Should run all tests except Unit tests
.\Invoke-PesterTests.ps1 -Tags "Unit" -Exclude
```

**Expected**: Integration and Comprehensive tests run

#### Test Case 2: File Exclusion
```powershell
# Should run all tests except one file
.\Invoke-PesterTests.ps1 -TestFile ".\tests\Unit\Get-EntraDirectoryObject.Tests.ps1" -Exclude
```

**Expected**: 144+ tests run (all except the specified file)

#### Test Case 3: TestType Exclusion
```powershell
# Should run Unit and Comprehensive tests
.\Invoke-PesterTests.ps1 -TestType Integration -Exclude
```

**Expected**: Unit and Comprehensive folders scanned, Integration skipped

#### Test Case 4: Combined Exclusion
```powershell
# Should run non-Unit tests that aren't tagged Slow
.\Invoke-PesterTests.ps1 -TestType Unit -Tags "Slow" -Exclude
```

**Expected**: Integration and Comprehensive tests run, excluding any tagged "Slow"

#### Test Case 5: Interactive Tag Exclusion
```powershell
# Should present tag menu and exclude selected tags
.\Invoke-PesterTests.ps1 -Tags "Interactive" -Exclude
```

**Expected**: Tag selection menu appears, selected tags are excluded from test run

---

## Implementation Notes

### Design Decisions

1. **Single Switch Parameter**: Used one `-Exclude` switch instead of separate `-ExcludeTags`, `-ExcludeFile`, etc.
   - **Rationale**: Simpler API, no parameter explosion, intuitive behavior

2. **PesterConfiguration Update**: Modified `Get-AutopilotPesterConfiguration` to accept `-Exclude`
   - **Rationale**: TestType exclusion requires changing test paths, which is handled in configuration function

3. **File Exclusion Strategy**: Get all test files, then filter out excluded ones
   - **Rationale**: Simple, reliable, works with fuzzy search and multiple file selection

4. **Display Updates**: Show exclusion mode clearly in configuration output
   - **Rationale**: User feedback critical for understanding what tests will run

5. **Interactive Mode Compatibility**: Works with "Interactive" keyword for both tags and files
   - **Rationale**: Consistent UX, allows dynamic exclusion selection

### Code Quality

- ✅ No syntax errors
- ✅ Consistent parameter handling across all three filtering types
- ✅ Clear user feedback for all exclusion scenarios
- ✅ Leverages existing helper functions (Select-ItemsFromList, Find-FileWithFuzzySearch)
- ⚠️ Pre-existing lint warning: `$hasErrors` unused (line 366, unrelated to this feature)

### Backwards Compatibility

- ✅ All existing functionality preserved
- ✅ `-Exclude` is optional, default behavior unchanged
- ✅ No breaking changes to existing scripts or workflows

---

## Future Enhancements

### Potential Improvements

1. **Regex Pattern Exclusion**: Support regex patterns for file exclusion
   ```powershell
   .\Invoke-PesterTests.ps1 -TestFile "*Graph*" -Exclude
   ```

2. **Exclusion Presets**: Define named exclusion sets in configuration
   ```powershell
   .\Invoke-PesterTests.ps1 -ExcludePreset "Development"
   # Excludes: Slow tests, Integration tests, known problematic tests
   ```

3. **Dry Run Mode**: Show what would be excluded without running tests
   ```powershell
   .\Invoke-PesterTests.ps1 -Tags "Slow" -Exclude -WhatIf
   ```

4. **Exclusion History**: Track commonly excluded tests for reporting
   - Helps identify problematic tests that are frequently excluded

---

## Related Documentation

- **Main Script**: `Invoke-PesterTests.ps1`
- **Configuration**: `PesterConfiguration.ps1`
- **Testing Guide**: `docs/GITHUB_ACTIONS_TESTING_GUIDE.md`
- **Tag Selection**: `docs/features/TAG_SELECTION_FEATURE.md`
- **File Selection**: `docs/features/MULTIPLE_FILE_SELECTION_FEATURE.md`
- **Interactive Mode**: `docs/features/INTERACTIVE_TEST_SELECTION.md`

---

## Summary

The `-Exclude` switch provides a powerful and intuitive way to run all tests **except** those matching specified criteria. It works seamlessly with existing filtering parameters (`-Tags`, `-TestFile`, `-TestType`) and interactive selection features, providing a consistent user experience across all exclusion scenarios.

**Key Benefits**:
- Simple API (single switch parameter)
- Works with all existing filtering mechanisms
- Clear user feedback
- Leverages built-in Pester exclusion features where available
- No breaking changes
- Backwards compatible

**Implementation Status**: ✅ Complete and ready for use
