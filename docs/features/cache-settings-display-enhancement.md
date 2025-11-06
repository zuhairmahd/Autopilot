# Cache Settings Display Enhancement

## Overview
Enhanced the cache settings editor interface to provide human-readable parameter names and context-aware descriptions, improving user experience when configuring cache behavior.

**Date**: November 6, 2025  
**PR**: #189 - Add settings editors for repoInfo and cacheSettings  
**Files Modified**:
- `functions/setupFunctions/Show-SettingsEditor.ps1`

## Problem Statement

The original cache settings editor displayed technical dot-notation paths that were difficult to understand:

```
Setting: cacheTypes.Devices.enabled
Description: Enable or disable caching globally
Current value: true
```

**Issues**:
1. **Unclear parameter names**: `cacheTypes.Devices.enabled` doesn't clearly indicate this is the "Devices Cache: Enabled" setting
2. **Generic descriptions**: "Enable or disable caching globally" was used for both global and cache-type-specific settings
3. **Poor user experience**: Users had to mentally parse technical paths to understand what they were configuring

## Solution

### 1. Human-Readable Display Names (`Get-SettingDisplayName`)

Added a new helper function that converts technical paths to user-friendly names:

**Technical Path** → **Display Name**
- `cacheTypes.Devices.enabled` → `Devices Cache: Enabled`
- `cacheTypes.Configuration.expirationMinutes` → `Configuration Cache: Expiration (minutes)`
- `cacheTypes.DirectoryObjects.enabled` → `DirectoryObjects Cache: Enabled`
- `enabled` → `enabled` (global setting - unchanged)
- `repoInfo.companyName` → `Repository: Company Name`

#### Implementation Details
```powershell
function Get-SettingDisplayName() {
    param([string]$SettingPath, [string]$SettingName)
    
    # Handles cache types: "cacheTypes.Type.Property" → "Type Cache: Property"
    # Handles repo info: "repoInfo.Property" → "Repository: Property"
    # Generic nested: "section.property" → "Section: Property"
    # Non-nested: returns original name
}
```

### 2. Context-Aware Descriptions (`Get-SettingDescription`)

Extended the description function to accept both `SettingName` and `SettingPath` parameters, enabling context-specific descriptions:

**Global vs Cache-Type-Specific**:

| Path | Setting Name | Old Description | New Description |
|------|--------------|-----------------|-----------------|
| `enabled` | `enabled` | "Enable or disable caching globally" | "Enable or disable caching globally across all cache types" |
| `cacheTypes.Devices.enabled` | `enabled` | "Enable or disable caching globally" | "Enable or disable caching for Devices data" |
| `defaultExpirationMinutes` | `defaultExpirationMinutes` | "Default cache expiration time in minutes" | "Default expiration time for cache entries (in minutes) when not overridden by cache type" |
| `cacheTypes.Configuration.expirationMinutes` | `expirationMinutes` | "Configuration setting: expirationMinutes" | "How long to cache Configuration data before refreshing (in minutes)" |

#### Implementation Details
```powershell
function Get-SettingDescription() {
    param([string]$SettingName, [string]$SettingPath = '')
    
    # Detects nested cache settings: "cacheTypes.*.*"
    # Returns cache-type-specific descriptions
    # Falls back to general description table
}
```

### 3. Updated Display Logic

Modified the settings editor loop to use the new functions:

```powershell
# OLD: Used raw path or simple name
$displayName = if ($isNested) { $settingPath } else { $settingName }
Write-Host "Description: $(Get-SettingDescription -SettingName $settingName)"

# NEW: Uses human-readable names and context-aware descriptions
$displayName = Get-SettingDisplayName -SettingPath $settingPath -SettingName $settingName
Write-Host "Description: $(Get-SettingDescription -SettingName $settingName -SettingPath $settingPath)"
```

## User Experience Comparison

### Before
```
Setting: cacheTypes.Devices.enabled
Description: Enable or disable caching globally
Current value: true

Setting: cacheTypes.Devices.expirationMinutes
Description: Configuration setting: expirationMinutes
Current value: 15
```

### After
```
Setting: Devices Cache: Enabled
Description: Enable or disable caching for Devices data
Current value: true

Setting: Devices Cache: Expiration (minutes)
Description: How long to cache Devices data before refreshing (in minutes)
Current value: 15
```

## Benefits

1. **Clarity**: Users immediately understand what each setting controls
2. **Context**: Descriptions distinguish between global and cache-type-specific settings
3. **Consistency**: Same approach works for repoInfo and other nested settings
4. **Maintainability**: Centralized display logic makes future enhancements easier
5. **Backward Compatibility**: Internal storage format unchanged; only display is affected

## Technical Details

### PowerShell 5.1 Compatibility

Initial implementation used string interpolation with colons, which failed in PowerShell 5.1:
```powershell
# BROKEN in PS 5.1
return "$cacheType Cache: $propertyDisplay"
# PowerShell interprets "Cache:" as a drive specification
```

**Fix**: Used string concatenation instead:
```powershell
# WORKS in PS 5.1 and 7+
return $cacheType + ' Cache: ' + $propertyDisplay
```

### Supported Nested Structures

1. **Cache Types** (`cacheTypes.Type.Property`):
   - Types: `Devices`, `Configuration`, `DirectoryObjects`
   - Properties: `enabled`, `expirationMinutes`, `maxSize`

2. **Repository Info** (`repoInfo.Property`):
   - Properties: `repoPath`, `baseURL`, `baseSourceURL`, `repoName`, `companyName`, `supportEmail`, etc.

3. **Generic Nested** (automatic camelCase to Title Case conversion):
   - Example: `section.myPropertyName` → `Section: My Property Name`

### Testing

All changes validated with:
- ✅ **Integration Tests**: 20/20 passed (`SettingsEditors.Tests.ps1`)
- ✅ **PowerShell 5.1 Syntax**: Validated with PSParser
- ✅ **PowerShell 5.1 Execution**: Function loading and execution confirmed
- ✅ **Manual Testing**: Verified display names and descriptions for all cache types

## Future Enhancements

### Potential Improvements
1. **Acronym Handling**: Currently "baseURL" displays as "Base U R L" - could add special case handling for common acronyms
2. **Custom Display Mappings**: Could add configuration file for custom display name overrides
3. **Localization**: Could extend to support multiple languages for display names/descriptions
4. **Help Text**: Could add extended help/examples for complex settings

### Extension Pattern
To add human-readable names for new nested settings:

1. **Add to `Get-SettingDisplayName`**:
   ```powershell
   if ($pathParts[0] -eq 'newSection' -and $pathParts.Count -eq 2) {
       $property = $pathParts[1]
       $propertyDisplay = Convert-CamelCaseToTitleCase $property
       return 'New Section: ' + $propertyDisplay
   }
   ```

2. **Add to `Get-SettingDescription`**:
   ```powershell
   if ($SettingPath -like 'newSection.*') {
       switch ($pathParts[1]) {
           'property1' { return "Description for property1" }
           'property2' { return "Description for property2" }
       }
   }
   ```

3. **Add base descriptions** to the `$descriptions` hashtable for non-nested lookups

## Related Documentation

- **Settings Architecture**: `docs/architecture/Unified-Selection-Architecture.md`
- **Settings Utilities**: `functions/utilityFunctions/Settings-Utilities.ps1`
- **Settings Editor**: `functions/setupFunctions/Show-SettingsEditor.ps1`
- **Cache Settings Editor**: `functions/setupFunctions/Show-CacheSettingsEditor.ps1`
- **Integration Tests**: `tests/Integration/SettingsEditors.Tests.ps1`

## Notes

- **Storage Format**: Internal `.psd1` file format remains unchanged (`cacheTypes.Devices.enabled`)
- **Display Only**: This enhancement affects only how settings are presented to users
- **No Breaking Changes**: All existing functionality preserved
- **Cross-Platform**: Works identically on Windows, macOS, and Linux
- **PowerShell Versions**: Compatible with both PowerShell 5.1 and 7+
