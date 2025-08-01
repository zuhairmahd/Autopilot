# Contributor Guide - Windows Autopilot Management Tool

This guide provides comprehensive information for developers and contributors working on the Windows Autopilot Management Tool.

## Table of Contents

- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Development Environment Setup](#development-environment-setup)  
- [Architecture Understanding](#architecture-understanding)
- [Configuration System](#configuration-system)
- [Development Workflows](#development-workflows)
- [Testing Guidelines](#testing-guidelines)
- [Code Standards](#code-standards)
- [Function Development](#function-development)
- [Menu System Development](#menu-system-development)
- [Security Considerations](#security-considerations)
- [Documentation Guidelines](#documentation-guidelines)
- [Build and Release Process](#build-and-release-process)

## Getting Started

### Prerequisites
- **PowerShell 5.1 or later** (must maintain 5.1 compatibility)
- **Git** for version control
- **Azure AD App Registration** for testing Microsoft Graph API integration
- **Code Editor** (VS Code recommended with PowerShell extension)

### Quick Start for Contributors

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/zuhairmahd/Autopilot.git
   cd Autopilot
   ```

2. **Initial setup and testing**:
   ```powershell
   # Run the application for the first time (launches First Run Wizard)
   .\main.ps1

   # Run in development mode with verbose logging
   .\main.ps1 -appMode "test" -Verbose -LogLevel "Debug"
   ```

3. **Run existing tests**:
   ```powershell
   # Run all tests
   Get-ChildItem .\TestScripts\test-*.ps1 | ForEach-Object { & $_.FullName }

   # Run specific test
   .\TestScripts\test-settings-functions.ps1
   ```

## Project Structure

### Directory Layout
```
/
├── functions/                 # Core PowerShell modules (dot-sourced at startup)
│   ├── AutopilotDeviceFunctions.ps1
│   ├── DeviceAndUserLookupFunctions.ps1
│   ├── GraphAPIFunctions.ps1
│   ├── MenuFunctions.ps1
│   ├── SettingsHelperFunctions.ps1
│   ├── EncryptionFunctions.ps1
│   └── GetAppAssignmentTypes.ps1
├── TestScripts/               # Test files (test-*.ps1)
├── docs/                      # Documentation files
├── .secrets/                  # Encrypted configuration files (created at runtime)
├── main.ps1                   # Main entry point
├── settings.json              # Main configuration file
├── strings.json               # Localized UI strings
├── init.json                  # Configuration template
└── CreateRelease.ps1          # Build script
```

### Key Files

| File | Purpose | When Modified |
|------|---------|---------------|
| `main.ps1` | Application entry point, initialization | Core app changes |
| `settings.json` | Configuration template | New settings, defaults |
| `strings.json` | UI text and messages | UI changes, localization |
| `init.json` | First Run Wizard template | Initial setup changes |
| `functions/*.ps1` | Core functionality modules | Feature development |
| `TestScripts/test-*.ps1` | Test suites | New features, bug fixes |

## Development Environment Setup

### Environment Configuration Scripts
```powershell
# Switch to GAO domain configuration
.\gao.bat

# Switch to ZMC domain configuration
.\zmc.bat
```

### Development Commands
```powershell
# Run with development settings
.\main.ps1 -appMode "test" -Verbose -LogLevel "Debug"

# Force authentication refresh
.\main.ps1 -ForceNewToken -Delegated

# Use custom configuration files
.\main.ps1 -InitFile "custom-settings.json" -configFile ".secrets\custom-config.json"

# Run with specific parameters
.\main.ps1 -GroupTag "Dev-Autopilot" -maxWaitTime 600
```

### Debugging and Logging
- **Verbose Mode**: Use `-Verbose` for detailed operation logging
- **Debug Mode**: Use `-LogLevel "Debug"` for comprehensive troubleshooting
- **Log Files**: Check the `Logs` directory for CMTrace-compatible log files
- **Console Output**: Real-time feedback during development

## Architecture Understanding

### Function Loading System
All functions are dynamically loaded from `/functions/` at startup:
- Files are loaded alphabetically using dot-sourcing
- Each module must be independent (no inter-module dependencies)
- Functions are available globally after loading

### Configuration Hierarchy (3-Tier System)
1. **Runtime Parameters** (highest priority) - command-line arguments
2. **Domain-Specific Settings** (`settings.json` → `domains[domain].settings`)
3. **Global Settings** (`settings.json` → `globalSettings`)

### Menu System Architecture
- Hierarchical navigation with stack-based history
- State in `$global:History` and `$global:MenuHistory`
- Context-aware navigation with `Get-CallingContext`
- Role-based access control via menu inclusion system

## Configuration System

### Configuration Files Overview

#### settings.json Structure
```json
{
  "description": "Configuration file for the Autopilot script",
  "version": "1.3.0.0",
  "auth": {
    "Delegated": true,
    "authType": "PublicAuthFlow",
    "scope": ["Device.ReadWrite.All", "User.Read.All"]
  },
  "globalSettings": {
    "appMode": "full",
    "autoUpdate": true,
    "maxWaitTime": 300,
    "GroupTag": "Autopilot"
  },
  "domains": {
    "contoso.com": {
      "groupsToInclude": ["Contoso-Users"],
      "settings": {
        "deviceNamePrefix": "CONTOSO-",
        "maxNumberOfDevicesAllowed": 2
      }
    }
  },
  "menuItemsToInclude": [
    "Give a device to a user",
    "Check device status"
  ]
}
```

#### Configuration Loading Functions
- **`Get-JsonConfiguration`**: Universal JSON loader with fallback support
- **`MergeSettings`**: Hierarchical configuration merging
- **`Update-GlobalSetting`**: Individual setting updates
- **`Update-DomainSettings`**: Domain-specific configuration management

### Adding New Configuration Options

1. **Add to globalSettings in settings.json**:
   ```json
   "globalSettings": {
     "newSetting": "defaultValue"
   }
   ```

2. **Update configuration functions if needed**:
   ```powershell
   # In your function
   $newSetting = Get-ConfigurationValue -Settings $settings -Key "newSetting" -DefaultValue "fallback"
   ```

3. **Add domain override support**:
   ```json
   "domains": {
     "example.com": {
       "settings": {
         "newSetting": "domainSpecificValue"
       }
     }
   }
   ```

## Development Workflows

### Feature Development Workflow

1. **Create feature branch**:
   ```bash
   git checkout -b feature/new-feature-name
   ```

2. **Develop and test**:
   ```powershell
   # Create or modify functions in /functions/
   # Write tests in /TestScripts/
   # Test thoroughly
   .\TestScripts\test-new-feature.ps1
   ```

3. **Integration testing**:
   ```powershell
   # Test with main application
   .\main.ps1 -appMode "test" -Verbose
   ```

4. **Documentation**:
   - Update function documentation
   - Update user documentation if needed
   - Add examples and usage patterns

### Bug Fix Workflow

1. **Reproduce the issue**:
   ```powershell
   # Use verbose logging to understand the problem
   .\main.ps1 -Verbose -LogLevel "Debug"
   ```

2. **Create test case**:
   ```powershell
   # Create test that reproduces the bug
   # Place in /TestScripts/test-bugfix-description.ps1
   ```

3. **Fix and validate**:
   ```powershell
   # Make minimal changes to fix the issue
   # Verify test passes
   # Run related tests to ensure no regression
   ```

### Testing Workflow

```powershell
# Run syntax validation
.\TestScripts\test-syntax.ps1

# Run configuration tests
.\TestScripts\test-settings-functions.ps1

# Run comprehensive tests
.\TestScripts\test-comprehensive.ps1

# Run all tests
Get-ChildItem .\TestScripts\test-*.ps1 | ForEach-Object { & $_.FullName }
```

## Testing Guidelines

### Test File Naming Convention
- All test files must start with `test-`
- Use descriptive names: `test-device-selection.ps1`, `test-settings-functions.ps1`
- Group related functionality in single test files

### Test Structure Pattern
```powershell
# Test file header
# Test-NewFeature.ps1

# Create isolated test environment
$testDirectory = Join-Path $env:TEMP "autopilot-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -Path $testDirectory -ItemType Directory -Force | Out-Null

try {
    # Load required functions
    . (Join-Path $PSScriptRoot "..\functions\TargetFunction.ps1")
    
    # Test Setup
    Write-Host "Setting up test environment..." -ForegroundColor Yellow
    
    # Test Cases
    Write-Host "Running test cases..." -ForegroundColor Yellow
    
    # Test Case 1: Positive test
    Write-Host "  Testing normal operation..." -ForegroundColor Cyan
    $result = Test-Function -Parameter "value"
    if ($result -eq "expected") {
        Write-Host "    PASS: Normal operation test" -ForegroundColor Green
    } else {
        Write-Host "    FAIL: Normal operation test" -ForegroundColor Red
        throw "Test failed: Expected 'expected', got '$result'"
    }
    
    # Test Case 2: Error handling
    Write-Host "  Testing error handling..." -ForegroundColor Cyan
    try {
        Test-Function -Parameter "invalid"
        Write-Host "    FAIL: Should have thrown error" -ForegroundColor Red
        throw "Test failed: Should have thrown error"
    } catch {
        Write-Host "    PASS: Error handling test" -ForegroundColor Green
    }
    
    Write-Host "All tests passed!" -ForegroundColor Green
    
} finally {
    # Cleanup
    if (Test-Path $testDirectory) {
        Remove-Item -Path $testDirectory -Recurse -Force
    }
}
```

### Test Coverage Requirements
- **Positive tests**: Normal operation with valid inputs
- **Negative tests**: Error handling with invalid inputs
- **Edge cases**: Boundary conditions and unusual scenarios
- **Integration tests**: Function interaction and workflow testing

## Code Standards

### PowerShell 5.1 Compatibility Requirements
- **Hashtables**: Use regular hashtables, not ordered hashtables
- **Arrays**: Use PowerShell array syntax `@()` instead of generic lists
- **String formatting**: Use `-f` operator instead of string interpolation
- **Error handling**: Use `try/catch` blocks consistently

### Coding Style Guidelines

#### Function Structure
```powershell
function New-ExampleFunction {
    <#
    .SYNOPSIS
    Brief description of what the function does.
    
    .DESCRIPTION
    Detailed description of the function's purpose and behavior.
    
    .PARAMETER ParameterName
    Description of the parameter.
    
    .EXAMPLE
    New-ExampleFunction -ParameterName "value"
    Description of what this example does.
    
    .NOTES
    Additional notes about the function.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$ParameterName,
        
        [Parameter(Mandatory = $false)]
        [Switch]$OptionalSwitch
    )
    
    # Function name for logging
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function execution"
    
    try {
        # Function logic here
        Write-Verbose "[$functionName] Processing parameter: $ParameterName"
        
        # Return result
        return $result
        
    } catch {
        Write-Error "[$functionName] Error: $($_.Exception.Message)"
        Write-Log -Message "[$functionName] Error: $($_.Exception.Message)" -Level "Error"
        throw
    } finally {
        Write-Verbose "[$functionName] Function execution completed"
    }
}
```

#### Logging Standards
```powershell
# At function start
$functionName = $MyInvocation.MyCommand.Name
Write-Verbose "[$functionName] Starting function execution"

# For informational messages
Write-Log -Message "[$functionName] Processing device: $deviceName" -Level "Information"

# For warnings
Write-Log -Message "[$functionName] Device not found, using fallback" -Level "Warning"

# For errors
Write-Log -Message "[$functionName] Failed to connect to API: $($_.Exception.Message)" -Level "Error"

# For debug information
Write-Verbose "[$functionName] Variable value: $variableName = '$variableValue'"
```

#### Error Handling Patterns
```powershell
# API calls
try {
    $response = Invoke-GraphAPIRequest -Uri $uri -AccessToken $token
    Write-Verbose "[$functionName] API request successful"
} catch {
    Write-Error "[$functionName] API request failed: $($_.Exception.Message)"
    Write-Log -Message "[$functionName] API request failed: $($_.Exception.Message)" -Level "Error"
    return $null
}

# Configuration loading with fallback
try {
    $config = Get-JsonConfiguration -FilePath $configFile
} catch {
    Write-Warning "[$functionName] Failed to load configuration, using defaults"
    $config = Get-DefaultConfiguration
}
```

## Function Development

### Function Categories and Locations

| Category | File | Purpose |
|----------|------|---------|
| **Device Management** | `AutopilotDeviceFunctions.ps1` | Autopilot device operations |
| **User/Device Lookup** | `DeviceAndUserLookupFunctions.ps1` | Search and lookup operations |
| **API Integration** | `GraphAPIFunctions.ps1` | Microsoft Graph API calls |
| **UI Navigation** | `MenuFunctions.ps1` | Menu system and navigation |
| **Configuration** | `SettingsHelperFunctions.ps1` | Settings management |
| **Security** | `EncryptionFunctions.ps1` | Encryption and security |
| **Reporting** | `GetAppAssignmentTypes.ps1` | Data export and reporting |

### Adding New Functions

1. **Determine the appropriate module** based on function purpose
2. **Follow the function structure pattern** with proper documentation
3. **Include comprehensive error handling** and logging
4. **Add parameter validation** using PowerShell attributes
5. **Write corresponding tests** in `/TestScripts/`

### Function Independence Requirements
- **No inter-module dependencies**: Functions cannot depend on other modules
- **Self-contained**: Include all necessary helper functions within the module
- **Global variable usage**: Minimize reliance on global variables
- **Return consistent data types**: Use objects or hashtables for complex returns

### Microsoft Graph API Integration

#### API Function Pattern
```powershell
function Get-IntuneDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$AccessToken,
        
        [Parameter(Mandatory = $false)]
        [String]$Filter
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    
    if ($Filter) {
        $uri += "?`$filter=$Filter"
    }
    
    try {
        Write-Verbose "[$functionName] Making API request to: $uri"
        $response = Invoke-GraphAPIRequest -Uri $uri -AccessToken $AccessToken -Method "GET"
        
        Write-Verbose "[$functionName] Retrieved $($response.value.Count) devices"
        return $response.value
        
    } catch {
        Write-Error "[$functionName] Failed to retrieve devices: $($_.Exception.Message)"
        Write-Log -Message "[$functionName] API Error: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}
```

## Menu System Development

### Menu Creation Pattern
```powershell
# Create main menu
$mainMenu = NewMenu -Title "Main Menu" -Description "Select an option from the menu below"

# Add action items
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Perform Action" -Action {
    Write-Host "Executing action..." -ForegroundColor Green
    # Action logic here
    
    # Get context for conditional behavior
    $context = Get-CallingContext -IncludeNavigationPath
    switch -Regex ($context) {
        '.*ViaCheckMenu' {
            # Behavior when accessed via Check Device Status
        }
        '.*ViaAutopilotMenu' {
            # Behavior when accessed via Autopilot Menu
        }
        default {
            # Default behavior
        }
    }
}

# Add submenu items
$subMenu = NewMenu -Title "Sub Menu" -Description "Submenu options"
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Sub Menu" -Submenu $subMenu

# Display the menu
ShowMenu -Menu $mainMenu
```

### Menu Inclusion System
```powershell
# Test if menu item should be included
if (Test-MenuItemIncluded -MenuItemName "Advanced Options") {
    $menu = AddMenuItem -Menu $menu -Name "Advanced Options" -Action { ... }
}
```

### Context-Aware Menu Behavior
```powershell
# Get enhanced context information
$context = Get-CallingContext -IncludeNavigationPath

# Conditional behavior based on navigation path
switch -Regex ($context) {
    'Action-ViaCheckMenu' {
        Write-Host "Accessed via Check Device Status menu" -ForegroundColor Green
        # Emphasize device status functionality
    }
    'Action-ViaAutopilotMenu' {
        Write-Host "Accessed via Autopilot menu" -ForegroundColor Blue
        # Emphasize Autopilot-specific functionality
    }
    'Direct' {
        Write-Host "Direct function call" -ForegroundColor Yellow
        # Standard behavior
    }
}
```

## Security Considerations

### Secure Coding Practices

#### Password and Credential Handling
```powershell
# Use SecureString for passwords
$securePassword = Get-SecurePassword -Message "Enter password" -RequireConfirmation

# Clear sensitive variables after use
Clear-SecureMemory -Variables @("password", "token", "credentials")

# Use try/finally for cleanup
try {
    $sensitiveData = Get-SensitiveData
    # Process data
} finally {
    Clear-SecureMemory -Variables @("sensitiveData")
}
```

#### Configuration File Security
```powershell
# Always encrypt sensitive configuration
$configResult = Load-EncryptedConfigFile -ConfigFile $configPath -MaxRetries 3

if (-not $configResult.Success) {
    Write-Error "Failed to load configuration: $($configResult.ErrorMessage)"
    return
}

$config = $configResult.Content | ConvertFrom-Json
```

#### API Security Best Practices
- **Use least-privilege scopes** for Microsoft Graph API
- **Validate all input parameters** before API calls
- **Don't log sensitive information** (tokens, passwords, personal data)
- **Implement token refresh logic** to maintain security
- **Use HTTPS only** for all API communications

### Security Testing
```powershell
# Test password retry logic
.\TestScripts\test-password-change.ps1

# Test encryption functionality
.\TestScripts\test-encryption.ps1

# Test API token handling
.\TestScripts\test-api-security.ps1
```

## Documentation Guidelines

### Code Documentation
- **Function headers**: Use PowerShell comment-based help
- **Parameter descriptions**: Document all parameters with examples
- **Examples**: Provide practical usage examples
- **Notes**: Include important implementation details

### Inline Comments
```powershell
# Complex logic explanation
# This loop processes each device and checks against multiple criteria
# to determine eligibility for Autopilot enrollment
foreach ($device in $devices) {
    # Check device memory requirements (minimum 8GB for standard deployment)
    if ($device.Memory -lt $minMemoryGB) {
        Write-Verbose "Device $($device.Name) doesn't meet memory requirements"
        continue
    }
    
    # Validate device is corporate-owned and not already enrolled
    if ($device.OwnerType -eq "Corporate" -and -not $device.AutopilotEnrolled) {
        $eligibleDevices += $device
    }
}
```

### README and User Documentation
- **Keep user documentation separate** from technical documentation
- **Focus on "how to use"** rather than "how it works"
- **Include troubleshooting** for common user issues
- **Provide examples** for common scenarios

## Build and Release Process

### Version Management
Update version numbers in these files before release:
- `settings.json` - Update version field
- `CreateRelease.ps1` - Update default version if needed
- Any hardcoded version references in code

### Build Commands
```powershell
# Create signed executable release
.\CreateRelease.ps1 -InputFile "main.ps1" -Version "1.2.3"

# Create unsigned executable (development)
.\CreateRelease.ps1 -InputFile "main.ps1" -NoSign

# Create PowerShell module
.\CreateRelease.ps1 -InputFile "main.ps1" -CreateModule

# Build without version increment
.\CreateRelease.ps1 -InputFile "main.ps1" -NoVersionUpdate
```

### Pre-Release Checklist
- [ ] All tests pass
- [ ] Code review completed
- [ ] Documentation updated
- [ ] Version numbers updated
- [ ] Configuration files validated
- [ ] Security review completed
- [ ] Build successful with signatures

### Release Notes
Document changes in these categories:
- **New Features**: New functionality added
- **Bug Fixes**: Issues resolved
- **Security Updates**: Security improvements
- **Breaking Changes**: Changes that affect existing usage
- **Configuration Changes**: Updates to settings or configuration format

### Post-Release Tasks
- Tag the release in Git
- Update documentation website if applicable
- Notify users of new release
- Monitor for issues and feedback

## Common Development Scenarios

### Adding a New Menu Item
1. **Determine menu location** (main menu or submenu)
2. **Create the action function** in appropriate module
3. **Add menu item** with `AddMenuItem`
4. **Test menu inclusion** logic if applicable
5. **Write tests** for the new functionality

### Adding a New Configuration Setting
1. **Add to `globalSettings`** in settings.json
2. **Update domain override** support if needed
3. **Use `Get-ConfigurationValue`** to access the setting
4. **Test configuration merging** logic
5. **Document the new setting**

### Adding a New Microsoft Graph API Endpoint
1. **Check required scopes** and add to auth configuration
2. **Create wrapper function** in GraphAPIFunctions.ps1
3. **Implement error handling** for API-specific errors  
4. **Add parameter validation** for API requirements
5. **Write tests** with mock data if possible

### Debugging Common Issues

#### Configuration Loading Problems
```powershell
# Test configuration loading
$config = Get-JsonConfiguration -FilePath "settings.json" -Verbose

# Check merged settings
$mergedSettings = MergeSettings -localSettings $domainSettings -globalSettings $globalSettings -Verbose
```

#### Authentication Issues
```powershell
# Test authentication with verbose logging
$token = Get-AuthToken -ClientId $clientId -TenantId $tenantId -Verbose

# Check token validity
if ($token -and $token.ExpiresOn -gt (Get-Date)) {
    Write-Host "Token is valid until: $($token.ExpiresOn)"
} else {
    Write-Host "Token is invalid or expired"
}
```

#### Menu Navigation Problems
```powershell
# Debug menu history
Write-Host "Menu History: $($global:MenuHistory -join ' -> ')"

# Test context detection
$context = Get-CallingContext -IncludeNavigationPath -Verbose
Write-Host "Current context: $context"
```

---

This contributor guide provides comprehensive information for developers working on the Windows Autopilot Management Tool. For additional technical details, refer to TECHNICAL_DOCUMENTATION.md.