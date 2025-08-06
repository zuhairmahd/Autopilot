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

- **Interactive Menu System**: User-friendly interface with hierarchical navigation
- **Autopilot Device Management**: Import devices into Autopilot with automated hash generation
- **Device Status Monitoring**: Real-time device enrollment and readiness status checking
- **User Verification**: Validate user readiness for device assignment based on group memberships
- **Corporate Device Identifier Management**: Mark devices as corporate-owned in Intune
- **Bulk Operations**: Export device lists and perform batch operations
- **App Assignment Reporting**: Comprehensive reporting and export functionality for Intune app assignments
- **Security Features**: AES-256 encrypted configuration with secure password handling
- **Automatic Setup**: First Run Wizard for easy initial configuration

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

### Environment-Specific Configurations

The tool supports domain-specific configurations. Refer to [Advanced Settings](./docs/Consolidated-Configuration-System.md) in the technical documentation for more information.

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

8. **About**
   - View version information, copyright, and licensing details
   - Summary of application capabilities

### Navigation Tips

- **Type the number** of the menu option you want to select and press Enter
- **Use navigation shortcuts**: 
  - 'b' for Back (when available)
  - 'm' for Main Menu (when available)
  - 'q' or 'e' for Exit
  - '0' for Exit
- **Menu history**: The last two options in submenus allow you to go back to the previous menu or return to the main menu

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