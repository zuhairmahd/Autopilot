# Code Coverage Improvement Plan

**Document Version**: 1.0  
**Created**: October 14, 2025  
**Last Updated**: October 14, 2025  
**Current Coverage**: 12% (1,738 / 14,556 lines)  
**Target Coverage**: 65%+  
**Estimated Timeline**: 8 weeks

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Implementation Phases](#implementation-phases)
4. [Progress Tracking](#progress-tracking)
5. [Testing Guidelines](#testing-guidelines)
6. [Success Metrics](#success-metrics)

---

## Executive Summary

This document outlines a systematic approach to improve code coverage from 12% to 65%+ over 8 weeks. The strategy prioritizes:
1. Zero-coverage packages (quick wins)
2. Critical authentication and API functions
3. Expanding existing well-tested modules
4. Complex integration scenarios

---

## Current State Analysis

### Coverage by Package (Baseline - October 14, 2025)

| Package | Coverage | Lines Covered | Lines Missed | Priority |
|---------|----------|---------------|--------------|----------|
| **UserAndGroupFunctions** | 39.5% | 417 | 703 | P3 - Expand |
| **menuFunctions** | 20.2% | 239 | 912 | P3 - Expand |
| **setupFunctions** | 17.8% | 964 | 3,766 | P3 - Expand |
| **graphFunctions** | 2.3% | 53 | 2,617 | P2 - Critical |
| **utilityFunctions** | 3.6% | 44 | 1,216 | P2 - Critical |
| **reportingFunctions** | 1.8% | 21 | 1,024 | P4 - Complex |
| **autopilotFunctions** | 0% | 0 | 64 | P1 - Quick Win |
| **deviceFunctions** | 0% | 0 | 1,411 | P4 - Complex |
| **encryptionFunctions** | 0% | 0 | 804 | P1 - Quick Win |
| **updateFunctions** | 0% | 0 | 301 | P1 - Quick Win |

### Key Findings
- **5 packages at 0% coverage** - immediate attention required
- **UserAndGroupFunctions** shows best practices (39.5%) - use as template
- **graphFunctions** critical for application but only 2.3% covered
- **82% test migration complete** but coverage doesn't reflect it

---

## Implementation Phases

### Phase 1: Zero-Coverage Quick Wins (Weeks 1-2)
**Target**: Increase coverage from 12% to 25%  
**Focus**: Get all packages above 0% coverage

#### Week 1: Encryption Functions ✅ IN PROGRESS
**Status**: 🟡 In Progress  
**Owner**: TBD  
**Start Date**: October 14, 2025  
**Target Completion**: October 21, 2025

##### Deliverables
- [ ] `tests/Unit/encryptionFunctions/Get-DecryptedConfigValue.Tests.ps1`
  - Test successful decryption
  - Test invalid input handling
  - Test missing key scenarios
  - Test error propagation
  - **Estimated Lines Covered**: ~120 lines

- [ ] `tests/Unit/encryptionFunctions/Test-FileEncryptionStatus.Tests.ps1`
  - Test encrypted file detection
  - Test unencrypted file detection
  - Test missing file handling
  - Test various file formats
  - **Estimated Lines Covered**: ~80 lines

- [ ] `tests/Unit/encryptionFunctions/Get-AuthConfigValue.Tests.ps1`
  - Test value retrieval
  - Test missing value handling
  - Test type conversion
  - Test secure string handling
  - **Estimated Lines Covered**: ~60 lines

- [ ] `tests/Unit/encryptionFunctions/Get-SecurePassword.Tests.ps1`
  - Test password prompt
  - Test validation rules
  - Test secure storage
  - Test empty input handling
  - **Estimated Lines Covered**: ~80 lines

- [ ] `tests/Unit/encryptionFunctions/Clear-SecureMemory.Tests.ps1`
  - Test memory clearing
  - Test null handling
  - Test secure string cleanup
  - **Estimated Lines Covered**: ~40 lines

**Week 1 Target**: 380 lines / 804 total = **47% coverage** for encryptionFunctions

#### Week 2: Update & Autopilot Functions
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: October 21, 2025  
**Target Completion**: October 28, 2025

##### Deliverables
- [ ] `tests/Unit/updateFunctions/GetLatestGithubRelease.Tests.ps1`
  - Mock GitHub API calls
  - Test release parsing
  - Test version comparison
  - Test network error handling
  - **Estimated Lines Covered**: ~80 lines

- [ ] `tests/Unit/updateFunctions/getFileVersion.Tests.ps1`
  - Test version extraction from files
  - Test missing file handling
  - Test invalid format handling
  - **Estimated Lines Covered**: ~60 lines

- [ ] `tests/Unit/updateFunctions/Invoke-FileCertVerification.Tests.ps1`
  - Test certificate validation
  - Test unsigned files
  - Test expired certificates
  - Test trusted/untrusted publishers
  - **Estimated Lines Covered**: ~80 lines

- [ ] `tests/Unit/autopilotFunctions/GetDeviceInfo.Tests.ps1`
  - Mock WMI/CIM calls
  - Test device info retrieval
  - Test error handling
  - Test data formatting
  - **Estimated Lines Covered**: ~50 lines

**Week 2 Target**: 270 lines covered  
**Phase 1 Total Coverage**: **25%** (estimated)

---

### Phase 2: Critical Low-Coverage Functions (Weeks 3-4)
**Target**: Increase coverage from 25% to 40%  
**Focus**: Authentication, API, and utility functions

#### Week 3: Graph Functions - Authentication Core
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: October 28, 2025  
**Target Completion**: November 4, 2025

##### Deliverables
- [ ] `tests/Unit/graphFunctions/GetGraphAccessToken.Tests.ps1`
  - Expand existing tests
  - Test certificate authentication
  - Test client secret authentication
  - Test delegated authentication
  - Test token caching
  - Test token refresh
  - Test error scenarios
  - **Estimated Lines Covered**: +200 lines

- [ ] `tests/Unit/graphFunctions/HasScope.Tests.ps1`
  - Expand scope validation tests
  - Test scope hierarchy
  - Test missing scopes
  - Test scope combinations
  - **Estimated Lines Covered**: +150 lines

- [ ] `tests/Unit/graphFunctions/Test-ScopeAvailability.Tests.ps1`
  - Test scope checking logic
  - Test API scope validation
  - Test error handling
  - **Estimated Lines Covered**: +120 lines

**Week 3 Target**: +470 lines (graphFunctions to ~20% coverage)

#### Week 4: Graph Functions - API Core & Utilities
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: November 4, 2025  
**Target Completion**: November 11, 2025

##### Deliverables
- [ ] `tests/Unit/graphFunctions/CallGraphAPI.Tests.ps1`
  - Expand existing tests
  - Test GET/POST/PATCH/DELETE methods
  - Test pagination
  - Test error responses (400, 401, 403, 404, 429, 500)
  - Test retry logic
  - Test batching
  - **Estimated Lines Covered**: +250 lines

- [ ] `tests/Unit/utilityFunctions/Write-Log.Tests.ps1`
  - Test log levels (Debug, Info, Warning, Error)
  - Test file logging
  - Test console output
  - Test log rotation
  - Test concurrent logging
  - **Estimated Lines Covered**: +120 lines

- [ ] `tests/Unit/utilityFunctions/validateInput.Tests.ps1`
  - Test various validation rules
  - Test regex patterns
  - Test type validation
  - Test range validation
  - **Estimated Lines Covered**: +100 lines

**Week 4 Target**: +470 lines  
**Phase 2 Total Coverage**: **40%** (estimated)

---

### Phase 3: Expand Existing Good Coverage (Weeks 5-6)
**Target**: Increase coverage from 40% to 55%  
**Focus**: Build on successfully tested modules

#### Week 5: UserAndGroupFunctions Enhancement
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: November 11, 2025  
**Target Completion**: November 18, 2025

##### Deliverables
- [ ] Expand `tests/Unit/UserAndGroupFunctions/Get-EntraDirectoryObject.Tests.ps1`
  - Add edge cases (special characters, long names)
  - Test cache expiration scenarios
  - Test network failures
  - Test throttling responses
  - **Estimated Lines Covered**: +150 lines

- [ ] Expand `tests/Unit/UserAndGroupFunctions/Resolve-DirectoryObject.Tests.ps1`
  - Add complex navigation scenarios
  - Test all return value types
  - Test timeout scenarios
  - **Estimated Lines Covered**: +120 lines

- [ ] Create `tests/Integration/UserAndGroupFunctions/DirectoryObjectWorkflow.Tests.ps1`
  - Test end-to-end user lookup
  - Test end-to-end group lookup
  - Test fuzzy matching workflow
  - Test selection workflow
  - **Estimated Lines Covered**: +100 lines

**Week 5 Target**: +370 lines (UserAndGroupFunctions to ~70% coverage)

#### Week 6: Menu & Setup Functions Enhancement
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: November 18, 2025  
**Target Completion**: November 25, 2025

##### Deliverables
- [ ] Expand `tests/Unit/menuFunctions/ShowMenu.Tests.ps1`
  - Test various menu configurations
  - Test navigation paths
  - Test input validation
  - Test error recovery
  - **Estimated Lines Covered**: +200 lines

- [ ] Expand `tests/Unit/setupFunctions/Initialize-ApplicationConfiguration.Tests.ps1`
  - Test various config scenarios
  - Test migration paths
  - Test error handling
  - Test validation
  - **Estimated Lines Covered**: +250 lines

- [ ] Create `tests/Integration/setupFunctions/ConfigurationWorkflow.Tests.ps1`
  - Test complete initialization
  - Test settings merge
  - Test domain switching
  - **Estimated Lines Covered**: +150 lines

**Week 6 Target**: +600 lines  
**Phase 3 Total Coverage**: **55%** (estimated)

---

### Phase 4: Complex Integration Areas (Weeks 7-8)
**Target**: Increase coverage from 55% to 65%+  
**Focus**: Device operations and reporting

#### Week 7: Device Functions Foundation
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: November 25, 2025  
**Target Completion**: December 2, 2025

##### Deliverables
- [ ] `tests/Unit/deviceFunctions/GetDeviceIdFromSerial.Tests.ps1`
  - Mock Graph API device queries
  - Test serial number formats
  - Test error handling
  - **Estimated Lines Covered**: ~120 lines

- [ ] `tests/Unit/deviceFunctions/ProcessSerialNumber.Tests.ps1`
  - Test serial validation
  - Test device lookup
  - Test caching
  - **Estimated Lines Covered**: ~180 lines

- [ ] `tests/Unit/deviceFunctions/VerifyGroupMembership.Tests.ps1`
  - Test group membership checks
  - Test nested groups
  - Test cache usage
  - **Estimated Lines Covered**: ~150 lines

**Week 7 Target**: +450 lines (deviceFunctions to ~30% coverage)

#### Week 8: Reporting Functions
**Status**: ⚪ Not Started  
**Owner**: TBD  
**Start Date**: December 2, 2025  
**Target Completion**: December 9, 2025

##### Deliverables
- [ ] `tests/Unit/reportingFunctions/AssessDeviceState.Tests.ps1`
  - Test state assessment logic
  - Test various device states
  - Test error scenarios
  - **Estimated Lines Covered**: ~200 lines

- [ ] `tests/Unit/reportingFunctions/ExportDeviceList.Tests.ps1`
  - Test CSV export
  - Test data formatting
  - Test file operations
  - **Estimated Lines Covered**: ~150 lines

- [ ] `tests/Unit/reportingFunctions/ShowDeviceReport.Tests.ps1`
  - Test report generation
  - Test data aggregation
  - Test display formatting
  - **Estimated Lines Covered**: ~180 lines

**Week 8 Target**: +530 lines  
**Phase 4 Total Coverage**: **65%+** (estimated)

---

## Progress Tracking

### Weekly Progress Log

#### Week 1 (Oct 14-21, 2025) - Encryption Functions
**Status**: 🟡 In Progress  
**Started**: October 14, 2025  
**Completed Tests**:
- [x] Get-DecryptedConfigValue.Tests.ps1 - Created (24 test cases, 3 failures - needs fixes)
- [x] Test-FileEncryptionStatus.Tests.ps1 - Created (23 test cases, 3 failures - needs fixes)
- [x] Get-AuthConfigValue.Tests.ps1 - Created (26 test cases, all passing ✅)
- [x] Get-SecurePassword.Tests.ps1 - Created (20 test cases, 1 failure - needs fix)
- [x] Clear-SecureMemory.Tests.ps1 - Created (27 test cases, 17 failures - needs redesign)

**Lines Covered This Week**: TBD (waiting for test fixes)  
**Current Package Coverage**: 0% → Testing in progress  
**Overall Coverage**: 12% → Testing in progress

**Test Results**: 87 passing / 24 failing (78% pass rate)  
**Blockers**: 
- Clear-SecureMemory tests need to handle variable scope behavior properly
- Get-DecryptedConfigValue needs better error handling mocks
- Test-FileEncryptionStatus needs whitespace handling fixes
- Get-SecurePassword SecureString conversion test needs fix

**Notes**: 
- Created comprehensive test suite with 120 test cases covering 5 encryption functions
- Get-AuthConfigValue tests are 100% passing
- Most tests are passing, but need refinements for edge cases
- Tests follow Pester 5 best practices and PS 5.1 compatibility
- Next: Fix failing tests and measure actual coverage improvement

---

#### Week 2 (Oct 21-28, 2025) - Update & Autopilot Functions
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

#### Week 3 (Oct 28 - Nov 4, 2025) - Graph Auth Functions
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

#### Week 4 (Nov 4-11, 2025) - Graph API & Utilities
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

#### Week 5 (Nov 11-18, 2025) - UserAndGroup Enhancement
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

#### Week 6 (Nov 18-25, 2025) - Menu & Setup Enhancement
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

#### Week 7 (Nov 25 - Dec 2, 2025) - Device Functions
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

#### Week 8 (Dec 2-9, 2025) - Reporting Functions
**Status**: ⚪ Not Started  
**Completed Tests**: N/A  
**Lines Covered This Week**: N/A  
**Blockers**: N/A  
**Notes**: N/A

---

### Coverage Trend Chart

```
Week | Target | Actual | Delta | Status
-----|--------|--------|-------|--------
  0  |  12%   |  12%   |  +0%  | ✅ Baseline
  1  |  15%   |   -    |   -   | 🟡 In Progress
  2  |  25%   |   -    |   -   | ⚪ Pending
  3  |  30%   |   -    |   -   | ⚪ Pending
  4  |  40%   |   -    |   -   | ⚪ Pending
  5  |  47%   |   -    |   -   | ⚪ Pending
  6  |  55%   |   -    |   -   | ⚪ Pending
  7  |  60%   |   -    |   -   | ⚪ Pending
  8  |  65%   |   -    |   -   | ⚪ Pending
```

---

## Testing Guidelines

### For Developers

1. **Before Writing Tests**
   - Read `tests/AGENTS.md` for step-by-step guidance
   - Review `docs/TEST_TEMPLATE_GUIDELINES.md` for patterns
   - Check existing tests in same category for examples
   - Identify helper modules needed (TestHelpers, GraphMocks, MenuMocks)

2. **Test Structure**
   ```powershell
   Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
   
   Describe "Function: Your-Function" -Tags 'Unit' {
       BeforeAll {
           # Direct dot-sourcing for PS 5.1 compatibility
           $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
           . "$script:RepoRoot/functions/category/Your-Function.ps1"
       }
       
       Context "When testing normal operation" {
           It "Should perform expected behavior" {
               $result = Your-Function -Parameter "value"
               $result | Should -Be "Expected"
           }
       }
       
       Context "When testing error conditions" {
           It "Should handle invalid input" {
               { Your-Function -Parameter $null } | Should -Throw
           }
       }
   }
   ```

3. **Running Tests**
   ```powershell
   # Run specific test file
   .\Invoke-PesterTests.ps1 -TestType Unit -TestPath "tests/Unit/encryptionFunctions"
   
   # Run with coverage
   .\Invoke-PesterTests.ps1 -TestType Unit -EnableCodeCoverage
   
   # Run all tests
   .\Invoke-AllTests.ps1
   ```

4. **Quality Standards**
   - ✅ 100% pass rate required
   - ✅ Test on PowerShell 5.1 and 7+
   - ✅ Use Sort-Object for deterministic ordering
   - ✅ Document approach in `.NOTES` section
   - ✅ Handle cleanup in AfterEach/AfterAll blocks

### For AI Agents

1. **Planning Phase**
   - Review this document's deliverables for current week
   - Check `tests/AGENTS.md` Section 2 for test creation workflow
   - Identify the function to test in `functions/` directory
   - Review helper modules in `tests/Helpers/`

2. **Implementation Phase**
   - Use direct dot-sourcing pattern for function loading
   - Follow existing test patterns in `tests/Unit/` for same category
   - Implement all test cases listed in deliverables
   - Add edge cases and error scenarios

3. **Validation Phase**
   - Run tests: `.\Invoke-PesterTests.ps1 -TestType Unit`
   - Verify 100% pass rate
   - Check coverage increase in `coverage.xml`
   - Update progress tracking in this document

4. **Update Phase**
   - Mark deliverable as complete with ✅
   - Update "Lines Covered This Week"
   - Update "Current Package Coverage"
   - Update "Coverage Trend Chart"
   - Add notes about any blockers or insights

---

## Success Metrics

### Coverage Targets by Package (End of Week 8)

| Package | Baseline | Target | Increase |
|---------|----------|--------|----------|
| encryptionFunctions | 0% | 60% | +60% |
| updateFunctions | 0% | 75% | +75% |
| autopilotFunctions | 0% | 80% | +80% |
| graphFunctions | 2.3% | 50% | +47.7% |
| utilityFunctions | 3.6% | 45% | +41.4% |
| UserAndGroupFunctions | 39.5% | 70% | +30.5% |
| menuFunctions | 20.2% | 55% | +34.8% |
| setupFunctions | 17.8% | 50% | +32.2% |
| deviceFunctions | 0% | 30% | +30% |
| reportingFunctions | 1.8% | 35% | +33.2% |

### Key Performance Indicators

- **Overall Coverage**: 12% → 65%+ (target)
- **Test Execution Time**: Should remain under 5 seconds for unit tests
- **Pass Rate**: Maintain 100% throughout
- **Zero-Coverage Packages**: 5 → 0
- **Functions with Tests**: 34 → 120+ (estimated)

---

## Appendix

### Related Documents
- `tests/AGENTS.md` - AI-optimized test creation guide
- `docs/TEST_TEMPLATE_GUIDELINES.md` - Comprehensive test patterns
- `docs/PESTER_MIGRATION_README.md` - Migration documentation hub
- `docs/PESTER_MIGRATION_LESSONS_LEARNED.md` - Technical challenges & solutions
- `AGENTS.md` - Repository guidelines and architecture

### Helper Modules Reference
- `tests/Helpers/AutopilotTestHelpers.psm1` - Temp folders, settings, cleanup
- `tests/Helpers/AutopilotGraphMocks.psm1` - Graph API mocking
- `tests/Helpers/AutopilotMenuMocks.psm1` - Menu system mocking

### Commands Quick Reference
```powershell
# Run unit tests only
.\Invoke-PesterTests.ps1 -TestType Unit

# Run with coverage report
.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage

# Run complete test suite (Pester + legacy)
.\Invoke-AllTests.ps1

# Validate migration
.\tools\Validate-PesterMigration.ps1
```

---

**Document Maintenance**: Update this document at the end of each week with progress, blockers, and insights.
