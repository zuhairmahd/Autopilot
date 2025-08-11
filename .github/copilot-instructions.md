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
pwsh -Command "Install-Module -Name TrustedSigning -Force -Scope CurrentUser"

# Verify modules are installed
pwsh -Command "Get-Module -ListAvailable ps2exe, TrustedSigning"
```

**Note**: The `TrustedSigning` module requires an Azure Trusted Signing account for production builds. For testing and development, mock this functionality by using test builds only.

### Bootstrap and Validate the Repository
**CRITICAL TIMING**: ALL builds and tests take significant time. **NEVER CANCEL** long-running operations.

```bash
# Validate syntax and function loading (~1 second)
pwsh -File "./TestScripts/test-syntax.ps1"

# Run comprehensive test suite - NEVER CANCEL: takes 6 minutes. Set timeout to 10+ minutes.
pwsh -File "./TestScripts/run-all-tests.ps1"

# Test basic application functionality
pwsh -File "./main.ps1" -appMode "full" -Verbose
```

### Testing and Validation
**CRITICAL TIMING**: ALL builds and tests take significant time. **NEVER CANCEL** long-running operations.

**UNIFIED TESTING FRAMEWORK**: All testing goes through a single point of entry - `Test-Runner.ps1`. This replaces individual test script execution and provides centralized test management.

```bash
# ALWAYS use the unified test runner - this is the single point of entry for all testing
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax       # Quick validation (~5 seconds)
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory core         # Essential tests (~30-60 seconds)
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit         # Unit tests (~2-4 minutes)
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory integration  # Integration tests (~3-5 minutes)
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory comprehensive # Full tests (~5-8 minutes)
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all          # All tests (~15+ minutes)

# Test discovery and information
pwsh -File "./TestScripts/Test-Runner.ps1" -ListTests              # See all available tests
pwsh -File "./TestScripts/Test-Runner.ps1" -ListCategories         # See test categories

# Pattern-based testing
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory specific -TestPattern "test-menu*"

# Advanced options
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit -ShowVerbose -ContinueOnError
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all -LogLevel Verbose -DryRun

# Legacy run-all-tests.ps1 is DEPRECATED - it will redirect to Test-Runner.ps1
```

**DEPRECATED PATTERNS** - Do not use these:
```bash
# ❌ Don't run individual test scripts anymore
pwsh -File "./TestScripts/test-specific-functionality.ps1"

# ❌ Don't use the old test runner directly (it will redirect, but use the new one)
pwsh -File "./TestScripts/run-all-tests.ps1"
```

**Validation Checklist** - Always validate changes using the unified test runner:
- [ ] **Quick Syntax**: `Test-Runner.ps1 -TestCategory syntax` (< 5 seconds)
- [ ] **Core Functions**: `Test-Runner.ps1 -TestCategory core` (30-60 seconds)  
- [ ] **Unit Tests**: `Test-Runner.ps1 -TestCategory unit` (2-4 minutes)
- [ ] **Integration Tests**: `Test-Runner.ps1 -TestCategory integration` (3-5 minutes)
- [ ] **Full Validation**: `Test-Runner.ps1 -TestCategory all` (15+ minutes - use appropriate timeout)

**End-to-End Validation**: Always run `pwsh -File "./main.ps1" -appMode "full" -Verbose` and verify:
- Functions load without errors (should see "Importing function" messages)
- Configuration files are processed correctly
- Menu system initializes (even if authentication fails due to missing credentials)

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

**Function Count**: 137 total functions organized across 9 categories:
- **menuFunctions** (17): User interface and navigation system
- **setupFunctions** (23): Configuration management and initialization  
- **utilityFunctions** (18): General-purpose helper functions
- **deviceFunctions** (12): Device operations and queries
- **autopilotFunctions** (14): Autopilot device management
- **graphFunctions** (22): Microsoft Graph API integration
- **reportingFunctions** (11): Device assessment and reporting
- **encryptionFunctions** (14): Security and encryption utilities
- **updateFunctions** (6): Update and maintenance operations

### Menu System Architecture

The application uses a sophisticated hierarchical menu system with the following key characteristics:

**Menu Configuration**: Menu definitions are stored in `settings.json` in the `menus` array. The menu system is data-driven and supports:
- **Hierarchical Navigation**: Multi-level menu structure with submenus
- **Role-Based Access**: Menu items filtered by `appMode` and `includeInDisplayModes`
- **Stack-Based History**: Navigation history maintained in `$global:MenuHistory`
- **Context-Aware Actions**: Menu functions adapt based on calling context
- **Mnemonic Support**: Keyboard shortcuts for navigation (b=back, m=main, q/e/0=exit)

**Key Menu Functions**:
- `DisplayNumericMenu`: Primary menu rendering engine
- `ShowMenu`: Menu orchestration and display coordination  
- `Handle-MenuItemSelection`: User input processing and validation
- `Handle-ActionExecution`: Action dispatch and execution
- Navigation handlers for back/main menu/submenu operations

**Menu Structure**: The main menu includes sections for:
1. Device assignment and readiness checking
2. Device status and troubleshooting
3. Autopilot device management
4. Application settings and configuration
5. Update management
6. Device exports and reporting
7. Device actions (wipe, clean, sync)

**Documentation**: Complete menu system documentation available in `/docs/MENU_SYSTEM_DOCUMENTATION.md` including all functions, usage patterns, and navigation flows.

**Important**: If any changes are made to the menu structure or functionality, the `settings.json` file must be updated accordingly, and menu tests should be run to validate changes.

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
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "X.Y.Z" -Overwrite

# Create test build without version update (recommended for development)
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate -Overwrite

# Build with specific output location
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "X.Y.Z" -outputFile "./build/autopilot.exe" -Overwrite

# Secrets-only mode (copies secrets without building)
pwsh -File "./CreateRelease.ps1" -SecretsOnly -Overwrite

# Module creation mode (creates PowerShell module instead of executable)
pwsh -File "./CreateRelease.ps1" -CreateModule -InputFile "./main.ps1" -Overwrite
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
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate -Overwrite
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
- Use test builds only: `CreateRelease.ps1 -NoVersionUpdate -Overwrite`
- The signing process will fail gracefully in testing environments
- Focus on functionality validation rather than signed executables
- Use module creation mode for testing: `CreateRelease.ps1 -CreateModule -Overwrite`

Remember: This tool integrates with Microsoft Graph API for Windows Autopilot device management. When making changes, always validate both the PowerShell functionality AND the logical device management workflows.
