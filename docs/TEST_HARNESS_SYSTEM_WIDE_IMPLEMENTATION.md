# Test Harness System-Wide Implementation Plan

**Document Version:** 1.0  
**Created:** October 9, 2025  
**Status:** Ready for Implementation  
**Estimated Total Effort:** 4-6 hours  
**Expected Impact:** 8-10 minutes saved per test run, 4,000+ lines of code removed

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Proposed Architecture](#proposed-architecture)
4. [Implementation Phases](#implementation-phases)
5. [Technical Details](#technical-details)
6. [Edge Cases & Gotchas](#edge-cases--gotchas)
7. [Testing & Validation](#testing--validation)
8. [Rollback Strategy](#rollback-strategy)
9. [Success Metrics](#success-metrics)

---

## Executive Summary

### Problem Statement
The current test infrastructure executes 202 test files in isolated PowerShell sessions, requiring each test to independently load 185 application functions. This results in:
- **8-10 minutes** of redundant function loading overhead per full test run
- **PowerShell scoping issues** when functions call other functions in test context
- **4,000+ lines** of duplicated function loading code across test files
- **Maintenance burden** when function paths or loading logic changes

### Solution Overview
Migrate Test-Runner.ps1 from isolated session execution to in-process execution with shared function scope:
1. Load all 185 functions **once** in Test-Runner.ps1 before test execution loop
2. Execute tests in-process using dot-sourcing (`. $testPath`) instead of spawning new PowerShell sessions
3. Remove function loading code from all 202 test files
4. Preserve existing test category system, reporting, and error handling

### Validation Status
- ✅ **Proof of Concept Validated:** Run-MigrationTests.ps1 successfully demonstrates pattern
- ✅ **Success Rate:** 48/50 tests passing (96%) in migration test harness
- ✅ **Performance Verified:** Function loading overhead reduced from per-test to once-per-run
- ✅ **PowerShell 5.1 Compatible:** All changes maintain strict 5.1 compatibility

---

## Current State Analysis

### Test-Runner.ps1 Architecture (Current)
**File:** `c:\Users\zuhai\code\Autopilot\TestScripts\Test-Runner.ps1` (821 lines)

**Key Components:**
```powershell
# Lines 97-218: TestRegistry - 13 categories with patterns, priorities, dependencies
$TestRegistry = @{
    'syntax' = @{ Pattern = 'test-syntax-*.ps1'; Priority = 1; EstimatedDuration = '< 5 seconds' }
    'core' = @{ Pattern = 'test-core-*.ps1'; Priority = 2; EstimatedDuration = '30-60 seconds' }
    'unit' = @{ Pattern = 'test-*-unit.ps1'; Priority = 3; EstimatedDuration = '2-4 minutes' }
    # ... 10 more categories
}

# Lines 500-600: Test execution loop (CRITICAL SECTION)
for ($i = 0; $i -lt $TestFiles.Count; $i++) {
    # Line 555: ISOLATED SESSION EXECUTION
    $testArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $testPath)
    $output = & pwsh @testArgs 2>&1  # ← Spawns new PowerShell process
    $exitCode = $LASTEXITCODE
    
    # Lines 560-590: Result tracking and error handling
}
```

**Current Execution Flow:**
```
Test-Runner.ps1
  ├─→ Discover tests by category (Get-TestFilesByCategory)
  ├─→ For each test file:
  │     ├─→ Spawn new PowerShell process (& pwsh -File test.ps1)
  │     ├─→ Test loads 185 functions internally
  │     ├─→ Test executes
  │     ├─→ Process exits, return exit code
  │     └─→ Parse output and track results
  └─→ Generate summary report
```

**Performance Profile:**
- **Function Loading:** 202 tests × 2.5 seconds = 505 seconds (8.4 minutes)
- **Test Execution:** Varies by category (syntax: 5s, comprehensive: 8m)
- **Process Overhead:** 202 process spawns + teardowns = ~20-30 seconds
- **Total Overhead:** ~9 minutes per full test run

### Test File Architecture (Current)
**Sample Test Structure:** `test-migration-comprehensive.ps1` (BEFORE simplification)

```powershell
# Lines 1-50: Function loading boilerplate (REPEATED IN ALL 202 FILES)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$functionsPath = Join-Path -Path $rootPath -ChildPath "functions"

# Load all functions from subdirectories
Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Lines 51+: Actual test logic
# Test 1: Verify something
# Test 2: Verify something else
# ...
```

**Redundancy Analysis:**
- **202 files** × **20 lines** of loading code = **4,040 lines** of duplication
- **Same loading logic** in every file (copy-paste pattern)
- **Maintenance risk:** Path changes require updates in 202 locations
- **Error-prone:** Inconsistent error handling across files

---

## Proposed Architecture

### New Execution Flow
```
Test-Runner.ps1
  ├─→ LOAD ALL FUNCTIONS ONCE (NEW - Lines ~490-520)
  │     ├─→ Find-FolderPath helper
  │     ├─→ Recursively load *.ps1 from functions/
  │     ├─→ Verify critical functions
  │     └─→ Cache in global scope
  │
  ├─→ Discover tests by category (UNCHANGED)
  │
  ├─→ For each test file:
  │     ├─→ Dot-source test in current scope (. $testPath)  ← CHANGED
  │     ├─→ Test executes with access to loaded functions  ← NEW
  │     ├─→ Capture output and exit status
  │     └─→ Track results (UNCHANGED)
  │
  └─→ Generate summary report (UNCHANGED)
```

### Simplified Test File Structure (After Migration)
```powershell
# test-migration-comprehensive-simple.ps1 (AFTER simplification)

# NO FUNCTION LOADING CODE - relies on Test-Runner harness

# Optional: Mock external dependencies
Mock Get-EntraDirectoryObject { ... }
Mock Read-Host { return "y" }

# Test 1: Verify something
# Test 2: Verify something else
# ...

# Return exit code
exit 0  # or exit 1 on failure
```

**Benefits:**
- **~20 lines removed** per test file
- **4,040 lines** removed from codebase
- **Single source of truth** for function loading
- **Consistent behavior** across all tests

---

## Implementation Phases

### Phase 0: Preparation & Backup (15 minutes)

**0.1 Create Implementation Branch**
```powershell
git checkout -b test-harness-system-wide
git push -u origin test-harness-system-wide
```

**0.2 Backup Critical Files**
```powershell
# Create backup directory
New-Item -Path ".\TestScripts\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -ItemType Directory

# Backup Test-Runner.ps1
Copy-Item ".\TestScripts\Test-Runner.ps1" ".\TestScripts\backup-*\Test-Runner.ps1.bak"

# Backup first 10 test files (validation set)
$validationTests = Get-ChildItem ".\TestScripts\test-*.ps1" | Select-Object -First 10
$validationTests | ForEach-Object {
    Copy-Item $_.FullName ".\TestScripts\backup-*\$($_.Name).bak"
}
```

**0.3 Document Current Test Results (Baseline)**
```powershell
# Run current test suite and capture baseline
.\TestScripts\Test-Runner.ps1 -TestCategory syntax -Verbose > baseline-syntax.log
.\TestScripts\Test-Runner.ps1 -TestCategory core -Verbose > baseline-core.log

# Record timing
Measure-Command { .\TestScripts\Test-Runner.ps1 -TestCategory syntax } | Out-File baseline-timing.txt
```

---

### Phase 1: Modify Test-Runner.ps1 (45-60 minutes)

**1.1 Add Find-FolderPath Helper Function**

**Location:** After parameter validation, around line 320 (after Get-AllTestFiles function)

**Code to Insert:**
```powershell
<#
.SYNOPSIS
    Finds a folder by name starting from script location and searching upwards.
.DESCRIPTION
    Helper function to locate the functions folder regardless of where Test-Runner.ps1 is executed from.
    Searches from current script location upward through parent directories until folder is found.
    Borrowed from test.ps1 proven implementation.
.PARAMETER FolderName
    Name of the folder to find (e.g., "functions").
.RETURNS
    Full path to the folder if found.
.THROWS
    Terminates script if folder not found after searching to root.
#>
function Find-FolderPath
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    
    # Start from script directory
    $currentPath = $PSScriptRoot
    if (-not $currentPath)
    {
        $currentPath = Get-Location
    }
    
    $maxLevels = 10
    $levelsChecked = 0
    
    while ($levelsChecked -lt $maxLevels)
    {
        $targetPath = Join-Path -Path $currentPath -ChildPath $FolderName
        
        if (Test-Path -Path $targetPath -PathType Container)
        {
            Write-Verbose "Found '$FolderName' folder at: $targetPath"
            return $targetPath
        }
        
        # Move up one directory
        $parentPath = Split-Path -Path $currentPath -Parent
        if (-not $parentPath -or $parentPath -eq $currentPath)
        {
            break
        }
        
        $currentPath = $parentPath
        $levelsChecked++
    }
    
    throw "Could not find '$FolderName' folder after checking $levelsChecked levels up from $PSScriptRoot"
}
```

**1.2 Add Function Loading Logic**

**Location:** Just before test execution loop, around line 490 (before "Test execution tracking" comment)

**Code to Insert:**
```powershell
# ============================================================================
# FUNCTION LOADING - Load all application functions once for all tests
# ============================================================================
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Loading Application Functions" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$functionLoadStart = Get-Date

try
{
    # Find functions folder
    $functionsFolder = Find-FolderPath -FolderName "functions"
    Write-Host "Functions folder: $functionsFolder" -ForegroundColor Gray
    
    # Load all .ps1 files recursively
    $functionFiles = Get-ChildItem -Path $functionsFolder -Recurse -Filter *.ps1 -ErrorAction Stop
    $loadedCount = 0
    $failedCount = 0
    $failedFunctions = @()
    
    foreach ($file in $functionFiles)
    {
        try
        {
            . $file.FullName
            $loadedCount++
            if ($LogLevel -in @('Debug'))
            {
                Write-Host "  Loaded: $($file.Name)" -ForegroundColor DarkGray
            }
        }
        catch
        {
            $failedCount++
            $failedFunctions += @{
                File = $file.Name
                Path = $file.FullName
                Error = $_.Exception.Message
            }
            Write-Host "  Failed: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    $functionLoadEnd = Get-Date
    $functionLoadDuration = $functionLoadEnd - $functionLoadStart
    
    Write-Host "`nFunction Loading Summary:" -ForegroundColor Cyan
    Write-Host "  Total files found: $($functionFiles.Count)" -ForegroundColor White
    Write-Host "  Successfully loaded: $loadedCount" -ForegroundColor Green
    if ($failedCount -gt 0)
    {
        Write-Host "  Failed to load: $failedCount" -ForegroundColor Yellow
    }
    Write-Host "  Duration: $($functionLoadDuration.TotalSeconds.ToString('F2'))s" -ForegroundColor White
    
    # Verify critical functions are loaded
    Write-Host "`nVerifying Critical Functions..." -ForegroundColor Cyan
    $criticalFunctions = @(
        'Write-Log',
        'Get-GraphAccessToken',
        'Initialize-AppConfig',
        'Show-Menu',
        'Get-EntraDirectoryObject',
        'Invoke-SettingsMigration'
    )
    
    $missingFunctions = @()
    foreach ($funcName in $criticalFunctions)
    {
        if (Get-Command $funcName -ErrorAction SilentlyContinue)
        {
            Write-Host "  ✓ $funcName" -ForegroundColor Green
        }
        else
        {
            Write-Host "  ✗ $funcName - NOT FOUND" -ForegroundColor Red
            $missingFunctions += $funcName
        }
    }
    
    if ($missingFunctions.Count -gt 0)
    {
        Write-Host "`nERROR: Critical functions missing!" -ForegroundColor Red
        Write-Host "Missing: $($missingFunctions -join ', ')" -ForegroundColor Red
        
        if ($failedFunctions.Count -gt 0)
        {
            Write-Host "`nFailed Function Details:" -ForegroundColor Yellow
            foreach ($failed in $failedFunctions)
            {
                Write-Host "  File: $($failed.File)" -ForegroundColor Yellow
                Write-Host "  Path: $($failed.Path)" -ForegroundColor Gray
                Write-Host "  Error: $($failed.Error)" -ForegroundColor Red
            }
        }
        
        throw "Cannot proceed with tests - critical functions not loaded"
    }
    
    Write-Host "`nAll critical functions verified successfully!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}
catch
{
    Write-Host "`nFATAL ERROR: Function loading failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nCannot proceed with test execution." -ForegroundColor Red
    exit 1
}

# Continue with test execution...
```

**1.3 Modify Test Execution Logic**

**Location:** Lines 540-570 (test execution loop)

**BEFORE:**
```powershell
try
{
    $testStartTime = Get-Date
    
    # Create test arguments
    $testArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $testPath
    )
    
    # Add verbosity based on log level
    if ($ShowVerbose -or $LogLevel -in @('Verbose', 'Debug'))
    {
        $testArgs += '-Verbose'
    }
    
    # Run the test in isolated session
    $output = & pwsh @testArgs 2>&1
    $exitCode = $LASTEXITCODE
    
    $testEndTime = Get-Date
    $duration = $testEndTime - $testStartTime
```

**AFTER:**
```powershell
try
{
    $testStartTime = Get-Date
    
    # Run the test in current process with loaded functions
    # Tests now have access to all 185 loaded functions
    $output = . $testPath 2>&1
    
    # Capture exit status (tests should use 'exit 0' or 'exit 1')
    # If test doesn't call exit, assume success if no exception thrown
    $exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    
    $testEndTime = Get-Date
    $duration = $testEndTime - $testStartTime
```

**GOTCHA #1:** Exit code handling changes with in-process execution:
- Isolated session: `$LASTEXITCODE` always set by process exit
- In-process: `$LASTEXITCODE` only set if test explicitly calls `exit`
- **Solution:** Default to 0 if `$LASTEXITCODE` is null, document requirement for tests to call `exit`

**1.4 Add Cleanup Between Tests (State Isolation)**

**Location:** Inside test execution loop, after test completes (around line 590)

**Code to Insert:**
```powershell
            # ... existing result tracking code ...
            
            # Cleanup: Reset any test-specific state (NEW)
            # This prevents state pollution between tests
            if ($testResult.Status -in @('Passed', 'Failed'))
            {
                # Clear any test-created variables (except our test infrastructure)
                Get-Variable | Where-Object {
                    $_.Name -notin @('TestFiles', 'testResults', 'totalTests', 'passedTests', 
                                      'failedTests', 'skippedTests', 'startTime', 'i', 'testFile',
                                      'testName', 'testPath', 'progress', 'testResult', 
                                      'functionsFolder', 'functionFiles', 'loadedCount',
                                      'criticalFunctions', 'LogLevel', 'ShowVerbose', 'CategoryName',
                                      'ContinueOnError', 'PWD', 'HOME', 'PSVersionTable', 'PSScriptRoot')
                } | Remove-Variable -ErrorAction SilentlyContinue
                
                # Clear any test-created PSDrives
                Get-PSDrive | Where-Object { 
                    $_.Provider.Name -eq 'FileSystem' -and 
                    $_.Name -notin @('C', 'D', 'E', 'F', 'Temp') 
                } | Remove-PSDrive -ErrorAction SilentlyContinue
            }
```

**GOTCHA #2:** State pollution between tests:
- Tests running in same process share global state
- Variables, PSDrives, environment changes persist
- **Solution:** Aggressive cleanup between tests, whitelist infrastructure variables

---

### Phase 2: Create Test Conversion Script (60-75 minutes)

**2.1 Create Conversion Script**

**File:** `TestScripts\Convert-TestToHarnessPattern.ps1`

```powershell
<#
.SYNOPSIS
    Converts test files from isolated session pattern to test harness pattern.
.DESCRIPTION
    Removes function loading boilerplate from test files, allowing them to rely on
    Test-Runner.ps1's shared function scope. Creates backup before modification.
.PARAMETER TestPath
    Path to test file to convert. Can be single file or wildcard pattern.
.PARAMETER WhatIf
    Shows what would be changed without making modifications.
.PARAMETER Backup
    Creates .bak backup file before modification (default: true).
.EXAMPLE
    .\Convert-TestToHarnessPattern.ps1 -TestPath "test-syntax-validation.ps1"
.EXAMPLE
    .\Convert-TestToHarnessPattern.ps1 -TestPath "test-*.ps1" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestPath,
    
    [switch]$WhatIf,
    
    [bool]$Backup = $true
)

$ErrorActionPreference = 'Stop'

# Find test files matching pattern
$testFiles = Get-ChildItem -Path $TestPath -ErrorAction SilentlyContinue
if (-not $testFiles)
{
    Write-Host "No test files found matching: $TestPath" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($testFiles.Count) test file(s) to convert" -ForegroundColor Cyan
Write-Host ""

$converted = 0
$skipped = 0
$failed = 0

foreach ($file in $testFiles)
{
    Write-Host "Processing: $($file.Name)" -ForegroundColor White
    
    try
    {
        $content = Get-Content -Path $file.FullName -Raw
        $originalContent = $content
        $modified = $false
        
        # Pattern 1: Standard function loading block
        $pattern1 = '(?ms)# Load (all )?functions.*?Get-ChildItem.*?-Filter \*\.ps1.*?ForEach-Object\s*\{[^}]*\.\s+\$_\.FullName[^}]*\}'
        if ($content -match $pattern1)
        {
            $content = $content -replace $pattern1, '# Functions loaded by Test-Runner.ps1 test harness'
            $modified = $true
            Write-Host "  ✓ Removed standard function loading block" -ForegroundColor Green
        }
        
        # Pattern 2: Path construction block (scriptPath, rootPath, functionsPath)
        $pattern2 = '(?m)^\$scriptPath\s*=\s*Split-Path.*?[\r\n]+^\$rootPath\s*=\s*Split-Path.*?[\r\n]+^\$functionsPath\s*=\s*Join-Path.*?[\r\n]+'
        if ($content -match $pattern2)
        {
            $content = $content -replace $pattern2, ''
            $modified = $true
            Write-Host "  ✓ Removed path construction variables" -ForegroundColor Green
        }
        
        # Pattern 3: Dot-sourcing specific function files
        $pattern3 = '(?m)^\.\s+["\$].*?functions.*?\.ps1["\s]*[\r\n]+'
        if ($content -match $pattern3)
        {
            $matchCount = ([regex]::Matches($content, $pattern3)).Count
            $content = $content -replace $pattern3, ''
            $modified = $true
            Write-Host "  ✓ Removed $matchCount dot-sourced function file(s)" -ForegroundColor Green
        }
        
        # Pattern 4: Find-FolderPath helper function definition
        $pattern4 = '(?ms)function Find-FolderPath\s*\{.*?\n\}\s*[\r\n]+'
        if ($content -match $pattern4)
        {
            $content = $content -replace $pattern4, ''
            $modified = $true
            Write-Host "  ✓ Removed Find-FolderPath helper function" -ForegroundColor Green
        }
        
        # Pattern 5: Explicit function folder discovery
        $pattern5 = '(?m)^\$functionsFolder\s*=\s*Find-FolderPath.*?[\r\n]+'
        if ($content -match $pattern5)
        {
            $content = $content -replace $pattern5, ''
            $modified = $true
            Write-Host "  ✓ Removed function folder discovery" -ForegroundColor Green
        }
        
        # Clean up excessive blank lines (more than 2 consecutive)
        $content = $content -replace '(\r?\n){3,}', "`n`n"
        
        # Add header comment if function loading was removed
        if ($modified)
        {
            # Check if header already exists
            if ($content -notmatch '# Functions loaded by Test-Runner\.ps1 test harness')
            {
                $header = @"
# ============================================================================
# Test Harness Pattern
# ============================================================================
# This test relies on Test-Runner.ps1 to load application functions.
# DO NOT add function loading code here - it's handled by the test harness.
# ============================================================================

"@
                $content = $header + $content
            }
            
            # Ensure test calls exit with status code
            if ($content -notmatch 'exit\s+\$')
            {
                Write-Host "  ⚠ Warning: Test doesn't call 'exit' - may need manual review" -ForegroundColor Yellow
            }
        }
        
        # Check if content actually changed
        if ($content -ne $originalContent)
        {
            $linesBefore = ($originalContent -split "`n").Count
            $linesAfter = ($content -split "`n").Count
            $linesRemoved = $linesBefore - $linesAfter
            
            Write-Host "  Lines: $linesBefore → $linesAfter (removed $linesRemoved)" -ForegroundColor Cyan
            
            if ($WhatIf)
            {
                Write-Host "  [WHATIF] Would modify file" -ForegroundColor Yellow
            }
            else
            {
                # Create backup
                if ($Backup)
                {
                    $backupPath = "$($file.FullName).bak"
                    Copy-Item -Path $file.FullName -Destination $backupPath -Force
                    Write-Host "  ✓ Backup created: $($file.Name).bak" -ForegroundColor Gray
                }
                
                # Write modified content
                Set-Content -Path $file.FullName -Value $content -NoNewline
                Write-Host "  ✓ File converted successfully" -ForegroundColor Green
            }
            
            $converted++
        }
        else
        {
            Write-Host "  ⊝ No function loading found - skipped" -ForegroundColor Gray
            $skipped++
        }
    }
    catch
    {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Conversion Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Total files processed: $($testFiles.Count)" -ForegroundColor White
Write-Host "  Successfully converted: $converted" -ForegroundColor Green
Write-Host "  Skipped (no changes): $skipped" -ForegroundColor Gray
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })

if ($WhatIf)
{
    Write-Host "`n  [WHATIF] No files were modified" -ForegroundColor Yellow
}

Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

exit $(if ($failed -gt 0) { 1 } else { 0 })
```

**2.2 Test Conversion Script on Sample Files**

```powershell
# Test on single file first
.\TestScripts\Convert-TestToHarnessPattern.ps1 -TestPath ".\TestScripts\test-syntax-validation.ps1" -WhatIf

# Review changes
.\TestScripts\Convert-TestToHarnessPattern.ps1 -TestPath ".\TestScripts\test-syntax-validation.ps1"

# Verify converted test still works
.\TestScripts\Test-Runner.ps1 -TestCategory syntax -Verbose
```

---

### Phase 3: Phased Test Conversion (2-3 hours)

**3.1 Pilot Conversion - Syntax Category (10 tests)**

```powershell
# Convert syntax tests
$syntaxTests = Get-ChildItem ".\TestScripts\test-syntax-*.ps1"
foreach ($test in $syntaxTests) {
    .\TestScripts\Convert-TestToHarnessPattern.ps1 -TestPath $test.FullName
}

# Validate
.\TestScripts\Test-Runner.ps1 -TestCategory syntax -Verbose

# Compare with baseline
Compare-Object (Get-Content baseline-syntax.log) (Get-Content current-syntax.log)
```

**Validation Criteria:**
- ✅ All syntax tests pass (same count as baseline)
- ✅ No new errors introduced
- ✅ Execution time equal or faster
- ✅ Output format unchanged

**If Validation Fails:**
- Review first failed test manually
- Check exit code handling
- Verify function availability
- Adjust Test-Runner.ps1 or conversion script
- Re-run conversion on pilot tests

**3.2 Expand - Core Category (20-30 tests)**

```powershell
# Convert core tests
$coreTests = Get-ChildItem ".\TestScripts\test-core-*.ps1"
foreach ($test in $coreTests) {
    .\TestScripts\Convert-TestToHarnessPattern.ps1 -TestPath $test.FullName
}

# Validate
.\TestScripts\Test-Runner.ps1 -TestCategory core -Verbose
```

**3.3 Scale - Unit Category (30-40 tests)**

```powershell
# Convert unit tests
$unitTests = Get-ChildItem ".\TestScripts\test-*-unit.ps1"
foreach ($test in $unitTests) {
    .\TestScripts\Convert-TestToHarnessPattern.ps1 -TestPath $test.FullName
}

# Validate
.\TestScripts\Test-Runner.ps1 -TestCategory unit -Verbose
```

**3.4 Scale - Remaining Categories (120+ tests)**

**Batch Conversion by Category:**
```powershell
$remainingCategories = @('integration', 'comprehensive', 'validation', 'enhanced', 
                          'specialized', 'performance', 'fixes', 'menu', 'autopilot')

foreach ($category in $remainingCategories) {
    Write-Host "`nConverting category: $category" -ForegroundColor Cyan
    
    # Get tests for this category
    $categoryPattern = $TestRegistry[$category].Pattern
    $categoryTests = Get-ChildItem ".\TestScripts\$categoryPattern"
    
    Write-Host "Found $($categoryTests.Count) tests in $category category" -ForegroundColor White
    
    # Convert each test
    foreach ($test in $categoryTests) {
        .\TestScripts\Convert-TestToHarnessPattern.ps1 -TestPath $test.FullName
    }
    
    # Validate category
    Write-Host "Validating $category category..." -ForegroundColor Cyan
    .\TestScripts\Test-Runner.ps1 -TestCategory $category -Verbose
    
    # Pause for review
    Read-Host "Press Enter to continue to next category or Ctrl+C to stop"
}
```

**GOTCHA #3:** Some tests may have custom patterns requiring manual adjustment:
- Tests that spawn child processes
- Tests that modify global environment
- Tests that depend on specific execution context
- **Solution:** Flag these during conversion, handle manually after bulk conversion

---

### Phase 4: Final Validation (30-45 minutes)

**4.1 Run Full Test Suite**

```powershell
# Run all categories
$allCategories = @('syntax', 'core', 'unit', 'integration', 'comprehensive', 
                   'validation', 'enhanced', 'specialized', 'performance', 
                   'fixes', 'menu', 'autopilot')

$results = @{}
foreach ($category in $allCategories) {
    Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Testing Category: $category" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $result = .\TestScripts\Test-Runner.ps1 -TestCategory $category -Verbose
    $results[$category] = @{
        Output = $result
        ExitCode = $LASTEXITCODE
        Timestamp = Get-Date
    }
}

# Generate comprehensive report
$report = @"
# Test Harness System-Wide Implementation - Validation Report
Generated: $(Get-Date)

## Summary
Total Categories Tested: $($results.Count)

## Category Results
"@

foreach ($category in $allCategories) {
    $categoryResult = $results[$category]
    $status = if ($categoryResult.ExitCode -eq 0) { "✓ PASSED" } else { "✗ FAILED" }
    $report += "`n- **$category**: $status"
}

$report | Out-File ".\TestScripts\validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
```

**4.2 Performance Comparison**

```powershell
# Measure execution time for each category
$performanceResults = @{}

foreach ($category in @('syntax', 'core', 'unit')) {
    $duration = Measure-Command {
        .\TestScripts\Test-Runner.ps1 -TestCategory $category | Out-Null
    }
    
    $performanceResults[$category] = $duration
    Write-Host "$category: $($duration.TotalSeconds)s" -ForegroundColor Cyan
}

# Compare with baseline (from Phase 0)
# Expected improvement: ~8-10 minutes faster for full suite
```

**Expected Performance Improvements:**
- **Syntax category:** 5s → 3s (40% faster)
- **Core category:** 60s → 45s (25% faster)
- **Unit category:** 240s → 210s (12% faster)
- **Full suite:** 45m → 36m (20% faster, 9 minutes saved)

---

## Edge Cases & Gotchas

### Edge Case 1: Tests That Spawn Child Processes

**Scenario:** Some tests spawn child PowerShell processes for isolation testing
**Example:** Tests that verify script execution in different contexts

**Problem:** Child processes won't have access to Test-Runner's loaded functions

**Solution:**
```powershell
# In test file, explicitly pass function definitions to child process
$functionToTest = (Get-Command Get-GraphAccessToken).Definition
& pwsh -Command "
    function Get-GraphAccessToken { $functionToTest }
    # Now test the function
"
```

**Affected Tests:** Search for tests using `& pwsh`, `Start-Process`, or `Invoke-Command`
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "& pwsh|Start-Process|Invoke-Command"
```

---

### Edge Case 2: Tests That Modify Global State

**Scenario:** Tests that change environment variables, working directory, or PSModulePath
**Example:** Tests for deployment or configuration changes

**Problem:** State changes persist to subsequent tests in shared process

**Solution:**
```powershell
# At start of test: Capture original state
$originalLocation = Get-Location
$originalEnv = [Environment]::GetEnvironmentVariables()

# Test logic that modifies state
Set-Location "C:\Temp"
$env:CUSTOM_VAR = "test"

# At end of test: Restore original state (CRITICAL)
Set-Location $originalLocation
foreach ($key in $originalEnv.Keys) {
    [Environment]::SetEnvironmentVariable($key, $originalEnv[$key])
}

exit 0
```

**Affected Tests:** Search for tests using `Set-Location`, `$env:`, or `[Environment]::`
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "Set-Location|\$env:|Environment]::"
```

---

### Edge Case 3: Tests That Rely on $LASTEXITCODE from External Commands

**Scenario:** Tests that execute external commands and check exit codes
**Example:** Tests calling git, az cli, or other command-line tools

**Problem:** $LASTEXITCODE from external commands may interfere with test exit code

**Solution:**
```powershell
# Execute external command
& git status
$gitExitCode = $LASTEXITCODE  # Capture immediately

# Do test validation
if ($gitExitCode -ne 0) {
    Write-Host "Git command failed"
    exit 1  # Set test failure explicitly
}

# Success path
exit 0  # Set test success explicitly
```

**Rule:** Always explicitly call `exit 0` or `exit 1` at end of test file

**Affected Tests:** Search for tests using `$LASTEXITCODE`
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "LASTEXITCODE"
```

---

### Edge Case 4: Tests That Use Mock Functions

**Scenario:** Tests that mock application functions to control behavior
**Example:** Mocking `Get-EntraDirectoryObject` to return test data

**Problem:** Mocks created in one test may affect subsequent tests

**Solution:**
```powershell
# At start of test: Save original function
if (Get-Command Get-EntraDirectoryObject -ErrorAction SilentlyContinue) {
    $originalFunction = Get-Command Get-EntraDirectoryObject
}

# Create mock
function Get-EntraDirectoryObject {
    return @{ id = "test-id"; displayName = "Test User" }
}

# Test logic using mock

# At end of test: Restore original function (CRITICAL)
if ($originalFunction) {
    # Restore from saved definition
    Invoke-Expression "function Get-EntraDirectoryObject { $($originalFunction.Definition) }"
} else {
    # Remove mock if no original existed
    Remove-Item Function:\Get-EntraDirectoryObject -ErrorAction SilentlyContinue
}

exit 0
```

**Alternative:** Use Test-Runner cleanup logic (added in Phase 1.4)

**Affected Tests:** Search for tests defining functions
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "^function\s+\w+-\w+"
```

---

### Edge Case 5: Tests That Require Specific Module Versions

**Scenario:** Tests that verify behavior with specific PowerShell module versions
**Example:** Tests for Microsoft.Graph module version compatibility

**Problem:** Module version changes persist across tests in shared process

**Solution:**
```powershell
# At start of test: Save imported modules
$importedModules = Get-Module

# Test logic that imports specific module version
Import-Module Microsoft.Graph -RequiredVersion 2.0.0

# Test logic

# At end of test: Restore original module state
$currentModules = Get-Module
foreach ($module in $currentModules) {
    if ($module -notin $importedModules) {
        Remove-Module $module.Name -Force
    }
}

exit 0
```

**Affected Tests:** Search for tests using `Import-Module` or `Remove-Module`
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "Import-Module|Remove-Module"
```

---

### Gotcha #1: PowerShell 5.1 Exit Behavior

**Issue:** In PowerShell 5.1, `exit` in dot-sourced script exits entire PowerShell session

**Impact:** Tests calling `exit` will terminate Test-Runner.ps1 entirely

**Solution:** Modify test pattern to return status instead of calling exit
```powershell
# BEFORE (causes session exit)
if ($testFailed) {
    exit 1
}
exit 0

# AFTER (returns status to Test-Runner)
$testStatus = 0
if ($testFailed) {
    $testStatus = 1
}
return $testStatus
```

**Test-Runner.ps1 Adjustment:** Capture return value instead of $LASTEXITCODE
```powershell
# BEFORE
$output = . $testPath 2>&1
$exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 0 }

# AFTER
$output = . $testPath 2>&1
$exitCode = if ($output -match '^\d+$' -and $output -le 1) { [int]$output } else { 0 }
```

**CRITICAL:** This is a breaking difference between isolated and in-process execution
**Testing Required:** Validate exit code handling extensively in Phase 3.1

---

### Gotcha #2: Function Name Collisions

**Issue:** Test helper functions may have same name as application functions

**Impact:** Test helper functions override application functions in shared scope

**Solution:** Prefix test helper functions with `Test-`
```powershell
# BEFORE (collides with application function)
function Format-Result {
    param($value)
    return "Result: $value"
}

# AFTER (no collision)
function Test-FormatResult {
    param($value)
    return "Result: $value"
}
```

**Affected Tests:** Search for function definitions in tests
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "^function\s+\w+-\w+" | 
    Where-Object { $_.Line -notmatch "^function Test-" }
```

---

### Gotcha #3: Variable Scope Pollution

**Issue:** Variables created in tests persist to subsequent tests

**Impact:** Test B may see variables from Test A, causing unexpected behavior

**Solution 1:** Use `Remove-Variable` cleanup (handled by Phase 1.4 cleanup logic)

**Solution 2:** Use unique variable names per test
```powershell
# Instead of generic names
$result = Invoke-SomeFunction

# Use test-specific names
$testSyntaxResult = Invoke-SomeFunction
```

**Affected Variables:** Search for common variable names
```powershell
Get-ChildItem ".\TestScripts\test-*.ps1" | Select-String "\$result|\$output|\$data"
```

---

### Gotcha #4: Working Directory Changes

**Issue:** Tests that change working directory affect subsequent tests

**Impact:** Relative paths in later tests may resolve incorrectly

**Solution:** Test-Runner should reset working directory between tests
```powershell
# In Test-Runner.ps1, after each test execution
Set-Location $PSScriptRoot  # Reset to Test-Runner directory
```

**Already Handled:** Phase 1.4 cleanup logic includes PSDrive cleanup

---

### Gotcha #5: Console Output Buffering

**Issue:** In-process execution may buffer output differently than isolated sessions

**Impact:** Test output capture may be incomplete or out-of-order

**Solution:** Force output flushing in tests
```powershell
# After critical output
Write-Host "Important test result"
[Console]::Out.Flush()
```

**Monitoring:** Check if test output in new system matches old system format

---

### Gotcha #6: Error Action Preference Inheritance

**Issue:** Test-Runner's $ErrorActionPreference propagates to tests

**Impact:** Tests may fail differently than in isolated sessions

**Solution:** Tests should explicitly set their error action preference
```powershell
# At start of test
$ErrorActionPreference = 'Stop'  # or 'Continue', as needed

# Test logic

# Restore is not needed (cleanup between tests handles this)
```

**Recommendation:** Document this in test template

---

### Gotcha #7: Performance Tests May Be Affected

**Issue:** Shared process state may affect performance test results

**Impact:** Memory, cache, or JIT compilation from previous tests affects timing

**Solution:** Performance tests should warm up before timing
```powershell
# Warm up - run once without timing
Invoke-FunctionToTest

# Actual timed test
$duration = Measure-Command {
    Invoke-FunctionToTest
}
```

**Alternative:** Keep performance tests in isolated sessions
```powershell
# In Test-Runner.ps1, add exception for performance category
if ($CategoryName -eq 'performance') {
    # Use old isolated session execution for performance tests
    $output = & pwsh @testArgs 2>&1
}
```

---

## Testing & Validation Strategy

### Validation Checklist

**Phase 1 Validation (Test-Runner.ps1 Modifications):**
- [ ] Test-Runner.ps1 loads all 185 functions successfully
- [ ] All critical functions verified present
- [ ] Function loading completes in < 5 seconds
- [ ] No errors in function loading output
- [ ] Test execution loop still runs
- [ ] Results summary still generates correctly

**Phase 2 Validation (Conversion Script):**
- [ ] Script correctly identifies function loading patterns
- [ ] Script removes only function loading code
- [ ] Script preserves test logic
- [ ] Script handles edge cases (no loading code, multiple patterns)
- [ ] Backup files created correctly
- [ ] WhatIf mode works without modifying files

**Phase 3 Validation (Per Category):**
- [ ] All tests in category pass (same count as baseline)
- [ ] No new errors introduced
- [ ] Output format matches baseline
- [ ] Execution time equal or faster
- [ ] No state pollution observed between tests

**Phase 4 Validation (Full Suite):**
- [ ] All 13 categories pass
- [ ] Total test count matches baseline (202 tests)
- [ ] Pass rate matches or exceeds baseline
- [ ] Full suite execution 8-10 minutes faster
- [ ] No regression in test coverage
- [ ] CI/CD integration works (if applicable)

### Regression Testing

**Create Regression Test Suite:**
```powershell
# TestScripts\test-harness-regression.ps1
# Validates test harness infrastructure itself

# Test 1: Verify function loading
$functionsLoaded = Get-Command -Name Write-Log, Get-GraphAccessToken, Show-Menu -ErrorAction SilentlyContinue
if ($functionsLoaded.Count -lt 3) {
    Write-Host "FAIL: Not all critical functions loaded"
    exit 1
}

# Test 2: Verify state isolation
$testVar = "initial"
. .\TestScripts\test-state-pollution-test.ps1
if ($testVar -ne "initial") {
    Write-Host "FAIL: Variable state not isolated between tests"
    exit 1
}

# Test 3: Verify exit code handling
$testExitCode = . .\TestScripts\test-exit-code-test.ps1
if ($testExitCode -ne 0) {
    Write-Host "FAIL: Exit code not captured correctly"
    exit 1
}

Write-Host "PASS: All harness regression tests passed"
exit 0
```

---

## Rollback Strategy

### Rollback Triggers
- More than 5% test failure increase
- Critical tests failing that passed in baseline
- Performance regression > 10%
- Unrecoverable errors in Test-Runner.ps1

### Rollback Steps

**Option 1: Rollback Individual Test**
```powershell
# Restore from backup
Copy-Item ".\TestScripts\backup-*\test-example.ps1.bak" ".\TestScripts\test-example.ps1" -Force
```

**Option 2: Rollback Entire Category**
```powershell
# Restore all tests in category from backup
$backupDir = Get-ChildItem ".\TestScripts\backup-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$categoryTests = Get-ChildItem "$backupDir\test-core-*.ps1.bak"
foreach ($backup in $categoryTests) {
    $originalName = $backup.Name -replace '\.bak$', ''
    Copy-Item $backup.FullName ".\TestScripts\$originalName" -Force
}
```

**Option 3: Rollback Test-Runner.ps1**
```powershell
# Restore Test-Runner.ps1 from backup
Copy-Item ".\TestScripts\backup-*\Test-Runner.ps1.bak" ".\TestScripts\Test-Runner.ps1" -Force
```

**Option 4: Rollback Entire Implementation**
```powershell
# Reset to pre-implementation state
git checkout 324migration  # or master
git reset --hard HEAD~1    # if changes committed
# OR
git stash                  # if changes not committed
```

---

## Success Metrics

### Quantitative Metrics

**Code Reduction:**
- **Target:** Remove 4,000+ lines of function loading code
- **Measurement:** `(Get-Content .\TestScripts\test-*.ps1 | Measure-Object -Line).Lines` before vs after

**Performance Improvement:**
- **Target:** 8-10 minutes faster full test suite execution
- **Measurement:** `Measure-Command { .\TestScripts\Test-Runner.ps1 -TestCategory all }` before vs after

**Function Loading Overhead:**
- **Target:** 185 function loads × 202 tests = 37,370 loads → 185 loads (99.5% reduction)
- **Measurement:** Count of function loading operations before vs after

**Test Pass Rate:**
- **Target:** Maintain or exceed baseline pass rate (currently ~95%)
- **Measurement:** (PassedTests / TotalTests) × 100 before vs after

### Qualitative Metrics

**Developer Experience:**
- **Target:** Simpler test creation (no loading boilerplate required)
- **Measurement:** Survey test contributors, count lines in test template

**Maintainability:**
- **Target:** Single source of truth for function loading
- **Measurement:** Count of locations requiring updates when function paths change (202 → 1)

**Debugging:**
- **Target:** Easier troubleshooting with direct execution
- **Measurement:** Time to diagnose test failures before vs after

---

## Post-Implementation Tasks

### Documentation Updates

**1. Update TEST_HARNESS_GUIDE.md**
- Add section on Test-Runner.ps1 integration
- Update usage examples to reference Test-Runner
- Document exit code handling requirements
- Add troubleshooting section for new execution model

**2. Update CONTRIBUTING.md**
- Update test creation guidelines
- Remove function loading instructions
- Add test template without loading boilerplate
- Document state isolation requirements

**3. Create MIGRATION_GUIDE.md**
- Document differences between old and new test patterns
- Provide conversion examples
- List edge cases and solutions
- Include rollback procedures

**4. Update README.md**
- Update test execution instructions
- Update performance benchmarks
- Add note about test harness architecture

### CI/CD Integration

**If Using GitHub Actions:**
```yaml
# .github/workflows/test.yml
- name: Run Test Suite
  run: |
    # New execution pattern (faster)
    .\TestScripts\Test-Runner.ps1 -TestCategory all -Verbose
    
    # Old execution pattern (for comparison, remove after validation)
    # foreach ($test in Get-ChildItem .\TestScripts\test-*.ps1) { & pwsh $test.FullName }
```

**If Using Azure DevOps:**
```yaml
# azure-pipelines.yml
- task: PowerShell@2
  displayName: 'Run Test Suite'
  inputs:
    targetType: 'inline'
    script: |
      .\TestScripts\Test-Runner.ps1 -TestCategory all -Verbose
```

### Monitoring & Alerts

**Track Key Metrics:**
```powershell
# Add to Test-Runner.ps1 summary output
Write-Host "`nPerformance Metrics:" -ForegroundColor Cyan
Write-Host "  Function loading time: $($functionLoadDuration.TotalSeconds)s" -ForegroundColor White
Write-Host "  Total execution time: $($totalDuration.TotalSeconds)s" -ForegroundColor White
Write-Host "  Average test time: $($averageTestTime)s" -ForegroundColor White
Write-Host "  Tests per minute: $($testsPerMinute)" -ForegroundColor White
```

---

## Implementation Timeline

**Total Estimated Time:** 4-6 hours (can be split across multiple sessions)

| Phase | Task | Duration | Can Pause After |
|-------|------|----------|-----------------|
| 0 | Preparation & Backup | 15 min | ✓ Yes |
| 1 | Modify Test-Runner.ps1 | 45-60 min | ✓ Yes |
| 1.5 | Validate Test-Runner changes | 15 min | ✓ Yes |
| 2 | Create Conversion Script | 60-75 min | ✓ Yes |
| 3.1 | Pilot Conversion (syntax) | 20 min | ✓ Yes |
| 3.2 | Expand (core) | 30 min | ✓ Yes |
| 3.3 | Expand (unit) | 30 min | ✓ Yes |
| 3.4 | Scale (remaining) | 60-90 min | ✓ Yes (per category) |
| 4 | Final Validation | 30-45 min | ✓ Yes |
| 5 | Documentation Updates | 30 min | ✓ Yes |

**Recommended Schedule:**

**Session 1 (90 minutes):**
- Phase 0: Preparation
- Phase 1: Modify Test-Runner.ps1
- Phase 1.5: Validate changes
- Commit progress

**Session 2 (90 minutes):**
- Phase 2: Create Conversion Script
- Phase 3.1: Pilot conversion
- Validate pilot results
- Commit progress

**Session 3 (2 hours):**
- Phase 3.2-3.3: Expand to core and unit
- Phase 3.4: Start scaling to remaining categories
- Commit progress after each category

**Session 4 (90 minutes):**
- Phase 3.4: Complete remaining categories
- Phase 4: Final validation
- Phase 5: Documentation updates
- Final commit

---

## Conclusion

This implementation plan provides a comprehensive, step-by-step approach to modernizing the test infrastructure with the test harness pattern. The phased rollout strategy minimizes risk, and the detailed edge case documentation ensures smooth handling of special scenarios.

**Key Success Factors:**
1. **Thorough validation at each phase** - Don't proceed if phase fails
2. **Maintain backups** - Enable quick rollback if needed
3. **Document anomalies** - Track unexpected behavior for future reference
4. **Incremental commits** - Preserve progress and enable partial rollback
5. **Monitor performance** - Verify expected improvements are realized

**Expected Outcomes:**
- ✅ 202 tests running in shared function scope
- ✅ 8-10 minutes faster test execution
- ✅ 4,000+ lines of code removed
- ✅ Simplified test maintenance
- ✅ Consistent test patterns across codebase
- ✅ Maintained or improved test reliability

---

**Document Status:** Ready for Implementation  
**Next Step:** Begin Phase 0 - Preparation & Backup  
**Questions/Issues:** Document in implementation log for review
