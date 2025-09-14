# GitHub Copilot Coding Agent Instructions for Windows Autopilot Management Tool

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
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax

# Run comprehensive test suite - NEVER CANCEL: takes 15+ minutes. Set timeout to 20+ minutes.
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all

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
```

**DEPRECATED PATTERNS** - Do not use these:
```bash
# ❌ Don't run individual test scripts anymore - use unified Test-Runner.ps1 instead
pwsh -File "./TestScripts/test-specific-functionality.ps1"

# ❌ Don't use the old test runner (it was removed in favor of Test-Runner.ps1)
pwsh -File "./TestScripts/run-all-tests.ps1"
```

**CRITICAL TESTING REQUIREMENT**: ALL new tests MUST be added through the unified testing framework (Test-Runner.ps1). When creating new test files:
1. Add them to the TestScripts directory with descriptive names
2. Register them in Test-Runner.ps1 configuration for proper categorization
3. **NEVER run individual test scripts directly** - always use Test-Runner.ps1 categories
4. Ensure tests integrate with the unified reporting and failure handling system
5. **MANDATORY**: All tests created or modified MUST be validated through Test-Runner.ps1 before submission

**TESTING COMPLIANCE**: 
- ✅ **REQUIRED**: Use `Test-Runner.ps1 -TestCategory <category>` for all testing
- ❌ **PROHIBITED**: Direct execution of individual test files (e.g., `pwsh -File test-specific.ps1`)
- ❌ **PROHIBITED**: Creating standalone test scripts that bypass the unified framework
- ✅ **REQUIRED**: All new functionality must include tests registered in Test-Runner.ps1

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

### Configuration System - PSD1 Migration
**MAJOR ARCHITECTURAL CHANGE**: The application has migrated from JSON to PowerShell Data Files (.psd1) for all configuration storage.

**Performance Benefits**:
- **89.6% Performance Improvement**: Load times reduced from 96ms to 10ms
- **Native PowerShell Integration**: No JSON parsing dependencies
- **Enhanced Reliability**: Eliminates JSON encoding and parsing errors
- **Type Safety**: PowerShell native data types with automatic validation

**Key Configuration Files** (all .psd1 format):
- `settings.psd1` - Main configuration with domain-specific settings
- `.secrets/config.psd1` - Encrypted authentication configuration (created by app)
- `menu.psd1` - Menu structure and navigation definitions
- `strings.psd1` - UI text and localization strings
- `init.psd1` - Configuration templates and defaults
- `lastrun.psd1` - Build and version tracking

**Enhanced Group and Autopilot Profile Storage**:
```powershell
# Enhanced format with both names and IDs for improved performance
@{
    groupsToInclude = @(
        @{
            name = 'Security-Group-1'
            id = '12345678-1234-1234-1234-123456789abc'
        }
    )
    autopilotProfilesToInclude = @(
        @{
            name = 'Corporate-Enrollment-Profile'
            id = '87654321-4321-4321-4321-abcdef123456'
        }
    )
}
```

### Menu System Architecture

The application uses a sophisticated hierarchical menu system with the following key characteristics:

**Menu Configuration**: Menu definitions are stored in `menu.psd1`. The menu system is data-driven and supports:
- **Hierarchical Navigation**: Multi-level menu structure with submenus
- **Role-Based Access**: Menu items filtered by `appMode` and `includeInDisplayModes`
- **Stack-Based History**: Navigation history maintained in `$global:MenuHistory`
- **Context-Aware Actions**: Menu functions adapt based on calling context
- **Mnemonic Support**: Keyboard shortcuts for navigation (b=back, m=main, q/e/0=exit)

**Enhanced Menu Structure** (from recent updates):
- **Inclusion/Exclusion Menu**: Hierarchical organization of related settings
  - Groups Editor: Enhanced format with automatic ID resolution
  - Autopilot Profiles Editor: New menu-driven interface with profile validation

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
7. **Inclusion/Exclusion Settings** - Hierarchical menu for:
   - Group inclusion/exclusion (enhanced with ID resolution)
   - Autopilot profile settings (new profile validation system)
8. Device actions (wipe, clean, sync)

**Documentation**: Complete menu system documentation available in `/docs/MENU_SYSTEM_DOCUMENTATION.md` including all functions, usage patterns, and navigation flows.

**Important**: If any changes are made to the menu structure or functionality, the `menu.psd1` file must be updated accordingly, and menu tests should be run to validate changes.

### Main Application Flow
- **Entry Point**: `main.ps1` - handles initialization and menu navigation
- **Menu System**: Hierarchical, stack-based navigation using `MenuFunctions.ps1`
- **State Management**: Tracked in `$global:History` and `$global:MenuHistory`
- **Authentication**: OAuth 2.0 with multiple flows, token caching in encrypted `.secrets/config.psd1`

### Configuration Hierarchy (3-tier system)
1. **Runtime Parameters** (highest priority) - command-line arguments
2. **Domain-Specific Settings** (`settings.psd1` → `domains[domain].settings`)
3. **Global Settings** (`settings.psd1` → `globalSettings`)

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
# Run all tests - NEVER CANCEL: 15+ minutes
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all

# Run specific test categories
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory integration
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory comprehensive

# Quick syntax validation
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax
```

### Build and Release
**PREREQUISITES**: Requires `ps2exe` and `TrustedSigning` PowerShell modules (see Environment Setup above).

```powershell
# Create release build with signing - NEVER CANCEL: 10+ minutes. Set timeout to 15+ minutes.
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

# Target-based builds (new in v4.0)
pwsh -File "./CreateRelease.ps1" -TargetsFile "./targets.psd1" -TargetName "dev"
```

**Build Process Features:**
- **Function Merging**: Inlines all functions from `/functions/` into the main script
- **Code Signing**: Uses Azure Trusted Signing for production builds
- **Secrets Management**: Automatically encrypts and copies configuration files
- **Version Management**: Tracks build history in `lastrun.psd1`
- **Executable Creation**: Uses `ps2exe` to create standalone .exe files
- **Target-Based Builds**: Multiple build configurations through targets.psd1

## Key Development Patterns

### PowerShell 5.1 Compatibility
- **ALWAYS maintain compatibility with PowerShell 5.1** for Windows environments
- Use regular hashtables instead of ordered hashtables for PS 5.1 compatibility
- Test with both PowerShell 5.1 and PowerShell 7+ when possible
- Add version comments if PowerShell 5.1 compatibility cannot be maintained
- If you must use syntax like 'write-host "$variableName: $value"' be sure to surround the first variable with parentheses "$($variable): $value"
- Avoid using unicode characters such as ✓ in your write-host and other write statements as they break PowerShell 5.1. It is fine to use them for test scripts, as we test on PowerShell 7+. Main.ps1 and other functions, however, will always need to be compatible with PowerShell 5.1 for Windows.

### Logging Standards
- Use `Write-Log` function consistently with CMTrace format support
- Include `$functionName = $MyInvocation.MyCommand.Name` at start of functions
- Log at appropriate levels: Error, Warning, Information, Verbose, Debug
- Include detailed verbose logging for troubleshooting
- **Console Output Control**: Rich diagnostic information is available only in verbose mode (`-Verbose`) to prevent console clutter, while all information is always logged to log files
- **CallGraphAPI Improvements**: Extensive error diagnostics including Graph error codes, request IDs, headers, and response bodies are logged for troubleshooting but only displayed in verbose mode

### Error Handling Best Practices
- Wrap API calls in try-catch blocks with comprehensive error handling
- Use `Write-Verbose` for detailed operation logging
- Provide fallback to default values when configuration loading fails
- Validate PSD1 structure before processing

### Configuration File Handling
- **All configuration uses .psd1 format** - JSON support has been completely removed
- Use `Get-ConfigurationData` for loading all configuration files
- Use `Export-PowerShellDataFile` for saving configuration changes
- Always validate PSD1 syntax using `Import-PowerShellDataFile` before processing
- Handle migration scenarios gracefully (legacy JSON files may still exist)

## Microsoft Graph API Integration

### API Optimization and Batch Processing
The application uses Microsoft Graph batch API functionality to optimize performance and reduce network latency:
- **Batch Resource Lists**: Initial resource list calls (mobile apps, device configurations, etc.) are batched into a single API call instead of individual calls
- **Batch Assignment Retrieval**: Assignment data for multiple resources is retrieved using batch requests with configurable batch sizes (default: 20 requests per batch)
- **Intelligent API Version Selection**: Automatically uses appropriate API versions (v1.0 vs beta) based on feature requirements
- **Throttling Management**: Built-in delays and error handling to prevent API throttling
- **Efficient Data Processing**: Minimizes redundant API calls through intelligent caching and batch processing

### Primary Endpoints
- `/deviceManagement/windowsAutopilotDeviceIdentities` - Autopilot device management
- `/users/{id}/registeredDevices` - User device associations  
- `/deviceManagement/managedDevices` - Intune managed device data
- `/users/{id}/memberOf` - User group memberships

### Group Assignment Analysis Endpoints
The application provides comprehensive group assignment analysis across all Intune object types:
- `/deviceAppManagement/mobileApps` - Mobile applications and assignments
- `/deviceManagement/deviceConfigurations` - Device configuration policies and assignments
- `/deviceManagement/deviceCompliancePolicies` - Device compliance policies and assignments
- `/deviceManagement/deviceManagementScripts` - PowerShell device management scripts and assignments
- `/deviceManagement/deviceHealthScripts` - Device health monitoring scripts and assignments (beta)
- `/deviceAppManagement/managedAppPolicies` - App protection policies and assignments
- `/deviceManagement/intents` - Security baselines and endpoint security policies and assignments
- `/deviceManagement/resourceAccessProfiles` - VPN, Wi-Fi, certificate profiles and assignments
- `/deviceManagement/configurationPolicies` - Settings catalog policies and assignments (beta)
- `/deviceManagement/groupPolicyConfigurations` - Group policy ADMX configurations and assignments (beta)
- `/deviceManagement/windowsAutopilotDeploymentProfiles` - Autopilot deployment profiles and assignments (beta)

### Required Scopes (defined in settings.psd1)
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
├── settings.psd1            # Main configuration file (PSD1 format)
├── strings.psd1             # UI text and localization (PSD1 format)
├── menu.psd1                # Menu structure definitions (PSD1 format)
├── init.psd1                # Configuration templates (PSD1 format)
├── targets.psd1             # Build target configurations (PSD1 format)
├── functions/               # All PowerShell function modules
├── TestScripts/             # Comprehensive test suite with Test-Runner.ps1
├── docs/                    # Technical documentation
├── .secrets/                # Encrypted configuration files (created at runtime)
└── .github/workflows/       # CI/CD pipeline definitions
```

### Key Configuration Files
- `settings.psd1` - Main configuration with domain-specific settings (PSD1 format)
- `.secrets/config.psd1` - Encrypted authentication configuration (created by app, PSD1 format)
- `menu.psd1` - Menu structure and navigation definitions (PSD1 format)
- `strings.psd1` - UI text and localization strings (PSD1 format)

## Validation Checklist

Before submitting changes, ALWAYS run these validation steps:

- [ ] **Syntax Check**: `pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax` (< 5 seconds)
- [ ] **Function Loading**: `pwsh -File "./main.ps1" -appMode "full" -Verbose` (verify no function loading errors)
- [ ] **Core Tests**: `pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory core` (~30-60 seconds)
- [ ] **Unit Tests**: `pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit` (~2-4 minutes)
- [ ] **Integration Tests**: `pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory integration` (~3-5 minutes)
- [ ] **Full Test Suite**: `pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all` (NEVER CANCEL: 15+ minutes)
- [ ] **Build Test**: `pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate` (NEVER CANCEL: 10+ minutes)

## Critical Timing Information

**NEVER CANCEL builds or long-running commands. These operations require significant time:**

- **Syntax validation**: < 5 seconds
- **Core functionality tests**: 30-60 seconds
- **Individual unit tests**: 2-4 minutes each
- **Integration tests**: 3-5 minutes
- **Comprehensive tests**: 5-8 minutes
- **Full test suite**: 15+ minutes (87 tests) - **Set timeout to 20+ minutes**
- **Build process**: 10+ minutes - **Set timeout to 15+ minutes**
- **Application startup**: 2-5 seconds for function loading

## Security Considerations

- **Secrets Management**: Configuration files in `.secrets/` are AES-256 encrypted using `EncryptionFunctions.ps1`
- **Code Signing**: Production builds are signed using Azure Trusted Signing
- **API Security**: Use least-privilege scopes for Graph API calls
- **Environment Isolation**: Domain-specific settings allow environment separation
- **Secret Storage**: **NEVER commit secrets** - all sensitive data goes in encrypted `.secrets/config.psd1`
- **Clipboard Integration**: Automatic clipboard integration for sensitive data (LAPS, BitLocker keys)
- **Build Security**: Release builds automatically encrypt secrets and update password change flags

## Recent Major Features (Post-PSD Migration)

### Enhanced Groups and Autopilot Profiles Management
- **Groups Editor**: Enhanced with automatic ID resolution and format migration
- **Autopilot Profiles Editor**: New menu-driven interface with profile validation
- **Hierarchical Menu Structure**: "Change inclusion/exclusion" submenu organizing related settings
- **Enhanced Storage Format**: Both names and IDs stored for improved API performance

### Performance Optimizations
- **PSD1 Migration**: 89.6% performance improvement (96ms → 10ms load times)
- **Multi-layer Caching**: Application defaults, menu configurations, string resources
- **Unified Configuration Loading**: Single `Get-ConfigurationData` function for all files
- **Enhanced Error Handling**: PowerShell-native error reporting and validation

### Testing Framework Improvements
- **Unified Test-Runner.ps1**: Single point of entry for all testing (87 total tests)
- **Comprehensive Categories**: syntax, core, unit, integration, comprehensive, validation, enhanced
- **Advanced Features**: Pattern-based filtering, dry-run mode, verbose output, error continuation
- **100% Success Rates**: All categories consistently passing with comprehensive coverage

## Troubleshooting Common Issues

### Build Failures
```powershell
# Check if required modules are installed
pwsh -Command "Get-Module -ListAvailable ps2exe, TrustedSigning"

# Install missing modules
pwsh -Command "Install-Module -Name ps2exe -Force -Scope CurrentUser"
pwsh -Command "Install-Module -Name TrustedSigning -Force -Scope CurrentUser"

# Test build without signing (for development)
pwsh -File "./CreateRelease.ps1" -InputFile "./main.ps1" -Version "test.0.0.1" -NoVersionUpdate -Overwrite
```

### Function Loading Errors
```powershell
# Check function loading explicitly
pwsh -File "./main.ps1" -appMode "full" -Verbose
# Look for "Importing function" messages - all should succeed

# Test function syntax validation
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory syntax
```

### Test Failures
```powershell
# Run specific failing test category with verbose output
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory unit -ShowVerbose

# Continue on errors to see all failures
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory all -ContinueOnError

# List all available tests
pwsh -File "./TestScripts/Test-Runner.ps1" -ListTests
```

### Configuration Issues
```powershell
# Validate PSD1 configuration syntax
pwsh -File "./TestScripts/Test-Runner.ps1" -TestCategory core

# Test configuration loading
pwsh -c "Import-PowerShellDataFile './settings.psd1'"

# Check for legacy JSON files that need migration
Get-ChildItem -Path . -Name "*.json" | Where-Object { $_ -match "(settings|menu|strings|init|lastrun)\.json" }
```

### PSD1 Migration Issues
```powershell
# Check if migration completed successfully
ls -la *.psd1  # Should see settings.psd1, menu.psd1, strings.psd1, init.psd1

# Check for legacy JSON files
ls -la *.json  # Should only see config-sample.json and lastrun.json (until migrated)

# Validate PSD1 file syntax
pwsh -c "try { Import-PowerShellDataFile './settings.psd1'; Write-Host 'Valid' } catch { Write-Host 'Invalid' }"
```

### Azure Trusted Signing Issues
For development and testing environments where Azure Trusted Signing is not available:
- Use test builds only: `CreateRelease.ps1 -NoVersionUpdate -Overwrite`
- The signing process will fail gracefully in testing environments
- Focus on functionality validation rather than signed executables
- Use module creation mode for testing: `CreateRelease.ps1 -CreateModule -Overwrite`

Remember: This tool integrates with Microsoft Graph API for Windows Autopilot device management. When making changes, always validate both the PowerShell functionality AND the logical device management workflows using the unified Test-Runner.ps1 framework.