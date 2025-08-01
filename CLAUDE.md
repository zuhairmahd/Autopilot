# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a PowerShell-based Windows Autopilot device enrollment tool that integrates with Microsoft Graph API to manage Intune device registration. The application provides a menu-driven interface for helpdesk operations including device assignment, status checking, and Autopilot management.

## Getting Started

### First Run Setup
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

**Required Information**: Have ready your Azure AD App ID, Tenant ID, domain name, and authentication credentials.

### Running the Application
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

### Environment Setup
```powershell
# Switch to GAO configuration
.\gao.bat

# Switch to ZM configuration  
.\zmc.bat
```

### Testing
```powershell
# Run configuration system tests
.\TestScripts\test-settings-functions.ps1

# Run device selection tests
.\TestScripts\test-device-selection.ps1

# Run all tests in test folder
Get-ChildItem .\TestScripts\test-*.ps1 | ForEach-Object { & $_.FullName }
```

### Building and Deployment
```powershell
# Create signed release executable
.\CreateRelease.ps1 -InputFile "main.ps1" -Version "1.2.3"

# Create PowerShell module
.\CreateRelease.ps1 -InputFile "main.ps1" -CreateModule

# Build without version update
.\CreateRelease.ps1 -InputFile "main.ps1" -NoVersionUpdate
```

## Architecture

### Function Loading System
All PowerShell functions are dynamically loaded from the `/functions/` directory at startup using dot-sourcing. Functions are loaded alphabetically with no dependency resolution, so maintain independence between modules.

### Configuration Hierarchy
The application uses a three-tier configuration system:
1. **Runtime Parameters** (highest priority)
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`)
3. **Global Settings** (`settings.json` → `globalSettings`)

Configuration merging is handled by `MergeSettings` function in `/functions/SettingsHelperFunctions.ps1`.

### Authentication Flow
OAuth 2.0 implementation supports multiple authentication types:
- **Interactive**: Browser-based user authentication
- **PublicAuthFlow**: Public client MSAL authentication
- **Private**: Confidential client with app secrets

Token management includes automatic refresh, caching, and secure storage in encrypted `.secrets/config.json`.

### Menu System Architecture
Hierarchical menu navigation with stack-based history tracking:
- `NewMenu` - Create menu objects
- `AddMenuItem` - Add actions or submenus  
- `ShowMenu` - Display and handle interactions
- `Get-CallingContext` - Manage navigation context

Menu state is maintained in global variables `$global:History` and `$global:MenuHistory`.

## Key Modules

### Core Function Modules (`/functions/`)
*For complete function reference with parameters, examples, and implementation details, see `docs/TECHNICAL_DOCUMENTATION.md` and `docs/CONTRIBUTOR_GUIDE.md`*

- **AutopilotDeviceFunctions.ps1**: Device import, validation, assignment checking, corporate device identifier management
- **DeviceAndUserLookupFunctions.ps1**: User/device queries, BitLocker keys, LAPS credentials
- **DeviceReportingFunctions.ps1**: Export functionality and reporting
- **GraphAPIFunctions.ps1**: Authentication, token management, JWT handling
- **MenuFunctions.ps1**: Interactive UI navigation system
- **SettingsHelperFunctions.ps1**: Configuration management and merging
- **EncryptionFunctions.ps1**: Secure configuration file handling and password management

### Security Functions Overview
- `Load-EncryptedConfigFile`: Loads and decrypts configuration files with retry logic
- `Invoke-JsonFileEncryption`: Core AES-256 encryption/decryption functionality
- `Invoke-PasswordChangeProcess`: Administrative password change workflow
- `Get-SecurePassword`: Secure password input with confirmation
- `Clear-SecureMemory`: Memory cleanup for sensitive data

*For detailed function signatures, parameters, and usage examples, see `docs/TECHNICAL_DOCUMENTATION.md`*

## Configuration Files

### Automatically Created Files
The First Run Wizard automatically creates these files with secure defaults:
- **settings.json**: Main configuration with global and domain-specific settings, including comprehensive Microsoft Graph API scopes and operational parameters
- **strings.json**: Localized messages and return values for all user-facing text
- **.secrets/config.json**: Encrypted authentication credentials with password protection

*For complete configuration system documentation, see `docs/TECHNICAL_DOCUMENTATION.md`*

### Template Files
- **init.json**: Default configuration template used by the First Run Wizard
- **config-sample.json**: Sample configuration file for reference (advanced users)

### First Run Wizard Features
- **Automatic Detection**: Detects missing configuration files and launches setup wizard
- **Interactive Setup**: Guides users through Azure AD app registration and authentication setup
- **Secure Encryption**: Encrypts sensitive configuration data with user-defined password
- **Comprehensive Defaults**: Creates fully functional configurations with all required scopes and settings
- **Authentication Options**: Supports both delegated (interactive) and application (service) authentication flows

## Documentation Structure

### Primary Documentation Files
- **README.md**: End-user focused documentation with installation, menu options, and troubleshooting
- **docs/TECHNICAL_DOCUMENTATION.md**: Comprehensive technical implementation details, API integration, and architecture
- **docs/CONTRIBUTOR_GUIDE.md**: Complete developer guide with project structure, development workflows, and contribution guidelines

### Quick Reference
For detailed information about:
- **Architecture and API Integration**: See `docs/TECHNICAL_DOCUMENTATION.md`  
- **Development and Contributing**: See `docs/CONTRIBUTOR_GUIDE.md`
- **End-user guidance**: See main `README.md`

## Microsoft Graph API Integration

### Required Scopes
The application requires these Microsoft Graph API permissions:
- `User.Read.All` - User profile and group membership access
- `Device.Read.All` - Entra ID device object access
- `DeviceManagementManagedDevices.ReadWrite.All` - Intune device management
- `DeviceManagementServiceConfig.ReadWrite.All` - Autopilot device management
- `DeviceManagementManagedDevices.PrivilegedOperations.All` - LAPS password access
- `BitlockerKey.Read.All` - BitLocker recovery key access

*For complete API integration details, endpoints, and implementation examples, see `docs/TECHNICAL_DOCUMENTATION.md`*

### API Endpoints
Primary endpoints used:
- `/deviceManagement/windowsAutopilotDeviceIdentities` - Autopilot device management
- `/users/{id}/registeredDevices` - User device associations
- `/deviceManagement/managedDevices` - Intune managed device data
- `/directory/deviceLocalCredentials` - LAPS credentials
- `/deviceManagement/importedDeviceIdentities/importDeviceIdentityList` - Corporate device identifier management

*For complete endpoint documentation and usage examples, see `docs/TECHNICAL_DOCUMENTATION.md`*

### Corporate Device Identifier Management
The application provides comprehensive management of Windows Corporate Device Identifiers in Microsoft Intune through key functions: `AddCorporateDeviceIdentifier` and `DeleteCorporateDeviceIdentifier`. This functionality is essential for Autopilot V2 device enrollment.

*For detailed implementation examples and supported identifier types, see `docs/TECHNICAL_DOCUMENTATION.md`*

## Testing Approach

Tests are located in `/TestScripts/` and follow this pattern:
1. Create isolated test environment
2. Load specific function modules
3. Execute test scenarios with validation
4. Cleanup test environment

Current test coverage includes:
- Configuration system functions (`test-settings-functions.ps1`)
- Device selection functions (`test-device-selection.ps1`)
- Corporate device identifier functions (`test-corporate-device-identifier.ps1`)
- Syntax validation (`test-syntax.ps1`)
- Comprehensive integration testing (`test-comprehensive.ps1`)

*For detailed testing guidelines and development workflows, see `docs/CONTRIBUTOR_GUIDE.md`*

## Security Considerations

- Configuration files in `.secrets/` directory are encrypted using `EncryptionFunctions.ps1`
- Code signing is implemented via Azure Trusted Signing service
- Authentication tokens are cached securely with automatic refresh
- Domain-specific settings allow environment isolation
- All Microsoft Graph API calls use least-privilege scopes
- **Administrative password change control**: `auth.changePWOnNextStart` setting enables forced password rotation

*For complete security implementation details, see `docs/TECHNICAL_DOCUMENTATION.md`*

### Password Change Security Feature

The application includes administrative control over configuration password security through the `changePWOnNextStart` setting. When enabled, this feature forces users to change their encryption password on next application start and automatically re-encrypts the configuration file.

*For implementation details and use cases, see `docs/TECHNICAL_DOCUMENTATION.md`*

## Domain Configuration

The application supports multiple domains with specific settings:
- **gao.gov**: Production environment with group-based access control
- **arabictutor.com**: Test environment with different device naming conventions

Each domain can override global settings for device naming, group memberships, Autopilot profiles, and security restrictions. 

*For complete domain configuration examples and implementation details, see `docs/TECHNICAL_DOCUMENTATION.md`*