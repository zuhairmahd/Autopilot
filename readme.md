# Windows Autopilot Management Tool

A comprehensive PowerShell-based solution for managing Windows Autopilot device enrollment through Microsoft Intune. This tool provides an interactive, menu-driven interface for IT administrators and help desk personnel to perform various Autopilot-related operations.

## Table of Contents

- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Installation and Setup](#installation-and-setup)
- [Menu Options](#menu-options)
- [Advanced Configuration](#advanced-configuration)
- [Security and Password Management](#security-and-password-management)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Overview

This script leverages the Microsoft Graph API to communicate with Intune and provides a secure, efficient way to manage device lifecycles in enterprise environments. The tool features an intuitive menu system that guides users through device registration, status checking, user readiness verification, and device management tasks.

### Key Features

- **🎯 Role-Based Interface**: Hierarchical app mode system with inheritance-based privilege escalation. Seven built-in modes (Full, Admin, Advanced, Helpdesk, Registration, Advanced Registration, Custom) with tailored menu options and capabilities for different organizational roles. See [App Mode Configuration Guide](docs/APP_MODE_CONFIGURATION.md) for detailed role definitions and defaults.
- **📋 Interactive Menu System**: Intuitive hierarchical navigation with keyboard shortcuts and stack-based history
- **⚡ Device Assignment Workflow**: Streamlined device-to-user assignment with automated readiness validation
- **🔍 Comprehensive Device Monitoring**: Real-time device enrollment status, BitLocker keys, LAPS credentials, and health monitoring
- **🚀 Autopilot Device Management**: Complete device lifecycle from import to deployment with hash generation and profile assignment
- **👥 User Readiness Validation**: Intelligent assessment of user eligibility based on group memberships and organizational policies
- **🏢 Corporate Device Management**: Mark devices as corporate-owned for Intune Device Preparation and compliance
- **📊 Advanced Reporting & Export**: CSV exports for devices, assignments, storage analysis, and application deployments with comprehensive group assignment analysis covering scripts, app protection policies, security baselines, and configuration policies. Optimized with Microsoft Graph batch API for efficient data retrieval.
- **🔐 Enterprise Security**: AES-256 encrypted configuration, secure credential handling, and multi-factor authentication support
- **⚙️ Automated Setup**: First Run Wizard with guided configuration and automatic credential encryption
- **🔄 Smart Updates**: Automatic application updates with digital signature verification and rollback capabilities
- **🌐 Multi-Domain Support**: Environment-specific configurations for different organizational domains
- **📱 Device Actions**: Remote device management (restart, wipe, clean, sync) with proper authorization
- **🎨 Menu Customization**: Flexible menu system that adapts to organizational needs and user permissions
- **🚄 Performance Optimized**: Advanced performance optimizations deliver up to 92% improvement in startup time with memory-efficient operations, parallel processing, and asynchronous logging for enhanced user experience

## System Requirements

### Technical Requirements

- **Operating System**: Windows 10/11 or Windows Server
- **PowerShell**: Version 5.1 or later
- **Privileges**: Administrator privileges (for some device operations)
- **Network**: Connectivity to Microsoft Graph API endpoints

### Azure Configuration Prerequisites

- **Azure AD App Registration** with appropriate permissions
- **Intune subscription** and configuration
- **Required API permissions** (automatically configured during setup)

## Installation and Setup

### Quick Start (Recommended)

The application includes an interactive First Run Wizard that automatically launches when configuration files are missing:

1. **Download** the main.exe executable file from the [GitHub Releases page](https://github.com/zuhairmahd/autopilot/releases) to a local directory
2. **Run the application** for the first time:
   ```powershell
   .\main.exe
   ```
3. **Follow the First Run Wizard** which will guide you through:
   - Azure AD Configuration (App ID, Tenant ID, Domain Name)
   - Authentication Setup (delegated or application authentication)
   - Auto Update Configuration
   - **App Mode Selection** (choose the interface that fits your role)
   - Credential Collection
   - Automatic file creation and encryption

**Required Information**: Have ready your Azure AD App ID, Tenant ID, domain name, and authentication credentials.

### Manual Setup (Advanced Users)

For advanced scenarios where custom configuration is needed:

1. **Clone or download** the script files from the [repository](https://github.com/zuhairmahd/autopilot) to a local directory
2. **Create the secrets folder**: `New-Item -Path ".secrets" -ItemType Directory -Force` ([see .secrets/](./.secrets))
3. **Configure authentication**: Place your `config.json` file in the [`.secrets` folder](./.secrets)
4. **Configure application settings**: Ensure [`settings.json`](./settings.json) is configured for your environment
5. **Set up encryption**: On first run, the script will prompt you to encrypt your configuration file

**Note**: The application automatically creates and manages essential configuration files (`settings.json`, `strings.json`, `menu.json`) with comprehensive defaults if they are missing. This ensures a smooth setup experience and automatic recovery from configuration issues.

### Environment-Specific Configurations

The tool supports domain-specific configurations stored in separate files for better organization and management.

#### Domain Configuration Files

Starting with this version, domain-specific settings are stored in separate JSON files named after the domain (e.g., `contoso.com.json`, `fabrikam.com.json`). This provides several benefits:

- **Better Organization**: Each domain has its own configuration file
- **Easier Management**: Modify domain settings without affecting the main settings.json
- **Simplified Backup**: Back up individual domain configurations separately
- **Reduced Conflicts**: Multiple administrators can work on different domain configurations simultaneously

#### Configuration Structure

Each domain configuration file contains:
```json
{
  "groupsToInclude": ["Domain-Users", "Device-Recipients"],
  "groupsToExclude": ["Contractors", "Temporary-Users"],
  "settings": {
    "deviceNamePrefix": "CONTOSO-",
    "domain": "contoso.com",
    "maxNumberOfDevicesAllowed": 10,
    "MinimumDevicePhysicalMemoryInGB": 8
  },
  "additionalScopes": []
}
```

#### Automatic Migration

The application automatically migrates existing domain configurations from the main `settings.json` file to separate domain files on first load. The migration:

- Creates separate `.json` files for each domain
- Preserves all existing settings and group configurations
- Removes the domains section from the main settings.json after successful migration
- Creates backups before making any changes

#### Backward Compatibility

The tool maintains backward compatibility with existing configurations:
- Can still read domains from `settings.json` if separate files don't exist
- Automatically creates domain files with default settings if needed
- Supports loading from both formats during transition period

For more technical details, refer to [Advanced Settings](./docs/Consolidated-Configuration-System.md) in the technical documentation.

## Menu Options

### Main Menu

When you launch the application, you'll see the main menu with the following options:

1. **Give a device to a user**
   - Assign a device to a specific user
   - Validates user readiness and device availability
   - Checks group memberships and device requirements

2. **Check device status**
   - **Lookup device by Serial Number**: Enter a device serial number to check its status
   - **Lookup device by User**: Find devices associated with a specific user
   - **Check next user readiness state**: Comprehensive assessment of device readiness for next user assignment
     - Validates all device requirements and configuration
     - Identifies multiple issues simultaneously
     - Provides specific remediation actions for each issue
     - Checks Autopilot profile assignment, enrollment state, RAM requirements, user associations, and network connectivity

3. **Autopilot menu**
   - **Quick Import device into Autopilot**: Import current device using default settings
   - **Custom import device into Autopilot**: Import with custom Autopilot profile settings
   - **Import Corporate Device Identifier**: Mark device as corporate-owned for device preparation
   - **Delete Corporate Device Identifier**: Remove device from corporate identifier list
   - **Export Corporate Device Identifier**: Generate data for manual upload to Device Preparation
   - **Get device hash**: Generate hardware hash for manual Autopilot upload
   - **Download and install latest Windows updates**: Update device during provisioning
   - **Check device Autopilot status**: Verify device enrollment status
   - **Delete device from Autopilot**: Remove device from Autopilot

4. **Change application settings**
   - **Change application settings**: Reconfigure the entire application
   - **Change environment settings**: Configure global and domain-specific settings
     - **Change global settings**: Update application-wide configuration options
     - **Change domain settings**: Configure settings for specific domains 
     - **Change authentication settings**: Configure Microsoft Graph API authentication
   - **Change password and authentication information**: Update credentials and passwords
   - **Change Auto Update setting**: Toggle automatic updates on/off
   - **Restore defaults**: Reset application to default configuration

5. **Check for script updates**
   - Manually check for and apply script updates
   - Download latest features and security improvements

6. **Restart the device**
   - Remotely restart the current device (requires appropriate permissions)

7. **Export Menu**
   - **Export Autopilot Devices**: Export list of Autopilot-enrolled devices
   - **Export Imported Autopilot Devices**: Export devices pending Autopilot enrollment
   - **Export Managed Windows Devices**: Export all Intune-managed Windows devices
   - **Export app assignment report**: Comprehensive app assignment reporting with CSV export
   - **Show Group Assignments**: View and export comprehensive group assignment analysis
     - View assignments for Applications, Device Configurations, Compliance Policies
     - View Device Management Scripts, App Protection Policies, Security Intents (Baselines)
     - View Resource Access Profiles (VPN, Wi-Fi, Certificates), Autopilot Profiles
     - View Device Health Scripts, Configuration Policies (Settings Catalog), Group Policy Configurations
     - Export all assignment types to CSV for analysis and reporting

8. **About**
   - View version information, copyright, and licensing details
   - Summary of application capabilities

### Enhanced Navigation Features

The menu system includes several advanced features for improved usability:

- **🎯 Smart Navigation**: Contextual menu options that adapt based on your current operation
- **⌨️ Keyboard Shortcuts**: Quick access using mnemonic keys for common actions
- **📚 Navigation History**: Full back/forward navigation with menu stack memory
- **🔍 Dynamic Filtering**: Menu items automatically shown/hidden based on your role and permissions
- **💡 Contextual Help**: Descriptive menu items with clear explanations of functionality
- **⚡ Quick Actions**: Direct access to frequently used operations from multiple menu paths

### Navigation Tips

- **Type the number** of the menu option you want to select and press Enter
- **Use navigation shortcuts**: 
  - 'b' for Back (when available)
  - 'm' for Main Menu (when available)
  - 'q' or 'e' for Exit
  - '0' for Exit
- **Menu history**: The last two options in submenus allow you to go back to the previous menu or return to the main menu
- **Smart defaults**: The system remembers your preferences and suggests relevant actions

## Advanced Configuration

### Menu Customization

The application supports menu customization through the `menuItemsToInclude` array in `settings.json`. This feature allows administrators to control which menu items are visible to users based on their roles or organizational policies.

**Important**: The menu system uses an INCLUSION model - only items listed in `menuItemsToInclude` will be shown when `appMode` is not set to 'full'. See [`settings.json`](./settings.json).

Example configuration:
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

### Custom App Mode

### What is Custom App Mode?

Custom App Mode allows administrators to define a tailored set of menu options for specific user roles or operational scenarios. When enabled, only the menu items explicitly listed in the `menuItemsToInclude` array in `settings.json` will be shown to the user. This provides granular control over the application's interface, ensuring users only see the features relevant to their responsibilities.

### How to Enable Custom App Mode

1. Open your `settings.json` file.
2. Set the `appMode` property to a custom value (e.g., `"custom"`, `"helpDesk"`, or any string other than `"full"`).
3. Add a `menuItemsToInclude` array listing the menu item names you want visible:

```json
{
  "appMode": "custom",
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status",
    "Export Menu",
    "About"
  ]
}
```

### How It Works
- When `appMode` is set to `"full"`, all menu items are displayed.
- When set to any other value, only the items listed in `menuItemsToInclude` are shown.
- This applies to all users, making it easy to restrict access to advanced or administrative features.
- The menu system will automatically hide any items not included in the array, including submenus and actions.

### Use Cases
- Limit help desk users to basic device assignment and status checks
- Provide a simplified interface for onboarding or registration scenarios
- Restrict access to sensitive operations (e.g., device wipe, advanced settings)

### Example
If you want help desk users to only see device assignment, status checks, and the About page, configure your settings as follows:

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

The application will display only those menu options, hiding all others.

---

## Application Modes

The tool supports several operational modes that control which features and menu items are available to users. App modes can be configured during the first-run wizard or changed later through the settings menu.

### Available App Modes

- **Full Mode** (`appMode: "full"`): Complete feature set with all available functionality (recommended for administrators)
- **Help Desk Mode** (`appMode: "helpDesk"`): Streamlined interface for help desk operations and device troubleshooting
- **Advanced Mode** (`appMode: "advanced"`): Advanced features for experienced users and technical staff
- **Advanced Registration Mode** (`appMode: "advancedRegistration"`): Advanced device registration capabilities with extended options
- **Registration Mode** (`appMode: "registration"`): Device registration and enrollment focused interface
- **Administrator Mode** (`appMode: "admin"`): Administrative functions and system configuration options
- **Custom Mode** (`appMode: "custom"`): Custom configuration for specialized deployments

### Selecting App Mode

App mode selection provides a consistent, user-friendly experience across different contexts with enhanced interface features:

#### During First-Run Setup
When running the application for the first time, the First Run Wizard will prompt you to select an app mode:

1. Run the application: `.\main.ps1`
2. Follow the wizard prompts for Azure AD configuration
3. When prompted, select your preferred app mode from the menu with clear descriptions for each option
4. Complete the remaining setup steps

#### Changing App Mode Later
You can change the app mode at any time through the settings menu:

1. Navigate to **Change application settings** → **Change App Mode setting**
2. Use the interactive menu to select from available app modes with detailed descriptions
3. The system displays your current mode and provides navigation options (Back/Main)
4. Confirm the change when prompted
5. Restart the application when prompted to apply the new mode

**Note**: The app mode selection uses the application's standard menu system for consistent navigation and user experience across all contexts.

### Custom App Mode Configuration

Custom App Mode allows administrators to define a tailored set of menu options for specific user roles or operational scenarios. When using custom mode, you can further restrict menu items through the `menuItemsToInclude` array in `settings.json`.

Example configuration:
```json
{
  "appMode": "custom",
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status",
    "Autopilot menu"
  ]
}
```

### How It Works
- When `appMode` is set to `"full"`, all menu items are displayed
- Other modes display predefined sets of menu items appropriate for that role
- Custom mode can be further restricted using `menuItemsToInclude`
- The menu system automatically shows/hides items based on the selected mode

---

## Configuration Editors and Viewers

The application includes comprehensive tools for managing various configuration settings through interactive editors and read-only viewers. These tools provide user-friendly interfaces for modifying application configuration without requiring manual JSON editing.

### Settings Editors and Viewers

#### Global Settings Editor/Viewer
**Navigation Path**: Main Menu → Change application settings → Change global environment settings → View/Change global environment settings

**Purpose**: Manage application-wide settings that apply across all domains.

**Features**:
- Interactive editing of global configuration parameters
- Real-time validation of setting values
- Automatic backup creation before changes
- Read-only viewer for current global settings
- Type-aware input handling (strings, booleans, arrays, numbers)

**Example Settings**:
- `maxNumberOfDevicesAllowed`: Maximum devices per user
- `timeInSeconds`: Default timeout values
- `autoUpdate`: Automatic update settings
- `showLicenseBanner`: UI display preferences

#### Domain Settings Editor/Viewer
**Navigation Path**: Main Menu → Change application settings → Change global environment settings → View/Change domain specific settings

**Purpose**: Manage domain-specific configuration settings for individual organizational domains.

**Features**:
- Domain selection interface for multi-domain environments
- Interactive editing of domain-specific parameters
- Automatic domain detection and validation
- Backup and restore capabilities
- Read-only viewer for current domain settings

**Example Settings**:
- `operatingSystem`: Target OS for device management
- `deviceNamePrefix`: Naming convention for devices
- `DesiredAutopilotProfiles`: Autopilot profile assignments
- `userPatternsToExclude`: User filtering patterns
- `groupPatternsToExclude`: Group filtering patterns

#### Authentication Settings Editor
**Navigation Path**: Main Menu → Change application settings → Change global environment settings → Change authentication settings

**Purpose**: Configure Microsoft Graph API authentication parameters.

**Features**:
- Authentication type selection (PublicAuthFlow, PrivateAuthFlow, Interactive, Device)
- Microsoft Graph API scope management
- Token caching and renewal configuration
- Credential validation and testing
- Security warnings for advanced configurations

**Key Settings**:
- `authType`: Authentication method
- `delegated`: Use delegated vs application permissions
- `scope`: Microsoft Graph API permissions array
- `renewalLeadTime`: Token renewal timing
- `cacheType`: Token storage method

### Groups Editor and Viewer

#### Groups Settings Viewer
**Navigation Path**: Main Menu → Change application settings → Change global environment settings → View group inclusion/exclusion settings

**Purpose**: Display current group inclusion and exclusion settings for all domains or a specific domain with format detection.

**Enhanced Features**:
- **Format-Aware Display**: Automatically detects and displays legacy vs enhanced format
- **Rich Information**: Shows both group names and IDs when available
- **Format Indicators**: Clear visual indicators for format type
- **Read-only display** of group filtering configuration
- **Support for all domains** or specific domain viewing
- **Clear formatting** with descriptions and summaries
- **Group count statistics** and overview
- **Consistent with other settings viewers**

**Display Format (Enhanced)**:
```
══ Groups Settings Viewer ══
Domain: example.com

Groups to Include:
  Description: Groups in this list will be specifically included in operations
  Current Value: [4 group(s)] [Enhanced Format]
    - Name: security-group-1
      ID:   12345678-1234-1234-1234-123456789abc
    - Name: enrollment-group-prod
      ID:   87654321-4321-4321-4321-abcdef123456
    - Name: license-group-office365
      ID:   11111111-1111-1111-1111-111111111111
    - Name: department-group-it
      ID:   22222222-2222-2222-2222-222222222222

Groups to Exclude:
  Description: Groups in this list will be specifically excluded from operations
  Current Value: (empty - no groups specified)

Summary:
  Domains displayed: 1
  Total groups to include: 4
  Total groups to exclude: 0
```

**Display Format (Legacy)**:
```
══ Groups Settings Viewer ══
Domain: example.com

Groups to Include:
  Description: Groups in this list will be specifically included in operations
  Current Value: [2 group(s)] [Legacy Format]
    - security-group-1
    - enrollment-group-prod

Groups to Exclude:
  Description: Groups in this list will be specifically excluded from operations
  Current Value: [1 group(s)] [Legacy Format]
    - excluded-group-1

Summary:
  Domains displayed: 1
  Total groups to include: 2
  Total groups to exclude: 1
```

#### Groups Settings Editor
**Navigation Path**: Main Menu → Change application settings → Change global environment settings → Edit group inclusion/exclusion settings

**Purpose**: Interactive editor for domain-level group inclusion and exclusion settings with automatic group ID resolution.

**Enhanced Features**:
- **Smart Format Detection**: Automatically detects legacy string arrays vs enhanced hashtable format
- **Real-Time ID Resolution**: Resolves group names to IDs during editing when possible
- **Format Migration**: Automatically upgrades legacy configurations to enhanced format
- **Rich Display**: Shows both group names and IDs with format indicators
- **Interactive group array editing** with user-friendly prompts
- **Automatic domain selection** for multi-domain environments
- **Safe group list modification** with validation
- **Automatic timestamped backup creation**
- **Post-update verification and confirmation**
- **Change detection** (only saves if modifications made)

**Usage Workflow**:
1. **Domain Selection**: Automatically selects domain or prompts user choice
2. **Current Settings Display**: Shows existing groups with format indicators:
   - **[Enhanced Format]**: Groups with both names and IDs
   - **[Legacy Format]**: Groups with names only (will be upgraded)
3. **Interactive Editing**: 
   - Choose to modify groups to include/exclude (y/n)
   - Enter group names one per line
   - **Group IDs automatically resolved** when access token available
   - Visual feedback during ID resolution process
   - Empty line to finish input
   - Option to keep current values by pressing Enter
4. **Change Confirmation**: Reviews and saves only if changes detected
5. **Backup and Verification**: Creates backup and verifies save success

**Example Usage Session (Enhanced Format)**:
```
══ Groups Editor ══
Managing group inclusion/exclusion settings for domain: contoso.com

══ Groups to Include ══
Current groups to include:
  - Name: security-group-1
    ID:   12345678-1234-1234-1234-123456789abc
  - Name: enrollment-group-prod  
    ID:   87654321-4321-4321-4321-abcdef123456

Do you want to modify groups to include? (y/n): y
Enter group names to include (one per line).
Group IDs will be automatically resolved and stored.
Press Enter on empty line to finish.
Leave first line empty to cancel.
Group name: new-security-group

Resolving group IDs...
  ✓ new-security-group -> 99999999-9999-9999-9999-999999999999

Group name: [Enter to finish]

Saving changes...
Group settings updated successfully!
```

**Example Usage Session (Legacy Format Migration)**:
```
══ Groups Editor ══
Managing group inclusion/exclusion settings for domain: contoso.com

══ Groups to Include ══
Current groups to include:
  - old-group-1
  - old-group-2
  (Note: Groups are in old format - will be upgraded)

Do you want to modify groups to include? (y/n): y
Converting existing groups to new format...
Enter group names to include (one per line).
Group IDs will be automatically resolved and stored.
Press Enter on empty line to finish.
Group name: additional-group

Resolving group IDs...
  ✓ old-group-1 -> (ID not found)
  ✓ old-group-2 -> (ID not found)  
  ✓ additional-group -> 88888888-8888-8888-8888-888888888888

Groups will be saved without IDs and resolved later.
Saving changes...
Group settings updated successfully!
```

#### Settings Storage Structure

**Groups Settings Location**:
Groups are stored at the domain level in `settings.json`, separate from the domain's `settings` sub-object.

**Enhanced Format (Recommended)**:
The new enhanced format stores both group names and IDs for improved performance and reliability:

```json
{
  "domains": {
    "example.com": {
      "groupsToInclude": [
        {
          "name": "security-group-1",
          "id": "12345678-1234-1234-1234-123456789abc"
        },
        {
          "name": "enrollment-group-prod", 
          "id": "87654321-4321-4321-4321-abcdef123456"
        }
      ],
      "groupsToExclude": [
        {
          "name": "excluded-group-1",
          "id": "11111111-1111-1111-1111-111111111111"
        }
      ],
      "settings": {
        // Other domain-specific settings
      }
    }
  }
}
```

**Legacy Format (Still Supported)**:
The original string array format continues to work for backward compatibility:

```json
{
  "domains": {
    "example.com": {
      "groupsToInclude": [
        "security-group-1",
        "enrollment-group-prod"
      ],
      "groupsToExclude": [
        "excluded-group-1"
      ],
      "settings": {
        // Other domain-specific settings
      }
    }
  }
}
```

**Automatic Migration**:
- Legacy string arrays are automatically upgraded to the enhanced format when:
  - Groups are edited through the Groups Editor
  - VerifyGroupMembership function processes them (if group IDs can be resolved)
- No manual intervention required - migration is seamless and automatic
- Enhanced format provides better performance by using group IDs for API calls

**Format Benefits**:
- **Enhanced Format**: Faster API calls using group IDs, reduced Graph API queries, better error handling
- **Legacy Format**: Simple configuration, backward compatibility, easy manual editing
- **Automatic Detection**: System automatically detects format and handles appropriately

**Why Domain Level?**:
- Groups control operations across the entire domain
- Separate from domain-specific configuration settings  
- Maintains backward compatibility
- Aligns with existing data structure hierarchy

### Editor Common Features

All configuration editors share these common features:

#### Safety and Backup
- **Automatic Backups**: Timestamped backup files created before any modification
- **Change Detection**: Only saves when actual changes are made
- **Verification**: Post-save verification to ensure changes were applied correctly
- **Error Handling**: Comprehensive error handling with user-friendly messages

#### User Experience
- **Consistent Interface**: All editors follow the same UI patterns and color schemes
- **Clear Navigation**: Intuitive prompts and instructions throughout
- **Visual Feedback**: Color-coded output for status, warnings, and confirmations
- **Contextual Help**: Descriptive text explaining each setting's purpose

#### Technical Implementation
- **PowerShell 5.1 Compatibility**: Works across all Windows PowerShell versions
- **Robust Error Handling**: Graceful handling of file access, JSON parsing, and validation errors
- **Comprehensive Logging**: Detailed logging for troubleshooting and audit trails
- **Input Validation**: Type-aware validation for different setting types

#### Programmatic Usage

All editors support programmatic usage for automation scenarios:

```powershell
# Groups Editor - Silent mode
Show-GroupsEditor -DomainName "contoso.com" -Silent

# Settings Editor - Specific domain
Show-SettingsEditor -SettingsType "Domain" -DomainName "contoso.com" -SettingsFile "custom-settings.json"

# Groups Viewer - Specific domain only
Show-GroupsViewer -DomainName "contoso.com" -Silent

# Settings Viewer - Global settings
Show-SettingsViewer -SettingsType "Global"
```

---



## Security and Password Management

### Encryption and Security

The application uses enterprise-grade security features:

- **AES-256 Encryption**: All sensitive configuration data is encrypted
- **Password Protection**: Configuration files require password to decrypt
- **In-Memory Security**: Decryption happens in memory only - never stored as plaintext on disk
- **Secure Password Handling**: PowerShell SecureString objects protect sensitive input

### Password Retry Behavior

**Important Security Feature**: The application has built-in protection against unauthorized access:

- **Maximum Attempts**: You have **3 attempts** to enter the correct password
- **Automatic Protection**: After 3 failed attempts, the configuration file is **automatically deleted**
- **Security Reason**: This prevents unauthorized users from accessing encrypted credentials

### What to Do If Your Configuration File Is Deleted

If you exceed the maximum password attempts and your configuration file is deleted:

1. **Don't panic** - this is a security feature working as designed
2. **Re-run the application**: `.\main.ps1`
3. **The First Run Wizard will automatically launch** since configuration is missing
4. **Follow the setup wizard** to recreate your configuration
5. **Use the same Azure AD app registration details** as before
6. **Set a new encryption password** that you can remember

**Prevention Tips**:
- Use a memorable but secure password
- Consider using a password manager
- Document your encryption password securely
- Test your password immediately after setup

### Administrative Password Management

Administrators can force users to change their encryption password by setting the `changePWOnNextStart` flag to `true` in [`settings.json`](./settings.json). This is useful for:

- Regular password rotation policies
- Security incident response
- New employee onboarding
- Compliance requirements

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify Azure AD app registration credentials
   - Check API permissions in Azure portal
   - Ensure network connectivity to Microsoft Graph API

2. **Device Not Found**
   - Verify serial number format (no spaces or special characters)
   - Check if device is enrolled in Intune
   - Confirm device is powered on and connected

3. **Permission Denied**
   - Run PowerShell as Administrator for device operations
   - Verify user has appropriate permissions in Azure AD
   - Check Intune role assignments

4. **Password Issues**
   - **Forgotten Password**: Configuration file cannot be recovered - delete it and re-run First Run Wizard
   - **Invalid Password**: Check for typos, remember you have only 3 attempts
   - **Configuration Deleted**: Re-run `.\main.ps1` to launch First Run Wizard

5. **Network Connectivity**
   - Verify access to `graph.microsoft.com`
   - Check firewall and proxy settings
   - Ensure proper DNS resolution

### Getting Help

- **Verbose Logging**: Run with `-Verbose` flag for detailed operation logs
- **Debug Mode**: Use `-LogLevel "Debug"` for comprehensive troubleshooting information
- **Check Logs**: Review log files in the `Logs` directory for error details

### Error Recovery

The script includes comprehensive error handling:
- Automatic fallback to default values
- Graceful recovery from network issues
- Detailed error messages with suggested actions
- Automatic cleanup of temporary files

## Support

### Documentation Resources

- **Technical Documentation**: See the [`docs/` folder](./docs/) for detailed technical information
- **Function Reference**: Individual function documentation in the [`docs/` folder](./docs/)
- **Configuration Guide**: [`docs/Consolidated-Configuration-System.md`](./docs/Consolidated-Configuration-System.md)

### Microsoft Resources

- [Windows Autopilot Documentation](https://learn.microsoft.com/en-us/mem/autopilot/)
- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/)
- [Intune Device Management](https://learn.microsoft.com/en-us/mem/intune/)

### Support Options


For technical support or feature requests:
- Review the documentation in the [`docs/` folder](./docs/)
- Check the troubleshooting section above
- Contact your system administrator
- [File an issue](https://github.com/zuhairmahd/autopilot/issues)

---

*This tool is designed to simplify Windows Autopilot device management while maintaining enterprise security standards. For technical implementation details, API references, and developer documentation, please refer to the files in the `docs/` folder.*