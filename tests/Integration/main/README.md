# Main.ps1 Integration Tests

## Overview
Integration tests for main.ps1 focusing on the complete application initialization workflow, including the new fastStart configuration loading mechanism.

## Test Files

### MainInitialization.Tests.ps1
**Purpose**: Core initialization workflow testing
**Focus Areas**:
- Basic startup with testMode
- Application metadata loading
- Configuration file initialization
- Parameter handling and precedence
- Logging initialization
- Settings migration
- Authentication in test mode

**Optimizations Applied**:
- Consolidated test runs within `BeforeAll` blocks
- Reduced redundant test executions by combining assertions
- Added performance tracking to monitor execution time
- Improved test efficiency by sharing setup between related tests

**Estimated Runtime**: ~15-30 seconds (optimized from ~45-60 seconds)

### MainFastStartConfiguration.Tests.ps1 ⭐ NEW
**Purpose**: FastStart mechanism validation and performance testing
**Focus Areas**:
- FastStart success path (all files present)
- FastStart fallback scenarios (missing files)
- Performance comparison: fastStart vs regular initialization
- Configuration validation in fastStart mode
- Integration with custom domains and verbose logging

**Key Features**:
- Measures execution time for performance comparisons
- Tests all fastStart fallback conditions
- Validates configuration completeness
- Provides performance metrics in test output

**Estimated Runtime**: ~20-40 seconds

### MainMenuFlow.Tests.ps1
**Purpose**: Menu creation and structure validation
**Focus Areas**:
- Menu object creation (NewMenu)
- Menu item registration (AddMenuItem)
- Menu configuration validation

**Estimated Runtime**: ~5-10 seconds

### MainUpdateFlow.Tests.ps1
**Purpose**: Update checking workflow
**Focus Areas**:
- Release version determination
- GitHub API integration
- Update availability detection

**Estimated Runtime**: ~10-15 seconds

### MainErrorHandling.Tests.ps1
**Purpose**: Error scenarios and edge cases
**Focus Areas**:
- Missing/invalid configuration files
- Authentication failures
- Functions folder validation
- Configuration errors
- Graceful degradation

**Estimated Runtime**: ~20-30 seconds

## FastStart Mechanism

### What is FastStart?
FastStart is an optimization in main.ps1 (lines 800-885) that attempts to load configuration files directly using `Import-PowerShellDataFile` instead of going through the full `Initialize-ApplicationConfiguration` workflow.

### When FastStart Succeeds
FastStart succeeds when ALL of the following conditions are met:
1. `InitFile` (settings.psd1) exists and is valid
2. `StringsFile` (strings.psd1) exists and is valid
3. Domain file (`$domain.psd1`) exists and is valid
4. `MenuFile` (menu.psd1) exists and is valid
5. All required configuration sections are present:
   - `auth`
   - `globalSettings`
   - `repoInfo`
   - `requiredScopes`
   - `cacheSettings`
   - Domain settings
   - Menu configuration
   - Strings configuration

### When FastStart Falls Back
FastStart automatically falls back to full initialization (`Initialize-ApplicationConfiguration`) when:
- Any configuration file is missing
- Any file fails to parse as PowerShell data
- Any required configuration section is null or missing
- The `$configResult.Success` validation fails

### Performance Benefits
FastStart provides significant performance improvements:
- **Typical improvement**: 30-50% faster initialization
- **Mechanism**: Direct file loading vs. full initialization with defaults merging
- **Trade-off**: No automatic defaults merging on fastStart path

## Test Mode Options

The tests use testMode with granular control over initialization phases:

```powershell
$testModeOptions = @{
    metadata        = $true/$false  # Load application metadata
    cleanup         = $true/$false  # Run temp file cleanup
    migration       = $true/$false  # Check settings migration
    config          = $true/$false  # Load configuration files
    auth            = $true/$false  # Attempt authentication
    legacyMigration = $true/$false  # Run legacy migration check
    exitAfter       = $true/$false  # Exit after initialization
}
```

### Usage Pattern
```powershell
# Minimal test - metadata only
$testOpts = @{
    metadata = $true
    exitAfter = $true
    # All other options default to $false
}

# Full initialization test
$testOpts = @{
    metadata = $true
    cleanup = $true
    migration = $true
    config = $true
    auth = $true
    legacyMigration = $true
    exitAfter = $true
}
```

## Running the Tests

### Run All Main Tests
```powershell
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestType Integration -TestFile "tests\Integration\main\*.Tests.ps1"
```

### Run Specific Test File
```powershell
# FastStart tests only
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Integration\main\MainFastStartConfiguration.Tests.ps1" -outputVerbosity Detailed

# Initialization tests only
pwsh.exe -ExecutionPolicy Bypass -File .\Invoke-PesterTests.ps1 -TestFile "tests\Integration\main\MainInitialization.Tests.ps1" -outputVerbosity Detailed
```

### Run by Tags
```powershell
# Performance-related tests only
Invoke-Pester -Path "tests\Integration\main" -Tag "Performance"

# Quick smoke test
Invoke-Pester -Path "tests\Integration\main" -Tag "Quick"

# FastStart-specific tests
Invoke-Pester -Path "tests\Integration\main" -Tag "FastStart"
```

## Performance Monitoring

### Built-in Performance Tracking
The tests now include performance tracking:
- Individual test execution times logged to console
- Performance summary at end of test runs
- Comparison between fastStart and regular loading

### Sample Output
```
Fast start configuration load succeeded.
Quick TestMode completed in 1234.56 ms
FastStart Duration: 1234.56 ms
Regular Init Duration: 2345.67 ms
Speed improvement: 47.35%
```

### Performance Baselines
Expected execution times on a typical development machine:
- **FastStart success**: 1-3 seconds
- **Regular initialization**: 2-5 seconds
- **Complete test suite**: 60-90 seconds (optimized from 120-180 seconds)

## Coverage Report

### Main.ps1 Lines Covered
- **800-885**: FastStart mechanism (fully covered)
- **233-273**: TestMode initialization (covered)
- **304-393**: Functions folder loading (covered)
- **397-440**: Script parameters setup (covered)
- **441-596**: Configuration loading (covered)
- **597-610**: Cache clearing (covered)
- **615-799**: Login processing (partially covered - auth tests limited in testMode)
- **887-942**: Configuration extraction and merging (covered)
- **948-988**: Password change requirement (covered in testMode)

### Coverage Gaps
- Full authentication flow (requires real Graph token)
- Menu execution (requires interactive session)
- Update download and installation
- Real password change workflow

These gaps are intentional for integration tests. Unit tests provide coverage for isolated components.

## Troubleshooting

### Tests Taking Too Long
- Check if multiple pwsh.exe processes are running
- Ensure logs are being overwritten (`-OverwriteLogs`)
- Review which phases are enabled in testModeOptions
- Consider running specific test files instead of full suite

### FastStart Tests Failing
- Verify configuration files are being created correctly
- Check log files for "Fast start configuration load" messages
- Ensure domain file matches domain setting in settings.psd1
- Validate all required configuration sections exist

### Random Test Failures
- Clean up temp folders: `Remove-Item $env:TEMP\AutopilotTest* -Recurse -Force`
- Check for orphaned test directories in repo root
- Verify no file locks on test configuration files
- Run with `-outputVerbosity Detailed` for more information

## Best Practices

### When Adding New Tests
1. ✅ Use `BeforeAll` to share setup between related tests
2. ✅ Consolidate test runs - one run per Context when possible
3. ✅ Add performance tracking for long-running tests
4. ✅ Use appropriate testModeOptions (minimal phases = faster tests)
5. ✅ Document expected behavior and timing in test descriptions
6. ❌ Don't run main.ps1 separately for each It block
7. ❌ Don't enable all testMode phases unless needed

### When Debugging Tests
1. Add `-outputVerbosity Detailed` to see full output
2. Check log files in test temp directory
3. Use `Get-FastStartLogMessages` helper to extract fastStart logs
4. Add timing measurements to identify slow tests
5. Run individual contexts to isolate issues

## Future Enhancements

### Planned Improvements
- [ ] Add benchmarking suite for performance regression detection
- [ ] Implement parallel test execution for independent test files
- [ ] Add coverage for corporate settings file loading
- [ ] Create performance dashboard/reporting
- [ ] Add tests for configuration file validation and auto-repair

### Research Areas
- [ ] Investigate mocking Graph API for authentication tests
- [ ] Explore snapshot testing for configuration results
- [ ] Consider property-based testing for configuration permutations

## References

- [Pester Documentation](https://pester.dev/)
- [AGENTS.md](../../../AGENTS.md) - Repository guidelines
- [DEVELOPER_GUIDE.md](../../../docs/DEVELOPER_GUIDE.md) - Architecture and standards
- [tests/AGENTS.md](../../AGENTS.md) - Testing guide for AI agents
