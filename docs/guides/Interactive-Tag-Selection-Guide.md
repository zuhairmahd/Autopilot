# Interactive Tag Selection Feature

## Overview
The `Invoke-PesterTests.ps1` script now supports interactive tag selection when you pass `-Tags @()`.

## Usage

### Method 1: Specify Tags Directly (Traditional)
```powershell
# Run tests with specific tags
.\Invoke-PesterTests.ps1 -Tags "Unit", "Fast"

# Run Integration tests only
.\Invoke-PesterTests.ps1 -Tags "Integration"
```

### Method 2: Interactive Tag Selection (New!)
```powershell
# Show interactive tag menu
.\Invoke-PesterTests.ps1 -Tags @()
```

## Interactive Menu Example

When you run with `-Tags @()`, you'll see:

```
Scanning test files for available tags...

===============================================================
  Available Test Tags
===============================================================

  [1] AppMode (3 test(s))
  [2] Assignment (2 test(s))
  [3] Authentication (5 test(s))
  [4] Autopilot (4 test(s))
  [5] AutopilotFunctions (8 test(s))
  [6] Comprehensive (12 test(s))
  [7] Configuration (15 test(s))
  [8] ConfigurationLoading (2 test(s))
  [9] Device (6 test(s))
  [10] Domain (3 test(s))
  [11] EncryptionFunctions (10 test(s))
  [12] Fast (5 test(s))
  [13] FunctionLoading (2 test(s))
  [14] Import (3 test(s))
  [15] Integration (25 test(s))
  [16] Main (8 test(s))
  [17] Menu (10 test(s))
  [18] Parameters (2 test(s))
  [19] Profile (4 test(s))
  [20] TestMode (3 test(s))
  [21] TestModeConfig (1 test(s))
  [22] Unit (50 test(s))
  [23] User (2 test(s))

  [a] Select All
  [q] Quit

Enter tag numbers separated by commas (e.g., 1,3,5) or 'a' for all:
Selection:
```

## Selection Options

### Select Specific Tags
Enter comma-separated numbers:
```
Selection: 22,12,13
```
This selects: Unit, Fast, FunctionLoading

### Select All Tags
```
Selection: a
```
Runs all tests with any tags

### Quit/Cancel
```
Selection: q
```
Exits without running tests

## Common Scenarios

### Run All Fast Unit Tests
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Then select: 22,12 (Unit, Fast)
```

### Run All Integration Tests
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Then select: 15 (Integration)
```

### Run All Comprehensive Tests
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Then select: 6 (Comprehensive)
```

### Run All Tests Related to Authentication
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Then select: 3 (Authentication)
```

### Run Multiple Related Categories
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Then select: 7,8,20,21 (Configuration, ConfigurationLoading, TestMode, TestModeConfig)
```

## Benefits

### Discovery
- See all available tags before selecting
- See how many tests use each tag
- No need to remember exact tag names

### Flexibility
- Select multiple tags at once
- Quick "select all" option
- Easy to cancel

### Efficiency
- No manual test file searching
- No typos in tag names
- Quick iteration during development

## Integration with Other Parameters

### With Code Coverage
```powershell
.\Invoke-PesterTests.ps1 -Tags @() -EnableCodeCoverage
# Select tags, then run with coverage
```

### With Specific Test Type
```powershell
# TestType and Tags work together
.\Invoke-PesterTests.ps1 -TestType Unit -Tags @()
# Shows only tags from Unit tests
```

### With CI Mode
```powershell
# For automation, use specific tags instead
.\Invoke-PesterTests.ps1 -Tags "Unit", "Fast" -CI
# Not: -Tags @() -CI (interactive doesn't work well in CI)
```

## Tag Naming Conventions

Common tags in the Autopilot project:

### Test Categories
- `Unit` - Unit tests (isolated, fast)
- `Integration` - Integration tests (multiple components)
- `Comprehensive` - End-to-end tests (full scenarios)

### Functional Areas
- `AppMode` - Application mode tests
- `Authentication` - Auth flow tests
- `Autopilot` - Autopilot device tests
- `Configuration` - Configuration management
- `Device` - Device-related tests
- `Menu` - Menu system tests
- `Profile` - Profile assignment tests

### Special Tags
- `Fast` - Quick-running tests
- `TestMode` - Test mode specific tests
- `Main` - Main script tests

### Module-Specific
- `AutopilotFunctions` - Autopilot function tests
- `EncryptionFunctions` - Encryption function tests
- `FunctionLoading` - Function loading tests

## Tips & Tricks

### Tip 1: Use Fast Tag for Quick Feedback
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Select: 12 (Fast)
# Quick validation in <5 seconds
```

### Tip 2: Run Related Test Areas
```powershell
.\Invoke-PesterTests.ps1 -Tags @()
# Select: 17,15 (Menu, Integration)
# Test menu system thoroughly
```

### Tip 3: Save Common Selections as Aliases
```powershell
# In your PowerShell profile:
function Test-QuickValidation { .\Invoke-PesterTests.ps1 -Tags "Unit", "Fast" }
function Test-FullIntegration { .\Invoke-PesterTests.ps1 -Tags "Integration" }
```

### Tip 4: Check Tag Counts
The menu shows test counts - use this to estimate run time:
- `Fast (5 test(s))` - ~5 seconds
- `Unit (50 test(s))` - ~1 minute
- `Integration (25 test(s))` - ~3 minutes
- `Comprehensive (12 test(s))` - ~10 minutes

## Troubleshooting

### No Tags Found
If you see "No tags found in test files":
- Check that tests folder exists
- Verify test files have -Tags in Describe blocks
- Ensure you're in the correct directory

### Invalid Selection
If you enter invalid numbers:
- Numbers must be within the displayed range
- Use commas to separate multiple selections
- No spaces around numbers (e.g., "1,2,3" not "1, 2, 3")

### Selection Not Working
Common issues:
- Entering letters instead of numbers (except 'a' or 'q')
- Using dashes or ranges (e.g., "1-5" won't work, use "1,2,3,4,5")
- Typing tag names instead of numbers

## Technical Details

### How It Works
1. Scans all `*.Tests.ps1` files recursively
2. Extracts tags from `Describe ... -Tags` blocks using regex
3. Counts usage of each tag
4. Presents sorted list with counts
5. Parses user selection
6. Passes selected tags to Pester configuration

### Performance
- Tag scanning: <1 second for ~200 test files
- No impact on test execution
- One-time scan at startup

### Accuracy
- Only counts tags in `Describe` blocks
- Handles both single quotes and double quotes
- Case-sensitive matching
- Shows actual tag names as written in files

## Comparison: Before vs After

### Before
```powershell
# Had to know exact tag names
PS> .\Invoke-PesterTests.ps1 -Tags "Unit"

# Or search manually
PS> Get-ChildItem tests -Recurse -Filter "*.Tests.ps1" | Select-String "-Tags"
# Copy tag name from output
PS> .\Invoke-PesterTests.ps1 -Tags "EncryptionFunctions"
```
**Time:** ~60 seconds

### After
```powershell
# Interactive discovery and selection
PS> .\Invoke-PesterTests.ps1 -Tags @()
# See all tags, select by number
Selection: 11
# Tests run immediately
```
**Time:** ~5 seconds

## Related Features

### Fuzzy Test File Search
```powershell
.\Invoke-PesterTests.ps1 -TestFile "Config"
# Also uses interactive selection
```

### Test Type Filtering
```powershell
.\Invoke-PesterTests.ps1 -TestType Integration
# Pre-filters by folder structure
```

### Combined Usage
```powershell
# Run Integration tests, then interactively filter by tags
.\Invoke-PesterTests.ps1 -TestType Integration -Tags @()
```

## Summary

✅ **Easy tag discovery** - See all available tags  
✅ **Multiple selection** - Choose several tags at once  
✅ **Quick selection** - Use numbers instead of typing names  
✅ **Usage statistics** - See test counts per tag  
✅ **Select all option** - Run everything with one keystroke  
✅ **Backward compatible** - Old syntax still works

## Example Session

```powershell
PS C:\Autopilot> .\Invoke-PesterTests.ps1 -Tags @()

===============================================================
  Autopilot Pester Test Suite
===============================================================

Scanning test files for available tags...

===============================================================
  Available Test Tags
===============================================================

  [1] AppMode (3 test(s))
  [2] Assignment (2 test(s))
  [3] Authentication (5 test(s))
  ...
  [22] Unit (50 test(s))
  [23] User (2 test(s))

  [a] Select All
  [q] Quit

Enter tag numbers separated by commas (e.g., 1,3,5) or 'a' for all:
Selection: 22,12

Selected tags: Unit, Fast

Test Configuration:
  Test Type: All
  Test Path: C:\Autopilot\tests
  Tags: Unit, Fast

Starting Pester tests...
[Tests execute...]
```
