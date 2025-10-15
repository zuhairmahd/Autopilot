# Dynamic Menu System Implementation

## Overview

The Windows Autopilot Management Tool now features a fully dynamic menu system that reads menu definitions from `menu.json` instead of using hardcoded strings. This implementation satisfies all requirements from issue #106.

## Key Changes Made

### 1. NewMenu Function Enhancement (`functions/menuFunctions/NewMenu.ps1`)
- **New Parameter**: Added `-MenuName` parameter to load menus from configuration
- **Configuration Loading**: Automatically reads menu structure from `menu.json`
- **Variable Substitution**: Supports dynamic variables like `$deviceName`, `$DomainName`, `$serialNumber`
- **Graceful Fallback**: Falls back to manual creation if configuration not found
- **includeInDisplayModes Handling**: Defaults to `["full"]` when empty or missing

### 2. AddMenuItem Function Enhancement (`functions/menuFunctions/AddMenuItem.ps1`)
- **Smart Updates**: Updates existing menu items instead of always adding new ones
- **Preservation**: Preserves `includeInDisplayModes` when updating existing items
- **Backward Compatibility**: Still adds new items when name doesn't exist

### 3. New Menu Configuration Functions
- **Get-MenuConfiguration**: Loads menu definitions from `menu.json`
- **Test-MenuJsonExists**: Ensures `menu.json` exists with comprehensive defaults
- **Set-MenuItemActions**: Helper for mapping menu item names to actions (created but not used in final approach)

#### Test-MenuJsonExists Function
The `Test-MenuJsonExists` function provides automatic menu.json management similar to settings.json and strings.json:

**Features:**
- **Automatic Creation**: Creates `menu.json` with comprehensive defaults when missing
- **Intelligent Merging**: Updates existing files with missing menu configurations
- **Version Management**: Tracks configuration version for future updates
- **Error Handling**: Graceful fallback and comprehensive logging
- **Silent Mode**: Can run without user prompts during automated setup

**Integration Points:**
- Called during application startup via `Initialize-ApplicationConfiguration`
- Invoked by `Get-MenuConfiguration` when menu file is missing
- Used in first-run wizard setup process

This ensures users never encounter missing menu configuration errors and automatically receive new menu definitions when the application is updated.

### 4. Updated Menu Creation Throughout Codebase
Updated all files that use `NewMenu` to leverage the new dynamic system:

#### Static Menus (Load from Configuration)
- `main.ps1`: Main application menus (mainMenu, checkMenu, serialNumberMenu, exportMenu, settingsMenu, autopilotMenu, environmentMenu)
- `Show-GroupsEditor.ps1`: groupsEditMenu with domain name substitution
- `ProcessSerialNumber.ps1`: deviceActionsMenu with device name substitution
- `ProcessDevice.ps1`: deviceWaitMenu with serial number substitution  
- `ShowDeviceReport.ps1`: reportExportMenu

#### Dynamic Menus (Use Configuration for Base Structure)
- `Get-AppModeConfigurationFromUser.ps1`: appModeMenu with title/description substitution
- `DisplayGroupList.ps1`: groupMenu for runtime-generated group lists
- `DisplayUserList.ps1`: userMenu for runtime-generated user lists
- `GetDeviceByUser.ps1`: deviceMenu for runtime-generated device lists
- `ShowGroupAssignments.ps1`: groupAssignmentsMenu with group name substitution

### 5. Configuration Migration
- **Removed**: Entire `menus` array from `settings.json` (354 lines removed)
- **Replaced**: With `menu.json` as the single source of menu definitions
- **Updated**: `main.ps1` to load menu configuration for filtering via `$script:menus`

### 6. App Mode Filtering Integration
- **Enhanced Test-MenuItemIncluded**: Now works with flat `menu.json` structure
- **Maintained Compatibility**: All existing app mode filtering behavior preserved
- **Default Behavior**: Items without `includeInDisplayModes` default to `["full"]`

## Menu Configuration Structure

### menu.json Format
```json
{
  "menuName": {
    "Title": "Menu Title",
    "Description": "Menu description", 
    "type": "static|dynamic",
    "items": [
      {
        "name": "Item Name",
        "description": "Item description",
        "type": "action",
        "includeInDisplayModes": ["helpdesk", "registration"]
      },
      {
        "name": "Submenu Item",
        "description": "Submenu description",
        "blockType": "menu",
        "menuName": "referencedMenuName"
      }
    ]
  }
}
```

### Variable Substitution Support
Menu titles and descriptions support runtime variable substitution:
- `$deviceName` → Actual device name
- `$DomainName` → Current domain name  
- `$serialNumber` → Device serial number
- `$groupName` → Group name
- `$menuTitle` → Dynamic menu title
- `$menuDescription` → Dynamic menu description

## Usage Patterns

### Creating a Menu from Configuration
```powershell
# Load from configuration
$menu = NewMenu -MenuName "mainMenu"

# Add/update actions
$menu = AddMenuItem -Menu $menu -Name "Export Autopilot Devices" -Action {
    # Action logic here
}
```

### Creating a Dynamic Menu
```powershell
# Load base structure from configuration
$deviceMenu = NewMenu -MenuName "deviceMenu"

# Update with runtime variables
$deviceMenu.Description = $deviceMenu.Description -replace '\$UserName', $UserName

# Add runtime-generated items
foreach ($device in $devices) {
    $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $device.Name -Action { ... }
}
```

### Fallback for Missing Configuration
```powershell
# Try configuration first, fallback to manual
$menu = NewMenu -MenuName "customMenu"
if (-not $menu) {
    $menu = NewMenu -Title "Fallback Title" -Description "Fallback Description"
}
```

## Testing

### Comprehensive Test Suite
1. **test-dynamic-menu-system.ps1**: Core dynamic menu functionality
2. **test-dynamic-menu-appmode-integration.ps1**: App mode filtering integration
3. **Existing tests**: All syntax and core tests continue to pass

### Test Coverage
- ✅ Menu configuration loading
- ✅ Static menu creation from configuration
- ✅ Dynamic menu creation with variable substitution
- ✅ AddMenuItem update vs. add behavior
- ✅ includeInDisplayModes defaulting and filtering
- ✅ App mode integration (full, helpdesk, registration, advanced, admin)
- ✅ Graceful fallback when configuration missing
- ✅ Backward compatibility with existing menu patterns

## Benefits

### Maintainability
- **Centralized Configuration**: All menu structure in single `menu.json` file
- **Reduced Code Duplication**: Menu definitions separated from logic
- **Easier Updates**: Change menu structure without touching code

### Flexibility  
- **Variable Substitution**: Dynamic content based on runtime context
- **App Mode Filtering**: Granular control over menu visibility
- **Mixed Approach**: Static configuration + dynamic runtime generation

### Backward Compatibility
- **Existing Code**: Minimal changes to existing functions
- **AddMenuItem**: Enhanced to update existing items seamlessly
- **Fallback**: Graceful degradation when configuration missing

## Migration Guide

### For New Menus
1. Add menu definition to `menu.json`
2. Use `NewMenu -MenuName "menuName"` instead of `NewMenu -Title "..." -Description "..."`
3. Add actions using existing `AddMenuItem` pattern

### For Existing Code
- Static menus: Replace with `NewMenu -MenuName "configName"`
- Dynamic menus: Use configuration for base structure, add runtime items
- Variable substitution: Use `-replace` to substitute variables in titles/descriptions

## Future Enhancements

### Potential Improvements
- **Validation**: Schema validation for `menu.json`
- **Localization**: Multi-language support in menu definitions
- **Conditional Items**: More advanced visibility rules beyond app modes
- **Menu Templates**: Reusable menu item patterns

### Extension Points
- **Custom Actions**: Action definitions in configuration
- **Menu Themes**: Styling and formatting options
- **Dynamic Loading**: Runtime menu definition updates
- **Menu Inheritance**: Base menu extension patterns

## Conclusion

The dynamic menu system successfully makes menus configurable while maintaining backward compatibility and preserving all existing functionality. The implementation satisfies all requirements from issue #106 with minimal code changes and comprehensive test coverage.