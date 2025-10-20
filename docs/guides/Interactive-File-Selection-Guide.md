# Interactive Test File Selection Feature

## Overview
The `Invoke-PesterTests.ps1` script now supports interactive file selection, allowing you to browse and select multiple test files to run interactively.

## Usage Methods

### Method 1: Specify Exact File Path (Traditional)
```powershell
# Run a specific test file with full path
.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\SettingsFunctions.Tests.ps1"

# Run a specific test file with just filename
.\Invoke-PesterTests.ps1 -TestFile "SettingsFunctions.Tests.ps1"
```

### Method 2: Fuzzy Search with Multiple Selection
```powershell
# Search for files matching "Settings" - select one or more
.\Invoke-PesterTests.ps1 -TestFile "Settings"
```

When multiple matches are found, you can now select multiple files using comma-separated numbers:
```
Selection: 1,3,5    # Select files 1, 3, and 5
Selection: a        # Select all matched files
Selection: q        # Quit without running
```

### Method 3: Interactive File Browser (New!)
```powershell
# Show full test file browser
.\Invoke-PesterTests.ps1 -TestFile ""
```

This displays ALL test files in the project and allows multi-select.

## Interactive File Browser Example

```powershell
PS> .\Invoke-PesterTests.ps1 -TestFile ""

===============================================================
  Autopilot Pester Test Suite
===============================================================

Loading test files...

===============================================================
  Available Test Files
===============================================================

  [1] tests\Unit\AppMode.Tests.ps1
  [2] tests\Unit\Assignment.Tests.ps1
  [3] tests\Unit\Authentication.Tests.ps1
  [4] tests\Unit\AutopilotFunctions.Tests.ps1
  [5] tests\Unit\ConfigurationLoading.Tests.ps1
  [6] tests\Unit\DeviceFunctions.Tests.ps1
  [7] tests\Unit\EncryptionFunctions.Tests.ps1
  [8] tests\Unit\GraphFunctions.Tests.ps1
  [9] tests\Unit\MenuFunctions.Tests.ps1
  [10] tests\Unit\SettingsFunctions.Tests.ps1
  ...
  [50] tests\Comprehensive\EndToEnd.Tests.ps1

  [a] Select All
  [q] Quit

Enter file numbers (comma-separated, e.g., 1,3,5) or 'a' for all:
Selection:
```

## Selection Options

### Select Specific Files
Enter comma-separated numbers:
```
Selection: 1,5,10
```
This selects files 1, 5, and 10 to run together.

### Select All Files
```
Selection: a
```
Runs all displayed files.

### Quit/Cancel
```
Selection: q
```
Exits without running tests.

## Common Scenarios

### Scenario 1: Run Related Test Files Together
```powershell
.\Invoke-PesterTests.ps1 -TestFile "Graph"

# Menu shows:
# [1] GraphFunctions.Tests.ps1
# [2] GraphAuthentication.Tests.ps1
# [3] GraphDeviceQueries.Tests.ps1

Selection: 1,2,3    # Run all Graph-related tests
```

### Scenario 2: Run All Configuration Tests
```powershell
.\Invoke-PesterTests.ps1 -TestFile "Config"

# Menu shows matching files
# Select all with: a
```

### Scenario 3: Browse and Pick Tests
```powershell
.\Invoke-PesterTests.ps1 -TestFile ""

# Browse full list
# Pick tests: 5,12,23,45
```

### Scenario 4: Quick Test of Multiple Components
```powershell
.\Invoke-PesterTests.ps1 -TestFile ""

# Select tests for features you just modified
Selection: 7,9,14    # Encryption, Menu, Settings
```

## Integration with Tags

You can combine file selection with tag filtering:

```powershell
# Select specific files, then filter by tags
.\Invoke-PesterTests.ps1 -TestFile "Functions" -Tags "Unit", "Fast"
```

This will:
1. Show fuzzy search results for files matching "Functions"
2. Let you select multiple files
3. Run only tests in those files that have both "Unit" and "Fast" tags

## Benefits

### 1. Flexibility
- Select one or many files in a single run
- No need to remember exact file paths
- Quick iteration on related tests

### 2. Discovery
- Browse available test files
- See file organization
- Find tests by partial name match

### 3. Efficiency
- Run multiple files without typing full paths
- Group related tests easily
- Quick smoke testing of modified areas

### 4. Developer Workflow
```powershell
# Developer working on user and device functions
.\Invoke-PesterTests.ps1 -TestFile ""

# Selects:
# - UserFunctions.Tests.ps1
# - DeviceFunctions.Tests.ps1
# - GraphFunctions.Tests.ps1

# All run together in one session
```

## Comparison: Single vs Multiple Selection

### Old Behavior (Single Selection Only)
```powershell
PS> .\Invoke-PesterTests.ps1 -TestFile "Config"

Found 3 similar files:
  [1] ConfigurationLoading.Tests.ps1
  [2] ConfigurationStorage.Tests.ps1
  [3] ConfigurationValidation.Tests.ps1

Select a file (1-3) or 'q' to quit: 1

# Only runs ConfigurationLoading.Tests.ps1
# Need to run script again for other files
```

### New Behavior (Multiple Selection)
```powershell
PS> .\Invoke-PesterTests.ps1 -TestFile "Config"

Found 3 similar files:
  [1] ConfigurationLoading.Tests.ps1
  [2] ConfigurationStorage.Tests.ps1
  [3] ConfigurationValidation.Tests.ps1

  [a] Select All
  [q] Quit

Enter file numbers (comma-separated, e.g., 1,3,5) or 'a' for all:
Selection: a

# Runs all 3 files in one session!
```

## Technical Details

### Code Reuse
The implementation leverages:
- `Select-ItemsFromList()` - Generic selection function
- `Select-TestFiles()` - File-specific wrapper
- `Select-Tags()` - Tag-specific wrapper (refactored to use generic function)

### Architecture
```
Select-ItemsFromList (Generic)
    ├── Select-TestFiles (Files)
    └── Select-Tags (Tags)
```

### File Selection Flow
1. User triggers interactive mode (`-TestFile ""` or fuzzy search returns multiple)
2. `Find-FileWithFuzzySearch` calls `Select-TestFiles` with `-AllowMultiple`
3. `Select-TestFiles` calls `Select-ItemsFromList` with file-specific formatting
4. User makes selection(s)
5. Selected file paths returned as array
6. Pester configuration updated with array of paths
7. All selected files run in single Pester session

### Performance
- File listing: <1 second for ~200 test files
- Multi-file execution: Same overhead as TestType filtering
- Results aggregated across all selected files

## Examples & Use Cases

### Use Case 1: Testing a Feature Branch
```powershell
# You modified user and group functions
.\Invoke-PesterTests.ps1 -TestFile ""

# Select all user/group related tests:
Selection: 15,16,23,24    # All user and group test files
```

### Use Case 2: Quick Smoke Test
```powershell
# Run fast critical tests before commit
.\Invoke-PesterTests.ps1 -TestFile "" -Tags "Fast", "Critical"

# Select essential files:
Selection: 1,3,7,12
```

### Use Case 3: Integration Testing
```powershell
# Test all integration tests for modified subsystem
.\Invoke-PesterTests.ps1 -TestFile "Integration"

# Select all integration tests:
Selection: a
```

### Use Case 4: Debugging Multiple Failures
```powershell
# Test results showed failures in files 5, 12, and 23
.\Invoke-PesterTests.ps1 -TestFile ""

# Re-run just those files:
Selection: 5,12,23
```

## Tips & Best Practices

### Tip 1: Use Fuzzy Search for Grouping
```powershell
# Get all "Functions" tests at once
.\Invoke-PesterTests.ps1 -TestFile "Functions"
# Shows: GraphFunctions, UserFunctions, DeviceFunctions, etc.
# Select all: a
```

### Tip 2: Combine with Coverage
```powershell
.\Invoke-PesterTests.ps1 -TestFile "" -EnableCodeCoverage

# Select files covering features you changed
# Get coverage for just those areas
```

### Tip 3: Create Aliases for Common Selections
```powershell
# In your PowerShell profile
function Test-CoreFunctions {
    # Pre-defined file numbers for core tests
    # This approach requires manual maintenance
    .\Invoke-PesterTests.ps1 -TestFile "Core"
}

# Better: Use tags for grouping
function Test-CoreFunctions {
    .\Invoke-PesterTests.ps1 -Tags "Core"
}
```

### Tip 4: Interactive Mode for Discovery
```powershell
# New to the project? Browse all tests
.\Invoke-PesterTests.ps1 -TestFile ""

# See what's available, learn test organization
# Quit without running: q
```

## Troubleshooting

### No Files Found
If fuzzy search returns no files:
- Check spelling of search term
- Try shorter search term (e.g., "Func" instead of "Functions")
- Use interactive browser: `-TestFile ""`

### Selection Not Working
Common issues:
- Entering file paths instead of numbers
- Using spaces in comma list (e.g., "1, 2, 3" - remove spaces)
- Using ranges (e.g., "1-5" - use "1,2,3,4,5" instead)

### Too Many Files Listed
If fuzzy search returns too many matches:
- Be more specific: "GraphFunctions" instead of "Graph"
- Or use interactive mode and select specific ones you want

### Wrong Files Selected
If you selected wrong files:
- Just quit (q) and try again
- No tests run until you confirm selection

## Related Features

### Interactive Tag Selection
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Shows tag browser similar to file browser
```

### Combined File + Tag Selection
```powershell
# Select files interactively
.\Invoke-PesterTests.ps1 -TestFile ""
Selection: 1,5,10

# Then filter by tags in those files
# (Use -Tags parameter when initially calling script)
```

### Proper Combined Workflow
```powershell
# Select both files and tags interactively
.\Invoke-PesterTests.ps1 -TestFile "" -Tags @()

# First shows file selection, then tag selection
# Runs selected files filtered by selected tags
```

## Summary

✅ **Multiple file selection** - Run several test files at once  
✅ **Interactive file browser** - Browse all tests with `-TestFile ""`  
✅ **Fuzzy search multi-select** - Select multiple from search results  
✅ **Comma-separated input** - Easy syntax: `1,3,5,7`  
✅ **Select all option** - Quick `a` to run all matches  
✅ **Code reuse** - Unified selection logic for files and tags  
✅ **Backward compatible** - Single file selection still works

## Quick Reference

| Command | Description |
|---------|-------------|
| `.\Invoke-PesterTests.ps1 -TestFile ""` | Browse and select multiple files |
| `.\Invoke-PesterTests.ps1 -TestFile "Pattern"` | Fuzzy search and select multiple |
| `Selection: 1,3,5` | Select files 1, 3, and 5 |
| `Selection: a` | Select all displayed files |
| `Selection: q` | Cancel and quit |

## Architecture Diagram

```
User Input: -TestFile ""
    ↓
Load all test files
    ↓
Select-TestFiles (AllowMultiple: true)
    ↓
Select-ItemsFromList (generic function)
    ├── Display numbered list
    ├── Accept comma-separated input
    ├── Handle 'a' for all
    └── Handle 'q' to quit
    ↓
Return array of selected file paths
    ↓
Update Pester configuration
    ↓
Invoke-Pester with multiple paths
    ↓
Aggregated results across all files
```
