# Pester Test Template Usage Guidelines

## Overview

This document explains when and how to use the test template (`tests/Template.Tests.ps1`) and helper modules when writing Pester tests for the Autopilot project.

## Template Components

### Helper Modules

1. **AutopilotTestHelpers.psm1** - Core test utilities
   - `Initialize-AutopilotTestEnvironment` - Creates temp folders, sets up test context
   - `Import-AutopilotFunctions` - Loads functions (note: see limitations below)
   - `Remove-TestEnvironment` - Cleans up test folders
   - `New-MockSettingsFile` - Creates mock configuration files

2. **AutopilotGraphMocks.psm1** - Graph API mocking
   - Mock data management (Add-MockUser, Add-MockGroup)
   - Graph API simulation (Invoke-MockGraphAPI)
   - Test environment initialization for directory object tests

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
| GetEntraDirectoryObject.Tests.ps1 | Graph API Mocking | AutopilotGraphMocks | ✅ Exemplary |
| ShowDirectoryObjectList.Tests.ps1 | Custom Mocks | None | ✅ Appropriate for menu testing |
| ResolveDirectoryObject.Tests.ps1 | Graph API Mocking | AutopilotGraphMocks | ✅ Integration test |
| MenuInclusions.Tests.ps1 | Direct Loading | None | ✅ Appropriate for menu logic |

### Tests with Acceptable Deviations

| Test | Reason | Status |
|------|--------|--------|
| Syntax.Tests.ps1 | No state, no I/O | ✅ Acceptable |
| FunctionLoading.Tests.ps1 | Tests loading itself | ✅ Acceptable |
| DomainConfiguration.Tests.ps1 | Self-contained | ✅ Acceptable |

## Summary

**Key Principles:**

1. **Use helpers when you need them** - temp files, cleanup, complex mocking
2. **Direct dot-sourcing is preferred** for loading functions to test
3. **Document deviations** from the template pattern
4. **Prioritize test reliability** over strict template adherence
5. **All tests must pass** - 100% success rate is mandatory

**When in Doubt:**
- Start with direct dot-sourcing in BeforeAll
- Add helpers only when needed for specific features
- Document your approach in .NOTES section
- Ensure test cleanup happens in AfterAll
