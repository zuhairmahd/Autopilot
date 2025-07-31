# AutoUpdate First-Run Wizard Integration

## Overview

This document describes the implementation of the autoUpdate setting integration into the first-run wizard. This enhancement allows users to configure automatic update preferences during initial application setup.

## Implementation Details

### New Function: Get-AutoUpdateConfigurationFromUser

**Location**: `functions/FirstRunWizardFunctions.ps1`

**Purpose**: Prompts the user to configure automatic update preferences during the first-run wizard.

**Behavior**:
- In interactive mode: Presents a user-friendly prompt with clear options
- In silent mode: Defaults to enabling automatic updates
- Returns a hashtable with the autoUpdate setting

**Example Output**:
```
── Auto Update Configuration ──
The script can automatically check for and install updates.
This helps ensure you have the latest features and security improvements.

Do you want to enable automatic updates?
1. Yes - Enable automatic updates (recommended)
2. No - Disable automatic updates
Enter your choice (1 or 2): 1

Automatic updates: Enabled
The script will check for updates automatically.
```

### Integration Points

#### 1. First-Run Wizard Flow
The autoUpdate configuration is integrated into the existing `Start-FirstRunWizard` function:

1. **Step 1**: Basic configuration (App ID, Tenant ID, Domain)
2. **Step 2**: Authentication configuration 
3. **Step 2.5**: **AutoUpdate configuration** (NEW)
4. **Step 3**: Configuration merging
5. **Step 4**: Configuration file creation and encryption
6. **Step 5**: Settings.json creation with defaults
7. **Step 5.5**: **AutoUpdate setting update** (NEW)
8. **Step 6**: Strings.json creation
9. **Step 7**: Completion message with configuration summary

#### 2. Settings Management Integration
The implementation leverages the existing `Update-GlobalSetting` function from `SettingsHelperFunctions.ps1`:

```powershell
$autoUpdateSuccess = Update-GlobalSetting -SettingsFile $SettingsFile -SettingName "autoUpdate" -SettingValue $autoUpdateConfig.autoUpdate
```

This approach provides:
- Automatic backup creation before modification
- JSON validation before and after updates
- Error handling and logging
- Consistency with other settings updates

#### 3. Completion Message Enhancement
The wizard completion message now includes a configuration summary:

```
Configuration Summary:
• Domain: example.com
• Authentication: Delegated
• Auto Updates: Enabled
```

## Technical Specifications

### Function Signature
```powershell
function Get-AutoUpdateConfigurationFromUser()
{
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
}
```

### Return Value
```powershell
@{
    autoUpdate = $true|$false
}
```

### Error Handling
- Validates user input (1 or 2 only)
- Provides clear error messages for invalid choices
- Returns $null on failure for proper error detection
- Comprehensive logging with Write-SafeLog

### PowerShell 5.1 Compatibility
- Uses regular hashtables instead of ordered hashtables
- Compatible with older PowerShell versions
- No dependencies on newer PowerShell features

## Integration Benefits

### 1. Leverages Existing Infrastructure
- Uses established `Update-GlobalSetting` function
- Follows existing wizard prompt patterns
- Maintains consistent error handling and logging

### 2. Backward Compatibility
- Existing settings.json files continue to work
- Default autoUpdate value is preserved (true)
- No breaking changes to existing functionality

### 3. User Experience
- Clear, user-friendly prompts
- Contextual explanations of the setting
- Configuration summary at completion
- Silent mode support for automation

### 4. Maintainability
- Minimal code changes
- Follows established patterns
- Well-documented functions
- Comprehensive test coverage

## Testing

### Test Coverage
1. **Unit Tests**: `Get-AutoUpdateConfigurationFromUser` function in isolation
2. **Integration Tests**: Full wizard with autoUpdate in silent mode
3. **Settings Tests**: Validation that autoUpdate is properly saved
4. **Update Tests**: Verification that `Update-GlobalSetting` works with autoUpdate

### Test Script
Location: `TestScripts/test-autoupdate-wizard.ps1`

The test script validates:
- Function works in silent mode with correct defaults
- Full wizard integration saves autoUpdate setting correctly
- Settings can be updated after initial creation
- All file creation and validation works properly

## Future Enhancements

### Potential Improvements
1. **Update Frequency**: Allow users to configure update check frequency
2. **Update Source**: Allow users to choose update source (stable/beta)
3. **Notification Preferences**: Configure how update notifications are displayed
4. **Rollback Options**: Allow users to configure automatic rollback on failure

### Extension Points
The implementation provides a foundation for additional settings prompts:
- Other boolean settings can follow the same pattern
- The `Get-AutoUpdateConfigurationFromUser` function can serve as a template
- The settings update mechanism is reusable for other configuration options

## Implementation Notes

### Design Decisions
1. **Separate Function**: Created dedicated function for maintainability and testability
2. **Silent Mode Default**: Defaults to enabled for security and feature updates
3. **Existing Infrastructure**: Uses `Update-GlobalSetting` to avoid code duplication
4. **User-Friendly Prompts**: Clear explanations help users make informed decisions

### Security Considerations
- Automatic updates help ensure users have latest security patches
- Default of enabled provides secure-by-default configuration
- User can still opt-out if needed for specific environments

### Performance Impact
- Minimal performance impact during wizard execution
- Settings update uses efficient JSON manipulation
- No impact on normal application operation

## Conclusion

The autoUpdate first-run wizard integration provides a seamless way for users to configure automatic update preferences during initial setup. The implementation leverages existing infrastructure, maintains backward compatibility, and follows established patterns for consistency and maintainability.