# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Windows Autopilot Management Tool - a PowerShell-based solution for managing Windows Autopilot device enrollment through Microsoft Intune. Provides an interactive, menu-driven interface for IT administrators.

**Current Version**: 1.3.0.0

### Project Statistics
- **Total Functions**: 208 PowerShell files across 10 categories
- **Test Files**: 73 unit, 14 integration, 8 comprehensive
- **License**: MIT

## Development Commands

```powershell
# Run application in development mode
.\main.ps1 -Verbose -LogLevel "Debug"

# Run with specific app mode
.\main.ps1 -appMode "admin"

# Run all tests (PowerShell 7+ REQUIRED)
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Unit -outputVerbosity Detailed

# Run specific test file
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1" -outputVerbosity Detailed

# Run all test types with coverage
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage -outputVerbosity Detailed

# Create signed release build
.\CreateRelease.ps1 -Stage Build
```

**CRITICAL**: Tests MUST run using `pwsh.exe` (PowerShell 7+). Do NOT use `powershell.exe` (5.1) for tests. The application itself must support PowerShell 5.1, but Pester tests require PowerShell 7+.

## Architecture

### Function Loading
Functions in `functions/` are dynamically dot-sourced at startup from `main.ps1`. Functions load alphabetically with no dependency resolution - each module must be self-contained with no circular dependencies.

### Function Categories (208 total)
| Category | Files | Purpose |
|----------|-------|---------|
| setupFunctions | 45 | Initialization, configuration, settings management, wizards |
| menuFunctions | 27 | Menu system, navigation, display, stack management |
| graphFunctions | 26 | Microsoft Graph API integration, authentication |
| utilityFunctions | 26 | Logging, caching, validation, data formatting |
| UserAndGroupFunctions | 22 | User/group resolution, assignments, membership |
| autopilotFunctions | 16 | Autopilot device management, import/delete, profiles |
| deviceFunctions | 16 | Device operations, status, enrollment, system info |
| reportingFunctions | 14 | Reports, device assessment, data export |
| encryptionFunctions | 11 | Encryption, secure config, password management |
| updateFunctions | 5 | Version checking, update retrieval |

### Configuration Hierarchy
Settings merge in priority order (highest first):
1. Runtime Parameters (command-line)
2. Domain Settings (`settings.psd1` -> `domains[domain].settings`)
3. Global Settings (`settings.psd1` -> `globalSettings`)

### Menu System
Stack-based navigation using global variables:
- `$global:MenuHistory` - Navigation stack
- `$global:History` - General history
- `$global:returnValues` - State between menu actions

Menu items filtered by `includeInDisplayModes` based on current `appMode`.

### App Modes
Role-based access through app modes defined in `menu.psd1`:
| Mode | Best For | Access Level |
|------|----------|--------------|
| full | System Admin | All features unrestricted |
| admin | IT Manager | Administrative + advanced + helpdesk |
| advanced | Technical Staff | Advanced features + helpdesk access |
| helpdesk | Help Desk | Device assignment, troubleshooting |
| registration | Device Specialist | Autopilot enrollment and imports |
| advancedRegistration | Senior Specialist | Advanced Autopilot + custom imports |
| custom | Special Cases | User-defined access patterns |

### Caching System
Multi-layer caching for performance:
- `DirectoryObjectCache` - Users/groups (15 min TTL)
- Configuration cache - Settings files (60 min TTL)
- Graph API cache - API responses (15 min TTL)

## Coding Standards

### PowerShell 5.1 Compatibility (REQUIRED)
The application must support PowerShell 5.1. Avoid:
- Ordered hashtables (`[ordered]@{}`)
- PowerShell 7-only features

### Style
- Four-space indentation
- ~120-character line limit
- PascalCase for functions, camelCase for variables
- Include `$functionName = $MyInvocation.MyCommand.Name` for logging

### ASCII-Only Output
Do NOT use Unicode characters (checkmarks, arrows, emoji) in output:
```powershell
# Correct
Write-Host "[PASS] Test completed"

# Wrong
Write-Host "✓ Test completed"
```

### Function Template
```powershell
function Get-ExampleData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$InputValue
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting"

    try {
        # Function logic
        return $result
    }
    catch {
        Write-Error "[$functionName] Error: $($_.Exception.Message)"
        Write-Log -Message "[$functionName] Error: $($_.Exception.Message)" -Level "Error"
        throw
    }
}
```

## Testing

### Test Structure
```
tests/
├── Unit/           # Unit tests (use for isolated function testing)
├── Integration/    # Integration tests (multi-component workflows)
├── Comprehensive/  # End-to-end scenarios
└── Helpers/
    ├── AutopilotTestHelpers.psm1   # Core utilities (temp files, settings)
    ├── AutopilotGraphMocks.psm1    # Graph API mocking
    └── AutopilotMenuMocks.psm1     # Menu system mocking
```

### Test Requirements
- 100% pass rate required before committing
- Use direct dot-sourcing for function loading (not module imports)
- Always include `AfterAll` cleanup block
- Avoid `TestDrive:` - use `Initialize-AutopilotTestEnvironment` instead

### Writing Tests
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Feature" -Tags 'Unit' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        . "$script:RepoRoot/functions/category/Function.ps1"
        $script:TestContext = Initialize-AutopilotTestEnvironment
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }

    It "Should work" {
        $result = Test-Function
        $result | Should -Be "expected"
    }
}
```

### Binary Cmdlet Mocking
Use exact parameter names (e.g., `Get-CimInstance` uses `-ClassName`, not `-Class`). Return simple types to bypass strict validation.

## Key Patterns

### Directory Object Resolution
Use unified functions for user/group operations:
```powershell
# Preferred
$result = Resolve-DirectoryObject -EntityName $name -EntityType "User"

# Deprecated but backward compatible
$result = Resolve-UserWithMatching -UserName $name
```

### Graph API Calls
Use `CallGraphAPI` for Microsoft Graph operations. Mock with `Invoke-MockGraphAPI` from `AutopilotGraphMocks.psm1` in tests.

### Device Readiness
`AssessDeviceState` orchestrates multi-stage validation: Autopilot registration, enrollment state, profile assignment, hardware validation, user association, pending actions, network connectivity.

### Cache Management
Use `Invoke-CacheManagement` for unified cache operations:
```powershell
# Get cache statistics
Invoke-CacheManagement -Action GetStatistics

# Clear specific cache type
Invoke-CacheManagement -Action ClearSpecific -CacheType Groups

# Available cache types: Devices, Configuration, DirectoryObjects, Groups, Users, Menu, Strings
```

## Key Files

| File | Purpose |
|------|---------|
| `main.ps1` | Application entry point |
| `settings.psd1` | Global and domain settings |
| `menu.psd1` | Menu structure and app mode definitions |
| `strings.psd1` | Localized UI text |
| `Invoke-PesterTests.ps1` | Test runner (requires PowerShell 7+) |
| `CreateRelease.ps1` | Build and release automation |
| `functions/utilityFunctions/Invoke-CacheManagement.ps1` | Unified cache system |
| `functions/graphFunctions/CallGraphAPI.ps1` | Core Graph API client |
| `functions/menuFunctions/ShowMenu.ps1` | Central menu display engine |
| `functions/reportingFunctions/AssessDeviceState.ps1` | Device readiness validation |
