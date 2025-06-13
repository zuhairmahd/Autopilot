# Get-CallingContext Function - Usage Guide and Examples

## Overview
The `Get-CallingContext` function is an enhanced context detection utility that analyzes the PowerShell call stack to determine the calling context. It provides intelligent context identification for menu navigation systems and can generate unique contexts based on calling function patterns.

## Function Signature
```powershell
function Get-CallingContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null,
        [Parameter(Mandatory = $false)]
        [string]$PreferredContext = $null
    )
}
```

## Parameters

### `$Menu` (Optional)
- **Type**: `[hashtable]`
- **Purpose**: Pass the current menu object for enhanced context analysis
- **Usage**: Provides additional context information for debugging and decision-making

### `$PreferredContext` (Optional)
- **Type**: `[string]`
- **Purpose**: Override automatic detection with a specific context
- **Valid Values**: `'Direct'`, `'Action'`, `'Submenu'`, `'Navigation'`
- **Usage**: Ensures backward compatibility and allows explicit context setting

## Basic Usage Examples

### 1. Simple Context Detection (Backward Compatible)
```powershell
# Basic call - maintains backward compatibility
$context = Get-CallingContext
Write-Host "Current context: $context"
# Output: "Direct" (when called from main script)
```

### 2. Using Preferred Context Override
```powershell
# Force a specific context
$context = Get-CallingContext -PreferredContext 'Action'
Write-Host "Forced context: $context"
# Output: "Action"
```

### 3. Enhanced Context with Menu Information
```powershell
# Create a menu object
$mainMenu = @{
    Title = "Main Menu"
    Description = "Application main menu"
    Items = @()
}

# Get context with menu information
$context = Get-CallingContext -Menu $mainMenu
Write-Host "Context with menu: $context"
# Output varies based on calling function
```

## Pattern-Based Context Examples

### 4. Get- Function Patterns
```powershell
function Get-UserDevices() {
    $context = Get-CallingContext
    Write-Host "Context from Get function: $context"
    # Output: "Getter_Get-UserDevices"
}

function Get-DeviceInfo() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Getter_Get-DeviceInfo"
}

# Call the functions
Get-UserDevices
Get-DeviceInfo
```

### 5. Set- Function Patterns
```powershell
function Set-UserConfiguration() {
    $context = Get-CallingContext
    Write-Host "Context from Set function: $context"
    # Output: "Setter_Set-UserConfiguration"
}

function Set-DeviceSettings() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Setter_Set-DeviceSettings"
}

Set-UserConfiguration
Set-DeviceSettings
```

### 6. New-/Create Function Patterns
```powershell
function New-AutopilotDevice() {
    $context = Get-CallingContext
    Write-Host "Context from New function: $context"
    # Output: "Creator_New-AutopilotDevice"
}

function New-UserAccount() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Creator_New-UserAccount"
}

New-AutopilotDevice
New-UserAccount
```

### 7. Remove-/Delete Function Patterns
```powershell
function Remove-UserDevice() {
    $context = Get-CallingContext
    Write-Host "Context from Remove function: $context"
    # Output: "Remover_Remove-UserDevice"
}

function Delete-TempFiles() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Remover_Delete-TempFiles"
}

Remove-UserDevice
Delete-TempFiles
```

### 8. Test-/Validate Function Patterns
```powershell
function Test-ConnectivityStatus() {
    $context = Get-CallingContext
    Write-Host "Context from Test function: $context"
    # Output: "Validator_Test-ConnectivityStatus"
}

function Validate-UserPermissions() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Validator_Validate-UserPermissions"
}

Test-ConnectivityStatus
Validate-UserPermissions
```

### 9. Connect-/Disconnect Function Patterns
```powershell
function Connect-ToTenant() {
    $context = Get-CallingContext
    Write-Host "Context from Connect function: $context"
    # Output: "Connection_Connect-ToTenant"
}

function Disconnect-FromService() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Connection_Disconnect-FromService"
}

Connect-ToTenant
Disconnect-FromService
```

### 10. Menu-Related Function Patterns
```powershell
function ShowUserMenu() {
    $context = Get-CallingContext
    Write-Host "Context from Menu function: $context"
    # Output: "MenuFunction_ShowUserMenu"
}

function DisplayMainMenu() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "MenuFunction_DisplayMainMenu"
}

ShowUserMenu
DisplayMainMenu
```

### 11. Action/Execute Function Patterns
```powershell
function ExecuteDeviceReport() {
    $context = Get-CallingContext
    Write-Host "Context from Execute function: $context"
    # Output: "ActionFunction_ExecuteDeviceReport"
}

function ProcessUserAction() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "ActionFunction_ProcessUserAction"
}

ExecuteDeviceReport
ProcessUserAction
```

### 12. Custom Function Patterns
```powershell
function CustomBusinessLogic() {
    $context = Get-CallingContext
    Write-Host "Context from Custom function: $context"
    # Output: "Custom_MenuFunctions_CustomBusinessLogic" 
    # (assumes called from MenuFunctions.ps1 file)
}

function SpecialProcessing() {
    $context = Get-CallingContext
    Write-Host "Context: $context"
    # Output: "Custom_[FileName]_SpecialProcessing"
}

CustomBusinessLogic
SpecialProcessing
```

## Advanced Usage Scenarios

### 13. Menu Navigation Context
```powershell
# Inside ShowMenu function
function ShowMenu() {
    param([hashtable]$Menu)
    
    # Auto-detect context with menu information
    $context = Get-CallingContext -Menu $Menu
    
    switch ($context) {
        'Navigation' {
            Write-Host "Called during navigation operation"
        }
        'Action' {
            Write-Host "Called after action execution"
        }
        'Submenu' {
            Write-Host "Called for submenu display"
        }
        'Direct' {
            Write-Host "Called directly from main script"
        }
        default {
            Write-Host "Custom context detected: $context"
        }
    }
}
```

### 14. Conditional Logic Based on Context
```powershell
function SmartMenuHandler() {
    $menu = @{ Title = "Smart Menu"; Items = @() }
    $context = Get-CallingContext -Menu $menu
    
    # Make decisions based on context
    if ($context -match '^Getter_.*') {
        Write-Host "Handling data retrieval context"
        # Add data-specific menu items
    }
    elseif ($context -match '^Setter_.*') {
        Write-Host "Handling data modification context"
        # Add modification-specific menu items
    }
    elseif ($context -match '^Custom_.*') {
        Write-Host "Handling custom business logic context"
        # Add custom menu items
    }
    else {
        Write-Host "Handling standard context: $context"
        # Default menu behavior
    }
}
```

### 15. Debugging and Logging
```powershell
function LoggedOperation() {
    $context = Get-CallingContext
    Write-Verbose "Operation called from context: $context"
    
    # Enhanced logging based on context
    $logMessage = switch -Regex ($context) {
        '^Getter_.*' { "Data retrieval operation from $context" }
        '^Setter_.*' { "Data modification operation from $context" }
        '^Action.*' { "User action triggered from $context" }
        '^Menu.*' { "Menu operation from $context" }
        default { "General operation from $context" }
    }
    
    Write-Host $logMessage -ForegroundColor Cyan
    
    # Your actual operation logic here
    return "Operation completed successfully"
}
```

## Integration with Existing ShowMenu System

### 16. Enhanced ShowMenu Call
```powershell
# In your main script or menu handler
$mainMenu = NewMenu -Title "Application Menu" -Description "Main application menu"

# The enhanced ShowMenu will automatically use Get-CallingContext
$result = ShowMenu -Menu $mainMenu -CalledBy 'Unknown' -StackOperation 'Auto'

# ShowMenu internally calls: Get-CallingContext -Menu $mainMenu
# This provides rich context information for stack management decisions
```

## Best Practices

1. **Use PreferredContext for Backward Compatibility**
   ```powershell
   # When you know the exact context
   $context = Get-CallingContext -PreferredContext 'Action'
   ```

2. **Pass Menu Information for Enhanced Context**
   ```powershell
   # Provides additional debugging information
   $context = Get-CallingContext -Menu $currentMenu
   ```

3. **Handle Unknown Contexts Gracefully**
   ```powershell
   $context = Get-CallingContext
   if ($context -eq 'Unknown') {
       Write-Warning "Unable to determine calling context"
       # Implement fallback behavior
   }
   ```

4. **Use Context Patterns for Decision Making**
   ```powershell
   $context = Get-CallingContext
   if ($context -match '^(Getter|Setter)_.*') {
       # Handle data operations
   }
   elseif ($context -match '^(Action|Menu).*') {
       # Handle UI operations
   }
   ```

## Return Value Patterns

- **Standard Contexts**: `'Direct'`, `'Action'`, `'Submenu'`, `'Navigation'`
- **Getter Pattern**: `"Getter_[FunctionName]"`
- **Setter Pattern**: `"Setter_[FunctionName]"`
- **Creator Pattern**: `"Creator_[FunctionName]"`
- **Remover Pattern**: `"Remover_[FunctionName]"`
- **Validator Pattern**: `"Validator_[FunctionName]"`
- **Connection Pattern**: `"Connection_[FunctionName]"`
- **Menu Pattern**: `"MenuFunction_[FunctionName]"`
- **Action Pattern**: `"ActionFunction_[FunctionName]"`
- **Custom Pattern**: `"Custom_[FileName]_[FunctionName]"`

This enhanced function provides much more granular context information while maintaining full backward compatibility with existing code.
