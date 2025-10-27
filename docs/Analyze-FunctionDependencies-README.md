# Function Dependency Analyzer with Test Coverage

## Overview

The `Analyze-FunctionDependencies.ps1` script is a powerful analysis tool that helps identify unused functions in the Autopilot project, assess test coverage, and enable memory optimization and codebase cleanup.

## Purpose

As the codebase has grown to include **186 PowerShell files** with **254 function definitions**, some functions may no longer be needed. This script performs comprehensive static code analysis to:

1. Discover all function definitions across the entire `functions/` directory
2. Build a dependency graph showing which functions call other functions
3. Trace usage starting from `main.ps1` entry points
4. **Scan Pester test files** (*.Tests.ps1) to identify functions with test coverage ✨ NEW
5. Identify functions that are defined but never called
6. Generate a detailed CSV report for review with test coverage information

## Usage

### Basic Usage

Run the script from the project root directory:

```powershell
.\tools\Analyze-FunctionDependencies.ps1
```

This will generate a report file named `FunctionDependencyReport.csv` in the current directory.

### Advanced Usage

```powershell
# Specify custom output path
.\tools\Analyze-FunctionDependencies.ps1 -OutputPath "C:\Reports\MyReport.csv"

# Use verbose logging to see detailed analysis
.\tools\Analyze-FunctionDependencies.ps1 -Verbose

# Specify custom paths
.\tools\Analyze-FunctionDependencies.ps1 -FunctionsFolder ".\functions" -MainScript ".\main.ps1" -TestsFolder ".\tests"
```

### Parameters

- **`-OutputPath`**: Path where the CSV report will be saved (default: `.\FunctionDependencyReport.csv`)
- **`-FunctionsFolder`**: Path to the functions folder (default: `.\functions`)
- **`-MainScript`**: Path to the main entry point script (default: `.\main.ps1`)
- **`-TestsFolder`**: Path to the tests folder containing Pester tests (default: `.\tests`) ✨ NEW
- **`-Verbose`**: Show detailed progress information during analysis

## Understanding the Report

The generated CSV report contains the following columns:

| Column | Description |
|--------|-------------|
| **FunctionName** | Name of the function |
| **IsUsed** | Boolean indicating if the function is used (True/False) |
| **Status** | Human-readable status: "USED" or "UNUSED" |
| **FilePath** | Relative path to the file containing the function |
| **CallCount** | Number of other functions that call this function |
| **CalledBy** | List of functions that call this function (semicolon-separated) |
| **CallsOthers** | List of functions that this function calls (semicolon-separated) |
| **FoundInTests** ✨ | "Yes" or "No" indicating if function is referenced in Pester tests |
| **TestCount** ✨ | Number of test files that reference this function |
| **TestDetails** ✨ | Details of tests (format: "TestFile \| Describe \| It") |

### Example Report Entry

```csv
"FunctionName","IsUsed","Status","FilePath","CallCount","CalledBy","CallsOthers","FoundInTests","TestCount","TestDetails"
"GetDeviceInfo","True","USED","./functions/deviceFunctions/GetDeviceInfo.ps1","15","ProcessDevice; Export-DeviceList","CallGraphAPI; Write-Log","Yes","1",".\tests\Unit\GetDeviceInfo.Tests.ps1 | Function: GetDeviceInfo | Multiple contexts"
"OldUnusedFunction","False","UNUSED","./functions/utilityFunctions/OldFunction.ps1","0","","","No","0",""
```

## Current Analysis Results

As of the latest run:

- **Total Functions Defined**: 254
- **Used Functions**: 227 (89.37%)
- **Unused Functions**: 27 (10.63%)
- **Functions with Test Coverage**: 89 (35.04%)
- **Memory Optimization Potential**: ~10.63%

### Test Coverage Breakdown

- **Used functions WITH tests**: 87 (38.3% of used functions)
- **Used functions WITHOUT tests**: 140 (61.7% need test coverage)
- **Unused functions WITH tests**: 2 (orphaned tests - review needed)
- **Unused functions WITHOUT tests**: 25 (safe removal candidates)

### Common Unused Function Categories

1. **Legacy functions** that have been replaced by newer implementations
2. **Utility functions** that were created for specific use cases but never integrated
3. **Experimental features** that didn't make it to production
4. **Deprecated authentication methods** (e.g., older token retrieval patterns)
5. **Functions with orphaned tests** that have test coverage but are no longer called

## How It Works

### 1. Function Discovery Phase

The script scans all `.ps1` files in the `functions/` directory and extracts function definitions using regex patterns:

```regex
function\s+(?:script:|global:)?([\w-]+)\s*(?:\([^\)]*\))?\s*\{
```

This captures:
- Standard functions: `function MyFunction { ... }`
- Scoped functions: `function script:MyFunction { ... }`
- Functions with parameters: `function MyFunction($param1) { ... }`

### 2. Dependency Graph Building

For each file, the script identifies function calls using multiple regex patterns:

- Direct calls: `FunctionName -Parameter`
- Variable assignments: `$result = FunctionName`
- Return statements: `return FunctionName @params`
- Pipeline calls: `| FunctionName`
- Call operators: `& FunctionName`
- Dot-sourcing: `. FunctionName`

### 3. Usage Tracing

Starting from entry points (`main.ps1`), the script recursively marks functions as "used" by:

1. Finding all functions called directly in main.ps1
2. For each called function, finding all functions it calls
3. Recursively repeating step 2 until no new functions are found
4. Any function not marked as "used" is considered unused

### 4. Test Coverage Analysis ✨ NEW

The script scans all Pester test files (`*.Tests.ps1`) in the tests folder to:

1. Extract `Describe` block names to capture test context
2. Extract `It` block names to capture specific test scenarios
3. Search for function name references as whole words (using `\b` word boundaries)
4. Associate found functions with their test file, Describe, and It contexts
5. Track functions with test coverage vs. those without

This helps identify:
- **Used functions without tests**: High-priority candidates for adding test coverage
- **Unused functions with tests**: "Orphaned" tests that may indicate refactored code
- **Functions with multiple test files**: Well-tested critical functions
- **Overall test coverage percentage**: Project health metric

### 4. Report Generation

The script generates a comprehensive CSV report showing:
- All defined functions
- Their usage status
- Call relationships
- File locations

## Limitations and Considerations

### Known Limitations

1. **Dynamic Function Calls**: The script uses static analysis and may not detect functions called dynamically:
   ```powershell
   $functionName = "MyFunction"
   & $functionName  # This call may not be detected
   ```

2. **String-Based Invocation**: Calls using `Invoke-Expression` or similar methods are not detected:
   ```powershell
   Invoke-Expression "MyFunction -Param Value"  # Not detected
   ```

3. **Conditional Loading**: Functions loaded only in specific conditions may be incorrectly marked as unused if those conditions aren't reflected in main.ps1 or test.ps1

4. **External References**: Functions called from external scripts not included in the analysis will appear as unused

### Best Practices

Before removing functions marked as "unused":

1. **Search for dynamic references**: Use `grep` or similar tools to search for string references to the function name
2. **Check documentation**: Some functions may be documented for external use
3. **Review function purpose**: Some functions may be intentionally kept for future use or backward compatibility
4. **Test thoroughly**: After removing functions, run the full test suite to ensure nothing breaks

## Querying Test Coverage Data ✨ NEW

### Find High-Priority Testing Targets

Identify frequently-used functions without test coverage:

```powershell
$report = Import-Csv .\FunctionDependencyReport.csv
$needTests = $report | 
    Where-Object { $_.IsUsed -eq 'True' -and $_.FoundInTests -eq 'No' } |
    Sort-Object {[int]$_.CallCount} -Descending |
    Select-Object -First 20
$needTests | Format-Table FunctionName, CallCount, FilePath -AutoSize
```

### Find Orphaned Tests

Identify tests for functions that are no longer being called:

```powershell
$report = Import-Csv .\FunctionDependencyReport.csv
$orphaned = $report | 
    Where-Object { $_.IsUsed -eq 'False' -and $_.FoundInTests -eq 'Yes' }
$orphaned | Format-List FunctionName, FilePath, TestDetails
```

### Find Safe Removal Candidates

Find unused functions with no test coverage (safest to remove):

```powershell
$report = Import-Csv .\FunctionDependencyReport.csv
$safeToRemove = $report | 
    Where-Object { $_.IsUsed -eq 'False' -and $_.FoundInTests -eq 'No' }
$safeToRemove | Format-Table FunctionName, FilePath -AutoSize
```

### Calculate Test Coverage Metrics

```powershell
$report = Import-Csv .\FunctionDependencyReport.csv
$totalUsed = @($report | Where-Object { $_.IsUsed -eq 'True' }).Count
$usedWithTests = @($report | Where-Object { $_.IsUsed -eq 'True' -and $_.FoundInTests -eq 'Yes' }).Count
$coveragePercent = [math]::Round(($usedWithTests / $totalUsed) * 100, 2)
Write-Host "Test coverage for used functions: $usedWithTests/$totalUsed ($coveragePercent%)"
```

## Integration with Development Workflow

### Recommended Usage

1. **Regular Analysis**: Run this script monthly or after major refactoring efforts
2. **Code Review**: Include the report in pull requests that add new functions
3. **Cleanup Sprints**: Use the report to plan technical debt reduction sprints
4. **Documentation**: Update function documentation to note deprecation before removal
5. **Test Coverage Goals**: Track test coverage percentage over time, targeting 50%+ for used functions

### Automated Checks

You can integrate this script into CI/CD pipelines:

```powershell
# Example: Fail build if unused function count exceeds threshold
.\Analyze-FunctionDependencies.ps1 -OutputPath "report.csv"
$unused = (Import-Csv "report.csv" | Where-Object { $_.Status -eq "UNUSED" }).Count
if ($unused -gt 50) {
    Write-Error "Too many unused functions: $unused. Consider cleanup."
    exit 1
}
```

## Troubleshooting

### Script Reports Functions as Unused But They're Actually Used

**Cause**: The function may be called dynamically or in a way not captured by the regex patterns.

**Solution**: 
1. Search the codebase manually for the function name
2. If confirmed used, add a comment in the function file noting the dynamic usage
3. Consider refactoring to use static calls when possible

### Script Runs Slowly

**Cause**: Large codebase with many files and complex dependencies.

**Solution**: The script is optimized for the current codebase size, but you can:
1. Run without `-Verbose` to reduce console output
2. Exclude specific directories if analyzing a subset
3. Use a faster disk (SSD vs HDD) for better performance

### Regex Patterns Don't Match New Syntax

**Cause**: PowerShell syntax evolves, and new calling patterns may emerge.

**Solution**: Update the `$patterns` array in the `Get-FunctionCalls` function to include new patterns.

## Contributing

If you discover false positives/negatives or have suggestions for improving the analysis:

1. Document the specific case with examples
2. Propose regex pattern improvements
3. Test changes against the full codebase
4. Submit a pull request with updated patterns

## Version History

- **v1.0.0** (2025-10-18): Initial release
  - Function discovery across entire functions/ directory
  - Dependency graph building
  - Recursive usage tracing from main.ps1 and test.ps1
  - CSV report generation
  - Multiple regex patterns for comprehensive call detection

## License

This script is part of the Autopilot project and follows the same MIT License as the main project.

## Support

For issues, questions, or suggestions:
- Open an issue on the GitHub repository
- Contact the project maintainers
- Review the script comments for implementation details

---

**Last Updated**: October 2025  
**Script Location**: `/Analyze-FunctionDependencies.ps1`  
**Report Output**: `FunctionDependencyReport.csv` (git-ignored)
