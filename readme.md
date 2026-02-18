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
| **Autopilot menu** | Import devices, manage profiles, get device hash, analyze enrollment events |
| **Change application settings** | Configure global, domain, and authentication settings |
| **Check for script updates** | Download latest features and security updates |
| **Restart the device** | Remote device restart (requires permissions) |
| **Shutdown the device** | Remote device shutdown (requires permissions) |
| **Export Menu** | Export device lists, app assignments, group assignments |
| **Device Reports Menu** | View and export device reports including assigned devices by user |
| **Group Assignments Menu** | Manage device group memberships and assignments |
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

## Device Reports

The **Device Reports Menu** provides detailed insights into your device inventory with interactive viewing and export capabilities.

### Assigned Devices by User Report

Generate comprehensive reports of devices assigned to specific users with detailed device information:

**Features:**
- Query multiple users simultaneously (manual entry or file import)
- View devices with full details including compliance status, enrollment type, and ownership
- Interactive paged display with navigation controls
- Export to CSV for further analysis

**How to Use:**
1. Navigate to **Device Reports Menu** > **Assigned devices by user**
2. Choose input method:
   - **E** - Enter user names/emails manually (one per prompt)
   - **F** - Import from file (one user per line)
   - **Q** - Quit
3. Select output option:
   - **V** - View on screen with paging (1 device per page, ~48 lines)
   - **E** - Export to CSV file
   - **Q** - Cancel

**Report Information Displayed:**
- User association
- Device name and ID
- Manufacturer and model
- Operating system and version
- Account status (Enabled/Disabled)
- Compliance state (Compliant/Non-Compliant)
- Management status
- Trust type and ownership
- Enrollment type
- Registration and last sign-in dates (formatted with timezone)

**Filtering:**
The report automatically applies configured filters:
- Operating system filter (from `settings.operatingSystem`)
- Device name prefix filter (from `settings.deviceNamePrefix`)

**Navigation Controls** (when viewing on screen):
- `n` - Next page
- `p` - Previous page
- `1-N` - Jump to specific page number
- `q` - Quit paging and return to menu

**Export Files:**
CSV files are saved with timestamp: `AssignedDevicesByUserReport-YYYYMMDD_HHMM.csv`

### Autopilot Event Analysis

The **Autopilot Event Analysis** feature provides comprehensive analysis of Windows Autopilot enrollment events, helping you troubleshoot enrollment issues and understand deployment patterns.

**Features:**
- Analyze autopilot enrollment events with detailed success/failure tracking
- Optional location correlation using sign-in logs (enriches events with IP address, location, and device compliance)
- Filter by date range or specific user principal name
- Identify users with multiple failures versus single failures with recovery
- Chronological failure tracking and pattern analysis
- Multi-section paged display with navigation controls
- Export analysis results to CSV for further investigation

**How to Use:**
1. Navigate to **Autopilot menu** > **Autopilot enrollment report**
2. Choose filtering options (date range, specific user, or all events)
3. Enable location analysis if needed (requires additional processing time)
4. View detailed analysis on screen or export to CSV

**Analysis Includes:**
- Event success and failure counts
- Enrollment duration statistics
- Device information (serial number, model, manufacturer)
- User association and patterns
- Timeline of events
- Location data (when location analysis is enabled)
- Device compliance status
- Sign-in metadata correlation

**Location Analysis:**
When enabled with the `-ApplyLocationAnalysis` flag, the analysis correlates autopilot events with user sign-in logs to provide:
- IP address information
- Geographic location
- Device compliance state at time of enrollment
- Sign-in risk and authentication details

### Device Preparation (v2 Autopilot)

For organizations using Windows Autopilot Device Preparation, the tool provides management of **Corporate Device Identifiers**.

**Features:**
- Import corporate device identifiers for device preparation scenarios
- Export identifiers for manual upload to Intune
- Delete identifiers when devices are decommissioned

**How to Use:**
1. Navigate to **Autopilot menu**
2. Select one of the following options:
   - **Import Corporate Device Identifier for Device Preparation** - Import identifiers directly via API
   - **Export Corporate Device Identifier for manual upload** - Generate export file for Intune portal
   - **Delete Corporate Device Identifier** - Remove identifiers when no longer needed

**Note:** These operations require administrator rights in Azure AD.

### BitLocker and LAPS Management

The tool provides quick access to critical security credentials:

**BitLocker Recovery Keys:**
- Retrieve BitLocker recovery keys for encrypted devices
- Available from device status and management menus
- Requires appropriate Graph API permissions

**LAPS Credentials:**
- Retrieve Local Administrator Password Solution (LAPS) credentials
- Access local admin passwords for managed devices
- Requires appropriate administrative permissions

### Other Available Reports

- **Assigned Windows Devices** - All devices with user assignments
- **Unassigned Windows Devices** - Devices without user assignments
- **Pre-provisioned Windows Devices** - Devices staged for Autopilot
- **All Windows Devices** - Complete device inventory

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
