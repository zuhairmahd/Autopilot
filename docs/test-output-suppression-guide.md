# Test Output Suppression Guide

## Overview
This guide explains how to suppress console output during tests to prevent confusing "pseudo-prompts" - Write-Host messages that look like user prompts but are immediately answered by mocked Read-Host functions.

## Problem Statement

When testing interactive functions that use `Write-Host` to display menus and `Read-Host` to get user input, even with a mocked `Read-Host` that returns immediately, the `Write-Host` messages still display on the console. This creates confusing output that looks like the test is waiting for user input when it's actually not.

### Example Problem

```powershell
# Function being tested shows a menu
Write-Host "Multiple options found:"
Write-Host "  1. Option A"
Write-Host "  2. Option B"
$choice = Read-Host "Select option (1-2)"  # Mocked to return "0" immediately

# During test execution, the menu is displayed even though
# Read-Host returns immediately without blocking
```

## Solution: Temporary Write-Host Suppression

The solution is to temporarily override `Write-Host` with a no-op function during the execution of tests that check for interactive behavior.

### Implementation Pattern

```powershell
# Test that verifies Read-Host is called (prompting behavior)
Write-Host "`n=== Test: Function Prompts for Multiple Matches ===" -ForegroundColor Cyan

# 1. Mock Read-Host to track if it's called
function global:Read-Host
{ 
    param([string]$Prompt)
    $script:Prompted = $true
    return "0"  # Return value to skip/cancel
}

# 2. Mock Write-Host to suppress console output
function global:Write-Host
{
    param([string]$Object, [ConsoleColor]$ForegroundColor)
    # Suppress all Write-Host output during function execution
}

# 3. Execute the function being tested
$script:Prompted = $false
try
{
    $result = MyInteractiveFunction -Name "TestInput" -Silent
}
catch
{
    # Silent catch - errors handled elsewhere if needed
}

# 4. Restore Write-Host for test reporting
Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue

# 5. Verify the behavior
$prompted = $script:Prompted
Test-Result "Function prompts when expected" $prompted
```

## Real-World Example: test-migration-silent-mode-integration.ps1

### Before (Confusing Output)
```powershell
# Test 4: Silent Mode - Multiple Match Still Prompts (Profile)
function global:Read-Host
{ 
    param([string]$Prompt)
    Write-Host "  [DEBUG] Read-Host was called with prompt: $Prompt" -ForegroundColor Magenta
    $script:Prompted = $true
    return "0"
}

$result = Resolve-SingleAutopilotProfileInteractive -ProfileName "Multiple-Match" -AccessToken "dummy" -Silent

# Console output during test:
#   Multiple Autopilot profiles found matching 'Multiple-Match':
#     1. Multiple-Match-1 (ID: id-1)
#     2. Multiple-Match-2 (ID: id-2)
#     0. Skip this profile
#   [DEBUG] Read-Host was called with prompt: Select profile (0-2)
```

### After (Clean Output)
```powershell
# Test 4: Silent Mode - Multiple Match Still Prompts (Profile)
function global:Read-Host
{ 
    param([string]$Prompt)
    $script:Prompted = $true
    return "0"
}

# Suppress Write-Host during test execution
function global:Write-Host
{
    param([string]$Object, [ConsoleColor]$ForegroundColor)
    # Silent suppression
}

$result = Resolve-SingleAutopilotProfileInteractive -ProfileName "Multiple-Match" -AccessToken "dummy" -Silent

# Restore Write-Host
Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue

# Console output during test:
#   VERBOSE: [Resolve-SingleAutopilotProfileInteractive] Searching for Autopilot profile: 'Multiple-Match' (Silent mode)
#   [PASS] Profile: Silent mode does NOT auto-accept multiple matches
```

## Best Practices

### 1. **Scope the Suppression Narrowly**
Only suppress Write-Host for the specific function calls that need it, not for the entire test file.

```powershell
# ✅ Good - Scoped suppression
function global:Write-Host { param($Object, $ForegroundColor) }
$result = InteractiveFunction -Input "test"
Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue

# ❌ Bad - Global suppression
function global:Write-Host { param($Object, $ForegroundColor) }
# Run entire test suite
# Write-Host never restored
```

### 2. **Always Restore Write-Host**
Use `Remove-Item Function:\Write-Host` to restore the original behavior after the test.

```powershell
# Suppress
function global:Write-Host { param($Object, $ForegroundColor) }

# Test execution
$result = InteractiveFunction -Input "test"

# Restore (CRITICAL!)
Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue
```

### 3. **Use Error Handling**
Wrap in try/finally to ensure Write-Host is restored even if the test fails.

```powershell
function global:Write-Host { param($Object, $ForegroundColor) }
try
{
    $result = InteractiveFunction -Input "test"
}
finally
{
    Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue
}
```

### 4. **Document the Suppression**
Add comments explaining why Write-Host is being suppressed.

```powershell
# Mock Write-Host to suppress menu display during test
# (The function shows a menu via Write-Host before calling Read-Host,
#  but we only need to verify Read-Host is called, not see the menu)
function global:Write-Host
{
    param([string]$Object, [ConsoleColor]$ForegroundColor)
}
```

## Alternative Approaches

### 1. Redirect Output to Null
Less elegant but works for simple cases:

```powershell
$result = InteractiveFunction -Input "test" *>&1 | Out-Null
# Problem: Loses access to return value
```

### 2. Capture Output
Use output redirection to capture and inspect:

```powershell
$output = InteractiveFunction -Input "test" *>&1
# Can inspect $output if needed
```

### 3. Add -Quiet Parameter to Functions
Best long-term solution - add a parameter to functions:

```powershell
function MyInteractiveFunction
{
    param(
        [switch]$Silent,
        [switch]$Quiet  # Suppress all console output
    )
    
    if (-not $Quiet)
    {
        Write-Host "Displaying menu..."
    }
}
```

## When NOT to Use Write-Host Suppression

1. **When testing Write-Host output itself**: If your test validates what's written to the console, you need to see the output
2. **Debugging test failures**: Comment out the suppression temporarily to see what the function is doing
3. **Integration tests**: Tests that validate the complete user experience should show all output
4. **When Verbose output is sufficient**: If only verbose messages are shown, don't suppress Write-Host

## Relationship to -testMode

The Write-Host suppression technique is **complementary** to main.ps1's `-testMode` switch:

- **`-testMode`**: Prevents main.ps1 from prompting for passwords, running wizards, showing menus, etc.
- **Write-Host suppression**: Prevents individual function tests from displaying menu text during mock interactions

Use `-testMode` when:
- Testing the main.ps1 application end-to-end
- Verifying startup performance
- Testing configuration loading

Use Write-Host suppression when:
- Testing individual interactive functions in isolation
- Verifying Read-Host is called (prompt detection)
- Cleaning up test output for readability

## Summary

| Scenario | Solution | Example |
|----------|----------|---------|
| Main.ps1 prompts for password | Use `-testMode` | `.\main.ps1 -testMode` |
| Main.ps1 shows menu | Use `-testMode` | `.\main.ps1 -testMode` |
| Function test shows menu text | Suppress Write-Host | See implementation pattern above |
| Need to verify Read-Host called | Mock Read-Host + Suppress Write-Host | See real-world example above |
| Debugging test | Comment out Write-Host suppression | `# function global:Write-Host...` |

## Related Files

- `TestScripts/test-migration-silent-mode-integration.ps1` - Uses Write-Host suppression
- `main.ps1` - Uses `-testMode` switch
- `docs/testmode-implementation-summary.md` - Details on -testMode

## References

- PowerShell function overriding: `function global:FunctionName`
- Function removal: `Remove-Item Function:\FunctionName`
- Mock patterns: See TEST_HARNESS_GUIDE.md
