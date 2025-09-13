# Overwrite Settings Architecture Design

## Overview

This document outlines the design for centralizing overwrite settings configuration in `Get-ApplicationDefaults` to enable consistent force-overwrite capability across both global and domain-specific settings.

## Current State

- `Merge-ConfigurationDefaults` has an `OverwriteSettings` parameter for forcing specific settings
- Domain settings are processed separately in `Initialize-LocalSettings` and don't use `Merge-ConfigurationDefaults`
- No unified way to force overwrite settings across both global and domain configurations

## Proposed Solution

### 1. Overwrite Configuration Object Structure

The `Get-ApplicationDefaults` function will return an overwrite configuration object when requested:

```powershell
$overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
```

**Object Structure:**
```powershell
@{
    # Global settings that should be forcibly overwritten
    GlobalSettings = @{
        "CheckForUpdates" = $true
        "autoUpdate" = $true
        "showLicenseBanner" = $false
    }
    
    # Domain/local settings that should be forcibly overwritten  
    LocalSettings = @{
        "deviceContactThresholdInDays" = 30
        "maxWaitTime" = 30
        "testMode" = $false
    }
    
    # Universal settings that apply to both global and local contexts
    # These will be applied to both global and domain settings
    UniversalSettings = @{
        "operatingSystem" = "Windows"
        "repo" = "Github"
    }
}
```

### 2. Target Location Specification

Each overwrite setting category specifies where the setting should be applied:

- **GlobalSettings**: Applied only to global configuration during global settings processing
- **LocalSettings**: Applied only to domain/local configuration during domain settings processing  
- **UniversalSettings**: Applied to both global and domain configurations

### 3. Consumption by Settings Functions

#### Global Settings Processing
```powershell
function Initialize-GlobalSettings {
    # Get overwrite configuration
    $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
    
    # Combine global and universal overwrites
    $globalOverwrites = @{}
    if ($overwriteConfig.GlobalSettings) {
        $globalOverwrites += $overwriteConfig.GlobalSettings
    }
    if ($overwriteConfig.UniversalSettings) {
        $globalOverwrites += $overwriteConfig.UniversalSettings
    }
    
    # Apply to global settings processing
    # Use existing merge logic with the combined overwrites
}
```

#### Local/Domain Settings Processing  
```powershell
function Initialize-LocalSettings {
    # Get overwrite configuration
    $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
    
    # Combine local and universal overwrites
    $localOverwrites = @{}
    if ($overwriteConfig.LocalSettings) {
        $localOverwrites += $overwriteConfig.LocalSettings
    }
    if ($overwriteConfig.UniversalSettings) {
        $localOverwrites += $overwriteConfig.UniversalSettings
    }
    
    # Apply to domain settings processing
    # Implement new merge logic for domain settings
}
```

### 4. Backward Compatibility

- The `OverwriteSettings` parameter will be removed from `Merge-ConfigurationDefaults`
- Existing callers will continue to work but will no longer have overwrite capability through that function
- New overwrite mechanism will be the only way to force setting values

### 5. Configuration Maintenance

The overwrite configuration will be maintained directly in `Get-ApplicationDefaults` making it:
- Easy to modify without changing multiple files
- Centrally documented and visible
- Version controlled with the application defaults
- Testable as part of the defaults system

## Implementation Plan

1. **Add Overwrite case to Get-ApplicationDefaults**
   - Define the overwrite configuration structure
   - Return appropriate overwrite object

2. **Update Initialize-GlobalSettings**
   - Retrieve overwrite configuration
   - Apply global and universal overwrites

3. **Update Initialize-LocalSettings** 
   - Retrieve overwrite configuration
   - Apply local and universal overwrites
   - Implement domain-specific overwrite processing

4. **Remove OverwriteSettings from Merge-ConfigurationDefaults**
   - Remove the parameter and related logic
   - Update function documentation

5. **Add comprehensive testing**
   - Test overwrite configuration retrieval
   - Test global settings overwrite application
   - Test domain settings overwrite application
   - Test universal settings application to both contexts

## Benefits

- **Centralized Configuration**: All overwrite settings defined in one location
- **Clear Targeting**: Explicit specification of where settings should be applied
- **Consistent Behavior**: Same overwrite mechanism for both global and domain settings
- **Maintainable**: Easy to add/remove/modify overwrite settings
- **Testable**: Can be tested independently of the merge functions