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
The application features a sophisticated menu system with the following characteristics:

- **Hierarchical Navigation**: Multi-level menu structure with submenus
- **Stack-Based History**: Navigation stack maintained in `$global:MenuHistory`
- **Role-Based Access**: Menu items filtered by `appMode` and `includeInDisplayModes`
- **Data-Driven Configuration**: Menus defined in `settings.json` → `menus` array
- **Context-Aware Actions**: Menu functions adapt based on calling context
- **Mnemonic Support**: Keyboard shortcuts for common navigation actions

**Key Menu Functions**:
- `DisplayNumericMenu`: Primary menu rendering engine
- `ShowMenu`: Menu orchestration and display coordination
- `Handle-MenuItemSelection`: User input processing and validation
- `Handle-ActionExecution`: Action dispatch and execution
- Navigation handlers for back/main menu/submenu operations

For complete menu system documentation, see [MENU_SYSTEM_DOCUMENTATION.md](./MENU_SYSTEM_DOCUMENTATION.md).

### Function Categories Overview

The application organizes its **137 functions** across 9 logical categories:

| Category | Count | Purpose | Key Functions | Location |
|----------|-------|---------|---------------|----------|
| **menuFunctions** | 17 | User interface and navigation system | `DisplayNumericMenu`, `ShowMenu`, `Handle-MenuItemSelection` | `menuFunctions/` |
| **setupFunctions** | 23 | Configuration management and initialization | `MergeSettings`, `Start-FirstRunWizard`, `Show-SettingsEditor` | `setupFunctions/` |
| **utilityFunctions** | 18 | General-purpose helper functions | `Write-Log`, `GetUserInput`, `GetEntraUser` | `utilityFunctions/` |
| **deviceFunctions** | 12 | Device queries, operations, and lifecycle | `GetDeviceByUser`, `RestartDevice`, `GetBitLockerRecoveryKey` | `deviceFunctions/` |
| **autopilotFunctions** | 14 | Autopilot device enrollment and management | `ImportAutopilotDevice`, `GetDeviceHash`, `AddCorporateDeviceIdentifier` | `autopilotFunctions/v1/`, `autopilotFunctions/v2/` |
| **graphFunctions** | 22 | Microsoft Graph API integration and authentication | `GetGraphAccessToken`, `CallGraphAPI`, `Get-DelegatedToken` | `graphFunctions/` |
| **reportingFunctions** | 11 | Device assessment and readiness analysis | `GetNextUserReadinessReport`, `Export-DeviceList`, `ShowDeviceReport` | `reportingFunctions/` |
| **encryptionFunctions** | 14 | Security, encryption, and credential management | `Load-EncryptedConfigFile`, `Get-SecurePassword`, `Invoke-JsonFileEncryption` | `encryptionFunctions/` |
| **updateFunctions** | 6 | Application update and version management | `CheckForUpdates`, `GetLatestGithubRelease`, `Invoke-FileCertVerification` | `updateFunctions/` |

**Total Functions**: 137 across 9 categories

## Configuration System

### PSD1 Configuration Architecture

The tool has been migrated to use PowerShell Data Files (.psd1) for all configuration storage, providing significant performance improvements and native PowerShell integration.

#### Primary Configuration Files
| File | Purpose | Location | Security | Format |
|------|---------|----------|----------|---------|
| `settings.psd1` | Main application configuration | Root directory | Plain text | PowerShell Data File |
| `config.psd1` | Authentication credentials | `.secrets/` directory | AES-256 encrypted | PowerShell Data File |
| `strings.psd1` | Localized messages and UI text | Root directory | Plain text | PowerShell Data File |
| `init.psd1` | Configuration template for First Run Wizard | Root directory | Plain text | PowerShell Data File |
| `menu.psd1` | Menu structure definitions | Root directory | Plain text | PowerShell Data File |
| `lastrun.psd1` | Build and version tracking | Root directory | Plain text | PowerShell Data File |

#### Performance Benefits of PSD1 Migration
- **89.6% Performance Improvement**: Load times reduced from 96ms to 10ms compared to JSON parsing
- **Native PowerShell**: No external dependencies or JSON parsing libraries required
- **Enhanced Reliability**: Eliminates JSON encoding issues and parsing errors
- **Type Safety**: PowerShell native data types with automatic validation
- **Better Error Handling**: PowerShell syntax errors provide clear feedback

#### settings.psd1 Structure
```powershell
@{
    description = 'Configuration file for the Autopilot script'
    version = '4.0.0.0'
    auth = @{
        validateScopes = $false
        authType = 'PublicAuthFlow'
        Delegated = $true
        changePWOnNextStart = $false
        renewalLeadTime = 5
        NoSaveRefreshToken = $false
        cacheType = 'Memory'
        scope = @(
            'offline_access'
            'openid'
            'Device.ReadWrite.All'
            'DeviceManagementManagedDevices.ReadWrite.All'
            'DeviceManagementServiceConfig.ReadWrite.All'
            'DeviceManagementApps.Read.All'
            'User.Read.All'
        )
    }
    globalSettings = @{
        operatingSystem = 'Windows'
        autoUpdate = $true
        testMode = $false
        appMode = 'full'
        maxWaitTime = 300
        timeInSeconds = 10
        showLicenseBanner = $true
        deviceNamePrefix = ''
        GroupTag = 'Autopilot'
        maxNumberOfDevicesAllowed = 3
        MinimumDevicePhysicalMemoryInGB = 8
    }
    domains = @{
        'contoso.com' = @{
            groupsToInclude = @('Contoso-Users')
            groupsToExclude = @('Contractors')
            autopilotProfilesToInclude = @(
                @{
                    name = 'Corporate-Enrollment-Profile'
                    id = '12345678-1234-1234-1234-123456789abc'
                }
            )
            settings = @{
                deviceNamePrefix = 'CONTOSO-'
                maxNumberOfDevicesAllowed = 2
            }
        }
    }
    menuItemsToInclude = @(
        'Give a device to a user'
        'Check device status'
        'Autopilot menu'
    )
}
```

### Domain Configuration Files

Starting with version 4.0, domain-specific configurations continue to use separate files but now in .psd1 format for consistency and performance.

#### Domain File Structure

Each domain has its own configuration file named `{domain}.psd1` (e.g., `contoso.com.psd1`):

```powershell
@{
    groupsToInclude = @(
        @{
            name = 'Contoso-Users'
            id = '11111111-1111-1111-1111-111111111111'
        }
        @{
            name = 'Device-Recipients'
            id = '22222222-2222-2222-2222-222222222222'
        }
    )
    groupsToExclude = @(
        @{
            name = 'Contractors'
            id = '33333333-3333-3333-3333-333333333333'
        }
    )
    autopilotProfilesToInclude = @(
        @{
            name = 'Contoso-Standard'
            id = '44444444-4444-4444-4444-444444444444'
        }
        @{
            name = 'Contoso-Secure'
            id = '55555555-5555-5555-5555-555555555555'
        }
    )
    settings = @{
        deviceNamePrefix = 'CONTOSO-'
        domain = 'contoso.com'
        maxNumberOfDevicesAllowed = 10
        MinimumDevicePhysicalMemoryInGB = 8
        GroupTag = 'CONTOSO-Autopilot'
    }
    additionalScopes = @(
        @{
            Scope = 'CustomScope.Read.All'
            Reason = 'Required for custom domain operations'
        }
    )
}
```

#### Migration Process

The application automatically migrated from JSON to PSD1 format during the version 4.0 upgrade:

1. **Detection**: Startup checks for existing JSON configuration files
2. **Migration**: Converts JSON files to PSD1 format with enhanced structure
3. **Backup**: Creates legacy-json/ directory with original files preserved
4. **Validation**: Verifies migrated configurations load correctly
5. **Cleanup**: JSON files archived but not deleted for rollback capability

#### Enhanced Group and Profile Storage

The PSD1 migration introduced enhanced storage for groups and autopilot profiles:

- **Enhanced Format**: Stores both names and IDs for improved API performance
- **Legacy Compatibility**: Automatically upgrades string arrays to enhanced format
- **Validation**: Real-time validation against Microsoft Graph API
- **ID Resolution**: Automatic resolution of names to GUIDs during editing

#### Benefits

- **Modularity**: Each domain can be managed independently
- **Version Control**: Easier to track changes to specific domain configurations
- **Collaboration**: Multiple administrators can work on different domains simultaneously
- **Backup**: Individual domain configurations can be backed up separately
- **Security**: Domain-specific settings can be secured with different permissions

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

**`Update-Setting`** (Update-Setting.ps1)
- **Enhanced for separate domain files**: Now saves domain settings to separate configuration files
- Supports merge and replace modes for domain settings
- Maintains backward compatibility with legacy format

#### New Domain Configuration Functions

**`Get-DomainConfigurationFromFiles`** (Get-DomainConfigurationFromFiles.ps1)
- Loads domain-specific configuration from separate JSON files
- Creates default configuration with global settings if file doesn't exist
- Supports fallback to legacy format for backward compatibility

**`Save-DomainConfiguration`** (Save-DomainConfiguration.ps1)
- Saves domain configuration to separate JSON files
- Creates timestamped backups before modifications
- Validates JSON structure and provides error handling

**`Migrate-DomainsToSeparateFiles`** (Migrate-DomainsToSeparateFiles.ps1)
- Migrates domain configurations from settings.json to separate files
- Preserves all existing settings, groups, and additional scopes
- Provides detailed migration results and error reporting

**`Get-AvailableDomains`** (Get-AvailableDomains.ps1)
- Scans for available domain configuration files
- Supports both separate files and legacy format
- Used by domain selection interfaces

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
- `/deviceAppManagement/managedAppPolicies` - App protection policies
- `/deviceAppManagement/managedAppPolicies/{id}/assignments` - App protection policy assignments

#### Device Management and Configuration
- `/deviceManagement/deviceConfigurations` - Device configuration policies
- `/deviceManagement/deviceConfigurations/{id}/assignments` - Configuration assignments
- `/deviceManagement/deviceCompliancePolicies` - Compliance policies
- `/deviceManagement/deviceCompliancePolicies/{id}/assignments` - Compliance assignments
- `/deviceManagement/deviceManagementScripts` - PowerShell scripts
- `/deviceManagement/deviceManagementScripts/{id}/assignments` - Script assignments
- `/deviceManagement/deviceHealthScripts` - Health monitoring scripts (beta)
- `/deviceManagement/deviceHealthScripts/{id}/assignments` - Health script assignments (beta)
- `/deviceManagement/intents` - Security baselines and endpoint security policies
- `/deviceManagement/intents/{id}/assignments` - Security intent assignments
- `/deviceManagement/resourceAccessProfiles` - VPN, Wi-Fi, certificate profiles
- `/deviceManagement/resourceAccessProfiles/{id}/assignments` - Resource access assignments
- `/deviceManagement/configurationPolicies` - Settings catalog policies (beta)
- `/deviceManagement/configurationPolicies/{id}/assignments` - Configuration policy assignments (beta)
- `/deviceManagement/groupPolicyConfigurations` - Group policy ADMX settings (beta)
- `/deviceManagement/groupPolicyConfigurations/{id}/assignments` - Group policy assignments (beta)

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
AssessDeviceState -enrollmentState <Object> -AssessmentType <String> [-settings <Object>] [-username <String>]
```
- Core device assessment engine supporting multiple assessment types
- **Recent Enhancements**:
  - **Pending Actions Detection**: Checks for incomplete device operations before marking ready
  - **Same-User Detection**: Identifies devices already registered to intended user
  - **Enhanced Managed Device Handling**: Only checks pending actions for managed devices
  - **Improved Readiness Logic**: Comprehensive validation including enrollment state and pending actions
- **Assessment Types**:
  - `NextUserReadiness`: Comprehensive readiness validation with pending actions check
  - `PropperEnrollmentVerification`: Enrollment status verification
  - `TroubleShooting`: Device troubleshooting assistance
- **New Parameters**:
  - `username`: Optional parameter to check device association against intended user
- **Enhanced Readiness Criteria**:
  - Device passes all standard checks (enrollment, profile, RAM, network)
  - No pending actions (wipe, reset, sync)
  - Either ready for new user OR already registered to same user with compliant state
- Returns structured assessment object with detailed readiness information

**GetManagedDeviceRelevantProperties**
```powershell
GetManagedDeviceRelevantProperties -enrollmentState <Object> [-settings <Object>] [-username <String>]
```
- Extracts relevant properties from managed device object
- **Recent Enhancements**:
  - **Variable Initialization**: Proper initialization of all readiness check variables
  - **Same-User Detection**: New `RegisteredToSameUser` property indicates device is already registered to intended user
  - **Enhanced User Validation**: Improved logic for detecting invalid user associations (SPNs, deleted users)
- **Return Properties**:
  - `OrphanDevice`: Whether device has mismatched Autopilot/Intune records
  - `CorrectRam`: Device meets memory requirements
  - `HasUser`: Device has user association
  - `ValidUser`: User association is valid (not SPN or deleted)
  - `LastLogonDate`: Last user logon timestamp
  - `ReadyForNextUser`: Overall readiness boolean
  - `RegisteredToSameUser`: New - indicates device is registered to intended user

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

#### Get-GroupDirectAssignments.ps1

**Get-GroupDirectAssignments**
```powershell
Get-GroupDirectAssignments -GroupName <String> [-AccessToken <String>] [-IncludeBeta] [-ShowSummary] [-BatchSize <Int32>]
```
- Retrieves comprehensive group assignment analysis across all Intune object types
- Supports both v1.0 and beta Microsoft Graph API endpoints for maximum coverage
- Uses efficient batch API calls to minimize latency and API throttling
- Returns categorized assignments for:
  - **Applications**: Mobile apps and their deployment assignments
  - **Device Configurations**: Configuration profiles and settings
  - **Compliance Policies**: Device compliance and security policies
  - **Device Management Scripts**: PowerShell scripts for device automation
  - **App Protection Policies**: Mobile application management policies
  - **Security Intents**: Security baselines and endpoint security policies
  - **Resource Access Profiles**: VPN, Wi-Fi, and certificate profiles
  - **Autopilot Profiles**: Windows Autopilot deployment profiles (beta only)
  - **Device Health Scripts**: Proactive health monitoring scripts (beta only)
  - **Configuration Policies**: Settings catalog policies (beta only)
  - **Group Policy Configurations**: ADMX-based group policies (beta only)

**Show-GroupAssignments**
```powershell
Show-GroupAssignments -GroupName <String> [-accessToken <String>]
```
- Interactive menu-driven interface for viewing and exporting group assignments
- Provides filtered views by assignment type with detailed information display
- Supports CSV export with automatic filename generation based on group name and date
- Integrates with the application's hierarchical menu system for seamless navigation

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
├── GetAppAssignmentTypes.ps1         # App reporting
├── Get-GroupDirectAssignments.ps1     # Comprehensive group assignment analysis
└── Show-GroupAssignments.ps1          # Interactive group assignment viewer
```

## Testing Framework

### Unified Testing Framework

The Windows Autopilot Management Tool uses a **unified testing framework** with a single point of entry for all test execution. This framework provides comprehensive validation across all application components through centralized test management, categorization, and reporting.

#### Single Point of Entry: Test-Runner.ps1

**All testing goes through `Test-Runner.ps1`** - this is the centralized test runner that replaces individual test script execution:

```powershell
# Standard test execution (replaces run-all-tests.ps1)
.\TestScripts\Test-Runner.ps1 -TestCategory all

# Category-based testing
.\TestScripts\Test-Runner.ps1 -TestCategory syntax       # Quick validation (~5 seconds)
.\TestScripts\Test-Runner.ps1 -TestCategory core         # Essential tests (~30-60 seconds)
.\TestScripts\Test-Runner.ps1 -TestCategory unit         # Unit tests (~2-4 minutes)
.\TestScripts\Test-Runner.ps1 -TestCategory integration  # Integration tests (~3-5 minutes)
.\TestScripts\Test-Runner.ps1 -TestCategory comprehensive # Full tests (~5-8 minutes)
.\TestScripts\Test-Runner.ps1 -TestCategory all          # All tests (~15+ minutes)

# Pattern-based testing
.\TestScripts\Test-Runner.ps1 -TestCategory specific -TestPattern "test-menu*"

# Test discovery and information
.\TestScripts\Test-Runner.ps1 -ListTests              # See all available tests
.\TestScripts\Test-Runner.ps1 -ListCategories         # See test categories

# Advanced options
.\TestScripts\Test-Runner.ps1 -TestCategory unit -ShowVerbose -ContinueOnError
.\TestScripts\Test-Runner.ps1 -TestCategory all -LogLevel Verbose -DryRun
```

#### Test Categories and Registry

Tests are automatically discovered and categorized through a centralized **Test Registry**. Current test coverage includes:

| Category | Priority | Duration | Purpose | Test Count |
|----------|----------|----------|---------|------------|
| **syntax** | 1 | < 5 seconds | PowerShell syntax validation across 261+ files | 1 |
| **core** | 2 | 30-60 seconds | Essential functionality required for basic operation | 3 |
| **unit** | 3 | 2-4 minutes | Individual component and function tests | 51 |
| **integration** | 4 | 3-5 minutes | Cross-component integration and workflow tests | 12 |
| **comprehensive** | 5 | 5-8 minutes | Full workflow and end-to-end tests | 9 |
| **validation** | 6 | 2-3 minutes | Final validation and verification tests | 4 |
| **enhanced** | 4 | 2-3 minutes | Enhanced functionality tests (recent features) | 7 |

**Total Tests**: 87 tests providing comprehensive coverage with 100% success rates

#### Test Framework Features

**Centralized Management**:
- Single configuration file for all test definitions
- Automatic test discovery and categorization
- Consistent reporting and failure handling
- Unified logging and verbosity controls

**Advanced Capabilities**:
- **Pattern-Based Filtering**: Run specific test subsets using regex patterns
- **Dry-Run Mode**: Preview test execution without running tests
- **Verbose Output**: Detailed execution information for debugging
- **Error Continuation**: Continue running tests after failures for full validation
- **Exit Code Management**: Proper exit codes for CI/CD integration
- **Performance Tracking**: Test duration monitoring and optimization

**Legacy Compatibility**:
- Replaced deprecated `run-all-tests.ps1`
- Maintains backward compatibility for existing test scripts
- Automatic redirection from old test execution patterns

#### Test Development Standards

**Mandatory Requirements**:
- All new tests MUST be registered in Test-Runner.ps1 configuration
- Tests MUST integrate with unified reporting system
- Tests MUST follow consistent naming conventions (test-*.ps1)
- Tests MUST provide meaningful success/failure reporting

**Prohibited Patterns**:
- Direct execution of individual test files (use Test-Runner.ps1 categories)
- Standalone test scripts that bypass unified framework
- Hardcoded paths or test execution outside the framework

#### Test Coverage Areas

**Comprehensive Validation Coverage**:
- **Syntax Testing**: All 261 PowerShell files validated
- **Function Loading**: Dynamic function loading from /functions/ directory
- **Configuration System**: PSD1 file loading, merging, and validation
- **Menu System**: Hierarchical navigation and role-based filtering
- **Authentication**: Token management and Graph API integration
- **Group Operations**: Enhanced group format and legacy migration
- **Autopilot Profiles**: Profile validation and ID-based matching
- **Settings Management**: All editor and viewer functionality
- **Performance**: Load time validation and caching effectiveness
- **Security**: Encryption and credential handling

**Integration Testing**:
- Cross-component workflows and data flow
- Menu system integration with backend functions
- Configuration loading and merging across domains
- Error handling and recovery scenarios

#### Performance Validation

The test framework validates performance improvements:
- **PSD1 Migration**: Verifies 89.6% performance improvement claims
- **Caching Effectiveness**: Validates cache hit rates and performance gains
- **Function Loading**: Monitors startup time and memory usage
- **API Efficiency**: Tests Graph API batching and throttling management

### Testing Best Practices

**Total Tests**: 58+ test files across 9 categories

#### Unified Test Framework Integration

All tests use the standardized unified framework pattern:

```powershell
#!/usr/bin/env pwsh
# Load test helper and functions at script level
. "$PSScriptRoot\test-helper.ps1"
$rootPath = Split-Path -Parent $PSScriptRoot

try {
    # Load functions at script level (critical for proper scoping)
    $loadSuccess = Load-AllFunctions -RootPath $rootPath
    if (-not $loadSuccess) { throw "Failed to load functions" }

    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Test Name" -SkipFunctionCheck

    # Test execution logic...

    # Complete with proper cleanup
    $success = Complete-UnifiedTest -TestContext $testContext -PassedTests $passed -FailedTests $failed -TotalTests $total
    exit $(if ($success) { 0 } else { 1 })
}
catch {
    Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### Test Helper Framework

The `test-helper.ps1` provides the unified testing infrastructure:

#### Core Framework Functions
- **`Load-AllFunctions`**: Function loading with proper scoping
- **`Start-UnifiedTest`**: Test environment initialization
- **`Complete-UnifiedTest`**: Cleanup and result reporting
- **`Initialize-TestEnvironment`**: Mock data and global variable setup
- **`Cleanup-TestEnvironment`**: Resource cleanup

#### Utility Functions
- **`Write-TestResult`**: Standardized test result output with PowerShell 5.1 compatibility
- **`Write-TestSection`**: Consistent section headers
- **`Test-FunctionExists`**: Function availability verification
- **`New-MockDevice`**: Mock device data generation
- **`Test-PowerShellVersion`**: Cross-version compatibility checks

### Testing Best Practices

#### Framework Usage
- **Always use Test-Runner.ps1** as the single entry point for test execution
- **Load functions at script level** to avoid scoping issues
- **Use the unified framework pattern** for all new tests
- **Add new tests to appropriate categories** in the Test Registry

#### Test Development Standards
```powershell
# Proper temporary file handling (cross-platform)
$tempDir = if ($IsWindows -or $env:OS -eq "Windows_NT") { $env:TEMP } else { "/tmp" }
$testTempDir = Join-Path $tempDir "autopilot-test-$(Get-Random)"

try {
    New-Item -Path $testTempDir -ItemType Directory -Force | Out-Null
    # Test logic using $testTempDir
} finally {
    # Always cleanup
    if (Test-Path $testTempDir) {
        Remove-Item -Path $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
```

#### Migration from Legacy Patterns

❌ **Deprecated Patterns:**
```powershell
# Individual test script execution
.\TestScripts\test-specific-functionality.ps1

# Old test runner
.\TestScripts\run-all-tests.ps1
```

✅ **Unified Framework Patterns:**
```powershell
# Centralized test execution
.\TestScripts\Test-Runner.ps1 -TestCategory unit

# Pattern-based testing
.\TestScripts\Test-Runner.ps1 -TestCategory specific -TestPattern "test-specific*"
```

### Continuous Integration Integration

#### Recommended CI/CD Test Execution
```yaml
# Fast validation (< 1 minute)
- name: Syntax Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax

# Core functionality (1-2 minutes)
- name: Core Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory core

# Standard test suite (5-10 minutes)
- name: Unit and Integration Tests
  run: |
    pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit
    pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory integration

# Full validation (15+ minutes)
- name: Comprehensive Tests
  run: pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all
  timeout-minutes: 20
```

For complete testing framework documentation, see [UNIFIED_TESTING_FRAMEWORK.md](./UNIFIED_TESTING_FRAMEWORK.md).

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