# PowerShell 5.1 JSON Helper Functions Documentation

## Overview

This documentation describes the JSON helper functions created to solve PowerShell 5.1 formatting issues with nested objects in JSON files, specifically for the Intune Autopilot helpdesk script's `settings.json` configuration file.

## The Problem

PowerShell 5.1's `ConvertTo-Json` cmdlet has known limitations when working with complex nested objects:
- Formatting becomes inconsistent at third-level nesting and beyond
- Object serialization can break even with proper `-Depth` parameters
- Nested hashtables and PSCustomObjects don't always serialize correctly
- JSON output can become malformed or unreadable

## The Solution

Two helper function files have been created in the `functions/` directory:

1. **`JsonHelperFunctions.ps1`** - Core JSON serialization improvements
2. **`SettingsHelperFunctions.ps1`** - Settings-specific helper functions

---

## JsonHelperFunctions.ps1

### ConvertTo-JsonCompatible

**Purpose:** Replaces `ConvertTo-Json` with improved PowerShell 5.1 compatibility for nested objects.

**Syntax:**
```powershell
ConvertTo-JsonCompatible -InputObject <Object> [-Depth <Int32>] [-Compress] [-EscapeHandling <String>]
```

**Parameters:**
- `InputObject` - The object to convert to JSON
- `Depth` - Maximum depth of nested objects to serialize (default: 10)
- `Compress` - Output JSON in compressed format (no formatting)
- `EscapeHandling` - How to handle special characters (Default, EscapeNonAscii, EscapeHtml)

**Example:**
```powershell
# Instead of this (which causes formatting issues):
$settings | ConvertTo-Json -Depth 10 | Set-Content -Path "settings.json"

# Use this:
$settings | ConvertTo-JsonCompatible -Depth 10 | Set-Content -Path "settings.json"
```

### Save-JsonToFile

**Purpose:** Safely saves JSON content to a file with validation and error handling.

**Syntax:**
```powershell
Save-JsonToFile -JsonContent <String> -FilePath <String> [-Encoding <String>] [-Force]
```

**Parameters:**
- `JsonContent` - The JSON string content to save
- `FilePath` - The path where to save the JSON file
- `Encoding` - Text encoding to use (default: UTF8)
- `Force` - Overwrite existing files without prompting

**Example:**
```powershell
$settings | ConvertTo-JsonCompatible | Save-JsonToFile -FilePath "settings.json" -Force
```

### Test-JsonContent

**Purpose:** Validates if a string contains valid JSON content.

**Syntax:**
```powershell
Test-JsonContent -JsonString <String> [-ShowErrors]
```

**Parameters:**
- `JsonString` - The JSON string to validate
- `ShowErrors` - Display detailed error information if validation fails

**Example:**
```powershell
if (Test-JsonContent -JsonString $jsonData -ShowErrors) {
    Write-Host "JSON is valid"
} else {
    Write-Warning "JSON is malformed"
}
```

---

## SettingsHelperFunctions.ps1

### Read-SettingsFile

**Purpose:** Safely reads and parses the settings.json file with error handling.

**Syntax:**
```powershell
Read-SettingsFile -FilePath <String> [-CreateIfMissing]
```

**Parameters:**
- `FilePath` - Path to the settings JSON file
- `CreateIfMissing` - Create a default settings file if it doesn't exist

**Example:**
```powershell
# Your current way:
$settings = Get-Content -Path "settings.json" | ConvertFrom-Json

# Better way with error handling:
$settings = Read-SettingsFile -FilePath "settings.json"
```

### Update-SettingsProperty

**Purpose:** Safely updates nested properties in settings objects using dot notation.

**Syntax:**
```powershell
Update-SettingsProperty -Settings <Object> -Path <String> -Value <Object>
```

**Parameters:**
- `Settings` - The settings object to update
- `Path` - Dot-separated path to the property (e.g., "domains.gao.gov.settings.maxNumberOfDevicesAllowed")
- `Value` - The new value to set

**Example:**
```powershell
# Instead of direct property assignment which can break formatting:
$settings.domains."gao.gov".settings.maxNumberOfDevicesAllowed = 25

# Use the helper function:
$settings = Update-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -Value 25
```

### Get-SettingsProperty

**Purpose:** Safely retrieves nested property values using dot notation.

**Syntax:**
```powershell
Get-SettingsProperty -Settings <Object> -Path <String> [-DefaultValue <Object>]
```

**Parameters:**
- `Settings` - The settings object to read from
- `Path` - Dot-separated path to the property
- `DefaultValue` - Value to return if property doesn't exist

**Example:**
```powershell
$maxDevices = Get-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -DefaultValue 20
```

### Save-Settings

**Purpose:** Saves settings object to JSON file with proper formatting and validation.

**Syntax:**
```powershell
Save-Settings -Settings <Object> -FilePath <String> [-CreateBackup]
```

**Parameters:**
- `Settings` - The settings object to save
- `FilePath` - Path where to save the settings file
- `CreateBackup` - Create a backup of the existing file before saving

**Example:**
```powershell
# Instead of:
$settings | ConvertTo-Json -Depth 10 | Set-Content -Path "settings.json"

# Use:
Save-Settings -Settings $settings -FilePath "settings.json" -CreateBackup
```

---

## Implementation Guide

### Step 1: Load the Functions

Add this to the top of your PowerShell scripts:

```powershell
# Load the helper functions
. "$PSScriptRoot\functions\JsonHelperFunctions.ps1"
. "$PSScriptRoot\functions\SettingsHelperFunctions.ps1"
```

### Step 2: Update Your Existing Code

#### Reading Settings
```powershell
# Old way:
$settings = Get-Content -Path "settings.json" | ConvertFrom-Json

# New way:
$settings = Read-SettingsFile -FilePath "settings.json"
```

#### Updating Nested Properties
```powershell
# Old way (can break formatting):
$settings.domains."gao.gov".settings.maxNumberOfDevicesAllowed = 25
$settings.globalSettings.Release = "2.6"

# New way (preserves formatting):
$settings = Update-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -Value 25
$settings = Update-SettingsProperty -Settings $settings -Path "globalSettings.Release" -Value "2.6"
```

#### Saving Settings
```powershell
# Old way (can cause formatting issues):
$settings | ConvertTo-Json -Depth 10 | Set-Content -Path "settings.json"

# New way (preserves formatting):
Save-Settings -Settings $settings -FilePath "settings.json" -CreateBackup
```

### Step 3: Complete Example

Here's a complete example showing how to safely modify your settings.json:

```powershell
# Load helper functions
. "$PSScriptRoot\functions\JsonHelperFunctions.ps1"
. "$PSScriptRoot\functions\SettingsHelperFunctions.ps1"

try {
    # Read settings safely
    $settings = Read-SettingsFile -FilePath "settings.json"
    
    # Update existing properties
    $settings = Update-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -Value 30
    $settings = Update-SettingsProperty -Settings $settings -Path "globalSettings.Release" -Value "2.6"
    
    # Add a new domain configuration
    $newDomainSettings = @{
        groupsToInclude = @()
        groupsToExclude = @()
        settings = @{
            domain = "newdomain.com"
            deviceNamePrefix = "new-"
            maxNumberOfDevicesAllowed = 10
            MaxUserNameLength = 50
            MinUsernameLength = 3
            MaxSerialNumberLength = 100
            MinSerialNumberLength = 7
            MinimumDevicePhysicalMemoryInGB = 8
            DesiredAutopilotProfiles = @(
                "Standard Profile"
            )
        }
    }
    
    $settings = Update-SettingsProperty -Settings $settings -Path "domains.newdomain.com" -Value $newDomainSettings
    
    # Save with proper formatting and backup
    Save-Settings -Settings $settings -FilePath "settings.json" -CreateBackup
    
    Write-Host "Settings updated successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to update settings: $($_.Exception.Message)"
}
```

---

## Testing the Functions

### Quick Test Script

Create a test script to verify the functions work with your current settings.json:

```powershell
# test-json-helpers.ps1

# Load functions
. ".\functions\JsonHelperFunctions.ps1"
. ".\functions\SettingsHelperFunctions.ps1"

Write-Host "Testing JSON Helper Functions..." -ForegroundColor Yellow

try {
    # Test 1: Read existing settings
    Write-Host "Test 1: Reading settings.json..." -ForegroundColor Cyan
    $settings = Read-SettingsFile -FilePath "settings.json"
    Write-Host "✓ Successfully read settings" -ForegroundColor Green
    
    # Test 2: Update a property
    Write-Host "Test 2: Updating a nested property..." -ForegroundColor Cyan
    $originalValue = Get-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed"
    Write-Host "Original value: $originalValue"
    
    $settings = Update-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -Value 99
    $newValue = Get-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed"
    Write-Host "New value: $newValue"
    Write-Host "✓ Successfully updated nested property" -ForegroundColor Green
    
    # Test 3: Save to test file
    Write-Host "Test 3: Saving formatted JSON..." -ForegroundColor Cyan
    Save-Settings -Settings $settings -FilePath "settings-test.json"
    Write-Host "✓ Successfully saved test file" -ForegroundColor Green
    
    # Test 4: Validate JSON formatting
    Write-Host "Test 4: Validating JSON formatting..." -ForegroundColor Cyan
    $testContent = Get-Content -Path "settings-test.json" -Raw
    if (Test-JsonContent -JsonString $testContent) {
        Write-Host "✓ JSON formatting is valid" -ForegroundColor Green
    } else {
        Write-Warning "JSON formatting validation failed"
    }
    
    # Restore original value
    $settings = Update-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -Value $originalValue
    
    Write-Host "`nAll tests completed successfully!" -ForegroundColor Green
    Write-Host "Check 'settings-test.json' to compare formatting with original." -ForegroundColor Yellow
}
catch {
    Write-Error "Test failed: $($_.Exception.Message)"
}
```

### Running the Test

```powershell
# Navigate to your autopilot directory
cd "c:\Users\MahmoudZ\code\autopilot"

# Run the test
.\test-json-helpers.ps1
```

---

## Key Benefits

1. **PowerShell 5.1 Compatible** - Specifically designed to handle PowerShell 5.1 limitations
2. **Maintains Formatting** - JSON files remain readable and properly formatted
3. **Error Handling** - Comprehensive error handling and validation
4. **Preserves Structure** - No more broken nested objects or malformed JSON
5. **Verbose Logging** - Detailed logging helps debug issues
6. **Backup Support** - Automatic backup creation before making changes
7. **Dot Notation Support** - Easy access to nested properties using simple paths

---

## Troubleshooting

### Common Issues and Solutions

**Issue: "JSON validation failed"**
- Check that all property names are properly quoted
- Ensure no trailing commas in arrays or objects
- Verify that escape characters are properly handled

**Issue: "Property path not found"**
- Verify the dot notation path is correct
- Check that all intermediate objects exist
- Use `Get-SettingsProperty` with `-DefaultValue` to handle missing properties

**Issue: "PowerShell 5.1 compatibility errors"**
- Ensure you're not using PowerShell 7+ specific syntax
- Use `[ordered]@{}` instead of regular hashtables for better JSON ordering
- Avoid using `&&` operators (not supported in PowerShell 5.1)

### Debug Tips

1. Enable verbose output: `$VerbosePreference = "Continue"`
2. Test JSON validity before saving: `Test-JsonContent -JsonString $json -ShowErrors`
3. Create backups before making changes: `Save-Settings -CreateBackup`
4. Use the test script to verify functionality

---

## Migration from Existing Code

### Find and Replace Patterns

To update your existing scripts, use these find and replace patterns:

1. **Replace ConvertTo-Json calls:**
   ```powershell
   # Find:
   ConvertTo-Json -Depth 10
   
   # Replace with:
   ConvertTo-JsonCompatible -Depth 10
   ```

2. **Replace Get-Content JSON reads:**
   ```powershell
   # Find:
   Get-Content -Path "settings.json" | ConvertFrom-Json
   
   # Replace with:
   Read-SettingsFile -FilePath "settings.json"
   ```

3. **Replace direct property assignments:**
   ```powershell
   # Find:
   $settings.domains."gao.gov".settings.maxNumberOfDevicesAllowed = $value
   
   # Replace with:
   $settings = Update-SettingsProperty -Settings $settings -Path "domains.gao.gov.settings.maxNumberOfDevicesAllowed" -Value $value
   ```

---

## Conclusion

These helper functions provide a robust solution for handling JSON serialization issues in PowerShell 5.1, specifically addressing the nested object formatting problems you were experiencing with your settings.json file. By using these functions, you can ensure that your JSON configuration files maintain proper formatting and structure, even when working with complex nested objects.

For questions or issues, refer to the troubleshooting section or examine the verbose logging output when functions are executed.
