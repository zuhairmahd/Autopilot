# Settings Migration Implementation

## Overview

The `Invoke-SettingsMigration` function serves as a comprehensive migration wizard that converts JSON configuration files to PowerShell Data File (PSD1) format. It handles both domain-specific configuration files and the global settings.json file.

## Function Architecture

### Main Orchestrator: `Invoke-SettingsMigration`

This is the primary entry point that:
- Scans the specified directory (default: current working directory)
- Identifies files requiring migration
- Coordinates the conversion process
- Provides detailed status reporting
- Optionally removes JSON files after successful migration

### Helper Functions

#### 1. `Convert-DomainJsonToPsd1`
Handles conversion of domain configuration files (e.g., `contoso.com.json` → `contoso.com.psd1`)

#### 2. `Convert-SettingsJsonToPsd1`
Handles conversion of the global `settings.json` → `settings.psd1`

#### 3. `ConvertTo-Psd1Structure`
Transforms domain JSON structure to PSD1 format with domain-specific rules

#### 4. `ConvertTo-SettingsPsd1Structure`
Transforms settings.json structure to settings.psd1 format with global-settings-specific rules

## File Identification

### Domain Files
Files matching the pattern: `^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+\.json$`

Examples:
- `contoso.com.json`
- `arabictutor.com.json`
- `subdomain.example.org.json`

### Settings File
Single file: `settings.json`

## Transformation Rules

### Domain File Transformations

| Source (JSON) | Target (PSD1) | Notes |
|--------------|---------------|-------|
| `settings.appMode` (string) | `appModes` (array) | Converts string to array |
| `settings.*` | `*` (root level) | Flattens settings subkey |
| `settings.appInfo.version` | `version` | Extracts from nested object |
| `settings.appInfo.companyName` | `companyName` | Extracts from nested object |
| `settings.desiredAutopilotProfiles` (array of strings) | `autopilotProfilesToInclude` (array of hashtables) | Transforms strings to `@{id=$null; name="..."}` format |
| `settings.repo` | *(removed)* | Uses `repoInfo` instead |
| `groupsToInclude` | `groupsToInclude` | Preserved at root |
| `groupsToExclude` | `groupsToExclude` | Preserved at root |
| `additionalScopes` | `additionalScopes` | Preserved at root |

**Added Defaults** (if not present):
- `autopilotDeviceAllowedVendors` = `@()`
- `checkStrongMapping` = `$false`
- `strongMappingOptional` = `$true`
- `updateLocalSettings` = `$false`
- `groupTag` = `''`
- `assignedUser` = `''`

#### Autopilot Profiles Transformation Examples

**Input JSON (array of strings):**
```json
"desiredAutopilotProfiles": [
    "windowsCloudConfig Autopilot profile",
    "Hybrid join profile"
]
```

**Output PSD1 (array of hashtables):**
```powershell
autopilotProfilesToInclude = @(
    @{
        id = $null
        name = 'windowsCloudConfig Autopilot profile'
    },
    @{
        id = $null
        name = 'Hybrid join profile'
    }
)
```

**Input JSON (single string):**
```json
"desiredAutopilotProfiles": "Default Profile"
```

**Output PSD1:**
```powershell
autopilotProfilesToInclude = @(
    @{
        id = $null
        name = 'Default Profile'
    }
)
```

**Input JSON (already hashtables with ids):**
```json
"desiredAutopilotProfiles": [
    {
        "id": "edaca6f4-58e4-4a55-a985-52c8f74fb6c4",
        "name": "windowsCloudConfig Autopilot profile"
    }
]
```

**Output PSD1:**
```powershell
autopilotProfilesToInclude = @(
    @{
        id = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
        name = 'windowsCloudConfig Autopilot profile'
    }
)
```


### Settings File Transformations

| Source (JSON) | Target (PSD1) | Notes |
|--------------|---------------|-------|
| `description` | `description` | Preserved at root |
| `version` | `version` | Preserved at root |
| `auth` | `auth` | Preserved as-is |
| `requiredScopes` | `requiredScopes` | Preserved as-is |
| `globalSettings.appMode` (string) | `globalSettings.appModes` (array) | Converts string to array |
| `globalSettings.repo` | *(removed)* | Uses `repoInfo` instead |
| `globalSettings.appInfo` | *(removed)* | Fields extracted to root if needed |
| `menu` | *(removed)* | Not part of PSD1 format |
| `domains` | *(removed)* | Not part of PSD1 format |

## Usage Examples

### Basic Migration
```powershell
# Migrate all JSON files in current directory
$result = Invoke-SettingsMigration

# Check results
if ($result.success) {
    Write-Host "Migration successful!"
    Write-Host "Processed: $($result.totalProcessed)"
    Write-Host "Succeeded: $($result.totalSucceeded)"
}
```

### Migration with JSON Removal
```powershell
# Migrate and remove original JSON files
$result = Invoke-SettingsMigration -RemoveJsonFiles -Force

# Review which files were removed
Write-Host "Removed $($result.removedFileCount) JSON file(s)"
```

### Custom Path with No Validation
```powershell
# Migrate files in specific directory without validation
$result = Invoke-SettingsMigration -SearchPath "C:\Config" -Validate $false
```

## Return Object Structure

```powershell
@{
    success          = $true/$false      # Overall success
    migrationNeeded  = $true/$false      # Were any files found
    settingsFile     = @{                # Settings.json result
        success      = $true/$false
        fileName     = "settings.json"
        outputPath   = "C:\...\settings.psd1"
        errorMessage = $null/"error text"
    }
    domainFiles      = @(                # Array of domain results
        @{
            success      = $true/$false
            fileName     = "contoso.com.json"
            outputPath   = "C:\...\contoso.com.psd1"
            errorMessage = $null/"error text"
        }
    )
    totalProcessed   = 3                 # Total files attempted
    totalSucceeded   = 3                 # Successful conversions
    totalFailed      = 0                 # Failed conversions
    removedFileCount = 3                 # JSON files removed
    errorMessages    = @()               # Array of error messages
}
```

## Dependencies

### Existing Functions Used
- `ConvertFrom-JsonToHashtable` - Converts PSCustomObject to hashtable recursively
- `Export-PowerShellDataFile` - Exports hashtable to PSD1 format with validation

### Required Modules
- All functions from `functions/setupFunctions/FirstRunWizardFunctions/`
- All functions from `functions/utilityFunctions/Export-PowerShellDataFile/`

## Error Handling

The function provides comprehensive error handling:
- **File not found**: Returns `migrationNeeded = false`
- **Parse errors**: Captured in per-file `errorMessage`
- **Export failures**: Captured in per-file `errorMessage`
- **Validation failures**: Captured if `Validate = $true`
- **Removal failures**: Non-fatal, reported separately

All errors are aggregated in the `errorMessages` array of the return object.

## Console Output

The function provides user-friendly console output:
- **Cyan**: Section headers and file names being processed
- **Green**: Success messages with checkmarks (✓)
- **Red**: Error messages with X marks (✗)
- **Yellow**: Warning messages
- **White**: Summary statistics

Example:
```
Migrating settings.json...
  ✓ Successfully migrated settings.json to settings.psd1
Migrating contoso.com.json...
  ✓ Successfully migrated contoso.com.json to contoso.com.psd1

=== Migration Summary ===
Total files processed: 2
Successful migrations: 2
Failed migrations: 0
```

## Best Practices

1. **Always test first**: Run without `-RemoveJsonFiles` initially
2. **Enable validation**: Keep `-Validate $true` (default) for safety
3. **Create backups**: Keep `-CreateBackup $true` (default) when overwriting
4. **Review return object**: Check for partial failures in multi-file scenarios
5. **Use `-Force` carefully**: Only when you're certain about overwriting

## Integration Notes

This function is designed to be called:
- During application startup to detect and migrate legacy JSON configs
- As part of a manual migration process
- From a setup/initialization wizard
- From automated migration scripts

The rich return object enables both interactive and automated scenarios.
