# Unified Testing Framework Documentation

## Overview

The Windows Autopilot Management Tool uses a comprehensive unified testing framework that provides centralized test execution, categorization, and reporting. **All testing should be performed through the unified Test Runner** to ensure consistency, proper reporting, and efficient test management.

## Single Point of Entry: Test-Runner.ps1

### Core Principle
**All testing goes through `Test-Runner.ps1` - this is the single, centralized entry point for all test execution.**

### Basic Usage
```powershell
# Run all tests (most common usage)
.\Test-Runner.ps1

# Run specific test categories
.\Test-Runner.ps1 -TestCategory unit
.\Test-Runner.ps1 -TestCategory integration
.\Test-Runner.ps1 -TestCategory comprehensive

# Run tests matching a pattern
.\Test-Runner.ps1 -TestCategory specific -TestPattern "test-menu*"

# List available tests and categories
.\Test-Runner.ps1 -ListTests
.\Test-Runner.ps1 -ListCategories

# Quick syntax validation
.\Test-Runner.ps1 -TestCategory syntax
```

## Test Categories

### Automatic Test Discovery and Categorization

The test runner automatically discovers and categorizes tests based on a centralized **Test Registry**. Tests are organized into the following categories:

| Category | Priority | Duration | Purpose |
|----------|----------|----------|---------|
| **syntax** | 1 | < 5 seconds | Quick syntax validation and function loading |
| **core** | 2 | 30-60 seconds | Essential functionality required for basic operation |
| **unit** | 3 | 2-4 minutes | Individual component and function tests |
| **integration** | 4 | 3-5 minutes | Cross-component integration and workflow tests |
| **comprehensive** | 5 | 5-8 minutes | Full workflow and end-to-end tests |
| **validation** | 6 | 2-3 minutes | Final validation and verification tests |
| **demo** | 7 | Variable | Interactive demonstration scripts |

### Special Categories

- **enhanced**: New functionality tests (PR #91 enhancements)
- **specialized**: Advanced and specialized functionality tests
- **all**: Runs all available tests across all categories
- **specific**: Pattern-based test selection

## Test Registry System

### Centralized Test Management

The **Test Registry** is the central configuration that defines:
- Which tests belong to which categories
- Test execution order and priorities
- Dependencies between test categories
- Estimated execution durations
- Test descriptions and purposes

### Adding New Tests to Categories

When creating new tests, add them to the appropriate category in the Test Registry within `Test-Runner.ps1`:

```powershell
$TestRegistry = @{
    'unit' = @{
        Description = 'Individual component and function tests'
        Pattern = 'test-settings-functions.ps1,test-json-merge.ps1,NEW-TEST-HERE.ps1'
        Priority = 3
        EstimatedDuration = '2-4 minutes'
        Dependencies = @('syntax', 'core')
    }
}
```

## Unified Test Framework Integration

### Using the Test Framework in New Tests

All new tests **MUST** use the unified test framework. Here's the standard pattern:

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Your test description
.DESCRIPTION
    Detailed test description
#>

[CmdletBinding()]
param()

# Load test helper and functions at script level to avoid scoping issues
. "$PSScriptRoot\test-helper.ps1"
$rootPath = Split-Path -Parent $PSScriptRoot

try {
    # Load functions at script level - CRITICAL for proper scoping
    $loadSuccess = Load-AllFunctions -RootPath $rootPath
    if (-not $loadSuccess) {
        throw "Failed to load functions"
    }
    
    # Initialize unified test without function loading (already done above)
    $testContext = Start-UnifiedTest -TestName "Your Test Name" -SkipFunctionCheck
    
    # Your test logic here...
    $passedTests = 0
    $failedTests = 0
    $totalTests = 0
    
    # Test execution...
    
    # Complete the test
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passedTests -FailedTests $failedTests -TotalTests $totalTests
    exit $(if ($success) { 0 } else { 1 })
}
catch {
    Write-Host "Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### Key Framework Functions

| Function | Purpose |
|----------|---------|
| `Load-AllFunctions` | Loads all application functions (call at script level) |
| `Start-UnifiedTest` | Initializes test environment and context |
| `Complete-UnifiedTest` | Handles cleanup and provides summary |
| `Write-TestResult` | Standardized test result output |
| `Write-TestSection` | Creates consistent section headers |
| `Test-FunctionExists` | Verifies function availability |
| `New-MockDevice` | Creates mock device data for testing |

## Test Execution Options

### Command Line Options

```powershell
# Basic execution
.\Test-Runner.ps1 -TestCategory <category>

# Advanced options
.\Test-Runner.ps1 -TestCategory <category> -ShowVerbose -ContinueOnError

# Information and discovery
.\Test-Runner.ps1 -ListTests
.\Test-Runner.ps1 -ListCategories  
.\Test-Runner.ps1 -DryRun -TestCategory <category>

# Pattern-based execution
.\Test-Runner.ps1 -TestCategory specific -TestPattern "test-menu*"

# Logging control
.\Test-Runner.ps1 -TestCategory <category> -LogLevel Verbose
```

### Output Formats

- **Console** (default): Human-readable output with colors and formatting
- **JSON**: Machine-readable output (future enhancement)
- **XML**: Structured output for CI/CD integration (future enhancement)

## Development Guidelines

### Creating New Tests

1. **Use the unified framework pattern** shown above
2. **Add your test to the appropriate category** in the Test Registry
3. **Follow the naming convention**: `test-<functionality>.ps1`
4. **Include proper cleanup** of temporary files and resources
5. **Use cross-platform temporary directories** (`$env:TEMP` or `/tmp`)

### Test Categories for New Tests

Choose the appropriate category based on your test's purpose:

- **unit**: Testing individual functions or components in isolation
- **integration**: Testing interactions between components
- **comprehensive**: End-to-end workflow testing
- **specialized**: Advanced or niche functionality testing

### Temporary File Management

All tests must properly manage temporary files:

```powershell
# Cross-platform temporary directory
$tempDir = if ($IsWindows -or $env:OS -eq "Windows_NT") { $env:TEMP } else { "/tmp" }
$testTempDir = Join-Path $tempDir "autopilot-test-$(Get-Random)"

try {
    # Create temp directory
    New-Item -Path $testTempDir -ItemType Directory -Force | Out-Null
    
    # Your test logic using $testTempDir
    
} finally {
    # Always cleanup
    if (Test-Path $testTempDir) {
        Remove-Item -Path $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
```

## Migration from Individual Test Scripts

### For Existing Tests

Existing tests should be gradually migrated to use the unified framework:

1. **Update function loading** to use `Load-AllFunctions` at script level
2. **Add unified test initialization** with `Start-UnifiedTest`
3. **Include proper cleanup** with `Complete-UnifiedTest`
4. **Ensure proper categorization** in the Test Registry

### Deprecated Patterns

❌ **Don't do this anymore:**
```powershell
# Running individual test scripts directly
.\TestScripts\test-specific-functionality.ps1

# Using the old run-all-tests.ps1
.\TestScripts\run-all-tests.ps1
```

✅ **Do this instead:**
```powershell
# Use the unified test runner
.\TestScripts\Test-Runner.ps1 -TestCategory unit

# For specific tests
.\TestScripts\Test-Runner.ps1 -TestCategory specific -TestPattern "test-specific*"
```

## Continuous Integration Integration

### Recommended CI/CD Test Execution

```yaml
# Example GitHub Actions workflow
- name: Run Syntax Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax
  
- name: Run Core Tests  
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory core
  
- name: Run Unit Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit
  
- name: Run Integration Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory integration
  
- name: Run Comprehensive Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory comprehensive
```

### Test Execution Timing

**Important**: Tests have specific timing requirements:

- **Syntax tests**: < 5 seconds (safe for frequent execution)
- **Core tests**: 30-60 seconds (good for CI)
- **Unit tests**: 2-4 minutes (standard CI duration)
- **Integration tests**: 3-5 minutes (requires adequate timeout)
- **Comprehensive tests**: 5-8 minutes (requires extended timeout)
- **All tests**: 15+ minutes (use appropriate CI timeout settings)

## Test Framework Benefits

### Centralized Management
- Single point of entry for all testing
- Consistent test discovery and execution
- Centralized test categorization and metadata

### Enhanced Reporting
- Comprehensive test execution summaries
- Progress tracking for long test runs
- Detailed failure analysis and debugging information

### Improved Developer Experience
- Easy test discovery with `-ListTests` and `-ListCategories`
- Pattern-based test selection for focused testing
- Dry-run capability for test planning

### Quality Assurance
- Standardized test patterns and best practices
- Proper resource cleanup and temporary file management
- Cross-platform compatibility

## Summary

The unified testing framework provides a robust, scalable, and maintainable approach to testing the Windows Autopilot Management Tool. By centralizing test execution through `Test-Runner.ps1` and following the established patterns, developers can ensure consistent, reliable, and efficient testing of all application functionality.

**Remember: Always use `Test-Runner.ps1` as your single point of entry for all testing activities.**