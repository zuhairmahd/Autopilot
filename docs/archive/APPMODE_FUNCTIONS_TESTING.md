# App Mode Functions Testing Documentation

## Overview

This document describes the comprehensive test suite for app mode configuration functions in the Windows Autopilot Management Tool. The test suite validates all aspects of the multiple app modes feature, including hierarchy management, conflict resolution, settings persistence, and backward compatibility.

## Test File

**Location**: `TestScripts\test-appmode-functions-comprehensive.ps1`

**Test Category**: `unit`, `menu`, `appmode`

**Compatible**: PowerShell 5.1+

## Test Coverage

### Functions Under Test

1. **Get-AppModeHierarchy** - Core hierarchy resolution for single app modes
2. **Get-MultipleAppModeHierarchy** - Wrapper for handling single and multiple modes
3. **Get-AppModeSettingsFromFile** - Settings file reading with backward compatibility
4. **Get-EffectiveAppModes** - Runtime mode determination from settings
5. **Get-CombinedAppModeHierarchy** - Conflict resolution for multiple modes
6. **Test-AppModeSelection** - Validation and redundancy detection
7. **Update-AppModeSettings** - Settings persistence and validation
8. **Get-AppModeConfigurationFromUser** - User interaction (silent mode only)
9. **Get-MultipleAppModeInput** - User interaction (validation only)
10. **Show-AppModeHierarchyInfo** - Help display (existence check only)

### Test Statistics

- **Total Test Cases**: 70+
- **Test Sections**: 8 major sections
- **Estimated Duration**: 10-15 seconds
- **Success Criteria**: ≥90% pass rate

## Test Sections

### 1. Get-AppModeHierarchy Tests (8 tests)

Tests core hierarchy resolution for all available app modes.

#### Test Cases:
- ✓ Full mode returns wildcard (*)
- ✓ Admin mode includes admin, advanced, helpdesk, registration
- ✓ Advanced mode includes advanced, helpdesk, registration
- ✓ HelpDesk mode returns itself only
- ✓ Registration mode includes helpdesk and registration
- ✓ AdvancedRegistration mode includes registration
- ✓ Custom mode returns empty/minimal hierarchy
- ✓ Invalid mode returns fallback

**Key Validations**:
- Hierarchy definitions match menu.psd1 configuration
- Full mode wildcard grants universal access
- Hierarchical inclusion is transitive
- Invalid modes handle gracefully

### 2. Get-MultipleAppModeHierarchy Tests (7 tests)

Tests wrapper function for single and multiple mode handling.

#### Test Cases:
- ✓ Single mode string backward compatibility
- ✓ Single mode array handling
- ✓ Multiple modes with additive strategy
- ✓ Multiple modes with precedence strategy
- ✓ Full mode overrides all others
- ✓ Empty modes array defaults to full
- ✓ Null modes defaults to full

**Key Validations**:
- Backward compatibility with single mode usage
- Proper strategy application (additive vs precedence)
- Full mode always takes precedence
- Safe defaults for edge cases

### 3. Get-AppModeSettingsFromFile Tests (6 tests)

Tests settings file reading with multiple format support.

#### Test Cases:
- ✓ Reads appModes array format (new format)
- ✓ Reads legacy appMode format (single string)
- ✓ Prioritizes appModes over legacy appMode
- ✓ Missing file defaults to full mode
- ✓ Single mode in appModes detected as SingleMode
- ✓ IsValid flag set correctly

**Key Validations**:
- Backward compatibility with legacy configurations
- Priority order: appModes > appMode > default
- Configuration type detection (SingleMode, MultipleMode, LegacyMode)
- Safe defaults for missing/corrupted files

### 4. Get-EffectiveAppModes Tests (10 tests)

Tests runtime mode determination from settings objects.

#### Test Cases:
- ✓ Hashtable with appModes array
- ✓ PSCustomObject with appModes
- ✓ Legacy appMode fallback
- ✓ appModes takes priority over legacy
- ✓ Invalid modes filtered out
- ✓ Empty settings defaults to full
- ✓ Null settings defaults to full
- ✓ Duplicate mode removal
- ✓ Single mode string converted to array
- ✓ All invalid modes defaults to full

**Key Validations**:
- Works with both hashtable and PSCustomObject
- Validates modes against known valid modes
- Removes duplicates while preserving order
- Always returns array (even for single modes)
- Mode validation prevents invalid configurations

### 5. Get-CombinedAppModeHierarchy Tests (7 tests)

Tests conflict resolution and permission combining for multiple modes.

#### Test Cases:
- ✓ Single mode returns simple hierarchy
- ✓ Full mode overrides all other modes
- ✓ Additive strategy combines all permissions
- ✓ Precedence strategy uses highest mode
- ✓ Conflict detection for overlapping hierarchies
- ✓ Precedence order established correctly
- ✓ Resolution description provided

**Key Validations**:
- Proper conflict detection between modes
- Strategy application (additive vs precedence)
- Precedence order respects hierarchy
- Detailed resolution information provided

### 6. Test-AppModeSelection Tests (7 tests)

Tests validation and redundancy detection for mode combinations.

#### Test Cases:
- ✓ Valid single mode selection
- ✓ Valid multiple mode selection
- ✓ Detects redundancy when full mode with others
- ✓ Detects hierarchical redundancy
- ✓ Conflict detection works
- ✓ Resolution message provided
- ✓ Non-conflicting mode has no conflicts

**Key Validations**:
- Detects when full mode makes others redundant
- Identifies hierarchical redundancies (e.g., admin includes helpdesk)
- Provides actionable resolution messages
- Distinguishes between conflicts and redundancies

### 7. Update-AppModeSettings Tests (5 tests)

Tests settings persistence with validation and formatting.

#### Test Cases:
- ✓ Single mode stored as single-element array
- ✓ Multiple modes stored as array
- ✓ Invalid modes filtered during update
- ✓ Duplicate modes removed during update
- ✓ Empty configuration defaults to full

**Key Validations**:
- Single modes always stored as arrays (no legacy format)
- Invalid modes filtered before persistence
- Duplicates removed automatically
- Safe defaults applied
- Settings file format preserved

### 8. Non-Interactive Function Validation (3 tests)

Tests function existence and silent mode operation.

#### Test Cases:
- ✓ Get-AppModeConfigurationFromUser silent mode works
- ✓ Show-AppModeHierarchyInfo function exists
- ✓ Get-MultipleAppModeInput function exists

**Key Validations**:
- Silent mode bypasses user interaction
- Functions are properly loaded
- Non-interactive testing possible

## Running Tests

### Run Comprehensive Test Suite

```powershell
# Direct execution
.\TestScripts\test-appmode-functions-comprehensive.ps1

# With verbose output
.\TestScripts\test-appmode-functions-comprehensive.ps1 -Verbose

# Through Test Runner (recommended)
.\TestScripts\Test-Runner.ps1 -TestCategory menu
```

### Run Specific Categories

```powershell
# Unit tests only
.\TestScripts\Test-Runner.ps1 -TestCategory unit

# All app mode tests
.\TestScripts\Test-Runner.ps1 -TestCategory specific -TestPattern "test-appmode*"
```

### Integration with CI/CD

The test suite is designed for automated execution:

```powershell
# Quick syntax validation
.\TestScripts\Test-Runner.ps1 -TestCategory syntax

# Core functionality
.\TestScripts\Test-Runner.ps1 -TestCategory core

# Full test suite
.\TestScripts\Test-Runner.ps1 -TestCategory all
```

## Test Output

### Console Output Format

```
╔════════════════════════════════════════════════════════════════╗
║  App Mode Functions - Comprehensive Test Suite                ║
╚════════════════════════════════════════════════════════════════╝

Initializing test environment...
  Loaded: Write-Log.ps1
  Loaded: Get-AppModeHierarchy.ps1
  ...

=== Testing Get-AppModeHierarchy ===
✓ Full mode returns wildcard (*)
✓ Admin mode includes expected modes
✓ Advanced mode includes expected modes
...

=== Test Summary ===
Total Tests:   70
Passed:        70
Failed:        0
Success Rate:  100%
Duration:      12.45 seconds

🎉 All tests passed! App mode functions are working correctly.
```

### Success Indicators

- **Green checkmarks (✓)**: Test passed
- **Red X marks (✗)**: Test failed (with details)
- **Success rate color coding**:
  - Green (≥90%): Excellent
  - Yellow (70-89%): Needs attention
  - Red (<70%): Critical issues

### Test Results Export

When run with `-Verbose`, detailed results are exported to JSON:

```powershell
.\test-appmode-functions-comprehensive.ps1 -Verbose
# Creates: test-appmode-functions-results.json
```

## Test Framework Features

### Automatic Cleanup

- Temporary test files are automatically deleted
- Test artifacts cleaned up even on failure
- Log files preserved for debugging

### Error Handling

- Individual test failures don't stop execution
- Detailed error messages with stack traces
- Graceful degradation for missing dependencies

### Function Loading

The test suite automatically loads required functions:
- Write-Log (logging)
- All app mode related functions
- Helper utilities (Update-Setting, Get-MenuConfiguration)

### Test File Management

Helper function creates temporary settings files with various configurations:

```powershell
New-TestSettingsFile -FilePath $path -AppModes @('helpdesk', 'registration')
New-TestSettingsFile -FilePath $path -LegacyAppMode 'admin'
```

## Troubleshooting

### Common Issues

**Issue**: Functions not loading
- **Solution**: Ensure all dependencies are in correct paths
- **Check**: Function file existence before test execution

**Issue**: Settings file tests failing
- **Solution**: Verify Write permissions in TestScripts directory
- **Check**: PowerShell execution policy allows file creation

**Issue**: Hierarchy tests failing
- **Solution**: Verify menu.psd1 is present and valid
- **Check**: appModeHierarchy section in menu configuration

### Debug Mode

Enable detailed logging:

```powershell
$VerbosePreference = "Continue"
.\test-appmode-functions-comprehensive.ps1
```

Check the log file:

```powershell
Get-Content ..\Logs\test-appmode-functions.log -Tail 50
```

## Integration with Existing Tests

### Related Test Files

- `test-appmode-comprehensive.ps1` - End-to-end app mode workflows
- `test-appmode-refactored.ps1` - Legacy app mode tests
- `test-multiple-appmodes-final.ps1` - Multiple modes integration
- `test-menu-inclusions.ps1` - Menu filtering based on modes
- `test-settings-integration.ps1` - Settings system integration

### Test Dependencies

```
test-appmode-functions-comprehensive.ps1
├── Depends on: test-syntax.ps1 (function loading)
├── Depends on: test-core-validation.ps1 (core functions)
├── Required by: test-menu-inclusions.ps1
└── Required by: test-settings-integration.ps1
```

## Maintenance

### Adding New Tests

1. Add test cases to appropriate section function
2. Follow naming convention: `Test-<FunctionName>`
3. Use `Write-TestResult` for consistency
4. Include descriptive details parameter

Example:

```powershell
function Test-NewAppModeFunction
{
    Write-TestSection "Testing New-AppModeFunction"
    
    try
    {
        $result = New-AppModeFunction -Parameter 'value'
        Write-TestResult "New functionality works" `
            ($result -eq 'expected') `
            "Expected: 'expected', Got: '$result'"
    }
    catch
    {
        Write-TestResult "New functionality works" $false $_.Exception.Message
    }
}
```

### Updating Test Expectations

When app mode behavior changes:

1. Update expected values in test assertions
2. Document behavior change in test details
3. Update this documentation
4. Run full test suite to verify

### Test Coverage Goals

- **Minimum**: 80% pass rate for release
- **Target**: 95% pass rate
- **Ideal**: 100% pass rate

## Best Practices

### Test Isolation

- Each test is independent
- No shared state between tests
- Cleanup ensures no side effects

### Test Data

- Use temporary files for persistence tests
- Clean up all test artifacts
- Don't depend on external state

### Assertions

- Test one behavior per test case
- Provide meaningful details
- Include both expected and actual values

### Documentation

- Keep this document in sync with tests
- Document any known issues
- Update when adding test cases

## References

### Related Documentation

- [APP_MODE_CONFIGURATION.md](APP_MODE_CONFIGURATION.md) - App mode feature documentation
- [MENU_SYSTEM_DOCUMENTATION.md](MENU_SYSTEM_DOCUMENTATION.md) - Menu system architecture
- [CONTRIBUTOR_GUIDE.md](CONTRIBUTOR_GUIDE.md) - General testing guidelines
- [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) - System architecture

### Function Documentation

See inline documentation in function files:
- `functions/menuFunctions/Get-AppModeHierarchy.ps1`
- `functions/setupFunctions/Get-AppModeSettingsFromFile.ps1`
- `functions/setupFunctions/Update-AppModeSettings.ps1`

## Version History

**Version 1.0** - Initial comprehensive test suite
- 70+ test cases covering all app mode functions
- Integration with Test-Runner.ps1
- Automated cleanup and error handling
- JSON export for detailed results

---

**Last Updated**: October 7, 2025  
**Maintained By**: Windows Autopilot Management Tool Team  
**Test Suite Version**: 1.0.0
