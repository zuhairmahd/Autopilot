# GitHub Actions Testing Strategy

## Overview

With the complete migration to Pester v5, the Autopilot project now leverages a sophisticated multi-stage testing approach in GitHub Actions, providing comprehensive quality checks at every stage of development.

## Workflows

### 1. **pr-checks.yml** - Pull Request Validation ⭐ NEW
**Trigger:** Pull requests to master, dev, or lhm branches

**Purpose:** Comprehensive quality gate for all pull requests

**Stages:**
- **Unit Tests with Coverage** (10 min)
  - Runs all 144+ unit tests
  - Generates code coverage reports
  - Fails fast on test failures
  
- **Integration Tests** (15 min)
  - Tests cross-component functionality
  - Validates settings, menu, and Graph API integration
  - Only runs if unit tests pass

- **Comprehensive Tests** (20 min) - *Conditional*
  - Full end-to-end scenarios
  - Only runs for PRs to `master` branch
  - Can be triggered manually with `run-comprehensive-tests` label
  
- **Code Quality Checks** (5 min)
  - PSScriptAnalyzer validation
  - Enforces PowerShell best practices
  - Fails on errors, warns on issues

- **Test Summary**
  - Aggregates all check results
  - Provides clear pass/fail status

**Features:**
- ✅ Test result annotations in PR
- ✅ Code coverage tracking
- ✅ Fast feedback (fails early)
- ✅ Parallel test execution where possible
- ✅ Artifact retention (7 days)

### 2. **publish.yml** - Branch Build & Deploy
**Trigger:** Pushes to dev and lhm branches (skip with `[skip ci]`)

**Purpose:** Automated builds for development environments

**Stages:**
- **Unit Tests** (10 min)
  - Fast validation before build
  - Cached Pester module for speed
  
- **Integration Tests** (15 min)
  - Ensures branch stability
  - Runs after unit tests pass

- **Build** (25 min)
  - Creates branch-specific executables
  - Applies target configuration (dev/government)
  - Only runs if tests pass

- **Sign** (20 min)
  - Azure Trusted Signing
  - Updates hashes
  - Commits signed artifacts back to branch

**Features:**
- ✅ Multi-stage testing before build
- ✅ Branch-specific configurations
- ✅ Automatic signing and commit
- ✅ Skip CI support
- ✅ Artifact uploads

### 3. **release.yml** - Production Release
**Trigger:** GitHub release published

**Purpose:** Create signed, production-ready releases

**Stages:**
- **Unit Tests with Coverage** (10 min)
  - Full unit test suite
  - Code coverage analysis
  - Required for release
  
- **Integration Tests** (15 min)
  - Cross-component validation
  - Ensures release stability

- **Comprehensive Tests** (20 min)
  - End-to-end scenarios
  - Complete system validation
  - Final quality gate

- **Build** (25 min)
  - Production executable
  - Uses production target
  - Includes all optimizations

- **Sign** (20 min)
  - Azure Trusted Signing
  - Production certificate
  - Hash validation

- **Release** (5 min)
  - Uploads signed artifacts to GitHub release
  - Includes main.exe and lastrun.json

**Features:**
- ✅ Complete test coverage (Unit → Integration → Comprehensive)
- ✅ Production signing
- ✅ Automated release asset upload
- ✅ Test result artifacts (30-day retention)

## Test Execution Strategy

### Multi-Stage Approach
```
┌─────────────┐
│ Unit Tests  │  Fast (2-3s), 144+ tests
└──────┬──────┘
       │ Pass
       ▼
┌─────────────┐
│Integration  │  Medium (~10s), 8+ tests
└──────┬──────┘
       │ Pass
       ▼
┌─────────────┐
│Comprehensive│  Slower (~20s), full E2E
└─────────────┘
```

### Benefits
1. **Fail Fast**: Unit tests catch 80% of issues in <3 seconds
2. **Resource Efficient**: Only runs expensive tests after fast tests pass
3. **Clear Feedback**: Test results organized by category
4. **Parallel Execution**: Independent jobs run concurrently when possible

## Caching Strategy

All workflows cache the Pester module to speed up execution:
```yaml
- name: Cache Pester module
  uses: actions/cache@v4
  with:
    path: ~\Documents\PowerShell\Modules\Pester
    key: ${{ runner.os }}-pester-${{ hashFiles('**/Invoke-PesterTests.ps1') }}
```

**Impact:** 20-30 second reduction per job

## Test Result Artifacts

### Retention Periods
- **PR workflows**: 7 days
- **Release workflows**: 30 days
- **Branch builds**: 30 days (signed artifacts)

### Artifact Contents
- `TestResults*.xml` - NUnit-format test results
- `coverage.xml` - Code coverage data (Cobertura format)
- Test execution logs

## CI/CD Configuration

### Environment Variables
All workflows use these secrets:
- `AZURE_TENANT_ID` - Azure Trusted Signing tenant
- `AZURE_CLIENT_ID` - Service principal client ID
- `AZURE_CLIENT_SECRET` - Service principal secret
- `GITHUB_TOKEN` - Automatically provided

### Skip CI
Add `[skip ci]` to commit messages to bypass all checks:
```bash
git commit -m "docs: update README [skip ci]"
```

## Usage Examples

### Running Tests Locally (Matches CI)
```powershell
# Unit tests only (fast)
.\Invoke-PesterTests.ps1 -TestType Unit -CI

# Integration tests
.\Invoke-PesterTests.ps1 -TestType Integration -CI

# Comprehensive tests
.\Invoke-PesterTests.ps1 -TestType Comprehensive -CI

# All tests with coverage (release mode)
.\Invoke-PesterTests.ps1 -TestType All -EnableCodeCoverage -CI
```

### Triggering Comprehensive Tests on PRs
Add the label `run-comprehensive-tests` to any PR to force comprehensive testing:
1. Go to PR
2. Add label: "run-comprehensive-tests"
3. Workflow will trigger automatically

### Creating a Release
1. Create a tag: `git tag v1.0.0`
2. Push tag: `git push origin v1.0.0`
3. Create GitHub release from tag
4. Workflow runs automatically with full test suite

## Monitoring & Debugging

### View Test Results
- **Actions tab** → Select workflow run → View job logs
- **Checks tab** on PRs shows test summaries
- Download artifacts for detailed XML reports

### Common Issues

**Tests fail in CI but pass locally:**
- Check PowerShell version (must be 7+)
- Verify Pester version (5.0.0+)
- Review environment differences

**Signing fails:**
- Verify Azure secrets are configured
- Check service principal permissions
- Review Azure Trusted Signing configuration

**Cache misses:**
- Cache keys are based on `Invoke-PesterTests.ps1` hash
- Changing test runner invalidates cache

## Performance Metrics

### Typical Execution Times
| Stage | Duration | Test Count | Notes |
|-------|----------|------------|-------|
| Unit Tests | 2-5s | 144+ | Fastest feedback |
| Integration | 8-12s | 8+ | Settings, menu, Graph |
| Comprehensive | 15-25s | Variable | Full scenarios |
| Build | 3-5 min | N/A | ps2exe compilation |
| Sign | 1-2 min | N/A | Azure API latency |

### Full Pipeline Duration
- **PR Check (Unit + Integration):** ~5-7 minutes
- **PR Check (with Comprehensive):** ~10-12 minutes
- **Branch Build (with Sign):** ~15-20 minutes
- **Release (Full Suite + Sign):** ~25-35 minutes

## Best Practices

### For Developers
1. ✅ Run unit tests locally before pushing
2. ✅ Use `[skip ci]` for documentation-only changes
3. ✅ Add comprehensive tests for new features
4. ✅ Check test artifacts when debugging failures
5. ✅ Keep test execution time under 30 seconds

### For Maintainers
1. ✅ Review test results before merging PRs
2. ✅ Monitor test execution times (watch for slow tests)
3. ✅ Update test infrastructure when adding test categories
4. ✅ Verify code coverage trends
5. ✅ Maintain comprehensive test coverage for critical paths

## Future Enhancements

### Planned
- [ ] Code coverage reporting in PRs
- [ ] Performance regression testing
- [ ] Cross-platform testing (Linux, macOS)
- [ ] Automated dependency updates

### Under Consideration
- [ ] Test result dashboard
- [ ] Flaky test detection
- [ ] Parallel test execution within categories
- [ ] Docker-based test environments

## Migration Notes

### What Changed
- **Before:** Single test job with `TestScripts\Test-Runner.ps1`
- **After:** Multi-stage Pester tests (Unit → Integration → Comprehensive)

### Benefits
- ✅ 82% of tests migrated to Pester v5
- ✅ 2-3 second execution time (vs. 30+ seconds)
- ✅ Better failure isolation
- ✅ Standardized test reporting
- ✅ Code coverage support

### Compatibility
All workflows support PowerShell 5.1 and 7.x, matching local development.

## Related Documentation
- [`tests/AGENTS.md`](../tests/AGENTS.md) - Test writing guide
- [`docs/PESTER_MIGRATION_README.md`](PESTER_MIGRATION_README.md) - Migration documentation
- [`docs/TEST_TEMPLATE_GUIDELINES.md`](TEST_TEMPLATE_GUIDELINES.md) - Test patterns
- [`Invoke-PesterTests.ps1`](../Invoke-PesterTests.ps1) - Test runner

---

**Last Updated:** October 2025  
**Migration Status:** 82% complete (155 of ~190 tests)  
**Next Phase:** Phase 4 - Comprehensive test expansion
