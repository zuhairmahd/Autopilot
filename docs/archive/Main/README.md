# Main.ps1 Integration Tests

## Overview

The `MainInitialization.Tests.ps1` file contains integration tests for `main.ps1` using the `-testMode` switch to enable real script execution testing without requiring interactive user input or showing the menu.

## Testing Approach

### Why Use `-testMode`?

The previous approach attempted to mock internal functions and simulate the execution environment. The new approach:

1. **Runs Actual Code**: Executes `main.ps1` with `-testMode` parameter
2. **No Mocking Required**: Tests real initialization logic without mocks
3. **End-to-End Validation**: Verifies the entire startup sequence
4. **Realistic Testing**: Uses actual functions, configuration loading, and dependencies

### Test Execution Flow

```powershell
# Helper function invokes main.ps1
$result = Invoke-MainScriptTest -Parameters @{
    appMode = 'admin'
    LogLevel = 'Debug'
}

# Validates execution
$result.Success | Should -Be $true

# Checks log file for indicators
$logContent = Get-Content $result.LogFile -Raw
$logContent | Should -Match "expected pattern"
```

### What `-testMode` Does

When `main.ps1` is run with `-testMode`:

1. **Skips Authentication**: Uses `"test-mode-fake-token"` instead of calling Graph API
2. **Skips Menu Display**: Exits after initialization without showing interactive menu
3. **Uses Default Config**: If config files missing, uses dummy values (`test.local`, etc.)
4. **Accepts TestPassword**: Can provide password via parameter to skip prompts
5. **Completes Quickly**: Bypasses time-consuming interactive operations

## Test Structure

### Test Categories

1. **Basic Startup** (`Main.ps1 - Test Mode Execution`)
   - Script execution with -testMode
   - Function folder detection
   - Version detection

2. **Configuration Initialization** (`Main.ps1 - Test Mode Execution`)
   - Settings file loading
   - Configuration file handling
   - Logging initialization
   - Log file creation and management

3. **Parameter Handling** (`Main.ps1 - Parameter Handling`)
   - Command-line parameter precedence (bug fix validation)
   - Switch parameters (showVersion, showSettings, etc.)
   - Parameter validation (appMode, LogLevel values)

4. **Test Mode Behavior** (`Main.ps1 - Test Mode Configuration Behavior`)
   - Behavior without config file
   - TestPassword handling
   - Dummy configuration values

## Validation Strategy

### Log File Validation (Primary)

**Preferred approach** - Most reliable:

```powershell
if (Test-Path $script:TestLogFile) {
    $logContent = Get-Content $script:TestLogFile -Raw
    $logContent | Should -Match "Expected pattern"
}
```

**Why?**
- Write-Log calls are captured reliably
- Contains verbose execution details
- Not affected by output stream redirection issues
- Persistent across test runs

### Output Capture (Secondary)

**Used sparingly** due to PowerShell stream capture complexities:

```powershell
$result = & $script:InvokeMainScript
$outputString = $result.Output | Out-String
$outputString | Should -Match "pattern"
```

**Challenges:**
- Write-Host output may not be captured
- Stream redirection behavior varies by PowerShell version
- Output formatting can interfere with pattern matching

### Success Validation (Always)

```powershell
$result.Success | Should -Be $true
$result.ExitCode | Should -BeIn @(0, $null)
```

## Test Performance

### Execution Time

- **Per Test**: 20-30 seconds (each test runs full main.ps1 initialization)
- **Full Suite**: ~10-15 minutes for 21 tests
- **Reason**: Real configuration loading, function imports, file I/O

### Optimization Considerations

**Current Approach** (separate execution per test):
- ✅ Complete isolation between tests
- ✅ Each test validates full initialization
- ❌ Slower execution

**Alternative Approach** (shared execution):
- ✅ Faster test suite
- ❌ Tests not isolated
- ❌ Harder to debug failures

**Decision**: Prioritize **test isolation and reliability** over speed for integration tests.

## Test File Structure

```
tests/Integration/main/
├── MainInitialization.Tests.ps1      # Current test suite (using -testMode)
├── MainInitialization.Tests.old.ps1  # Backup of old approach (mocking)
└── README.md                          # This file
```

## Running the Tests

### Single Test File

```powershell
.\Invoke-PesterTests.ps1 -TestType Integration -TestFile "tests\Integration\main\MainInitialization.Tests.ps1"
```

### All Integration Tests

```powershell
.\Invoke-PesterTests.ps1 -TestType Integration
```

### Specific Test

```powershell
Invoke-Pester -Path "tests\Integration\main\MainInitialization.Tests.ps1" -FullNameFilter "*Should execute successfully with -testMode switch*"
```

## Debugging Failed Tests

### Check Log Files

When a test fails, check the log file:

```powershell
$testLogPath = Join-Path $env:TEMP "AutopilotTest_*\Logs\test.log"
Get-ChildItem $testLogPath -ErrorAction SilentlyContinue | Get-Content
```

### Run main.ps1 Directly

Test manually with -testMode:

```powershell
.\main.ps1 -testMode -LogLevel Verbose -LogFilePath "C:\temp\test.log"
```

### Enable Verbose Output

```powershell
.\Invoke-PesterTests.ps1 -TestType Integration -TestFile "tests\Integration\main\MainInitialization.Tests.ps1" -Verbose
```

## Known Limitations

1. **Execution Speed**: Each test takes 20-30 seconds due to full initialization
2. **Output Capture**: Write-Host output may not be reliably captured
3. **Test Isolation**: Each test creates new temp folders and config files
4. **Authentication**: Cannot test real Graph API calls (uses fake token)
5. **Menu Navigation**: Cannot test interactive menu (skipped in testMode)

## Future Improvements

1. **Shared Test Context**: Run main.ps1 once, validate multiple aspects
2. **Mock Authentication**: Test auth flows without real API calls
3. **Configuration Variations**: Test different config file scenarios
4. **Error Scenarios**: Test failure paths (missing files, invalid config)
5. **Performance Baseline**: Track execution time trends

## Related Documentation

- [Test Template Guidelines](../../../docs/TEST_TEMPLATE_GUIDELINES.md)
- [AGENTS.md](../../AGENTS.md) - AI-optimized testing guide
- [Main.ps1 Technical Docs](../../../docs/TECHNICAL_DOCUMENTATION.md)

## Migration from Old Approach

The old test file (`MainInitialization.Tests.old.ps1`) used extensive mocking:

**Old Approach:**
```powershell
# Created mock function files
$mockFile = Join-Path $UtilityFolder "Write-Log.ps1"
"function Write-Log { }" | Out-File -FilePath $mockFile

# Mocked initialization
Mock Initialize-ApplicationConfiguration { return @{ Success = $true } }
```

**New Approach:**
```powershell
# Runs actual main.ps1
$result = & $script:InvokeMainScript -Parameters @{ testMode = $true }

# Validates real behavior
$result.Success | Should -Be $true
```

**Benefits of New Approach:**
- Tests actual code paths, not mocked behavior
- Catches real integration issues
- No need to keep mocks in sync with implementation
- Validates parameter passing through entire call chain
- Tests configuration file loading with real Get-ApplicationDefaults

**Trade-offs:**
- Slower execution (real initialization vs mocked functions)
- Requires -testMode implementation in main.ps1
- Cannot test certain interactive scenarios

## Conclusion

The `-testMode` approach provides **realistic integration testing** by running the actual script with minimal modifications. While slower than unit tests, it validates the true behavior of the application startup sequence and catches issues that mocking would miss.

For fast, isolated testing of individual functions, use unit tests in `tests/Unit/`.
For end-to-end validation of the complete startup flow, use these integration tests.
