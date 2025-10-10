# Pester Test Template Usage Guidelines

## Overview

This document explains when and how to use the test template (`tests/Template.Tests.ps1`) and helper modules when writing Pester tests for the Autopilot project.

## Core Philosophy: Improve Helpers, Not Workarounds

**🎯 CRITICAL PRINCIPLE:** When you encounter a testing need that isn't supported by the helpers, **improve the helpers** rather than creating workarounds in individual tests.

### Why This Matters

- ✅ **Reusability**: Improvements benefit all current and future tests
- ✅ **Consistency**: All tests use the same patterns and approaches
- ✅ **Maintainability**: Fixes and enhancements in one place
- ✅ **Documentation**: Helpers serve as living documentation of best practices

### Examples of Helper Improvements

1. **File Format Support**: If tests need `.psd1` files but helpers only create `.json`, enhance `New-MockSettingsFile` to support both formats
2. **Additional API Mocking**: If tests need device or identity API calls, extend `AutopilotGraphMocks.psm1` with new mock functions
3. **New Test Scenarios**: If tests need specific mock data patterns, add functions to create those patterns in helpers

### When You Should Enhance Helpers

- ❓ "I need to create a `.psd1` file but the helper creates `.json`" → **Enhance helper**
- ❓ "I need to mock device API calls but only user/group mocks exist" → **Enhance helper**
- ❓ "I need specific test data patterns multiple tests will use" → **Enhance helper**
- ❓ "I'm copying test setup code from another test" → **Extract to helper**

### Process for Helper Enhancements

1. **Identify the need**: What capability is missing?
2. **Check for patterns**: Will other tests benefit from this?
3. **Design the enhancement**: How should the API work?
4. **Implement in helper**: Add the new function/parameter/feature
5. **Document in helper**: Add comment-based help
6. **Update guidelines**: Document the new capability here
7. **Use in your test**: Apply the enhancement

## Three-Tiered Helper Architecture

The Autopilot test infrastructure uses a **three-tiered helper module system** for comprehensive test support:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Core Test Infrastructure                          │
│ AutopilotTestHelpers.psm1                                   │
│ • Temp folder management                                    │
│ • Settings file creation (.psd1/.json)                      │
│ • Common mock functions (Write-Log, global variables)       │
│ • Deep hashtable merging                                    │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Domain-Specific Mocking                           │
├─────────────────────────────────────────────────────────────┤
│ AutopilotGraphMocks.psm1    │ AutopilotMenuMocks.psm1       │
│ • Microsoft Graph API       │ • Menu structure generation   │
│ • User/Group mocking        │ • Show-Menu/New-Menu mocking  │
│ • Device/Profile mocking    │ • Menu environment setup      │
│ • Auth token generation     │ • ReturnValues management     │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Test Files                                        │
│ • Unit Tests (tests/Unit/)                                  │
│ • Integration Tests (tests/Integration/)                    │
│ • Comprehensive Tests (tests/Comprehensive/)                │
└─────────────────────────────────────────────────────────────┘
```

### Layer 1: AutopilotTestHelpers.psm1 (Core Infrastructure)

**Purpose:** Foundation for all tests requiring file I/O, temporary folders, or common mock patterns.

**Key Functions:**
- `Initialize-AutopilotTestEnvironment` - Creates temp folders with auto-cleanup tracking
- `Remove-TestEnvironment` - Cleans up temp folders and resources
- `New-MockSettingsFile` - Creates `.psd1` or `.json` settings files with deep merge support
- `New-MockWriteLog` - Mocks Write-Log function for log-related tests
- `Initialize-MockGlobalVariables` - Sets up common global variables ($LogFile, $settings)
- `Clear-MockGlobalVariables` - Removes mock global variables
- `Merge-HashTableDeep` - Deep merges hashtables for settings overrides

**When to Use:**
- Tests need temporary files/folders
- Tests need to create/modify settings files
- Tests need to mock Write-Log
- Tests need standardized global variable setup
- Multiple tests share common patterns

**Example:**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Settings Functions" {
    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:settingsPath = New-MockSettingsFile -FileFormat "psd1" -Settings @{
            appMode = "admin"
            domain = "test.local"
        }
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
}
```

### Layer 2a: AutopilotGraphMocks.psm1 (Microsoft Graph API)

**Purpose:** Comprehensive Microsoft Graph API mocking for user, group, device, and profile operations.

**Key Functions:**
- `Initialize-GraphMockEnvironment` - Sets up mock data store with optional cache clearing
- `Add-MockUser` / `Get-MockUsers` - User object management
- `Add-MockGroup` / `Get-MockGroups` - Group object management
- `Add-MockDevice` / `Get-MockDevices` - Device object management
- `Add-MockAutopilotProfile` / `Get-MockAutopilotProfiles` - Autopilot profile management
- `Invoke-MockGraphAPI` - Simulates Graph API calls with filtering, searching, expanding
- `New-MockAuthToken` - Generates realistic authentication tokens

**When to Use:**
- Tests call Microsoft Graph API
- Tests work with directory objects (users, groups)
- Tests work with devices or Autopilot profiles
- Tests need authentication token mocking
- Tests require search/filter simulation

**Example:**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Directory Object Search" {
    BeforeAll {
        # Initialize Graph mocking
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add test data
        Add-MockUser -UserPrincipalName "john.doe@contoso.com" -DisplayName "John Doe" -Id "user-123"
        Add-MockGroup -DisplayName "IT Admins" -Id "group-456" -GroupTypes @("Unified")
        
        # Mock CallGraphAPI globally
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel)
            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel
        }
        
        # Load function to test
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
    }
}
```

### Layer 2b: AutopilotMenuMocks.psm1 (Menu System)

**Purpose:** Menu structure generation and menu function mocking for menu-related tests.

**Key Functions:**
- `Initialize-MenuTestEnvironment` - Sets up global menu variables ($MenuHistory, $History, $settings, $returnValues)
- `Clear-MenuTestEnvironment` - Removes menu global variables
- `New-MockMenuStructure` - Generates realistic menu hierarchies with nested menus, actions, submenus
- `New-MockNewMenuFunction` - Mocks New-Menu for capturing menu display calls
- `New-MockShowMenuFunction` - Mocks Show-Menu with configurable responses
- `Set-MockShowMenuResponse` - Configures Show-Menu return values for testing flows
- `Get-MockShowMenuCalls` - Retrieves Show-Menu call history for assertions
- `New-MockReturnValues` - Creates ReturnValues hashtable with common navigation actions

**When to Use:**
- Tests work with menu structures
- Tests need to mock New-Menu or Show-Menu
- Tests need menu environment (MenuHistory, History)
- Tests validate menu filtering or navigation
- Tests need to simulate user menu selections

**Example:**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotMenuMocks.psm1" -Force

Describe "Menu Filtering" {
    BeforeAll {
        # Initialize menu environment
        Initialize-MenuTestEnvironment -AppMode "helpdesk"
        
        # Create menu structure
        $script:testMenus = New-MockMenuStructure -IncludeNestedMenus -IncludeActions -IncludeSubmenus
        
        # Load functions to test
        . (Join-Path $script:RepoRoot "functions/menuFunctions/Get-MenuItemsToShow.ps1")
    }
    
    AfterAll {
        Clear-MenuTestEnvironment
    }
    
    It "Filters menus by app mode" {
        $filteredMenus = Get-MenuItemsToShow -menus $script:testMenus -settings $Global:settings
        $filteredMenus.Count | Should -BeGreaterThan 0
    }
}
```

### Choosing the Right Helper Layer

| Test Needs | Helper Module(s) | Example Test |
|------------|------------------|--------------|
| Temp files only | AutopilotTestHelpers | SettingsFunctions.Tests.ps1 |
| Graph API calls | AutopilotTestHelpers + AutopilotGraphMocks | GetEntraDirectoryObject.Tests.ps1 |
| Menu operations | AutopilotTestHelpers + AutopilotMenuMocks | MenuInclusions.Tests.ps1 |
| Graph + Menu | All three helpers | (future integration tests) |
| Simple logic | None (direct dot-source) | Syntax.Tests.ps1 |

## Template Components

### Helper Module Details

1. **AutopilotTestHelpers.psm1** - Core test utilities (Layer 1)
   - `Initialize-AutopilotTestEnvironment` - Creates temp folders, sets up test context
   - `Import-AutopilotFunctions` - Loads functions (note: see limitations below)
   - `Remove-TestEnvironment` - Cleans up test folders
   - `New-MockSettingsFile` - Creates mock configuration files (.psd1 or .json format)
   - `New-MockWriteLog` - Mocks Write-Log function
   - `Initialize-MockGlobalVariables` - Sets up $LogFile, $settings
   - `Clear-MockGlobalVariables` - Removes mock globals

2. **AutopilotGraphMocks.psm1** - Graph API mocking (Layer 2a)
   - Mock data management (Add-MockUser, Add-MockGroup, Add-MockDevice, Add-MockAutopilotProfile)
   - Graph API simulation (Invoke-MockGraphAPI)
   - Authentication (New-MockAuthToken)
   - Test environment initialization for directory object tests

3. **AutopilotMenuMocks.psm1** - Menu system mocking (Layer 2b)
   - Menu structure generation (New-MockMenuStructure)
   - Menu function mocking (New-MockNewMenuFunction, New-MockShowMenuFunction)
   - Menu environment setup (Initialize-MenuTestEnvironment, Clear-MenuTestEnvironment)
   - ReturnValues management (New-MockReturnValues)

## When to Use the Template

### ✅ REQUIRED: Use helpers for tests that need:

1. **Temporary Files/Folders**
   - Configuration file testing
   - Log file operations
   - Any test that writes to disk

2. **Graph API Mocking**
   - Directory object operations (users, groups)
   - Any test calling Microsoft Graph
   - Authentication testing

3. **Complex State Management**
   - Tests requiring cleanup between runs
   - Tests with multiple setup/teardown steps

### ⚠️ OPTIONAL: Direct approaches acceptable for:

1. **Syntax Validation**
   - Simple file parsing
   - No external dependencies
   - No state to manage

2. **Pure Function Testing**
   - Functions with no side effects
   - No file I/O
   - No API calls

3. **Simple Unit Tests**
   - Testing single functions in isolation
   - Direct dot-sourcing is more reliable than Import-AutopilotFunctions

## PowerShell 5.1 + Pester 5.x Scoping Considerations

### The Challenge

PowerShell 5.1 with Pester 5.x has complex scoping behavior:
- Functions loaded in a module stay in the module's scope
- Functions loaded in BeforeAll have limited visibility
- Dot-sourcing is the ONLY reliable way to load functions for testing

### Best Practice: Direct Dot-Sourcing

**For most tests, use direct dot-sourcing in BeforeAll:**

```powershell
Describe "My Feature" {
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Dot-source functions directly
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }
    }
}
```

**Why this works:**
- Dot-sourcing happens in the BeforeAll scope
- Pester makes BeforeAll scope available to tests
- Functions become available in all It blocks

**Why Import-AutopilotFunctions doesn't work:**
- Module functions can't dot-source into caller's scope
- Scoping rules prevent reliable function availability
- Only works for simple cases

## Template Usage Patterns

### Pattern 1: Full Template (Tests with Temp Files)

```powershell
# Import helper
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Feature Name" {
    BeforeAll {
        # Initialize environment (creates temp folders)
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Dot-source functions directly (most reliable)
        $functionsPath = Join-Path $TestContext.RootPath "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }
    }
    
    AfterAll {
        # Clean up temp folders
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    # Tests...
}
```

### Pattern 2: Graph API Mocking

```powershell
# Import both helpers
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Directory Object Feature" {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Load function being tested
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
        
        # Initialize Graph mocking
        Initialize-GraphMockEnvironment -ClearCache
        
        # Mock CallGraphAPI
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel)
            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel
        }
    }
    
    # Tests...
}
```

### Pattern 3: Simple Tests (No Helpers Needed)

```powershell
Describe "Simple Feature" {
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Dot-source specific functions needed
        . (Join-Path $script:RepoRoot "functions/someFolder/MyFunction.ps1")
    }
    
    # Tests...
}
```

## Documentation Requirements

### When NOT using helpers, document why:

Add a `.NOTES` section to your test explaining the deviation:

```powershell
<#
.SYNOPSIS
    My test description

.NOTES
    Test Category: Unit
    Template Compliance: Partial - No helpers needed
    Reason: Simple syntax validation, no state management required
#>
```

### When using helpers, document what:

```powershell
<#
.SYNOPSIS
    My test description

.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotTestHelpers for temp folders, AutopilotGraphMocks for API simulation
#>
```

## Existing Test Analysis

### Tests Following Best Practices

| Test | Pattern | Helpers Used | Notes |
|------|---------|--------------|-------|
| GetEntraDirectoryObject.Tests.ps1 | Graph API Mocking | AutopilotGraphMocks | ✅ Exemplary - full Graph API simulation |
| ShowDirectoryObjectList.Tests.ps1 | Custom Mocks | None | ✅ Appropriate for menu testing |
| ResolveDirectoryObject.Tests.ps1 | Graph API Mocking | AutopilotGraphMocks | ✅ Integration test |
| MenuInclusions.Tests.ps1 | Menu Mocking | AutopilotMenuMocks | ✅ Exemplary - uses Initialize-MenuTestEnvironment |
| SettingsFunctions.Tests.ps1 | Settings + Temp Files | AutopilotTestHelpers | ✅ Exemplary - .psd1 support, 100% pass rate |

### Tests with Acceptable Deviations

| Test | Reason | Status |
|------|--------|--------|
| Syntax.Tests.ps1 | No state, no I/O, simple validation | ✅ Acceptable |
| FunctionLoading.Tests.ps1 | Tests loading mechanism itself | ✅ Acceptable |
| DomainConfiguration.Tests.ps1 | Self-contained, no helpers needed | ✅ Acceptable |

### Helper Usage Patterns in Production Tests

**Pattern 1: Core Infrastructure Only (SettingsFunctions.Tests.ps1)**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

BeforeAll {
    $script:TestContext = Initialize-AutopilotTestEnvironment
    $script:settingsPath = New-MockSettingsFile -FileFormat "psd1" -Settings @{ appMode = "admin" }
}
AfterAll {
    Remove-TestEnvironment -TestContext $script:TestContext
}
```

**Pattern 2: Graph API Mocking (GetEntraDirectoryObject.Tests.ps1)**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

BeforeAll {
    Initialize-GraphMockEnvironment -ClearCache
    Add-MockUser -UserPrincipalName "test@contoso.com" -DisplayName "Test User"
    
    function global:CallGraphAPI { /* ... */ }
}
```

**Pattern 3: Menu System Mocking (MenuInclusions.Tests.ps1)**
```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotMenuMocks.psm1" -Force

BeforeAll {
    Initialize-MenuTestEnvironment -AppMode "helpdesk"
    $script:testMenus = New-MockMenuStructure -IncludeNestedMenus -IncludeActions
}
AfterAll {
    Clear-MenuTestEnvironment
}
```

## Summary

**Key Principles:**

1. **Three-tiered helper architecture** - Core (AutopilotTestHelpers), Domain-Specific (AutopilotGraphMocks, AutopilotMenuMocks), Test Files
2. **Improve helpers first** - When encountering new testing needs, enhance helpers rather than creating workarounds
3. **Use helpers when you need them** - temp files, cleanup, Graph API mocking, menu mocking
4. **Direct dot-sourcing is preferred** for loading functions to test (PowerShell 5.1 + Pester 5.x scoping limitation)
5. **Document deviations** from the template pattern
6. **Prioritize test reliability** over strict template adherence
7. **All tests must pass** - 100% success rate is mandatory
8. **Share improvements** - Helper enhancements benefit the entire test suite

**Helper Selection Guide:**

| Need | Helper Module | Key Functions |
|------|---------------|---------------|
| Temp folders/files | AutopilotTestHelpers | Initialize-AutopilotTestEnvironment, New-MockSettingsFile |
| Settings files (.psd1) | AutopilotTestHelpers | New-MockSettingsFile with -FileFormat "psd1" |
| Write-Log mocking | AutopilotTestHelpers | New-MockWriteLog |
| Global variable setup | AutopilotTestHelpers | Initialize-MockGlobalVariables |
| User/Group API calls | AutopilotGraphMocks | Add-MockUser, Add-MockGroup, Invoke-MockGraphAPI |
| Device/Profile APIs | AutopilotGraphMocks | Add-MockDevice, Add-MockAutopilotProfile |
| Auth tokens | AutopilotGraphMocks | New-MockAuthToken |
| Menu structures | AutopilotMenuMocks | New-MockMenuStructure, Initialize-MenuTestEnvironment |
| Menu functions | AutopilotMenuMocks | New-MockNewMenuFunction, New-MockShowMenuFunction |

**When in Doubt:**
- Start with direct dot-sourcing in BeforeAll for function loading
- Add Layer 1 helper (AutopilotTestHelpers) for temp files/folders
- Add Layer 2 helpers (Graph/Menu) for domain-specific mocking
- If you need something helpers don't provide, enhance the helpers
- Document your approach in .NOTES section
- Ensure test cleanup happens in AfterAll

**Helper Enhancement Checklist:**
- [ ] Does this need exist in multiple tests?
- [ ] Would other tests benefit from this capability?
- [ ] Is this a pattern worth standardizing?
- [ ] Can this be generalized for reuse?
- [ ] Which helper layer does it belong to? (Core, Graph, Menu, or new domain?)
- [ ] If yes to any: Enhance the helper modules

**Test Quality Standards:**
- ✅ 100% test pass rate (mandatory)
- ✅ Proper cleanup in AfterAll blocks
- ✅ Comment-based help with .NOTES section
- ✅ Use helpers when appropriate
- ✅ Document deviations when not using helpers
- ✅ Follow PowerShell 5.1 compatibility patterns
- ✅ Use approved verbs for function names
