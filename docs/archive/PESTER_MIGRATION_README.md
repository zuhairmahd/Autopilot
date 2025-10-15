# Pester Migration Documentation Hub - SUPERSEDED

**⚠️ This document has been superseded by consolidated documentation:**

## New Authoritative Documents (October 14, 2025)

**Primary Documents:**
1. **[`PESTER_MIGRATION_GUIDE.md`](PESTER_MIGRATION_GUIDE.md)** - Complete technical guide
   - Comprehensive patterns and examples
   - Helper module usage
   - Step-by-step migration workflow
   - Troubleshooting guide
   - AI agent instructions

2. **[`PESTER_MIGRATION_STATUS.md`](PESTER_MIGRATION_STATUS.md)** - Current accurate status
   - Real test inventory (17 files, 197 tests)
   - Phase completion status
   - Performance metrics
   - Timeline and next actions

**Supporting Documents:**
- **[`PESTER_MIGRATION_COMPLETION_PLAN.md`](PESTER_MIGRATION_COMPLETION_PLAN.md)** - Detailed roadmap
- **[`PESTER_MIGRATION_LESSONS_LEARNED.md`](PESTER_MIGRATION_LESSONS_LEARNED.md)** - Technical insights

**Archived Documents:**
- Multiple contradictory files moved to `docs/archive/`
- See archive for historical reference

---

## Why This Consolidation Was Needed

**Problems Found:**
- 11+ migration documents with contradictory information
- Conflicting test counts (155/~190 vs 155/~250)
- Overlapping "progress", "status", and "summary" documents
- Outdated information throughout multiple files

**Solution Implemented:**
- Audited actual test status (17 Pester files, 197 individual tests)
- Consolidated accurate information into 2 primary documents
- Archived contradictory/redundant files
- Created single source of truth for migration status

---

**Use the new documents above for current information.**

**Last Updated:** October 14, 2025  
**Status:** Superseded by consolidated documentation

---

## Getting Started

### For Test Authors

**Writing a new test?** Start here:
1. Read [AI Agent Guide](../tests/AGENTS.md) → Quick Reference section
2. Choose your test type (Unit/Integration/Comprehensive)
3. Follow the step-by-step workflow in [AI Agent Guide](../tests/AGENTS.md)
4. Reference [Test Templates](TEST_TEMPLATE_GUIDELINES.md) for patterns
5. Run `.\Invoke-PesterTests.ps1 -TestType [Type]` to validate

**Key Principles:**
- ✅ **Improve helpers first** (don't create workarounds)
- ✅ **Direct dot-sourcing** (PS 5.1 compatibility)
- ✅ **100% pass rate** (never commit failing tests)
- ✅ **Test both versions** (PS 5.1 and 7+)
- ✅ **Use Sort-Object** for cross-version compatibility

---

### For AI Agents

**Primary Document:** [tests/AGENTS.md](../tests/AGENTS.md)

**Workflow Summary:**
1. Analyze legacy test → Identify test category
2. Choose helper modules → Create Pester file
3. Convert test logic → Validate pass
4. Test PS 5.1 and 7+ → Archive legacy test

**Helper Selection:**
- **Core:** AutopilotTestHelpers.psm1 (temp folders, cleanup)
- **Graph API:** AutopilotGraphMocks.psm1 (users, devices, groups, profiles)
- **Menu:** AutopilotMenuMocks.psm1 (menu navigation, user interactions)

**Common Patterns:** See [AI Agent Guide](../tests/AGENTS.md) → Section 5

---

### For Project Managers

**Current Status:** [Progress Report](PESTER_MIGRATION_PROGRESS_UPDATED.md)

**Key Metrics:**
- 155 tests migrated (82% complete)
- 100% pass rate maintained
- 10-15x performance improvement
- 37% code reduction (~4,000 lines)
- 35+ reusable helper functions

**Timeline:** [Completion Plan](PESTER_MIGRATION_COMPLETION_PLAN.md)
- Phase 3: 1 week remaining
- Phase 4: 4 weeks (Weeks 7-10)
- Phase 5: 2 weeks (Weeks 11-12)
- **Total: 6-8 weeks to completion**

**Risks:** Low - Migration ahead of schedule, infrastructure proven

---

### For Stakeholders

**Why Migrate?**
- **Performance:** 10-15x faster test execution (30-45s → 2-3s)
- **Maintainability:** 37% less code, consistent patterns
- **Quality:** 100% pass rate, better coverage
- **Modern Tooling:** Industry-standard framework, better CI/CD integration
- **Developer Experience:** Faster iteration, clearer feedback

**Business Value:**
- Reduced CI/CD pipeline time (faster deployments)
- Lower maintenance costs (less code to maintain)
- Improved quality confidence (comprehensive test coverage)
- Better onboarding (standardized patterns)

**Investment:** 12-16 weeks total effort
**ROI:** Ongoing maintenance savings, faster feature delivery

---

## Documentation Organization

### Strategic Documents (Big Picture)

**[PESTER_MIGRATION_PLAN.md](PESTER_MIGRATION_PLAN.md)**
- Original migration strategy (created Week 1)
- 6-phase approach rationale
- Risk assessment and mitigation
- Success criteria definition

**[PESTER_MIGRATION_COMPLETION_PLAN.md](PESTER_MIGRATION_COMPLETION_PLAN.md)**
- Detailed roadmap for remaining work
- Phase 3-5 task breakdown
- Helper enhancement plans
- Week-by-week timeline

**[PESTER_MIGRATION_PROGRESS_UPDATED.md](PESTER_MIGRATION_PROGRESS_UPDATED.md)**
- Current migration status
- Statistics and metrics dashboard
- Phase completion details
- Remaining work summary

---

### Technical Documents (How-To)

**[PESTER_MIGRATION_LESSONS_LEARNED.md](PESTER_MIGRATION_LESSONS_LEARNED.md)**
- Technical challenges and solutions
- PowerShell 5.1 scoping insights
- Hashtable ordering fix (Sort-Object)
- [ordered] hashtable failure analysis
- Helper enhancement examples

**[TEST_TEMPLATE_GUIDELINES.md](TEST_TEMPLATE_GUIDELINES.md)**
- Test patterns and structure
- Helper usage guidelines
- Cross-version compatibility section
- When to use which helpers
- Common pitfalls and solutions

**[../tests/AGENTS.md](../tests/AGENTS.md)**
- AI-specific step-by-step guide
- Copy-paste ready examples
- Decision trees and workflows
- Complete migration example
- Troubleshooting guide

---

### Supporting Documents

**[PESTER_MIGRATION_QUICK_START.md](PESTER_MIGRATION_QUICK_START.md)**
- Getting started guide
- Command reference
- Quick validation steps

**[PESTER_MIGRATION_SUMMARY.md](PESTER_MIGRATION_SUMMARY.md)**
- Executive summary
- Key achievements
- Benefits realized

**[MIGRATION_TEST_COVERAGE.md](MIGRATION_TEST_COVERAGE.md)**
- Test coverage analysis
- Gap identification
- Coverage improvements

---

## Running Tests

### Quick Commands

```powershell
# Run all Pester tests (fast - 2-3 seconds)
.\Invoke-PesterTests.ps1 -TestType All

# Run specific test type
.\Invoke-PesterTests.ps1 -TestType Unit
.\Invoke-PesterTests.ps1 -TestType Integration
.\Invoke-PesterTests.ps1 -TestType Comprehensive

# Run with code coverage
.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage

# Run complete test suite (Pester + legacy)
.\Invoke-AllTests.ps1

# Run legacy tests (being phased out)
.\TestScripts\Test-Runner.ps1 -TestCategory syntax
```

### Validation Workflow

**Before committing a new test:**

```powershell
# 1. Run your new test
.\Invoke-PesterTests.ps1 -TestType [Unit|Integration|Comprehensive]

# 2. Ensure 100% pass rate
# If any failures, fix before proceeding

# 3. Test on PowerShell 5.1
powershell.exe -File .\Invoke-PesterTests.ps1 -TestType [Type]

# 4. Test on PowerShell 7+
pwsh.exe -File .\Invoke-PesterTests.ps1 -TestType [Type]

# 5. Compare results (should be identical)

# 6. Commit test file
git add tests/[Category]/[TestName].Tests.ps1

# 7. Archive legacy test
git mv TestScripts/[LegacyTest].ps1 TestScripts/archived/
```

---

## Helper Modules

### Three-Tiered Architecture

**Layer 1: Core (AutopilotTestHelpers.psm1)**
- Temporary folder creation/cleanup
- Settings file generation (.json, .psd1)
- Authentication token mocking
- File/directory operations
- Timestamp testing helpers

**Layer 2a: Graph API (AutopilotGraphMocks.psm1)**
- Mock Graph API environment
- User/device/group/profile entities
- API operation mocking (GET/POST/PATCH/DELETE)
- Search and query simulation
- Bulk data generation

**Layer 2b: Menu System (AutopilotMenuMocks.psm1)**
- Menu structure mocking
- User interaction simulation
- Navigation command testing
- Menu state management

### Helper Enhancement Philosophy

**"Improve helpers, not workarounds"**

When encountering a testing need:
1. ❌ **Don't:** Create workaround in individual test
2. ✅ **Do:** Enhance helper module to support the need
3. ✅ **Benefit:** All tests gain the improvement
4. ✅ **Document:** Update TEST_TEMPLATE_GUIDELINES.md

**Impact:** Eliminated ~4,000 lines of code duplication

---

## Key Technical Lessons

### PowerShell 5.1 Scoping

**Problem:** Module-based Import-AutopilotFunctions doesn't reliably dot-source into caller scope  
**Solution:** Direct dot-sourcing in BeforeAll blocks

```powershell
BeforeAll {
    # ✅ Reliable pattern for PS 5.1
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    . "$script:RepoRoot/functions/[category]/[function].ps1"
}
```

**Why:** PowerShell 5.1 + Pester 5.x scoping behavior is complex; direct loading is ONLY reliable method.

---

### Cross-Version Hashtable Ordering

**Problem:** PS 5.1 hashtables unordered (non-deterministic), PS 7+ ordered by default  
**Solution:** Use Sort-Object on collections for deterministic results

```powershell
# ❌ Unreliable (order varies by PS version)
$results = Get-GraphData | Select-Object -Property Name, Id

# ✅ Reliable (consistent order across versions)
$results = Get-GraphData | Sort-Object -Property Name | Select-Object -Property Name, Id
```

**Applies to:** All functions returning collections (users, devices, groups, etc.)

---

### [ordered] Hashtable Incompatibility

**Problem:** [ordered]@{} creates OrderedDictionary (lacks .Clone() method)  
**Solution:** Use regular hashtables @{}, apply Sort-Object when order matters

```powershell
# ❌ OrderedDictionary (can't clone)
$settings = [ordered]@{ Key = "Value" }
$copy = $settings.Clone()  # ERROR: Method not found

# ✅ Hashtable (can clone)
$settings = @{ Key = "Value" }
$copy = $settings.Clone()  # Works fine
```

**Decision:** Avoid [ordered] hashtables; use Sort-Object for deterministic ordering instead.

---

## Migration Phases Summary

### ✅ Phase 0: Foundation (Week 1)
- Created three-tiered helper architecture
- Established testing patterns
- Set up Pester infrastructure
- **Deliverable:** Helper modules operational

### ✅ Phase 1: Pilot (Week 2)
- Migrated 3 simple unit tests
- Validated helper approach
- Discovered PS 5.1 scoping issues
- **Deliverable:** 3 tests passing, scoping solution documented

### ✅ Phase 2: Unit Tests (Weeks 3-5)
- Migrated 144 unit tests
- Enhanced helpers (30+ functions added)
- Solved hashtable ordering issues
- Handled .psd1 file support
- **Deliverable:** 144 tests passing, comprehensive helper library

### 🔄 Phase 3: Integration Tests (Week 6)
- 8 of 12 tests complete (66%)
- Menu navigation (4 remaining)
- Device/user/profile integration
- Reporting workflows
- **Deliverable:** 12 integration tests passing

### ⏳ Phase 4: Comprehensive Tests (Weeks 7-10)
- 9 complex end-to-end tests
- Workflow orchestration needed
- Bulk operation testing
- Multi-step scenarios
- **Deliverable:** 9 comprehensive tests passing

### ⏳ Phase 5: Evaluation & Cleanup (Weeks 11-12)
- Review remaining ~20 tests
- Decide: migrate, consolidate, or deprecate
- Performance tests → separate framework
- Final documentation updates
- **Deliverable:** Complete migration, final report

---

## Success Metrics Dashboard

### Quantitative (Current)

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Tests Migrated | 190+ | 155 | 🟢 82% |
| Pass Rate | 100% | 100% | 🟢 Met |
| Execution Time | <10s | 2-3s | 🟢 Exceeded |
| PS 5.1 Compatible | 100% | 100% | 🟢 Met |
| Code Duplication | <10% | ~0% | 🟢 Exceeded |
| Helper Functions | 20+ | 35+ | 🟢 Exceeded |
| Documentation Pages | 8+ | 9+ | 🟢 Exceeded |

### Qualitative

- ✅ **Maintainability:** Consistent patterns, helper-based
- ✅ **Developer Experience:** Fast iteration, good tooling
- ✅ **Test Coverage:** More granular than legacy
- ✅ **Documentation Quality:** Comprehensive guides
- 🔄 **Team Adoption:** Training ongoing
- 🔄 **CI/CD Integration:** Pipeline updates planned

---

## Frequently Asked Questions

### For Developers

**Q: Do I need to use all the helpers for every test?**  
A: No. Use helpers when you need their features:
- Temp files/folders → AutopilotTestHelpers
- Graph API calls → AutopilotGraphMocks
- Menu interactions → AutopilotMenuMocks
- Simple tests may not need helpers at all

**Q: Can I still use the legacy Test-Runner.ps1?**  
A: Yes, during migration both frameworks coexist. Use `.\Invoke-AllTests.ps1` to run both. Once migration is complete, legacy framework will be retired.

**Q: What if I find a bug in a helper?**  
A: Fix the helper, not the individual test! This is the core philosophy. Update the helper module, test the fix, and all tests benefit.

**Q: How do I test on both PowerShell versions?**  
A: Run tests with both `powershell.exe` (5.1) and `pwsh.exe` (7+):
```powershell
powershell.exe -File .\Invoke-PesterTests.ps1 -TestType Unit
pwsh.exe -File .\Invoke-PesterTests.ps1 -TestType Unit
```

---

### For AI Agents

**Q: Where do I start when migrating a test?**  
A: [tests/AGENTS.md](../tests/AGENTS.md) → Section 3 (Step-by-Step Migration Workflow)

**Q: How do I know which helpers to use?**  
A: [tests/AGENTS.md](../tests/AGENTS.md) → Section 4 (Helper Usage Guide) has decision tree

**Q: What if the test uses a .psd1 file?**  
A: Use `New-MockSettingsFile -FileFormat "psd1"`. See [PESTER_MIGRATION_LESSONS_LEARNED.md](PESTER_MIGRATION_LESSONS_LEARNED.md) → Phase 1 Lessons

**Q: What if tests fail on PS 5.1 but pass on PS 7+?**  
A: Check for hashtable ordering issues. Add `Sort-Object` to collections. See [TEST_TEMPLATE_GUIDELINES.md](TEST_TEMPLATE_GUIDELINES.md) → Cross-Version Compatibility section.

---

### For Managers

**Q: When will migration be complete?**  
A: 6-8 weeks from now (Weeks 6-12). See [Completion Plan](PESTER_MIGRATION_COMPLETION_PLAN.md) for detailed timeline.

**Q: Can we pause migration if needed?**  
A: Yes. Both test frameworks run in parallel. No production impact. Can pause at phase boundaries.

**Q: What's the ROI?**  
A: Immediate: 10-15x faster test execution, 37% less code. Ongoing: Lower maintenance costs, faster feature delivery, better quality confidence.

**Q: What are the risks?**  
A: Low. Migration is ahead of schedule, infrastructure proven, rollback plan in place. See [Completion Plan](PESTER_MIGRATION_COMPLETION_PLAN.md) → Risk Management section.

---

## Contributing

### Adding Documentation

1. Place in `docs/` folder
2. Follow naming convention: `PESTER_MIGRATION_[Topic].md`
3. Update this README's Quick Links section
4. Cross-reference related documents

### Updating Progress

Update these documents as phases complete:
- `PESTER_MIGRATION_PROGRESS_UPDATED.md` (statistics)
- `PESTER_MIGRATION_COMPLETION_PLAN.md` (next actions)
- This README (at-a-glance status)

### Adding Helper Functions

1. Add to appropriate helper module (AutopilotTestHelpers/GraphMocks/MenuMocks)
2. Document function in module header
3. Add example to [tests/AGENTS.md](../tests/AGENTS.md)
4. Update [TEST_TEMPLATE_GUIDELINES.md](TEST_TEMPLATE_GUIDELINES.md) if new pattern

---

## Contact & Support

**Questions about migration?**
- Review [tests/AGENTS.md](../tests/AGENTS.md) for step-by-step guidance
- Check [Lessons Learned](PESTER_MIGRATION_LESSONS_LEARNED.md) for common issues
- Consult [Test Templates](TEST_TEMPLATE_GUIDELINES.md) for patterns

**Found a helper issue?**
- Improve the helper module (don't create workarounds)
- Document the enhancement
- Submit PR with updated tests

**Need help?**
- Review [Completion Plan](PESTER_MIGRATION_COMPLETION_PLAN.md) for roadmap
- Check [Progress Report](PESTER_MIGRATION_PROGRESS_UPDATED.md) for current status
- Reach out to development team for guidance

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Oct 10, 2025 | Initial creation - consolidates all migration documentation |

---

**Last Updated:** October 10, 2025  
**Migration Status:** Phase 3 In Progress (82% Complete)  
**Next Milestone:** Phase 3 Completion (Week 6)
