# Function Reference Documentation

This document provides detailed reference information for all PowerShell functions in the Windows Autopilot Management Tool.

## Table of Contents

- [AutopilotDeviceFunctions.ps1](#autopilotdevicefunctionsps1)
- [DeviceAndUserLookupFunctions.ps1](#deviceanduserlookupfunctionsps1)
- [GraphAPIFunctions.ps1](#graphapifunctionsps1)
- [MenuFunctions.ps1](#menufunctionsps1)
- [SettingsHelperFunctions.ps1](#settingshelperfunctionsps1)
- [EncryptionFunctions.ps1](#encryptionfunctionsps1)
- [GetAppAssignmentTypes.ps1](#getappassignmenttypesps1)

## AutopilotDeviceFunctions.ps1

### GetCorpDeviceIdentifier

Retrieves the current device's manufacturer, model, and serial number using WMI.

**Syntax:**
```powershell
GetCorpDeviceIdentifier
```

**Returns:**
PowerShell object with properties:
- `Manufacturer`: Device manufacturer name
- `Model`: Device model name  
- `SerialNumber`: Device serial number

**Example:**
```powershell
$deviceInfo = GetCorpDeviceIdentifier
Write-Host "Device: $($deviceInfo.Manufacturer) $($deviceInfo.Model) - SN: $($deviceInfo.SerialNumber)"
```

### AddCorporateDeviceIdentifier

Adds a device identifier to the corporate device identifiers list in Intune via Microsoft Graph API.

**Syntax:**
```powershell
AddCorporateDeviceIdentifier -AccessToken <String> -DeviceIdentifier <String> -IdentifierType <String> [-OverwriteImportedDeviceIdentities]
```

**Parameters:**
- `AccessToken` (Required): Microsoft Graph API access token
- `DeviceIdentifier` (Required): Device identifier string
- `IdentifierType` (Required): Type of identifier ("SerialNumber", "IMEI", "manufacturerModelSerial")
- `OverwriteImportedDeviceIdentities` (Optional): Switch to overwrite existing entries

**Examples:**
```powershell
# Add by serial number
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"

# Add by IMEI with overwrite
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "123456789012345" -IdentifierType "IMEI" -OverwriteImportedDeviceIdentities

# Add by manufacturer/model/serial composite
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Microsoft Corporation,Virtual Machine,ABC123456789" -IdentifierType "manufacturerModelSerial"
```

### DeleteCorporateDeviceIdentifier

Removes a device identifier from the corporate device identifiers list in Intune via Microsoft Graph API.

**Syntax:**
```powershell
DeleteCorporateDeviceIdentifier -AccessToken <String> -DeviceIdentifier <String> -IdentifierType <String>
```

**Parameters:**
- `AccessToken` (Required): Microsoft Graph API access token
- `DeviceIdentifier` (Required): Device identifier string to remove
- `IdentifierType` (Required): Type of identifier ("SerialNumber", "IMEI", "manufacturerModelSerial")

**Safety Features:**
- Interactive confirmation prompts before deletion
- Automatic verification that device identifier exists
- Post-deletion verification of successful removal
- Comprehensive logging and error handling

**Examples:**
```powershell
# Delete by serial number
DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"

# Delete by manufacturer/model/serial composite
DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "Microsoft Corporation,Virtual Machine,ABC123456789" -IdentifierType "manufacturerModelSerial"
```

## DeviceAndUserLookupFunctions.ps1

### GetUserInput

Collects user input with validation and formatting based on input type.

**Syntax:**
```powershell
GetUserInput -Message <String> -Prompt <String> -InputType <String> -settings <Object>
```

**Parameters:**
- `Message` (Required): Message to display to user
- `Prompt` (Required): Input prompt text
- `InputType` (Required): Type of input validation ("userName", "serialNumber", etc.)
- `settings` (Required): Settings object containing validation parameters

**Returns:**
Validated user input string or navigation command

### GetDeviceByUser

Retrieves devices associated with a specific user.

**Syntax:**
```powershell
GetDeviceByUser -AccessToken <String> -userName <String>
```

**Parameters:**
- `AccessToken` (Required): Microsoft Graph API access token
- `userName` (Required): User email address or username

**Returns:**
Device information object or navigation command

## GraphAPIFunctions.ps1

### Get-AuthToken

Obtains Microsoft Graph API authentication token using specified authentication flow.

**Syntax:**
```powershell
Get-AuthToken -ClientId <String> -TenantId <String> [-ClientSecret <String>] [-CertificateThumbprint <String>] [-AuthType <String>] [-Scope <String[]>]
```

**Parameters:**
- `ClientId` (Required): Azure AD Application ID
- `TenantId` (Required): Azure AD Tenant ID
- `ClientSecret` (Optional): Application secret for confidential client flow
- `CertificateThumbprint` (Optional): Certificate thumbprint for certificate authentication
- `AuthType` (Optional): Authentication type ("PublicAuthFlow", "Interactive", "Private")
- `Scope` (Optional): Array of required scopes

**Returns:**
Authentication token object with access token and metadata

### Invoke-GraphAPIRequest

Makes authenticated requests to Microsoft Graph API endpoints.

**Syntax:**
```powershell
Invoke-GraphAPIRequest -Uri <String> -AccessToken <String> [-Method <String>] [-Body <String>] [-ContentType <String>]
```

**Parameters:**
- `Uri` (Required): Graph API endpoint URI
- `AccessToken` (Required): Valid access token
- `Method` (Optional): HTTP method (default: "GET")
- `Body` (Optional): Request body for POST/PUT operations
- `ContentType` (Optional): Content type header (default: "application/json")

**Returns:**
API response data or error information

## MenuFunctions.ps1

### NewMenu

Creates a new menu object for the menu system.

**Syntax:**
```powershell
NewMenu -Title <String> -Description <String>
```

**Parameters:**
- `Title` (Required): Menu title to display
- `Description` (Required): Menu description/instructions

**Returns:**
Menu object for use with AddMenuItem and ShowMenu

### AddMenuItem

Adds an item to a menu with either an action or submenu.

**Syntax:**
```powershell
AddMenuItem -Menu <Object> -Name <String> [-Action <ScriptBlock>] [-Submenu <Object>]
```

**Parameters:**
- `Menu` (Required): Menu object to add item to
- `Name` (Required): Display name for the menu item
- `Action` (Optional): Script block to execute when item is selected
- `Submenu` (Optional): Submenu object to navigate to when item is selected

**Returns:**
Updated menu object

### ShowMenu

Displays a menu and handles user interaction.

**Syntax:**
```powershell
ShowMenu -Menu <Object>
```

**Parameters:**
- `Menu` (Required): Menu object to display

**Returns:**
User selection result or navigation command

### Test-MenuItemIncluded

Tests whether a menu item should be included based on current settings.

**Syntax:**
```powershell
Test-MenuItemIncluded -MenuItemName <String>
```

**Parameters:**
- `MenuItemName` (Required): Name of menu item to test

**Returns:**
Boolean indicating whether item should be included

## SettingsHelperFunctions.ps1

### MergeSettings

Merges configuration settings from multiple sources with conflict resolution.

**Syntax:**
```powershell
MergeSettings -localSettings <Object> -globalSettings <Object> [-ConflictResolution <String>]
```

**Parameters:**
- `localSettings` (Required): Local/domain-specific settings object
- `globalSettings` (Required): Global settings object
- `ConflictResolution` (Optional): Conflict resolution strategy ("Local", "Global")

**Returns:**
Merged settings object with resolved conflicts

### Get-ConfigurationValue

Retrieves a configuration value with fallback to default if not found.

**Syntax:**
```powershell
Get-ConfigurationValue -Settings <Object> -Key <String> [-DefaultValue <Object>]
```

**Parameters:**
- `Settings` (Required): Settings object to search
- `Key` (Required): Configuration key to retrieve
- `DefaultValue` (Optional): Default value if key not found

**Returns:**
Configuration value or default value

## EncryptionFunctions.ps1

### Load-EncryptedConfigFile

Loads and decrypts configuration files with password retry logic.

**Syntax:**
```powershell
Load-EncryptedConfigFile -ConfigFile <String> [-MaxRetries <Int>] [-UseStoredPassword]
```

**Parameters:**
- `ConfigFile` (Required): Path to configuration file
- `MaxRetries` (Optional): Maximum password attempts (default: 3)
- `UseStoredPassword` (Optional): Attempt to use stored password first

**Returns:**
Result object with Success boolean, Content string, and ErrorMessage

**Security Features:**
- AES-256 encryption with SHA-256 key derivation
- Maximum 3 password attempts before config file deletion
- Memory-only decryption with automatic cleanup
- Comprehensive logging for security auditing

### Invoke-JsonFileEncryption

Core encryption/decryption functionality for JSON configuration files.

**Syntax:**
```powershell
Invoke-JsonFileEncryption -FilePath <String> -Password <SecureString> [-Encrypt] [-Decrypt]
```

**Parameters:**
- `FilePath` (Required): Path to file to encrypt/decrypt
- `Password` (Required): SecureString password for encryption/decryption
- `Encrypt` (Optional): Switch to encrypt the file
- `Decrypt` (Optional): Switch to decrypt the file

**Returns:**
Operation result with success status and any error messages

### Get-SecurePassword

Securely collects password input with confirmation.

**Syntax:**
```powershell
Get-SecurePassword -Message <String> [-RequireConfirmation] [-MaxAttempts <Int>]
```

**Parameters:**
- `Message` (Required): Prompt message for password input
- `RequireConfirmation` (Optional): Require password confirmation
- `MaxAttempts` (Optional): Maximum attempts for password confirmation

**Returns:**
SecureString object containing the password

### Clear-SecureMemory

Clears sensitive data from memory variables.

**Syntax:**
```powershell
Clear-SecureMemory -Variables <String[]> [-ClearScriptVariables]
```

**Parameters:**
- `Variables` (Required): Array of variable names to clear
- `ClearScriptVariables` (Optional): Clear script-scoped variables

**Effects:**
- Sets variables to $null
- Forces garbage collection
- Clears PowerShell variable cache

### Invoke-PasswordChangeProcess

Handles administrative password change workflow.

**Syntax:**
```powershell
Invoke-PasswordChangeProcess -ConfigFile <String> -SettingsFile <String>
```

**Parameters:**
- `ConfigFile` (Required): Path to encrypted configuration file
- `SettingsFile` (Required): Path to settings.json file

**Features:**
- Prompts for new password with confirmation
- Re-encrypts configuration with new password
- Updates changePWOnNextStart flag to false
- Creates backup with rollback capability

## GetAppAssignmentTypes.ps1

### GetAppAssignmentTypes

Retrieves and categorizes Intune app assignments with comprehensive reporting and export capabilities.

**Syntax:**
```powershell
GetAppAssignmentTypes -AccessToken <String> [-Export] [-outputPath <String>] [-fileMode <String>]
```

**Parameters:**
- `AccessToken` (Required): Microsoft Graph API access token
- `Export` (Optional): Switch to enable CSV export functionality
- `outputPath` (Required when Export used): Path to output CSV file
- `fileMode` (Optional): Export mode - 'Append' or 'Overwrite' (default: 'Overwrite')

**Returns:**
PowerShell object with properties:
- `AllApps`: Complete list of all apps with metadata
- `RequiredApps`: Apps with Required assignment intent
- `AvailableApps`: Apps with Available assignment intent  
- `UnassignedApps`: Apps without assignments

**CSV Export Columns:**
- Intent: Assignment category (Required, Available, Unassigned)
- id: Unique app identifier in Intune
- type: App type (win32LobApp, mobileApp, webApp)
- displayName: App display name
- applicableDeviceType: Target device platforms
- AssignedGroups: Resolved group names (human-readable)
- assignedGroupCount: Number of assigned groups

**Examples:**
```powershell
# Export all app assignments to CSV (overwrite mode)
GetAppAssignmentTypes -AccessToken $token -Export -outputPath "app-assignments.csv" -fileMode Overwrite

# Retrieve data as object for programmatic use
$result = GetAppAssignmentTypes -AccessToken $token
Write-Host "Total apps: $($result.AllApps.Count)"
Write-Host "Required apps: $($result.RequiredApps.Count)"
```

**Features:**
- **Comprehensive Reporting**: Categorizes assignments by intent automatically
- **Robust CSV Export**: Uses PSCustomObject for reliable CSV output
- **Advanced Logging**: Extensive verbose and CMTrace-compatible logging
- **Group Resolution**: Converts group IDs to human-readable names
- **Error Handling**: Comprehensive error handling with detailed logging

---

*This function reference provides detailed documentation for all functions in the Windows Autopilot Management Tool. For implementation examples and usage patterns, refer to the main README.md and Technical-Reference.md files.*