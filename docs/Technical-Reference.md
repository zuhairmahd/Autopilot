# Technical Reference Documentation

This document contains technical implementation details, API integration information, and developer-focused documentation for the Windows Autopilot Management Tool.

## Table of Contents

- [Microsoft Graph API Integration](#microsoft-graph-api-integration)
- [Authentication Implementation](#authentication-implementation)
- [Configuration System Technical Details](#configuration-system-technical-details)
- [Security Implementation](#security-implementation)
- [Function Reference](#function-reference)
- [Development Guidelines](#development-guidelines)

## Microsoft Graph API Integration

### Required Scopes

The application requires these Microsoft Graph API permissions:

| Scope | Purpose | Endpoints |
|-------|---------|-----------|
| `User.Read.All` | Read user profiles, group memberships, and registered devices | `/users`, `/users/{id}`, `/users/{id}/memberOf`, `/users/{id}/registeredDevices` |
| `Device.Read.All` | Read Microsoft Entra ID device objects | `/devices` |
| `DeviceManagementApps.ReadWrite.All` | Read application information and manage app assignments | `/deviceAppManagement/mobileApps`, `/deviceAppManagement/mobileApps/{id}/assignments` |
| `DeviceManagementConfiguration.Read.All` | Read Intune device configuration policies | `/deviceManagement/deviceConfigurations` |
| `DeviceManagementManagedDevices.Read.All` | Read Intune managed device properties | `/deviceManagement/managedDevices`, `/deviceManagement/managedDevices/{id}` |
| `BitlockerKey.Read.All` | Read BitLocker recovery keys for all devices | `/informationProtection/bitlocker/recoveryKeys` |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | Highly privileged operations, specifically to read local admin (LAPS) passwords | `/directory/deviceLocalCredentials` |
| `DeviceManagementServiceConfig.ReadWrite.All` | Read Autopilot events and manage Autopilot device identities | `/deviceManagement/autopilotEvents`, `/deviceManagement/importedWindowsAutopilotDeviceIdentities`, `/deviceManagement/windowsAutopilotDeviceIdentities` |

### Primary API Endpoints

The application interacts with these Microsoft Graph API endpoints:

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

## Authentication Implementation

### Authentication Flows

The application supports multiple OAuth 2.0 authentication flows:

#### PublicAuthFlow (Recommended)
- **Type**: Public client MSAL authentication
- **Benefits**: No app secrets required, enhanced security
- **Use Case**: Standard deployments where app secrets are not desired
- **Configuration**: `"authType": "PublicAuthFlow"`

#### Interactive Flow
- **Type**: Browser-based user authentication
- **Benefits**: Full user interaction, supports MFA
- **Use Case**: Interactive scenarios requiring user consent
- **Configuration**: `"authType": "Interactive"`

#### Private Flow
- **Type**: Confidential client with app secrets or certificates
- **Benefits**: Service-to-service authentication
- **Use Case**: Automated scenarios, background services
- **Configuration**: `"authType": "Private"`

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
    "scope": [
      "offline_access",
      "openid", 
      "Device.ReadWrite.All",
      "DeviceManagementApps.Read.All",
      "DeviceManagementConfiguration.ReadWrite.All",
      "DeviceManagementManagedDevices.PrivilegedOperations.All",
      "DeviceManagementManagedDevices.ReadWrite.All",
      "DeviceManagementServiceConfig.ReadWrite.All"
    ]
  }
}
```

## Configuration System Technical Details

### Hierarchical Configuration System

The application uses a three-tier configuration hierarchy:

1. **Runtime Parameters** (highest priority) - Command-line arguments
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`)
3. **Global Settings** (`settings.json` → `globalSettings`)

### Configuration File Structure

#### settings.json Structure
```json
{
  "description": "Configuration file for the Autopilot script",
  "version": "1.3.0.0",
  "auth": { /* Authentication settings */ },
  "globalSettings": { /* Global configuration */ },
  "domains": {
    "domain1.com": {
      "groupsToInclude": [],
      "groupsToExclude": [],
      "settings": { /* Domain-specific overrides */ }
    }
  },
  "menuItemsToInclude": [ /* Menu customization */ ]
}
```

#### Configuration Merging Logic

Configuration merging is handled by the `MergeSettings` function in `SettingsHelperFunctions.ps1`:

- Domain-specific settings override global settings
- Runtime parameters override both domain and global settings
- Conflict resolution uses 'Local' priority by default

### Global Settings Reference

| Setting | Type | Purpose |
|---------|------|---------|
| `operatingSystem` | String | Target operating system (default: "Windows") |
| `autoUpdate` | Boolean | Enable automatic script updates |
| `testMode` | Boolean | Enable test mode operations |
| `maxWaitTime` | Integer | Default maximum wait time for operations |
| `timeInSeconds` | Integer | Default retry interval |
| `appMode` | String | Application mode ("full", "helpDesk", "registration") |
| `showLicenseBanner` | Boolean | Show license banner and disclaimer |
| `maxUserMatchDisplay` | Integer | Number of users to display in search results |
| `deviceNamePrefix` | String | Device name prefix for lookups |
| `maxNumberOfDevicesAllowed` | Integer | Maximum devices per user account |
| `MaxUserNameLength` | Integer | Maximum username length |
| `MinUsernameLength` | Integer | Minimum username length |
| `MaxSerialNumberLength` | Integer | Maximum serial number length |
| `MinSerialNumberLength` | Integer | Minimum serial number length |
| `preferredBrowser` | String | Browser for authentication (Chrome, Firefox, Edge, Default) |
| `privateSession` | Boolean | Use private/incognito browser sessions |
| `MinimumDevicePhysicalMemoryInGB` | Integer | Minimum memory requirement for device readiness |
| `GroupTag` | String | Default Group Tag for Autopilot registration |
| `userPatternsToExclude` | Array | User patterns to exclude from reporting |
| `DesiredAutopilotProfiles` | Array | Required Autopilot profiles for user readiness |

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

#### Security Functions Reference

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
- `GetCorpDeviceIdentifier`: Retrieve device manufacturer, model, serial number
- `AddCorporateDeviceIdentifier`: Add device to corporate identifier list
- `DeleteCorporateDeviceIdentifier`: Remove device from corporate identifier list
- Device import, validation, and assignment checking functions

#### DeviceAndUserLookupFunctions.ps1
- User/device queries and lookups
- BitLocker recovery key management
- LAPS credential access
- Device status verification functions

#### GraphAPIFunctions.ps1
- Authentication and token management
- Microsoft Graph API communication
- JWT token handling and validation
- Scope management and validation

#### MenuFunctions.ps1
- `NewMenu`: Create menu objects
- `AddMenuItem`: Add actions or submenus
- `ShowMenu`: Display and handle menu interactions
- `Get-CallingContext`: Manage navigation context
- `Test-MenuItemIncluded`: Menu inclusion filtering

#### SettingsHelperFunctions.ps1
- `MergeSettings`: Configuration hierarchy merging
- Configuration validation and loading
- Domain-specific setting management

#### EncryptionFunctions.ps1
- `Load-EncryptedConfigFile`: Configuration file decryption
- `Invoke-JsonFileEncryption`: Core encryption operations
- `Get-SecurePassword`: Secure password collection
- `Clear-SecureMemory`: Memory cleanup operations

### Corporate Device Identifier Management

The application provides comprehensive management of Windows Corporate Device Identifiers:

#### Supported Identifier Types
1. **SerialNumber**: Device serial number only (`"ABC123456789"`)
2. **IMEI**: Device IMEI number (`"123456789012345"`)
3. **manufacturerModelSerial**: Composite identifier (`"Manufacturer,Model,SerialNumber"`)

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

## Development Guidelines

### PowerShell 5.1 Compatibility
- Maintain compatibility with PowerShell 5.1 for Windows environments
- Use regular hashtables instead of ordered hashtables
- Add version comments if compatibility cannot be maintained

### Logging Standards
- Use `Write-Log` function consistently with CMTrace format support
- Include `$functionName = $MyInvocation.MyCommand.Name` at function start
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

### Testing Approach
- Tests located in `/TestScripts/` directory
- Create isolated test environments
- Load specific function modules for testing
- Execute test scenarios with validation
- Cleanup test environment after execution

### Build and Deployment
- Use `CreateRelease.ps1` for signed executable releases
- Support for Azure Trusted Signing service
- Domain-specific configurations via environment switchers
- PowerShell module creation capability

---

*This technical documentation provides implementation details for developers and system administrators. For end-user documentation, please refer to the main README.md file.*