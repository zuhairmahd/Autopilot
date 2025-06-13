# Get-CallingContext Quick Reference

## Function Syntax
```powershell
Get-CallingContext [-Menu <hashtable>] [-PreferredContext <string>]
```

## Quick Examples

### Basic Usage
```powershell
# Auto-detect context
$context = Get-CallingContext

# Force specific context
$context = Get-CallingContext -PreferredContext 'Action'

# With menu information
$context = Get-CallingContext -Menu $myMenu
```

## Context Patterns Reference

| Function Pattern | Context Returned | Example |
|-----------------|------------------|---------|
| `Get-*` | `Getter_[FunctionName]` | `Getter_Get-UserDevices` |
| `Set-*` | `Setter_[FunctionName]` | `Setter_Set-Configuration` |
| `New-*` | `Creator_[FunctionName]` | `Creator_New-AutopilotDevice` |
| `Remove-*`, `Delete-*` | `Remover_[FunctionName]` | `Remover_Remove-Device` |
| `Test-*`, `Validate-*` | `Validator_[FunctionName]` | `Validator_Test-Compliance` |
| `Connect-*`, `Disconnect-*` | `Connection_[FunctionName]` | `Connection_Connect-Graph` |
| `*Menu*` | `MenuFunction_[FunctionName]` | `MenuFunction_ShowMainMenu` |
| `*Action*`, `*Execute*` | `ActionFunction_[FunctionName]` | `ActionFunction_ExecuteReport` |
| Other functions | `Custom_[File]_[Function]` | `Custom_Main_ProcessData` |

## Standard Contexts

| Context | When Returned |
|---------|---------------|
| `'Direct'` | Called directly from main script |
| `'Action'` | Called from action execution functions |
| `'Submenu'` | Called from submenu navigation |
| `'Navigation'` | Called from navigation functions |

## Common Usage Patterns

### 1. Context-Based Decision Making
```powershell
$context = Get-CallingContext
switch -Regex ($context) {
    '^Getter_.*' { # Handle data retrieval }
    '^Setter_.*' { # Handle data modification }
    '^Action.*'  { # Handle user actions }
    '^Menu.*'    { # Handle menu operations }
    default      { # Handle standard operations }
}
```

### 2. Enhanced Logging
```powershell
$context = Get-CallingContext
Write-Verbose "Operation called from: $context"
```

### 3. Menu Integration
```powershell
function ShowMenu() {
    param([hashtable]$Menu)
    $context = Get-CallingContext -Menu $Menu
    # Use context for stack management decisions
}
```

### 4. Backward Compatibility
```powershell
# Old code still works unchanged
$context = Get-CallingContext
if ($context -eq 'Direct') {
    # Original logic
}
```

## Pro Tips

- ✅ Use `PreferredContext` for backward compatibility
- ✅ Pass `Menu` parameter for enhanced debugging
- ✅ Handle `Unknown` context gracefully
- ✅ Use regex patterns for flexible context matching
- ⚠️ Context strings are case-sensitive
- ⚠️ Custom contexts include file and function names
