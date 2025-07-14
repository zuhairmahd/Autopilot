# Intune Autopilot Management Script

## Overview

This PowerShell script provides a comprehensive solution for managing Windows Autopilot device enrollment through Microsoft Intune. It offers an interactive menu-driven interface for IT administrators and help desk personnel to perform various Autopilot-related operations, including device registration, status checking, user readiness verification, and device management.

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
- **Automatic Credential Management**: Clipboard integration for secure credential handling

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

#### Configuration File Structure
The authentication system uses two separate configuration files:
- `config.json`: Contains sensitive credentials (automatically encrypted)
- `settings.json`: Contains application settings and authentication scope (plaintext)

#### Creating the Configuration File
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
  }
}
```

### 3. Password-Based Encryption Setup

#### First Run Experience
When you run the script for the first time with an unencrypted configuration file:

1. **Detection**: The script automatically detects that your `config.json` is not encrypted
2. **Setup Prompt**: You'll see: `"Configuration file is not encrypted. Setting up encryption..."`
3. **Password Creation**: You'll be prompted to create an encryption password with confirmation
4. **Automatic Encryption**: The configuration file is encrypted using AES-256 encryption
5. **Confirmation**: You'll see: `"Configuration file encrypted successfully."`

#### Subsequent Runs
For all subsequent runs with an encrypted configuration file:

1. **Detection**: The script detects the encrypted configuration file
2. **Password Prompt**: You'll see: `"The configuration file is encrypted. Please enter your password to decrypt it."`
3. **Password Entry**: Enter your encryption password (up to 3 attempts allowed)
4. **In-Memory Decryption**: The configuration is decrypted in memory only - never stored as plaintext on disk
5. **Confirmation**: You'll see: `"Configuration file decrypted successfully."`

#### Security Benefits
- **AES-256 Encryption**: Military-grade encryption for your sensitive credentials
- **No Plaintext Storage**: Configuration file remains encrypted on disk at all times
- **Secure Memory Handling**: Decryption happens in memory with automatic cleanup
- **Password Protection**: Your credentials are protected even if someone accesses your files
- **Retry Protection**: Up to 3 password attempts with clear error messages

### 4. First Run
1. Open PowerShell as Administrator
2. Navigate to the script directory
3. Run: `.\main.ps1`
4. **Set up encryption** when prompted (first run only)
5. **Enter your password** for subsequent runs
6. Follow the interactive setup prompts

## Usage

### Basic Usage
```powershell
# First run - will prompt for encryption password setup
.\main.ps1

# Subsequent runs - will prompt for decryption password
.\main.ps1

# Run with custom settings file
.\main.ps1 -InitFile "custom-settings.json"

# Run in help desk mode
.\main.ps1 -appMode "helpDesk"

# Run with verbose logging
.\main.ps1 -Verbose
```

**Note**: The script will automatically detect whether your configuration file is encrypted and prompt accordingly:
- **First run**: Prompts to set up encryption with password confirmation
- **Subsequent runs**: Prompts for your encryption password (up to 3 attempts)
- **Security**: Configuration file remains encrypted on disk at all times

### Interactive Operations

#### Device Registration
1. Select "Autopilot menu" from the main menu
2. Choose "Quick Import device into Autopilot" for current device
3. Or "Custom import device into Autopilot" for manual entry
4. Follow the prompts to complete registration

#### Device Status Checking
1. Select "Check device status" from the main menu
2. Choose lookup method:
   - By Serial Number
   - By User
3. Enter required information and view detailed status

#### User Readiness Verification
1. Select "Check user readiness for Windows 11 device"
2. Enter user email address
3. Review group membership and readiness status

## Command Line Parameters

### Authentication Parameters
- `-configFile`: Path to authentication configuration file (default: `.\.secrets\config.json`)
- `-Deligated`: Use delegated authentication flow
- `-AuthType`: Authentication type (`PublicAuthFlow`, `Interactive`, `Private`)
- `-Scope`: Custom authentication scope
- `-ForceNewToken`: Force generation of new access token
- `-ForceNewRefreshToken`: Force generation of new refresh token
- `-NoSaveRefreshToken`: Don't save refresh token for future use

### Logging Parameters
- `-LogFile`: Path to custom log file (default: `$pwd\\Logs\\Autopilot.log`)
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
- `-Update`: Check for and apply script updates
- `-ForceUpdate`: Force update even if local files exist

### Utility Parameters
- `-Reconfigure`: Reconfigure application settings
- `-ReInitialize`: Reinitialize configuration files
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
- `testMode`: Enable test mode operations (boolean)
- `configFile`: Path to authentication configuration file
- `maxWaitTime`: Default maximum wait time for operations
- `timeInSeconds`: Default retry interval
- `Release`: Default release branch
- `Repo`: Default repository source
- `appMode`: Default application mode
- `requiredScopes`: Array of required Microsoft Graph API scopes

### Domain Settings
Each domain can have specific configuration:
- `groupsToInclude`: Array of required user groups
- `groupsToExclude`: Array of groups to exclude
- `settings`: Domain-specific overrides for global settings
  - `deviceNamePrefix`: Prefix for device names
  - `maxNumberOfDevicesAllowed`: Maximum devices per user
  - `MinimumDevicePhysicalMemoryInGB`: Minimum RAM requirement
  - `GroupTag`: Domain-specific Autopilot group tag
  - `DesiredAutopilotProfiles`: Array of acceptable Autopilot profiles

### Required API Scopes
The script requires the following Microsoft Graph API permissions:
- `User.Read.All`: Read user profiles and group memberships
- `Device.Read.All`: Read device objects
- `DeviceManagementApps.ReadWrite.All`: Manage app assignments
- `DeviceManagementConfiguration.ReadWrite.All`: Read and write device configuration policies
- `DeviceManagementManagedDevices.ReadWrite.All`: Read and write managed device properties
- `DeviceManagementManagedDevices.PrivilegedOperations.All`: Privileged operations (LAPS passwords)
- `DeviceManagementServiceConfig.ReadWrite.All`: Manage Autopilot device identities
- `BitlockerKey.Read.All`: Read BitLocker recovery keys
- `offline_access`: Maintain access with refresh tokens
- `openid`: User sign-in with OpenID Connect
- `profile`: Basic user profile information during sign-in

## Advanced Features

### Menu Navigation
- Use arrow keys to navigate menu options
- Press Enter to select items
- Type 'back' or 'b' to return to previous menus
- Type 'quit' or 'q' to exit the application

### Logging and Debugging
- Use `-Verbose` for detailed operation logging including encryption operations
- Use `-LogLevel` to control log verbosity (Error, Warning, Information, Verbose, Debug)
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
- Track and display Windows update installation history
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
- [Windows Autopilot Documentation](https://learn.microsoft.com/en-us/autopilot/)
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/)
- [Intune Device Management](https://learn.microsoft.com/en-us/mem/intune/)

For technical support or feature requests, please contact the script maintainer or submit an issue.