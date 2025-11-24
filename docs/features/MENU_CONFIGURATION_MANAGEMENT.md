# Menu Configuration Management

## Overview

The Windows Autopilot Management Tool includes automatic menu configuration management through the `Test-MenuJsonExists` function, which ensures the `menu.json` file always exists with comprehensive default menu definitions.

## Test-MenuJsonExists Function

### Purpose

`Test-MenuJsonExists` provides robust menu configuration management by:
- Creating `menu.json` with complete default menu definitions when the file is missing
- Merging new menu configurations into existing files during application updates
- Maintaining configuration consistency across different environments
- Preventing menu-related application errors

### Function Signature

```powershell
Test-MenuJsonExists -MenuFile <string> [-Silent]
```

**Parameters:**
- `MenuFile` (Required): Path to the menu.json file
- `Silent` (Optional): Suppress user prompts and confirmation messages

**Returns:** `$true` if successful, `$false` if an error occurred

### Default Menu Structure

When creating a new `menu.json` file, the function includes:

#### Core Metadata
- **name**: File identifier
- **description**: File purpose description
- **version**: Version tracking for updates

#### App Mode Hierarchy
Defines privilege inheritance across application modes:
- **full**: Wildcard access to all features (`["*"]`)
- **admin**: Full administrative access (`["admin", "advanced", "helpdesk", "registration"]`)
- **advanced**: Advanced user capabilities (`["advanced", "helpdesk", "registration"]`)
- **helpdesk**: Device troubleshooting access (`["helpdesk"]`)
- **registration**: Device registration capabilities (`["registration"]`)
- **advancedRegistration**: Enhanced registration features (`["advancedRegistration", "registration"]`)
- **custom**: User-defined access patterns (`[]`)

#### App Mode Defaults
Capability definitions for each application mode including descriptions and feature lists.

#### Complete Menu Definitions
All essential menu configurations:
- **mainMenu**: Primary application navigation
- **checkMenu**: Device status and troubleshooting options
- **serialNumberMenu**: Device-specific operations
- **autopilotMenu**: Autopilot device management
- **settingsMenu**: Application configuration
- **environmentMenu**: Environment settings
- **exportMenu**: Data export options
- **deviceWaitMenu**: Device waiting operations
- **deviceMenu**: Device selection interface
- **deviceActionsMenu**: Device action commands

### Integration Points

#### Application Startup
The function is called during application initialization:

```powershell
# In Initialize-ApplicationConfiguration.ps1
$MenuFile = "$pwd\menu.json"
$menuCreated = Test-MenuJsonExists -MenuFile $MenuFile -Silent
```

#### First-Run Wizard
Included in the setup process:

```powershell
# In Start-FirstRunWizard.ps1
$MenuFile = "$pwd\menu.json"
$menuCreated = Test-MenuJsonExists -MenuFile $MenuFile -Silent:$Silent
```

#### Menu Loading
Called automatically when menu configurations are missing:

```powershell
# In Get-MenuConfiguration.ps1
if (-not (Test-Path $MenuConfigFile)) {
    if (Test-MenuJsonExists -MenuFile $MenuConfigFile -Silent) {
        # Continue with loading
    }
}
```

### Configuration Merging

When an existing `menu.json` file is found, the function:

1. **Loads Existing Content**: Reads current menu configurations
2. **Converts to Hashtables**: Prepares for deep merging operations
3. **Merges Defaults**: Uses `Merge-ConfigurationDefaults` to add missing configurations
4. **Preserves Customizations**: Keeps existing menu modifications
5. **Updates File**: Writes merged configuration back to disk

### Error Handling

The function includes comprehensive error handling:
- **File Access Errors**: Logs and reports permission or I/O issues
- **JSON Parsing Errors**: Handles corrupted configuration files
- **Merge Failures**: Provides fallback to complete recreation
- **Logging Integration**: Uses application logging framework for troubleshooting

### Usage Examples

#### Basic Usage
```powershell
# Ensure menu.json exists with defaults
$success = Test-MenuJsonExists -MenuFile "menu.json"
if ($success) {
    Write-Host "Menu configuration ready"
}
```

#### Silent Operation
```powershell
# For automated/scripted environments
$success = Test-MenuJsonExists -MenuFile "menu.json" -Silent
```

#### Custom Location
```powershell
# Using custom file path
$customPath = "C:\Config\custom-menu.json"
$success = Test-MenuJsonExists -MenuFile $customPath
```

### Testing

The function includes comprehensive test coverage in `TestScripts/test-menu-json-exists.ps1`:

- **Creation Test**: Verifies new file creation with correct structure
- **Update Test**: Validates merging of missing configurations
- **Content Test**: Confirms all expected menu definitions are present
- **Hierarchy Test**: Validates app mode hierarchy structure

### Relationship to Other Functions

#### Settings Management
Similar pattern to `Test-SettingsJsonExists` and `Test-StringsJsonExists`:
- Consistent API design across configuration management
- Shared merging and error handling patterns
- Integrated into same initialization workflows

#### Menu System
Works with menu loading functions:
- **Get-MenuConfiguration**: Calls Test-MenuJsonExists when file missing
- **NewMenu**: Benefits from guaranteed configuration availability
- **Application Startup**: Ensures menu system can always initialize

### Best Practices

#### For Developers
- Always call during application initialization
- Use Silent mode in automated scripts
- Check return value for error handling
- Include in test scenarios for configuration management

#### For Users
- Menu configurations are automatically managed
- Customizations are preserved during updates
- No manual intervention required for menu setup
- File corruption is automatically resolved

### Troubleshooting

#### Common Issues
1. **Permission Errors**: Ensure write access to application directory
2. **Corrupted Files**: Function will recreate from defaults
3. **Missing Dependencies**: Requires supporting functions to be loaded
4. **Logging Failures**: Check log file path configuration

#### Debug Information
The function provides verbose logging for troubleshooting:
- Configuration merge operations
- File creation and update activities
- Error conditions and fallback actions
- Performance timing information

### Future Enhancements

#### Planned Improvements
- Schema validation for menu configurations
- Configuration backup and rollback
- Menu configuration templates
- Remote configuration synchronization

#### Extension Points
- Custom menu definition sources
- Configuration validation rules
- Automated configuration updates
- Integration with external configuration systems

## Conclusion

The `Test-MenuJsonExists` function provides robust, automatic menu configuration management that ensures the Windows Autopilot Management Tool can always initialize its menu system successfully. By following the same patterns as settings and strings management, it provides a consistent and reliable configuration experience for all users.