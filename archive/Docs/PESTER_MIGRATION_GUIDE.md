# Pester Migration Guide

**Version:** 2.0 (Consolidated)  
**Updated:** October 14, 2025  
**Purpose:** Complete guide for Pester test development and migration  
**Audience:** Developers, AI agents, contributors

---

## Quick Reference

### Essential Commands

| Task | Command | Time |
|------|---------|------|
| Run all tests | `.\Invoke-PesterTests.ps1 -TestType All` | 2-3s |
| Run single test | `.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"` | <1s |
| Run with coverage | `.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage` | 5-10s |
| Validate PS 5.1 | `powershell.exe -File .\Invoke-PesterTests.ps1 -TestType All` | 3-5s |
| Run all (legacy + Pester) | `.\Invoke-AllTests.ps1` | Variable |

### Project Structure

```
tests/
├── Unit/                      # Unit tests (isolated function testing)
├── Integration/               # Integration tests (multi-component)
├── Comprehensive/             # End-to-end scenarios
├── Helpers/
│   ├── AutopilotTestHelpers.psm1       # Core utilities (Layer 1)
│   ├── AutopilotGraphMocks.psm1        # Graph API mocking (Layer 2a)
│   └── AutopilotMenuMocks.psm1         # Menu system mocking (Layer 2b)
└── Template.Tests.ps1         # Copy this for new tests
```

---

## Core Principles (CRITICAL)

### 1. Improve Helpers, NOT Workarounds

**🚫 WRONG - Creating workaround in test:**
```powershell
It "Should create settings file" {
    # Manual .psd1 creation in test
    $content = "@{`n"
    foreach ($key in $settings.Keys) {
        $content += "    $key = '$($settings[$key])'`n"
    }
    $content += "}`n"
    Set-Content -Path $file -Value $content
    # ... test code
}
```

**✅ RIGHT - Enhancing helper:**
```powershell
# In AutopilotTestHelpers.psm1
function New-MockSettingsFile {
    param(
        [ValidateSet('json', 'psd1')]
        [string]$FileFormat = 'json'
    )
    # Handles both formats correctly
}

# In test file - simple, reusable
It "Should create settings file" {
    $file = New-MockSettingsFile -FileFormat 'psd1' -Settings $settings
    # ... test code
}
```

**Enhancement Process:**
1. Identify the testing need
2. Check if other tests will benefit (usually yes)
3. Design the helper enhancement
4. Add to appropriate helper module
5. Document with comment-based help
6. Update this guide with new patterns
7. Use in your test

### 2. Direct Dot-Sourcing (PowerShell 5.1 Compatible)

**🚫 WRONG - Module-based loading (unreliable in PS 5.1):**
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1"
    Import-AutopilotFunctions  # Functions not available in test scope!
}
```

**✅ RIGHT - Direct dot-sourcing:**
```powershell
BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Dot-source functions directly (ONLY reliable method)
    $functionsPath = Join-Path $script:RepoRoot "functions"
    Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}
```

**Why:** PowerShell 5.1 + Pester 5.x scoping limitations prevent module functions from dot-sourcing into test scope. Direct dot-sourcing in BeforeAll is the ONLY pattern that works reliably.

### 3. Always Clean Up (AfterAll Required)

**✅ Mandatory cleanup pattern:**
```powershell
Describe "My Tests" {
    BeforeAll {
        # Setup
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Initialize-GraphMockEnvironment -ClearCache
        Initialize-MenuTestEnvironment -AppMode "admin"
    }
    
    AfterAll {
        # Cleanup (REQUIRED - don't skip!)
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
        Clear-MenuTestEnvironment
    }
    
    It "Tests something" { ... }
}
```

### 4. Maintain 100% Pass Rate

**🚫 NEVER commit failing tests**

**If test reveals a bug:**
1. Fix the bug first, OR
2. Mark test as pending and file issue:
   ```powershell
   It "Should work when bug fixed" -Skip {
       # Test code
   } # Issue #123: Bug in feature X
   ```

### 5. Cross-Version Compatibility

**Use Sort-Object for deterministic results:**
```powershell
# ❌ Unreliable (order varies by PS version)
$results = Get-GraphData | Select-Object -Property Name, Id

# ✅ Reliable (consistent order across versions)
$results = Get-GraphData | Sort-Object -Property Name | Select-Object -Property Name, Id
```

**Avoid [ordered] hashtables:**
```powershell
# ❌ OrderedDictionary (can't clone, PS version issues)
$settings = [ordered]@{ Key = "Value" }

# ✅ Regular hashtable (works everywhere)
$settings = @{ Key = "Value" }
```

---

## Helper Module Architecture

### Three-Tiered Design

**Layer 1: AutopilotTestHelpers.psm1 (Core Infrastructure)**
- Temporary folder creation/cleanup
- Settings file generation (.json, .psd1)
- Authentication token mocking
- Global variable initialization
- Common test utilities

**Layer 2a: AutopilotGraphMocks.psm1 (Microsoft Graph API)**
- Mock Graph API environment
- User/device/group/profile entities
- API operation simulation (GET/POST/PATCH/DELETE)
- Search and query mocking
- Bulk data generation

**Layer 2b: AutopilotMenuMocks.psm1 (Menu System)**
- Menu structure mocking
- User interaction simulation
- Navigation command testing
- Menu state management
- App mode behavior testing

### When to Use Which Helper

| Need | Helper Module | Key Functions |
|------|---------------|---------------|
| Temp folders/files | AutopilotTestHelpers | Initialize-AutopilotTestEnvironment, New-MockSettingsFile |
| Settings files (.psd1) | AutopilotTestHelpers | New-MockSettingsFile -FileFormat 'psd1' |
| Write-Log mocking | AutopilotTestHelpers | New-MockWriteLog |
| Global variables | AutopilotTestHelpers | Initialize-MockGlobalVariables |
| User/Group API | AutopilotGraphMocks | Add-MockUser, Add-MockGroup, Invoke-MockGraphAPI |
| Device/Profile API | AutopilotGraphMocks | Add-MockDevice, Add-MockAutopilotProfile |
| Menu structures | AutopilotMenuMocks | New-MockMenuStructure, Initialize-MenuTestEnvironment |
| Menu functions | AutopilotMenuMocks | New-MockNewMenuFunction, New-MockShowMenuFunction |

---

## Test Creation Patterns

### Pattern 1: Simple Unit Test (No Helpers)

```powershell
<#
.SYNOPSIS
    Tests for simple utility function
.NOTES
    Test Category: Unit
    Template Compliance: Partial - No helpers needed
    Reason: Simple pure function, no I/O or state
#>

Describe "Simple Utility" -Tags 'Unit', 'Fast' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        . (Join-Path $script:RepoRoot "functions/utilities/SimpleFunction.ps1")
    }
    
    It "Should return expected value" {
        $result = SimpleFunction -Input "test"
        $result | Should -Be "expected"
    }
}
```

### Pattern 2: Unit Test with File Operations

```powershell
<#
.SYNOPSIS
    Tests for file-based operations
.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "File Operations" -Tags 'Unit' {
    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $TestContext.RootPath
        
        # Load functions
        . (Join-Path $script:RepoRoot "functions/fileOps/FileFunction.ps1")
        
        # Create test file
        $script:testFile = New-MockSettingsFile -FileFormat 'psd1' -Settings @{
            key = "value"
        }
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    It "Should process file correctly" {
        $result = Process-File -Path $script:testFile
        $result | Should -Not -BeNullOrEmpty
    }
}
```

### Pattern 3: Unit Test with Graph API

```powershell
<#
.SYNOPSIS
    Tests for directory object operations
.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotGraphMocks
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Directory Object Functions" -Tags 'Unit', 'GraphAPI' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Load function to test
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-EntraDirectoryObject.ps1")
        
        # Initialize Graph mocking
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add custom test data if needed
        Add-MockUser -UserPrincipalName "custom@contoso.com" `
            -DisplayName "Custom User" `
            -Id "user-custom"
        
        # Mock CallGraphAPI globally
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel)
            return Invoke-MockGraphAPI -accessToken $accessToken `
                -ResourcePath $ResourcePath `
                -Filter $Filter `
                -ExtraParameters $ExtraParameters `
                -consistencyLevel:$consistencyLevel
        }
        
        # Get mock token
        $script:token = New-MockAuthToken
    }
    
    AfterAll {
        Clear-GraphMockEnvironment
    }
    
    Context "User search" {
        It "Should find existing user" {
            $result = Get-EntraDirectoryObject -EntityName "john.doe@contoso.com" `
                -AccessToken $script:token `
                -EntityType "User"
            
            $result[0].userPrincipalName | Should -Be "john.doe@contoso.com"
            $result[1] | Should -Be $false  # Not fuzzy match
        }
    }
}
```

### Pattern 4: Integration Test with Menu System

```powershell
<#
.SYNOPSIS
    Tests for menu filtering and display
.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotMenuMocks
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotMenuMocks.psm1" -Force

Describe "Menu Integration" -Tags 'Integration', 'Menu' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Initialize menu environment
        Initialize-MenuTestEnvironment -AppMode "helpdesk"
        
        # Create menu structure
        $script:testMenus = New-MockMenuStructure -IncludeNestedMenus -IncludeActions
        
        # Load functions
        . (Join-Path $script:RepoRoot "functions/menuFunctions/Get-MenuItemsToShow.ps1")
    }
    
    AfterAll {
        Clear-MenuTestEnvironment
    }
    
    It "Should filter menus by app mode" {
        $filtered = Get-MenuItemsToShow -menus $script:testMenus -settings $Global:settings
        $filtered.Count | Should -BeGreaterThan 0
    }
}
```

### Pattern 5: Data-Driven Tests

```powershell
Context "Input validation" {
    It "Should validate <InputType> correctly" -TestCases @(
        @{ InputType = "Email"; Input = "test@contoso.com"; Expected = $true }
        @{ InputType = "Empty"; Input = ""; Expected = $false }
        @{ InputType = "Null"; Input = $null; Expected = $false }
        @{ InputType = "Whitespace"; Input = "   "; Expected = $false }
    ) {
        param($InputType, $Input, $Expected)
        
        $result = Validate-Input -Value $Input
        $result | Should -Be $Expected
    }
}
```

---

## Test Migration Workflow

### Step 1: Analyze Legacy Test
1. Read the legacy test file in `TestScripts/`
2. Identify what functions are being tested
3. Determine test scenarios and expected outcomes
4. Assess helper module needs

### Step 2: Determine Test Category

| Category | Characteristics | Location |
|----------|----------------|----------|
| Unit | Single function, isolated, fast | `tests/Unit/` |
| Integration | Multiple components, workflows | `tests/Integration/` |
| Comprehensive | End-to-end scenarios, complex | `tests/Comprehensive/` |

### Step 3: Create Pester Test File

**Use this template structure:**
```powershell
<#
.SYNOPSIS
    Tests for [Feature Name]

.DESCRIPTION
    [Description of what this tests]
    Converted from TestScripts/[legacy-test-name.ps1]

.NOTES
    Test Category: Unit|Integration|Comprehensive
    Template Compliance: Full|Partial
    Uses: [List helper modules used, or "None" if no helpers]
    Migration Notes: [Any special considerations]
#>

# Import needed helpers (if any)
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "[Feature Name]" -Tags '[Category]', '[Feature]' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Dot-source functions (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }
        
        # Initialize helpers (if needed)
        $script:TestContext = Initialize-AutopilotTestEnvironment
    }
    
    AfterAll {
        # Cleanup (if using helpers)
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "[Scenario Group]" {
        
        It "Should [specific behavior]" {
            # Arrange
            $input = "test value"
            
            # Act
            $result = Test-Function -Input $input
            
            # Assert
            $result | Should -Be "expected value"
        }
    }
}
```

### Step 4: Convert Test Logic

**Legacy to Pester conversion:**

| Legacy Pattern | Pester Pattern |
|----------------|----------------|
| `Write-Host "[PASS]"` | `$result \| Should -Be $expected` |
| `Write-Host "[FAIL]"` | Pester handles failures automatically |
| `exit 0` / `exit 1` | Not needed (Pester manages exit codes) |
| Manual counters | Pester aggregates automatically |
| `foreach` with tracking | `-TestCases` for data-driven tests |

### Step 5: Validate Conversion

```powershell
# Run new Pester test
.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"
# Verify: 0 failures expected

# Test on both PowerShell versions
powershell.exe -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"
pwsh.exe -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"
# Results should be identical
```

### Step 6: Archive Legacy Test

```powershell
# Move legacy test to archive
Move-Item "TestScripts\test-original.ps1" "TestScripts\archived\"
```

---

## Helper Module Usage

### AutopilotTestHelpers (Layer 1)

**Core infrastructure for all tests**

**Initialize-AutopilotTestEnvironment**
```powershell
# Creates temp folders with automatic cleanup tracking
$script:TestContext = Initialize-AutopilotTestEnvironment
# Returns: @{ RootPath, TempPath, CreatedFolders, CreatedFiles }
```

**New-MockSettingsFile**
```powershell
# Create .psd1 file
$psd1Path = New-MockSettingsFile -FileFormat 'psd1' -Settings @{
    appMode = "admin"
    domain = "contoso.com"
}

# Create .json file  
$jsonPath = New-MockSettingsFile -FileFormat 'json' -Settings @{
    setting1 = "value1"
}
```

**Initialize-MockGlobalVariables**
```powershell
# Set up $LogFile, $settings globals for tests
Initialize-MockGlobalVariables -Settings @{ appMode = "helpdesk" }
```

**Remove-TestEnvironment**
```powershell
# Cleanup temp folders and files (REQUIRED in AfterAll)
Remove-TestEnvironment -TestContext $script:TestContext
```

### AutopilotGraphMocks (Layer 2a)

**Microsoft Graph API simulation**

**Initialize-GraphMockEnvironment**
```powershell
# Set up mock data store (call once in BeforeAll)
Initialize-GraphMockEnvironment -ClearCache
```

**Add-MockUser**
```powershell
# Add custom test user
Add-MockUser -UserPrincipalName "john.doe@contoso.com" `
    -DisplayName "John Doe" `
    -Id "user-001" `
    -CustomProperties @{
        givenName = "John"
        surname = "Doe"
        department = "IT"
    }
```

**Add-MockGroup**
```powershell
# Add custom test group
Add-MockGroup -DisplayName "IT Admins" `
    -Id "group-001" `
    -CustomProperties @{
        mailNickname = "itadmins"
        groupTypes = @("Unified")
    }
```

**Invoke-MockGraphAPI**
```powershell
# Mock CallGraphAPI function globally
function global:CallGraphAPI {
    param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel)
    return Invoke-MockGraphAPI -accessToken $accessToken `
        -ResourcePath $ResourcePath `
        -Filter $Filter `
        -ExtraParameters $ExtraParameters `
        -consistencyLevel:$consistencyLevel
}
```

**Default Mock Data Available:**
- **Users:** jane.smith@, jane.test@, john.admin@, john.doe@, john.johnson@
- **Groups:** Archive Marketing, Disabled Group, Marketing Support, Marketing Team, Sales Team
- **Devices:** device-001, device-002 (sample structure)
- **Profiles:** profile-001, profile-002 (sample structure)

### AutopilotMenuMocks (Layer 2b)

**Menu system behavior simulation**

**Initialize-MenuTestEnvironment**
```powershell
# Set up menu globals ($MenuHistory, $History, $settings, $returnValues)
Initialize-MenuTestEnvironment -AppMode "helpdesk"
```

**New-MockMenuStructure**
```powershell
# Create realistic menu hierarchy
$menus = New-MockMenuStructure -IncludeNestedMenus -IncludeActions -IncludeSubmenus
```

**New-MockShowMenuFunction**
```powershell
# Mock Show-Menu with configurable responses
New-MockShowMenuFunction

# Set what Show-Menu should return
Set-MockShowMenuResponse -Response "UserSelection"

# Get call history for assertions
$calls = Get-MockShowMenuCalls
$calls.CallCount | Should -Be 1
```

---

## Technical Lessons Learned

### PowerShell 5.1 Scoping Issues

**Problem:** Module-based Import-AutopilotFunctions doesn't reliably dot-source into caller scope  
**Solution:** Direct dot-sourcing in BeforeAll blocks

**Why this matters:** PowerShell 5.1 + Pester 5.x scoping behavior is complex; direct loading is the ONLY reliable method that works consistently across both PowerShell versions.

### Cross-Version Hashtable Ordering

**Problem:** PS 5.1 hashtables are unordered (non-deterministic), PS 7+ are ordered by default  
**Solution:** Use Sort-Object on collections for deterministic results

**Example:**
```powershell
# ❌ Unreliable (order varies by PS version)
$results = Get-GraphData | Select-Object -Property Name, Id

# ✅ Reliable (consistent order across versions)  
$results = Get-GraphData | Sort-Object -Property Name | Select-Object -Property Name, Id
```

**Applies to:** All functions returning collections (users, devices, groups, etc.)

### [ordered] Hashtable Incompatibility

**Problem:** [ordered]@{} creates OrderedDictionary (lacks .Clone() method, version issues)  
**Solution:** Use regular hashtables @{}, apply Sort-Object when order matters

**Example:**
```powershell
# ❌ OrderedDictionary (can't clone, PS version issues)
$settings = [ordered]@{ Key = "Value" }
$copy = $settings.Clone()  # ERROR: Method not found

# ✅ Hashtable (can clone, works everywhere)
$settings = @{ Key = "Value" }  
$copy = $settings.Clone()  # Works fine
```

### Helper Enhancement Philosophy

**Core Principle:** "Improve helpers, not workarounds"

When you encounter a testing limitation:
1. ❌ **Don't:** Create a workaround in your individual test
2. ✅ **Do:** Enhance the appropriate helper module  
3. ✅ **Benefit:** All tests (current and future) gain the improvement
4. ✅ **Document:** Update this guide with the new capability

**Result:** Eliminated ~4,000 lines of duplicated code across tests

---

## Troubleshooting Guide

### Problem: Functions not available in test scope

**Symptoms:**
```
Get-EntraDirectoryObject : The term 'Get-EntraDirectoryObject' is not recognized...
```

**Cause:** Using module-based function loading  
**Solution:** Use direct dot-sourcing in BeforeAll

```powershell
BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $functionsPath = Join-Path $script:RepoRoot "functions"
    Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}
```

### Problem: Tests pass in PS 7+ but fail in PS 5.1

**Symptoms:**
```
Expected: john.doe@contoso.com
But was:  john.admin@contoso.com
```

**Cause:** Hashtable ordering differences  
**Solution:** Add `Sort-Object` to results that need deterministic order

```powershell
# In helper or test
$results = $data.Values | Where-Object { ... } | Sort-Object propertyName
```

### Problem: Test creates files but doesn't clean up

**Symptoms:** Temp folder fills with test artifacts  
**Solution:** Always use AfterAll cleanup with test helpers

```powershell
BeforeAll {
    $script:TestContext = Initialize-AutopilotTestEnvironment
}

AfterAll {
    Remove-TestEnvironment -TestContext $script:TestContext  # REQUIRED
}
```

### Problem: Mock data not matching expectations

**Symptoms:**
```
Expected: 3 matches
But was:  1 match
```

**Cause:** Missing mock data in helpers  
**Solution:** Add required mock data

```powershell
BeforeAll {
    Initialize-GraphMockEnvironment -ClearCache
    
    # Add missing data
    Add-MockUser -UserPrincipalName "needed@contoso.com" -DisplayName "Needed User" -Id "user-new"
}
```

### Problem: Helper doesn't support needed feature

**Symptoms:** Considering workaround in test file  
**Solution:** **STOP! Enhance the helper instead**

1. Pause test creation/migration
2. Add feature to appropriate helper module  
3. Document enhancement in helper
4. Update this guide with new pattern
5. Use enhanced helper in test

---

## Validation Checklist

Before committing a test, verify:

**File Structure:**
- [ ] Test file follows naming convention (`*.Tests.ps1`)
- [ ] Located in correct directory (`tests/Unit/`, `tests/Integration/`, `tests/Comprehensive/`)
- [ ] Has comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.NOTES`)

**Code Quality:**
- [ ] Uses direct dot-sourcing for function loading (PS 5.1 compatible)
- [ ] Imports only needed helper modules
- [ ] Has BeforeAll setup block
- [ ] Has AfterAll cleanup block (if using helpers)
- [ ] Uses `Should` assertions (not manual Write-Host)
- [ ] No exit codes in test (Pester manages this)
- [ ] Tagged appropriately (Unit/Integration/Comprehensive + feature tags)

**Testing:**
- [ ] Runs successfully: `.\Invoke-PesterTests.ps1 -TestFile "tests\...\MyTest.Tests.ps1"`
- [ ] **100% pass rate** (0 failures)
- [ ] Tested on PowerShell 7+: `pwsh.exe -File .\Invoke-PesterTests.ps1 -TestFile "..."`
- [ ] Tested on PowerShell 5.1: `powershell.exe -File .\Invoke-PesterTests.ps1 -TestFile "..."`
- [ ] Results identical between PS versions

**Migration Specific:**
- [ ] Legacy test archived (if migration): moved to `TestScripts\archived\`
- [ ] Documentation updated (if helper enhanced)
- [ ] New patterns documented in this guide

---

## Decision Tree

```
Need to create a test?
├─ Simple function, no I/O?
│  └─ Use Pattern 1 (No helpers)
│
├─ Need temp files or settings files?
│  └─ Use Pattern 2 (AutopilotTestHelpers)
│
├─ Need Graph API mocking (users, groups)?
│  └─ Use Pattern 3 (AutopilotGraphMocks)
│
├─ Need menu system testing?
│  └─ Use Pattern 4 (AutopilotMenuMocks)
│
└─ Multiple scenarios with same structure?
   └─ Use Pattern 5 (-TestCases)

Helper doesn't support what you need?
├─ NO: Use existing helper functions
└─ YES: Enhance helper first, then use it

Test failing?
├─ Bug in code? → Fix code first
├─ Bug in test? → Fix test
└─ Expected behavior? → Mark test with -Skip and file issue

Test passes in PS 7+ but fails in PS 5.1?
└─ Add Sort-Object for deterministic ordering

Multiple similar edits needed?
└─ Consider multi_replace_string_in_file for efficiency
```

---

## Example: Complete Test Migration

**Legacy test:** `TestScripts/test-get-user-strong-mapping.ps1` (26 test scenarios)

**Step 1: Analyze**
- Tests `Get-UserStrongMapping` function
- Needs Graph API mocking for user certificates
- Tests various scenarios: multiple certs, no certs, null certs, non-existent users
- Category: Unit test

**Step 2: Create test file**
File: `tests/Unit/GetUserStrongMapping.Tests.ps1`

```powershell
<#
.SYNOPSIS
    Tests for Get-UserStrongMapping function
.DESCRIPTION
    Validates strong authentication mapping detection
    Converted from TestScripts/test-get-user-strong-mapping.ps1
.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotGraphMocks
    Migration Notes: 26 scenarios from legacy test
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Get-UserStrongMapping Function" -Tags 'Unit', 'Authentication' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Load function
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-UserStrongMapping.ps1")
        
        # Initialize mocking
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add test users with certificates
        Add-MockUser -UserPrincipalName "user.with.certs@contoso.com" `
            -DisplayName "User With Certs" `
            -Id "user-001" `
            -CustomProperties @{
                certificateUserIds = @("cert1", "cert2")
            }
        
        Add-MockUser -UserPrincipalName "user.no.certs@contoso.com" `
            -DisplayName "User No Certs" `
            -Id "user-002" `
            -CustomProperties @{
                certificateUserIds = @()
            }
        
        # Mock CallGraphAPI
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel)
            return Invoke-MockGraphAPI -accessToken $accessToken `
                -ResourcePath $ResourcePath `
                -Filter $Filter `
                -ExtraParameters $ExtraParameters `
                -consistencyLevel:$consistencyLevel
        }
        
        $script:token = New-MockAuthToken
    }
    
    AfterAll {
        Clear-GraphMockEnvironment
    }
    
    Context "User with multiple certificates" {
        BeforeAll {
            $script:result = Get-UserStrongMapping -UserName "user.with.certs@contoso.com" -AccessToken $script:token
        }
        
        It "Should return StrongMapping as true" {
            $script:result.StrongMapping | Should -Be $true
        }
        
        It "Should preserve UserName" {
            $script:result.UserName | Should -Be "user.with.certs@contoso.com"
        }
        
        It "Should have CertificateCount of 2" {
            $script:result.CertificateCount | Should -Be 2
        }
    }
    
    Context "User with no certificates" {
        BeforeAll {
            $script:result = Get-UserStrongMapping -UserName "user.no.certs@contoso.com" -AccessToken $script:token
        }
        
        It "Should return StrongMapping as false" {
            $script:result.StrongMapping | Should -Be $false
        }
        
        It "Should have CertificateCount of 0" {
            $script:result.CertificateCount | Should -Be 0
        }
    }
    
    Context "Non-existent user" {
        BeforeAll {
            $script:result = Get-UserStrongMapping -UserName "nonexistent@contoso.com" -AccessToken $script:token
        }
        
        It "Should return StrongMapping as false" {
            $script:result.StrongMapping | Should -Be $false
        }
        
        It "Should have empty DisplayName" {
            $script:result.DisplayName | Should -BeNullOrEmpty
        }
    }
}
```

**Step 3: Validate**
```powershell
# Run new test
.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\GetUserStrongMapping.Tests.ps1"
# Result: All tests passing

# Validate on PS 5.1
powershell.exe -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\GetUserStrongMapping.Tests.ps1"
# Result: All tests passing (identical results)
```

**Step 4: Archive legacy test**
```powershell
Move-Item "TestScripts\test-get-user-strong-mapping.ps1" "TestScripts\archived\"
```

**Migration complete!**

---

## Summary

**Key Success Factors:**
1. ✅ **Improve helpers first** - Enhance infrastructure for everyone
2. ✅ **Direct dot-sourcing** - Only reliable pattern for PS 5.1
3. ✅ **Always clean up** - AfterAll blocks are mandatory
4. ✅ **100% pass rate** - Never commit failing tests
5. ✅ **Test both versions** - PS 5.1 and 7+ compatibility required
6. ✅ **Sort-Object for consistency** - Deterministic results across versions
7. ✅ **Use appropriate helpers** - Don't reinvent, reuse and enhance

**The "improve helpers" philosophy has been transformational** - it eliminated thousands of lines of duplicate code and created a robust, reusable testing infrastructure that accelerates all future test development.

---

**Questions?** 
- Reference the troubleshooting section for common issues
- Check existing tests in `tests/Unit/`, `tests/Integration/` for working examples
- Review helper modules in `tests/Helpers/` for available functions
- When in doubt, enhance helpers rather than creating workarounds

---

**Last Updated:** October 14, 2025  
**Document Status:** Consolidated from 11 migration documents  
**Test Infrastructure:** Fully operational and proven