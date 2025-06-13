# ShowMenu Function Documentation

## Overview
The `ShowMenu` function is the core navigation controller for the PowerShell menu system. It displays menus, handles user input, manages navigation history, and controls the menu stack for proper Back/Main Menu functionality.

## Function Signature
```powershell
function ShowMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $false)]
        [string]$BackoutText = $backoutText,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Push', 'Pop', 'None')]
        [string]$StackOperation = 'Auto',
        [Parameter(Mandatory = $false)]
        [ValidateSet('Unknown', 'Direct', 'Action', 'Submenu', 'Navigation')]
        [string]$CalledBy = 'Unknown'
    )
}
```

## Parameters

### 1. `$Menu` (Mandatory)
- **Type:** `[hashtable]`
- **Purpose:** The menu structure containing the title, description, and menu items to display
- **Required:** Yes
- **Usage:** Always required - this is the actual menu you want to show

**Example:**
```powershell
$myMenu = NewMenu -Title "Main Menu" -Description "Select an option"
ShowMenu -Menu $myMenu
```

### 2. `$BackoutText` (Optional)
- **Type:** `[string]`
- **Default:** `$backoutText` (global variable)
- **Purpose:** Text that signals a "back out" action from menu items
- **Usage:** When you have menu actions that might return a specific text value to indicate the user wants to go back

**Example:**
```powershell
ShowMenu -Menu $myMenu -BackoutText "Cancel Operation"
```

### 3. `$StackOperation` (Optional)
- **Type:** `ValidateSet('Auto', 'Push', 'Pop', 'None')`
- **Default:** `'Auto'`
- **Purpose:** Controls how the menu manages the navigation stack

#### Valid Values:

**`'Auto'` (Default)**
- Let the function decide based on calling context
- Recommended for most use cases
```powershell
# Most common usage - let the system handle stack management
ShowMenu -Menu $subMenu
```

**`'Push'`**
- Force adding this menu to the navigation stack
- Use when you want to explicitly add to history for Back navigation
```powershell
ShowMenu -Menu $newMenu -StackOperation 'Push'
```

**`'Pop'`**
- Force removing the current menu from stack
- Use when implementing custom back navigation
```powershell
ShowMenu -Menu $previousMenu -StackOperation 'Pop'
```

**`'None'`**
- Don't modify the navigation stack
- Use when refreshing the same menu without affecting navigation
```powershell
ShowMenu -Menu $currentMenu -StackOperation 'None'
```

### 4. `$CalledBy` (Optional)
- **Type:** `ValidateSet('Unknown', 'Direct', 'Action', 'Submenu', 'Navigation')`
- **Default:** `'Unknown'`
- **Purpose:** Indicates the context from which ShowMenu was called

#### Valid Values:

**`'Unknown'` (Default)**
- Let the function auto-detect the calling context
- Function will analyze call stack to determine context

**`'Direct'`**
- Called directly from your code (like from main script)
```powershell
# Initial menu display
ShowMenu -Menu $mainMenu -CalledBy 'Direct'
```

**`'Action'`**
- Called as a result of executing a menu action
```powershell
# Inside action execution, returning to menu
ShowMenu -Menu $currentMenu -CalledBy 'Action' -StackOperation 'None'
```

**`'Submenu'`**
- Called when navigating to a submenu
```powershell
# When entering a submenu
ShowMenu -Menu $selectedItem.Submenu -CalledBy 'Submenu'
```

**`'Navigation'`**
- Called during Back/Main Menu navigation
```powershell
# Internal navigation handling
ShowMenu -Menu $targetMenu -CalledBy 'Navigation' -StackOperation 'None'
```

## Common Usage Scenarios

### 1. Basic Usage (Most Common)
```powershell
# Simple menu display - let the system handle everything automatically
ShowMenu -Menu $myMenu
```

### 2. Initial Main Menu
```powershell
# Starting the application with the main menu
ShowMenu -Menu $mainMenu -CalledBy 'Direct' -StackOperation 'Push'
```

### 3. Custom Navigation Handling
```powershell
# When implementing custom back logic
ShowMenu -Menu $previousMenu -CalledBy 'Navigation' -StackOperation 'None'
```

### 4. Refreshing Current Menu
```powershell
# Redisplaying the same menu without affecting navigation stack
ShowMenu -Menu $currentMenu -StackOperation 'None'
```

### 5. Submenu Navigation
```powershell
# Navigating to a submenu (typically handled internally)
ShowMenu -Menu $submenu -CalledBy 'Submenu' -StackOperation 'Auto'
```

### 6. Action Return Navigation
```powershell
# Returning to menu after action execution
ShowMenu -Menu $currentMenu -CalledBy 'Action' -StackOperation 'None'
```

## How It Works

### Navigation Stack Management
The function maintains two global collections:
- `$Global:MenuHistory` - Stack of menu objects for navigation
- `$Global:History` - Stack of menu titles for breadcrumb display

### Auto Context Detection
When `CalledBy` is 'Unknown', the function:
1. Analyzes the PowerShell call stack using `Get-PSCallStack`
2. Examines the calling function name
3. Determines appropriate context based on caller

### Stack Operation Logic
The function uses a two-level switch statement:
1. First level: `$StackOperation` parameter
2. Second level: `$CalledBy` context (when using 'Auto')

This provides intelligent stack management while allowing manual override when needed.

### Navigation Options
The function automatically adds navigation options based on stack depth:
- **Back** - Added when `$Global:MenuHistory.Count > 0`
- **Main Menu** - Added when `$Global:MenuHistory.Count > 1`
- **Exit** - Always available (option 0)

## Return Values
The function can return various types:
- **Menu object** - When navigating to another menu
- **Action result** - When an action returns a value
- **`$null`** - When exiting the application
- **Integer 0** - When user selects Exit

## Best Practices

### 1. Use Default Parameters
For most scenarios, simply pass the menu:
```powershell
ShowMenu -Menu $myMenu
```

### 2. Explicit Parameters for Special Cases
Use explicit parameters only when you need fine control:
```powershell
# Initial application startup
ShowMenu -Menu $mainMenu -CalledBy 'Direct' -StackOperation 'Push'

# Custom navigation handling
ShowMenu -Menu $targetMenu -CalledBy 'Navigation' -StackOperation 'None'
```

### 3. Let Auto-Detection Work
The function is designed to be intelligent about context detection. Trust the auto-detection unless you have specific requirements.

### 4. Consistent Error Handling
Always handle the return value appropriately:
```powershell
$result = ShowMenu -Menu $myMenu
if ($null -eq $result) {
    # Handle application exit
    exit
}
```

## PowerShell Compatibility
- **Primary Target:** PowerShell 5.1 for Windows
- **Fallback Support:** Includes try/catch blocks for ArrayList operations
- **Cross-Platform:** Should work on PowerShell Core/7+ with minor adjustments

## Global Dependencies
The function requires these global variables:
- `$Global:MenuHistory` - Automatically initialized if not present
- `$Global:History` - Automatically initialized if not present  
- `$backoutText` - Should be defined in your application

## Related Functions
- `DisplayNumericMenu` - Handles user input and menu display
- `Handle-BackNavigation` - Processes back navigation
- `Handle-MainMenuNavigation` - Processes main menu navigation
- `Handle-MenuItemSelection` - Processes menu item selection
- `Push-MenuToStack` / `Pop-MenuFromStack` - Stack management
- `Create-MenuBanner` - Creates menu headers with breadcrumbs

## Troubleshooting

### Common Issues:
1. **Navigation not working** - Check that menus are being pushed to stack properly
2. **Duplicate menu entries** - Verify StackOperation settings
3. **Missing breadcrumbs** - Ensure History is being populated correctly

### Debug Information:
The function provides extensive verbose logging. Run with `-Verbose` to see detailed execution flow:
```powershell
ShowMenu -Menu $myMenu -Verbose
```