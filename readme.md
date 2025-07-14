# Intune Autopilot Management Script

## Overview

This PowerShell script provides a comprehensive solution for managing Windows Autopilot device enrollment through Microsoft Intune. It offers an interactive, menu-driven interface for IT administrators and help desk personnel to perform various Autopilot-related operations, including device registration, status checking, user readiness verification, and device management.

The script leverages the Microsoft Graph API to communicate with Intune and provides a secure, efficient way to manage device lifecycles in enterprise environments.

## Key Features

### Core Functionality

- **Interactive Menu System**: User-friendly interface with navigation and context-aware options
- **Autopilot Device Management**: Import devices into Autopilot with automated hash generation
- **Device Status Monitoring**: Real-time device enrollment and readiness status checking
- **User Verification**: Validate user readiness for device assignment based on group memberships
- **Bulk Operations**: Export device lists and perform batch operations
- **Settings Management**: Configure application settings through interactive menus

### Security Features

- **Azure App Registration Authentication**: Uses application credentials for secure API access
- **Password-Based Configuration Encryption**: AES-256 encryption for secure storage of sensitive credentials
- **In-Memory Security**: Configuration decryption happens in memory only - never stored as plaintext on disk
- **Automatic Encryption Setup**: First-run encryption setup with password confirmation
- **Secure Password Handling**: PowerShell SecureString objects for sensitive data protection
- **Principle of Least Privilege**: Minimal required permissions for operations
- **Rotating Secret Keys**: Enhanced security through credential rotation
- **Automatic Clipboard Integration**: LAPS passwords and BitLocker keys automatically copied to clipboard
- **Enhanced Token Management**: Improved token validation and refresh mechanisms

### Operational Modes

- **Full Mode**: Complete feature set for administrators
- **Help Desk Mode**: Limited features appropriate for help desk personnel
- **Registration Mode**: Focused on device registration tasks

### Additional Features

- **Windows Updates Tracking**: Monitor and display Windows update history
- **Enhanced Logging**: CMTrace format support with automatic log rotation
- **Multi-Repository Support**: GitHub and GitLab repository integration

## Prerequisites

### System Requirements

- Windows 10/11 or Windows Server
- PowerShell 5.1 or later
- Administrator privileges (for some operations)
- Network connectivity to Microsoft Graph API endpoints

### Azure Configuration

- Azure AD App Registration with appropriate permissions
- Intune subscription and configuration
- Required API permissions (see [Settings.json Configuration](#settingsjson-configuration))

## Setup Instructions

### 1. Initial Setup

1. **Clone or download** the script files to a local directory
2. **Create the secrets folder**: Create a `.secrets` folder in the script directory
3. **Configure authentication**: Place your `config.json` file in the `.secrets` folder
4. **Configure application settings**: Ensure `settings.json` is configured for your environment
5. **Set up encryption**: On first run, the script will prompt you to encrypt your configuration file

### 2. Authentication Configuration

The script can use "Delegated" or "App" permissions to authenticate. Autopilot device registration operations can work with application permissions only, honoring the principle of least privilege. Other operations require you to use delegated authentication. Delegated authentication provides you with the ability to better audit operations executed by the app and allows dynamic scopes based on the user's existing roles.

Create a `config.json` file in the `.secrets` folder with your Azure App Registration details:

```json
{
  "domain": "your-domain.com",
  "TenantId": "your-tenant-id",
  "AppId": "your-app-id",
  "AppSecret": "your-app-secret",
  "Thumbprint": "your-cert-thumbprint",
  "Subject": "your-certificate-subject"
}
```

#### Authentication Settings

The authentication settings are configured in the `settings.json` file at the root level under the `auth` object:

```json
{
  "auth": {
    "Delegated": true, // Recommended configuration. If you set this to false, you must provide an app secret or a certificate thumbprint.
    "authType": "PublicAuthFlow", // Also recommended, as it does not require app secrets.
    "renewalLeadTime": 5, // How many minutes before the access token expires it should be renewed
    "NoSaveRefreshToken": false, // Do not save the refresh token. Set to true if running from a USB stick.
    "SecureString": false,
    "ForceNewToken": false,
    "CacheType": "Memory",
    "scope": [
      "Device.ReadWrite.All",
      "DeviceManagementApps.Read.All",
      "DeviceManagementConfiguration.ReadWrite.All",
      "DeviceManagementManagedDevices.PrivilegedOperations.All",
      "DeviceManagementManagedDevices.ReadWrite.All",
      "DeviceManagementServiceConfig.ReadWrite.All"
    ]
  },
  "domain": "your-domain.com",
  "TenantId": "your-tenant-id",
  "AppId": "your-app-id",
  "AppSecret": "your-app-secret", // The remaining fields are only needed if using application scopes or a delegated authtype other than Public Flow
  "Thumbprint": "your-cert-thumbprint",
  "Subject": "your-certificate-subject"
}
```

### 3. First Run

1. Open PowerShell and navigate to the script directory
2. Run: `./main.ps1`
3. Follow the menu prompts

## Usage

### Basic Usage

```powershell
# Run with default settings
./main.ps1

# Run with custom settings file
./main.ps1 -InitFile "custom-settings.json"

# Run in help desk mode
./main.ps1 -appMode "helpDesk"

# Run with verbose logging
./main.ps1 -Verbose
```

**Note**: The script will automatically detect whether your configuration file is encrypted and prompt accordingly:

- **First run**: Prompts to set up encryption with password confirmation
- **Subsequent runs**: Prompts for your encryption password (up to 3 attempts)
- **Security**: Configuration file remains encrypted on disk at all times

### Interactive Operations

#### Device Registration

1. Select "Autopilot menu" from the main menu
2. Choose "Quick Import device into Autopilot" to upload the hardware hash of the current device using the settings in `settings.json`
3. Or "Custom import device into Autopilot" for manual entry of the Autopilot profile and other parameters
4. Follow the prompts to complete registration

#### Device Status Checking

1. Select "Check device status" from the main menu
2. Choose lookup method:
   - By Serial Number
   - By User
3. Enter required information and view detailed status

#### User Readiness Verification

1. Select "Check user readiness"
2. Enter user email address
3. Review group membership and readiness status
4. If the user is in the correct group, you will be prompted to enter the serial number of the device you want to provide to the user. The script will then check to make sure the device is not registered to someone else and that it has downloaded the required apps and policies.

## Command Line Parameters

### Authentication Parameters

- `-configFile`: Path to authentication configuration file (default: `./.secrets/config.json`)
- `-Delegated`: Use delegated authentication flow
- `-AuthType`: Authentication type (`PublicAuthFlow`, `Interactive`, `Private`)
- `-Scope`: Custom authentication scope
- `-ForceNewToken`: Force generation of new access token
- `-ForceNewRefreshToken`: Force generation of new refresh token
- `-NoSaveRefreshToken`: Don't save refresh token for future use

### Logging Parameters

- `-LogFile`: Path to custom log file (default: `$pwd/Logs/Autopilot.log`)
- `-LogLevel`: Set logging verbosity (`Error`, `Warning`, `Information`, `Verbose`, `Debug`)

### Configuration Parameters

- `-InitFile`: Path to settings configuration file (default: `settings.json`)
- `-appMode`: Application mode (`full`, `helpDesk`, `registration`)
- `-GroupTag`: Autopilot group tag for device assignment
- `-maxWaitTime`: Maximum wait time for operations (seconds)
- `-timeInSeconds`: Retry interval timing (seconds)

### Repository Parameters

- `-Repo`: Repository source (`github`, `gitlab`)
- `-Release`: Release branch to use (default: `master`)
- `-Update`: Check for and apply script updates (to do)
- `-ForceUpdate`: Force update even if local files exist (to do)

### Utility Parameters

- `-showAuth`: Display authentication configuration
- `-showSettings`: Display current settings
- `-SecureString`: Use secure string for sensitive inputs

## Settings.json Configuration

The `settings.json` file contains the primary configuration for the script with a hierarchical structure supporting global settings, authentication configuration, and domain-specific overrides.

### Structure Overview

```json
{
  "description": "Configuration file for the Autopilot script",
  "version": "1.0",
  "auth": {
    "Deligated": true,
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
  },
  "globalSettings": {
    // Global configuration applied to all domains
  },
  "domains": {
    "domain1.com": {
      // Domain-specific configuration
      "groupsToInclude": [],
      "groupsToExclude": [],
      "settings": {}
    }
  }
}
```

### Authentication Configuration

The `auth` object at the root level of `settings.json` contains all authentication-related settings:

- `Deligated`: Whether to use delegated authentication (boolean)
- `authType`: Type of authentication flow ("PublicAuthFlow", "Interactive", "Private")
- `renewalLeadTime`: Time in minutes before token expiration to renew
- `NoSaveRefreshToken`: Whether to save refresh tokens (boolean)
- `SecureString`: Whether to use secure string for sensitive inputs (boolean)
- `ForceNewToken`: Whether to force generation of new tokens (boolean)
- `CacheType`: Token cache type ("Memory", "File")
- `scope`: Array of required Microsoft Graph API scopes

### Global Settings

- `operatingSystem`: Target operating system (default: "Windows")
- `testMode`: Enable test mode operations (boolean, only needed for unit tests)
- `configFile`: Path to authentication configuration file
- `maxWaitTime`: Default maximum wait time for operations
- `timeInSeconds`: Default retry interval
- `Release`: Default release branch
- `Repo`: Default repository source
- `appMode`: Default application mode
- `requiredScopes`: Array of required Microsoft Graph API scopes
- `showLicenseBanner`: Show the license banner and disclaimer
- `maxUserMatchDisplay`: The number of users to display when a user lookup results in more than one user
- `deviceNamePrefix`: The device name prefix to use to lookup devices
- `maxNumberOfDevicesAllowed`: The number of devices allowed to a user per account (needed to check user readiness)
- `MaxUserNameLength`: The maximum username length (used for username validation)
- `MinUsernameLength`: The minimum length of a user ID
- `MaxSerialNumberLength`: Maximum number of characters allowed for a serial number
- `MinSerialNumberLength`: Minimum serial number length
- `preferredBrowser`: Browser to use for authentication. Can be Chrome, Firefox, Edge, or Default. The default browser is used if this value is not present.
- `privateSession`: Whether to open the browser authentication session in a private (incognito) mode (needed in some organizations)
- `MinimumDevicePhysicalMemoryInGB`: How much memory a device needs to have to be "user ready"
- `GroupTag`: The default Group Tag to use for Autopilot registration
- `userPatternsToExclude`: An array of user pattern names to exclude from reporting. This is especially helpful if administrators authenticate with separate identities, as we are only interested in the primary identity.
- `DesiredAutopilotProfiles`: An array of Autopilot profiles that the device has to be assigned to in order to pass user readiness

### Domain Settings

Each domain can have specific configuration:

- `groupsToInclude`: Array of required user groups that the user must belong to in order to be ready to receive a device
- `groupsToExclude`: Array of groups that users should not be a part of, otherwise their enrollment may fail
- `settings`: Domain-specific overrides for global settings. You can use any of the settings documented in GlobalSettings above. If a setting exists in both the Global Settings and Domain Settings, the Domain setting will take precedence.

### Required API Scopes

We recommend you use "Delegated" authentication in order to decrease exposure (through leakage of secrets) and to ensure that users have access to the scopes they require, while preventing them from accessing resources they do not have permissions to access.
The script requires the following Microsoft Graph API permissions, which can either be assigned to your Azure app (and thus not require user interaction), or can be requested by the user when they first sign in (using Delegated Authentication). Additional permissions may be required (for reading LAPS passwords or BitLocker recovery keys) and to support future functionality. See the Microsoft Graph API documentation for more details.

- `User.Read.All`: Read user profiles and group memberships -- required to check user groups
- `Group.ReadWrite.All`
- `GroupMember.ReadWrite.All`
- `Device.Read.All`: Read device objects
- `DeviceManagementApps.ReadWrite.All`: Manage app assignments
- `DeviceManagementConfiguration.ReadWrite.All`: Read and write device configuration policies
- `DeviceManagementManagedDevices.ReadWrite.All`: Read and write managed device properties
- `DeviceManagementServiceConfig.ReadWrite.All`: Manage Autopilot device identities

## Advanced Features

### Menu Navigation

- Type the number of the menu option you want to select
- Press Enter to select items
- The last two options in the menu allow you to go back to the previous menu or to the main menu, depending on how deep you are in the menu system.

### Logging and Debugging

- Use `-Verbose` for detailed operation logging
- Use `-LogLevel` to control log verbosity (`Error`, `Warning`, `Information`, `Verbose`, `Debug`)
- CMTrace format support for enhanced log viewing
- Automatic log rotation with size management
- Check log outputs for troubleshooting authentication and encryption issues
- Settings validation occurs automatically
- Encryption process is logged for security auditing

### Configuration Security

- **Encrypted Storage**: Sensitive credentials are always encrypted on disk
- **Password Protection**: Only you can decrypt your configuration with your password
- **No Plaintext Leakage**: Configuration is never stored as plaintext after initial encryption
- **Secure Memory Handling**: Decrypted data is automatically cleaned from memory
- **Audit Trail**: All encryption/decryption operations are logged for security monitoring

### Batch Operations

- Export device lists in CSV format
- Bulk device management operations
- Automated profile assignment verification

### Windows Updates Module

- Track and display Windows update installation history (especially useful when pre-provisioning devices to make sure they have the latest updates before they are given to the user)
- Comprehensive logging of update information
- Integration with device management workflows

### Password-Based Configuration Encryption

The script includes a comprehensive encryption system for protecting sensitive configuration data:

#### Security Features

- **AES-256 Encryption**: Military-grade encryption for configuration files
- **SHA-256 Key Derivation**: Secure key generation from user passwords
- **Memory-Only Decryption**: Configuration never stored as plaintext on disk
- **Automatic Key Cleanup**: Sensitive data automatically cleared from memory
- **Password Retry Protection**: Up to 3 password attempts with clear error messages
- **Secure Password Handling**: PowerShell SecureString objects for input protection

#### User Experience

- **First Run**: Automatic detection and setup of encryption with password confirmation
- **Subsequent Runs**: Seamless password-based decryption workflow
- **Error Handling**: Clear error messages and retry mechanisms
- **Backward Compatibility**: Existing unencrypted files are automatically detected and can be encrypted

#### Technical Implementation

- **Temporary Encryption Keys**: Generated for secure in-memory operations during runtime
- **Base64 Encoding**: Encrypted data is stored as Base64 for safe file storage
- **JSON Validation**: Automatic detection of encrypted vs. unencrypted configuration files
- **Memory Protection**: Automatic cleanup of sensitive variables and garbage collection

### Clipboard Integration

- LAPS passwords automatically copied to clipboard for secure access
- BitLocker recovery keys automatically copied to clipboard
- Device authentication codes copied for easy access
- Reduced verbosity for sensitive operations

## Troubleshooting

### Common Issues

1. **Authentication Failures**: Verify `config.json` credentials and API permissions
2. **Device Not Found**: Check serial number format and Intune enrollment status
3. **Permission Denied**: Ensure PowerShell is running as Administrator for device operations
4. **Network Connectivity**: Verify access to Microsoft Graph API endpoints
5. **Password Authentication Issues**:
   - **Forgotten Password**: The encryption password cannot be recovered - you'll need to delete the encrypted config file and recreate it
   - **Invalid Password**: Check for typos and ensure correct password entry (up to 3 attempts allowed)
   - **Configuration Corruption**: If the encrypted file becomes corrupted, delete it and recreate from your backup
6. **Configuration File Issues**:
   - **Missing Config**: Ensure `config.json` exists in the `.secrets` folder
   - **Invalid Format**: Verify JSON syntax in configuration files
   - **Auth Settings**: Ensure authentication settings are properly configured in `settings.json`

### Error Handling

The script includes comprehensive error handling:

- JSON syntax validation
- File existence checks
- Fallback to default values
- Detailed logging for troubleshooting
- Graceful exception handling

## Support and Resources

### Documentation

- See `docs/` folder for detailed technical documentation
- `docs/Consolidated-Configuration-System.md`: Configuration system details
- `docs/STRINGS_README.md`: String localization information

### Microsoft Resources

- [Windows Autopilot Documentation](https://learn.microsoft.com/en-us/mem/autopilot/)
- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/)
- [Intune Device Management](https://learn.microsoft.com/en-us/mem/intune/)

For technical support or feature requests, please contact the script maintainer or submit an issue.
