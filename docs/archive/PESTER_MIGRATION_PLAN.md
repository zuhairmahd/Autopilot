# Pester Migration Plan - Comprehensive Implementation Guide

**Document Version:** 1.0  
**Created:** October 10, 2025  
**Status:** Ready for Implementation  
**Estimated Total Effort:** 6-8 weeks (phased implementation)  
**Expected Impact:** Industry-standard testing, improved maintainability, better CI/CD integration

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Why Migrate to Pester](#why-migrate-to-pester)
4. [Migration Strategy](#migration-strategy)
5. [Implementation Phases](#implementation-phases)
6. [Test Prioritization](#test-prioritization)
7. [Pester Patterns & Code Samples](#pester-patterns--code-samples)
8. [AI Agent Implementation Guide](#ai-agent-implementation-guide)
9. [Validation & Quality Gates](#validation--quality-gates)
10. [Rollback Strategy](#rollback-strategy)
11. [Success Metrics](#success-metrics)
12. [Timeline & Resource Planning](#timeline--resource-planning)

---

## Executive Summary

### Problem Statement
The current custom testing framework has served well but faces limitations:
- **Custom framework maintenance burden** - unique patterns require documentation and learning curve
- **Limited tooling support** - no IDE integration, coverage reports, or CI/CD plugins
- **Inconsistent patterns** - 101 tests with varying structures and exit code handling
- **Mock limitations** - manual function override without proper isolation
- **No test discovery** - manual Test-Runner.ps1 category management

### Recommended Solution
Migrate to **Pester v5.7.1** (already installed), the de-facto PowerShell testing standard:
1. Adopt Describe/Context/It block structure for better test organization
2. Leverage Pester's mocking capabilities for proper function isolation
3. Use BeforeAll/AfterAll for setup/teardown instead of custom helpers
4. Integrate with Pester's test discovery and execution engine
5. Generate code coverage reports and integrate with CI/CD pipelines

### Migration Approach
**Phased migration with parallel operation:**
- Keep existing Test-Runner.ps1 functional during migration
- Migrate tests category-by-category based on value and complexity
- Run both frameworks in parallel until confidence achieved
- Preserve test logic while modernizing structure
- AI-agent-friendly step-by-step conversion process

### Expected Benefits
- ✅ **Industry standard tooling** - IDE support, plugins, community resources
- ✅ **Better test isolation** - Pester mocking without state pollution
- ✅ **Code coverage reports** - identify untested code paths
- ✅ **CI/CD integration** - NUnit XML output for build pipelines
- ✅ **Improved maintainability** - consistent patterns, less custom code
- ✅ **PowerShell 5.1 compatible** - Pester 5.x fully supports PS 5.1

---

## Current State Analysis

### Test Infrastructure Inventory

**Test Count by Category (101 tests total):**
```
Category          | Count | Complexity | Migration Priority
------------------|-------|------------|-------------------
syntax            |   1   | Low        | High (Foundation)
core              |   8   | Medium     | High (Critical)
unit              |  35   | Low-Medium | High (High Value)
integration       |  12   | High       | Medium (Complex)
comprehensive     |   9   | Very High  | Low (Refactor First)
validation        |   8   | Medium     | Medium
enhanced          |   6   | Medium     | Low
specialized       |   5   | High       | Low
performance       |   4   | Medium     | Low (Keep Isolated)
fixes             |   8   | Low-Medium | Medium
menu              |   3   | Medium     | Medium
autopilot         |   2   | High       | Low
migration         |   5   | Very High  | Low (Already Complex)
demo              |  13   | Low        | Exclude (Not Tests)
final-validation  |   4   | High       | Exclude (Manual)
```

**Framework Components:**
- `Test-Runner.ps1` (821 lines) - orchestrates test execution across categories
- `test-helper.ps1` (~600 lines) - unified test framework with helper functions
- `Run-MigrationTests.ps1` - proof-of-concept for test harness pattern
- Custom exit code handling and result aggregation
- Manual function loading in each test or via Test-Runner harness

### Current Test Pattern Analysis

**Pattern 1: Isolated Session Tests (Legacy - 50% of tests)**
```powershell
# test-example-old.ps1
param([string]$TestName = "Example Test")

# Load all functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$functionsPath = Join-Path -Path $rootPath -ChildPath "functions"

Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Test logic
$result = Test-SomeFunction
if ($result -eq "expected") {
    Write-Host "[PASS] Test passed" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] Test failed" -ForegroundColor Red
    exit 1
}
```

**Pattern 2: Unified Framework Tests (Modern - 40% of tests)**
```powershell
# test-example-modern.ps1
param([string]$TestName = "Example Test", [string]$TestFolder = $null)

# Load test helper
. "$PSScriptRoot\test-helper.ps1"

# Load functions
$RootPath = Split-Path -Parent $PSScriptRoot
Load-AllFunctions -RootPath $RootPath

# Initialize test environment
$TestContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder -RootPath $RootPath

Write-TestSection "Test Section 1"
$result = Test-SomeFunction
Write-TestResult "Function works correctly" -Success ($result -eq "expected")

# Cleanup and exit
Complete-UnifiedTest -TestContext $TestContext -TotalTests 1 -PassedTests $(if ($result -eq "expected") {1} else {0})
exit $(if ($result -eq "expected") {0} else {1})
```

**Pattern 3: Test Harness Tests (Newest - 10% of tests)**
```powershell
# test-example-harness.ps1
# Functions loaded by Test-Runner.ps1 test harness

# Test logic
$result = Test-SomeFunction
if ($result -eq "expected") {
    Write-Host "[PASS] Test passed" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] Test failed" -ForegroundColor Red
    exit 1
}
```

### Key Insights for Migration

**Strengths to Preserve:**
- ✅ Comprehensive test coverage across 13 categories
- ✅ Test-Runner.ps1 orchestration and category management
- ✅ Unified test helper framework with common patterns
- ✅ PowerShell 5.1 compatibility throughout

**Challenges to Address:**
- ❌ Inconsistent test structure across 101 tests
- ❌ Manual function loading code in many tests (4,000+ lines)
- ❌ Custom mocking patterns without proper cleanup
- ❌ Exit code handling varies between patterns
- ❌ State pollution between tests in harness pattern
- ❌ No code coverage measurement capability

---

## Why Migrate to Pester

### Benefits of Pester Framework

**1. Industry Standard & Ecosystem**
- Used by Microsoft for PowerShell module testing
- Rich IDE integration (VS Code Pester plugin)
- Extensive documentation and community support
- Continuous development and security updates

**2. Advanced Mocking Capabilities**
```powershell
# Current manual mock (state pollution risk)
function Get-User { return @{ Name = "Test" } }  # Overrides real function

# Pester mock (proper isolation)
Mock Get-User { return @{ Name = "Test" } } -ModuleName MyModule
# Automatically cleaned up after test
```

**3. Better Test Organization**
```powershell
# Pester hierarchical structure
Describe "User Management Functions" {
    Context "When user exists" {
        It "Should return user details" { }
        It "Should return user groups" { }
    }
    Context "When user does not exist" {
        It "Should return null" { }
        It "Should not throw error" { }
    }
}
```

**4. Built-in Test Discovery**
```powershell
# No need for TestRegistry - Pester discovers *.Tests.ps1 automatically
Invoke-Pester -Path ".\tests" -TagFilter "Unit", "Core"
```

**5. Code Coverage Reports**
```powershell
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = ".\functions\**\*.ps1"
$config.CodeCoverage.OutputFormat = "JaCoCo"  # For CI/CD
Invoke-Pester -Configuration $config
```

**6. Multiple Output Formats**
```powershell
# NUnit XML for Azure DevOps / GitHub Actions
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = "NUnitXml"
$config.TestResult.OutputPath = ".\TestResults.xml"
```

**7. PowerShell 5.1 Compatibility**
- Pester 5.x fully supports PowerShell 5.1+
- No breaking changes required for PS 5.1 compatibility
- Can use modern Pester features while maintaining compatibility

### Comparison: Current Framework vs Pester

| Feature | Current Framework | Pester |
|---------|------------------|--------|
| Test Discovery | Manual TestRegistry | Automatic (*.Tests.ps1) |
| Test Organization | Flat scripts | Describe/Context/It hierarchy |
| Mocking | Manual function override | Built-in Mock with cleanup |
| Setup/Teardown | Start-UnifiedTest/Complete-UnifiedTest | BeforeAll/AfterAll/BeforeEach/AfterEach |
| Assertions | Manual Write-TestResult | Should -Be / Should -Not -BeNullOrEmpty |
| Code Coverage | None | Built-in with multiple formats |
| CI/CD Integration | Custom exit codes | NUnit/JUnit XML output |
| IDE Support | None | VS Code extension, syntax highlighting |
| Parallel Execution | Manual with Test-Runner flag | Built-in with -ForEach |
| Documentation | Custom | Extensive official docs |
| Community | None | Large PowerShell community |

---

## Migration Strategy

### Guiding Principles

1. **Preserve Test Coverage** - No test should be lost during migration
2. **Phased Approach** - Migrate category by category, not all at once
3. **Parallel Operation** - Run both frameworks until Pester validated
4. **Value-Based Prioritization** - Migrate high-value, low-complexity tests first
5. **Iterative Refinement** - Learn from early migrations, improve patterns
6. **Backward Compatibility** - Keep Test-Runner.ps1 functional for unmigrated tests
7. **AI-Agent Friendly** - Clear, step-by-step instructions for automation

### Coexistence Strategy

**Dual Framework Operation:**
```
TestScripts/
├── test-*.ps1              # Legacy tests (101 files)
├── *.Tests.ps1             # Pester tests (new)
├── Test-Runner.ps1         # Orchestrates legacy tests
├── Invoke-PesterTests.ps1  # Orchestrates Pester tests (new)
└── test-helper.ps1         # Shared helpers for legacy tests
```

**Unified Test Execution:**
```powershell
# Run all tests (both frameworks)
.\TestScripts\Invoke-AllTests.ps1

# This script will:
# 1. Run remaining legacy tests via Test-Runner.ps1
# 2. Run Pester tests via Invoke-Pester
# 3. Combine results into unified report
```

### Migration Workflow

**For Each Category:**
1. **Analyze** - Review existing tests in category
2. **Design** - Create Pester test structure for category
3. **Convert** - Migrate tests to Pester format
4. **Validate** - Run both old and new, compare results
5. **Deploy** - Replace old tests with new Pester tests
6. **Archive** - Move old tests to `TestScripts/archived/`

---

## Implementation Phases

### Phase 0: Foundation Setup (Week 1)

**Goal:** Establish Pester infrastructure without disrupting existing tests

**Tasks:**

**0.1 Create Pester Test Directory Structure**
```powershell
# Create new directory for Pester tests
New-Item -Path ".\tests" -ItemType Directory
New-Item -Path ".\tests\Unit" -ItemType Directory
New-Item -Path ".\tests\Integration" -ItemType Directory
New-Item -Path ".\tests\Comprehensive" -ItemType Directory
New-Item -Path ".\tests\Helpers" -ItemType Directory

# Archive folder for migrated legacy tests
New-Item -Path ".\TestScripts\archived" -ItemType Directory
```

**0.2 Create Pester Configuration File**

**File:** `PesterConfiguration.ps1`
```powershell
<#
.SYNOPSIS
    Central Pester configuration for Autopilot test suite
.DESCRIPTION
    Defines standard Pester configuration used across all test executions
    Compatible with PowerShell 5.1 and Pester 5.x
#>

function Get-AutopilotPesterConfiguration {
    [CmdletBinding()]
    param(
        [ValidateSet('Unit', 'Integration', 'Comprehensive', 'All')]
        [string]$TestType = 'All',
        
        [switch]$EnableCodeCoverage,
        
        [switch]$CI
    )
    
    $config = New-PesterConfiguration
    
    # Output configuration
    $config.Output.Verbosity = 'Detailed'
    
    # Test discovery
    switch ($TestType) {
        'Unit' {
            $config.Run.Path = '.\tests\Unit'
            $config.Filter.Tag = 'Unit'
        }
        'Integration' {
            $config.Run.Path = '.\tests\Integration'
            $config.Filter.Tag = 'Integration'
        }
        'Comprehensive' {
            $config.Run.Path = '.\tests\Comprehensive'
            $config.Filter.Tag = 'Comprehensive'
        }
        'All' {
            $config.Run.Path = '.\tests'
        }
    }
    
    # Test execution
    $config.Run.Exit = $false  # Don't exit PowerShell after tests
    $config.Run.PassThru = $true  # Return test results object
    
    # Code coverage
    if ($EnableCodeCoverage) {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = '.\functions\**\*.ps1'
        $config.CodeCoverage.OutputPath = '.\coverage.xml'
        $config.CodeCoverage.OutputFormat = 'JaCoCoXml'
    }
    
    # CI/CD integration
    if ($CI) {
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = '.\TestResults.xml'
        $config.Output.Verbosity = 'Normal'
    }
    
    return $config
}

# Export for use in test scripts
Export-ModuleMember -Function Get-AutopilotPesterConfiguration
```

**0.3 Create Pester Helper Module**

**File:** `tests/Helpers/AutopilotTestHelpers.psm1`
```powershell
<#
.SYNOPSIS
    Helper functions for Autopilot Pester tests
.DESCRIPTION
    Provides common utilities for test setup, mocking, and validation
    Replaces test-helper.ps1 functionality for Pester tests
#>

function Initialize-AutopilotTestEnvironment {
    <#
    .SYNOPSIS
        Sets up test environment for Autopilot tests
    .DESCRIPTION
        Loads functions, creates temp folders, initializes mocks
    #>
    [CmdletBinding()]
    param(
        [string]$TestFolder = $null
    )
    
    # Find repository root
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Create test folder if not specified
    if (-not $TestFolder) {
        $TestFolder = Join-Path $env:TEMP "AutopilotTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    if (-not (Test-Path $TestFolder)) {
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
    }
    
    # Create subfolders
    $secretsFolder = Join-Path $TestFolder ".secrets"
    $logsFolder = Join-Path $TestFolder "Logs"
    
    New-Item -Path $secretsFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $logsFolder -ItemType Directory -Force | Out-Null
    
    # Return test context
    return @{
        RootPath = $repoRoot
        TestFolder = $TestFolder
        SecretsFolder = $secretsFolder
        LogsFolder = $logsFolder
        ConfigFile = Join-Path $secretsFolder "config.json"
        SettingsFile = Join-Path $TestFolder "settings.json"
        StringsFile = Join-Path $TestFolder "strings.json"
        LogFile = Join-Path $logsFolder "Autopilot.log"
    }
}

function Import-AutopilotFunctions {
    <#
    .SYNOPSIS
        Loads all Autopilot functions for testing
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath
    )
    
    $functionsPath = Join-Path $RootPath "functions"
    
    if (-not (Test-Path $functionsPath)) {
        throw "Functions folder not found: $functionsPath"
    }
    
    $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1
    
    foreach ($file in $functionFiles) {
        . $file.FullName
    }
    
    Write-Verbose "Loaded $($functionFiles.Count) function files"
}

function New-MockSettingsFile {
    <#
    .SYNOPSIS
        Creates a mock settings.json file for testing
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [hashtable]$CustomSettings = @{}
    )
    
    $defaultSettings = @{
        version = "1.0"
        globalSettings = @{
            maxUserMatchDisplay = 10
            maxGroupMatchDisplay = 10
            logLevel = "Info"
        }
        authSettings = @{
            authType = "ClientCredentials"
        }
    }
    
    # Merge custom settings
    foreach ($key in $CustomSettings.Keys) {
        $defaultSettings[$key] = $CustomSettings[$key]
    }
    
    $defaultSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    return $Path
}

function Remove-TestEnvironment {
    <#
    .SYNOPSIS
        Cleans up test environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestContext
    )
    
    if (Test-Path $TestContext.TestFolder) {
        Remove-Item -Path $TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-AutopilotTestEnvironment',
    'Import-AutopilotFunctions',
    'New-MockSettingsFile',
    'Remove-TestEnvironment'
)
```

**0.4 Create Pester Test Runner**

**File:** `Invoke-PesterTests.ps1`
```powershell
<#
.SYNOPSIS
    Executes Pester tests for Autopilot project
.DESCRIPTION
    Runs Pester tests with standard configuration
    Supports filtering by test type, tags, and CI/CD integration
.PARAMETER TestType
    Type of tests to run: Unit, Integration, Comprehensive, All
.PARAMETER EnableCodeCoverage
    Enable code coverage analysis
.PARAMETER CI
    Run in CI/CD mode with NUnit XML output
.PARAMETER Tags
    Filter tests by tags
.EXAMPLE
    .\Invoke-PesterTests.ps1 -TestType Unit
.EXAMPLE
    .\Invoke-PesterTests.ps1 -EnableCodeCoverage -CI
#>
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Comprehensive', 'All')]
    [string]$TestType = 'All',
    
    [switch]$EnableCodeCoverage,
    
    [switch]$CI,
    
    [string[]]$Tags = @()
)

$ErrorActionPreference = 'Stop'

# Import configuration
. "$PSScriptRoot\PesterConfiguration.ps1"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Autopilot Pester Test Suite" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Get Pester configuration
$config = Get-AutopilotPesterConfiguration -TestType $TestType -EnableCodeCoverage:$EnableCodeCoverage -CI:$CI

# Apply tag filter if specified
if ($Tags.Count -gt 0) {
    $config.Filter.Tag = $Tags
}

# Display configuration
Write-Host "`nTest Configuration:" -ForegroundColor Cyan
Write-Host "  Test Type: $TestType" -ForegroundColor White
Write-Host "  Test Path: $($config.Run.Path)" -ForegroundColor White
Write-Host "  Code Coverage: $($config.CodeCoverage.Enabled)" -ForegroundColor White
if ($Tags.Count -gt 0) {
    Write-Host "  Tags: $($Tags -join ', ')" -ForegroundColor White
}
Write-Host ""

# Run Pester
$startTime = Get-Date
Write-Host "Starting Pester tests..." -ForegroundColor Cyan

try {
    $result = Invoke-Pester -Configuration $config
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # Display results
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Test Results" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Gray
    Write-Host "  Duration: $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor White
    
    if ($config.CodeCoverage.Enabled) {
        $coverage = $result.CodeCoverage
        $coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) {
            ($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100
        } else { 0 }
        
        Write-Host "`nCode Coverage:" -ForegroundColor Cyan
        Write-Host "  Commands Analyzed: $($coverage.NumberOfCommandsAnalyzed)" -ForegroundColor White
        Write-Host "  Commands Executed: $($coverage.NumberOfCommandsExecuted)" -ForegroundColor White
        Write-Host "  Coverage: $($coveragePercent.ToString('F2'))%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
        Write-Host "  Report: $($config.CodeCoverage.OutputPath)" -ForegroundColor Gray
    }
    
    if ($config.TestResult.Enabled) {
        Write-Host "`nTest Results XML: $($config.TestResult.OutputPath)" -ForegroundColor Gray
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    # Exit with appropriate code
    exit $result.FailedCount
}
catch {
    Write-Host "`nERROR: Pester execution failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
```

**0.5 Create Sample Pester Test Template**

**File:** `tests/Template.Tests.ps1`
```powershell
<#
.SYNOPSIS
    Template for Pester tests in Autopilot project
.DESCRIPTION
    Copy this template when creating new Pester tests
    Demonstrates best practices and common patterns
#>

# Import test helpers
Import-Module "$PSScriptRoot\Helpers\AutopilotTestHelpers.psm1" -Force

# Test suite
Describe "Feature Name" -Tags 'Unit', 'FeatureArea' {
    
    # Setup - runs once before all tests in this Describe block
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Load functions
        Import-AutopilotFunctions -RootPath $TestContext.RootPath
        
        # Create test files/data
        $script:TestData = @{
            ExpectedValue = "test"
            InputData = @{ key = "value" }
        }
    }
    
    # Teardown - runs once after all tests in this Describe block
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    # Context groups related tests
    Context "When input is valid" {
        
        # BeforeEach runs before each It block in this Context
        BeforeEach {
            # Reset state for each test
            $script:TestInput = "valid input"
        }
        
        It "Should return expected result" {
            # Arrange
            $input = $script:TestInput
            
            # Act
            $result = Get-SomeFunction -Input $input
            
            # Assert
            $result | Should -Be $script:TestData.ExpectedValue
        }
        
        It "Should not throw exception" {
            # Act & Assert
            { Get-SomeFunction -Input $script:TestInput } | Should -Not -Throw
        }
        
        It "Should call dependency function" {
            # Arrange - Mock dependency
            Mock Invoke-Dependency { return "mocked" } -ModuleName TargetModule
            
            # Act
            $result = Get-SomeFunction -Input $script:TestInput
            
            # Assert - Verify mock was called
            Should -Invoke Invoke-Dependency -Exactly 1 -Scope It
        }
    }
    
    Context "When input is invalid" {
        
        It "Should return null" {
            # Act
            $result = Get-SomeFunction -Input $null
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
        
        It "Should throw exception with clear message" {
            # Act & Assert
            { Get-SomeFunction -Input "invalid" } | Should -Throw "Expected error message*"
        }
    }
    
    Context "When function is mocked" {
        
        It "Should use mock return value" {
            # Arrange
            Mock Get-SomeFunction { return "mocked result" }
            
            # Act
            $result = Get-SomeFunction -Input "any"
            
            # Assert
            $result | Should -Be "mocked result"
        }
    }
}

# Multiple Describe blocks for different components
Describe "Another Feature" -Tags 'Integration' {
    
    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath $TestContext.RootPath
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    It "Should integrate with other components" {
        # Integration test example
        $result = Invoke-IntegratedFunction
        $result.Status | Should -Be "Success"
    }
}
```

**Validation:**
```powershell
# Verify Pester is available
Get-Module -ListAvailable Pester

# Test the configuration
. .\PesterConfiguration.ps1
$config = Get-AutopilotPesterConfiguration -TestType Unit
$config

# Run template test (should skip/pass)
.\Invoke-PesterTests.ps1 -TestType Unit
```

**Commit:** "Phase 0 complete - Pester infrastructure established"

---

### Phase 1: Pilot Migration - Syntax & Simple Unit Tests (Week 2)

**Goal:** Migrate 10-15 simple tests to validate patterns and tooling

**Prioritized Tests for Pilot:**
1. `test-syntax.ps1` - Syntax validation (foundation test)
2. `test-simple-function-loading.ps1` - Function loading validation
3. `test-function-loading-validation.ps1` - Function availability checks
4. `test-get-user-strong-mapping-simple.ps1` - Simple unit test
5. `test-domain-config-simple.ps1` - Simple configuration test
6. `test-replace-logic-simple.ps1` - Simple logic test

**1.1 Convert test-syntax.ps1 to Pester**

**Current:** `TestScripts/test-syntax.ps1`
```powershell
# Comprehensive syntax check for PowerShell files using robust parser
param([string[]]$Files = @())

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "PowerShell Syntax Check"

# Get root directory
$rootPath = Split-Path -Parent $PSScriptRoot

# Check all PowerShell files
foreach ($file in $Files) {
    $content = Get-Content $file -Raw
    $parseErrors = @()
    $tokens = @()
    $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors)
    
    if ($parseErrors.Count -eq 0) {
        Write-Host "[PASS] $file" -ForegroundColor Green
        $passedFiles++
    } else {
        Write-Host "[FAIL] $file" -ForegroundColor Red
        $errorDetails += $parseErrors
    }
}

exit $(if ($errorDetails.Count -gt 0) { 1 } else { 0 })
```

**Pester Version:** `tests/Unit/Syntax.Tests.ps1`
```powershell
<#
.SYNOPSIS
    PowerShell syntax validation tests
.DESCRIPTION
    Validates that all PowerShell files in the repository have valid syntax
    Converted from TestScripts/test-syntax.ps1
#>

BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe "PowerShell Syntax Validation" -Tags 'Syntax', 'Unit', 'Fast' {
    
    Context "Main scripts" {
        
        It "main.ps1 should have valid syntax" {
            # Arrange
            $file = Join-Path $script:RepoRoot "main.ps1"
            $content = Get-Content $file -Raw
            
            # Act
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            
            # Assert
            $parseErrors | Should -BeNullOrEmpty -Because "main.ps1 must have valid PowerShell syntax"
        }
        
        It "test.ps1 should have valid syntax" {
            $file = Join-Path $script:RepoRoot "test.ps1"
            $content = Get-Content $file -Raw
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            $parseErrors | Should -BeNullOrEmpty
        }
        
        It "CreateRelease.ps1 should have valid syntax" {
            $file = Join-Path $script:RepoRoot "CreateRelease.ps1"
            $content = Get-Content $file -Raw
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            $parseErrors | Should -BeNullOrEmpty
        }
    }
    
    Context "Function files" {
        
        BeforeAll {
            # Get all function files
            $functionsPath = Join-Path $script:RepoRoot "functions"
            $script:FunctionFiles = Get-ChildItem -Path $functionsPath -Filter '*.ps1' -Recurse
        }
        
        It "Function file '<Name>' should have valid syntax" -TestCases (
            $script:FunctionFiles | ForEach-Object {
                @{ Name = $_.Name; Path = $_.FullName }
            }
        ) {
            param($Name, $Path)
            
            # Arrange
            $content = Get-Content $Path -Raw
            
            # Act
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            
            # Assert
            $parseErrors | Should -BeNullOrEmpty -Because "$Name must have valid PowerShell syntax"
        }
    }
    
    Context "Test scripts" {
        
        BeforeAll {
            $testsPath = Join-Path $script:RepoRoot "TestScripts"
            $script:TestFiles = Get-ChildItem -Path $testsPath -Filter '*.ps1' -Recurse
        }
        
        It "Test file '<Name>' should have valid syntax" -TestCases (
            $script:TestFiles | ForEach-Object {
                @{ Name = $_.Name; Path = $_.FullName }
            }
        ) {
            param($Name, $Path)
            
            $content = Get-Content $Path -Raw
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            $parseErrors | Should -BeNullOrEmpty
        }
    }
}
```

**Key Conversion Points:**
1. `Write-Host "[PASS]"` → `Should -BeNullOrEmpty`
2. `exit 0/1` → Pester handles exit codes
3. `foreach` loop → `-TestCases` for dynamic test generation
4. Manual error tracking → Pester aggregates automatically
5. `Write-TestSection` → `Context` blocks

**1.2 Convert test-simple-function-loading.ps1 to Pester**

**Current:** `TestScripts/test-simple-function-loading.ps1`
```powershell
# Simple test to verify functions can be loaded
. "$PSScriptRoot\test-helper.ps1"

$RootPath = Split-Path -Parent $PSScriptRoot
Load-AllFunctions -RootPath $RootPath

$requiredFunctions = @('Write-Log', 'Get-GraphAccessToken', 'Show-Menu')

$allAvailable = $true
foreach ($func in $requiredFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "[PASS] $func available" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $func not available" -ForegroundColor Red
        $allAvailable = $false
    }
}

exit $(if ($allAvailable) { 0 } else { 1 })
```

**Pester Version:** `tests/Unit/FunctionLoading.Tests.ps1`
```powershell
<#
.SYNOPSIS
    Function loading validation tests
.DESCRIPTION
    Verifies that critical application functions can be loaded successfully
    Converted from TestScripts/test-simple-function-loading.ps1
#>

Import-Module "$PSScriptRoot\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "Function Loading" -Tags 'Unit', 'FunctionLoading', 'Fast' {
    
    BeforeAll {
        # Get repository root and load all functions
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-AutopilotFunctions -RootPath $script:RepoRoot
        
        # Define critical functions that must be available
        $script:CriticalFunctions = @(
            'Write-Log',
            'Get-GraphAccessToken',
            'Show-Menu',
            'Initialize-AppConfig',
            'Get-EntraDirectoryObject',
            'Invoke-SettingsMigration'
        )
    }
    
    Context "Critical functions" {
        
        It "Function '<FunctionName>' should be available" -TestCases (
            $script:CriticalFunctions | ForEach-Object {
                @{ FunctionName = $_ }
            }
        ) {
            param($FunctionName)
            
            # Act
            $command = Get-Command $FunctionName -ErrorAction SilentlyContinue
            
            # Assert
            $command | Should -Not -BeNullOrEmpty -Because "$FunctionName is a critical function"
            $command.CommandType | Should -Be 'Function'
        }
    }
    
    Context "Function count" {
        
        It "Should load at least 180 functions" {
            # Act
            $functionsPath = Join-Path $script:RepoRoot "functions"
            $functionFiles = Get-ChildItem -Path $functionsPath -Filter '*.ps1' -Recurse
            
            # Assert
            $functionFiles.Count | Should -BeGreaterThan 180 -Because "Expected ~185 function files"
        }
    }
    
    Context "Function naming conventions" {
        
        BeforeAll {
            # Get all loaded functions from our module
            $script:LoadedFunctions = Get-Command -CommandType Function | 
                Where-Object { $_.Source -eq '' }  # Functions without module
        }
        
        It "Functions should follow Verb-Noun naming convention" {
            # Find functions that don't follow convention
            $invalidNames = $script:LoadedFunctions | Where-Object {
                $_.Name -notmatch '^[A-Z][a-z]+-[A-Z]'
            }
            
            # Assert - allow some exceptions for helper functions
            $invalidNames.Count | Should -BeLessThan 10 -Because "Most functions should follow Verb-Noun convention"
        }
    }
}
```

**1.3 Validation Strategy**

**Compare Output:**
```powershell
# Run old test
.\TestScripts\test-syntax.ps1
# Capture exit code: $LASTEXITCODE

# Run new Pester test
.\Invoke-PesterTests.ps1 -TestType Unit -Tags 'Syntax'
# Compare results - should match

# Run side-by-side
Write-Host "=== Running Legacy Test ===" -ForegroundColor Yellow
$legacyResult = & .\TestScripts\test-syntax.ps1
$legacyExitCode = $LASTEXITCODE

Write-Host "`n=== Running Pester Test ===" -ForegroundColor Yellow
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = '.\tests\Unit\Syntax.Tests.ps1'
$pesterConfig.Run.PassThru = $true
$pesterResult = Invoke-Pester -Configuration $pesterConfig

# Compare
Write-Host "`n=== Comparison ===" -ForegroundColor Cyan
Write-Host "Legacy Exit Code: $legacyExitCode"
Write-Host "Pester Failed Tests: $($pesterResult.FailedCount)"
Write-Host "Match: $(($legacyExitCode -eq 0 -and $pesterResult.FailedCount -eq 0) -or ($legacyExitCode -ne 0 -and $pesterResult.FailedCount -gt 0))"
```

**Success Criteria for Phase 1:**
- ✅ All pilot tests converted to Pester
- ✅ Pester tests produce same pass/fail results as legacy tests
- ✅ Test execution time equal or faster
- ✅ Patterns documented and repeatable
- ✅ Team review and approval of approach

**Commit:** "Phase 1 complete - Pilot migration successful (10 tests)"

---

### Phase 2: Unit Tests Migration (Weeks 3-4)

**Goal:** Migrate ~35 unit tests to Pester

**Category:** Unit tests - individual component and function tests

**Tests to Migrate (Priority Order):**

**High Priority (Week 3):**
1. `test-get-entra-directory-object.ps1` (25 tests) - Core functionality
2. `test-show-directory-object-list.ps1` (18 tests) - Display logic
3. `test-resolve-directory-object.ps1` (25 tests) - Resolution workflow
4. `test-update-setting-unified.ps1` - Settings management
5. `test-initialize-applicationconfiguration.ps1` - App initialization
6. `test-initialize-menu-configuration.ps1` - Menu initialization
7. `test-initialize-strings-configuration.ps1` - Strings initialization

**Medium Priority (Week 4):**
8. `test-vendor-matching.ps1` - Vendor validation
9. `test-scope-validation.ps1` - Scope checking
10. `test-password-change.ps1` - Password management
11. `test-json-merge.ps1` - Configuration merging
12. `test-array-verification.ps1` - Array handling
13. `test-compare-editor-array.ps1` - Editor array logic
14. Additional unit tests based on velocity

**Conversion Pattern for Unit Tests:**

**Example: test-get-entra-directory-object.ps1 → GetEntraDirectoryObject.Tests.ps1**

**Before (Legacy):**
```powershell
# test-get-entra-directory-object.ps1
param([string]$TestName = "Get-EntraDirectoryObject Tests")

. "$PSScriptRoot\test-helper.ps1"
$RootPath = Split-Path -Parent $PSScriptRoot
Load-AllFunctions -RootPath $RootPath
$TestContext = Start-UnifiedTest -TestName $TestName

Write-TestSection "Test 1: Exact Match - User"
Mock Get-MgUser { return @{ id = "user1"; displayName = "Test User" } }
$result = Get-EntraDirectoryObject -EntityName "test.user@domain.com" -EntityType "User"
Write-TestResult "Returns user object" -Success ($result -ne $null)

Write-TestSection "Test 2: Fuzzy Match - User"
Mock Get-MgUser { return @(@{ id = "user1"; displayName = "John Doe" }, @{ id = "user2"; displayName = "Jane Doe" }) }
$result = Get-EntraDirectoryObject -EntityName "Doe" -EntityType "User" -FindSimilar
Write-TestResult "Returns multiple matches" -Success ($result.Count -eq 2)

# ... 23 more tests

Complete-UnifiedTest -TestContext $TestContext -TotalTests 25 -PassedTests $passedCount
exit $(if ($passedCount -eq 25) { 0 } else { 1 })
```

**After (Pester):**
```powershell
# tests/Unit/GetEntraDirectoryObject.Tests.ps1
<#
.SYNOPSIS
    Tests for Get-EntraDirectoryObject function
.DESCRIPTION
    Validates user and group search with exact match and fuzzy search
    Converted from TestScripts/test-get-entra-directory-object.ps1
#>

Import-Module "$PSScriptRoot\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "Get-EntraDirectoryObject" -Tags 'Unit', 'DirectoryObject', 'Core' {
    
    BeforeAll {
        # Setup test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath $script:TestContext.RootPath
        
        # Mock access token
        $script:MockToken = "mock-access-token"
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Exact match - User entity" {
        
        It "Should return user object when exact UPN match exists" {
            # Arrange
            Mock Get-MgUser {
                return @{
                    id = "user-123"
                    userPrincipalName = "test.user@domain.com"
                    displayName = "Test User"
                }
            }
            
            # Act
            $result = Get-EntraDirectoryObject -EntityName "test.user@domain.com" -EntityType "User" -AccessToken $script:MockToken
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be "user-123"
            $result.displayName | Should -Be "Test User"
        }
        
        It "Should call Get-MgUser with correct filter" {
            # Arrange
            Mock Get-MgUser { return @{ id = "user-123" } }
            
            # Act
            Get-EntraDirectoryObject -EntityName "test@domain.com" -EntityType "User" -AccessToken $script:MockToken
            
            # Assert
            Should -Invoke Get-MgUser -Exactly 1 -Scope It -ParameterFilter {
                $Filter -like "*userPrincipalName eq 'test@domain.com'*"
            }
        }
        
        It "Should return null when user not found" {
            # Arrange
            Mock Get-MgUser { return $null }
            
            # Act
            $result = Get-EntraDirectoryObject -EntityName "nonexistent@domain.com" -EntityType "User" -AccessToken $script:MockToken
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Fuzzy search - User entity" {
        
        BeforeEach {
            # Reset cache before each fuzzy search test
            $script:DirectoryObjectCache = @{}
        }
        
        It "Should return multiple users when display name matches" {
            # Arrange
            Mock Get-MgUser {
                return @(
                    @{ id = "user-1"; displayName = "John Doe"; userPrincipalName = "john@domain.com" },
                    @{ id = "user-2"; displayName = "Jane Doe"; userPrincipalName = "jane@domain.com" }
                )
            }
            
            # Act
            $result = Get-EntraDirectoryObject -EntityName "Doe" -EntityType "User" -AccessToken $script:MockToken -FindSimilar
            
            # Assert
            $result.Count | Should -Be 2
            $result[0].displayName | Should -BeLike "*Doe"
            $result[1].displayName | Should -BeLike "*Doe"
        }
        
        It "Should search by first name when partial name provided" {
            # Arrange
            Mock Get-MgUser {
                return @( @{ id = "user-1"; givenName = "John"; surname = "Smith" } )
            }
            
            # Act
            $result = Get-EntraDirectoryObject -EntityName "John" -EntityType "User" -AccessToken $script:MockToken -FindSimilar
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-MgUser -Exactly 1 -Scope It -ParameterFilter {
                $Filter -like "*startswith(givenName,'John')*"
            }
        }
        
        It "Should return empty when fuzzy search finds no matches" {
            # Arrange
            Mock Get-MgUser { return @() }
            
            # Act
            $result = Get-EntraDirectoryObject -EntityName "NonexistentName" -EntityType "User" -AccessToken $script:MockToken -FindSimilar
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Exact match - Group entity" {
        
        It "Should return group object when exact match exists" {
            # Arrange
            Mock Get-MgGroup {
                return @{
                    id = "group-456"
                    displayName = "Test Group"
                    mail = "testgroup@domain.com"
                }
            }
            
            # Act
            $result = Get-EntraDirectoryObject -EntityName "Test Group" -EntityType "Group" -AccessToken $script:MockToken
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be "group-456"
            $result.displayName | Should -Be "Test Group"
        }
        
        It "Should call Get-MgGroup with correct filter" {
            # Arrange
            Mock Get-MgGroup { return @{ id = "group-456" } }
            
            # Act
            Get-EntraDirectoryObject -EntityName "Test Group" -EntityType "Group" -AccessToken $script:MockToken
            
            # Assert
            Should -Invoke Get-MgGroup -Exactly 1 -Scope It -ParameterFilter {
                $Filter -like "*displayName eq 'Test Group'*"
            }
        }
    }
    
    Context "Caching behavior" {
        
        BeforeEach {
            $script:DirectoryObjectCache = @{}
        }
        
        It "Should cache user results" {
            # Arrange
            Mock Get-MgUser { return @{ id = "user-123"; displayName = "Cached User" } }
            
            # Act - First call
            $result1 = Get-EntraDirectoryObject -EntityName "cached@domain.com" -EntityType "User" -AccessToken $script:MockToken
            # Act - Second call
            $result2 = Get-EntraDirectoryObject -EntityName "cached@domain.com" -EntityType "User" -AccessToken $script:MockToken
            
            # Assert - Mock should be called only once (cached on second call)
            Should -Invoke Get-MgUser -Exactly 1 -Scope It
            $result1.id | Should -Be $result2.id
        }
        
        It "Should cache group results" {
            # Arrange
            Mock Get-MgGroup { return @{ id = "group-789"; displayName = "Cached Group" } }
            
            # Act
            $result1 = Get-EntraDirectoryObject -EntityName "Cached Group" -EntityType "Group" -AccessToken $script:MockToken
            $result2 = Get-EntraDirectoryObject -EntityName "Cached Group" -EntityType "Group" -AccessToken $script:MockToken
            
            # Assert
            Should -Invoke Get-MgGroup -Exactly 1 -Scope It
        }
        
        It "Should use separate cache keys for users and groups" {
            # Arrange
            Mock Get-MgUser { return @{ id = "user-same"; displayName = "Same Name" } }
            Mock Get-MgGroup { return @{ id = "group-same"; displayName = "Same Name" } }
            
            # Act
            $userResult = Get-EntraDirectoryObject -EntityName "Same Name" -EntityType "User" -AccessToken $script:MockToken
            $groupResult = Get-EntraDirectoryObject -EntityName "Same Name" -EntityType "Group" -AccessToken $script:MockToken
            
            # Assert - Both should be called (different cache keys)
            Should -Invoke Get-MgUser -Exactly 1 -Scope It
            Should -Invoke Get-MgGroup -Exactly 1 -Scope It
            $userResult.id | Should -Be "user-same"
            $groupResult.id | Should -Be "group-same"
        }
    }
    
    Context "Error handling" {
        
        It "Should handle Graph API errors gracefully" {
            # Arrange
            Mock Get-MgUser { throw "Graph API Error: Unauthorized" }
            
            # Act & Assert
            { Get-EntraDirectoryObject -EntityName "test@domain.com" -EntityType "User" -AccessToken $script:MockToken } | 
                Should -Throw "*Graph API Error*"
        }
        
        It "Should validate EntityType parameter" {
            # Act & Assert
            { Get-EntraDirectoryObject -EntityName "test" -EntityType "InvalidType" -AccessToken $script:MockToken } | 
                Should -Throw
        }
        
        It "Should require AccessToken parameter" {
            # Act & Assert
            { Get-EntraDirectoryObject -EntityName "test" -EntityType "User" } | 
                Should -Throw
        }
    }
}
```

**Key Improvements in Pester Version:**
1. **Better Organization:** Describe/Context/It hierarchy
2. **Proper Mocking:** Pester Mock with automatic cleanup
3. **Assertion Clarity:** `Should -Be` instead of manual comparisons
4. **Test Isolation:** BeforeEach resets state per test
5. **Mock Verification:** `Should -Invoke` validates mock calls
6. **Parameter Testing:** `-ParameterFilter` validates mock parameters
7. **No Manual Exit Codes:** Pester handles pass/fail

**2.1 Conversion Automation Script**

**File:** `tools/Convert-LegacyTestToPester.ps1`
```powershell
<#
.SYNOPSIS
    Converts legacy test files to Pester format
.DESCRIPTION
    Automates common conversion patterns from legacy test-*.ps1 to Pester *.Tests.ps1
    Requires manual review and adjustment after conversion
.PARAMETER TestPath
    Path to legacy test file to convert
.PARAMETER OutputPath
    Path where Pester test should be created (default: tests/Unit/)
.PARAMETER WhatIf
    Show what would be converted without creating file
.EXAMPLE
    .\Convert-LegacyTestToPester.ps1 -TestPath .\TestScripts\test-example.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$TestPath,
    
    [string]$OutputPath = $null,
    
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Validate input
if (-not (Test-Path $TestPath)) {
    throw "Test file not found: $TestPath"
}

$testFile = Get-Item $TestPath
$testContent = Get-Content $TestPath -Raw

# Determine output path
if (-not $OutputPath) {
    $testName = $testFile.BaseName -replace '^test-', ''
    $pascalName = (Get-Culture).TextInfo.ToTitleCase($testName) -replace '-', ''
    $OutputPath = Join-Path ".\tests\Unit" "$pascalName.Tests.ps1"
}

Write-Host "Converting: $($testFile.Name)" -ForegroundColor Cyan
Write-Host "To: $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Analysis
$hasTestHelper = $testContent -match '\.\s+"?\$PSScriptRoot\\test-helper\.ps1"?'
$hasLoadAllFunctions = $testContent -match 'Load-AllFunctions'
$hasStartUnifiedTest = $testContent -match 'Start-UnifiedTest'
$hasWriteTestSection = $testContent -match 'Write-TestSection'
$hasWriteTestResult = $testContent -match 'Write-TestResult'
$hasExitCode = $testContent -match 'exit\s+'

Write-Host "Analysis:" -ForegroundColor Yellow
Write-Host "  Uses test-helper: $hasTestHelper"
Write-Host "  Uses Load-AllFunctions: $hasLoadAllFunctions"
Write-Host "  Uses unified framework: $hasStartUnifiedTest"
Write-Host "  Uses test sections: $hasWriteTestSection"
Write-Host "  Uses test results: $hasWriteTestResult"
Write-Host "  Has exit codes: $hasExitCode"
Write-Host ""

# Build Pester template
$pesterContent = @"
<#
.SYNOPSIS
    Pester tests for $testName
.DESCRIPTION
    Converted from $($testFile.Name)
    ** MANUAL REVIEW REQUIRED **
#>

Import-Module "`$PSScriptRoot\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "$testName" -Tags 'Unit' {
    
    BeforeAll {
        # Setup test environment
        `$script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath `$script:TestContext.RootPath
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext `$script:TestContext
    }
    
    Context "TODO: Add context description" {
        
        It "TODO: Convert test logic to Pester assertions" {
            # TODO: Convert from legacy test code below
            
            # Assert
            # Replace Write-TestResult with Should assertions
            # Replace exit codes with Should assertions
        }
    }
}

<# 
═══════════════════════════════════════════════════════════════
ORIGINAL LEGACY TEST CODE (for reference during manual conversion)
═══════════════════════════════════════════════════════════════

$testContent

═══════════════════════════════════════════════════════════════
END ORIGINAL CODE
═══════════════════════════════════════════════════════════════
#>
"@

if ($WhatIf) {
    Write-Host "Would create:" -ForegroundColor Yellow
    Write-Host $pesterContent
} else {
    # Create output directory if needed
    $outputDir = Split-Path $OutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    # Write Pester file
    Set-Content -Path $OutputPath -Value $pesterContent
    
    Write-Host "Created: $OutputPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Review generated file and convert TODO sections"
    Write-Host "2. Convert Write-TestSection to Context blocks"
    Write-Host "3. Convert Write-TestResult to Should assertions"
    Write-Host "4. Remove exit codes (Pester handles)"
    Write-Host "5. Add proper mocking with Mock keyword"
    Write-Host "6. Run: .\Invoke-PesterTests.ps1 -TestType Unit"
    Write-Host "7. Compare results with legacy test"
}
```

**Usage:**
```powershell
# Convert a test (generates template)
.\tools\Convert-LegacyTestToPester.ps1 -TestPath .\TestScripts\test-example.ps1

# Review output file, complete TODO sections

# Test the conversion
.\Invoke-PesterTests.ps1 -TestType Unit -Tags 'Example'
```

**Success Criteria for Phase 2:**
- ✅ 35 unit tests migrated to Pester
- ✅ Code coverage reports working
- ✅ All Pester tests pass
- ✅ Execution time matches or beats legacy tests
- ✅ Patterns documented for remaining tests

**Commit:** "Phase 2 complete - Unit tests migrated to Pester (35 tests)"

---

### Phase 3: Integration Tests Migration (Weeks 5-6)

**Goal:** Migrate ~12 integration tests with cross-component dependencies

**Category:** Integration tests - multi-component workflows

**Tests to Migrate:**
1. `test-menu-system-comprehensive.ps1` - Menu system integration
2. `test-autopilot-menu-integration.ps1` - Autopilot menu workflow
3. `test-auth-flows-comprehensive.ps1` - Authentication flows
4. `test-settings-integration.ps1` - Settings system integration
5. `test-menu-inclusions-integration.ps1` - Menu inclusion logic
6. `test-settings-viewer-menu-integration.ps1` - Settings viewer integration
7. Additional integration tests

**Integration Test Pattern:**

**Key Differences from Unit Tests:**
- Tests multiple components working together
- May require more setup/teardown
- Longer execution time acceptable
- More complex mocking scenarios

**Example Conversion:**

**Legacy Integration Test:**
```powershell
# test-menu-system-comprehensive.ps1
. "$PSScriptRoot\test-helper.ps1"
Load-AllFunctions
$TestContext = Start-UnifiedTest

# Test 1: Menu loading
$settings = Get-Content "settings.json" | ConvertFrom-Json
$menu = Initialize-MenuConfiguration -Settings $settings
Write-TestResult "Menu loaded" -Success ($menu -ne $null)

# Test 2: Menu item filtering
$filtered = $menu.menuItems | Where-Object { $_.visible }
Write-TestResult "Filtering works" -Success ($filtered.Count -gt 0)

# Test 3: Menu navigation
Mock Read-Host { return "1" }
$result = Show-Menu -Menu $menu
Write-TestResult "Navigation works" -Success ($result -ne $null)

Complete-UnifiedTest
```

**Pester Integration Test:**
```powershell
# tests/Integration/MenuSystem.Tests.ps1
Import-Module "$PSScriptRoot\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "Menu System Integration" -Tags 'Integration', 'Menu' {
    
    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath $script:TestContext.RootPath
        
        # Create test settings file
        $testSettings = @{
            version = "1.0"
            menuConfig = @{
                showHidden = $false
            }
        }
        $settingsPath = Join-Path $script:TestContext.TestFolder "settings.json"
        $testSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
        
        $script:Settings = Get-Content $settingsPath | ConvertFrom-Json
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Menu initialization" {
        
        It "Should load menu configuration from settings" {
            # Act
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            
            # Assert
            $menu | Should -Not -BeNullOrEmpty
            $menu.menuItems | Should -Not -BeNullOrEmpty
            $menu.menuItems.Count | Should -BeGreaterThan 0
        }
        
        It "Should contain standard menu items" {
            # Act
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            
            # Assert
            $menu.menuItems.title | Should -Contain "Device Management"
            $menu.menuItems.title | Should -Contain "User Management"
            $menu.menuItems.title | Should -Contain "Settings"
        }
    }
    
    Context "Menu filtering" {
        
        It "Should filter hidden menu items" {
            # Arrange
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            
            # Act
            $visibleItems = $menu.menuItems | Where-Object { $_.visible -eq $true }
            $hiddenItems = $menu.menuItems | Where-Object { $_.visible -eq $false }
            
            # Assert
            $visibleItems | Should -Not -BeNullOrEmpty
            $hiddenItems | Should -BeNullOrEmpty -Because "showHidden is false in settings"
        }
        
        It "Should filter by app mode" {
            # Arrange
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            
            # Act
            $appModeItems = $menu.menuItems | Where-Object { $_.appMode -contains "Standard" }
            
            # Assert
            $appModeItems.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Menu navigation" {
        
        It "Should return selected menu item when valid choice entered" {
            # Arrange
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            Mock Read-Host { return "1" }
            
            # Act
            $result = Show-Menu -Menu $menu -Title "Test Menu"
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.title | Should -Be $menu.menuItems[0].title
        }
        
        It "Should handle invalid choice gracefully" {
            # Arrange
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            Mock Read-Host { return "999" }
            
            # Act
            $result = Show-Menu -Menu $menu -Title "Test Menu"
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
        
        It "Should support mnemonic navigation" {
            # Arrange
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            $firstItem = $menu.menuItems[0]
            Mock Read-Host { return $firstItem.mnemonic }
            
            # Act
            $result = Show-Menu -Menu $menu -Title "Test Menu"
            
            # Assert
            $result.mnemonic | Should -Be $firstItem.mnemonic
        }
    }
    
    Context "End-to-end menu workflow" {
        
        It "Should complete full menu interaction cycle" {
            # Arrange
            $menu = Initialize-MenuConfiguration -Settings $script:Settings
            $mockSequence = @("1", "2", "0")  # Select item 1, then 2, then exit
            $mockIndex = 0
            Mock Read-Host { 
                $choice = $mockSequence[$script:mockIndex]
                $script:mockIndex++
                return $choice
            }
            
            # Act
            $result1 = Show-Menu -Menu $menu
            $result2 = Show-Menu -Menu $menu
            $result3 = Show-Menu -Menu $menu
            
            # Assert
            $result1 | Should -Not -BeNullOrEmpty
            $result2 | Should -Not -BeNullOrEmpty
            $result3.title | Should -Be "Exit"
        }
    }
}
```

**Success Criteria for Phase 3:**
- ✅ 12 integration tests migrated
- ✅ Cross-component interactions validated
- ✅ Complex mocking scenarios working
- ✅ Test execution remains stable

**Commit:** "Phase 3 complete - Integration tests migrated (12 tests)"

---

### Phase 4: Selective Migration of Complex Tests (Weeks 7-8)

**Goal:** Migrate selected comprehensive, validation, and specialized tests

**Strategy:** Not all tests need migration - focus on high-value tests

**Tests to Migrate (Selective):**
1. **High Value Comprehensive Tests:**
   - `test-auth-configuration-pipeline.ps1` - End-to-end auth setup
   - `test-device-lookup-comprehensive.ps1` - Device search workflows
   
2. **Critical Validation Tests:**
   - `test-core-validation.ps1` - Core functionality checks
   - `test-scope-hierarchy.ps1` - Permission scoping
   - `test-backward-compatibility.ps1` - Version compatibility

3. **Selected Specialized Tests:**
   - `test-batch-optimization.ps1` - Performance optimizations
   - `test-graph-encryption-functions.ps1` - Security functions

**Tests to KEEP in Legacy Framework:**
- Performance tests (`test-performance-*.ps1`) - Require isolated timing
- Migration tests (`test-migration-*.ps1`) - Already complex, low ROI
- Demo scripts (`demo-*.ps1`) - Not tests, manual validation
- Final validation scripts (`final-validation-*.ps1`) - Manual workflows

**Complex Test Pattern:**

**Handling Long-Running Tests:**
```powershell
# tests/Comprehensive/DeviceLookup.Tests.ps1
Describe "Device Lookup Comprehensive" -Tags 'Comprehensive', 'Device', 'Slow' {
    
    BeforeAll {
        # Extended timeout for comprehensive tests
        $script:TestTimeout = 300  # 5 minutes
        
        # Setup with real-like data
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath $script:TestContext.RootPath
        
        # Create mock device data
        $script:MockDevices = @(
            @{ id = "device-1"; displayName = "LAPTOP-001"; serialNumber = "SN001" },
            @{ id = "device-2"; displayName = "LAPTOP-002"; serialNumber = "SN002" },
            @{ id = "device-3"; displayName = "DESKTOP-001"; serialNumber = "SN003" }
        )
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Device search scenarios" {
        
        It "Should find device by serial number" -Skip:$($env:SKIP_SLOW_TESTS -eq 'true') {
            # Arrange
            Mock Get-MgDevice { return $script:MockDevices | Where-Object { $_.serialNumber -eq $SerialNumber } }
            
            # Act
            $result = Find-AutopilotDevice -SerialNumber "SN001"
            
            # Assert
            $result.serialNumber | Should -Be "SN001"
        }
        
        # More comprehensive tests...
    }
}
```

**Success Criteria for Phase 4:**
- ✅ High-value complex tests migrated
- ✅ Low-value tests documented as "keep legacy"
- ✅ Performance tests remain in legacy framework
- ✅ Clear criteria for what stays in legacy

**Commit:** "Phase 4 complete - Selective complex test migration"

---

### Phase 5: Cleanup & Optimization (Week 9)

**Goal:** Finalize migration, optimize suite, retire legacy tests

**Tasks:**

**5.1 Validate Complete Migration**
```powershell
# Create validation report
$legacyTests = Get-ChildItem ".\TestScripts\test-*.ps1"
$pesterTests = Get-ChildItem ".\tests\**\*.Tests.ps1" -Recurse
$archivedTests = Get-ChildItem ".\TestScripts\archived\test-*.ps1"

Write-Host "Migration Status Report"
Write-Host "Legacy Tests: $($legacyTests.Count)"
Write-Host "Pester Tests: $($pesterTests.Count)"
Write-Host "Archived Tests: $($archivedTests.Count)"
Write-Host "Kept in Legacy: $($legacyTests.Count - $archivedTests.Count)"
```

**5.2 Create Unified Test Runner**

**File:** `Invoke-AllTests.ps1`
```powershell
<#
.SYNOPSIS
    Runs all tests - both Pester and legacy
.DESCRIPTION
    Executes full test suite including Pester tests and remaining legacy tests
    Generates combined report
#>
[CmdletBinding()]
param(
    [switch]$Quick,  # Run only fast tests
    [switch]$CI      # CI/CD mode
)

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Autopilot Complete Test Suite" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$startTime = Get-Date
$allPassed = $true

# Run Pester tests
Write-Host "`n=== Running Pester Tests ===" -ForegroundColor Yellow
if ($Quick) {
    $pesterResult = .\Invoke-PesterTests.ps1 -TestType Unit -CI:$CI
} else {
    $pesterResult = .\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage -CI:$CI
}
$pesterExitCode = $LASTEXITCODE
if ($pesterExitCode -ne 0) { $allPassed = $false }

# Run remaining legacy tests (performance, migration, demos)
Write-Host "`n=== Running Legacy Tests ===" -ForegroundColor Yellow
$legacyCategories = @('performance')  # Only categories not migrated

foreach ($category in $legacyCategories) {
    Write-Host "Running $category tests..." -ForegroundColor Cyan
    $legacyResult = .\TestScripts\Test-Runner.ps1 -TestCategory $category
    $legacyExitCode = $LASTEXITCODE
    if ($legacyExitCode -ne 0) { $allPassed = $false }
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Combined report
Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Complete Suite Results" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Pester Tests: $(if ($pesterExitCode -eq 0) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($pesterExitCode -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Legacy Tests: $(if ($legacyExitCode -eq 0) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($legacyExitCode -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Total Duration: $($duration.TotalMinutes.ToString('F1')) minutes" -ForegroundColor White
Write-Host "  Overall Status: $(if ($allPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($allPassed) { 'Green' } else { 'Red' })
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

exit $(if ($allPassed) { 0 } else { 1 })
```

**5.3 Archive Migrated Legacy Tests**
```powershell
# Move migrated tests to archive
$migratedTests = @(
    "test-syntax.ps1",
    "test-simple-function-loading.ps1",
    "test-get-entra-directory-object.ps1"
    # ... all migrated tests
)

foreach ($test in $migratedTests) {
    $source = Join-Path ".\TestScripts" $test
    $dest = Join-Path ".\TestScripts\archived" $test
    
    if (Test-Path $source) {
        Move-Item $source $dest
        Write-Host "Archived: $test" -ForegroundColor Gray
    }
}
```

**5.4 Update Documentation**

Update `AGENTS.md`:
```markdown
## Testing Guidelines
The project uses Pester v5 as the primary testing framework. Legacy tests remain for performance benchmarking and complex migration scenarios.

**Running Tests:**
- Quick validation: `.\Invoke-PesterTests.ps1 -TestType Unit`
- Full Pester suite: `.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage`
- Complete suite (Pester + Legacy): `.\Invoke-AllTests.ps1`
- Legacy performance tests: `.\TestScripts\Test-Runner.ps1 -TestCategory performance`

**Writing New Tests:**
- Use Pester format (Describe/Context/It)
- Follow template: `tests/Template.Tests.ps1`
- Tag appropriately: Unit, Integration, Comprehensive
- Use helper module: `tests/Helpers/AutopilotTestHelpers.psm1`
```

**5.5 CI/CD Integration**

**File:** `.github/workflows/test.yml` (GitHub Actions example)
```yaml
name: Test Suite

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    runs-on: windows-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install Pester
      shell: pwsh
      run: |
        Install-Module -Name Pester -MinimumVersion 5.7.1 -Force -SkipPublisherCheck
    
    - name: Run Tests
      shell: pwsh
      run: |
        .\Invoke-AllTests.ps1 -Quick -CI
    
    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: |
          TestResults.xml
          coverage.xml
    
    - name: Publish Test Results
      if: always()
      uses: EnricoMi/publish-unit-test-result-action/composite@v2
      with:
        files: TestResults.xml
    
    - name: Code Coverage Report
      if: always()
      uses: codecov/codecov-action@v3
      with:
        files: coverage.xml
        flags: unittests
```

**Success Criteria for Phase 5:**
- ✅ All migrated tests archived
- ✅ Unified test runner working
- ✅ Documentation updated
- ✅ CI/CD pipeline integrated
- ✅ Code coverage reporting functional

**Commit:** "Phase 5 complete - Migration finalized, CI/CD integrated"

---

## Test Prioritization

### Prioritization Matrix

Tests are prioritized based on **Value** and **Complexity**:

```
High Value + Low Complexity  = MIGRATE FIRST (Phase 1-2)
High Value + High Complexity = MIGRATE CAREFULLY (Phase 3-4)
Low Value + Low Complexity   = MIGRATE IF TIME (Phase 4)
Low Value + High Complexity  = KEEP LEGACY (Excluded)
```

### Detailed Priority Rankings

| Test | Value | Complexity | Priority | Phase |
|------|-------|------------|----------|-------|
| test-syntax.ps1 | High | Low | 1 | Phase 1 |
| test-simple-function-loading.ps1 | High | Low | 1 | Phase 1 |
| test-function-loading-validation.ps1 | High | Low | 1 | Phase 1 |
| test-get-entra-directory-object.ps1 | High | Medium | 2 | Phase 2 |
| test-show-directory-object-list.ps1 | High | Medium | 2 | Phase 2 |
| test-resolve-directory-object.ps1 | High | Medium | 2 | Phase 2 |
| test-update-setting-unified.ps1 | High | Medium | 2 | Phase 2 |
| test-initialize-*.ps1 (3 files) | High | Medium | 2 | Phase 2 |
| test-menu-system-comprehensive.ps1 | High | High | 3 | Phase 3 |
| test-auth-flows-comprehensive.ps1 | High | High | 3 | Phase 3 |
| test-settings-integration.ps1 | High | High | 3 | Phase 3 |
| test-core-validation.ps1 | High | High | 4 | Phase 4 |
| test-device-lookup-comprehensive.ps1 | Medium | High | 4 | Phase 4 |
| test-performance-*.ps1 (4 files) | Medium | High | 5 | Keep Legacy |
| test-migration-*.ps1 (5 files) | Low | Very High | 6 | Keep Legacy |
| demo-*.ps1 (13 files) | Low | Low | 6 | Exclude |

### Value Assessment Criteria

**High Value Tests:**
- Core functionality (authentication, directory operations)
- Frequently modified code areas
- Critical business logic
- Foundation for other features

**Medium Value Tests:**
- Secondary features
- Less frequently modified
- Nice-to-have validations

**Low Value Tests:**
- One-time migrations already complete
- Demo/manual validation scripts
- Rarely executed scenarios

### Complexity Assessment Criteria

**Low Complexity:**
- Syntax/structure validation
- Simple function calls
- Minimal setup/teardown
- No external dependencies

**Medium Complexity:**
- Multiple function interactions
- Moderate mocking required
- Some state management

**High Complexity:**
- End-to-end workflows
- Heavy mocking requirements
- File system operations
- Complex state management

**Very High Complexity:**
- Already using custom framework
- Migration-specific logic
- Interdependent test sequences

---

## Pester Patterns & Code Samples

### Essential Pester Patterns

#### Pattern 1: Basic Unit Test
```powershell
Describe "Function-Name" -Tags 'Unit' {
    It "Should return expected value" {
        # Arrange
        $input = "test"
        
        # Act
        $result = Get-Function -Input $input
        
        # Assert
        $result | Should -Be "expected"
    }
}
```

#### Pattern 2: Test with Setup/Teardown
```powershell
Describe "Function-Name" -Tags 'Unit' {
    BeforeAll {
        # Runs once before all tests
        $script:TestData = Initialize-TestData
    }
    
    BeforeEach {
        # Runs before each test
        $script:State = @{}
    }
    
    AfterEach {
        # Runs after each test
        Clear-State
    }
    
    AfterAll {
        # Runs once after all tests
        Remove-TestData
    }
    
    It "Test 1" { }
    It "Test 2" { }
}
```

#### Pattern 3: Mocking Functions
```powershell
Describe "Function with Dependencies" -Tags 'Unit' {
    It "Should call dependency function" {
        # Arrange
        Mock Get-Dependency { return "mocked" }
        
        # Act
        $result = Invoke-Function
        
        # Assert
        Should -Invoke Get-Dependency -Exactly 1
        $result | Should -Contain "mocked"
    }
}
```

#### Pattern 4: Parameterized Tests
```powershell
Describe "Validation Function" -Tags 'Unit' {
    It "Should validate '<Input>' as '<Expected>'" -TestCases @(
        @{ Input = "valid@email.com"; Expected = $true }
        @{ Input = "invalid-email"; Expected = $false }
        @{ Input = ""; Expected = $false }
        @{ Input = $null; Expected = $false }
    ) {
        param($Input, $Expected)
        
        # Act
        $result = Test-Email -Email $Input
        
        # Assert
        $result | Should -Be $Expected
    }
}
```

#### Pattern 5: Testing Exceptions
```powershell
Describe "Error Handling" -Tags 'Unit' {
    It "Should throw when input is null" {
        { Invoke-Function -Input $null } | Should -Throw
    }
    
    It "Should throw with specific message" {
        { Invoke-Function -Input "bad" } | Should -Throw "*Invalid input*"
    }
    
    It "Should not throw when input is valid" {
        { Invoke-Function -Input "good" } | Should -Not -Throw
    }
}
```

#### Pattern 6: Testing File Operations
```powershell
Describe "File Operations" -Tags 'Integration' {
    BeforeAll {
        $script:TestFolder = Join-Path $env:TEMP "PesterTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $script:TestFolder -ItemType Directory -Force | Out-Null
    }
    
    AfterAll {
        Remove-Item -Path $script:TestFolder -Recurse -Force
    }
    
    It "Should create file" {
        # Arrange
        $filePath = Join-Path $script:TestFolder "test.txt"
        
        # Act
        New-TestFile -Path $filePath
        
        # Assert
        Test-Path $filePath | Should -Be $true
    }
}
```

#### Pattern 7: Mocking Microsoft Graph Calls
```powershell
Describe "Graph API Integration" -Tags 'Integration' {
    BeforeAll {
        Import-AutopilotFunctions -RootPath $script:RepoRoot
    }
    
    It "Should retrieve user from Graph API" {
        # Arrange
        Mock Get-MgUser {
            return @{
                id = "user-123"
                displayName = "Test User"
                userPrincipalName = "test@domain.com"
            }
        }
        
        # Act
        $user = Get-AutopilotUser -UserPrincipalName "test@domain.com" -AccessToken "mock-token"
        
        # Assert
        $user | Should -Not -BeNullOrEmpty
        $user.id | Should -Be "user-123"
        Should -Invoke Get-MgUser -Exactly 1 -ParameterFilter {
            $UserId -eq "test@domain.com"
        }
    }
}
```

#### Pattern 8: Testing Async/Long-Running Operations
```powershell
Describe "Long Running Operations" -Tags 'Integration', 'Slow' {
    It "Should complete within timeout" -Skip:$($env:SKIP_SLOW_TESTS -eq 'true') {
        # Arrange
        $timeout = 30  # seconds
        
        # Act
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-LongRunningOperation
        $stopwatch.Stop()
        
        # Assert
        $result | Should -Not -BeNullOrEmpty
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan $timeout
    }
}
```

### Common Assertions

```powershell
# Equality
$result | Should -Be "expected"
$result | Should -Not -Be "unexpected"

# Null/Empty
$result | Should -BeNullOrEmpty
$result | Should -Not -BeNullOrEmpty

# Type
$result | Should -BeOfType [string]
$result | Should -BeOfType [System.Collections.Hashtable]

# Boolean
$result | Should -BeTrue
$result | Should -BeFalse

# Collections
$result | Should -Contain "item"
$result | Should -Not -Contain "missing"
$result.Count | Should -Be 5

# Numeric
$result | Should -BeGreaterThan 10
$result | Should -BeLessThan 100
$result | Should -BeGreaterOrEqual 10
$result | Should -BeLessOrEqual 100

# String matching
$result | Should -Match "pattern"
$result | Should -Like "*wildcard*"
$result | Should -BeLike "*wildcard*"

# File/Path
"C:\path\file.txt" | Should -Exist
"C:\path\file.txt" | Should -FileContentMatch "expected content"

# Exceptions
{ Invoke-Function } | Should -Throw
{ Invoke-Function } | Should -Throw "*specific message*"
{ Invoke-Function } | Should -Not -Throw

# Mock verification
Should -Invoke Get-Function -Exactly 1
Should -Invoke Get-Function -Times 3
Should -Invoke Get-Function -AtLeast 1
Should -Invoke Get-Function -ParameterFilter { $Param -eq "value" }
```

---

## AI Agent Implementation Guide

### Overview for AI Coding Agents

This section provides step-by-step instructions optimized for AI agents to implement the Pester migration. Each step is atomic, verifiable, and includes clear success criteria.

### Pre-Migration Checklist

Before starting migration, verify:
- [ ] PowerShell 5.1 or later installed
- [ ] Pester 5.7.1 or later installed (`Get-Module -ListAvailable Pester`)
- [ ] All existing tests passing (`.\TestScripts\Test-Runner.ps1 -TestCategory all`)
- [ ] Git repository clean with no uncommitted changes
- [ ] Branch created for migration work

### AI Agent Implementation Steps

#### Step 1: Setup Infrastructure (Phase 0)

**Task 1.1: Create Directory Structure**
```powershell
# Command to execute
New-Item -Path ".\tests" -ItemType Directory -Force
New-Item -Path ".\tests\Unit" -ItemType Directory -Force
New-Item -Path ".\tests\Integration" -ItemType Directory -Force
New-Item -Path ".\tests\Comprehensive" -ItemType Directory -Force
New-Item -Path ".\tests\Helpers" -ItemType Directory -Force
New-Item -Path ".\TestScripts\archived" -ItemType Directory -Force

# Verification
Test-Path ".\tests\Unit"  # Should return $true
Test-Path ".\tests\Helpers"  # Should return $true
```

**Task 1.2: Create PesterConfiguration.ps1**
```powershell
# Action: Create file .\PesterConfiguration.ps1
# Content: Copy from Phase 0 section above
# Verification:
. .\PesterConfiguration.ps1
$config = Get-AutopilotPesterConfiguration -TestType Unit
$config.Run.Path  # Should return '.\tests\Unit'
```

**Task 1.3: Create Test Helper Module**
```powershell
# Action: Create file .\tests\Helpers\AutopilotTestHelpers.psm1
# Content: Copy from Phase 0 section above
# Verification:
Import-Module ".\tests\Helpers\AutopilotTestHelpers.psm1" -Force
Get-Command Initialize-AutopilotTestEnvironment  # Should return function
```

**Task 1.4: Create Pester Test Runner**
```powershell
# Action: Create file .\Invoke-PesterTests.ps1
# Content: Copy from Phase 0 section above
# Verification:
Get-Help .\Invoke-PesterTests.ps1  # Should show help
```

**Task 1.5: Create Template Test**
```powershell
# Action: Create file .\tests\Template.Tests.ps1
# Content: Copy from Phase 0 section above
# Verification:
.\Invoke-PesterTests.ps1 -TestType Unit  # Should execute (may skip tests)
```

**Commit:** `git commit -m "Phase 0: Setup Pester infrastructure"`

#### Step 2: Migrate First Test (Phase 1)

**Task 2.1: Migrate test-syntax.ps1**

**Steps:**
1. Read existing test: `Get-Content .\TestScripts\test-syntax.ps1 -Raw`
2. Create new file: `.\tests\Unit\Syntax.Tests.ps1`
3. Copy template structure from Phase 1 section
4. Convert test logic:
   - Replace `Write-Host "[PASS]"` with `Should -BeNullOrEmpty`
   - Replace `foreach` with `-TestCases`
   - Remove `exit` statements
5. Verify conversion:
```powershell
# Run old test
.\TestScripts\test-syntax.ps1
$oldExitCode = $LASTEXITCODE

# Run new test
.\Invoke-PesterTests.ps1 -TestType Unit -Tags 'Syntax'
# Should pass same number of files
```

**Verification Criteria:**
- New test file exists at `.\tests\Unit\Syntax.Tests.ps1`
- New test passes when run via Invoke-PesterTests.ps1
- Same files validated as legacy test
- No parse errors in new test file

**Commit:** `git commit -m "Migrate test-syntax.ps1 to Pester"`

**Task 2.2: Migrate test-simple-function-loading.ps1**

**Steps:**
1. Read existing test: `Get-Content .\TestScripts\test-simple-function-loading.ps1 -Raw`
2. Create new file: `.\tests\Unit\FunctionLoading.Tests.ps1`
3. Copy template structure from Phase 1 section
4. Convert test logic:
   - Replace function availability checks with `Should -Not -BeNullOrEmpty`
   - Use `-TestCases` for multiple functions
5. Verify conversion:
```powershell
.\TestScripts\test-simple-function-loading.ps1
$oldExitCode = $LASTEXITCODE

.\Invoke-PesterTests.ps1 -TestType Unit -Tags 'FunctionLoading'
# Compare results
```

**Verification Criteria:**
- New test file exists
- All critical functions validated
- Same pass/fail result as legacy test

**Commit:** `git commit -m "Migrate test-simple-function-loading.ps1 to Pester"`

**Repeat for remaining Phase 1 tests:**
- test-function-loading-validation.ps1
- test-get-user-strong-mapping-simple.ps1
- test-domain-config-simple.ps1
- test-replace-logic-simple.ps1

**Commit after each:** `git commit -m "Migrate [test-name] to Pester"`

#### Step 3: Migrate Unit Tests Batch (Phase 2)

**For each unit test in priority list:**

**Algorithm:**
```
FOR each test in unit_test_priority_list:
    1. Read legacy test file
    2. Analyze structure:
       - Identify test sections (Write-TestSection calls)
       - Identify assertions (Write-TestResult calls)
       - Identify mocks (function overrides)
       - Identify setup/teardown (Start-UnifiedTest/Complete-UnifiedTest)
    3. Create Pester test file:
       - Generate Describe block with test name
       - Convert sections to Context blocks
       - Convert assertions to It blocks with Should
       - Convert mocks to Mock statements
       - Convert setup/teardown to BeforeAll/AfterAll
    4. Verify conversion:
       - Run legacy test, capture exit code
       - Run Pester test, capture results
       - Compare: both should pass or both should fail
    5. If verification passes:
       - Commit new Pester test
       - Archive legacy test (move to .\TestScripts\archived\)
    6. If verification fails:
       - Log failure details
       - Review and adjust conversion
       - Re-verify
END FOR
```

**Conversion Template for AI:**
```powershell
# Input: Legacy test content
$legacyContent = Get-Content $legacyTestPath -Raw

# Pattern matching for conversion
$testSections = [regex]::Matches($legacyContent, 'Write-TestSection\s+"([^"]+)"')
$testResults = [regex]::Matches($legacyContent, 'Write-TestResult\s+"([^"]+)"\s+-Success\s+(\$[^)]+)')

# Generate Pester structure
$pesterContent = @"
Describe "$testName" -Tags 'Unit' {
    BeforeAll {
        `$script:TestContext = Initialize-AutopilotTestEnvironment
        Import-AutopilotFunctions -RootPath `$script:TestContext.RootPath
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext `$script:TestContext
    }
"@

# Add Context blocks for each section
foreach ($section in $testSections) {
    $sectionName = $section.Groups[1].Value
    $pesterContent += @"
    
    Context "$sectionName" {
"@
    # Find assertions in this section
    # Convert to It blocks
}

# Complete Pester file
$pesterContent += "`n}"

# Write to new file
Set-Content -Path $pesterTestPath -Value $pesterContent
```

**Batch Processing Command:**
```powershell
# Process all unit tests
$unitTests = @(
    "test-get-entra-directory-object.ps1",
    "test-show-directory-object-list.ps1",
    "test-resolve-directory-object.ps1"
    # ... more tests
)

foreach ($test in $unitTests) {
    Write-Host "Processing: $test" -ForegroundColor Cyan
    
    # Run conversion
    .\tools\Convert-LegacyTestToPester.ps1 -TestPath ".\TestScripts\$test"
    
    # Manual review and completion of TODOs
    # (AI agent should analyze generated file and complete)
    
    # Verify
    $legacyResult = & ".\TestScripts\$test"
    $legacyExit = $LASTEXITCODE
    
    $pesterFile = $test -replace '^test-', '' -replace '\.ps1$', '.Tests.ps1'
    $pesterResult = .\Invoke-PesterTests.ps1 -TestType Unit -Tags ($pesterFile -replace '.Tests.ps1','')
    
    # Compare and commit if match
    if (($legacyExit -eq 0 -and $pesterResult.FailedCount -eq 0) -or 
        ($legacyExit -ne 0 -and $pesterResult.FailedCount -gt 0)) {
        git add .
        git commit -m "Migrate $test to Pester"
        
        # Archive legacy test
        Move-Item ".\TestScripts\$test" ".\TestScripts\archived\$test"
        git add .
        git commit -m "Archive $test (migrated)"
    } else {
        Write-Host "Verification failed for $test - requires manual review" -ForegroundColor Red
    }
}
```

#### Step 4: Integration Tests (Phase 3)

**For each integration test:**

**Key Differences:**
- More complex setup with multiple components
- Multiple mocks interacting
- File system operations common
- Longer execution time acceptable

**Conversion Algorithm:**
```
1. Identify all components under test
2. Create comprehensive BeforeAll setup:
   - Initialize test environment
   - Load all functions
   - Create test files (settings, config, etc.)
   - Setup mock data
3. For each test scenario:
   - Create Context block
   - Setup scenario-specific mocks
   - Execute workflow
   - Verify end-to-end results
4. Comprehensive AfterAll cleanup:
   - Remove test files
   - Clear mocks
   - Reset state
```

**Commit:** After each integration test migration

#### Step 5: Finalization (Phase 5)

**Task 5.1: Create Unified Test Runner**
```powershell
# Action: Create .\Invoke-AllTests.ps1
# Content: Copy from Phase 5 section
# Verification:
.\Invoke-AllTests.ps1 -Quick
# Should run both Pester and remaining legacy tests
```

**Task 5.2: Update Documentation**
```powershell
# Update AGENTS.md Testing Guidelines section
# Update README.md with new test commands
# Create PESTER_MIGRATION_SUMMARY.md with statistics
```

**Task 5.3: CI/CD Integration**
```powershell
# Create or update .github/workflows/test.yml
# Content: Copy from Phase 5 section
```

**Task 5.4: Generate Migration Report**
```powershell
# Create migration completion report
$report = @"
# Pester Migration Completion Report

**Migration Date:** $(Get-Date -Format 'yyyy-MM-dd')

## Statistics
- Tests Migrated: $migratedCount
- Tests Archived: $archivedCount
- Tests Remaining in Legacy: $legacyCount
- Total Pester Test Files: $pesterFileCount
- Code Coverage: $coveragePercent%

## Test Execution Comparison
- Legacy Framework Time: $oldTime minutes
- Pester Framework Time: $newTime minutes
- Time Saved: $timeSaved minutes

## Files Modified
$modifiedFiles

## Commits Made
$commitCount commits

## Next Steps
- Monitor CI/CD pipeline stability
- Review code coverage reports
- Identify gaps in test coverage
- Plan for remaining legacy test migration
"@

$report | Set-Content ".\docs\PESTER_MIGRATION_SUMMARY.md"
```

**Final Commit:** `git commit -m "Complete Pester migration - Phase 5"`

### AI Agent Decision Tree

```
START Migration Decision

Is this a new test file creation?
├─ YES → Use Pester format (Template.Tests.ps1)
└─ NO → Continue to legacy test migration

Is test in Phase 1-4 priority list?
├─ YES → Migrate to Pester
│   ├─ Is test complexity LOW?
│   │   ├─ YES → Automated conversion + manual review
│   │   └─ NO → Manual conversion with AI assistance
│   └─ Verify: Does Pester test match legacy results?
│       ├─ YES → Commit and archive legacy
│       └─ NO → Debug and fix conversion
└─ NO → Keep in legacy framework

Is test a performance benchmark?
├─ YES → Keep in legacy framework
└─ NO → Continue evaluation

Is test a demo script?
├─ YES → Exclude from migration
└─ NO → Evaluate for future migration

END Decision
```

### Automated Validation Script

**File:** `tools/Validate-PesterMigration.ps1`
```powershell
<#
.SYNOPSIS
    Validates Pester migration for a specific test
.DESCRIPTION
    Compares legacy test and Pester test results to ensure equivalence
.PARAMETER LegacyTestPath
    Path to legacy test file
.PARAMETER PesterTestPath
    Path to Pester test file
.EXAMPLE
    .\Validate-PesterMigration.ps1 -LegacyTestPath .\TestScripts\test-example.ps1 -PesterTestPath .\tests\Unit\Example.Tests.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LegacyTestPath,
    
    [Parameter(Mandatory)]
    [string]$PesterTestPath
)

Write-Host "Validating Migration" -ForegroundColor Cyan
Write-Host "Legacy: $LegacyTestPath" -ForegroundColor Gray
Write-Host "Pester: $PesterTestPath" -ForegroundColor Gray
Write-Host ""

# Run legacy test
Write-Host "Running legacy test..." -ForegroundColor Yellow
$legacyOutput = & $LegacyTestPath 2>&1
$legacyExitCode = $LASTEXITCODE
$legacyPassed = $legacyExitCode -eq 0

# Run Pester test
Write-Host "Running Pester test..." -ForegroundColor Yellow
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $PesterTestPath
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Minimal'
$pesterResult = Invoke-Pester -Configuration $pesterConfig
$pesterPassed = $pesterResult.FailedCount -eq 0

# Compare results
Write-Host ""
Write-Host "Comparison Results:" -ForegroundColor Cyan
Write-Host "  Legacy Status: $(if ($legacyPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($legacyPassed) { 'Green' } else { 'Red' })
Write-Host "  Pester Status: $(if ($pesterPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($pesterPassed) { 'Green' } else { 'Red' })

$match = ($legacyPassed -eq $pesterPassed)
Write-Host "  Results Match: $match" -ForegroundColor $(if ($match) { 'Green' } else { 'Red' })

if (-not $match) {
    Write-Host ""
    Write-Host "VALIDATION FAILED - Results do not match!" -ForegroundColor Red
    Write-Host "Legacy exit code: $legacyExitCode" -ForegroundColor Yellow
    Write-Host "Pester failed count: $($pesterResult.FailedCount)" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "VALIDATION PASSED - Migration successful!" -ForegroundColor Green
exit 0
```

### Error Handling for AI Agents

**Common Issues and Solutions:**

| Issue | Symptom | Solution |
|-------|---------|----------|
| Mock not isolated | Tests affect each other | Add `BeforeEach` to reset mocks |
| Function not found | `Get-Command` returns null | Verify `Import-AutopilotFunctions` called |
| Test timeout | Pester hangs | Add `-Skip` for slow tests |
| Exit code mismatch | Legacy exits, Pester doesn't | Remove `exit` from test, use `Should` |
| File not cleaned up | Tests leave files | Ensure `AfterAll` removes test folder |
| Mock not called | `Should -Invoke` fails | Check function is mocked before called |
| PowerShell 5.1 syntax | Unicode characters fail | Use ASCII only in output |
| State pollution | Test B fails after Test A | Add state reset in `BeforeEach` |

---

## Validation & Quality Gates

### Validation Checklist

**Phase 0 Validation:**
- [ ] Pester module installed and accessible
- [ ] Directory structure created
- [ ] Helper module imports successfully
- [ ] Template test runs without errors
- [ ] Configuration function returns valid config

**Phase 1 Validation (Per Test):**
- [ ] New Pester test file created
- [ ] Pester test passes
- [ ] Legacy test still passes
- [ ] Same pass/fail outcome as legacy
- [ ] No PowerShell syntax errors

**Phase 2 Validation (Per Test):**
- [ ] Pester test covers all legacy test scenarios
- [ ] Mocking works as expected
- [ ] Test isolation verified (no state pollution)
- [ ] Code coverage reported
- [ ] Execution time comparable or better

**Phase 3 Validation (Per Test):**
- [ ] Complex workflows function correctly
- [ ] Multiple component interactions work
- [ ] Mock sequences execute properly
- [ ] End-to-end scenarios pass

**Phase 4 Validation:**
- [ ] High-value tests migrated
- [ ] Low-value tests documented as "keep legacy"
- [ ] Decision matrix applied consistently

**Phase 5 Validation:**
- [ ] Unified test runner executes successfully
- [ ] CI/CD pipeline integrated
- [ ] Documentation updated
- [ ] Code coverage reports generated
- [ ] Migration summary document created

### Quality Gates

**Gate 1: Phase Completion**
- All tests in phase migrated successfully
- All validation criteria met
- No regressions in migrated tests
- Peer review completed
- Commit to main branch

**Gate 2: Coverage Threshold**
- Minimum 70% code coverage for migrated components
- Coverage report generated and reviewed
- Gaps in coverage documented

**Gate 3: Performance Benchmark**
- Pester tests execute in comparable time to legacy
- No more than 20% slowdown acceptable
- Performance regression analyzed and justified

**Gate 4: CI/CD Integration**
- Tests run successfully in CI/CD pipeline
- Test results published correctly
- Code coverage reported to pipeline
- Build fails on test failure

### Regression Testing

**Regression Test Suite:**
```powershell
# Run after each migration batch
.\tools\Run-RegressionTests.ps1

# What it tests:
# 1. All migrated Pester tests pass
# 2. Remaining legacy tests still pass
# 3. No new failures introduced
# 4. Performance within acceptable range
# 5. Code coverage maintained or improved
```

**Regression Test Script:**
```powershell
# tools/Run-RegressionTests.ps1
[CmdletBinding()]
param()

$passed = $true

# Test 1: Pester tests pass
Write-Host "Running Pester tests..." -ForegroundColor Cyan
$pesterResult = .\Invoke-PesterTests.ps1 -TestType All
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: Pester tests failed" -ForegroundColor Red
    $passed = $false
}

# Test 2: Legacy tests pass
Write-Host "Running legacy tests..." -ForegroundColor Cyan
$legacyCategories = @('performance')
foreach ($category in $legacyCategories) {
    $result = .\TestScripts\Test-Runner.ps1 -TestCategory $category
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Legacy $category tests failed" -ForegroundColor Red
        $passed = $false
    }
}

# Test 3: Performance check
Write-Host "Checking performance..." -ForegroundColor Cyan
$unitDuration = Measure-Command { .\Invoke-PesterTests.ps1 -TestType Unit | Out-Null }
if ($unitDuration.TotalMinutes -gt 5) {
    Write-Host "WARN: Unit tests took longer than expected ($($unitDuration.TotalMinutes) minutes)" -ForegroundColor Yellow
}

# Summary
if ($passed) {
    Write-Host "`nREGRESSION TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nREGRESSION TESTS FAILED" -ForegroundColor Red
    exit 1
}
```

---

## Rollback Strategy

### Rollback Triggers

Rollback should be considered if:
- More than 20% of migrated tests fail
- Performance degrades by more than 50%
- Critical functionality broken
- CI/CD pipeline consistently fails
- Team cannot maintain Pester tests

### Rollback Procedures

**Level 1: Rollback Single Test**
```powershell
# Restore individual test from archive
$testName = "test-example.ps1"
Copy-Item ".\TestScripts\archived\$testName" ".\TestScripts\$testName" -Force
git add ".\TestScripts\$testName"
git commit -m "Rollback $testName from Pester migration"

# Remove Pester test
$pesterTest = $testName -replace '^test-', '' -replace '\.ps1$', '.Tests.ps1'
Remove-Item ".\tests\Unit\$pesterTest" -Force
git add ".\tests\Unit\$pesterTest"
git commit -m "Remove Pester version of $testName"
```

**Level 2: Rollback Phase**
```powershell
# Restore all tests from a specific phase
$phase = "Phase2"  # Or Phase1, Phase3, etc.

# Get list of archived tests from that phase (from git history)
git log --all --oneline --grep="$phase" --diff-filter=M -- "TestScripts/archived/*" |
    ForEach-Object {
        # Extract test name and restore
    }

# Remove corresponding Pester tests
# Commit rollback
```

**Level 3: Complete Rollback**
```powershell
# Restore all archived tests
Get-ChildItem ".\TestScripts\archived\test-*.ps1" | ForEach-Object {
    Copy-Item $_.FullName ".\TestScripts\$($_.Name)" -Force
}

# Remove Pester infrastructure
Remove-Item ".\tests" -Recurse -Force
Remove-Item ".\PesterConfiguration.ps1" -Force
Remove-Item ".\Invoke-PesterTests.ps1" -Force

# Commit rollback
git add .
git commit -m "Complete rollback of Pester migration"

# Update documentation
# Update CI/CD to use legacy Test-Runner.ps1
```

### Rollback Decision Matrix

| Issue Severity | Failed Tests % | Performance Impact | Action |
|----------------|----------------|-------------------|---------|
| Low | < 5% | < 20% | Fix forward, no rollback |
| Medium | 5-10% | 20-30% | Pause migration, fix issues |
| High | 10-20% | 30-50% | Rollback last phase |
| Critical | > 20% | > 50% | Complete rollback |

---

## Success Metrics

### Quantitative Metrics

**1. Test Count Migration**
- **Target:** Migrate 60+ high-value tests to Pester (60% of 101 tests)
- **Measurement:** Count of files in `.\tests\**\*.Tests.ps1`
- **Minimum Success:** 50 tests migrated (50%)

**2. Code Coverage**
- **Target:** Achieve 70% code coverage for migrated components
- **Measurement:** Pester code coverage reports
- **Minimum Success:** 60% coverage

**3. Test Execution Time**
- **Baseline:** Current full suite ~45 minutes
- **Target:** Pester tests ≤ legacy test execution time
- **Measurement:** `Measure-Command { .\Invoke-PesterTests.ps1 -TestType All }`

**4. Test Stability**
- **Target:** >95% pass rate for migrated tests
- **Measurement:** (PassedTests / TotalTests) * 100
- **Minimum Success:** >90% pass rate

**5. CI/CD Integration**
- **Target:** Tests run automatically on PR and merge
- **Measurement:** GitHub Actions workflow executes successfully
- **Success:** 100% of PRs trigger test runs

**6. Code Duplication Reduction**
- **Current:** Test-helper.ps1 + per-test function loading
- **Target:** Centralized helpers in AutopilotTestHelpers.psm1
- **Measurement:** Lines of code in test files

### Qualitative Metrics

**1. Developer Experience**
- **Target:** Developers prefer Pester for new tests
- **Measurement:** Survey team, track new test format adoption
- **Success:** 80% of new tests use Pester

**2. Maintainability**
- **Target:** Easier test updates when application changes
- **Measurement:** Time to update tests after function changes
- **Success:** Subjective improvement reported by team

**3. Debugging**
- **Target:** Faster test failure diagnosis
- **Measurement:** Time from failure to fix
- **Success:** Clear failure messages in Pester output

**4. Documentation Quality**
- **Target:** Clear migration docs for future reference
- **Measurement:** Doc completeness, team feedback
- **Success:** Docs enable new contributors to write Pester tests

### Success Criteria Dashboard

```
┌────────────────────────────────────────────────────────────┐
│                PESTER MIGRATION SUCCESS DASHBOARD           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Tests Migrated:        [████████████░░░] 60/101 (59%)   │
│  Code Coverage:         [███████████░░░░] 72%            │
│  Test Pass Rate:        [███████████████] 97%            │
│  CI/CD Integration:     [████████████████] 100%          │
│  Execution Time:        [██████████████░░] 95% of target │
│                                                            │
│  Overall Progress:      [██████████████░░] 85%           │
│                                                            │
│  Status: ON TRACK ✓                                       │
└────────────────────────────────────────────────────────────┘
```

---

## Timeline & Resource Planning

### Estimated Timeline

**Total Duration: 8-9 weeks**

| Phase | Duration | Work Days | Effort (Hours) | Dependencies |
|-------|----------|-----------|----------------|--------------|
| Phase 0: Setup | 1 week | 2-3 days | 8-12 hours | None |
| Phase 1: Pilot | 1 week | 3-4 days | 12-16 hours | Phase 0 |
| Phase 2: Unit Tests | 2 weeks | 8-10 days | 32-40 hours | Phase 1 |
| Phase 3: Integration | 2 weeks | 8-10 days | 32-40 hours | Phase 2 |
| Phase 4: Complex Tests | 2 weeks | 6-8 days | 24-32 hours | Phase 3 |
| Phase 5: Finalization | 1 week | 3-4 days | 12-16 hours | Phase 4 |
| **Total** | **9 weeks** | **30-39 days** | **120-156 hours** | |

### Detailed Weekly Schedule

**Week 1: Foundation**
```
Day 1-2: Phase 0 Setup
  - Create directory structure
  - Setup Pester configuration
  - Create helper modules
  - Documentation setup
  
Day 3-5: Phase 1 Begin
  - Migrate test-syntax.ps1
  - Migrate test-simple-function-loading.ps1
  - Validate patterns
  - Team review
```

**Week 2: Pilot Completion**
```
Day 1-3: Phase 1 Continue
  - Migrate remaining pilot tests
  - Validate all conversions
  - Document lessons learned
  
Day 4-5: Phase 2 Begin
  - Start unit test migration
  - Create conversion script
  - Migrate first batch (3-5 tests)
```

**Week 3-4: Unit Tests**
```
Week 3:
  - Migrate 15-20 unit tests
  - Validate each conversion
  - Daily progress commits
  
Week 4:
  - Complete remaining unit tests (15-20)
  - Run regression tests
  - Generate code coverage reports
  - Week summary and review
```

**Week 5-6: Integration Tests**
```
Week 5:
  - Analyze integration test complexity
  - Migrate 6-8 integration tests
  - Complex mocking scenarios
  
Week 6:
  - Complete integration tests
  - End-to-end validation
  - Performance benchmarking
```

**Week 7-8: Selective Complex Migration**
```
Week 7:
  - Migrate high-value comprehensive tests
  - Document "keep legacy" decisions
  - Update test prioritization
  
Week 8:
  - Complete final migrations
  - Archive migrated tests
  - Update documentation
```

**Week 9: Finalization**
```
Day 1-2:
  - Create unified test runner
  - Integrate CI/CD
  - Final validation
  
Day 3-4:
  - Documentation updates
  - Migration summary
  - Team training/handoff
  
Day 5:
  - Final review and sign-off
  - Celebrate completion! 🎉
```

### Resource Requirements

**Personnel:**
- 1 Senior Developer (AI Agent or Human)
  - Leads migration effort
  - Performs complex conversions
  - Reviews all changes
  
- 1 Junior Developer (Optional)
  - Assists with simple conversions
  - Validates migrations
  - Updates documentation

**Tools:**
- PowerShell 5.1+
- Pester 5.7.1+
- Git for version control
- VS Code with Pester extension (recommended)
- CI/CD platform (GitHub Actions, Azure DevOps, etc.)

**Infrastructure:**
- Development environment for testing
- CI/CD pipeline access
- Code coverage reporting tools

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Conversion errors | High | Medium | Automated validation, peer review |
| Performance degradation | Medium | High | Benchmark each phase, optimize |
| Team resistance | Low | Medium | Training, documentation, gradual adoption |
| Timeline overrun | Medium | Medium | Phased approach, clear milestones |
| Breaking changes | Low | High | Parallel operation, rollback plan |
| Loss of test coverage | Low | High | Validation checklist, regression tests |

### Contingency Plans

**If Timeline Slips:**
- Pause after Phase 2 or 3
- Operate with partial migration
- Continue in next sprint/cycle

**If Performance Issues:**
- Profile slow tests
- Optimize Pester configuration
- Keep performance tests in legacy

**If Team Capacity Changes:**
- Prioritize high-value tests only
- Document partial migration state
- Plan continuation with new resources

---

## Conclusion

### Summary

This comprehensive migration plan provides a structured approach to transitioning from the current custom testing framework to Pester v5.7.1. The phased approach minimizes risk, the prioritization ensures high-value tests are migrated first, and the detailed AI agent guide enables automated implementation.

### Key Takeaways

1. **Phased Migration**: 5 distinct phases allow for incremental progress and validation
2. **Prioritization**: Focus on high-value, low-complexity tests first
3. **Parallel Operation**: Run both frameworks until confident in migration
4. **AI-Friendly**: Step-by-step instructions optimized for AI agent implementation
5. **Rollback Ready**: Multiple rollback levels if issues arise
6. **Quality Gates**: Clear validation criteria at each phase

### Expected Outcomes

Upon completion, the project will have:
- ✅ **60+ tests in Pester format** (60% of total tests)
- ✅ **Industry-standard testing framework** with IDE support
- ✅ **Code coverage reporting** (70%+ for migrated components)
- ✅ **CI/CD integration** with automated test execution
- ✅ **Improved maintainability** with consistent patterns
- ✅ **Better mocking capabilities** with proper isolation
- ✅ **Comprehensive documentation** for future development

### Next Steps

1. **Review this plan** with development team
2. **Get stakeholder approval** for migration effort
3. **Assign resources** (developer time, CI/CD access)
4. **Create migration branch** in Git
5. **Begin Phase 0** - Setup infrastructure
6. **Execute phases sequentially** with validation at each step
7. **Monitor progress** against success metrics
8. **Celebrate completion!** 🎉

### Questions & Support

For questions or issues during implementation:
- Review relevant phase documentation
- Check AI Agent Implementation Guide
- Consult Pester official docs: https://pester.dev/
- Review example conversions in this plan
- Use rollback strategy if needed

---

**Document Status:** ✅ Ready for Implementation  
**Next Action:** Review with team and begin Phase 0  
**Estimated Completion:** 8-9 weeks from start  
**Success Probability:** High (with proper execution)

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| Pester | PowerShell testing framework, industry standard |
| Describe | Top-level test container in Pester |
| Context | Logical grouping within Describe block |
| It | Individual test case |
| BeforeAll | Setup code run once before tests |
| AfterAll | Cleanup code run once after tests |
| BeforeEach | Setup run before each test |
| AfterEach | Cleanup run after each test |
| Mock | Pester function to fake dependencies |
| Should | Pester assertion keyword |
| -TestCases | Pester feature for parameterized tests |
| Code Coverage | Percentage of code executed by tests |

### B. References

**Official Documentation:**
- Pester v5 Docs: https://pester.dev/docs/quick-start
- Pester Migration Guide: https://pester.dev/docs/migrations/v3-to-v4
- PowerShell Testing Best Practices: https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/testing/testing-overview

**Community Resources:**
- Pester GitHub: https://github.com/pester/Pester
- PowerShell.org Forums: https://forums.powershell.org/
- Reddit r/PowerShell: https://reddit.com/r/PowerShell

**Internal References:**
- TEST_HARNESS_SYSTEM_WIDE_IMPLEMENTATION_PROPOSAL.md
- AGENTS.md (Testing Guidelines section)
- TestScripts/test-helper.ps1 (current framework)

### C. Conversion Quick Reference

**Common Conversions:**

| Legacy Pattern | Pester Equivalent |
|----------------|-------------------|
| `Write-Host "[PASS]"` | `Should -Be $expected` |
| `Write-Host "[FAIL]"` | Test automatically fails if Should fails |
| `exit 0` | Remove (Pester handles) |
| `exit 1` | Remove (Pester handles) |
| `Write-TestSection "Title"` | `Context "Title" { }` |
| `Write-TestResult "Msg" -Success $bool` | `$result \| Should -Be $expected` |
| `Start-UnifiedTest` | `BeforeAll { }` |
| `Complete-UnifiedTest` | `AfterAll { }` |
| `function Mock { }` | `Mock FunctionName { }` |
| `Load-AllFunctions` | `Import-AutopilotFunctions` |
| `if ($success) { exit 0 }` | `$result \| Should -Be $expected` |

### D. Test File Naming Conventions

**Legacy:**
- Pattern: `test-feature-name.ps1`
- Location: `TestScripts/`
- Example: `test-get-entra-directory-object.ps1`

**Pester:**
- Pattern: `FeatureName.Tests.ps1` (PascalCase)
- Location: `tests/Unit/`, `tests/Integration/`, etc.
- Example: `GetEntraDirectoryObject.Tests.ps1`

### E. Contact & Support

**Migration Lead:**
- Review this document for guidance
- Consult AI Agent Implementation Guide for step-by-step instructions

**Technical Issues:**
- Pester syntax errors: Check Pester documentation
- Conversion problems: Review conversion patterns section
- Performance issues: Profile tests, check benchmarks

**Process Issues:**
- Timeline concerns: Adjust phase schedule
- Resource constraints: Prioritize high-value tests
- Quality problems: Increase validation rigor

---

**END OF DOCUMENT**

**Version:** 1.0  
**Last Updated:** October 10, 2025  
**Document Owner:** Autopilot Development Team  
**Status:** ✅ Ready for Implementation

