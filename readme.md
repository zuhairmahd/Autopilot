# Windows Autopilot Management Tool

A PowerShell-based solution for managing Windows Autopilot device enrollment through Microsoft Intune. This tool provides an interactive, menu-driven interface for IT administrators and help desk personnel to perform Autopilot-related operations.

## Table of Contents

- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [Menu Overview](#menu-overview)
- [Key Settings](#key-settings)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)

## Quick Start

### Installation

1. **Download** the `main.exe` executable from the [GitHub Releases page](https://github.com/zuhairmahd/autopilot/releases)
2. **Run** the application:
   ```powershell
   .\main.exe
   ```
3. **Complete the First Run Wizard** which guides you through:
   - Azure AD Configuration (App ID, Tenant ID, Domain Name)
   - Authentication Setup
   - App Mode Selection (choose your role-based interface)
   - Credential Encryption

**Before you begin**: Have your Azure AD App ID, Tenant ID, and domain name ready.

### Running from Source

For development or advanced usage:
```powershell
# Clone the repository
git clone https://github.com/zuhairmahd/autopilot.git
cd autopilot

# Run with verbose logging
.\main.ps1 -Verbose -LogLevel "Debug"
```

## System Requirements

| Requirement | Details |
|-------------|---------|
| **Operating System** | Windows 10/11 or Windows Server |
| **PowerShell** | Version 5.1 or later |
| **Privileges** | Administrator (for device operations) |
| **Network** | Access to Microsoft Graph API endpoints |
| **Azure** | Azure AD App Registration with Intune subscription |

## Menu Overview

### Main Menu Options

| Option | Description |
|--------|-------------|
| **Give a device to a user** | Assign devices with comprehensive readiness checks (pending actions, enrollment state, user association) |
| **Check device status** | Lookup by serial number or user, assess readiness with detailed reporting |
| **Autopilot menu** | Import devices, manage profiles, get device hash |
| **Change application settings** | Configure global, domain, and authentication settings |
| **Check for script updates** | Download latest features and security updates |
| **Restart the device** | Remote device restart (requires permissions) |
| **Export Menu** | Export device lists, app assignments, group assignments |
| **About** | Version information and license details |

### Navigation

- **Type a number** and press Enter to select a menu option
- **b** - Go back to previous menu
- **m** - Return to main menu
- **q** or **e** or **0** - Exit the application

### App Modes

The tool supports role-based access through app modes:

| Mode | Best For | Access Level |
|------|----------|--------------|
| **full** | System Administrators | All features |
| **admin** | IT Managers | Administrative functions |
| **advanced** | Technical Staff | Advanced features |
| **helpdesk** | Help Desk | Troubleshooting and device assignment |
| **registration** | Device Specialists | Device enrollment |
| **advancedRegistration** | Senior Device Specialists | Extended registration features |
| **custom** | Special Deployments | User-defined access |

### Device Readiness Checks

The tool performs comprehensive device readiness assessments:

- **Enrollment State**: Verifies device is properly enrolled or ready for enrollment
- **Pending Actions**: Checks for incomplete device actions (wipe, reset, sync)
- **User Association**: Detects if device is already registered to intended user
- **Hardware Requirements**: Validates RAM and other specifications
- **Profile Assignment**: Confirms correct Autopilot profile assignment
- **Network Connectivity**: Ensures recent contact with Intune

Devices marked as "ready" have passed all checks and can be assigned to the next user. Devices already registered to the intended user with compliant state are identified and handled appropriately.

## Key Settings

Settings are stored in `settings.psd1`. The most important settings include:

| Setting | Description | Default |
|---------|-------------|---------|
| `appMode` | Role-based interface mode | `full` |
| `autoUpdate` | Enable automatic updates | `true` |
| `maxWaitTime` | API timeout in seconds | `30` |
| `deviceContactThresholdInDays` | Days before device considered stale | `30` |
| `maxMenuItemsPerPage` | Items per menu page | `15` |

**For detailed settings documentation**, see [SETTINGS.md](docs/SETTINGS.md).

### Domain-Specific Configuration

Configure different settings for each organizational domain:

```powershell
domains = @{
    "contoso.com" = @{
        groupsToInclude = @(...)
        settings = @{
            deviceNamePrefix = "CONTOSO-"
            maxNumberOfDevicesAllowed = 10
        }
    }
}
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Authentication fails** | Verify Azure AD credentials and API permissions |
| **Device not found** | Check serial number format, ensure device is enrolled |
| **Permission denied** | Run as Administrator, verify Intune role assignments |
| **Password forgotten** | Delete config file and re-run First Run Wizard |
| **Configuration deleted** | Re-run `.\main.exe` to launch setup wizard |

### Password Security

- You have **3 attempts** to enter your password
- After 3 failed attempts, the configuration file is deleted for security
- Re-run the application to reconfigure if this occurs

### Getting Help

- **Enable verbose logging**: `.\main.ps1 -Verbose -LogLevel "Debug"`
- **Check log files**: Look in the `Logs` directory
- **File an issue**: [GitHub Issues](https://github.com/zuhairmahd/autopilot/issues)

## Documentation

| Document | Description |
|----------|-------------|
| [SETTINGS.md](docs/SETTINGS.md) | Complete settings reference |
| [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | Architecture, testing, and coding standards |
| [TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md) | API and function reference |

### Microsoft Resources

- [Windows Autopilot Documentation](https://learn.microsoft.com/en-us/mem/autopilot/)
- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/)
- [Intune Device Management](https://learn.microsoft.com/en-us/mem/intune/)

---

*For technical implementation details, see the [docs/](docs/) folder.*
