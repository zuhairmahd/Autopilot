# Migration Experience - Test Coverage Documentation

## Overview
This document describes the comprehensive test coverage for the JSON to PSD1 migration experience, including all components and workflows.

## Test Files Created

### 1. test-migration-comprehensive.ps1
**Purpose**: Comprehensive unit and integration tests for all migration components

**Coverage Areas**:
- `Invoke-SettingsMigration.ps1`
  - Domain file migration with legacy structure
  - Settings.json migration
  - RemoveJsonFiles parameter functionality
  - No migration needed scenarios
  - PSD1 structure validation
  - Array conversion (appMode → appModes)
  - Migration flag addition

- `Resolve-MigratedLegacyObjects.ps1`
  - User deferral workflow
  - Array normalization (strings, hashtables, PSCustomObjects)
  - Objects already have IDs
  - Configuration save success/failure
  - Comprehensive statistics tracking
  - All three object types (Autopilot profiles, groupsToInclude, groupsToExclude)

- Main.ps1 Integration Logic
  - User defers - flag stays true
  - Success - flag becomes false
  - Failure - user choice determines flag
  - Configuration update workflows

- Edge Cases
  - Empty arrays
  - Null settings keys
  - Mixed format arrays
  - PSCustomObject conversion

- Error Handling
  - Missing access token
  - Invalid settings file path
  - Network errors during resolution

**Test Count**: 40+ tests
**Execution Time**: ~2-3 minutes
**Category**: integration

### 2. test-migration-silent-mode-integration.ps1
**Purpose**: Integration tests for -Silent switch behavior in resolution functions

**Coverage Areas**:
- `Resolve-SingleAutopilotProfileInteractive`
  - Exact match with -Silent (auto-accept, no output)
  - Exact match without -Silent (console output)
  - Duplicate detection in silent mode
  - No access token handling

- `Resolve-SingleGroupInteractive`
  - Exact match with -Silent (auto-accept, no output)
  - Exact match without -Silent (console output)
  - Duplicate detection in silent mode
  - Multiple matches still prompt (even in silent mode)

- Verbose Logging
  - Silent mode logs to file
  - Verbose entries present

**Test Count**: 15+ tests
**Execution Time**: ~1-2 minutes
**Category**: integration

### 3. test-migration-e2e-workflow.ps1
**Purpose**: End-to-end workflow test simulating complete migration experience

**Coverage Areas**:
- **Phase 1**: Initial State
  - JSON configuration files creation
  - Domain configuration with groups and profiles
  - Settings.json with auth and scopes

- **Phase 2**: Migration Execution
  - Invoke-SettingsMigration execution
  - PSD1 file creation
  - Structure transformation validation
  - Migration flag verification

- **Phase 3**: User Defers Resolution
  - User interaction simulation
  - Deferred workflow
  - Flag preservation

- **Phase 4**: Successful Resolution
  - User proceeds with resolution
  - All object types resolved
  - Configuration saved
  - Flag cleared

- **Phase 5**: Failure Scenarios
  - Save failures
  - User retry choices
  - Error handling

- **Phase 6**: Complete Workflow Validation
  - Full integration verification
  - All workflow steps validated

**Test Count**: 35+ tests
**Execution Time**: ~3-4 minutes
**Category**: integration

### 4. test-migration-callers.ps1 (Existing - Updated)
**Purpose**: Validates migrated callers use new Update-Setting function correctly

**Coverage Areas**:
- Direct Update-Setting calls
- Global settings updates
- Auth settings updates
- Domain settings updates with merge
- Settings verification after updates

**Test Count**: 10+ tests
**Execution Time**: ~1 minute
**Category**: integration

## Test Execution

### Run All Migration Tests
```powershell
.\TestScripts\Test-Runner.ps1 -TestCategory integration
```

### Run Individual Test Suites
```powershell
# Comprehensive tests
.\TestScripts\test-migration-comprehensive.ps1

# Silent mode integration
.\TestScripts\test-migration-silent-mode-integration.ps1

# E2E workflow
.\TestScripts\test-migration-e2e-workflow.ps1

# Caller migration
.\TestScripts\test-migration-callers.ps1
```

## Coverage Matrix

| Component | Unit Tests | Integration Tests | E2E Tests | Edge Cases | Error Handling |
|-----------|------------|-------------------|-----------|------------|----------------|
| Invoke-SettingsMigration.ps1 | ✓ | ✓ | ✓ | ✓ | ✓ |
| Resolve-MigratedLegacyObjects.ps1 | ✓ | ✓ | ✓ | ✓ | ✓ |
| Resolve-SingleAutopilotProfileInteractive (-Silent) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Resolve-SingleGroupInteractive (-Silent) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Main.ps1 Migration Logic | ✓ | ✓ | ✓ | ✓ | ✓ |
| Update-Setting Integration | ✓ | ✓ | ✓ | ✓ | ✓ |

## Scenarios Covered

### Migration Scenarios
1. ✓ First-time migration from JSON to PSD1
2. ✓ Domain file with legacy structure (settings subkey)
3. ✓ Settings.json with menu/domains removal
4. ✓ appMode → appModes array conversion
5. ✓ Migration flag addition (migrateLegacyConfiguration)
6. ✓ No migration needed (no JSON files)
7. ✓ JSON file removal after migration
8. ✓ Backup creation before modification

### Legacy Object Resolution Scenarios
1. ✓ User defers resolution (first time)
2. ✓ User proceeds with resolution
3. ✓ String arrays normalized to hashtables
4. ✓ Hashtables with missing IDs resolved
5. ✓ PSCustomObjects converted and resolved
6. ✓ Objects already have IDs (skip resolution)
7. ✓ Mixed format arrays handled
8. ✓ Empty arrays handled gracefully
9. ✓ Null settings keys handled
10. ✓ All three object types processed
11. ✓ Configuration save success
12. ✓ Configuration save failure
13. ✓ Comprehensive statistics tracking

### Silent Mode Scenarios
1. ✓ Exact match auto-accepted (Autopilot profiles)
2. ✓ Exact match auto-accepted (Groups)
3. ✓ No console output in silent mode
4. ✓ Verbose logging in silent mode
5. ✓ Duplicate detection in silent mode
6. ✓ Multiple matches still prompt (interactive)
7. ✓ Normal mode has console output

### Main.ps1 Integration Scenarios
1. ✓ User defers - flag stays true
2. ✓ Resolution succeeds - flag becomes false
3. ✓ Resolution fails - user chooses retry (flag stays true)
4. ✓ Resolution fails - user declines (flag becomes false)
5. ✓ Update-Setting called with correct parameters
6. ✓ Settings file path properly passed

### Error Handling Scenarios
1. ✓ Missing access token
2. ✓ Invalid settings file path
3. ✓ Network errors during Graph API calls
4. ✓ Save failures
5. ✓ Malformed JSON files
6. ✓ Missing required keys
7. ✓ Type conversion errors

## Success Criteria

### Test Success Metrics
- **Total Tests**: 100+ across all suites
- **Expected Pass Rate**: 100%
- **Coverage**: All functions, all branches, all error paths
- **Execution Time**: < 10 minutes for all tests

### Quality Gates
- ✓ All unit tests pass
- ✓ All integration tests pass
- ✓ All E2E workflow tests pass
- ✓ All edge cases covered
- ✓ All error scenarios handled
- ✓ No regression in existing functionality

## Test Maintenance

### Adding New Tests
1. Identify new scenario or edge case
2. Add test case to appropriate test file
3. Update coverage matrix in this document
4. Run full test suite to verify no regression

### Updating Existing Tests
1. Modify test as needed
2. Verify all related tests still pass
3. Update documentation if behavior changes
4. Update coverage matrix if coverage changes

## Continuous Integration

### CI/CD Integration
The migration tests are integrated into the Test-Runner.ps1 framework and will run automatically as part of the `integration` test category.

```powershell
# In CI/CD pipeline
.\TestScripts\Test-Runner.ps1 -TestCategory integration -NoInteractive
```

### Pre-Commit Checks
Developers should run migration tests before committing changes to:
- Invoke-SettingsMigration.ps1
- Resolve-MigratedLegacyObjects.ps1
- Resolve-SingleAutopilotProfileInteractive
- Resolve-SingleGroupInteractive
- Main.ps1 (migration section)

## Known Limitations

1. **Silent mode interactive tests**: Some tests require full mock setup and are skipped in unit test mode
2. **Graph API mocking**: Network tests use mocked responses
3. **User interaction**: Read-Host is mocked for automated testing

## Future Enhancements

1. Add performance benchmarking for large migrations
2. Add stress tests with hundreds of objects
3. Add parallel migration testing
4. Add rollback scenario testing
5. Add migration analytics collection

## Contact

For questions about migration testing:
- See AGENTS.md for contribution guidelines
- See CONTRIBUTOR_GUIDE.md for detailed contribution process
- Check docs/TECHNICAL_DOCUMENTATION.md for architecture details

## Version History

- **1.0.0** (2025-10-09): Initial comprehensive test coverage
  - Created test-migration-comprehensive.ps1
  - Created test-migration-silent-mode-integration.ps1
  - Created test-migration-e2e-workflow.ps1
  - Updated test-migration-callers.ps1
  - Updated Test-Runner.ps1 integration category
