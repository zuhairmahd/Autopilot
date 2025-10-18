# Test Helper Infrastructure Summary

## Overview

This document summarizes the **three-tiered helper module architecture** implemented to support the Pester migration and establish a robust, reusable testing infrastructure for the Autopilot project.

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│ Layer 1: Core Test Infrastructure                                │
│ tests/Helpers/AutopilotTestHelpers.psm1                           │
│ • Temp folder/file management with auto-cleanup                   │
│ • Settings file creation (.psd1 and .json formats)                │
│ • Common mock functions (Write-Log, global variables)             │
│ • Deep hashtable merging for settings overrides                   │
└───────────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌───────────────────────────────────────────────────────────────────┐
│ Layer 2: Domain-Specific Mocking                                 │
├────────────────────────────────┬──────────────────────────────────┤
│ AutopilotGraphMocks.psm1       │ AutopilotMenuMocks.psm1          │
│ tests/Helpers/                 │ tests/Helpers/                   │
│ • Microsoft Graph API          │ • Menu structure generation      │
│ • User/Group object mocking    │ • Show-Menu/New-Menu mocking     │
│ • Device/Profile mocking       │ • Menu environment setup         │
│ • Auth token generation        │ • ReturnValues management        │
└────────────────────────────────┴──────────────────────────────────┘
                              ▲
                              │
┌───────────────────────────────────────────────────────────────────┐
│ Layer 3: Test Files                                              │
│ • tests/Unit/*.Tests.ps1                                          │
│ • tests/Integration/*.Tests.ps1                                   │
│ • tests/Comprehensive/*.Tests.ps1                                 │
└───────────────────────────────────────────────────────────────────┘
```

## Core Philosophy: "Improve Helpers First"

**Critical Principle:** When encountering testing needs that aren't supported by helpers, **enhance the helpers** rather than creating workarounds in individual tests.

### Benefits
- ✅ **Reusability**: Improvements benefit all current and future tests
- ✅ **Consistency**: All tests use the same patterns
- ✅ **Maintainability**: Fixes and enhancements in one place
- ✅ **Documentation**: Helpers serve as living documentation

### Example Enhancement: `.psd1` Support

**Before:** Tests needed `.psd1` files but `New-MockSettingsFile` only created `.json`
**Enhancement:** Added `-FileFormat` parameter with "psd1"/"json" options
**Result:** All tests can now create either format, no workarounds needed

## Layer 1: AutopilotTestHelpers.psm1

**Location:** `tests/Helpers/AutopilotTestHelpers.psm1`

### Functions

| Function | Purpose | Key Features |
|----------|---------|--------------|
| `Initialize-AutopilotTestEnvironment` | Creates test environment | Temp folders, auto-cleanup tracking, repository root detection |
| `Remove-TestEnvironment` | Cleanup | Removes temp folders, handles locked files |
| `New-MockSettingsFile` | Settings files | .psd1/.json formats, deep merge, custom paths |
| `New-MockWriteLog` | Mock Write-Log | Captures log calls for validation |
| `Initialize-MockGlobalVariables` | Setup globals | $LogFile, $settings, optional custom values |
| `Clear-MockGlobalVariables` | Cleanup globals | Removes mock variables |
| `Merge-HashTableDeep` | Deep merge | Recursive hashtable merging for settings |

### Usage Example

```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Settings Functions" {
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Create .psd1 settings file
        $script:settingsPath = New-MockSettingsFile -FileFormat "psd1" -Settings @{
            appMode = "admin"
            domain = "test.local"
            enableLogging = $true
        }
        
        # Setup global variables
        Initialize-MockGlobalVariables -LogFile "test.log" -Settings @{ debug = $true }
        
        # Load functions to test
        . (Join-Path $script:TestContext.RootPath "functions/SettingsFunctions/Merge-Settings.ps1")
    }
    
    AfterAll {
        # Cleanup
        Clear-MockGlobalVariables
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    It "Merges settings correctly" {
        # Test implementation
    }
}
```

### When to Use
- ✅ Tests need temporary files/folders
- ✅ Tests create/modify settings files
- ✅ Tests need to mock Write-Log
- ✅ Tests require standardized global variable setup
- ✅ Multiple tests share common patterns

## Layer 2a: AutopilotGraphMocks.psm1

**Location:** `tests/Helpers/AutopilotGraphMocks.psm1`

### Functions

| Function | Purpose | Key Features |
|----------|---------|--------------|
| `Initialize-GraphMockEnvironment` | Setup mock data store | Optional cache clearing |
| `Add-MockUser` | Add user data | UPN, DisplayName, Id, custom properties |
| `Get-MockUsers` | Retrieve users | Filter by various properties |
| `Add-MockGroup` | Add group data | DisplayName, Id, GroupTypes, custom properties |
| `Get-MockGroups` | Retrieve groups | Filter by various properties |
| `Add-MockDevice` | Add device data | DisplayName, Id, EnrollmentProfileName |
| `Get-MockDevices` | Retrieve devices | Filter by device properties |
| `Add-MockAutopilotProfile` | Add profile data | DisplayName, Id, custom settings |
| `Get-MockAutopilotProfiles` | Retrieve profiles | Filter by profile properties |
| `Invoke-MockGraphAPI` | Simulate Graph API | Filtering, searching, expanding, pagination |
| `New-MockAuthToken` | Generate tokens | Realistic token structure with claims |

### Usage Example

```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Directory Object Search" {
    BeforeAll {
        # Get repo root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Initialize Graph mocking
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add test data
        Add-MockUser -UserPrincipalName "john.doe@contoso.com" -DisplayName "John Doe" `
                     -Id "user-001" -GivenName "John" -Surname "Doe"
        Add-MockUser -UserPrincipalName "jane.smith@contoso.com" -DisplayName "Jane Smith" `
                     -Id "user-002" -GivenName "Jane" -Surname "Smith"
        
        Add-MockGroup -DisplayName "IT Admins" -Id "group-001" -GroupTypes @("Unified")
        Add-MockGroup -DisplayName "Security Team" -Id "group-002" -GroupTypes @("Security")
        
        # Mock CallGraphAPI globally
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel)
            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel
        }
        
        # Load function to test
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
    }
    
    It "Finds user by exact UPN" {
        $result = Get-EntraDirectoryObject -EntityName "john.doe@contoso.com" `
            -AccessToken "mock-token" -EntityType "User"
        $result[0].userPrincipalName | Should -Be "john.doe@contoso.com"
    }
    
    It "Finds group by display name" {
        $result = Get-EntraDirectoryObject -EntityName "IT Admins" `
            -AccessToken "mock-token" -EntityType "Group"
        $result[0].displayName | Should -Be "IT Admins"
    }
}
```

### When to Use
- ✅ Tests call Microsoft Graph API
- ✅ Tests work with directory objects (users, groups)
- ✅ Tests work with devices or Autopilot profiles
- ✅ Tests need authentication token mocking
- ✅ Tests require search/filter simulation

## Layer 2b: AutopilotMenuMocks.psm1

**Location:** `tests/Helpers/AutopilotMenuMocks.psm1`

### Functions

| Function | Purpose | Key Features |
|----------|---------|--------------|
| `Initialize-MenuTestEnvironment` | Setup menu globals | $MenuHistory, $History, $settings, $returnValues |
| `Clear-MenuTestEnvironment` | Cleanup menu globals | Removes menu-related variables |
| `New-MockMenuStructure` | Generate menu hierarchies | Nested menus, actions, submenus, app mode filtering |
| `New-MockNewMenuFunction` | Mock New-Menu | Captures menu display calls |
| `New-MockShowMenuFunction` | Mock Show-Menu | Configurable responses, call history |
| `Set-MockShowMenuResponse` | Configure responses | Set return values for menu selections |
| `Get-MockShowMenuCalls` | Retrieve call history | Assert menu calls, validate parameters |
| `New-MockReturnValues` | Create ReturnValues | Navigation commands (Back, Main Menu, Exit) |

### Usage Example

```powershell
Import-Module "$PSScriptRoot/../Helpers/AutopilotMenuMocks.psm1" -Force

Describe "Menu Filtering" {
    BeforeAll {
        # Get repo root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Initialize menu environment (sets up $Global:settings, $Global:MenuHistory, etc.)
        Initialize-MenuTestEnvironment -AppMode "helpdesk"
        
        # Create comprehensive menu structure
        $script:testMenus = New-MockMenuStructure -IncludeNestedMenus -IncludeActions -IncludeSubmenus
        
        # Load functions to test
        . (Join-Path $script:RepoRoot "functions/menuFunctions/Get-MenuItemsToShow.ps1")
        . (Join-Path $script:RepoRoot "functions/menuFunctions/Search-Menus.ps1")
    }
    
    AfterAll {
        # Cleanup menu environment
        Clear-MenuTestEnvironment
    }
    
    It "Filters menus by app mode" {
        $filteredMenus = Get-MenuItemsToShow -menus $script:testMenus -settings $Global:settings
        $filteredMenus.Count | Should -BeGreaterThan 0
        
        # Should not include admin-only items in helpdesk mode
        $adminItems = $filteredMenus | Where-Object { $_.showIn -contains "admin" -and $_.showIn -notcontains "helpdesk" }
        $adminItems | Should -BeNullOrEmpty
    }
    
    It "Searches menu structure" {
        $searchResults = Search-Menus -searchTerm "user" -menus $script:testMenus
        $searchResults.Count | Should -BeGreaterThan 0
    }
}
```

### When to Use
- ✅ Tests work with menu structures
- ✅ Tests need to mock New-Menu or Show-Menu
- ✅ Tests need menu environment (MenuHistory, History)
- ✅ Tests validate menu filtering or navigation
- ✅ Tests simulate user menu selections

## Helper Selection Guide

| Test Scenario | Helper Module(s) | Example Test |
|---------------|------------------|--------------|
| Settings file operations | AutopilotTestHelpers | SettingsFunctions.Tests.ps1 |
| User/Group API calls | AutopilotGraphMocks | GetEntraDirectoryObject.Tests.ps1 |
| Device/Profile APIs | AutopilotGraphMocks | (future device tests) |
| Menu filtering/navigation | AutopilotMenuMocks | MenuInclusions.Tests.ps1 |
| Combined scenarios | Multiple helpers | (future integration tests) |
| Simple logic tests | None (direct dot-source) | Syntax.Tests.ps1 |

## Test Results

All tests using the enhanced helper infrastructure pass at **100%**:

| Test | Type | Helpers Used | Pass Rate |
|------|------|--------------|-----------|
| SettingsFunctions.Tests.ps1 | Integration | AutopilotTestHelpers | ✅ 11/11 (100%) |
| MenuInclusions.Tests.ps1 | Integration | AutopilotMenuMocks | ✅ 8/8 (100%) |
| GetEntraDirectoryObject.Tests.ps1 | Unit | AutopilotGraphMocks | ✅ 25/25 (100%) |

**Total: 44/44 tests passing (100%)**

## Implementation History

### Phase 1: Core Enhancement (SettingsFunctions Fix)
- **Problem**: SettingsFunctions.Tests.ps1 had 8/11 tests failing
- **Root Causes**: 
  - Parameter name mismatches (`DefaultConfigPath` vs `configPath`)
  - JSON format vs .psd1 format mismatch
  - Domain settings API assumptions
- **Solution**: Enhanced `AutopilotTestHelpers.psm1` with:
  - `.psd1` format support in `New-MockSettingsFile`
  - Deep hashtable merging via `Merge-HashTableDeep`
  - Common mock functions (`New-MockWriteLog`, global variable helpers)
- **Result**: 100% pass rate (11/11 tests)

### Phase 2: Menu Infrastructure (AutopilotMenuMocks)
- **Problem**: Menu test setup code duplicated across tests
- **Solution**: Created `AutopilotMenuMocks.psm1` with:
  - `Initialize-MenuTestEnvironment` / `Clear-MenuTestEnvironment`
  - `New-MockMenuStructure` for realistic menu hierarchies
  - Mock functions for `New-Menu` and `Show-Menu`
  - ReturnValues management
- **Refactored**: MenuInclusions.Tests.ps1 to use new helpers
- **Result**: 100% pass rate maintained, reduced code duplication

### Phase 3: Graph API Enhancement
- **Problem**: Device and profile tests would need mocking infrastructure
- **Solution**: Enhanced `AutopilotGraphMocks.psm1` with:
  - `Add-MockDevice` / `Get-MockDevices`
  - `Add-MockAutopilotProfile` / `Get-MockAutopilotProfiles`
  - `New-MockAuthToken` for authentication scenarios
- **Result**: Ready for future device/profile test migration

### Phase 4: Documentation Update
- **Updated**: `TEST_TEMPLATE_GUIDELINES.md` with:
  - "Improve Helpers First" philosophy
  - Three-tiered architecture diagram
  - Helper selection guide
  - Usage patterns for all three helpers
  - Real-world examples from production tests
- **Updated**: `AGENTS.md` with testing guidelines
- **Created**: This summary document

## PowerShell 5.1 Compatibility Notes

### Function Loading Pattern
Due to PowerShell 5.1 + Pester 5.x scoping limitations, **direct dot-sourcing in BeforeAll** is the most reliable pattern:

```powershell
BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Dot-source functions directly
    $functionsPath = Join-Path $script:RepoRoot "functions"
    Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}
```

**Why this works:**
- Dot-sourcing happens in BeforeAll scope
- Pester makes BeforeAll scope available to tests
- Functions become available in all It blocks

**Why module-based loading doesn't work reliably:**
- Module functions can't dot-source into caller's scope
- Scoping rules prevent reliable function availability

### Switch Parameter Defaults
Fixed linting issues with switch parameters using PSBoundParameters pattern:

```powershell
# Before (linter warning)
function My-Function {
    param([switch]$MySwitchParam = $false)
}

# After (correct)
function My-Function {
    param([switch]$MySwitchParam)
    if (-not $PSBoundParameters.ContainsKey('MySwitchParam')) {
        $MySwitchParam = $false
    }
}
```

## Best Practices

### 1. Choose the Right Helper Layer
- **Layer 1 (Core)**: Temp files, settings files, common mocks
- **Layer 2 (Domain-Specific)**: Graph API, Menu system, (future: other domains)
- **Layer 3 (Tests)**: Use helpers, don't duplicate logic

### 2. Enhance Helpers, Don't Create Workarounds
- ❌ **Bad**: Copy-paste setup code from another test
- ❌ **Bad**: Create inline workarounds for missing helper features
- ✅ **Good**: Add capability to appropriate helper module
- ✅ **Good**: Document enhancement in helper and guidelines

### 3. Document Your Approach
Add `.NOTES` section to tests explaining:
- Test category (Unit, Integration, Comprehensive)
- Template compliance (Full, Partial, None)
- Helpers used (if any)
- Reason for deviations (if applicable)

### 4. Ensure 100% Pass Rate
- All tests must pass before committing
- Run tests locally before pushing
- Fix failures immediately, don't commit broken tests

### 5. Proper Cleanup
- Use `AfterAll` blocks consistently
- Call helper cleanup functions (`Remove-TestEnvironment`, `Clear-MenuTestEnvironment`)
- Handle global variable removal (`Clear-MockGlobalVariables`)

## Future Enhancements

### Additional Helper Modules (Potential Layer 2 Additions)
- **AutopilotDeviceMocks** - Comprehensive device management mocking (if device tests need more than current Graph mocks)
- **AutopilotProfileMocks** - Autopilot profile-specific operations (if profile tests need dedicated infrastructure)
- **AutopilotReportingMocks** - Reporting and export function mocking

### Helper Improvements
- **AutopilotTestHelpers**:
  - Add support for additional file formats (XML, YAML)
  - Enhanced logging capture and validation
  - Test data generation utilities
  
- **AutopilotGraphMocks**:
  - Pagination simulation for large datasets
  - Error response simulation (401, 403, 429, 500)
  - Throttling and retry behavior mocking
  
- **AutopilotMenuMocks**:
  - Complex navigation flow simulation
  - Menu history validation helpers
  - Performance testing support

### Documentation
- Add visual diagrams for helper architecture
- Create video walkthrough of helper usage
- Expand examples in Template.Tests.ps1

## Migration Impact

The helper infrastructure directly supports Pester migration goals:

| Migration Phase | Helper Support | Status |
|----------------|----------------|--------|
| Phase 1: Syntax | Not needed (simple tests) | ✅ Complete |
| Phase 2: Core | AutopilotTestHelpers | ✅ In Progress |
| Phase 3: Integration | All three helpers | ✅ Infrastructure Ready |
| Phase 4+: Comprehensive | All helpers + enhancements | ⏳ Future |

## Conclusion

The three-tiered helper architecture provides:

1. **Reusable Infrastructure**: Common patterns extracted to helpers
2. **Consistent Patterns**: All tests use same approaches
3. **Easy Maintenance**: Fixes and improvements in one place
4. **Future-Proof**: Extensible for new test scenarios
5. **High Quality**: 100% pass rate achieved and maintained
6. **Developer Friendly**: Clear documentation and examples

**Result**: Robust foundation for completing Pester migration with high quality and maintainability.

---

*For detailed usage guidelines, see [TEST_TEMPLATE_GUIDELINES.md](TEST_TEMPLATE_GUIDELINES.md)*
*For migration progress, see [PESTER_MIGRATION_PROGRESS.md](PESTER_MIGRATION_PROGRESS.md)*
*For project guidelines, see [AGENTS.md](../AGENTS.md)*
