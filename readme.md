# Intune Autopilot Management Script

## Overview

This PowerShell script provides a comprehensive solution for managing Windows Autopilot device enrollment through Microsoft Intune. It offers an interactive, menu-driven interface for IT administrators and help desk personnel to perform various Autopilot-related operations, including device registration, status checking, user readiness verification, and device management.

The script leverages the Microsoft Graph API to communicate with Intune and provides a secure, efficient way to manage device lifecycles in enterprise environments.

## Key Features
### App Assignment Reporting & Export

The script now includes advanced reporting and export functionality for Intune app assignments via the `GetAppAssignmentTypes` function. This enhanced feature provides robust app assignment reporting with comprehensive logging and export capabilities.

#### Key Features

- **Comprehensive Reporting**: Retrieve all Intune app assignments, automatically categorized by intent (Required, Available, Unassigned)
- **Robust CSV Export**: Export all app assignments to a single CSV file with intent/category column for easy analysis
- **PSCustomObject Structure**: Uses [PSCustomObject] for robust CSV output, eliminating hashtable property issues
- **Advanced Logging**: Extensive `Write-Verbose` and `Write-Log` (CMTrace-compatible) logging throughout for troubleshooting and audit trails
- **Programmatic Access**: Returns structured objects for automation and scripting workflows
- **Flexible Output**: Support for both append and overwrite modes when exporting to CSV

#### Usage Examples

```powershell
# Export all app assignments to CSV (overwrite mode)
GetAppAssignmentTypes -AccessToken $token -Export -outputPath "app-assignments.csv" -fileMode Overwrite

# Append to an existing CSV file
GetAppAssignmentTypes -AccessToken $token -Export -outputPath "app-assignments.csv" -fileMode Append

# Retrieve assignment data as an object (no export)
$result = GetAppAssignmentTypes -AccessToken $token
Write-Host "Total apps found: $($result.AllApps.Count)"
Write-Host "Required apps: $($result.RequiredApps.Count)"
Write-Host "Available apps: $($result.AvailableApps.Count)" 
Write-Host "Unassigned apps: $($result.UnassignedApps.Count)"

# Access specific app categories
$result.RequiredApps   # All required apps with group assignments
$result.AvailableApps  # All available apps with group assignments
$result.UnassignedApps # All unassigned apps
$result.AllApps        # Complete list of all apps with metadata
```

#### Parameters

- **`-AccessToken`** (required): Microsoft Graph API access token
- **`-Export`** (optional): Switch to enable CSV export functionality
- **`-outputPath`** (required when `-Export` used): Path to the output CSV file
- **`-fileMode`** (optional): Export mode - 'Append' or 'Overwrite' (default: 'Overwrite')

#### CSV Output Format

The exported CSV includes the following columns for comprehensive analysis:
- **Intent**: Assignment category (Required, Available, Unassigned)
- **id**: Unique app identifier in Intune
- **type**: App type (e.g., win32LobApp, mobileApp, webApp)
- **displayName**: App display name as shown in Intune console
- **applicableDeviceType**: Target device platforms (iPad, iPhone, etc.)
- **AssignedGroups**: Resolved group names (human-readable) 
- **assignedGroupCount**: Number of groups the app is assigned to

#### Advanced Logging & Troubleshooting

All operations include comprehensive logging with both `Write-Verbose` and `Write-Log` (CMTrace-compatible format):

```powershell
# Enable verbose logging for detailed troubleshooting
GetAppAssignmentTypes -AccessToken $token -Export -outputPath "apps.csv" -Verbose

# Check logs for troubleshooting
# Logs are written to the standard log file location with CMTrace-compatible format
```

**Log Categories:**
- **Information**: High-level operation status and results
- **Debug**: Detailed API calls, group caching, and data processing
- **Warning**: Missing group information or unclear assignment intents
- **Error**: API failures or export issues

#### Why This Enhancement?

- **Fixes Export Bugs**: Eliminates previous CSV export issues (no more Count/IsReadOnly/Keys/Values in output)
- **Enables Compliance Reporting**: Robust reporting for compliance, audit, and automation workflows  
- **Improves Troubleshooting**: Detailed logs provide full traceability for issue resolution
- **Supports Automation**: Structured object returns enable programmatic use in larger workflows

### Core Functionality

- **Interactive Menu System**: User-friendly interface with navigation and context-aware options
- **Autopilot Device Management**: Import devices into Autopilot with automated hash generation
- **Device Identifier Management**: Mark devices as corporate-owned in Intune using serial number, IMEI, or manufacturer/model/serial composite. Supports overwrite protection and validation. (See [Device Identifier Management](#device-identifier-management))
- **Device Status Monitoring**: Real-time device enrollment and readiness status checking
- **User Verification**: Validate user readiness for device assignment based on group memberships and other criteria
- **Bulk Operations**: Export device lists and perform batch operations
- **Settings Management**: Configure application settings through interactive menus
### Device Identifier Management

The script now supports comprehensive management of Windows Corporate Device Identifiers in Intune, enabling you to mark devices as corporate-owned for Autopilot V2 and Intune enrollment scenarios. This is essential for environments where devices must be recognized as corporate assets before enrollment.

#### Key Functions

- **GetCorpDeviceIdentifier**: Automatically retrieves the current device's manufacturer, model, and serial number using WMI. Returns a PowerShell object with these properties for use in device registration workflows.
- **AddCorporateDeviceIdentifier**: Adds a device identifier to the corporate device identifiers list in Intune via Microsoft Graph API. Supports three identifier types:
  - `SerialNumber`: Device serial number only (e.g., `"ABC123456789"`)
  - `IMEI`: Device IMEI number (e.g., `"123456789012345"`)
  - `manufacturerModelSerial`: Composite string in the format `"Manufacturer,Model,SerialNumber"` (e.g., `"Microsoft Corporation,Virtual Machine,ABC123456789"`)
  - The `-OverwriteImportedDeviceIdentities` switch allows you to overwrite existing entries if needed.
- **DeleteCorporateDeviceIdentifier**: Removes a device identifier from the corporate device identifiers list in Intune via Microsoft Graph API. Supports the same three identifier types as the Add function. Includes confirmation prompts and verification of successful deletion.

#### Usage Examples

```powershell
# Add current device using manufacturerModelSerial (Windows-specific)
$deviceInfo = GetCorpDeviceIdentifier
$identifier = "$($deviceInfo.Manufacturer),$($deviceInfo.Model),$($deviceInfo.SerialNumber)"
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier $identifier -IdentifierType "manufacturerModelSerial"

# Add device by serial number only
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"

# Add mobile device by IMEI with overwrite enabled
AddCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "123456789012345" -IdentifierType "IMEI" -OverwriteImportedDeviceIdentities

# Delete device by serial number
DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier "ABC123456789" -IdentifierType "SerialNumber"

# Delete current device using manufacturerModelSerial
$deviceInfo = GetCorpDeviceIdentifier
$identifier = "$($deviceInfo.Manufacturer),$($deviceInfo.Model),$($deviceInfo.SerialNumber)"
DeleteCorporateDeviceIdentifier -AccessToken $token -DeviceIdentifier $identifier -IdentifierType "manufacturerModelSerial"
```

#### Overwrite Protection

By default, the script will not overwrite existing device identifiers when adding. Use the `-OverwriteImportedDeviceIdentities` switch to force an update if a device is already present in Intune.

#### Safety Features

The Delete function includes several safety features:
- Interactive confirmation prompts before deletion
- Automatic verification that the device identifier exists before attempting deletion
- Post-deletion verification to confirm successful removal
- Detailed logging and error handling for troubleshooting

#### Logging and Error Handling

Both functions include extensive logging and error handling for troubleshooting and auditing. All operations are logged in CMTrace-compatible format.
### About Menu Option

A new **About** menu option has been added to the main menu. This option provides version information, copyright, licensing, and a summary of the application's capabilities. It is accessible from the main menu and is useful for users who need to quickly reference the application's version, authorship, or support resources.

To access the About menu:

1. Launch the script as usual (`./main.ps1`)
2. From the main menu, select the "About" option
3. Review the displayed information

This feature helps with support, compliance, and user education.

### Security Features

- **Azure App Registration Authentication**: Uses application credentials for secure API access
- **Password-Based Configuration Encryption**: AES-256 encryption for secure storage of sensitive credentials
- **In-Memory Security**: Configuration decryption happens in memory only - never stored as plaintext on disk
- **Automatic Encryption Setup**: First-run encryption setup with password confirmation
- **Secure Password Handling**: PowerShell SecureString objects for sensitive data protection
- **Administrative Password Change**: Forced password change functionality for enhanced security
- **Principle of Least Privilege**: Minimal required permissions for operations
- **Enhanced Token Management**: Improved token validation and refresh mechanisms

#### Administrative Password Change Feature

Administrators can now force users to change their configuration decryption password on next login by setting the `auth.changePWOnNextStart` flag to `true` in `settings.json`. This security feature is useful for:

- **Regular password rotation policies**: Enforce periodic password changes
- **Security incident response**: Force password changes after potential compromises
- **New employee onboarding**: Ensure users change default passwords
- **Compliance requirements**: Meet organizational password policies

When enabled, the script will:
1. Detect the `changePWOnNextStart` flag after successful configuration decryption
2. Prompt the user to enter a new password (with confirmation)
3. Re-encrypt the configuration file with the new password
4. Automatically update `settings.json` to set `changePWOnNextStart` to `false`
5. Continue normal operation with the new password

The process includes automatic backup creation and rollback capabilities to ensure configuration safety.

### Operational Modes

- **Full Mode**: Complete feature set for administrators
- **Help Desk Mode**: Limited features appropriate for help desk personnel
- **Registration Mode**: Focused on device registration tasks

### Additional Features

- **Windows Updates Tracking**: Apply Windows Updates while provisioning a device
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

### 1. First Run Setup (Recommended)

The application includes an interactive setup wizard that automatically launches when configuration files are missing:

```powershell
# First time running the application
.\main.ps1
```

The First Run Wizard will guide you through:
1. **Azure AD Configuration**: App ID, Tenant ID, Domain Name, and Application Name
2. **Authentication Setup**: Choose between delegated (interactive) or application (service) authentication
3. **Credential Collection**: App secrets or certificate details for application authentication
4. **File Creation**: Automatic creation and encryption of configuration files
5. **Default Settings**: Generation of comprehensive `settings.json` and `strings.json` with sensible defaults

**Required Information**: Have your Azure AD App ID, Tenant ID, domain name, and authentication credentials ready.

### 2. Manual Setup (Advanced Users Only)

*Note: Manual configuration is only needed for advanced scenarios. The First Run Wizard handles standard setups automatically.*

1. **Clone or download** the script files to a local directory
2. **Create the secrets folder**: Create a `.secrets` folder in the script directory
3. **Configure authentication**: Place your `config.json` file in the `.secrets` folder
4. **Configure application settings**: Ensure `settings.json` is configured for your environment
5. **Set up encryption**: On first run, the script will prompt you to encrypt your configuration file

### 3. Authentication Configuration

The script can use "Delegated" or "App" permissions to authenticate. Delegated authentication provides you with the ability to better audit operations executed by the app and allows dynamic scopes based on the user's existing roles.

Create a `config.json` file in the `.secrets` folder with your Azure App Registration details:

```json
{
  "domain": "your-domain.com",
  "TenantId": "your-tenant-id",
  "AppId": "your-app-id",
  "AppSecret": "your-app-secret",
  "Thumbprint": "your-cert-thumbprint", 
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

### 4. Running the Application

```powershell
# Standard execution (launches wizard if first run)
.\main.ps1

# Development/testing with specific configuration
.\main.ps1 -appMode "test" -Verbose -LogLevel "Debug"

# Force authentication refresh
.\main.ps1 -ForceNewToken -Deligated

# Domain-specific configuration override
.\main.ps1 -configFile "custom-config.json" -appMode "helpDesk"
```

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
- `changePWOnNextStart`: Force password change on next application start (boolean)
- `authType`: Type of authentication flow ("PublicAuthFlow", "Interactive", "Private")
- `renewalLeadTime`: Time in minutes before token expiration to renew
- `NoSaveRefreshToken`: Whether to save refresh tokens (boolean)
- `SecureString`: Whether to use secure string for sensitive inputs (boolean)
- `ForceNewToken`: Whether to force generation of new tokens (boolean)
- `CacheType`: Token cache type ("Memory", "File")
- `scope`: Array of required Microsoft Graph API scopes

#### Password Change Control

The `changePWOnNextStart` setting provides administrators with control over configuration password security:

```json
{
  "auth": {
    "changePWOnNextStart": true,
    "authType": "PublicAuthFlow"
  }
}
```

When set to `true`, the application will:
- Prompt the user to change their encryption password after successful login
- Re-encrypt the configuration file with the new password
- Automatically reset the flag to `false` to prevent repeated prompts
- Provide backup and rollback capabilities for safety

This feature is particularly useful for:
- Enforcing password rotation policies
- Responding to security incidents
- Onboarding new users with temporary passwords
- Meeting compliance requirements

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

## Microsoft Graph API Integration

### Required Scopes
The application requires these Microsoft Graph API permissions:
- `User.Read.All` - User profile and group membership access
- `Device.Read.All` - Entra ID device object access
- `DeviceManagementManagedDevices.ReadWrite.All` - Intune device management
- `DeviceManagementServiceConfig.ReadWrite.All` - Autopilot device management
- `DeviceManagementManagedDevices.PrivilegedOperations.All` - LAPS password access
- `BitlockerKey.Read.All` - BitLocker recovery key access

### API Endpoints
Primary endpoints used:
- `/deviceManagement/windowsAutopilotDeviceIdentities` - Autopilot device management
- `/users/{id}/registeredDevices` - User device associations
- `/deviceManagement/managedDevices` - Intune managed device data
- `/directory/deviceLocalCredentials` - LAPS credentials

### Required API Scopes (Detailed)

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

## Domain Configuration

The application supports multiple domains with specific settings:
- **gao.gov**: Production environment with group-based access control
- **arabictutor.com**: Test environment with different device naming conventions

Each domain can override global settings for device naming, group memberships, Autopilot profiles, and security restrictions.

## Security Considerations

- Configuration files in `.secrets/` directory are encrypted using `EncryptionFunctions.ps1`
- Code signing is implemented via Azure Trusted Signing service
- Authentication tokens are cached securely with automatic refresh
- Domain-specific settings allow environment isolation
- All Microsoft Graph API calls use least-privilege scopes

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
