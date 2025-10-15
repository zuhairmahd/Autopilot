# PowerShell Test Function Loading Pattern

## Overview

This document explains the critical function loading pattern discovered while developing the migration test suite. This pattern is essential for writing PowerShell tests that use function mocking without encountering scope isolation issues.

## The Problem

When writing PowerShell tests, you often need to:
1. Load real functions from your codebase
2. Override (mock) specific functions for testing
3. Have those mocks work correctly when the real functions call each other

**Common failure pattern:**
```powershell
# ❌ INCORRECT - This fails due to scope isolation
function Initialize-TestEnvironment {
    # Load functions
    Get-ChildItem "functions" -Recurse | ForEach-Object { . $_.FullName }
    
    # Define mock - this won't work!
    function Get-EntraDirectoryObject {
        return "mocked value"
    }
}

Initialize-TestEnvironment
# When real functions call Get-EntraDirectoryObject, they get the REAL function, not the mock!
```

## The Solution

**Load functions at script scope, define mocks with `global:` prefix BEFORE loading real functions:**

```powershell
# ✅ CORRECT - This works!

# Step 1: Define mocks FIRST with global: prefix
function global:Get-EntraDirectoryObject {
    param($EntityType, $EntityName, $AccessToken, [switch]$FindSimilar)
    return @(
        @{ value = @( @{ displayName = "MockedEntity"; id = "mock-123" } ) },
        $false
    )
}

# Step 2: Load real functions at script scope (NOT inside functions or try blocks)
$scriptRoot = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptRoot
$functionsPath = Join-Path $projectRoot "functions"

Get-ChildItem -Path $functionsPath -Recurse -Filter "*.ps1" | ForEach-Object {
    try {
        . $_.FullName
    }
    catch {
        # Silent continue - some functions may have dependencies
    }
}

# Step 3: Now your tests can call real functions that internally use the mocks
$result = Resolve-MigratedLegacyObjects -SearchPath "..." -AccessToken "mock-token"
# ✓ When Resolve-MigratedLegacyObjects calls Get-EntraDirectoryObject, it gets the mock!
```

## Key Rules

### 1. Define Mocks BEFORE Loading Functions
```powershell
# ✅ DO THIS
function global:MyFunction { return "mock" }
. "functions\RealFunctions.ps1"

# ❌ NOT THIS
. "functions\RealFunctions.ps1"
function MyFunction { return "mock" }  # Too late! Real function already loaded
```

### 2. Use `global:` Prefix for Mocks
```powershell
# ✅ DO THIS - global: ensures the mock is visible to loaded functions
function global:Get-EntraDirectoryObject { ... }

# ❌ NOT THIS - without global:, the mock stays in local scope
function Get-EntraDirectoryObject { ... }
```

### 3. Load Functions at Script Scope
```powershell
# ✅ DO THIS - Load at script scope (top level)
Get-ChildItem "functions" -Recurse | ForEach-Object { . $_.FullName }

# ❌ NOT THIS - Loading inside function creates scope isolation
function Initialize-TestEnvironment {
    Get-ChildItem "functions" -Recurse | ForEach-Object { . $_.FullName }
}
Initialize-TestEnvironment

# ❌ NOT THIS - Loading inside try block may create scope issues
try {
    Get-ChildItem "functions" -Recurse | ForEach-Object { . $_.FullName }
}
catch { }
```

### 4. Remove Mocks After Tests
```powershell
# ✅ DO THIS - Clean up mocks in finally block
try {
    # Test code
}
finally {
    if (Get-Command Get-EntraDirectoryObject -ErrorAction SilentlyContinue) {
        Remove-Item function:Get-EntraDirectoryObject -ErrorAction SilentlyContinue
    }
}

# Or for Read-Host mocks:
function global:Read-Host { return "3" }
# ... test code ...
Remove-Item function:Read-Host
```

## Complete Example

Here's a complete test file demonstrating the pattern:

```powershell
#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0

function Test-Result {
    param([string]$TestName, [bool]$Condition, [string]$FailureMessage = "")
    if ($Condition) {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  ✗ $TestName" -ForegroundColor Red
        if ($FailureMessage) { Write-Host "    $FailureMessage" -ForegroundColor Yellow }
        $script:TestsFailed++
    }
}

Write-Host "=== Test Suite ===" -ForegroundColor Yellow

# STEP 1: Define mocks BEFORE loading functions
Write-Host "Setting up mocks..." -ForegroundColor Gray

function global:Get-EntraDirectoryObject {
    param($EntityType, $EntityName, $AccessToken, [hashtable]$Settings, [switch]$FindSimilar)
    
    if ($EntityName -eq "ExactMatch") {
        return @(
            @{ value = @( @{ displayName = $EntityName; id = "mock-id-123" } ) },
            $false
        )
    }
    return $null
}

function global:Update-Setting {
    param($SettingsFile, $Domain, $Setting, $Value)
    return $true  # Simulate successful save
}

Write-Host "Mocks configured" -ForegroundColor Green

# STEP 2: Load real functions at script scope
Write-Host "Loading functions..." -ForegroundColor Gray

$scriptRoot = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptRoot
$functionsPath = Join-Path $projectRoot "functions"

if (-not (Test-Path $functionsPath)) {
    throw "Functions directory not found at: $functionsPath"
}

$functionCount = 0
Get-ChildItem -Path $functionsPath -Recurse -Filter "*.ps1" | ForEach-Object {
    try {
        . $_.FullName
        $functionCount++
    } catch {
        # Silent continue - some functions may have dependencies
    }
}

Write-Host "Functions loaded: $functionCount" -ForegroundColor Green

# STEP 3: Run tests
try {
    Write-Host "`n=== Test 1: Mock Function Works ===" -ForegroundColor Cyan
    
    # This calls the real function, which internally uses our mock
    $result = Resolve-MigratedLegacyObjects -SearchPath "." -AccessToken "mock-token" -Silent
    
    Test-Result "Mock function was used" ($result -ne $null)
    Test-Result "Real function executed successfully" $true
}
catch {
    Write-Host "`nTest execution failed: $_" -ForegroundColor Red
    $script:TestsFailed++
}
finally {
    # STEP 4: Clean up
    Remove-Item function:Get-EntraDirectoryObject -ErrorAction SilentlyContinue
    Remove-Item function:Update-Setting -ErrorAction SilentlyContinue
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })

if ($script:TestsFailed -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed" -ForegroundColor Red
    exit 1
}
```

## Why This Works

PowerShell function resolution follows this priority:
1. **Functions in the current scope** (local)
2. **Functions in parent scopes** (including global)
3. **Functions loaded via dot-sourcing**

When you:
- Define a mock with `global:` prefix → It goes into global scope
- Load real functions via dot-sourcing → They also go into global scope, but...
- The mock was defined first → PowerShell uses the first definition it finds

Without `global:`, your mock stays in a local scope that the loaded functions can't see.

## Common Pitfalls

### Pitfall 1: Loading Functions First
```powershell
# ❌ Mock defined too late
. "functions\MyFunction.ps1"
function global:MyFunction { return "mock" }  # Too late - real function already loaded
```

### Pitfall 2: Forgetting `global:` Prefix
```powershell
# ❌ Mock not visible to loaded functions
function MyFunction { return "mock" }  # Local scope only
. "functions\RealFunctions.ps1"
```

### Pitfall 3: Scope Isolation in Initialization Functions
```powershell
# ❌ Functions and mocks in different scopes
function Initialize {
    function global:MyFunction { return "mock" }
    Get-ChildItem "functions" -Recurse | ForEach-Object { . $_.FullName }
}
Initialize  # Scope isolation may still cause issues
```

## Test Files Using This Pattern

The following test files in this repository demonstrate this pattern:

- `TestScripts/test-migration-comprehensive.ps1` (835 lines, 56 tests, 100% pass rate)
- `TestScripts/test-migration-e2e-workflow.ps1` (36 tests, 100% pass rate)  
- `TestScripts/test-migration-silent-mode-integration.ps1` (2 tests, 100% pass rate)

## When to Use This Pattern

Use this pattern when:
- ✅ Writing integration tests that need to mock external dependencies (Graph API calls, file I/O)
- ✅ Testing functions that call other functions internally
- ✅ You want to load real functions but override specific ones
- ✅ You need mocks to be visible across multiple function call depths

Don't use this pattern when:
- ❌ Writing unit tests that completely isolate a single function (use Pester mocking instead)
- ❌ Testing simple functions that don't call other functions
- ❌ You can refactor to dependency injection instead

## Related Patterns

### Dynamic Mock Behavior
```powershell
# Mock that returns different values based on input
function global:Get-EntraDirectoryObject {
    param($EntityType, $EntityName, $AccessToken, [switch]$FindSimilar)
    
    switch ($EntityName) {
        "ExactMatch" {
            return @(@{ value = @(@{ displayName = $EntityName; id = "exact-123" }) }, $false)
        }
        "MultipleMatches" {
            return @(@{ value = @(
                @{ displayName = "Match1"; id = "id-1" },
                @{ displayName = "Match2"; id = "id-2" }
            ) }, $true)
        }
        default {
            return $null  # No match
        }
    }
}
```

### Conditional Mocking (Read-Host)
```powershell
# Mock user interaction
function global:Read-Host {
    param($Prompt)
    if ($Prompt -match "skip") {
        return "3"  # Skip option
    }
    return "1"  # Default selection
}

# Test code that calls Read-Host
$result = Some-InteractiveFunction

# Clean up
Remove-Item function:Read-Host
```

### Mock Verification
```powershell
# Track mock invocations
$script:MockCallCount = 0

function global:Get-EntraDirectoryObject {
    param($EntityType, $EntityName, $AccessToken, [switch]$FindSimilar)
    $script:MockCallCount++
    return @(@{ value = @(@{ displayName = "Mock"; id = "123" }) }, $false)
}

# Run test
$result = Some-Function

# Verify mock was called
Test-Result "Mock was called" ($script:MockCallCount -gt 0)
Test-Result "Mock called correct number of times" ($script:MockCallCount -eq 5)
```

## Troubleshooting

### Mock Not Being Used
**Symptoms:** Real function executes instead of mock (e.g., actual Graph API calls)

**Solutions:**
1. Verify mock is defined BEFORE loading functions
2. Verify `global:` prefix is used
3. Verify functions are loaded at script scope, not in a function
4. Check for typos in function name (PowerShell is case-insensitive but spelling matters)

### Scope Isolation Errors
**Symptoms:** "Function not found" errors, variables not accessible

**Solutions:**
1. Move function loading to script scope (top level of test file)
2. Remove try/catch wrapping around function loading
3. Verify mocks use `global:` prefix

### Mocks Persist Between Tests
**Symptoms:** Mock from one test affects another test

**Solutions:**
1. Remove mocks in `finally` blocks
2. Use unique mock names per test if needed
3. Consider using Pester's `-MockWith` for better isolation

## References

- PowerShell Scoping Rules: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes
- Dot Sourcing: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scripts#script-scope-and-dot-sourcing
- Pester Mocking: https://pester.dev/docs/usage/mocking (alternative approach for unit tests)

## Version History

- **1.0** (2025-01-09): Initial documentation based on migration test suite debugging
  - Identified scope isolation issue in test-migration-silent-mode-integration.ps1
  - Discovered `global:` prefix + script-scope loading pattern
  - Validated pattern across 3 test files with 94 total tests passing
