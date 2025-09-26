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

- **🎯 Enhanced Role-Based Interface**: Advanced app mode system supporting both single and multiple mode configurations. Combine permissions from different modes (e.g., Help Desk + Registration) for flexible access control. Seven built-in modes with hierarchical permissions and intelligent conflict resolution. Interactive settings editor with real-time validation and conflict warnings.
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
- **🧪 Unified Testing Framework**: Comprehensive Test-Runner.ps1 system with categorized testing (syntax, core, unit, integration, comprehensive) supporting over 261 PowerShell files with 100% success rates and advanced reporting capabilities
- **🌐 Multi-Domain Support**: Environment-specific configurations for different organizational domains
- **📱 Device Actions**: Remote device management (restart, wipe, clean, sync) with proper authorization
- **🎨 Menu Customization**: Flexible menu system that adapts to organizational needs and user permissions
- **🚄 Performance Optimized**: Advanced performance optimizations deliver up to 92% improvement in startup time with memory-efficient operations, parallel processing, and asynchronous logging for enhanced user experience

## Performance Optimizations

The Windows Autopilot Management Tool includes comprehensive performance optimizations that significantly reduce loading times and improve responsiveness:

### 🚀 PSD1 Configuration Storage Migration
- **89.6% Performance Improvement**: Native PowerShell Data File (.psd1) processing delivers 10ms vs 96ms load times compared to JSON
- **Enhanced Reliability**: PowerShell-native format eliminates JSON parsing errors and encoding issues
- **Automatic Migration**: Seamless upgrade from JSON to PSD1 format with zero user intervention required
- **Backward Compatibility**: Legacy JSON files automatically detected and migrated during first run
- **Zero Dependencies**: No external JSON libraries required - uses native PowerShell capabilities

### 🚀 Multi-Layer Caching System
- **Application Defaults Caching**: 92% improvement in configuration loading (21ms → 1.6ms)
- **Menu Configuration Caching**: 80-85% reduction in menu loading time through intelligent file caching
- **String Resources Caching**: 99% improvement in localization loading for cached operations
- **Graph API Response Caching**: Eliminates redundant API calls for users, groups, and devices
- **Unified Cache Management**: Centralized monitoring and management with `Invoke-CacheManagement`

### ⚡ Optimized Operations
- **File I/O Reduction**: 50% reduction in disk operations through batching and lazy loading
- **Parallel Processing**: Concurrent file validation and background operations
- **Asynchronous Logging**: Non-blocking log operations for better UI responsiveness
- **Conditional Loading**: Load resources only when needed based on app mode and usage patterns

### 📊 Performance Monitoring
Monitor cache performance and optimization effectiveness:
```powershell
# View cache statistics
Invoke-CacheManagement -Action GetStatistics

# Monitor real-time performance
Invoke-CacheManagement -Action Monitor -ShowDetails

# Clear caches if needed
Invoke-CacheManagement -Action Clear
```

### 🎯 Real-World Impact
- **Startup Time**: Reduced from 45+ seconds to under 10 seconds
- **Menu Navigation**: Near-instantaneous response for cached menus
- **API Operations**: Significant reduction in network latency for repeated operations
- **Memory Efficiency**: Optimized memory usage without compromising performance

*For detailed technical information, see [Enhanced Caching Implementation](docs/ENHANCED_CACHING_IMPLEMENTATION.md)*

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
3. **Configure authentication**: Place your `config-sample.psd1` file in the [`.secrets` folder](./.secrets)) and update as needed
4. **Configure application settings**: Ensure [`settings.psd1`](./settings.psd1) is configured for your environment
5. **Set up encryption**: On first run, the script will prompt you to encrypt your configuration file

**Note**: The application automatically creates and manages essential configuration files (`settings.psd1`, `strings.psd1`, `menu.psd1`) with comprehensive defaults if they are missing. This ensures a smooth setup experience and automatic recovery from configuration issues.

### Environment-Specific Configurations


The tool supports domain-specific configurations stored in separate sections within the main PSD1 configuration file for better organization and management.

#### Domain Configuration Structure

Starting with this version, domain-specific settings are stored in the `domains` hashtable within the main `settings.psd1` file. Each domain is represented as a key in the hashtable (e.g., `contoso.com`, `fabrikam.com`). This provides several benefits:

- **Better Organization**: Each domain has its own configuration section
- **Easier Management**: Modify domain settings without affecting other domains
- **Simplified Backup**: Back up the main configuration file or export individual domain sections
- **Reduced Conflicts**: Multiple administrators can work on different domain configurations simultaneously

#### Configuration Structure

Each domain configuration is stored as a hashtable in `settings.psd1` and should follow this structure:
```powershell
@{
  domains = @{
    "arabictutor.com" = @{
      groupsToInclude = @(
        @{
          id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
          name = 'Cloud Managed PC User 3.26.2023_18:43:44'
        }
      )
      groupsToExclude = @(
        @{
          id = 'a0138743-e4fe-45db-a231-737b10a2615d'
          name = 'autoPilot-device-preparation-user'
        }
      )
      autopilotProfilesToInclude = @(
        @{
          id = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
          name = 'windowsCloudConfig Autopilot profile'
        },
        @{
          id = '78a4c8b8-c7fb-4fbb-9db6-7c91eb1db7d1'
          name = 'Hybrid join profile'
        }
      )
      domain = 'arabictutor.com'
      companyName = 'ZM Consulting'
      version = '4.0.0.30055'
      validateScopes = $false
      maxWaitTime = 30
      showLicenseBanner = $false
      deviceContactThresholdInDays = 30
      appMode = 'full'
      timeInSeconds = 60
      maxUserMatchDisplay = 10
      maxGroupMatchDisplay = 10
      release = 'master'
      repoInfo = @{
        repoPath = 'zuhairmahd'
        repoName = 'Autopilot'
        baseURL = 'https://www.github.com'
        baseSourceURL = 'https://raw.githubusercontent.com'
      }
      autoUpdate = $false
      deviceNamePrefix = 'vmware'
      operatingSystem = 'Windows'
      minUsernameLength = 3
      maxUserNameLength = 50
      maxSerialNumberLength = 50
      minSerialNumberLength = 7
      minimumDevicePhysicalMemoryInGB = 8
      maxNumberOfDevicesAllowed = 15
      preferredBrowser = 'Chrome'
      privateSession = $false
      userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com'
      )
      groupPatternsToExclude = @()
      groupTag = 'ENTRA'
      assignedUser = ''
      additionalScopes = @()
    }
  }
}
```

#### Automatic Migration

The application automatically migrates any legacy JSON or older configuration formats to the new PSD1 structure on first load. The migration:

- Converts existing domain configurations to the PSD1 hashtable format
- Preserves all existing settings and group configurations
- Removes legacy configuration files after successful migration
- Creates backups before making any changes

#### Backward Compatibility

The tool maintains backward compatibility with existing configurations:
- Can still read legacy formats if PSD1 files don't exist
- Automatically creates domain sections with default settings if needed
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

---

## Multiple App Modes - Enhanced Role-Based Access Control

The Windows Autopilot Management Tool now supports both **single app mode** (legacy) and **multiple app modes** (new) to provide flexible role-based access control and menu customization. This enhanced system allows users to combine permissions from different modes for greater functionality while maintaining security boundaries.

### Multiple App Modes Overview

The application now supports two configuration approaches:

1. **Single App Mode (Legacy)**: Traditional single mode configuration for backward compatibility
2. **Multiple App Modes (New)**: Combine multiple modes to create custom permission sets

#### Benefits of Multiple App Modes
- **Flexibility**: Combine permissions from different modes (e.g., Help Desk + Registration)
- **Granular Control**: Fine-tune access based on specific organizational needs  
- **Reduced Redundancy**: Automatically resolves conflicts between overlapping modes
- **Backward Compatibility**: Existing single mode configurations continue to work unchanged

### App Mode Hierarchy System

The application uses a hierarchical permission system where higher-level modes include permissions from lower-level modes:

```
Full Mode (*)
├── Admin Mode
│   ├── Advanced Mode
│   │   ├── Help Desk Mode
│   │   └── Registration Mode
│   └── Advanced Registration Mode
└── Custom Mode (user-defined)
```

#### Hierarchy Rules
- **Full Mode**: Grants all permissions, supersedes all other modes
- **Admin Mode**: Includes Advanced + Help Desk + Registration permissions
- **Advanced Mode**: Includes Help Desk + Registration permissions  
- **Advanced Registration**: Specialized registration with extended features
- **Help Desk**: Device troubleshooting and user management
- **Registration**: Device enrollment and basic operations
- **Custom**: User-defined permissions based on configuration

### Available Application Modes

#### 🔑 Full Mode (`full`)
**Complete administrative access with all features enabled**
- All menu items and actions available
- Bypasses all access restrictions
- Recommended for system administrators
- **Hierarchy**: `*` (all permissions)

#### 👨‍💼 Admin Mode (`admin`)  
**System administrator with full configuration and management capabilities**
- Administrative functions and system configuration
- Advanced user management and device operations
- Full export and reporting capabilities
- **Hierarchy**: `admin`, `advanced`, `helpdesk`, `registration`

#### ⚙️ Advanced Mode (`advanced`)
**Advanced user with helpdesk and configuration capabilities**
- Advanced features for experienced users
- Device configuration and policy management
- Advanced troubleshooting tools
- **Hierarchy**: `advanced`, `helpdesk`, `registration`

#### 🎧 Help Desk Mode (`helpdesk`)
**Streamlined interface for help desk operations and device troubleshooting**
- Device assignment and troubleshooting
- User management and device actions
- Basic exports and reporting
- **Hierarchy**: `helpdesk`

#### 📝 Registration Mode (`registration`)
**Device registration specialist with Autopilot enrollment capabilities**
- Autopilot device registration and import
- Device status checking and basic operations
- Basic export functionality
- **Hierarchy**: `helpdesk`, `registration`

#### 🔧 Advanced Registration Mode (`advancedRegistration`)
**Advanced registration specialist with administrative Autopilot capabilities**
- Advanced Autopilot features and custom imports
- Device preparation and advanced device actions
- Extended registration capabilities
- **Hierarchy**: `advancedRegistration`, `registration`

#### 🎨 Custom Mode (`custom`)
**Customizable mode where users define their own access patterns**
- User-defined permissions and capabilities
- Flexible configuration for specialized deployments
- **Hierarchy**: Configurable (empty by default)

### Configuration and Setup

#### Setting App Mode

App mode can be configured in multiple ways:

**1. Command Line Parameter (Single Mode)**
```powershell
.\main.ps1 -appMode "helpdesk"
```

**2. Settings Configuration (Single Mode - Legacy)**
```json
{
  "globalSettings": {
    "appMode": "helpdesk"
  }
}
```

**3. Settings Configuration (Multiple Modes - New)**
```json
{
  "globalSettings": {
    "appMode": "helpdesk",
    "appModes": ["helpdesk", "registration"]
  }
}
```

**4. Domain-Specific Configuration**
```json
{
  "domains": {
    "company.com": {
      "settings": {
        "appModes": ["advanced", "registration"]
      }
    }
  }
}
```

#### Multiple App Modes Configuration

When using multiple app modes, the system combines permissions using **additive strategy** by default:

**Help Desk + Registration Combination:**
```json
{
  "globalSettings": {
    "appModes": ["helpdesk", "registration"]
  }
}
```
*Result*: Access to help desk operations + device registration features

**Admin + Custom Combination:**  
```json
{
  "globalSettings": {
    "appModes": ["admin", "custom"]
  }
}
```
*Result*: Full admin permissions + any custom-defined permissions

### Conflict Resolution

When multiple modes are selected, the system automatically resolves conflicts:

#### Resolution Strategies

1. **Additive Strategy (Default)**
   - Combines permissions from all selected modes
   - Provides union of all allowed features
   - More permissive approach

2. **Precedence Strategy**
   - Uses permissions from highest precedence mode only
   - Follows hierarchy order (Full > Admin > Advanced > etc.)
   - More restrictive approach

#### Conflict Examples

**Redundant Modes:**
```json
{
  "appModes": ["admin", "helpdesk"]
}
```
→ *Warning*: `admin` already includes `helpdesk` permissions

**Full Mode Combination:**
```json
{
  "appModes": ["full", "helpdesk", "registration"]
}
```  
→ *Result*: `full` mode grants all permissions, other modes are redundant

### Interactive Settings Editor

#### Selecting App Mode

App mode selection provides enhanced interface features for both single and multiple mode configurations:

**During First-Run Setup**
When running the application for the first time, the First Run Wizard will prompt you to select app mode(s):

1. Run the application: `.\main.ps1`
2. Follow the wizard prompts for Azure AD configuration
3. Choose between single mode or multiple mode configuration
4. Select your preferred app mode(s) with interactive conflict detection
5. Complete the remaining setup steps

**Changing App Mode Later**
You can change the app mode at any time through the enhanced settings menu:

1. Navigate to **Change application settings** → **Change App Mode setting**
2. Choose between:
   - **Configure multiple app modes** (recommended - combine permissions)
   - **Configure single app mode** (legacy - one mode only)
   - **Keep current configuration**

#### Multiple App Mode Selection Features

The enhanced settings editor provides:

- **Interactive multi-selection interface**
- **Conflict detection and resolution warnings**
- **Hierarchy information and superseding notifications**
- **Real-time effective permissions display**

**Example Conflict Detection:**
```
⚠ CONFLICT INFORMATION:
• Mode 'admin' already includes 'helpdesk' permissions
• Resolution: Using additive strategy - all permissions combined
```

**Effective Permissions Display:**
```
Selected modes: [admin, registration]  
Effective permissions: [admin, advanced, helpdesk, registration]
```

### Custom App Mode Configuration

Organizations can create custom access patterns by:

#### 1. Defining Custom Hierarchy
```json
"appModeHierarchy": {
  "custom": ["registration", "helpdesk"]
}
```

#### 2. Setting Custom Menu Visibility
```json
{
  "name": "Special Function",
  "includeInDisplayModes": ["custom"]
}
```

#### 3. Custom Mode Combinations
```json
{
  "globalSettings": {
    "appModes": ["custom", "registration"]
  }
}
```

### Best Practices

#### Recommended Mode Combinations

**Support Operations:**
```json
{"appModes": ["helpdesk", "registration"]}
```
*Ideal for*: Support staff handling both troubleshooting and device enrollment

**Senior Technical Staff:**
```json  
{"appModes": ["advanced", "registration"]}
```
*Ideal for*: Technical leads with device management and enrollment responsibilities

**Device Specialists:**
```json
{"appModes": ["advancedRegistration"]}  
```
*Ideal for*: Dedicated device enrollment and preparation teams

**System Administrators:**
```json
{"appModes": ["admin"]}
```
*Ideal for*: Full administrative access with all permissions

#### Security Considerations

- **Start with Minimum Access**: Begin with the least privileged mode combination
- **Regular Reviews**: Periodically review mode assignments and effective permissions
- **Conflict Resolution**: Understand how conflicts are resolved in your configuration
- **Testing**: Test mode combinations in development before production deployment

### Migration from Single to Multiple Modes

**Existing Configuration:**
```json
{
  "globalSettings": {
    "appMode": "helpdesk"
  }
}
```

**Migrated Configuration:**
```json  
{
  "globalSettings": {
    "appMode": "helpdesk",
    "appModes": ["helpdesk", "registration"]
  }
}
```

*Note*: The legacy `appMode` property is maintained for backward compatibility.

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

### Autopilot Profiles Editor and Viewer

#### Autopilot Profiles Settings Viewer
**Navigation Path**: Main Menu → Change application settings → Change inclusion/exclusion → View current Autopilot profile settings

**Purpose**: Display current autopilot profile inclusion settings for all domains or a specific domain with profile validation.

**Enhanced Features**:
- **Profile Validation**: Validates profile names against available Autopilot deployment profiles
- **ID-Based Matching**: Shows profile IDs alongside names for precise identification
- **Read-only display** of autopilot profile filtering configuration
- **Support for all domains** or specific domain viewing
- **Clear formatting** with profile descriptions and summaries
- **Profile count statistics** and validation status
- **Consistent with other settings viewers**

**Display Format**:
```
══ Autopilot Profiles Settings Viewer ══
Domain: example.com

Autopilot Profiles to Include:
  Description: Autopilot deployment profiles to include in device assignment operations
  Current Value: [2 profile(s)]
    - Name: Corporate-Enrollment-Profile
      ID:   12345678-1234-1234-1234-123456789abc
      Status: ✓ Valid
    - Name: BYOD-Enrollment-Profile
      ID:   87654321-4321-4321-4321-abcdef123456
      Status: ✓ Valid

Summary:
  Domains displayed: 1
  Total profiles to include: 2
  Valid profiles: 2
  Invalid profiles: 0
```

#### Autopilot Profiles Settings Editor
**Navigation Path**: Main Menu → Change application settings → Change inclusion/exclusion → Change Autopilot profile settings

**Purpose**: Interactive editor for domain-level autopilot profile inclusion settings with automatic profile validation and ID resolution.

**Enhanced Features**:
- **Menu-Driven Interface**: Integrated with the hierarchical menu system for consistent navigation
- **Profile Validation**: Real-time validation against available Autopilot deployment profiles
- **ID-Based Storage**: Automatically resolves and stores profile IDs for reliable matching
- **Interactive profile array editing** with user-friendly prompts
- **Automatic domain selection** for multi-domain environments
- **Safe profile list modification** with validation
- **Automatic timestamped backup creation**
- **Post-update verification and confirmation**
- **Change detection** (only saves if modifications made)

**Usage Workflow**:
1. **Domain Selection**: Automatically selects domain or prompts user choice
2. **Menu Navigation**: Uses the standard menu system for consistent user experience
3. **Current Settings Display**: Shows existing profiles with validation status
4. **Interactive Editing**: 
   - Choose to modify autopilot profiles to include (y/n)
   - Enter profile names one per line
   - **Profile IDs automatically resolved** when access token available
   - Visual feedback during profile validation
   - Empty line to finish input
   - Option to keep current values by pressing Enter
5. **Validation and Confirmation**: Reviews and saves only if changes detected
6. **Backup and Verification**: Creates backup and verifies save success

**Example Usage Session**:
```
══ Autopilot Profiles Editor ══
Managing autopilot profile inclusion settings for domain: contoso.com

Current autopilot profiles to include:
  - Name: Standard-Corporate-Profile
    ID:   11111111-1111-1111-1111-111111111111
    Status: ✓ Valid

Do you want to modify autopilot profiles to include? (y/n): y
Enter autopilot profile names to include (one per line).
Profile IDs will be automatically resolved and stored.
Press Enter on empty line to finish.
Profile name: BYOD-Enrollment-Profile

Resolving and validating profiles...
  ✓ BYOD-Enrollment-Profile -> 22222222-2222-2222-2222-222222222222 (Valid)

Profile name: [Enter to finish]

Saving changes...
Autopilot profile settings updated successfully!
```

**Menu Integration**:
The Autopilot Profiles Editor is now integrated into the hierarchical menu system under "Change inclusion/exclusion":

```
7. Change inclusion/exclusion
   ├── Change group inclusion/exclusion
   └── Change Autopilot profile settings
```

This provides a more organized and intuitive menu structure that groups related functionality together while maintaining the enhanced menu system for consistent user experience.

**Settings Storage Structure**:
```powershell
@{
    domains = @{
        "example.com" = @{
            autopilotProfilesToInclude = @(
                @{
                    name = "Corporate-Enrollment-Profile"
                    id   = "12345678-1234-1234-1234-123456789abc"
                },
                @{
                    name = "BYOD-Enrollment-Profile"
                    id   = "87654321-4321-4321-4321-abcdef123456"
                }
            )
            settings = @{
                # Other domain-specific settings
            }
        }
    }
}
```

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