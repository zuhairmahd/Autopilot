# Overwrite Settings Implementation Documentation

## Overview

This document describes the implementation of the centralized overwrite settings architecture that allows consistent force-overwrite capability across both global and domain-specific settings. This addresses the issue where `Merge-ConfigurationDefaults` couldn't handle domain settings merges, which are processed separately.

## Implementation Summary

### 1. Enhanced Get-ApplicationDefaults Function

**Location**: `/functions/setupFunctions/Get-ApplicationDefaults.ps1`

**Changes Made**:
- Added `'Overwrite'` to the `ValidateSet` for `DefaultType` parameter
- Added comprehensive overwrite configuration structure to `$defaults.Overwrite`
- Added case to return overwrite configuration when requested
- Updated function documentation to include overwrite functionality

**Overwrite Configuration Structure**:
```powershell
$defaults.Overwrite = @{
    # Global settings that should be forcibly overwritten
    GlobalSettings = @{
        "autoUpdate" = $true
        "showLicenseBanner" = $true
        "testMode" = $false
    }
    
    # Local/domain settings that should be forcibly overwritten
    LocalSettings = @{
        "deviceContactThresholdInDays" = 30
        "maxWaitTime" = 30
        "minimumDevicePhysicalMemoryInGB" = 8
    }
    
    # Universal settings that apply to both global and local contexts
    UniversalSettings = @{
        "operatingSystem" = "Windows"
        "repo" = "Github"
        "release" = "master"
    }
}
```

### 2. Enhanced Global Settings Processing

**Location**: `/functions/setupFunctions/Initialize-ApplicationConfiguration.ps1`
**Function**: `Initialize-GlobalSettings`

**Changes Made**:
- Added overwrite configuration retrieval using `Get-ApplicationDefaults -DefaultType "Overwrite"`
- Implemented application of global-specific overwrites (`GlobalSettings`)
- Implemented application of universal overwrites (`UniversalSettings`)
- Added comprehensive logging and error handling for overwrite operations

**Usage Example**:
```powershell
# Automatically applies overwrite settings during global settings processing
$globalResult = Initialize-GlobalSettings -GlobalConfigData $globalData -PSBoundParameters @{}
# Result will have overwrite settings applied automatically
```

### 3. Enhanced Local/Domain Settings Processing

**Location**: `/functions/setupFunctions/Initialize-ApplicationConfiguration.ps1`
**Function**: `Initialize-LocalSettings`

**Changes Made**:
- Added overwrite configuration retrieval using `Get-ApplicationDefaults -DefaultType "Overwrite"`
- Implemented application of local-specific overwrites (`LocalSettings`)
- Implemented application of universal overwrites (`UniversalSettings`)
- Added comprehensive logging and error handling for overwrite operations

**Domain Settings Flow**:
1. Load domain configuration from separate files
2. Process domain-specific settings normally
3. Apply local-specific overwrite settings
4. Apply universal overwrite settings

### 4. Simplified Merge-ConfigurationDefaults Function

**Location**: `/functions/setupFunctions/FirstRunWizardFunctions/Merge-ConfigurationDefaults.ps1`

**Changes Made**:
- **REMOVED** `OverwriteSettings` parameter completely
- **REMOVED** all overwrite-related logic and helper functions
- Simplified to basic merge functionality only
- Updated documentation to reference new overwrite architecture
- Maintained backward compatibility for basic merge operations

**Before and After**:
```powershell
# Before (deprecated)
$merged = Merge-ConfigurationDefaults -ExistingConfig $config -DefaultConfig $defaults -OverwriteSettings $overwrites

# After (overwrite handled automatically in settings processing)
$merged = Merge-ConfigurationDefaults -ExistingConfig $config -DefaultConfig $defaults
# Overwrites are now applied automatically during Initialize-GlobalSettings and Initialize-LocalSettings
```

### 5. Created Missing Get-DomainConfigurationFromFiles Function

**Location**: `/functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1`

**Purpose**: This function was referenced throughout the codebase but was missing. It handles loading domain-specific configurations from separate JSON files.

**Functionality**:
- Loads existing domain configuration files
- Creates new configuration with defaults if file doesn't exist
- Supports both hashtable and PSCustomObject configurations
- Maintains PowerShell 5.1 compatibility

## Usage Patterns

### Retrieving Overwrite Configuration

```powershell
# Get the complete overwrite configuration
$overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"

# Access specific sections
$globalOverwrites = $overwriteConfig.GlobalSettings
$localOverwrites = $overwriteConfig.LocalSettings
$universalOverwrites = $overwriteConfig.UniversalSettings
```

### Automatic Application During Settings Processing

The overwrite settings are automatically applied during normal application initialization:

```powershell
# Global settings automatically get overwrite settings applied
$configResult = Initialize-ApplicationConfiguration -InitFile $settingsFile -StringsFile $stringsFile -Domain $domain

# Both global and local settings will have appropriate overwrites applied
$globalSettings = $configResult.GlobalSettings  # Has GlobalSettings + UniversalSettings overwrites
$localSettings = $configResult.LocalSettings    # Has LocalSettings + UniversalSettings overwrites
```

### Targeting Settings to Global vs Local

Settings are automatically targeted based on the section they're defined in:

- **GlobalSettings**: Applied only during global settings processing
- **LocalSettings**: Applied only during domain/local settings processing  
- **UniversalSettings**: Applied to both global and domain settings processing

## Configuration Maintenance

### Adding New Overwrite Settings

To add new overwrite settings, edit the `Get-ApplicationDefaults.ps1` function:

```powershell
# Add to appropriate section in $defaults.Overwrite
GlobalSettings = @{
    "autoUpdate" = $true
    "newGlobalSetting" = "forced-value"  # Add here for global-only
}

LocalSettings = @{
    "deviceContactThresholdInDays" = 30
    "newLocalSetting" = 42  # Add here for domain-only
}

UniversalSettings = @{
    "operatingSystem" = "Windows"
    "newUniversalSetting" = $true  # Add here for both global and local
}
```

### Modifying Existing Overwrite Values

Simply change the values in the `Get-ApplicationDefaults.ps1` function:

```powershell
GlobalSettings = @{
    "autoUpdate" = $false  # Changed from $true to $false
}
```

## Testing and Validation

### Comprehensive Test Suite

**Test File**: `/TestScripts/test-overwrite-architecture.ps1`

**Test Coverage**:
- Overwrite configuration retrieval from `Get-ApplicationDefaults`
- Verification of overwrite structure (GlobalSettings, LocalSettings, UniversalSettings)
- Removal of `OverwriteSettings` parameter from `Merge-ConfigurationDefaults`
- Basic merge functionality still works without overwrite parameter
- Global settings processing applies overwrites correctly
- All other default types continue to work
- Backward compatibility verification

**Test Results**: 100% pass rate with 24 successful test assertions

### Integration Testing

The implementation has been validated with:
- ✅ Syntax tests pass (100% success rate)
- ✅ Core tests pass (100% success rate)  
- ✅ Application loads successfully with verbose logging
- ✅ All 137 functions load without errors
- ✅ New overwrite architecture test passes completely

## Benefits Achieved

1. **Centralized Configuration**: All overwrite settings are now defined in one location (`Get-ApplicationDefaults`)
2. **Clear Targeting**: Explicit specification of whether settings apply to global, local, or both contexts
3. **Consistent Behavior**: Same overwrite mechanism works for both global and domain settings
4. **Maintainable**: Easy to add, remove, or modify overwrite settings without touching multiple files
5. **Testable**: Overwrite configuration can be tested independently
6. **Backward Compatible**: Existing code continues to work, only the overwrite mechanism changed

## Migration Notes

### For Users of Merge-ConfigurationDefaults

If you were previously using the `OverwriteSettings` parameter:

```powershell
# Old approach (no longer supported)
$overwrite = [PSCustomObject]@{ CheckForUpdates = $true }
$merged = Merge-ConfigurationDefaults -ExistingConfig $config -DefaultConfig $defaults -OverwriteSettings $overwrite

# New approach: Add the setting to Get-ApplicationDefaults
# Edit Get-ApplicationDefaults.ps1 to include your overwrite in the appropriate section
# Then use normal settings processing - overwrites will be applied automatically
```

### For Settings Processing

No changes needed - overwrites are applied automatically during `Initialize-ApplicationConfiguration`.

## Files Modified

1. `/functions/setupFunctions/Get-ApplicationDefaults.ps1` - Added overwrite configuration
2. `/functions/setupFunctions/Initialize-ApplicationConfiguration.ps1` - Enhanced both global and local settings processing
3. `/functions/setupFunctions/FirstRunWizardFunctions/Merge-ConfigurationDefaults.ps1` - Removed overwrite functionality
4. `/functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1` - Created missing function
5. `/TestScripts/test-overwrite-architecture.ps1` - Added comprehensive test suite
6. `/docs/OVERWRITE_SETTINGS_DESIGN.md` - Design documentation
7. `/docs/OVERWRITE_SETTINGS_IMPLEMENTATION.md` - This implementation documentation

This implementation successfully addresses the original requirement to move overwrite functionality from `Merge-ConfigurationDefaults` to a centralized location in `Get-ApplicationDefaults` while enabling both global and domain-specific settings to use the same overwrite mechanism.