# GitHub Copilot Instructions for Windows Autopilot Management Tool

**ALWAYS reference these instructions first and fallback to web search or bash commands only when you encounter unexpected information that does not match the info here.**

## Project Overview

This repository is a PowerShell-based Windows Autopilot device enrollment and management tool, integrating with Microsoft Graph API and supporting multi-domain configuration. It features a menu-driven UI for helpdesk operations, device assignment, and Intune/Autopilot management.

## Working Effectively

### Environment Setup and Dependencies
**CRITICAL**: The build process requires specific PowerShell modules to be installed.

```bash
# Verify PowerShell availability (requires PowerShell 7+)
pwsh -version

# Install required modules for building (required for CreateRelease.ps1)
pwsh -Command "Install-Module -Name ps2exe -Force -Scope CurrentUser"
pwsh -Command "Install-Module -Name Invoke-TrustedSigning -Force -Scope CurrentUser"

# Verify modules are installed
pwsh -Command "Get-Module -ListAvailable ps2exe, Invoke-TrustedSigning"
```

**Note**: The `Invoke-TrustedSigning` module requires an Azure Trusted Signing account for production builds. For testing and development, mock this functionality by using test builds only.

### Bootstrap and Validate the Repository
**CRITICAL TIMING**: ALL builds and tests take significant time. **NEVER CANCEL** long-running operations.

```bash
# Validate syntax and function loading (~1 second)
pwsh -File "./TestScripts/test-syntax.ps1"

# Run comprehensive test suite - NEVER CANCEL: takes 6 minutes. Set timeout to 10+ minutes.
pwsh -File "./TestScripts/run-all-tests.ps1"

# Build the application (requires modules above) - NEVER CANCEL: takes 10 minutes. Set timeout to 15+ minutes.
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate

# Test basic application functionality
pwsh -File "./main.ps1" -appMode "full" -Verbose
```

### Validation Scenarios
**ALWAYS manually validate any changes by running these complete scenarios:**

1. **Function Loading Test**: Run `pwsh -File "./TestScripts/test-syntax.ps1"` to verify all functions load correctly
2. **Configuration System Test**: Run `pwsh -File "./TestScripts/test-settings-functions.ps1"` 
3. **Menu System Test**: Run `pwsh -File "./TestScripts/test-menu-inclusions.ps1"`
4. **Authentication Test**: Run `pwsh -File "./TestScripts/test-authentication-types.ps1"`
5. **Core Validation**: Run `pwsh -File "./TestScripts/test-core-validation.ps1"` for essential functionality
6. **Comprehensive Testing**: Run `pwsh -File "./TestScripts/test-comprehensive.ps1"` for thorough validation

**End-to-End Validation**: Always run `pwsh -File "./main.ps1" -appMode "full" -Verbose` and verify:
- Functions load without errors (should see "Importing function" messages)
- Configuration files are processed correctly
- Menu system initializes (even if authentication fails due to missing credentials)

**Available Test Categories:**
- **Demo Scripts**: `demo-*.ps1` - Interactive demonstrations of functionality
- **Integration Tests**: `test-*-integration.ps1` - Cross-component validation
- **Unit Tests**: `test-*.ps1` - Individual component testing
- **Final Validation**: `final-validation*.ps1` - Pre-release comprehensive checks

### Common Validation Commands
```bash
# Quick syntax validation (~1 second)
pwsh -File "./TestScripts/test-syntax.ps1"

# Core functionality validation (~30 seconds)
pwsh -File "./TestScripts/test-core-validation.ps1"

# Validate specific functionality (each ~16 seconds)
pwsh -File "./TestScripts/test-configuration-system1.ps1"
pwsh -File "./TestScripts/test-menu-logic-validation.ps1"
pwsh -File "./TestScripts/test-settings-functions.ps1"

# Comprehensive testing (~2-3 minutes)
pwsh -File "./TestScripts/test-comprehensive.ps1"

# Full test suite - NEVER CANCEL: 6 minutes total
pwsh -File "./TestScripts/run-all-tests.ps1"

# Final validation before release
pwsh -File "./TestScripts/final-validation-comprehensive.ps1"
```

## Architecture & Key Patterns

### Function Organization
All PowerShell functions are organized in `/functions/` subdirectories:
```
functions/
├── autopilotFunctions/     # Autopilot device management  
├── deviceFunctions/        # Device operations and queries
├── encryptionFunctions/    # Security and encryption utilities
├── graphFunctions/         # Microsoft Graph API integration
├── menuFunctions/          # User interface and navigation
├── reportingFunctions/     # Device assessment and reporting
├── setupFunctions/         # Configuration and initialization
├── updateFunctions/        # Update and maintenance operations
└── utilityFunctions/       # General-purpose utilities
```

**Function Loading**: All functions are dot-sourced from `/functions/` at startup, loaded recursively. Each module must be independent—avoid inter-module dependencies.

### Main Application Flow
- **Entry Point**: `main.ps1` - handles initialization and menu navigation
- **Menu System**: Hierarchical, stack-based navigation using `MenuFunctions.ps1`
- **State Management**: Tracked in `$global:History` and `$global:MenuHistory`
- **Authentication**: OAuth 2.0 with multiple flows, token caching in encrypted `.secrets/config.json`

### Configuration Hierarchy (3-tier system)
1. **Runtime Parameters** (highest priority) - command-line arguments
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`)
3. **Global Settings** (`settings.json` → `globalSettings`)

Configuration merging handled by `MergeSettings` function in `/functions/setupFunctions/MergeSettings.ps1`

## Development Commands

### Running the Application
```powershell
# Run with full functionality
pwsh -File "./main.ps1" -appMode "full" -Verbose -LogLevel "Debug"

# Valid appMode values: full, helpDesk, advanced, advancedRegistration, registration, admin, custom
pwsh -File "./main.ps1" -appMode "helpDesk" -Verbose

# Force authentication refresh
pwsh -File "./main.ps1" -ForceNewToken -delegated

# Show version information only
pwsh -File "./main.ps1" -showVersion
```

### Testing and Validation
```powershell
# Run all tests - NEVER CANCEL: 6 minutes
pwsh -File "./TestScripts/run-all-tests.ps1"

# Run specific test categories
pwsh -File "./TestScripts/test-settings-functions.ps1"
pwsh -File "./TestScripts/test-menu-inclusions.ps1"
pwsh -File "./TestScripts/test-configuration-system1.ps1"

# Quick syntax validation
pwsh -File "./TestScripts/test-syntax.ps1"
```

### Build and Release
**PREREQUISITES**: Requires `ps2exe` and `Invoke-TrustedSigning` PowerShell modules (see Environment Setup above).

```powershell
# Create release build with signing - NEVER CANCEL: 10 minutes. Set timeout to 15+ minutes.
# Requires Azure Trusted Signing account for production
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "X.Y.Z"

# Create test build without version update (recommended for development)
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate

# Build with specific output location
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "X.Y.Z" -outputFile "./build/autopilot.exe"

# Secrets-only mode (copies secrets without building)
pwsh -File "./CreateRelease.ps1" -SecretsOnly -Overwrite

# Module creation mode (creates PowerShell module instead of executable)
pwsh -File "./CreateRelease.ps1" -CreateModule -InputFile "./main.ps1"
```

**Build Process Features:**
- **Function Merging**: Inlines all functions from `/functions/` into the main script
- **Code Signing**: Uses Azure Trusted Signing for production builds
- **Secrets Management**: Automatically encrypts and copies configuration files
- **Version Management**: Tracks build history in `lastrun.json`
- **Executable Creation**: Uses `ps2exe` to create standalone .exe files

## Key Development Patterns

### PowerShell 5.1 Compatibility
- **ALWAYS maintain compatibility with PowerShell 5.1** for Windows environments
- Use regular hashtables instead of ordered hashtables for PS 5.1 compatibility
- Test with both PowerShell 5.1 and PowerShell 7+ when possible
- Add version comments if PowerShell 5.1 compatibility cannot be maintained

### Logging Standards
- Use `Write-Log` function consistently with CMTrace format support
- Include `$functionName = $MyInvocation.MyCommand.Name` at start of functions
- Log at appropriate levels: Error, Warning, Information, Verbose, Debug
- Include detailed verbose logging for troubleshooting

### Error Handling Best Practices
- Wrap API calls in try-catch blocks with comprehensive error handling
- Use `Write-Verbose` for detailed operation logging
- Provide fallback to default values when configuration loading fails
- Validate JSON structure before processing

## Microsoft Graph API Integration

### Primary Endpoints
- `/deviceManagement/windowsAutopilotDeviceIdentities` - Autopilot device management
- `/users/{id}/registeredDevices` - User device associations  
- `/deviceManagement/managedDevices` - Intune managed device data
- `/users/{id}/memberOf` - User group memberships

### Required Scopes (defined in settings.json)
- `User.Read.All` - Read user profiles and group memberships
- `Device.Read.All` - Read Microsoft Entra ID device objects
- `DeviceManagementManagedDevices.ReadWrite.All` - Manage Intune devices
- `DeviceManagementServiceConfig.ReadWrite.All` - Manage Intune configuration
- `DeviceManagementApps.Read.All` - Read application assignments

### Authentication Types
- **PublicAuthFlow**: Public client MSAL authentication (recommended)
- **Interactive**: Browser-based user authentication
- **Private**: Confidential client with app secrets

## Common File Locations

### Repository Structure
```
/
├── main.ps1                 # Main application entry point
├── CreateRelease.ps1        # Build script for creating releases
├── settings.json           # Main configuration file
├── strings.json            # UI text and localization
├── menus.json             # Menu structure definitions
├── functions/             # All PowerShell function modules
├── TestScripts/           # Comprehensive test suite
├── docs/                  # Technical documentation
├── .secrets/              # Encrypted configuration files (created at runtime)
└── .github/workflows/     # CI/CD pipeline definitions
```

### Key Configuration Files
- `settings.json` - Main configuration with domain-specific settings
- `.secrets/config.json` - Encrypted authentication configuration (created by app)
- `menus.json` - Menu structure and navigation definitions
- `strings.json` - UI text and localization strings

## Validation Checklist

Before submitting changes, ALWAYS run these validation steps:

- [ ] **Syntax Check**: `pwsh -File "./TestScripts/test-syntax.ps1"` (< 1 second)
- [ ] **Function Loading**: `pwsh -File "./main.ps1" -appMode "full" -Verbose` (verify no function loading errors)
- [ ] **Configuration Tests**: `pwsh -File "./TestScripts/test-settings-functions.ps1"` (~17 seconds)
- [ ] **Menu System Tests**: `pwsh -File "./TestScripts/test-menu-inclusions.ps1"` (~17 seconds)
- [ ] **Full Test Suite**: `pwsh -File "./TestScripts/run-all-tests.ps1"` (NEVER CANCEL: 6 minutes)
- [ ] **Build Test**: `pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate` (NEVER CANCEL: 10 minutes)

## Critical Timing Information

**NEVER CANCEL builds or long-running commands. These operations require significant time:**

- **Syntax validation**: < 1 second
- **Individual function tests**: ~16-17 seconds each
- **Full test suite**: 6 minutes (26 tests) - **Set timeout to 10+ minutes**
- **Build process**: 10 minutes - **Set timeout to 15+ minutes**
- **Application startup**: 2-5 seconds for function loading

## Security Considerations

- **Secrets Management**: Configuration files in `.secrets/` are AES-256 encrypted using `EncryptionFunctions.ps1`
- **Code Signing**: Production builds are signed using Azure Trusted Signing
- **API Security**: Use least-privilege scopes for Graph API calls
- **Environment Isolation**: Domain-specific settings allow environment separation
- **Secret Storage**: **NEVER commit secrets** - all sensitive data goes in encrypted `.secrets/config.json`
- **Clipboard Integration**: Automatic clipboard integration for sensitive data (LAPS, BitLocker keys)
- **Build Security**: Release builds automatically encrypt secrets and update password change flags

## Troubleshooting Common Issues

### Build Failures
```powershell
# Check if required modules are installed
pwsh -Command "Get-Module -ListAvailable ps2exe, Invoke-TrustedSigning"

# Install missing modules
pwsh -Command "Install-Module -Name ps2exe -Force -Scope CurrentUser"
pwsh -Command "Install-Module -Name Invoke-TrustedSigning -Force -Scope CurrentUser"

# Test build without signing (for development)
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate
```

### Function Loading Errors
```powershell
# Check function loading explicitly
pwsh -File "./main.ps1" -appMode "full" -Verbose
# Look for "Importing function" messages - all should succeed

# Test function syntax validation
pwsh -File "./TestScripts/test-syntax.ps1"
```

### Test Failures
```powershell
# Run specific failing test with verbose output
pwsh -File "./TestScripts/test-[specific-test].ps1" -Verbose

# Check test helper framework
pwsh -File "./TestScripts/test-helper.ps1"

# Run core validation for essential functionality
pwsh -File "./TestScripts/test-core-validation.ps1"
```

### Configuration Issues
```powershell
# Validate configuration structure
pwsh -File "./TestScripts/test-configuration-system1.ps1"

# Test settings merging
pwsh -File "./TestScripts/test-json-merge.ps1"

# Test settings editor functionality
pwsh -File "./TestScripts/test-settings-editor.ps1"
```

### Azure Trusted Signing Issues
For development and testing environments where Azure Trusted Signing is not available:
- Use test builds only: `CreateRelease.ps1 -NoVersionUpdate`
- The signing process will fail gracefully in testing environments
- Focus on functionality validation rather than signed executables
- Use module creation mode for testing: `CreateRelease.ps1 -CreateModule`

Remember: This tool integrates with Microsoft Graph API for Windows Autopilot device management. When making changes, always validate both the PowerShell functionality AND the logical device management workflows.
