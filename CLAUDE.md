# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell-based Microsoft Intune Autopilot device management tool designed for helpdesk operations. The project provides an interactive menu system for device enrollment verification, user group validation, and device management tasks.

## Core Architecture

### Main Scripts
- **main.ps1**: Interactive menu-driven interface for helpdesk operations
- **Verify.ps1**: Command-line tool for device and user verification 
- **register.ps1**: Device registration script for Autopilot enrollment
- **Build.ps1**: Build/packaging script (currently empty)

### Configuration System
- **initVerify.json**: Domain-specific configuration with group memberships and settings
- **vars.json**: Runtime configuration variables (release version, repository settings)
- **init.json**: Default configuration template
- **.secrets/config.json**: Authentication configuration (encrypted, not in repository)

### Function Modules
The PowerShell functions are organized into modular files in the `functions/` directory:

- **CommonGraphAPIFunctions.ps1**: Microsoft Graph API authentication and utilities
- **DeviceAndUserLookupFunctions.ps1**: User group verification and device lookup
- **AutopilotDeviceFunctions.ps1**: Autopilot device operations and validation
- **CommonDeviceFunctions.ps1**: Device information gathering and utilities
- **DeviceReportingFunctions.ps1**: Device reporting and export functionality
- **CommonMenuFunctions.ps1**: Interactive menu system implementation
- **CommonMiscFunctions.ps1**: General utility functions
- **AutopilotMiscFunctions.ps1**: Autopilot-specific utilities
- **AutopilotScriptUpdateFunctions.ps1**: Script update and version management

## Key Functionality

### Device Management
- Device enrollment status verification
- Autopilot profile validation
- Device readiness assessment for user assignment
- Device command execution (wipe, clean)
- Device export capabilities (managed, unmanaged, autopilot)

### User Operations  
- Azure AD group membership verification
- User lookup by email/username
- Domain-specific user validation rules

### Authentication
- Microsoft Graph API integration using app registration credentials
- Encrypted configuration management
- Scope-based permissions (Device.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, etc.)

## Development Commands

### Running the Application
```powershell
# Interactive menu interface
./main.ps1

# Command-line verification
./Verify.ps1 -serialNumber "DEVICESERIAL"
./Verify.ps1 -userName "user@domain.com" 
./Verify.ps1 -currentDevice

# Device registration  
./register.ps1
```

### Configuration Management
- Configuration files use domain-based settings from `initVerify.json`
- Authentication credentials stored in `.secrets/config.json` (encrypted)
- Default settings can be found in `init.json` and `vars.json`

### Function Import Pattern
All scripts automatically import functions from the `functions/` directory using:
```powershell
$functionsFolder = "$PWD\functions"
$functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1'
foreach ($function in $functions) {
    . $function.FullName
}
```

## Architecture Notes

- **Modular Design**: Functions are separated by responsibility into focused modules
- **Configuration-Driven**: Domain-specific settings and group requirements stored in JSON
- **Error Handling**: Comprehensive validation and user feedback throughout
- **Security**: Encrypted credentials, principle of least privilege API access
- **Interactive UX**: Menu-driven interface with input validation and back navigation
- **Logging**: Verbose logging support throughout all functions

## Dependencies

- PowerShell 5.1+
- Microsoft Graph API access
- Azure AD app registration with appropriate scopes
- Windows environment (device information gathering)