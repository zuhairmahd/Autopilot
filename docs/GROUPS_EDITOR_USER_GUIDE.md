# Groups Editor Documentation

## Overview
The Groups Editor is a new feature that allows users to edit `groupsToExclude` and `groupsToInclude` settings for domains through an intuitive interface.

## Location
The Groups Editor can be accessed through the menu system:
```
Main Menu → Change application settings → Change global environment settings → Edit group inclusion/exclusion settings
```

## Functionality

### What it does
- Allows editing of domain-level group arrays (`groupsToInclude` and `groupsToExclude`)
- Provides an interactive interface for adding/removing groups
- Supports multiple domains with automatic domain selection
- Creates automatic backups before making changes
- Validates changes and provides feedback

### Settings Location
The groups settings are stored at the domain level in `settings.json`:
```json
{
  "domains": {
    "example.com": {
      "groupsToInclude": ["group1", "group2"],
      "groupsToExclude": ["excluded-group"],
      "settings": {
        // Other domain settings...
      }
    }
  }
}
```

## Usage

### Interactive Mode
1. Navigate to the Groups Editor through the menu
2. Select domain (if multiple domains exist)
3. View current groups to include/exclude
4. Choose to modify groups to include (y/n)
5. Enter group names one per line (empty line to finish)
6. Choose to modify groups to exclude (y/n)
7. Enter group names one per line (empty line to finish)
8. Changes are automatically saved

### Programmatic Usage
```powershell
# Edit groups for a specific domain
Show-GroupsEditor -DomainName "contoso.com"

# Edit groups with custom settings file
Show-GroupsEditor -SettingsFile "custom-settings.json"

# Silent mode (for automation)
Show-GroupsEditor -DomainName "contoso.com" -Silent
```

## Features

### Domain Selection
- Automatically detects available domains
- Prompts user to select domain if multiple exist
- Auto-selects single domain when only one available

### Group Management
- **Groups to Include**: Groups that will be specifically included in operations
- **Groups to Exclude**: Groups that will be specifically excluded from operations
- Interactive input with clear prompts
- Maintains array structure for consistency

### Safety Features
- Automatic backup creation before changes
- Change detection (only saves if changes made)
- Validation of settings after save
- Detailed logging for troubleshooting

### User Experience
- Clear visual indicators for current settings
- Intuitive prompts and instructions
- Color-coded output for better readability
- Option to keep current values by pressing Enter

## Implementation Details

### New Functions
- **Show-GroupsEditor**: Main editor function
- **Get-GroupArrayInput**: Handles user input for group arrays
- **Compare-ArrayContents**: Detects changes in array contents
- **Update-DomainGroupSetting**: Manages domain-level group setting updates

### Integration
- Leverages existing `Update-Setting` infrastructure patterns
- Follows same UI patterns as existing settings editors
- Uses existing logging and error handling systems
- Maintains PowerShell 5.1 compatibility

### File Locations
- Function: `/functions/setupFunctions/Show-GroupsEditor.ps1`
- Menu integration: `main.ps1` (environment menu section)
- Tests: `/TestScripts/test-groups-editor.ps1`

## Examples

### Current Groups Display
```
Groups to Include:
  - sg_Office_365_License_G5_wth_windows_pilot
  - sg_passwrd_hash_stage
  - ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB

Groups to Exclude:
  (no groups specified)
```

### Adding Groups
```
Enter group names to include (one per line).
Press Enter on empty line to finish.
Leave first line empty to keep current values.
Group name: new-group-1
Group name: new-group-2
Group name: [Enter]
```

## Error Handling
- Validates settings file existence
- Checks for required JSON structure
- Handles domain not found scenarios
- Provides clear error messages
- Automatic backup and rollback capabilities
- Detailed logging for troubleshooting

## Compatibility
- PowerShell 5.1 and later
- Windows, macOS, and Linux (cross-platform)
- Existing settings file formats
- All current application modes