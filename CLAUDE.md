# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a PowerShell-based Windows Autopilot device enrollment tool that integrates with Microsoft Graph API to manage Intune device registration. The application provides a menu-driven interface for helpdesk operations including device assignment, status checking, and Autopilot management.

## Development Commands

### Running the Application
```powershell
# Standard execution
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
- **AutopilotDeviceFunctions.ps1**: Device import, validation, assignment checking
- **DeviceAndUserLookupFunctions.ps1**: User/device queries, BitLocker keys, LAPS credentials
- **DeviceReportingFunctions.ps1**: Export functionality and reporting
- **GraphAPIFunctions.ps1**: Authentication, token management, JWT handling
- **MenuFunctions.ps1**: Interactive UI navigation system
- **SettingsHelperFunctions.ps1**: Configuration management and merging
- **EncryptionFunctions.ps1**: Secure configuration file handling

### Configuration Files
- **settings.json**: Main configuration with global and domain-specific settings
- **strings.json**: Localized messages and return values
- **.secrets/config.json**: Encrypted authentication credentials (use `config-sample.json` as template)
- **init.json**: Default configuration template

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

## Testing Approach

Tests are located in `/TestScripts/` and follow this pattern:
1. Create isolated test environment
2. Load specific function modules
3. Execute test scenarios with validation
4. Cleanup test environment

Current test coverage focuses on configuration system and device selection functions.

## Security Considerations

- Configuration files in `.secrets/` directory are encrypted using `EncryptionFunctions.ps1`
- Code signing is implemented via Azure Trusted Signing service
- Authentication tokens are cached securely with automatic refresh
- Domain-specific settings allow environment isolation
- All Microsoft Graph API calls use least-privilege scopes

## Domain Configuration

The application supports multiple domains with specific settings:
- **gao.gov**: Production environment with group-based access control
- **arabictutor.com**: Test environment with different device naming conventions

Each domain can override global settings for device naming, group memberships, Autopilot profiles, and security restrictions.