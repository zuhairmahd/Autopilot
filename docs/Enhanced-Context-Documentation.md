# Enhanced Get-CallingContext Function

## Overview

The `Get-CallingContext` function has been enhanced to provide unique context detection based on the navigation path through the menu system. This allows you to differentiate between the same function being called from different menu paths while maintaining full backward compatibility.

## New Features

### Navigation Path-Aware Context Detection

The function can now analyze the `$Global:MenuHistory` to determine how the user navigated to the current location and provide enhanced context information.

### Enhanced Function Signature

```powershell
function Get-CallingContext()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Menu = $null,
        [Parameter(Mandatory = $false)]
        [string]$PreferredContext = $null,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeNavigationPath    # NEW PARAMETER
    )
}
```

## Usage Examples

### Basic Usage (Backward Compatible)
```powershell
# This works exactly as before
$context = Get-CallingContext
# Returns: "Action", "Direct", "Navigation", etc.
```

### Enhanced Usage with Navigation Path
```powershell
# NEW: Include navigation path for unique context
$context = Get-CallingContext -IncludeNavigationPath
# Returns: "Action-ViaCheckMenu", "Action-ViaAutopilotMenu", etc.
```

## Context Patterns

### Serial Number Menu Contexts

When the serial number functionality is accessed from different paths, you'll get:

#### Via Check Device Status Menu
- **Path**: Main Menu → Check Device Status → Lookup by Serial Number
- **Context**: `Action-ViaCheckMenu` or `Direct-ViaCheckMenu`

#### Via Autopilot Menu  
- **Path**: Main Menu → Autopilot Menu → Check device Autopilot status
- **Context**: `Action-ViaAutopilotMenu` or `Direct-ViaAutopilotMenu`

#### Direct Access
- **Path**: Direct function call with no navigation history
- **Context**: `Action` or `Direct` (unchanged from original)

## Implementation Details

### Navigation Path Analysis

The function analyzes the `$Global:MenuHistory` to create a "path signature":

1. **Menu Title Normalization**: Removes spaces and special characters
2. **Path Pattern Matching**: Uses regex to identify known navigation patterns
3. **Context Generation**: Creates unique context strings based on the path

### Pattern Recognition

The function recognizes these specific patterns:

```powershell
'MainMenu-CheckDeviceStatus-LookupbySerialNumber' → 'ViaCheckMenu'
'MainMenu-AutopilotMenu-CheckdeviceAutopilotstatus' → 'ViaAutopilotMenu'
```

And generic patterns:
```powershell
'MainMenu-CheckDeviceStatus.*SerialNumber' → 'ViaCheckMenu'
'MainMenu-AutopilotMenu.*SerialNumber' → 'ViaAutopilotMenu'
```

## Practical Usage in Your Code

### Before (Limited Context)
```powershell
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    $context = Get-CallingContext
    # $context could be "Action" from either path
    
    # No way to differentiate between Check Menu vs Autopilot Menu paths
    ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
}
```

### After (Enhanced Context)
```powershell
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    $context = Get-CallingContext -IncludeNavigationPath
    
    # Now you can differentiate and customize behavior
    switch -Regex ($context) {
        '.*ViaCheckMenu' {
            Write-Host "Accessed via Check Device Status - focusing on device status" -ForegroundColor Green
            # Emphasize device status checks
        }
        '.*ViaAutopilotMenu' {
            Write-Host "Accessed via Autopilot Menu - focusing on Autopilot status" -ForegroundColor Blue
            # Emphasize Autopilot-specific functionality
        }
        default {
            Write-Host "Direct access - standard behavior" -ForegroundColor Yellow
        }
    }
    
    ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
}
```

## Backward Compatibility

✅ **100% Backward Compatible**
- All existing code continues to work unchanged
- New functionality is opt-in via the `-IncludeNavigationPath` switch
- Original context values are preserved when the new parameter is not used

## Testing

Run the included test script to see the enhanced functionality:

```powershell
.\Test-EnhancedContext.ps1 -Verbose
```

## Supporting Functions

### New Helper Functions

#### `Get-BaseCallingContext`
- Extracted the original context detection logic
- Maintains the same behavior as the original function

#### `Get-NavigationPathContext`  
- Analyzes `$Global:MenuHistory` to determine navigation path
- Creates navigation-specific context suffixes
- Handles pattern matching for known menu paths

## Performance Impact

- **Minimal**: Navigation path analysis only occurs when `-IncludeNavigationPath` is specified
- **Efficient**: Uses simple array operations and regex pattern matching
- **Memory**: No additional permanent memory usage

## Future Extensibility

The design allows for easy addition of new navigation patterns:

```powershell
# Add new patterns to Get-NavigationPathContext
'MainMenu-NewMenu-SerialNumber' {
    return 'ViaNewMenu'
}
```

This enhancement provides the unique context differentiation you requested while preserving all existing functionality.
