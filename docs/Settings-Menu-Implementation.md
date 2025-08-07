# Settings Menu Implementation

## Overview

The Settings Menu functionality provides users with an interactive interface to modify application settings from within the script. This implementation allows editing both global settings and domain-specific settings using a menu-driven approach.

## Features

### Settings Types Supported

1. **Global Settings**: Application-wide settings that affect all domains
2. **Domain-Specific Settings**: Settings that are specific to individual domains

### Data Types Handled

- **Boolean**: Interactive menu with current value highlighted
- **String**: Text input with current value display
- **Number**: Validated numeric input with range checking  
- **Array**: Multi-line input with completion on empty line
- **Enumerated Values**: Menu-based selection for predefined options

### Supported Enumerated Settings

- `appMode`: full, helpDesk, advanced, advancedRegistration, registration, admin, custom
- `cacheType`: Memory, File
- `repo`: Github, Gitlab
- `operatingSystem`: Windows, macOS, Linux
- `preferredBrowser`: Chrome, Edge, Firefox, Safari

## Usage

### Accessing the Settings Menu

1. Launch the main application
2. Navigate to "Change application settings" 
3. Select "Change environment settings"
4. Choose either:
   - "Change global environment settings"
   - "Change domain specific settings"

### Interactive Settings Editor

The settings editor will:

1. Display each setting with its description
2. Show the current value
3. Prompt for input based on the setting type
4. Validate input values
5. Save changes to settings.json

### Example Usage

```powershell
# Edit global settings
Show-SettingsEditor -SettingsType "Global"

# Edit domain-specific settings
Show-SettingsEditor -SettingsType "Domain" -DomainName "contoso.com"

# Silent mode with preset values (for automation)
$presetValues = @{ 'autoUpdate' = $true; 'timeInSeconds' = '120' }
Show-SettingsEditor -SettingsType "Global" -Silent -PresetValues $presetValues
```

## Implementation Details

### Core Functions

#### Show-SettingsEditor
Main function that provides the interactive settings editing interface.

**Parameters:**
- `SettingsType`: 'Global' or 'Domain'
- `SettingsFile`: Path to settings.json (defaults to "settings.json")
- `DomainName`: Required for Domain settings
- `Silent`: Non-interactive mode
- `PresetValues`: Hashtable of preset values for automation

#### Get-DefaultSettingsStructure
Retrieves the default settings structure from `Test-SettingsJsonExists.ps1`, ensuring consistency with the application's default configuration.

#### Data Type Handlers
- `Get-BooleanInput`: Handles true/false settings with menu selection
- `Get-AppModeInput`: Specialized handler for application mode selection
- `Get-EnumeratedInput`: Generic handler for predefined value lists
- `Get-ArrayInput`: Multi-line input for array values
- `Get-NumberInput`: Validated numeric input
- `Get-StringInput`: Basic string input

### Integration Points

The settings editor integrates with existing infrastructure:

- **Update-GlobalSetting**: For saving global settings changes
- **Update-DomainSettings**: For saving domain-specific changes
- **Test-SettingsJsonExists**: Source of default settings structure
- **Menu system**: Integrated with existing menu navigation

### Validation

Settings validation includes:

- Data type validation (numbers, booleans, strings)
- Range validation for numeric settings
- Format validation for specific settings
- Enumerated value validation

### Error Handling

- Graceful handling of invalid input
- Backup creation before modifications
- Rollback capability on save failures
- Comprehensive error logging

## Configuration Management

### Settings File Structure

The implementation works with the standard settings.json structure:

```json
{
  "globalSettings": {
    "autoUpdate": true,
    "appMode": "full",
    "maxWaitTime": "30",
    // ... other global settings
  },
  "domains": {
    "contoso.com": {
      "settings": {
        "domain": "contoso.com",
        "minUsernameLength": 3,
        "preferredBrowser": "Chrome",
        // ... other domain settings
      }
    }
  }
}
```

### Default Settings Source

All default values and setting definitions come from `Test-SettingsJsonExists.ps1`, making it the single source of truth for:

- Available settings
- Default values
- Setting structure
- Validation rules

## Testing

### Test Coverage

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: End-to-end menu functionality
3. **Automated Tests**: Silent mode validation
4. **Manual Tests**: Interactive user experience

### Test Scripts

- `test-settings-editor.ps1`: Core functionality tests
- `test-settings-integration.ps1`: Integration with main application
- `demo-settings-menu.ps1`: User experience demonstration

## Troubleshooting

### Common Issues

1. **Settings file not found**: The system will create a new file with defaults
2. **Invalid domain**: Domain settings will be created if they don't exist
3. **Permission errors**: Ensure write access to settings.json location
4. **Backup files**: Created automatically before modifications

### Debug Information

Enable verbose logging for troubleshooting:

```powershell
Show-SettingsEditor -SettingsType "Global" -Verbose
```

### Recovery

- Backup files are created with timestamp: `settings.json.backup.YYYYMMDD_HHMMSS`
- Restore from backup if needed: `Copy-Item settings.json.backup.* settings.json`

## Best Practices

1. **Always test in a safe environment first**
2. **Review changes before applying in production**
3. **Keep backups of working configurations**
4. **Use domain-specific settings for environment isolation**
5. **Validate settings after modification**

## Future Enhancements

Potential areas for future improvement:

1. **Setting categories and grouping**
2. **Advanced validation rules**
3. **Configuration templates**
4. **Import/export functionality**
5. **Setting change history**
6. **Conditional settings (dependencies)**

## Security Considerations

- Settings files may contain sensitive configuration data
- Backup files should be secured appropriately
- Consider encryption for sensitive settings
- Validate all input to prevent injection attacks