# Developer Guide

Comprehensive guide for developers and contributors working on the Windows Autopilot Management Tool.

## Table of Contents

- [Getting Started](#getting-started)
- [Project Architecture](#project-architecture)
- [Menu System](#menu-system)
- [Caching System](#caching-system)
- [Testing Framework](#testing-framework)
- [Coding Standards](#coding-standards)
- [Contributing](#contributing)

## Getting Started

### Prerequisites

- **PowerShell 5.1+** (application must support 5.1)
- **PowerShell 7+** (required for running tests)
- **Git** for version control
- **VS Code** with PowerShell extension (recommended)
- **Azure AD App Registration** for testing Graph API

### Quick Setup

```powershell
# Clone the repository
git clone https://github.com/zuhairmahd/autopilot.git
cd autopilot

# Run in development mode
.\main.ps1 -Verbose -LogLevel "Debug"

# Run tests (PowerShell 7+ required)
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed
```

### Development Commands

```powershell
# Run with specific app mode
.\main.ps1 -appMode "test" -Verbose

# Force new authentication token
.\main.ps1 -ForceNewToken -Delegated

# Use custom configuration
.\main.ps1 -InitFile "custom-settings.psd1"
```

## Project Architecture

### Directory Structure

```
/
├── functions/                 # PowerShell modules (dot-sourced at startup)
│   ├── UserAndGroupFunctions/ # User/Group operations
│   ├── autopilotFunctions/    # Autopilot device management
│   ├── deviceFunctions/       # Device operations
│   ├── encryptionFunctions/   # Security and encryption
│   ├── graphFunctions/        # Microsoft Graph API
│   ├── menuFunctions/         # UI and navigation
│   ├── reportingFunctions/    # Reporting and export
│   ├── setupFunctions/        # Configuration and setup
│   ├── updateFunctions/       # Auto-update functionality
│   └── utilityFunctions/      # General utilities
├── tests/                     # Pester test files
│   ├── Unit/                  # Unit tests
│   ├── Integration/           # Integration tests
│   ├── Comprehensive/         # End-to-end tests
│   └── Helpers/               # Test helper modules
├── docs/                      # Documentation
├── .secrets/                  # Encrypted credentials (runtime)
├── Logs/                      # Application logs
├── main.ps1                   # Entry point
├── settings.psd1              # Main configuration
├── menu.psd1                  # Menu definitions
└── strings.psd1               # UI text
```

### Function Loading

Functions are dynamically loaded at startup using dot-sourcing:

```powershell
# From main.ps1
Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}
```

**Key Principles:**
- Functions load alphabetically with no dependency resolution
- Each module must be self-contained
- No circular dependencies between modules

### Configuration Hierarchy

Settings merge in this order (highest priority first):

1. **Runtime Parameters** - Command-line arguments
2. **Domain Settings** - `settings.psd1` -> `domains[domain].settings`
3. **Global Settings** - `settings.psd1` -> `globalSettings`

The `MergeSettings` function handles this merging.

### Device Readiness Architecture

The application includes comprehensive device readiness assessment functionality:

#### Key Components

| Function | Purpose |
|----------|---------|
| `AssessDeviceState` | Main assessment orchestrator with multiple assessment types |
| `GetManagedDeviceRelevantProperties` | Extract device properties and check user association |
| `GetAutopilotDeviceRelevantProperties` | Validate Autopilot profile assignment |
| `GetLastDeviceContactDate` | Check device connectivity threshold |
| `getDevicePendingActions` | Detect incomplete device actions |

#### Readiness Checks

The system performs multi-stage validation:

1. **Autopilot Registration**: Confirms device is in Autopilot
2. **Enrollment State**: Validates enrollment status (notContacted/enrolled)
3. **Profile Assignment**: Checks correct Autopilot profile
4. **Hardware Validation**: Verifies RAM meets requirements
5. **User Association**: Determines if device has user and if it's the intended user
6. **Pending Actions**: Detects incomplete operations (wipe, reset, sync)
7. **Network Connectivity**: Ensures device recently contacted Intune

#### Special Cases

- **Same-User Devices**: Devices already registered to intended user are identified
- **Unmanaged Devices**: Properly handled without managed device checks
- **Orphan Detection**: Identifies devices with mismatched Autopilot/Intune records
- **Invalid Users**: Detects service principal or deleted user associations

#### Settings

- `includeEnrolledDevicesInNextUserReadiness`: Include enrolled devices in readiness checks
- `MinimumDevicePhysicalMemoryInGB`: RAM requirement (default: 16GB)
- `deviceContactThresholdInDays`: Days before device considered stale (default: 30)

## Menu System

### Architecture

The menu system uses a hierarchical, stack-based navigation pattern:

```
$global:MenuHistory  - Navigation stack for back/forward
$global:History      - General history tracking
$global:returnValues - State passed between menu actions
```

### Key Functions

| Function | Purpose |
|----------|---------|
| `DisplayNumericMenu` | Primary menu rendering |
| `ShowMenu` | Menu orchestration |
| `Handle-MenuItemSelection` | User input processing |
| `Handle-ActionExecution` | Action dispatch |
| `Get-CallingContext` | Context-aware navigation |

### Menu Definition (menu.psd1)

```powershell
menus = @(
    @{
        name = "MainMenu"
        title = "Main Menu"
        items = @(
            @{
                name = "Give a device to a user"
                action = "AssignDeviceToUser"
                includeInDisplayModes = @("full", "helpdesk", "admin")
            }
            @{
                name = "Autopilot menu"
                submenu = "AutopilotMenu"
                includeInDisplayModes = @("full", "registration", "admin")
            }
        )
    }
)
```

### App Mode Filtering

Menu items are filtered based on `includeInDisplayModes`:

```powershell
# Check if item should show for current mode
if (Test-MenuItemIncluded -MenuItemName "Advanced Options") {
    # Add menu item
}
```

### Context-Aware Navigation

```powershell
# Get current navigation context
$context = Get-CallingContext -IncludeNavigationPath

switch -Regex ($context) {
    'Action-ViaCheckMenu' {
        # Accessed via Check Device Status
    }
    'Action-ViaAutopilotMenu' {
        # Accessed via Autopilot menu
    }
}
```

## Caching System

### Multi-Layer Architecture

The caching system provides significant performance improvements:

| Cache Type | Purpose | TTL |
|------------|---------|-----|
| Configuration | Settings files | 60 min |
| DirectoryObjects | Users, groups | 15 min |
| Devices | Device data | 15 min |
| Graph API | API responses | 15 min |

### Cache Management

```powershell
# Get cache statistics
Invoke-CacheManagement -Action GetStatistics

# Clear specific cache type
Invoke-CacheManagement -Action Clear -CacheType DirectoryObjects

# Monitor performance
Invoke-CacheManagement -Action Monitor -ShowDetails
```

### DirectoryObjectCache

The `DirectoryObjectCache` reduces redundant Graph API calls:

```powershell
# Module-level cache
$script:DirectoryObjectCache = @{}

# Cache key format: "EntityType:SearchTerm"
$cacheKey = "User:john.doe@contoso.com"
```

### Configuration Caching

Settings files are cached after first load:

```powershell
# Cached configuration loading
$config = Get-CachedConfiguration -FilePath "settings.psd1"
```

## Testing Framework

### Framework Overview

The project uses **Pester v5** for testing:

- **Unit tests**: 144+ tests in `tests/Unit/`
- **Integration tests**: 36+ tests in `tests/Integration/`
- **Comprehensive tests**: End-to-end scenarios in `tests/Comprehensive/`

**CRITICAL**: Tests must run in PowerShell 7+ (`pwsh.exe`), not PowerShell 5.1.

### Running Tests

```powershell
# Run all unit tests
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed

# Run specific test file
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"

# Run with code coverage
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage
```

### Test Helper Modules

Three-tiered helper architecture:

| Layer | Module | Purpose |
|-------|--------|---------|
| 1 (Core) | `AutopilotTestHelpers.psm1` | Temp folders, settings files |
| 2a (API) | `AutopilotGraphMocks.psm1` | Graph API mocking |
| 2b (Menu) | `AutopilotMenuMocks.psm1` | Menu system mocking |

### Writing Tests

**Standard test structure:**

```powershell
<#
.SYNOPSIS
    Tests for Feature X
.NOTES
    Test Category: Unit
    Uses: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Feature X" -Tags 'Unit' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Direct dot-sourcing (required for PS 5.1 compatibility)
        . "$script:RepoRoot/functions/category/Function.ps1"
        
        $script:TestContext = Initialize-AutopilotTestEnvironment
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    It "Should do something" {
        $result = Test-Function
        $result | Should -Be "expected"
    }
}
```

**Key principles:**
- Use direct dot-sourcing (not module imports)
- Always include `AfterAll` cleanup
- Maintain 100% pass rate
- Use `Sort-Object` for deterministic ordering

### Test Documentation

- [tests/AGENTS.md](../tests/AGENTS.md) - AI-optimized test guide
- [PESTER_MIGRATION_README.md](archive/PESTER_MIGRATION_README.md) - Migration status

## Coding Standards

### PowerShell 5.1 Compatibility

The application must support PowerShell 5.1:

**DO:**
```powershell
# Use standard hashtables
$config = @{ key = "value" }

# Use -f operator for formatting
$message = "Device {0} assigned to {1}" -f $device, $user
```

**DON'T:**
```powershell
# Avoid ordered hashtables (PS 5.1 issues)
$config = [ordered]@{ key = "value" }

# Avoid string interpolation in some contexts
$message = "Device $device assigned to $user"
```

### Function Template

```powershell
function Get-ExampleData {
    <#
    .SYNOPSIS
        Brief description of function.
    
    .DESCRIPTION
        Detailed description.
    
    .PARAMETER InputValue
        Description of parameter.
    
    .EXAMPLE
        Get-ExampleData -InputValue "test"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$InputValue
    )
    
    # Function name for logging
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting"
    
    try {
        # Function logic
        Write-Verbose "[$functionName] Processing: $InputValue"
        
        return $result
    }
    catch {
        Write-Error "[$functionName] Error: $($_.Exception.Message)"
        Write-Log -Message "[$functionName] Error: $($_.Exception.Message)" -Level "Error"
        throw
    }
}
```

### Logging Standards

```powershell
# Function name at start
$functionName = $MyInvocation.MyCommand.Name

# Verbose for debugging
Write-Verbose "[$functionName] Processing device: $deviceName"

# Write-Log for persistent logging
Write-Log -Message "[$functionName] Operation complete" -Level "Information"
Write-Log -Message "[$functionName] Warning condition" -Level "Warning"
Write-Log -Message "[$functionName] Error occurred" -Level "Error"
```

### ASCII-Only Output

PowerShell 5.1 console may not render Unicode correctly:

```powershell
# DO: Use ASCII
Write-Host "[PASS] Test completed"
Write-Host "[INFO] Processing..."

# DON'T: Use Unicode
Write-Host "✓ Test completed"
Write-Host "→ Processing..."
```

## Contributing

### Development Workflow

1. **Create feature branch**
   ```bash
   git checkout -b feature/new-feature-name
   ```

2. **Develop and test**
   ```powershell
   # Run relevant tests frequently
   pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\Related.Tests.ps1"
   ```

3. **Ensure tests pass**
   ```powershell
   # Run full test suite before PR
   pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType All
   ```

4. **Update documentation** if needed

### Pre-Commit Checklist

- [ ] All tests pass (100% pass rate required)
- [ ] PowerShell 5.1 compatibility maintained
- [ ] Function has comment-based help
- [ ] Logging follows standards
- [ ] No Unicode characters in output
- [ ] Documentation updated if needed

### Build and Release

```powershell
# Create signed release
.\CreateRelease.ps1 -InputFile "main.ps1" -Version "1.2.3"

# Create unsigned (development)
.\CreateRelease.ps1 -InputFile "main.ps1" -NoSign

# Build without version increment
.\CreateRelease.ps1 -InputFile "main.ps1" -NoVersionUpdate
```

## Additional Resources

### Documentation Index

| Document | Description |
|----------|-------------|
| [SETTINGS.md](SETTINGS.md) | Complete settings reference |
| [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) | Detailed technical docs |
| [CONTRIBUTOR_GUIDE.md](CONTRIBUTOR_GUIDE.md) | Additional contributor info |
| [MENU_SYSTEM_DOCUMENTATION.md](features/MENU_SYSTEM_DOCUMENTATION.md) | Menu system details |

### External Resources

- [Windows Autopilot Docs](https://learn.microsoft.com/en-us/mem/autopilot/)
- [Microsoft Graph API](https://learn.microsoft.com/en-us/graph/)
- [Pester Documentation](https://pester.dev/)

---

*For end-user documentation, see [README.md](../readme.md).*
