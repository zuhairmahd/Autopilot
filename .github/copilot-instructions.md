# Copilot Code Generation Instructions

## Project Overview

This repository is a PowerShell-based Windows Autopilot device enrollment and management tool, integrating with Microsoft Graph API and supporting multi-domain configuration. It features a menu-driven UI for helpdesk operations, device assignment, and Intune/Autopilot management.

## Architecture & Key Patterns

- **Function Loading:** All PowerShell functions are dot-sourced from `/functions/` at startup, loaded alphabetically. Each module must be independent—avoid inter-module dependencies.
- Main entry point is `main.ps1` which handles initialization and menu navigation
- **Menu System:** Hierarchical, stack-based navigation using `MenuFunctions.ps1`. State is tracked in `$global:History` and `$global:MenuHistory`.
- **Authentication:** OAuth 2.0 with multiple flows (interactive, public, private). Token caching and secure storage in `.secrets/config.json` (encrypted).
- **Microsoft Graph API:** All device/user management is via Graph API. Required scopes and endpoints are documented in `CLAUDE.md`.

## Developer Workflows

- **Run Main App:**  
  `./main.ps1 [-appMode "test"] [-Verbose] [-LogLevel "Debug"]`
- **Switch Config:**  
  `./gao.bat` or `./zmc.bat`
- **Run Tests:**  
  `Get-ChildItem ./TestScripts/test-*.ps1 | ForEach-Object { & $_.FullName }`
- **Build Release:**  
  `./CreateRelease.ps1 -InputFile "main.ps1" -Version "X.Y.Z"`

## Integration Points

- **Microsoft Graph API:**  
  - Scopes: `User.Read.All`, `Device.Read.All`, `DeviceManagementManagedDevices.ReadWrite.All`, etc.
  - Endpoints: `/deviceManagement/windowsAutopilotDeviceIdentities`, `/users/{id}/registeredDevices`, etc.
- **Domain-Specific Behavior:**  
  - Domains like `gao.gov` and `arabictutor.com` have custom settings for device naming, group membership, and security.

## Key Files & Directories

- `/functions/`: All core logic modules (see `CLAUDE.md` for descriptions)
- `/docs/`: Extended documentation and usage guides

### Configuration Hierarchy (3-tier system)
1. **Runtime Parameters** (highest priority) - command-line arguments
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`) 
3. **Global Settings** (`settings.json` → `globalSettings`)

Configuration merging is handled by `MergeSettings` function in `/functions/SettingsHelperFunctions.ps1`

### Authentication Flow
OAuth 2.0 implementation supports multiple authentication types:
- **Interactive**: Browser-based user authentication  
- **PublicAuthFlow**: Public client MSAL authentication (recommended)
- **Private**: Confidential client with app secrets

Token management includes automatic refresh, caching, and secure storage in encrypted `.secrets/config.json`

## Key Development Patterns

### PowerShell 5.1 Compatibility
- Always maintain compatibility with PowerShell 5.1 for Windows
- Use regular hashtables instead of ordered hashtables for PS 5.1 compatibility
- Add version comments if PowerShell 5.1 compatibility cannot be maintained

### Logging Standards
- Use `Write-Log` function consistently with CMTrace format support
- Include `$functionName = $MyInvocation.MyCommand.Name` at start of functions
- Log at appropriate levels: Error, Warning, Information, Verbose, Debug
- Include detailed verbose logging for troubleshooting

### Error Handling
- Wrap API calls in try-catch blocks with comprehensive error handling
- Use `Write-Verbose` for detailed operation logging
- Provide fallback to default values when configuration loading fails
- Validate JSON structure before processing

## Core Function Modules
- **GraphAPIFunctions.ps1**: Authentication, token management, Graph API calls
- **MenuFunctions.ps1**: Interactive UI navigation system with stack-based history
- **SettingsHelperFunctions.ps1**: Configuration management and hierarchical merging
- **AutopilotDeviceFunctions.ps1**: Device import, validation, assignment checking
- **EncryptionFunctions.ps1**: Secure configuration file handling

## Microsoft Graph API Integration
Primary endpoints used:
- `/deviceManagement/windowsAutopilotDeviceIdentities` - Autopilot device management
- `/users/{id}/registeredDevices` - User device associations
- `/deviceManagement/managedDevices` - Intune managed device data

Required scopes defined in `settings.json` with detailed reasoning for each scope.

## Build and Deployment
- Use `CreateRelease.ps1` to create signed executable releases
- Support for Azure Trusted Signing service for code signing
- Domain-specific configurations via `gao.bat` and `zmc.bat` environment switchers

## Security Considerations
- Configuration files in `.secrets/` are encrypted using `EncryptionFunctions.ps1`
- Use least-privilege scopes for Graph API calls
- Domain-specific settings allow environment isolation
- Automatic clipboard integration for sensitive data (LAPS, BitLocker keys)

## Development Commands
```powershell
# Run with development settings
.\main.ps1 -appMode "test" -Verbose -LogLevel "Debug"

# Force authentication refresh
.\main.ps1 -ForceNewToken -Deligated

# Run configuration tests
.\TestScripts\test-settings-functions.ps1
```
