# Windows Autopilot Management Tool - Menu System Documentation

## Table of Contents
- [Overview](#overview)
- [Menu System Architecture](#menu-system-architecture)
- [Menu Functions Reference](#menu-functions-reference)
- [Menu Configuration](#menu-configuration)
- [Menu Navigation](#menu-navigation)
- [Function Categories](#function-categories)
- [Complete Function Reference](#complete-function-reference)

## Overview

The Windows Autopilot Management Tool uses a sophisticated hierarchical menu system that provides role-based access to various device management functions. The menu system is data-driven, configurable, and supports multiple application modes for different user roles.

### Key Features
- **Hierarchical Navigation**: Multi-level menu structure with submenus
- **Role-Based Access**: Different menu items visible based on user role (`appMode`)
- **Stack-Based Navigation**: Full navigation history with back/forward capability
- **Dynamic Menu Generation**: Menus built from JSON configuration at runtime
- **Context-Aware Actions**: Menu items adapt based on current context
- **Mnemonic Navigation**: Quick access using keyboard shortcuts

## Menu System Architecture

### Core Components

The menu system consists of several key components that work together:

1. **Menu Configuration** (`menu.json` → flat object structure with menu names as keys)
2. **Menu Functions** (`functions/menuFunctions/`)
3. **Action Functions** (spread across all function categories)
4. **Navigation Stack** (runtime menu history)

### Menu Data Structure

Menus are now defined in `menu.json` using a flat object structure where each key is a menu name:

```json
{
  "mainMenu": {
    "Title": "Main Menu",
    "Description": "Please choose from one of the following options",
    "type": "static",
    "items": [
      {
        "name": "Give a device to a user",
        "description": "Start the user and device readiness check",
        "blockType": "action",
        "includeInDisplayModes": ["helpdesk", "registration"]
      },
      {
        "name": "Check device status", 
        "description": "Troubleshoot a device",
        "blockType": "menu",
        "menuName": "checkMenu"
      }
    ]
  }
}
```

**Dynamic Menu Support**: Menus can be marked as `"type": "dynamic"` for runtime generation, or `"type": "static"` for configuration-based items.

**Variable Substitution**: Menu titles and descriptions support variables like `$deviceName`, `$DomainName`, `$serialNumber` that are substituted at runtime.

### Application Modes

The system supports multiple application modes that control menu visibility:

| Mode | Description | Target Users |
|------|-------------|--------------|
| `full` | All menu items visible | Administrators |
| `helpdesk` | Help desk operations | Help desk staff |
| `registration` | Device registration focused | Registration personnel |
| `advanced` | Advanced operations | Technical staff |
| `advancedRegistration` | Extended registration | Advanced registration staff |
| `admin` | Administrative functions | System administrators |
| `custom` | Custom configuration | Specialized deployments |

## Menu Functions Reference

### Core Navigation Functions

#### DisplayNumericMenu.ps1
**Purpose**: Primary menu display function that renders numbered menu options
**Usage**: Called automatically by the menu system
**Parameters**:
- `menuItems`: Array of menu item objects
- `menuTitle`: Title to display at top of menu
- `showNavigation`: Whether to show back/main navigation options

#### ShowMenu.ps1
**Purpose**: Main menu orchestration function
**Usage**: Entry point for displaying any menu
**Parameters**:
- `menuName`: Name of menu to display
- `menuItems`: Menu items array
- `parentMenu`: Parent menu for navigation

#### NewMenu.ps1
**Purpose**: Creates new menu object with proper structure
**Usage**: Used internally to construct menu objects
**Returns**: Properly formatted menu object

### Navigation Handling Functions

#### Handle-MenuItemSelection.ps1
**Purpose**: Processes user menu selection input
**Usage**: Called when user makes a menu choice
**Parameters**:
- `userInput`: User's numeric selection
- `menuItems`: Available menu items
- `currentMenu`: Current menu context

#### Handle-ActionExecution.ps1
**Purpose**: Executes the action associated with a menu item
**Usage**: Called when user selects an action item
**Parameters**:
- `actionName`: Name of action to execute
- `context`: Current execution context

#### Handle-BackNavigation.ps1
**Purpose**: Handles returning to previous menu
**Usage**: Called when user selects back option
**Returns**: Previous menu from navigation stack

#### Handle-MainMenuNavigation.ps1
**Purpose**: Handles returning to main menu
**Usage**: Called when user selects main menu option
**Returns**: Main menu object

#### Handle-SubmenuNavigation.ps1
**Purpose**: Handles entering a submenu
**Usage**: Called when user selects a submenu item
**Parameters**:
- `submenuName`: Name of submenu to enter
- `submenuItems`: Submenu items array

### Menu Stack Management

#### Push-MenuToStack.ps1
**Purpose**: Adds current menu to navigation history
**Usage**: Called before navigating to new menu
**Parameters**:
- `menuObject`: Menu to add to stack

#### Pop-MenuFromStack.ps1
**Purpose**: Retrieves previous menu from navigation history
**Usage**: Called when navigating back
**Returns**: Previous menu object

### Context and State Functions

#### Get-CallingContext.ps1
**Purpose**: Determines the context from which a function was called
**Usage**: Used for debugging and navigation tracking
**Returns**: String indicating calling context

#### Get-BaseCallingContext.ps1
**Purpose**: Gets the base calling context for navigation
**Usage**: Used in navigation decisions
**Returns**: Base context information

#### Get-NavigationPathContext.ps1
**Purpose**: Provides full navigation path information
**Usage**: Used for breadcrumb navigation and debugging
**Returns**: Array of navigation path elements

#### Get-UniqueCallerContext.ps1
**Purpose**: Generates unique identifier for current calling context
**Usage**: Used for context tracking and debugging
**Returns**: Unique context identifier

### Menu Configuration Functions

#### AddMenuItem.ps1
**Purpose**: Dynamically adds items to existing menus
**Usage**: Used to modify menus at runtime
**Parameters**:
- `menuItems`: Existing menu items array
- `newItem`: New item to add

#### Test-MenuItemIncluded.ps1
**Purpose**: Determines if a menu item should be displayed based on current mode
**Usage**: Called during menu generation
**Parameters**:
- `menuItem`: Item to test
- `currentMode`: Current application mode
**Returns**: Boolean indicating if item should be shown

#### Create-MenuBanner.ps1
**Purpose**: Creates formatted banner for menu display
**Usage**: Called during menu rendering
**Parameters**:
- `title`: Menu title
- `subtitle`: Optional subtitle
**Returns**: Formatted banner string

## Menu Configuration

### Main Menu Structure

The application's main menu is defined in `menu.json` and includes these primary sections:

1. **Give a device to a user**
   - User and device readiness validation
   - Device assignment workflow

2. **Check device status**
   - Device lookup by serial number
   - Device lookup by user
   - Group assignment viewing

3. **Autopilot menu**
   - Device import/export operations
   - Corporate device identifier management
   - Autopilot status checking

4. **Change application settings**
   - Environment settings management
   - Authentication configuration
   - Password management

5. **Check for script updates**
   - Manual update checking
   - Auto-update configuration

6. **Restart the device**
   - Remote device restart capability

7. **Export Menu**
   - Various device and configuration exports
   - Report generation

8. **About**
   - Version and license information

9. **Device Actions**
   - Device management operations (wipe, clean, sync)

### Role-Based Menu Filtering

Menus are filtered based on the `includeInDisplayModes` property. When `appMode` is not set to "full", only items with matching display modes are shown.

Example filtering:
```json
{
  "name": "Advanced Operation",
  "includeInDisplayModes": ["advanced", "admin"],
  "type": "action"
}
```

This item would only appear when `appMode` is set to "advanced", "admin", or "full".

## Menu Navigation

### Navigation Patterns

1. **Hierarchical Navigation**: Navigate down into submenus
2. **Stack-Based History**: Use back button to return to previous menu
3. **Direct Main Menu**: Jump directly to main menu from anywhere
4. **Exit Options**: Multiple ways to exit the application

### User Input Handling

- **Numeric Selection**: Type menu number and press Enter
- **Navigation Shortcuts**: 
  - 'b' for Back
  - 'm' for Main Menu  
  - 'q', 'e', or '0' for Exit
- **Input Validation**: Invalid selections prompt for retry

### Navigation Stack

The system maintains a navigation stack (`$global:MenuHistory`) that tracks:
- Previous menu objects
- Menu parameters
- Navigation context
- User path through menu system

## Function Categories

The Windows Autopilot Management Tool organizes its 137 functions across 9 categories:

### 1. Menu Functions (17 functions)
Core menu system functionality for navigation and display.

**Key Functions**:
- `DisplayNumericMenu`: Primary menu rendering
- `ShowMenu`: Menu orchestration
- `Handle-MenuItemSelection`: User input processing
- `Handle-ActionExecution`: Action dispatch

### 2. Setup Functions (23 functions)  
Configuration, initialization, and first-run setup.

**Key Functions**:
- `Start-FirstRunWizard`: Initial application setup
- `MergeSettings`: Configuration hierarchy management
- `Update-Setting`: Dynamic configuration updates
- `Show-SettingsEditor`: Interactive settings management

### 3. Utility Functions (18 functions)
General-purpose utilities used across the application.

**Key Functions**:
- `Write-Log`: Centralized logging system
- `GetUserInput`: User input validation
- `GetEntraUser`: Azure AD user lookup
- `DisplayUserList`: User selection interface

### 4. Device Functions (12 functions)
Device-specific operations and information retrieval.

**Key Functions**:
- `GetDeviceByUser`: Find devices for specific users
- `GetBitLockerRecoveryKey`: BitLocker key retrieval
- `GetDeviceLAPSCredentials`: LAPS password access
- `RestartDevice`: Remote device restart

### 5. Update Functions (6 functions)
Application update and version management.

**Key Functions**:
- `CheckForUpdates`: Manual update checking
- `GetLatestGithubRelease`: GitHub release information
- `Invoke-FileCertVerification`: File integrity checking

### 6. Autopilot Functions (14 functions)
Windows Autopilot device management and enrollment.

**Key Functions**:
- `ImportAutopilotDevice`: Device enrollment
- `GetDeviceHash`: Hardware hash generation
- `AddCorporateDeviceIdentifier`: Device preparation
- `DeleteAutopilotDevice`: Device removal

### 7. Graph Functions (22 functions)
Microsoft Graph API integration and authentication.

**Key Functions**:
- `GetGraphAccessToken`: OAuth token management
- `CallGraphAPI`: API request handling
- `Get-DelegatedToken`: Delegated authentication
- `BuildAuthSplatTable`: Authentication parameter building

### 8. Reporting Functions (11 functions)
Device assessment, reporting, and data export.

**Key Functions**:
- `ExportDeviceList`: Device data export
- `GetNextUserReadinessReport`: Readiness assessment
- `ShowDeviceReport`: Device information display
- `GetAppAssignmentTypes`: Application assignment analysis

### 9. Encryption Functions (14 functions)
Security, encryption, and credential management.

**Key Functions**:
- `Load-EncryptedConfigFile`: Secure configuration loading
- `Get-SecurePassword`: Password input handling
- `Invoke-JsonFileEncryption`: Configuration encryption
- `Initialize-ConfigurationSession`: Security context setup

## Complete Function Reference

### Menu Functions (17 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `AddMenuItem` | Add items to existing menus | Runtime menu modification |
| `Create-MenuBanner` | Create formatted menu headers | Menu display |
| `DisplayNumericMenu` | Primary menu rendering engine | Core menu display |
| `Get-BaseCallingContext` | Get base calling context | Navigation tracking |
| `Get-CallingContext` | Determine function caller | Debugging and navigation |
| `Get-NavigationPathContext` | Full navigation path | Breadcrumb navigation |
| `Get-UniqueCallerContext` | Unique context identifier | Context tracking |
| `Handle-ActionExecution` | Execute menu actions | Action dispatch |
| `Handle-BackNavigation` | Return to previous menu | Navigation control |
| `Handle-MainMenuNavigation` | Return to main menu | Navigation control |
| `Handle-MenuItemSelection` | Process user menu selection | User input handling |
| `Handle-SubmenuNavigation` | Enter submenu | Navigation control |
| `NewMenu` | Create new menu objects | Menu construction |
| `Pop-MenuFromStack` | Get previous menu from stack | Navigation history |
| `Push-MenuToStack` | Add menu to navigation stack | Navigation history |
| `ShowMenu` | Main menu orchestration | Menu display coordination |
| `Test-MenuItemIncluded` | Check if item should display | Role-based filtering |

### Setup Functions (21 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `CreateFullConfiguration` | Create complete configuration | Advanced setup |
| `Get-InitConfiguration` | Load initialization config | Application startup |
| `Get-JsonConfiguration` | Load JSON configuration files | Configuration loading |
| `Get-StringsFromJson` | Load localization strings | UI text management |
| `MergeSettings` | Merge configuration hierarchy | Settings management |
| `Set-SettingsJsonStructure` | Ensure settings file structure | Configuration validation |
| `Show-SettingsEditor` | Interactive settings editor | Configuration management |
| `Test-AuthDefaults` | Validate auth configuration | Security setup |
| `Update-Setting` | Update individual settings | Dynamic configuration |

#### First Run Wizard Functions (12 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `ConvertFrom-JsonToHashtable` | JSON to hashtable conversion | Data processing |
| `ConvertTo-OrderedJson` | Hashtable to ordered JSON | Configuration serialization |
| `Get-AppModeConfigurationFromUser` | Collect app mode preference | User setup |
| `Get-AuthenticationConfigurationFromUser` | Collect auth settings | Security setup |
| `Get-AutoUpdateConfigurationFromUser` | Collect update preferences | Update configuration |
| `Get-BasicConfigurationFromUser` | Collect basic settings | Initial setup |
| `Merge-ConfigurationDefaults` | Apply default values | Configuration initialization |
| `New-ConfigurationFile` | Create new config files | File creation |
| `Start-FirstRunWizard` | Main wizard orchestration | Initial application setup |
| `Test-SettingsJsonExists` | Check for settings file | Setup validation |
| `Test-StringsJsonExists` | Check for strings file | Setup validation |
| `Write-SafeLog` | Safe logging for setup | Setup logging |

### Utility Functions (18 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `cleanupTempFiles` | Remove temporary files | Cleanup operations |
| `ConvertUserDisplayName` | Format user display names | User interface |
| `CreateSecretsFile` | Create encrypted secrets file | Security setup |
| `DisplayGroupList` | Show group selection interface | User interface |
| `DisplayUserList` | Show user selection interface | User interface |
| `FormatDateWithTimeZone` | Format dates with timezone | Date display |
| `GetCachedDeviceEnrollmentState` | Get cached enrollment status | Performance optimization |
| `getEntraGroup` | Look up Azure AD groups | Group management |
| `GetEntraUser` | Look up Azure AD users | User management |
| `GetGroupDirectAssignments` | Get direct group assignments | Assignment analysis |
| `GetGroupIdsByNames` | Convert group names to IDs | Group resolution |
| `GetTimeZoneAbbreviation` | Get timezone abbreviations | Date formatting |
| `GetUserInput` | Validated user input collection | User interface |
| `Globals` | Global variable definitions | Application state |
| `normalizeADUserDisplayName` | Normalize AD user names | User name processing |
| `NormalizeUserName` | Normalize usernames | User name processing |
| `ShowGroupAssignments` | Display group assignments | Information display |
| `validateInput` | Input validation functions | Data validation |
| `Write-Log` | Centralized logging system | Application logging |

### Device Functions (12 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `GetBIOSPassword` | Retrieve device BIOS password | Device management |
| `GetBitLockerRecoveryKey` | Get BitLocker recovery keys | Security management |
| `GetDeviceByUser` | Find devices for specific user | Device lookup |
| `GetDeviceEnrollmentStatus` | Check device enrollment state | Status monitoring |
| `GetDeviceIdFromSerial` | Get device ID from serial number | Device identification |
| `GetDeviceLAPSCredentials` | Get LAPS administrator password | Credential management |
| `GetTotalRegisteredDevicesByUser` | Count user's registered devices | Device inventory |
| `GetVMAutopilotDeviceIdBySerialNumber` | Get VM Autopilot device ID | Virtual machine management |
| `ProcessSerialNumber` | Process and validate serial numbers | Input processing |
| `RestartDevice` | Remotely restart devices | Device management |
| `SendDeviceCommand` | Send commands to devices | Device control |
| `VerifyGroupMembership` | Check user group memberships | Access control |
| `WindowsUpdates` | Manage Windows updates | Update management |

### Update Functions (6 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `CheckForUpdates` | Check for application updates | Update management |
| `getFileVersion` | Get file version information | Version checking |
| `GetLatestGithubRelease` | Get latest GitHub release info | Update checking |
| `GetLatestGitlabRelease` | Get latest GitLab release info | Update checking |
| `GetUpdates` | Download and apply updates | Update management |
| `Invoke-FileCertVerification` | Verify file digital signatures | Security verification |

### Autopilot Functions (14 functions)

#### v1 Functions (10 functions)
| Function | Purpose | Usage |
|----------|---------|-------|
| `CheckDeviceAssignment` | Verify device assignment status | Assignment validation |
| `DeleteAutopilotDevice` | Remove device from Autopilot | Device management |
| `DisplayDeviceAssignmentStatus` | Show assignment status | Status display |
| `GetDeviceHash` | Generate device hardware hash | Device enrollment |
| `HandleCustomImportSettings` | Process custom import options | Advanced import |
| `HandleDeviceEnrollmentState` | Process enrollment state changes | State management |
| `ImportAutopilotDevice` | Import device into Autopilot | Device enrollment |
| `PrepareImportDevice` | Prepare device for import | Import preparation |
| `ProcessAssignmentResult` | Process assignment results | Assignment handling |
| `ProcessDevice` | Process device operations | Device processing |
| `ProcessImportResult` | Process import operation results | Import handling |

#### v2 Functions (3 functions)
| Function | Purpose | Usage |
|----------|---------|-------|
| `AddCorporateDeviceIdentifier` | Add corporate device identifier | Device preparation |
| `DeleteCorporateDeviceIdentifier` | Remove corporate device identifier | Device management |
| `GetCorpDeviceIdentifier` | Get corporate device identifiers | Device identification |

#### Common Functions (1 function)
| Function | Purpose | Usage |
|----------|---------|-------|
| `GetDeviceInfo` | Get comprehensive device information | Device information |

### Graph Functions (22 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `BuildAuthSplatTable` | Build authentication parameters | Auth preparation |
| `CallGraphAPI` | Make Microsoft Graph API calls | API communication |
| `DecodeJwtToken` | Decode JWT tokens | Token processing |
| `Format-TokenOutput` | Format token information | Token display |
| `FormatScopes` | Format OAuth scopes | Scope processing |
| `Get-CachedTokenObject` | Get cached token object | Token caching |
| `Get-ClientCredentialsToken` | Get client credentials token | App authentication |
| `Get-DelegatedToken` | Get delegated user token | User authentication |
| `Get-NormalizedExpiryTime` | Normalize token expiry times | Token management |
| `Get-RefreshToken` | Refresh OAuth tokens | Token refresh |
| `Get-TokenFromCache` | Retrieve token from cache | Token caching |
| `Get-TokenFromResponse` | Extract token from response | Token processing |
| `GetGraphAccessToken` | Main token acquisition function | Authentication |
| `HasScope` | Check if token has required scope | Permission validation |
| `Invoke-TokenRefresh` | Perform token refresh | Token management |
| `LaunchBrowser` | Launch browser for auth | Interactive authentication |
| `ProcessFilterCondition` | Process API filter conditions | Query building |
| `Save-RefreshTokenToConfig` | Save refresh token | Token persistence |
| `Save-TokenToCache` | Save token to cache | Token caching |
| `Start-HttpListener` | Start HTTP listener for auth | OAuth callback handling |
| `Test-CachedTokenValidity` | Validate cached tokens | Token validation |
| `Test-RefreshTokenValidity` | Validate refresh tokens | Token validation |

### Reporting Functions (11 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `AssessDeviceState` | Assess overall device state | Device analysis |
| `ExportDeviceList` | Export device lists to CSV | Data export |
| `ExportDeviceReport` | Export device reports | Report generation |
| `ExportDeviceStorage` | Export device storage information | Storage analysis |
| `GetAppAssignmentTypes` | Get application assignment types | Assignment analysis |
| `GetAutopilotDeviceRelevantProperties` | Get Autopilot device properties | Device information |
| `getDevicePendingActions` | Get pending device actions | Action tracking |
| `GetLastDeviceContactDate` | Get last device contact date | Connectivity tracking |
| `GetManagedDeviceRelevantProperties` | Get managed device properties | Device information |
| `GetNextUserReadinessReport` | Generate user readiness report | Readiness assessment |
| `ShowDeviceReport` | Display device reports | Report display |

### Encryption Functions (14 functions)

| Function | Purpose | Usage |
|----------|---------|-------|
| `Clear-SecureMemory` | Clear sensitive data from memory | Security cleanup |
| `ConvertFrom-SecureString-ToPlainText` | Convert secure strings to plaintext | Data processing |
| `Get-AuthConfigValue` | Get authentication config values | Config retrieval |
| `Get-DecryptedConfigValue` | Get decrypted configuration values | Secure config access |
| `Get-SecurePassword` | Securely collect passwords | Password input |
| `Initialize-ConfigurationSession` | Initialize secure config session | Security setup |
| `Invoke-JsonFileEncryption` | Encrypt JSON configuration files | File encryption |
| `Invoke-PasswordChangeProcess` | Handle password change workflow | Password management |
| `Load-EncryptedConfigFile` | Load encrypted configuration files | Secure config loading |
| `Setup-TemporaryEncryption` | Setup temporary encryption context | Temporary security |
| `Test-FileEncryptionStatus` | Check file encryption status | Encryption validation |

---

*This documentation provides a comprehensive reference for the Windows Autopilot Management Tool's menu system and all 137 functions. For technical implementation details, see the individual function files in the `/functions/` directory.*