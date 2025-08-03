# Windows Autopilot Management Tool - Technical Documentation

This document provides comprehensive technical implementation details, architecture documentation, and contributor guidance for the Windows Autopilot Management Tool.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Configuration System](#configuration-system)
- [Microsoft Graph API Integration](#microsoft-graph-api-integration)
- [Authentication Implementation](#authentication-implementation)
- [Security Implementation](#security-implementation)
- [Function Reference](#function-reference)
- [Menu System Architecture](#menu-system-architecture)
- [Development Guidelines](#development-guidelines)
- [Testing Framework](#testing-framework)
- [Build and Deployment](#build-and-deployment)

## Architecture Overview

### Core Design Principles

The Windows Autopilot Management Tool is designed as a modular PowerShell-based application with the following key architectural components:

#### Function Loading System
- All PowerShell functions are dynamically loaded from the `/functions/` directory at startup using dot-sourcing
- Functions are loaded alphabetically with no dependency resolution, so modules must be independent
- Each `.ps1` file in `/functions/` represents a functional module with related capabilities

#### Hierarchical Configuration System
The application uses a three-tier configuration hierarchy for maximum flexibility:

1. **Runtime Parameters** (highest priority) - Command-line arguments passed to `main.ps1`
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`) - Organization-specific overrides
3. **Global Settings** (`settings.json` → `globalSettings`) - Default application configuration

Configuration merging is handled by the `MergeSettings` function in `SettingsHelperFunctions.ps1`.

#### Menu System Architecture
- Hierarchical menu navigation with stack-based history tracking
- State maintained in global variables `$global:History` and `$global:MenuHistory`
- Menu inclusion system allows role-based access control
- Context-aware navigation with back/main menu functionality

### Key Modules Overview

| Module | Purpose | Key Functions |
|--------|---------|---------------|
| **AutopilotDeviceFunctions.ps1** | Device management, Autopilot enrollment | `AddCorporateDeviceIdentifier`, `DeleteCorporateDeviceIdentifier` |
| **DeviceAndUserLookupFunctions.ps1** | User/device queries, credential access | `GetDeviceByUser`, `GetUserInput` |
| **DeviceReportingFunctions.ps1** | Device assessment and readiness reporting | `GetNextUserReadinessReport`, `AssessDeviceState` |
| **GraphAPIFunctions.ps1** | Microsoft Graph API integration | `Get-AuthToken`, `Invoke-GraphAPIRequest` |
| **MenuFunctions.ps1** | Interactive UI navigation system | `NewMenu`, `AddMenuItem`, `ShowMenu` |
| **SettingsHelperFunctions.ps1** | Configuration management | `MergeSettings`, `Update-GlobalSetting` |
| **EncryptionFunctions.ps1** | Secure configuration handling | `Load-EncryptedConfigFile`, `Invoke-JsonFileEncryption` |

## Configuration System

### Configuration File Structure

The tool uses multiple configuration files with specific purposes:

#### Primary Configuration Files
| File | Purpose | Location | Security |
|------|---------|----------|----------|
| `settings.json` | Main application configuration | Root directory | Plain text |
| `config.json` | Authentication credentials | `.secrets/` directory | AES-256 encrypted |
| `strings.json` | Localized messages and UI text | Root directory | Plain text |
| `init.json` | Configuration template for First Run Wizard | Root directory | Plain text |

#### settings.json Structure
```json
{
  "description": "Configuration file for the Autopilot script",
  "version": "1.3.0.0",
  "auth": {
    "Delegated": true,
    "changePWOnNextStart": false,
    "authType": "PublicAuthFlow",
    "renewalLeadTime": 5,
    "NoSaveRefreshToken": false,
    "CacheType": "Memory",
    "scope": [
      "offline_access",
      "openid",
      "Device.ReadWrite.All",
      "DeviceManagementManagedDevices.ReadWrite.All",
      "DeviceManagementServiceConfig.ReadWrite.All"
    ]
  },
  "globalSettings": {
    "operatingSystem": "Windows",
    "autoUpdate": true,
    "testMode": false,
    "appMode": "full",
    "maxWaitTime": 300,
    "timeInSeconds": 10,
    "showLicenseBanner": true,
    "deviceNamePrefix": "",
    "GroupTag": "Autopilot",
    "maxNumberOfDevicesAllowed": 3,
    "MinimumDevicePhysicalMemoryInGB": 8
  },
  "domains": {
    "contoso.com": {
      "groupsToInclude": ["Contoso-Users"],
      "groupsToExclude": ["Contractors"],
      "settings": {
        "deviceNamePrefix": "CONTOSO-",
        "maxNumberOfDevicesAllowed": 2
      }
    }
  },
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status",
    "Autopilot menu"
  ]
}
```

### Configuration Functions Reference

#### Core Configuration Functions

**`MergeSettings`** (SettingsHelperFunctions.ps1)
- Merges configuration settings from multiple sources with conflict resolution
- Supports 'Local' and 'Global' conflict resolution strategies
- Flattens nested objects for easy runtime access

**`Update-GlobalSetting`** (SettingsHelperFunctions.ps1)
- Updates individual settings in the globalSettings section
- Creates timestamped backups before modification
- Validates JSON structure before and after update

**`Update-DomainSettings`** (SettingsHelperFunctions.ps1)
- Updates or creates domain-specific configurations
- Supports merge and replace modes
- Preserves other domains and global settings

**`Get-JsonConfiguration`** (MiscFunctions.ps1)
- Universal JSON configuration loader with fallback support
- Validates JSON syntax and provides error handling
- Supports multiple JSON formats and environment-specific values

### Domain-Specific Configuration

The application supports different configurations for different organizational domains:

```json
{
  "domains": {
    "gao.gov": {
      "groupsToInclude": ["GAO-Users", "Device-Recipients"],
      "groupsToExclude": ["Contractors"],
      "settings": {
        "deviceNamePrefix": "GAO-",
        "GroupTag": "GAO-Autopilot",
        "maxNumberOfDevicesAllowed": 2,
        "DesiredAutopilotProfiles": ["GAO-Standard", "GAO-Secure"],
        "MinimumDevicePhysicalMemoryInGB": 16
      }
    },
    "arabictutor.com": {
      "groupsToInclude": ["AT-Employees"],
      "settings": {
        "deviceNamePrefix": "AT-",
        "maxNumberOfDevicesAllowed": 1,
        "testMode": true
      }
    }
  }
}
```

### First Run Wizard System

The First Run Wizard automatically launches when configuration files are missing and guides users through initial setup:

#### Wizard Process Flow
1. **Azure AD Configuration**: App ID, Tenant ID, Domain Name, Application Name
2. **Authentication Setup**: Choose authentication type (PublicAuthFlow, Interactive, Private)
3. **Auto Update Configuration**: Enable/disable automatic script updates
4. **Credential Collection**: App secrets or certificate details (if needed)
5. **File Creation**: Automatic creation and encryption of configuration files
6. **Settings Generation**: Comprehensive `settings.json` with sensible defaults
7. **String Localization**: Creation of `strings.json` with all UI text

## Microsoft Graph API Integration

### Required Scopes and Permissions

The application requires specific Microsoft Graph API permissions for full functionality:

| Scope | Purpose | API Endpoints Used |
|-------|---------|------------------|
| `User.Read.All` | User profiles, group memberships | `/users`, `/users/{id}/memberOf`, `/users/{id}/registeredDevices` |
| `Device.Read.All` | Microsoft Entra ID device objects | `/devices` |
| `DeviceManagementApps.ReadWrite.All` | Application management | `/deviceAppManagement/mobileApps`, `/deviceAppManagement/mobileApps/{id}/assignments` |
| `DeviceManagementConfiguration.Read.All` | Device configuration policies | `/deviceManagement/deviceConfigurations` |
| `DeviceManagementManagedDevices.Read.All` | Intune managed device properties | `/deviceManagement/managedDevices` |
| `BitlockerKey.Read.All` | BitLocker recovery keys | `/informationProtection/bitlocker/recoveryKeys` |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | LAPS password access | `/directory/deviceLocalCredentials` |
| `DeviceManagementServiceConfig.ReadWrite.All` | Autopilot management | `/deviceManagement/autopilotEvents`, `/deviceManagement/windowsAutopilotDeviceIdentities` |

### Primary API Endpoints

#### Autopilot Management
- `/deviceManagement/windowsAutopilotDeviceIdentities` - Autopilot device management
- `/deviceManagement/importedWindowsAutopilotDeviceIdentities` - Import device identities
- `/deviceManagement/autopilotEvents` - Autopilot enrollment events

#### Device Management
- `/deviceManagement/managedDevices` - Intune managed device data
- `/users/{id}/registeredDevices` - User device associations
- `/devices` - Entra ID device objects

#### Corporate Device Identifiers
- `/deviceManagement/importedDeviceIdentities/importDeviceIdentityList` - Corporate device identifier management

#### Security and Credentials
- `/directory/deviceLocalCredentials` - LAPS credentials
- `/informationProtection/bitlocker/recoveryKeys` - BitLocker recovery keys

#### Application Management
- `/deviceAppManagement/mobileApps` - Application information
- `/deviceAppManagement/mobileApps/{id}/assignments` - App assignment management

### Corporate Device Identifier Management

The application provides comprehensive management of Windows Corporate Device Identifiers in Microsoft Intune, essential for Autopilot V2 device enrollment.

#### Supported Identifier Types
1. **SerialNumber**: Device serial number only (`"ABC123456789"`)
2. **IMEI**: Device IMEI number (`"123456789012345"`)
3. **manufacturerModelSerial**: Composite identifier (`"Manufacturer,Model,SerialNumber"`)

#### Key Functions
- **`GetCorpDeviceIdentifier`**: Retrieves local device information using WMI
- **`AddCorporateDeviceIdentifier`**: Marks devices as corporate-owned in Intune
- **`DeleteCorporateDeviceIdentifier`**: Removes devices from corporate identifier list

#### Implementation Examples
```powershell
# Add current device using manufacturerModelSerial
$deviceInfo = GetCorpDeviceIdentifier
$identifier = "$($deviceInfo.Manufacturer),$($deviceInfo.Model),$($deviceInfo.SerialNumber)"
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier $identifier -IdentifierType "manufacturerModelSerial"

# Add device by serial number with overwrite protection
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber" -OverwriteImportedDeviceIdentities

# Delete device identifier with safety verification
DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"
```

## Authentication Implementation

### Authentication Flows

The application supports multiple OAuth 2.0 authentication flows:

#### PublicAuthFlow (Recommended)
- **Type**: Public client MSAL authentication
- **Benefits**: No app secrets required, enhanced security
- **Configuration**: `"authType": "PublicAuthFlow"`
- **Use Case**: Standard deployments where app secrets are not desired

#### Interactive Flow
- **Type**: Browser-based user authentication
- **Benefits**: Full user interaction, supports MFA
- **Configuration**: `"authType": "Interactive"`
- **Use Case**: Interactive scenarios requiring user consent

#### Private Flow
- **Type**: Confidential client with app secrets or certificates
- **Benefits**: Service-to-service authentication
- **Configuration**: `"authType": "Private"`
- **Use Case**: Automated scenarios, background services

### Token Management

The application implements comprehensive token management:

- **Automatic Refresh**: Tokens are automatically refreshed before expiration
- **Secure Caching**: Configurable token cache (Memory or File)
- **Lead Time Configuration**: `renewalLeadTime` setting controls when tokens are renewed
- **Security**: All tokens handled in memory with automatic cleanup

### Authentication Configuration Structure

```json
{
  "auth": {
    "Delegated": true,
    "changePWOnNextStart": false,
    "authType": "PublicAuthFlow",
    "renewalLeadTime": 5,
    "NoSaveRefreshToken": false,
    "SecureString": false,
    "ForceNewToken": false,
    "CacheType": "Memory",
    "privateSession": false,
    "preferredBrowser": "Default",
    "scope": [
      "offline_access",
      "openid",
      "Device.ReadWrite.All",
      "DeviceManagementManagedDevices.ReadWrite.All"
    ]
  }
}
```

## Security Implementation

### Encryption Details

The application uses enterprise-grade encryption implemented in `EncryptionFunctions.ps1`:

#### AES-256 Encryption
- **Algorithm**: AES-256-CBC
- **Key Derivation**: SHA-256 from user password
- **IV Generation**: Cryptographically secure random IV per encryption
- **Encoding**: Base64 for safe file storage

#### Password Security Features
- **Maximum Attempts**: 3 password attempts before config deletion
- **SecureString Objects**: All password handling uses PowerShell SecureString
- **Memory Protection**: Automatic cleanup of sensitive variables
- **Garbage Collection**: Forced cleanup of encryption keys

### Security Functions Reference

| Function | Purpose |
|----------|---------|
| `Load-EncryptedConfigFile` | Load and decrypt configuration files with retry logic |
| `Invoke-JsonFileEncryption` | Core AES-256 encryption/decryption functionality |
| `Invoke-PasswordChangeProcess` | Administrative password change workflow |
| `Get-SecurePassword` | Secure password input with confirmation |
| `Clear-SecureMemory` | Memory cleanup for sensitive data |

### Password Change Security Feature

The `changePWOnNextStart` setting enables administrative control over password security:

```json
{
  "auth": {
    "changePWOnNextStart": true
  }
}
```

**Implementation Flow**:
1. Detect flag after successful configuration decryption
2. Prompt user for new password with confirmation
3. Re-encrypt configuration file with new password
4. Update `settings.json` to set flag to `false`
5. Create automatic backup with rollback capability

## Function Reference

### Core Function Modules

#### AutopilotDeviceFunctions.ps1

**GetCorpDeviceIdentifier**
- Retrieves the current device's manufacturer, model, and serial number using WMI
- Returns PowerShell object with `Manufacturer`, `Model`, and `SerialNumber` properties

**AddCorporateDeviceIdentifier**
```powershell
AddCorporateDeviceIdentifier -AccessToken <String> -DeviceIdentifier <String> -IdentifierType <String> [-OverwriteImportedDeviceIdentities]
```
- Adds a device identifier to the corporate device identifiers list in Intune
- Supports SerialNumber, IMEI, and manufacturerModelSerial identifier types
- Optional overwrite protection for existing entries

**DeleteCorporateDeviceIdentifier**
```powershell
DeleteCorporateDeviceIdentifier -AccessToken <String> -DeviceIdentifier <String> -IdentifierType <String>
```
- Removes a device identifier from the corporate device identifiers list
- Interactive confirmation prompts and post-deletion verification
- Comprehensive logging and error handling

#### DeviceAndUserLookupFunctions.ps1

**GetUserInput**
```powershell
GetUserInput -Message <String> -Prompt <String> -InputType <String> -settings <Object>
```
- Collects user input with validation and formatting based on input type
- Supports validation for userName, serialNumber, and other input types
- Returns validated input string or navigation command

**GetDeviceByUser**
```powershell
GetDeviceByUser -AccessToken <String> -userName <String>
```
- Retrieves devices associated with a specific user
- Returns device information object or navigation command

#### DeviceReportingFunctions.ps1

**GetNextUserReadinessReport**
```powershell
GetNextUserReadinessReport -enrollmentState <Object>
```
- **Enhanced in v2.0**: Comprehensive device readiness assessment for next user assignment
- Validates device against all requirements simultaneously
- **Key Improvements**:
  - **Multi-Issue Detection**: Captures ALL device issues, not just the first one found
  - **Comprehensive Return Object**: Includes detailed issue lists and recommended actions
  - **Error Handling**: Robust input validation and error recovery
  - **Enhanced Display**: User-friendly formatting with visual indicators and priorities
- **Return Object Properties**:
  - `ReadinessState`: Overall readiness state (ready/notReady/error)
  - `Action`: Primary recommended action (backward compatible)
  - `Device`: Device identifier
  - `AllIssues`: Array of all issues found
  - `AllActions`: Array of all recommended actions
  - `IssueCount`: Number of issues detected
  - `IsReady`: Boolean readiness indicator
- **Validation Checks**:
  - Autopilot profile assignment and correctness
  - Device enrollment state and remediation status
  - RAM requirements and hardware specifications  
  - User associations and validity
  - Network connectivity and last contact date
- **Action Prioritization**: Uses intelligent priority system to determine primary action when multiple issues exist

**AssessDeviceState**
```powershell
AssessDeviceState -enrollmentState <Object> -AssessmentType <String> [-settings <Object>]
```
- Core device assessment engine supporting multiple assessment types
- **Enhanced Logic**: Collects all issues simultaneously instead of overwriting previous findings
- **Assessment Types**:
  - `NextUserReadiness`: Comprehensive readiness validation
  - `PropperEnrollmentVerification`: Enrollment status verification
  - `TroubleShooting`: Device troubleshooting assistance
- **Issue Collection**: Uses priority-based action determination for comprehensive reporting
- Returns structured assessment object with all findings

#### GraphAPIFunctions.ps1

**Get-AuthToken**
```powershell
Get-AuthToken -ClientId <String> -TenantId <String> [-ClientSecret <String>] [-CertificateThumbprint <String>] [-AuthType <String>] [-Scope <String[]>]
```
- Obtains Microsoft Graph API authentication token using specified authentication flow
- Supports PublicAuthFlow, Interactive, and Private authentication types
- Returns authentication token object with access token and metadata

**Invoke-GraphAPIRequest**
```powershell
Invoke-GraphAPIRequest -Uri <String> -AccessToken <String> [-Method <String>] [-Body <String>] [-ContentType <String>]
```
- Makes authenticated requests to Microsoft Graph API endpoints
- Supports GET, POST, PUT, DELETE HTTP methods
- Returns API response data or error information

#### MenuFunctions.ps1

**NewMenu**
```powershell
NewMenu -Title <String> -Description <String>
```
- Creates a new menu object for the menu system
- Returns menu object for use with AddMenuItem and ShowMenu

**AddMenuItem**
```powershell
AddMenuItem -Menu <Object> -Name <String> [-Action <ScriptBlock>] [-Submenu <Object>]
```
- Adds an item to a menu with either an action or submenu
- Supports both action execution and submenu navigation
- Returns updated menu object

**ShowMenu**
```powershell
ShowMenu -Menu <Object> [-StackOperation <String>] [-CalledBy <String>]
```
- Displays a menu and handles user interaction
- Supports stack operations (Auto, Push, Pop, None) for navigation management
- Context-aware navigation with history tracking

**Get-CallingContext**
```powershell
Get-CallingContext [-Menu <Object>] [-PreferredContext <String>] [-IncludeNavigationPath]
```
- Analyzes PowerShell call stack to determine calling context
- Enhanced context detection with navigation path analysis
- Supports pattern-based context identification for different calling scenarios

**Test-MenuItemIncluded**
```powershell
Test-MenuItemIncluded -MenuItemName <String>
```
- Tests whether a menu item should be included based on current settings
- Implements menu inclusion system for role-based access control
- Returns boolean indicating whether item should be included

#### SettingsHelperFunctions.ps1

**MergeSettings**
```powershell
MergeSettings -localSettings <Object> -globalSettings <Object> [-ConflictResolution <String>]
```
- Merges configuration settings from multiple sources with conflict resolution
- Supports 'Local' and 'Global' conflict resolution strategies
- Returns merged settings object with resolved conflicts

**Get-ConfigurationValue**
```powershell
Get-ConfigurationValue -Settings <Object> -Key <String> [-DefaultValue <Object>]
```
- Retrieves a configuration value with fallback to default if not found
- Provides safe access to configuration values with error handling
- Returns configuration value or default value

**Update-GlobalSetting**
```powershell
Update-GlobalSetting -SettingsFile <String> -SettingName <String> -SettingValue <Object>
```
- Updates individual settings in the globalSettings section
- Creates timestamped backups before modification
- Validates JSON structure before and after update

**Update-DomainSettings**
```powershell
Update-DomainSettings -SettingsFile <String> -Domain <String> -Settings <Object> [-Mode <String>]
```
- Updates or creates domain-specific configurations
- Supports merge and replace modes for flexible configuration management
- Preserves other domains and global settings

#### EncryptionFunctions.ps1

**Load-EncryptedConfigFile**
```powershell
Load-EncryptedConfigFile -ConfigFile <String> [-MaxRetries <Int>] [-UseStoredPassword]
```
- Loads and decrypts configuration files with password retry logic
- AES-256 encryption with SHA-256 key derivation
- Maximum 3 password attempts before config file deletion
- Returns result object with Success boolean, Content string, and ErrorMessage

**Invoke-JsonFileEncryption**
```powershell
Invoke-JsonFileEncryption -FilePath <String> -Password <SecureString> [-Encrypt] [-Decrypt]
```
- Core encryption/decryption functionality for JSON configuration files
- Uses AES-256-CBC with cryptographically secure random IV
- Memory-only decryption with automatic cleanup

**Get-SecurePassword**
```powershell
Get-SecurePassword -Message <String> [-RequireConfirmation] [-MaxAttempts <Int>]
```
- Securely collects password input with confirmation
- Uses PowerShell SecureString objects for memory protection
- Returns SecureString object containing the password

**Clear-SecureMemory**
```powershell
Clear-SecureMemory -Variables <String[]> [-ClearScriptVariables]
```
- Clears sensitive data from memory variables
- Forces garbage collection and clears PowerShell variable cache
- Essential for security in encryption operations

**Invoke-PasswordChangeProcess**
```powershell
Invoke-PasswordChangeProcess -ConfigFile <String> -SettingsFile <String>
```
- Handles administrative password change workflow
- Prompts for new password with confirmation
- Re-encrypts configuration with new password and updates settings

#### GetAppAssignmentTypes.ps1

**GetAppAssignmentTypes**
```powershell
GetAppAssignmentTypes -AccessToken <String> [-Export] [-outputPath <String>] [-fileMode <String>]
```
- Retrieves and categorizes Intune app assignments with comprehensive reporting
- Supports CSV export with resolved group names
- Returns categorized app assignment data (Required, Available, Unassigned)

## Menu System Architecture

### Menu System Components

The menu system uses a hierarchical navigation structure with several key components:

#### Menu Object Structure
```powershell
$menu = @{
    Title = "Menu Title"
    Description = "Menu description and instructions"
    Items = @(
        @{
            Name = "Menu Item Name"
            Action = { # ScriptBlock for action items }
            Submenu = $submenuObject  # For navigation items
        }
    )
}
```

#### Navigation Stack Management
- `$global:MenuHistory` - Array storing navigation history for Back functionality
- `$global:History` - General history tracking for context awareness
- Stack operations (Push, Pop, None, Auto) control navigation flow

#### Menu Inclusion System
The application uses an inclusion-based menu system for role-based access control:

```json
{
  "appMode": "helpDesk",
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status",
    "About"
  ]
}
```

When `appMode` is set to "full", all menu items are shown. For other modes, only items listed in `menuItemsToInclude` are displayed.

### Context-Aware Navigation

The `Get-CallingContext` function provides enhanced context detection:

#### Standard Context Types
- **Direct**: Called directly from main script
- **Action**: Called from menu action execution
- **Submenu**: Called when navigating to submenu
- **Navigation**: Called from navigation commands

#### Enhanced Context with Navigation Path
Using the `-IncludeNavigationPath` parameter provides unique context identification:

```powershell
$context = Get-CallingContext -IncludeNavigationPath
# Returns: "Action-ViaCheckMenu", "Action-ViaAutopilotMenu", etc.
```

This allows the same function to behave differently based on how it was accessed through the menu system.

## Development Guidelines

### PowerShell 5.1 Compatibility
- Always maintain compatibility with PowerShell 5.1 for Windows environments
- Use regular hashtables instead of ordered hashtables for PS 5.1 compatibility
- Add version comments if PowerShell 5.1 compatibility cannot be maintained

### Logging Standards
- Use `Write-Log` function consistently with CMTrace format support
- Include `$functionName = $MyInvocation.MyCommand.Name` at start of functions
- Log at appropriate levels: Error, Warning, Information, Verbose, Debug
- Include detailed verbose logging for troubleshooting

### Error Handling Patterns
- Wrap API calls in try-catch blocks with comprehensive error handling
- Use `Write-Verbose` for detailed operation logging
- Provide fallback to default values when configuration loading fails
- Validate JSON structure before processing

### Function Development Guidelines
- Each function should be independent with no inter-module dependencies
- Functions are loaded alphabetically from `/functions/` directory
- Include parameter validation and comprehensive documentation
- Implement consistent error handling and logging patterns

### Code Organization
```
/functions/
├── AutopilotDeviceFunctions.ps1      # Device management
├── DeviceAndUserLookupFunctions.ps1  # User/device queries
├── DeviceReportingFunctions.ps1      # Device assessment and readiness reporting
├── GraphAPIFunctions.ps1             # API integration
├── MenuFunctions.ps1                 # UI navigation
├── SettingsHelperFunctions.ps1       # Configuration
├── EncryptionFunctions.ps1           # Security
└── GetAppAssignmentTypes.ps1         # App reporting
```

## Testing Framework

### Test Structure
Tests are located in `/TestScripts/` and follow this pattern:
1. Create isolated test environment
2. Load specific function modules
3. Execute test scenarios with validation
4. Cleanup test environment

### Current Test Coverage
- **Configuration system functions**: `test-settings-functions.ps1`
- **Device selection functions**: `test-device-selection.ps1`
- **Corporate device identifier functions**: `test-corporate-device-identifier.ps1`
- **Syntax validation**: `test-syntax.ps1`
- **Comprehensive integration testing**: `test-comprehensive.ps1`
- **Password change functionality**: `test-password-change.ps1`

### Testing Commands
```powershell
# Run configuration system tests
.\TestScripts\test-settings-functions.ps1

# Run device selection tests
.\TestScripts\test-device-selection.ps1

# Run all tests in test folder
Get-ChildItem .\TestScripts\test-*.ps1 | ForEach-Object { & $_.FullName }
```

### Test Development Guidelines
- Create isolated test environments to avoid side effects
- Include both positive and negative test cases
- Validate expected outcomes with appropriate assertions
- Clean up test artifacts after execution
- Use comprehensive logging for test debugging

## Build and Deployment

### Build System
- Use `CreateRelease.ps1` for signed executable releases
- Support for Azure Trusted Signing service for code signing
- Domain-specific configurations via environment switchers (`gao.bat`, `zmc.bat`)
- PowerShell module creation capability

### Build Commands
```powershell
# Create signed release executable
.\CreateRelease.ps1 -InputFile "main.ps1" -Version "1.2.3"

# Create PowerShell module
.\CreateRelease.ps1 -InputFile "main.ps1" -CreateModule

# Build without version update
.\CreateRelease.ps1 -InputFile "main.ps1" -NoVersionUpdate
```

### Environment Setup
```powershell
# Switch to GAO configuration
.\gao.bat

# Switch to ZM configuration  
.\zmc.bat
```

### Deployment Considerations
- **Configuration Files**: Ensure `.secrets/` directory is properly secured in production
- **Permissions**: Verify Azure AD app registration permissions are correctly configured
- **Network Access**: Ensure connectivity to Microsoft Graph API endpoints
- **Security**: Implement appropriate access controls for the executable and configuration files

### Release Process
1. **Testing**: Run comprehensive test suite to ensure functionality
2. **Version Update**: Update version numbers in configuration files
3. **Code Signing**: Sign executable using Azure Trusted Signing service
4. **Documentation**: Update user-facing documentation as needed
5. **Distribution**: Deploy through appropriate channels with configuration guidance

---

*This technical documentation provides comprehensive information for developers, system administrators, and contributors working with the Windows Autopilot Management Tool. For end-user documentation, please refer to the main README.md file.*