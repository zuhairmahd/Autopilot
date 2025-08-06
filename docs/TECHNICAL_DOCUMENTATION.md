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
- All PowerShell functions are dynamically loaded from the `/functions/` directory tree at startup using recursive dot-sourcing
- Functions are organized in logical subdirectories based on functionality
- Functions are loaded alphabetically with no dependency resolution, so modules must be independent
- Each `.ps1` file represents a single function or closely related group of functions

#### Reorganized Function Structure
The codebase has been reorganized into the following functional categories:

```
functions/
├── autopilotFunctions/     # Autopilot device management
│   ├── v1/                # Legacy Autopilot functions
│   ├── v2/                # Updated Autopilot functions  
│   └── GetDeviceInfo.ps1  # Common device information
├── deviceFunctions/        # Device operations and queries
├── encryptionFunctions/    # Security and encryption utilities
├── graphFunctions/         # Microsoft Graph API integration
├── menuFunctions/          # User interface and navigation
├── reportingFunctions/     # Device assessment and reporting
├── setupFunctions/         # Configuration and initialization
│   └── FirstRunWizardFunctions/  # First-time setup workflow
├── updateFunctions/        # Auto-update functionality
└── utilityFunctions/       # General-purpose utilities
```

#### Hierarchical Configuration System
The application uses a three-tier configuration hierarchy for maximum flexibility:

1. **Runtime Parameters** (highest priority) - Command-line arguments passed to `main.ps1`
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`) - Organization-specific overrides
3. **Global Settings** (`settings.json` → `globalSettings`) - Default application configuration

Configuration merging is handled by the `MergeSettings` function in `setupFunctions/MergeSettings.ps1`.

#### Menu System Architecture
- Hierarchical menu navigation with stack-based history tracking
- State maintained in global variables `$global:History` and `$global:MenuHistory`
- Menu inclusion system allows role-based access control
- Context-aware navigation with back/main menu functionality

### Function Categories Overview

| Category | Purpose | Key Functions | Location |
|----------|---------|---------------|----------|
| **autopilotFunctions** | Autopilot device enrollment and management | `ImportAutopilotDevice`, `DeleteAutopilotDevice`, `AddCorporateDeviceIdentifier` | `autopilotFunctions/v1/`, `autopilotFunctions/v2/` |
| **deviceFunctions** | Device queries, operations, and lifecycle | `GetDeviceByUser`, `RestartDevice`, `GetBitLockerRecoveryKey` | `deviceFunctions/` |
| **reportingFunctions** | Device assessment and readiness analysis | `GetNextUserReadinessReport`, `GetDeviceEnrollmentStatus` | `reportingFunctions/` |
| **graphFunctions** | Microsoft Graph API integration and authentication | `GetGraphAccessToken`, `CallGraphAPI`, `Get-DelegatedToken` | `graphFunctions/` |
| **menuFunctions** | User interface and navigation system | `ShowMenu`, `AddMenuItem`, `Handle-MenuItemSelection` | `menuFunctions/` |
| **encryptionFunctions** | Security, encryption, and credential management | `Load-EncryptedConfigFile`, `Get-SecurePassword` | `encryptionFunctions/` |
| **setupFunctions** | Configuration management and initialization | `InitializeConfiguration`, `CreateConfiguration`, `MergeSettings` | `setupFunctions/` |
| **utilityFunctions** | General-purpose helper functions | Logging, formatting, and utility operations | `utilityFunctions/` |
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
Test-MenuItemIncluded -MenuItemName <String> [-Menus <PSCustomObject[]>]
```
- Tests whether a menu item should be included based on menu configuration
- Searches through menu structure to find item by name and checks includeInDisplayModes array
- Returns true if menu item matches current appMode, if item not found, or if Menus parameter is null
- Returns false only if menu item is found but includeInDisplayModes doesn't match current appMode
- Implements hierarchical menu inclusion system for role-based access control

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

#### App Mode Configuration
The application supports multiple predefined app modes with user-friendly configuration:

**Available App Modes:**
- `full` - Complete feature set (default)
- `helpDesk` - Streamlined help desk operations
- `advanced` - Advanced features for technical staff
- `advancedRegistration` - Advanced device registration
- `registration` - Device registration focused
- `admin` - Administrative functions
- `custom` - Custom configuration

**Configuration Methods:**
1. **First-Run Wizard**: Guided selection during initial setup via `Get-AppModeConfigurationFromUser`
2. **Settings Menu**: Runtime changes through "Change App Mode setting" menu item
3. **Manual**: Direct editing of `settings.json`

**Implementation Details:**
- App mode changes require application restart to take effect
- Mode validation occurs at startup (line 443 in main.ps1)
- Settings updated using `Update-GlobalSetting` function
- User prompted for restart confirmation after mode change

**Recent Architecture Improvements (v1.3.0+):**
The app mode selection system has been significantly refactored to eliminate code duplication and improve maintainability:

- **Centralized Logic**: `Get-AppModeConfigurationFromUser.ps1` now handles all app mode selection logic, supporting multiple contexts (wizard vs settings)
- **Code Reduction**: Eliminated 110+ lines of duplicate code from `main.ps1`
- **Enhanced UI**: Consistent user experience with current mode highlighting, detailed descriptions, and cancel options
- **Improved Testing**: Comprehensive test coverage with 25+ assertions verifying backward compatibility and new features
- **Flexible Parameters**: Support for different display contexts, current mode awareness, and menu system integration
- **Robust Error Handling**: Enhanced validation and graceful error recovery across all contexts

**Function Signature Evolution:**
```powershell
# Original (backward compatible)
Get-AppModeConfigurationFromUser -Silent

# Enhanced (new capabilities)
Get-AppModeConfigurationFromUser -CurrentMode "helpDesk" -Context "settings"
```

**Return Structure (Enhanced):**
```powershell
@{
    appMode = 'full'                    # Selected app mode
    selectedChoice = '1'                # User's menu choice
    cancelled = $false                  # Whether user cancelled
    currentModeUnchanged = $false       # Whether selected mode equals current mode
}
```

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

### Test Architecture

The testing framework has been completely reorganized to support the new modular function structure:

#### Test Helper System
- **test-helper.ps1**: Common utilities for all tests
  - `Load-AllFunctions`: Recursively loads all functions from the reorganized structure
  - `Test-PowerShellVersion`: Detects PowerShell 5.1 vs 7+ for compatibility
  - `Write-TestResult`: Version-aware test result display (Unicode vs ASCII)
  - `Write-TestSection`: Formatted test section headers

#### Master Test Runner
- **run-all-tests.ps1**: Comprehensive test execution system
  - Runs all tests in isolated PowerShell sessions
  - Provides detailed timing and results reporting
  - PowerShell 5.1 compatible output formatting
  - Supports test filtering and error handling
  - Generates comprehensive test reports

### PowerShell 5.1 Compatibility

The testing framework ensures full compatibility with PowerShell 5.1:
- Automatic detection of PowerShell version
- Unicode character fallbacks for older versions
- Compatible cmdlet usage patterns
- Version-specific feature handling

### Test Structure
Tests are located in `/TestScripts/` and follow this pattern:
1. Load test-helper.ps1 for common utilities
2. Use Load-AllFunctions to import reorganized function modules
3. Create isolated test environment with version-aware output
4. Execute test scenarios with validation
5. Cleanup test environment

### Current Test Coverage
- **Next User Readiness**: `test-checknextuserreadiness.ps1` - Enhanced device readiness assessment
- **Configuration system**: `test-settings-functions.ps1` - Settings management functions
- **Device selection**: `test-device-selection.ps1` - Device lookup and selection
- **Corporate device identifiers**: `test-corporate-device-identifier.ps1` - Corporate device management
- **Syntax validation**: `test-syntax.ps1` - PowerShell syntax checking for all function files
- **Authentication types**: `test-authentication-types.ps1` - OAuth flow testing
- **Comprehensive integration**: `test-comprehensive.ps1` - End-to-end functionality
- **Password change**: `test-password-change.ps1` - Credential management
- **First-run wizard**: `test-firstrun-wizard.ps1` - Initial setup workflow
- **Menu system**: `test-menu-inclusions.ps1` - Navigation and menu functionality

### Testing Commands

#### Master Test Runner (Recommended)
```powershell
# Run all tests with detailed reporting
.\TestScripts\run-all-tests.ps1

# Run specific test pattern
.\TestScripts\run-all-tests.ps1 -TestPattern "test-settings*.ps1"

# Continue on errors with verbose output
.\TestScripts\run-all-tests.ps1 -ContinueOnError -ShowVerbose

# Exclude specific tests
.\TestScripts\run-all-tests.ps1 -ExcludePattern "test-comprehensive.ps1"
```

#### Individual Tests
```powershell
# Run specific test
.\TestScripts\test-checknextuserreadiness.ps1

# Run configuration system tests
.\TestScripts\test-settings-functions.ps1

# Run syntax validation
.\TestScripts\test-syntax.ps1
```

#### Legacy Batch Execution
```powershell
# Run all tests (legacy method)
Get-ChildItem .\TestScripts\test-*.ps1 | Where-Object { $_.Name -ne 'test-helper.ps1' } | ForEach-Object { & $_.FullName }
```

### Test Development Guidelines

#### Function Loading
- Always use `Load-AllFunctions` from test-helper.ps1 for consistent function loading
- Test in isolation using separate PowerShell sessions when possible
- Verify function availability before testing

#### Version Compatibility
- Use `Test-PowerShellVersion` to detect PowerShell capabilities
- Use `Write-TestResult` instead of direct Unicode characters
- Test with both PowerShell 5.1 and 7+ when possible

#### Test Structure
- Create isolated test environments to avoid side effects
- Include both positive and negative test cases
- Validate expected outcomes with appropriate assertions
- Clean up test artifacts after execution
- Use comprehensive logging for test debugging

#### Output Formatting
- Use `Write-TestSection` for consistent section headers
- Use `Write-TestResult` for pass/fail indicators
- Provide meaningful error messages with context

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