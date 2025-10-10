# Pester Migration Quick Start Guide

**Quick Reference for Starting the Migration**

This document provides a condensed quick-start guide for beginning the Pester migration. For full details, see [PESTER_MIGRATION_PLAN.md](./PESTER_MIGRATION_PLAN.md).

---

## Prerequisites

✅ PowerShell 5.1 or later  
✅ Pester 5.7.1 installed (verify: `Get-Module -ListAvailable Pester`)  
✅ All current tests passing  
✅ Git repository with clean working directory  
✅ Migration branch created

---

## Quick Start Steps

### 1. Create Infrastructure (Phase 0 - Day 1)

```powershell
# Create directory structure
New-Item -Path ".\tests\Unit", ".\tests\Integration", ".\tests\Helpers" -ItemType Directory -Force

# Verify Pester
Get-Module -ListAvailable Pester  # Should show v5.7.1

# Ready to add migration files
```

### 2. Add Required Files (Phase 0 - Day 1)

Create these three essential files (copy from PESTER_MIGRATION_PLAN.md Phase 0):

1. **`PesterConfiguration.ps1`** - Configuration function
2. **`tests/Helpers/AutopilotTestHelpers.psm1`** - Helper functions  
3. **`Invoke-PesterTests.ps1`** - Test runner

```powershell
# Verify setup
. .\PesterConfiguration.ps1
Get-Command Get-AutopilotPesterConfiguration  # Should return function

Import-Module ".\tests\Helpers\AutopilotTestHelpers.psm1" -Force
Get-Command Initialize-AutopilotTestEnvironment  # Should return function

Get-Help .\Invoke-PesterTests.ps1  # Should show help
```

**Commit:** `git commit -m "Phase 0: Setup Pester infrastructure"`

### 3. First Test Migration (Phase 1 - Day 2)

**Migrate test-syntax.ps1:**

```powershell
# Create tests/Unit/Syntax.Tests.ps1
# Copy template from PESTER_MIGRATION_PLAN.md Phase 1

# Run both tests to compare
.\TestScripts\test-syntax.ps1
$legacyExit = $LASTEXITCODE

.\Invoke-PesterTests.ps1 -TestType Unit -Tags 'Syntax'
# Should have similar pass/fail results
```

**Commit:** `git commit -m "Migrate test-syntax.ps1 to Pester"`

### 4. Continue with Pilot Tests (Phase 1 - Days 3-5)

Migrate these simple tests in order:
1. ✅ test-syntax.ps1
2. test-simple-function-loading.ps1
3. test-function-loading-validation.ps1
4. test-get-user-strong-mapping-simple.ps1
5. test-domain-config-simple.ps1

**Commit after each test migration**

### 5. Validate Pilot (Phase 1 - Day 5)

```powershell
# Run all pilot Pester tests
.\Invoke-PesterTests.ps1 -TestType Unit

# Should see all pilot tests passing
# Review with team before proceeding to Phase 2
```

---

## Migration Workflow (Repeat for Each Test)

```
1. Read legacy test → Understand logic
2. Create Pester test → Copy template structure
3. Convert patterns:
   - Write-TestSection → Context
   - Write-TestResult → Should
   - Manual mocks → Mock keyword
   - exit statements → Remove
4. Run both tests → Compare results
5. If match → Commit + Archive legacy
6. If mismatch → Debug and fix
```

---

## Key Conversion Patterns

| Legacy | Pester |
|--------|--------|
| `Write-Host "[PASS]"` | `$result | Should -Be $expected` |
| `Write-TestSection "Title"` | `Context "Title" { }` |
| `Write-TestResult "Msg" -Success $bool` | `$result | Should -Be $true` |
| `exit 0` | Remove (Pester handles) |
| `function Override { }` | `Mock FunctionName { }` |
| `Load-AllFunctions` | `Import-AutopilotFunctions` |

---

## Testing Your Migration

```powershell
# Quick unit tests only
.\Invoke-PesterTests.ps1 -TestType Unit

# All Pester tests
.\Invoke-PesterTests.ps1 -TestType All

# With code coverage
.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage

# Compare with legacy
.\TestScripts\Test-Runner.ps1 -TestCategory syntax
.\Invoke-PesterTests.ps1 -TestType Unit -Tags 'Syntax'
```

---

## Migration Progress Tracking

```powershell
# Count migrated tests
$pesterTests = (Get-ChildItem ".\tests\**\*.Tests.ps1" -Recurse).Count
$legacyTests = (Get-ChildItem ".\TestScripts\test-*.ps1").Count
$archivedTests = (Get-ChildItem ".\TestScripts\archived\test-*.ps1").Count

Write-Host "Migrated: $pesterTests"
Write-Host "Legacy: $legacyTests"
Write-Host "Archived: $archivedTests"
Write-Host "Progress: $([math]::Round(($pesterTests / 101) * 100, 1))%"
```

---

## When to Pause and Review

Stop and review with team after:
- ✅ Phase 0 complete (infrastructure setup)
- ✅ Phase 1 complete (pilot tests, ~10 tests)
- ✅ Phase 2 complete (unit tests, ~35 tests)
- ✅ Each integration test migration (Phase 3)
- ⚠️ Any test failure that can't be resolved quickly
- ⚠️ Performance degradation >20%

---

## Common Issues & Solutions

**Issue:** "Pester module not found"
```powershell
Install-Module -Name Pester -MinimumVersion 5.7.1 -Force -SkipPublisherCheck
```

**Issue:** "Function not found in test"
```powershell
# Verify imports in test:
BeforeAll {
    $script:TestContext = Initialize-AutopilotTestEnvironment
    Import-AutopilotFunctions -RootPath $script:TestContext.RootPath
}
```

**Issue:** "Mock not working"
```powershell
# Ensure Mock is in BeforeAll or BeforeEach
BeforeAll {
    Mock Get-Function { return "mocked" }
}
```

**Issue:** "Test hangs"
```powershell
# Add -Skip for long tests
It "Long test" -Skip:$($env:SKIP_SLOW_TESTS -eq 'true') {
    # test code
}
```

---

## Rollback Procedure

If major issues arise:

```powershell
# Rollback single test
Copy-Item ".\TestScripts\archived\test-example.ps1" ".\TestScripts\" -Force

# Rollback phase
git revert HEAD~5  # Last 5 commits

# Complete rollback
git checkout main
git branch -D copilot/create-migration-plan-to-pester
```

---

## Phase Checklist

### Phase 0: Setup (Week 1)
- [ ] Directory structure created
- [ ] PesterConfiguration.ps1 created
- [ ] AutopilotTestHelpers.psm1 created
- [ ] Invoke-PesterTests.ps1 created
- [ ] Infrastructure validated
- [ ] Committed to branch

### Phase 1: Pilot (Week 2)
- [ ] test-syntax.ps1 migrated
- [ ] test-simple-function-loading.ps1 migrated
- [ ] test-function-loading-validation.ps1 migrated
- [ ] 3+ additional simple tests migrated
- [ ] All pilot tests passing
- [ ] Team review completed

### Phase 2: Unit Tests (Weeks 3-4)
- [ ] 35+ unit tests migrated
- [ ] Code coverage >60%
- [ ] All tests passing
- [ ] Patterns documented

### Phase 3: Integration (Weeks 5-6)
- [ ] 12+ integration tests migrated
- [ ] Complex mocking working
- [ ] End-to-end workflows validated

### Phase 4: Selective (Weeks 7-8)
- [ ] High-value comprehensive tests migrated
- [ ] Low-value tests documented as "keep legacy"
- [ ] Performance tests remain in legacy

### Phase 5: Finalization (Week 9)
- [ ] Unified test runner created
- [ ] CI/CD integrated
- [ ] Documentation updated
- [ ] Migration summary created

---

## Resources

- **Full Plan:** [PESTER_MIGRATION_PLAN.md](./PESTER_MIGRATION_PLAN.md)
- **Pester Docs:** https://pester.dev/docs/quick-start
- **Current Tests:** `TestScripts/test-*.ps1`
- **New Tests:** `tests/**/*.Tests.ps1`
- **Helper Module:** `tests/Helpers/AutopilotTestHelpers.psm1`

---

## Quick Commands Reference

```powershell
# Run tests
.\Invoke-PesterTests.ps1 -TestType Unit
.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage
.\TestScripts\Test-Runner.ps1 -TestCategory syntax

# Check status
Get-Module -ListAvailable Pester
Get-ChildItem ".\tests\**\*.Tests.ps1" -Recurse
Get-Help .\Invoke-PesterTests.ps1

# Archive migrated test
Move-Item ".\TestScripts\test-example.ps1" ".\TestScripts\archived\"

# Commit
git add .
git commit -m "Migrate test-example.ps1 to Pester"
git push
```

---

## Success Indicators

✅ Pester tests pass consistently  
✅ Code coverage reports generate  
✅ Test execution time comparable to legacy  
✅ Team comfortable writing Pester tests  
✅ CI/CD pipeline runs tests automatically  
✅ >60% of high-value tests migrated

---

**Start Here:** Phase 0, then Phase 1  
**Get Help:** Review full PESTER_MIGRATION_PLAN.md  
**Questions:** Check AI Agent Implementation Guide section
