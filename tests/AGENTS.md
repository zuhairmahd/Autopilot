# AI Agent Guide for Autopilot Testing

**Purpose:** AI-specific instructions for test migration and creation  
**Audience:** AI coding agents (GitHub Copilot, etc.)  
**Version:** 1.0  
**Updated:** October 10, 2025

---

## Quick Reference

### Common Tasks

| Task | Command | Time |
|------|---------|------|
| Run all tests | `.\Invoke-PesterTests.ps1 -TestType All` | 2-3s |
| Run single test | `.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\MyTest.Tests.ps1"` | <1s |
| Run with coverage | `.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage` | 5-10s |
| Validate PS 5.1 | `powershell.exe -File .\Invoke-PesterTests.ps1 -TestType All` | 3-5s |

### File Locations

```
tests/
├── Unit/                      # Unit tests (144 tests, 100% passing)
├── Integration/               # Integration tests (36 tests, 100% passing)
├── Comprehensive/             # Comprehensive tests (1 test, 14 passed, 4 skipped)
├── Helpers/
│   ├── AutopilotTestHelpers.psm1       # Layer 1: Core utilities
│   ├── AutopilotGraphMocks.psm1        # Layer 2a: Graph API mocking
│   └── AutopilotMenuMocks.psm1         # Layer 2b: Menu system mocking
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

**When to enhance helpers:**
- ❓ Need to create specific file formats? → Enhance `New-MockSettingsFile`
- ❓ Need new Graph API mocking? → Enhance `AutopilotGraphMocks.psm1`
- ❓ Need menu behavior simulation? → Enhance `AutopilotMenuMocks.psm1`
- ❓ Copying setup code from another test? → Extract to helper

**Process:**
1. Identify the need (what's missing?)
2. Check if other tests will benefit (usually yes)
3. Design the helper enhancement
4. Add to appropriate helper module (Layer 1, 2a, or 2b)
5. Document with comment-based help
6. Update TEST_TEMPLATE_GUIDELINES.md
7. Use in your test

---

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

---

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

**Why:** Prevents test pollution, disk space issues, and state leakage between test runs.

---

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

**Why:** Failing tests reduce confidence and create technical debt.

---

## Test Migration Workflow (Step-by-Step)

### Step 1: Analyze Legacy Test

**Read the legacy test file:**
```powershell
# Example: TestScripts/test-get-user-strong-mapping.ps1
```

**Identify:**
- What functions are being tested?
- What are the test scenarios?
- What helpers are needed? (temp files, Graph API, menu system)
- What's the expected outcome?

---

### Step 2: Determine Test Category

| Category | Characteristics | Location |
|----------|----------------|----------|
| Unit | Single function, isolated, fast | `tests/Unit/` |
| Integration | Multiple components, workflows | `tests/Integration/` |
| Comprehensive | End-to-end scenarios, complex | `tests/Comprehensive/` |

---

### Step 3: Choose Helper Modules

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

### Step 4: Create Pester Test File

**Template structure:**
```powershell
<#
.SYNOPSIS
    Tests for [Feature Name]

.DESCRIPTION
    Converted from TestScripts/[legacy-test-name.ps1]
    Tests [specific functionality]

.NOTES
    Test Category: Unit|Integration|Comprehensive
    Template Compliance: Full
    Uses: [List helper modules used]
#>

# Import needed helpers
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force  # If needed

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
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add mock data (if needed)
        Add-MockUser -UserPrincipalName "test@contoso.com" -DisplayName "Test User"
    }
    
    AfterAll {
        # Cleanup
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
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

---

### Step 5: Convert Test Logic

**Legacy pattern → Pester pattern:**

| Legacy | Pester |
|--------|--------|
| `Write-Host "[PASS] Test passed"` | `$result \| Should -Be $expected` |
| `Write-Host "[FAIL] Test failed"` | Pester handles failures automatically |
| `exit 0` / `exit 1` | Not needed (Pester manages exit codes) |
| `foreach` loop with manual tracking | `-TestCases` for data-driven tests |
| Manual `$passedTests++` | Pester aggregates automatically |

**Example conversion:**

**Legacy:**
```powershell
$testsPassed = 0
$testsTotal = 0

$testsTotal++
if ($result -eq "expected") {
    Write-Host "[PASS] Test 1 passed" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "[FAIL] Test 1 failed" -ForegroundColor Red
}

exit $(if ($testsPassed -eq $testsTotal) { 0 } else { 1 })
```

**Pester:**
```powershell
It "Should return expected value" {
    $result = Test-Function
    $result | Should -Be "expected"
}
```

---

### Step 6: Validate Conversion

**Run both tests and compare:**
```powershell
# Run legacy test
.\TestScripts\test-original.ps1
$legacyExitCode = $LASTEXITCODE

# Run Pester test
.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\Original.Tests.ps1"
# Check: 0 failures expected

# Results should match:
# - Legacy exit 0 = Pester 0 failures
# - Legacy exit 1 = Pester 1+ failures
```

---

### Step 7: Archive Legacy Test

**After validation:**
```powershell
# Move legacy test to archive
Move-Item "TestScripts\test-original.ps1" "TestScripts\archived\"

# Update TestRegistry if needed
# Remove entry from Test-Runner.ps1 test list
```

---

## Helper Module Usage Guide

### Layer 1: AutopilotTestHelpers (Core Infrastructure)

**When to use:** Every test that needs temp files, settings files, or common mocks.

**Key Functions:**

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
# Cleanup temp folders and files
Remove-TestEnvironment -TestContext $script:TestContext
```

---

### Layer 2a: AutopilotGraphMocks (Microsoft Graph API)

**When to use:** Tests that call Microsoft Graph API (users, groups, devices, profiles).

**Key Functions:**

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

**Clear-GraphMockEnvironment**
```powershell
# Cleanup (call in AfterAll)
Clear-GraphMockEnvironment
```

**Default Mock Data Available:**
- **Users:** jane.smith@, jane.test@, john.admin@, john.doe@, john.johnson@
- **Groups:** Archive Marketing, Disabled Group, Marketing Support, Marketing Team, Sales Team
- **Devices:** device-001, device-002 (sample structure)
- **Profiles:** profile-001, profile-002 (sample structure)

---

### Layer 2b: AutopilotMenuMocks (Menu System)

**When to use:** Tests that work with menu structures, Show-Menu, or New-Menu.

**Key Functions:**

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

**Clear-MenuTestEnvironment**
```powershell
# Cleanup (call in AfterAll)
Clear-MenuTestEnvironment
```

---

## Common Test Patterns (Copy-Paste Ready)

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

---

### Pattern 2: Unit Test with Temp Files

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

---

### Pattern 3: Unit Test with Graph API Mocking

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

---

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

---

### Pattern 5: Data-Driven Tests with -TestCases

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

## Troubleshooting Guide

### Problem: Functions not available in test scope

**Symptom:**
```
Get-EntraDirectoryObject : The term 'Get-EntraDirectoryObject' is not recognized...
```

**Cause:** Using module-based function loading (doesn't work in PS 5.1 + Pester 5.x)

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

---

### Problem: Tests pass in PS 7+ but fail in PS 5.1

**Symptom:**
```
Expected: john.doe@contoso.com
But was:  john.admin@contoso.com
```

**Cause:** Hashtable ordering differences (PS 5.1 = unordered, PS 7+ = ordered by default)

**Solution:** Add `Sort-Object` to results that need deterministic order
```powershell
# In helper or test
$results = $data.Values | Where-Object { ... } | Sort-Object propertyName
```

---

### Problem: Test creates files but doesn't clean up

**Symptom:** Temp folder fills with test artifacts

**Solution:** Always use AfterAll cleanup
```powershell
BeforeAll {
    $script:TestContext = Initialize-AutopilotTestEnvironment
}

AfterAll {
    Remove-TestEnvironment -TestContext $script:TestContext  # REQUIRED
}
```

---

### Problem: Mock data not matching test expectations

**Symptom:**
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

---

### Problem: Helper doesn't support needed feature

**Symptom:** Considering workaround in test file

**Solution:** **STOP! Enhance the helper instead**
1. Pause test migration
2. Add feature to appropriate helper module
3. Document enhancement
4. Use enhanced helper in test

**Example:**
```powershell
# BAD: Workaround in test
$psd1Content = "@{`n"
# ... manual file creation

# GOOD: Enhance helper
# Add to AutopilotTestHelpers.psm1
function New-MockSettingsFile {
    param([ValidateSet('json', 'psd1')][string]$FileFormat = 'json')
    # Now supports both formats
}
```

---

## Validation Checklist

Before committing a test, verify:

- [ ] Test file follows naming convention (`*.Tests.ps1`)
- [ ] Test has comment-based help (.SYNOPSIS, .DESCRIPTION, .NOTES)
- [ ] Uses direct dot-sourcing for function loading (PS 5.1 compatible)
- [ ] Imports only needed helper modules
- [ ] Has BeforeAll setup block
- [ ] Has AfterAll cleanup block (if using helpers)
- [ ] Uses `Should` assertions (not manual Write-Host)
- [ ] No exit codes in test (Pester manages this)
- [ ] Tagged appropriately (Unit/Integration/Comprehensive + feature tags)
- [ ] Runs successfully: `.\Invoke-PesterTests.ps1 -TestFile "tests\...\MyTest.Tests.ps1"`
- [ ] **100% pass rate** (0 failures)
- [ ] Tested on PowerShell 7+ (development)
- [ ] Tested on PowerShell 5.1 (compatibility): `powershell.exe -File .\Invoke-PesterTests.ps1 -TestFile "..."`
- [ ] Legacy test archived (if migration)
- [ ] Documentation updated (if helper enhanced)

---

## Quick Decision Tree

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
```

---

## Example: Complete Test Migration

**Legacy test:** `TestScripts/test-get-user-strong-mapping.ps1` (26 test scenarios)

**Step 1: Analyze**
- Tests `Get-UserStrongMapping` function
- Needs Graph API mocking for user certificates
- Tests various scenarios: multiple certs, no certs, null certs, non-existent users
- Category: Unit test

**Step 2: Choose helpers**
- Need: Graph API mocking
- Helper: AutopilotGraphMocks

**Step 3: Create test file**
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
        
        It "Should have 2 certificates in array" {
            $script:result.Certificates.Count | Should -Be 2
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
        
        It "Should have empty certificates array" {
            $script:result.Certificates.Count | Should -Be 0
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

**Step 4: Run and validate**
```powershell
# Run new test
.\Invoke-PesterTests.ps1 -TestFile "tests\Unit\GetUserStrongMapping.Tests.ps1"
# Result: 26/26 passing

# Validate on PS 5.1
powershell.exe -File .\Invoke-PesterTests.ps1 -TestFile "tests\Unit\GetUserStrongMapping.Tests.ps1"
# Result: 26/26 passing
```

**Step 5: Archive legacy test**
```powershell
Move-Item "TestScripts\test-get-user-strong-mapping.ps1" "TestScripts\archived\"
```

**Done! Migration complete for this test.**

---

## Summary

**Remember the core principles:**
1. ✅ **Improve helpers, not workarounds** - Enhance infrastructure for everyone
2. ✅ **Direct dot-sourcing** - Only reliable pattern for PS 5.1
3. ✅ **Always clean up** - AfterAll blocks are mandatory
4. ✅ **100% pass rate** - Never commit failing tests
5. ✅ **Test both versions** - PS 5.1 and 7+ compatibility required

**When in doubt:**
- Start with Template.Tests.ps1
- Use existing tests as examples
- Follow the patterns in this guide
- Check TEST_TEMPLATE_GUIDELINES.md for detailed explanations
- Review PESTER_MIGRATION_LESSONS_LEARNED.md for common issues

**For help:**
- See `docs/TEST_TEMPLATE_GUIDELINES.md` - Comprehensive guide
- See `docs/PESTER_MIGRATION_LESSONS_LEARNED.md` - Common issues and solutions
- See `docs/PESTER_MIGRATION_PROGRESS_UPDATED.md` - Current status
- See existing tests in `tests/Unit/` for working examples

---

**Current Status:** 155 tests migrated, 100% passing, PS 5.1 compatible ✅
