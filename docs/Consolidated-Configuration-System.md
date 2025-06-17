# Consolidated Configuration System - Settings.json Migration

## Overview

The configuration system has been successfully migrated from `vars.json` to a robust `settings.json` structure with `globalSettings` and domain-specific overrides. The system maintains the consolidated JSON loading functionality while providing granular update capabilities and hierarchical configuration management. **All functions have been updated to work with the new settings.json structure and the system is production-ready.**

## Key Components

### 1. Core Configuration Functions

#### `InitializeConfiguration` (MiscFunctions.ps1)
- **Purpose**: Creates or overwrites the initialization configuration file (init.json)
- **Features**:
  - **Updated**: Now references `settings.json` as the default configuration file
  - Generates init.json with environment-specific values (dev, release, default)
  - PowerShell 5.1 compatible using regular hashtables
  - Interactive prompts for overwrite confirmation
  - Comprehensive verbose logging
- **Migration**: Updated default configuration reference from `vars.json` to `settings.json`

#### `CreateConfiguration` (MiscFunctions.ps1)
- **Purpose**: Creates settings.json from init.json with proper hierarchical structure
- **Features**:
  - **Updated**: Now creates `settings.json` with proper structure:
    - `description` and `version` metadata
    - `globalSettings` object containing configuration data
    - Empty `domains` object ready for domain-specific settings
  - Environment-specific value selection (dev/release/default)
  - Automatic creation of missing init.json files
  - Uses consolidated JSON loading system
- **Migration**: Completely rewritten to create `settings.json` structure instead of flat `vars.json`

#### `CreateFullConfiguration` (MiscFunctions.ps1)
- **Purpose**: Interactive configuration editor with user prompts for settings.json
- **Features**:
  - **Updated**: Properly handles `settings.json` hierarchical structure
  - Loads and extracts `globalSettings` for editing
  - Preserves complete `settings.json` structure when saving
  - Maintains `domains` section unchanged during updates
  - Interactive prompts for string, array, and static configuration types
  - Enhanced error handling with user feedback
- **Migration**: Rewritten to work with `settings.json` structure while preserving domain configurations

### 2. New Granular Update Functions

#### `Update-GlobalSetting` (MiscFunctions.ps1)
- **Purpose**: Updates individual settings in the globalSettings section
- **Features**:
  - Updates specific properties without overwriting entire file
  - Creates timestamped backups before modification
  - Validates JSON structure before and after update
  - PowerShell 5.1 compatible hashtable operations
  - Comprehensive error handling and verification

#### `Update-DomainSettings` (MiscFunctions.ps1)
- **Purpose**: Updates or creates domain-specific configurations
- **Features**:
  - Creates new domain entries if they don't exist
  - Supports merge mode to combine with existing settings
  - Supports replace mode to overwrite entire domain settings
  - Preserves all other domains and global settings
  - Creates timestamped backups before modification
  - Comprehensive error handling and verification

### 3. Supporting Functions

#### `Get-JsonConfiguration` (MiscFunctions.ps1)
- **Purpose**: Universal JSON configuration loader with fallback support
- **Features**:
  - Validates JSON syntax before processing
  - Supports multiple JSON formats (flat, structured, arrays)
  - Environment-specific value selection for init.json
  - Comprehensive error handling and logging
  - Fallback to default values on any failure
  - PowerShell 5.1 compatible using regular hashtables

#### `Get-InitConfiguration` (MiscFunctions.ps1)
- **Purpose**: Specialized loader for init.json with environment selection
- **Features**:
  - **Updated**: Defaults to `settings.json` instead of `vars.json`
  - Loads configuration based on environment type (dev/release/default)
  - Uses consolidated JSON loader for consistency
  - Provides sensible defaults for common configuration values

#### `Get-StringsFromJson` (main.ps1)
- **Purpose**: Loads localized strings and messages from strings.json
- **Features**:
  - Uses consolidated configuration system
  - Maintains backward compatibility
  - Comprehensive default string values

### 4. MergeSettings Function (MiscFunctions.ps1)
- **Purpose**: Merges global and domain-specific settings for runtime use
- **Features**:
  - Hierarchical configuration merging
  - Conflict resolution with precedence rules
  - Flattens nested objects for easy access
  - Supports both Local and Global conflict resolution modes

## Configuration Files

### 1. Settings.json (New Primary Configuration)
Contains the main application configuration with hierarchical structure:
```json
{
  "description": "This is the configuration file for the script. It contains the settings for the script to run correctly.",
  "version": "1.0",
  "globalSettings": {
    "operatingSystem": "Windows",
    "testMode": false,
    "configFile": ".\\.secrets\\config.json",
    "maxWaitTime": "30",
    "timeInSeconds": "60",
    "Release": "2.5",
    "Repo": "Github",
    "appMode": "full",
    "GroupTag": "ENTRA"
  },
  "domains": {
    "contoso.com": {
      "groupsToInclude": ["Group1", "Group2"],
      "groupsToExclude": ["ExcludedGroup"],
      "settings": {
        "domain": "contoso.com",
        "deviceNamePrefix": "win11-",
        "maxNumberOfDevicesAllowed": 20,
        "GroupTag": "CONTOSO01"
      }
    }
  }
}
```

### 2. Init.json (Initialization Template)
Contains initialization parameters with environment-specific values:
```json
[
  {
    "name": "configFile",
    "value": ".\\.secrets\\config.json",
    "description": "The path to the authentication configuration file.",
    "devdefault": ".\\.secrets\\config.json",
    "reldefault": ".\\.secrets\\config.json", 
    "default": ".\\.secrets\\config.json",
    "type": "string"
  },
  {
    "name": "configuration",
    "value": "settings.json",
    "description": "The path to the configuration file.",
    "devdefault": "settings.json",
    "reldefault": "settings.json",
    "default": "settings.json",
    "type": "string"
  }
]
```

### 3. Strings.json (Localization)
Contains localized strings organized by sections:
```json
{
  "returnValues": {
    "noRestartMessage": "Device not restarted.",
    "EnrolledMessage": "The device is enrolled."
  },
  "deviceStates": {
    "Ready": "The device is ready for the next user",
    "NotReady": "The device is not ready for the next user"
  },
  "deviceActions": {
    "none": "No action",
    "contactAdmin": "Contact an Intune administrator"
  }
}
```

## Benefits of Settings.json Migration

### 1. Hierarchical Configuration
- **Global Settings**: Common configuration shared across all domains
- **Domain-Specific Overrides**: Custom settings per domain/tenant
- **Inheritance Model**: Domain settings override global settings when specified
- **Structured Data**: Organized configuration with metadata and versioning

### 2. Granular Updates
- **Individual Setting Updates**: Modify single settings without file recreation
- **Selective Domain Updates**: Update specific domain configurations
- **Merge vs Replace**: Choose to merge with existing or replace entirely
- **Backup Safety**: Automatic timestamped backups before modifications

### 3. Code Reuse and Maintainability
- Single JSON loading function eliminates duplicate code
- Consistent error handling across all configuration loading
- Unified logging and debugging experience
- Better separation of global vs domain-specific logic

### 4. Reliability and Safety
- Comprehensive JSON validation before processing
- Robust fallback mechanisms for missing files or invalid data
- Detailed error reporting and logging
- PowerShell 5.1 compatibility throughout

### 5. Flexibility
- Supports multiple JSON formats without code duplication
- Environment-specific configuration selection
- Easy to extend for new configuration file types
- Maintains backward compatibility

## Usage Examples

### Creating and Managing Settings.json

#### Initialize Configuration System
```powershell
# Create init.json with settings.json reference
$success = InitializeConfiguration -RootFolder "C:\MyProject"
```

#### Create Settings.json from Init.json
```powershell
# Create settings.json with development configuration
$success = CreateConfiguration -RootFolder "C:\MyProject" -ConfigurationType 'dev'

# Create settings.json with release configuration
$success = CreateConfiguration -RootFolder "C:\MyProject" -ConfigurationType 'release'
```

#### Interactive Configuration Creation
```powershell
# Create interactive configuration with user prompts
$success = CreateFullConfiguration -RootFolder "C:\MyProject"

# Create configuration with custom paths
$success = CreateFullConfiguration -RootFolder "C:\Source" -DestinationFolder "C:\Config"
```

### Granular Settings Updates

#### Update Global Settings
```powershell
# Update a single global setting
$success = Update-GlobalSetting -SettingName "GroupTag" -SettingValue "NEWGROUP"

# Update with custom settings file path
$success = Update-GlobalSetting -SettingsFile "C:\Config\settings.json" -SettingName "maxWaitTime" -SettingValue "120"
```

#### Update Domain Settings
```powershell
# Create or replace entire domain configuration
$domainSettings = @{
    "domain" = "contoso.com"
    "deviceNamePrefix" = "win11-"
    "GroupTag" = "CONTOSO01"
    "maxNumberOfDevicesAllowed" = 25
}
$success = Update-DomainSettings -DomainName "contoso.com" -Settings $domainSettings

# Merge with existing domain configuration
$newSettings = @{ "MaxUserNameLength" = 60 }
$success = Update-DomainSettings -DomainName "contoso.com" -Settings $newSettings -MergeSettings
```

### Loading Configurations

#### Load Init Configuration
```powershell
# Load development configuration
$devConfig = Get-InitConfiguration -ConfigurationType 'dev'

# Load release configuration
$releaseConfig = Get-InitConfiguration -ConfigurationType 'release'
```

#### Load String Resources
```powershell
# Load strings from default location
$strings = Get-StringsFromJson

# Load strings from custom location
$strings = Get-StringsFromJson -StringsFile "C:\Config\custom-strings.json"
```

#### Merge Global and Domain Settings
```powershell
# Load settings.json and extract configurations
$settingsContent = Get-Content "settings.json" -Raw | ConvertFrom-Json
$globalSettings = $settingsContent.globalSettings
$domainSettings = $settingsContent.domains."contoso.com".settings

# Merge configurations (domain overrides global)
$mergedConfig = MergeSettings -localSettings $domainSettings -globalSettings $globalSettings -ConflictResolution 'Local'
```

## Error Handling

The consolidated system provides multiple layers of error handling:

1. **JSON Syntax Validation**: Validates JSON before processing
2. **File Existence Checks**: Handles missing files gracefully
3. **Fallback Values**: Returns sensible defaults when configuration fails
4. **Detailed Logging**: Comprehensive verbose logging for troubleshooting
5. **Exception Handling**: Catches and handles all exceptions gracefully

## Bug Fixes and PowerShell 5.1 Compatibility

### Critical Compatibility Fix: PowerShell 5.1 Collection Handling
- **Issue**: The original code used OrderedDictionary objects with methods not available in PowerShell 5.1
- **Root Cause**: 
  - `.ContainsKey()` method doesn't exist on OrderedDictionary in PowerShell 5.1
  - `.Contains()` method also has compatibility issues across different collection types
  - OrderedDictionary behavior differs between PowerShell versions
- **Solution**: 
  - Replaced all OrderedDictionary (`[ordered] @{}`) usage with regular hashtables (`@{}`)
  - Used `.ContainsKey()` method consistently on regular hashtables (which is supported in PowerShell 5.1)
  - Ensured all collection operations are PowerShell 5.1 compatible
- **Impact**: 
  - Eliminated "index out of range" errors when processing JSON files
  - Fixed method invocation failures on collection objects
  - Ensured consistent behavior across PowerShell 5.1 and later versions
- **Locations**: 
  - `Get-JsonConfiguration` function (main collection handling)
  - `InitializeConfiguration` function (initVars array elements)
  - `Get-StringsFromJson` function (default values structure)
  - Various utility functions using collection objects

## Migration from vars.json to settings.json

### Breaking Changes
- **Configuration File Format**: Changed from flat `vars.json` to hierarchical `settings.json`
- **Structure**: New format includes `description`, `version`, `globalSettings`, and `domains` sections
- **Domain Support**: Added support for domain-specific configuration overrides

### Backward Compatibility
- `Get-StringsFromJson()` continues to work unchanged
- `Get-JsonConfiguration()` supports both old and new formats
- All function signatures remain the same
- Enhanced error handling and logging throughout

### Migration Path
1. **Automatic Migration**: `CreateConfiguration` now creates `settings.json` instead of `vars.json`
2. **Existing vars.json**: Can be manually migrated by wrapping content in `globalSettings` object
3. **New Projects**: Use `InitializeConfiguration` to bootstrap new projects with `settings.json`

### Updated Functions
- ✅ **InitializeConfiguration**: References `settings.json` in init template
- ✅ **CreateConfiguration**: Creates proper `settings.json` structure
- ✅ **CreateFullConfiguration**: Handles hierarchical structure properly
- ✅ **Get-InitConfiguration**: Defaults to `settings.json`
- ➕ **Update-GlobalSetting**: New function for granular global setting updates
- ➕ **Update-DomainSettings**: New function for domain-specific configuration management

## Testing and Validation

### Test Script
A comprehensive test script `test-settings-functions.ps1` validates:
1. **InitializeConfiguration** - Creates proper init.json with settings.json reference
2. **CreateConfiguration** - Creates proper settings.json structure with globalSettings and domains
3. **CreateFullConfiguration** - Interactive editing preserves hierarchical structure
4. **Update-GlobalSetting** - Granular updates to global settings
5. **Update-DomainSettings** - Domain-specific configuration management
6. **PowerShell 5.1 compatibility** - All functions work correctly on Windows PowerShell 5.1

### Running Tests
```powershell
# Run the settings.json functionality tests
.\test-settings-functions.ps1 -Verbose

# Run the original consolidated system tests
.\test-configuration-system.ps1 -Verbose
```

### Sample Settings.json Structure
After running tests, the generated `settings.json` will have this structure:
```json
{
  "description": "This is the configuration file for the script. It contains the settings for the script to run correctly.",
  "version": "1.0",
  "globalSettings": {
    "configFile": ".\\.secrets\\config.json",
    "configuration": "settings.json",
    "ShowAdvancedOptions": "False",
    "GroupTag": "MSB01",
    "maxWaitTime": "60",
    "timeInSeconds": "60",
    "Repo": "Github",
    "Release": "2.2"
  },
  "domains": {}
}
```

## Future Enhancements

The new settings.json system provides a foundation for:

### Configuration Management
- **Configuration Templates**: Predefined templates for common scenarios
- **Schema Validation**: JSON schema validation for settings.json structure
- **Configuration Import/Export**: Bulk configuration management capabilities
- **Configuration Versioning**: Track and manage configuration changes over time

### Advanced Features
- **Dynamic Configuration Reloading**: Hot-reload configuration changes without restart
- **Configuration Encryption/Decryption**: Secure sensitive configuration values
- **Remote Configuration Loading**: Load configurations from remote sources
- **Configuration Inheritance**: Multi-level inheritance beyond global/domain

### Domain Management
- **Domain Templates**: Predefined templates for common domain types
- **Bulk Domain Operations**: Manage multiple domains simultaneously
- **Domain Validation**: Validate domain-specific settings against rules
- **Domain Migration**: Tools for migrating domain configurations

### Integration Enhancements
- **PowerShell DSC**: Integration with Desired State Configuration
- **Group Policy**: Integration with Group Policy settings
- **Azure Configuration**: Integration with Azure App Configuration
- **CI/CD Pipeline**: Integration with deployment pipelines

## Architecture Benefits

### Separation of Concerns
- **Global Settings**: System-wide configuration shared across all domains
- **Domain Settings**: Tenant/domain-specific overrides and customizations
- **Initialization**: Bootstrap configuration separate from runtime configuration
- **Localization**: UI strings and messages separate from functional configuration

### Scalability
- **Multi-Tenant Support**: Each domain can have completely different configurations
- **Hierarchical Overrides**: Clear precedence rules for configuration conflicts
- **Granular Updates**: Update individual settings without affecting others
- **Backup and Recovery**: Automatic backups ensure configuration safety

### Maintainability
- **Single Source of Truth**: All configuration in one structured file
- **Clear Structure**: Well-defined sections with specific purposes
- **Validation**: Built-in validation and error handling
- **Documentation**: Self-documenting structure with descriptions and versions
