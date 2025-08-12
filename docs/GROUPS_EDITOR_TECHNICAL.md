# Groups Editor Technical Documentation

## Architecture Overview
The Groups Editor provides the ability to edit `groupsToExclude` and `groupsToInclude` arrays at the domain level in the settings.json file, without changing their location in the configuration hierarchy.

## Design Principles
1. **Minimal Code Changes**: Leverages existing infrastructure where possible
2. **Consistency**: Follows same patterns as existing settings editors
3. **Safety**: Automatic backups and validation
4. **User Experience**: Intuitive interface matching application style

## Implementation Details

### Core Function: Show-GroupsEditor
**Location**: `/functions/setupFunctions/Show-GroupsEditor.ps1`

**Parameters**:
- `SettingsFile`: Path to settings.json (default: "settings.json")
- `DomainName`: Target domain (optional, will prompt if not provided)
- `Silent`: Minimal output mode for automation

**Return Value**: Boolean indicating success/failure

### Helper Functions

#### Get-GroupArrayInput
Handles interactive user input for group arrays with the following features:
- One group name per line input
- Empty line to finish
- Option to keep current values
- Maintains array structure

#### Compare-ArrayContents
Compares two arrays to detect changes:
- Handles null/empty arrays correctly
- Returns true if arrays differ, false if same
- Used to determine if changes need to be saved

#### Update-DomainGroupSetting
Updates domain-level group settings:
- Direct JSON manipulation for domain properties
- Automatic backup creation
- Post-update verification
- Supports both `groupsToInclude` and `groupsToExclude`

## Data Structure

### Settings Location
Groups are stored at the domain level, not within the `settings` sub-object:

```json
{
  "domains": {
    "example.com": {
      "groupsToInclude": [],
      "groupsToExclude": [],
      "settings": {
        // Domain-specific settings
      }
    }
  }
}
```

### Why Domain Level?
- Groups control operations across the entire domain
- Separate from domain-specific configuration settings
- Align with existing data structure
- Maintain backward compatibility

## Menu Integration

### Location in Menu Hierarchy
```
Main Menu
└── Change application settings
    └── Change global environment settings
        └── Edit group inclusion/exclusion settings  ← NEW
```

### Implementation in main.ps1
Added after authentication settings menu item:
```powershell
$environmentMenu = AddMenuItem -menu $environmentMenu -Name "Edit group inclusion/exclusion settings" -Action {
    Write-Host "Launching groups editor..." -ForegroundColor Cyan
    Write-Host "These settings control which groups are included or excluded from operations." -ForegroundColor Gray
    
    $success = Show-GroupsEditor -SettingsFile $InitFile
    if ($success) {
        Write-Host "`nGroup settings updated successfully. Changes will take effect immediately." -ForegroundColor Green
    } else {
        Write-Host "`nFailed to update group settings. Please check the logs for details." -ForegroundColor Red
    }
}
```

## Leveraging Existing Infrastructure

### Settings Management
- Uses similar patterns to `Show-SettingsEditor`
- Leverages `Get-CurrentSettings` approach for loading
- Follows same backup and validation patterns

### Error Handling
- Uses existing `Write-Log` function for logging
- Follows same error handling patterns as other settings functions
- Consistent verbose output and debugging

### User Interface
- Matches color scheme and prompt style of existing editors
- Uses same navigation and confirmation patterns
- Consistent help text and instructions

## Update Process Flow

1. **Load Settings**: Read current settings.json
2. **Domain Selection**: Auto-select or prompt user for domain
3. **Display Current**: Show current groups to include/exclude
4. **Edit Include Groups**: Optional editing of groupsToInclude
5. **Edit Exclude Groups**: Optional editing of groupsToExclude
6. **Change Detection**: Compare old vs new arrays
7. **Save Changes**: Update JSON file with backups
8. **Verification**: Confirm changes were saved correctly

## Backup Strategy
- Timestamped backup files: `settings.json.backup.yyyyMMdd_HHmmss`
- Created before any modification
- Allows manual rollback if needed
- Follows existing backup patterns in the application

## Testing Strategy

### Unit Tests
**Location**: `/TestScripts/test-groups-editor.ps1`

**Test Coverage**:
- Function availability validation
- Helper function functionality
- Array comparison logic
- Settings file structure validation
- Menu integration verification

### Integration Tests
- Validates with existing test suite
- Ensures no regression in core functionality
- Menu system compatibility
- Settings architecture compliance

## PowerShell 5.1 Compatibility

### Hashtable Usage
- Uses regular hashtables instead of ordered hashtables
- Avoids PowerShell Core-specific features
- Compatible array handling

### JSON Handling
- Uses `ConvertFrom-Json` and `ConvertTo-Json`
- Maintains depth settings for complex structures
- Handles PSCustomObject to hashtable conversion

## Error Scenarios and Handling

### File Not Found
- Settings file missing → Clear error message and return false
- Graceful degradation without application crash

### Invalid JSON
- Malformed settings.json → Caught and logged
- Provides specific error information for troubleshooting

### Domain Not Found
- Specified domain doesn't exist → User-friendly error
- Lists available domains for reference

### Permission Issues
- Cannot write to settings file → Clear error message
- Backup creation failure → Stops process safely

## Security Considerations

### File Access
- Only modifies settings.json (no arbitrary file access)
- Creates backups for safety
- Validates file structure before modification

### Input Validation
- Group names are trimmed but not filtered (user responsibility)
- No injection risks (direct JSON property assignment)
- Array structure maintained for type safety

## Future Enhancements

### Potential Improvements
1. **Group Name Validation**: Add pattern validation for group names
2. **Batch Import**: Support importing groups from CSV/text files
3. **Group Search**: Integration with Microsoft Graph to search/validate groups
4. **Templates**: Pre-defined group sets for common scenarios
5. **Audit Trail**: Enhanced logging of group changes with timestamps

### Extension Points
- Can be extended to support other domain-level arrays
- Framework can be adapted for similar configuration editing needs
- Menu system supports easy addition of related functions

## Dependencies

### Required Functions
- Core settings functions (Get-Content, ConvertFrom-Json, etc.)
- Logging infrastructure (Write-Log)
- Menu system functions (AddMenuItem)

### Global Variables
- `$global:maxJSONDepth`: For JSON serialization depth
- `$global:logFile`: For logging operations

### PowerShell Modules
- No additional PowerShell modules required
- Uses built-in JSON and file system cmdlets