# TestMode Implementation Summary

## Overview
Implemented a comprehensive `-testMode` switch parameter in `main.ps1` to enable non-interactive testing of the application, including all initialization and configuration workflows.

## Changes Made

### 1. main.ps1 - Core Changes

#### Added Parameters
- **`-testMode`**: Switch parameter to enable test mode (non-interactive execution)
- **`-TestPassword`**: SecureString parameter for providing password non-interactively (only works with `-testMode`)

```powershell
[switch]$testMode,
[SecureString]$TestPassword
```

#### Script-Level Password Storage
```powershell
# Store test password in script scope if provided (only works with testMode for security)
if ($testMode -and $TestPassword)
{
    $script:UserEncryptionPassword = $TestPassword
    Write-Verbose "[$scriptName] Test mode: Password provided via parameter"
}
```

#### Configuration Loading (lines ~420-510)
- **In test mode WITHOUT config file**: Skip First Run Wizard, use default test configuration
- **In test mode WITH config file**: Skip password prompts, use stored test password
- **In test mode WITH TestPassword**: Use provided password for config decryption

```powershell
# In test mode without a test password and config file exists, skip config loading
if ($testMode -and -not $TestPassword -and (Test-Path $configFile))
{
    Write-Verbose "[$scriptName] Test mode: Config file exists but no test password provided"
    Write-Verbose "[$scriptName] Test mode: Skipping config file loading to avoid interactive prompts"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping config file loading" -LogLevel "Information"
    
    # Set default test values
    $domain = "test.contoso.com"
    $appId = "00000000-0000-0000-0000-000000000000"
    $tenantId = "00000000-0000-0000-0000-000000000000"
    $name = "Test Application"
}
```

#### First Run Wizard Handling (lines ~477-510)
- **In test mode**: Skip wizard entirely, use default test configuration
- **Normal mode**: Launch wizard with `-Silent` switch if needed

```powershell
if ($testMode)
{
    # In test mode, skip first run wizard and create minimal configuration
    Write-Verbose "[$scriptName] Test mode enabled: Skipping first run wizard and using default test configuration"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping first run wizard" -LogLevel "Information"
    
    # Set default test values
    $domain = "test.contoso.com"
    $appId = "00000000-0000-0000-0000-000000000000"
    $tenantId = "00000000-0000-0000-0000-000000000000"
    $name = "Test Application"
    
    # Skip config file loading in test mode
    Write-Verbose "[$scriptName] Test mode: Using default test configuration without config file"
    $wizardResult = $true
}
else
{
    # Launch the first run wizard (pass Silent switch if testMode is active)
    $wizardResult = Start-FirstRunWizard -ConfigFile $configFile -SettingsFile $InitFile -StringsFile "$PWD\strings.psd1" -Silent:$testMode
}
```

#### Authentication Token Retrieval (lines ~890-915)
- **In test mode**: Skip Graph API authentication, use fake token
- **Normal mode**: Retrieve real access token

```powershell
if ($testMode)
{
    Write-Verbose "[$scriptName] Test mode: Skipping Graph API token retrieval"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping Graph API authentication" -LogLevel "Information"
    $accessToken = "test-mode-fake-token"
}
else
{
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Force new token: $($auth.ForceNewToken )" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Force new refresh token: $($auth.ForceNewRefreshToken )" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "No save refresh token: $($auth.NoSaveRefreshToken )" -LogLevel "Information"
    Write-Log -logFile $LogFile -Module $scriptName -Message "Getting access token..." -LogLevel "Information"
    $accessToken = GetGraphAccessToken @getTokenParams
}
```

#### Password Change Check (lines ~635-677)
- **In test mode**: Skip password change requirement checks
- **Normal mode**: Check and prompt for password changes if needed

```powershell
if ($testMode)
{
    Write-Verbose "[$scriptName] Test mode: Skipping password change check"
    Write-Log -LogFile $LogFile -Module $scriptName -Message "Test mode: Skipping password change requirement check" -LogLevel "Information"
}
else 
{
    # Check for password change requirement
    # ... existing password change logic ...
}
```

#### Menu Display (lines ~1976-1993)
- **In test mode**: Skip menu display
- **Normal mode**: Show interactive menu

```powershell
# Only show menu if not in test mode
if ($testMode)
{
    Write-Host "Test mode: $testMode. No menu will be shown." -ForegroundColor Yellow
    Write-Host "You can run the script in test mode to validate functionality without showing the menu."
}
else
{
    Write-Verbose "Test mode: $testMode"
    if ($null -ne $mainMenu)
    {
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Showing main menu." -LogLevel "Information"
        $result = ShowMenu -Menu $mainMenu
        if ($null -eq $result)
        {
            Write-Host "`nThank you for using the Intune Helpdesk menu. Goodbye!" -ForegroundColor Green
        }
    }
}
```

### 2. Get-SecurePassword.ps1 - Silent Mode Support

Added `-Silent` switch parameter to suppress interactive prompts:

```powershell
[switch]$Silent
```

Implementation:
```powershell
if ($Silent)
{
    # In silent mode, return stored password or null without prompting
    Write-Verbose "[$functionName] Silent mode: Returning stored password without prompt"
    if ($script:UserEncryptionPassword)
    {
        return $script:UserEncryptionPassword
    }
    else
    {
        Write-Verbose "[$functionName] Silent mode: No stored password available"
        return $null
    }
}
```

### 3. Load-EncryptedConfigFile.ps1 - Silent Mode Support

Added `-Silent` switch parameter and modified to suppress Write-Host messages in silent mode:

```powershell
[switch]$Silent
```

Key changes:
- Pass `-Silent` to `Get-SecurePassword`
- Suppress Write-Host messages when in silent mode
- Return early with null if no password available in silent mode

### 4. Initialize-ConfigurationSession.ps1 - Silent Mode Support

Added `-Silent` switch parameter to control interactive behavior:

```powershell
[switch]$Silent
```

Implementation:
- Pass `-Silent` to `Load-EncryptedConfigFile`
- Skip retry loops in silent mode
- Return appropriate error messages for debugging

### 5. Test Files Updated

#### test-performance-optimized.ps1
**OLD approach**: Used non-existent `-testmode` parameter and created test settings file
**NEW approach**: Uses `-testMode` switch parameter directly

```powershell
# Before:
@"
try {
    . '$PSScriptRoot/../main.ps1' -InitFile '$testSettingsPath' -appMode '$($scenario.AppMode)' -LogLevel 'Warning' 2>&1 | Out-Null
    exit 0
} catch {
    Write-Error `$_.Exception.Message
    exit 1
}
"@

# After:
@"
try {
    . '$PSScriptRoot/../main.ps1' -appMode '$($scenario.AppMode)' -LogLevel 'Warning' -testMode 2>&1 | Out-Null
    exit 0
} catch {
    Write-Error `$_.Exception.Message
    exit 1
}
"@
```

#### test-performance-baseline.ps1
**OLD approach**: Used environment variable `$env:SKIP_INTERACTIVE = "true"`
**NEW approach**: Uses `-testMode` switch parameter

```powershell
# Before:
$env:SKIP_INTERACTIVE = "true"
. $scriptPath -appMode $mode -LogLevel "Warning" 2>&1 | Out-Null

# After:
. $scriptPath -appMode $mode -LogLevel "Warning" -testMode 2>&1 | Out-Null
```

## Benefits

1. **Non-Interactive Testing**: Tests can run completely automated without user prompts
2. **CI/CD Compatible**: Tests can run in automated pipelines
3. **Consistent Behavior**: Single `-testMode` switch controls all interactive aspects
4. **Security**: TestPassword parameter only works with testMode for safety
5. **Backward Compatible**: Existing functionality unchanged when testMode is not used
6. **Comprehensive Coverage**: Handles all initialization paths (config loading, wizard, authentication, menu)

## Testing Results

### test-performance-optimized.ps1
- **Status**: ✅ All 5 tests passing (100% success rate)
- **Execution**: Non-interactive, no password prompts
- **Duration**: ~10 seconds for 1 iteration

### test-migration-silent-mode-integration.ps1
- **Status**: ✅ All 6 tests passing (100% success rate)
- **Execution**: Non-interactive
- **Note**: Uses mock functions, not affected by testMode changes

## Usage Examples

### Basic Test Mode
```powershell
.\main.ps1 -testMode
```
- Skips all interactive prompts
- Uses default test configuration
- Skips Graph API authentication
- Does not display menu

### Test Mode with Encrypted Config
```powershell
$password = ConvertTo-SecureString "MyPassword123!" -AsPlainText -Force
.\main.ps1 -testMode -TestPassword $password
```
- Decrypts config file using provided password
- No interactive password prompts
- Uses real config but skips other interactive elements

### In Test Scripts
```powershell
# In test harness
$scriptBlock = @"
try {
    . '$PSScriptRoot/../main.ps1' -appMode 'helpDesk' -LogLevel 'Warning' -testMode 2>&1 | Out-Null
    exit 0
} catch {
    Write-Error `$_.Exception.Message
    exit 1
}
"@
$process = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-File", $tempScript -Wait -PassThru -NoNewWindow
```

## Future Enhancements

1. **Test Data Injection**: Allow providing test data via parameters for more comprehensive testing
2. **Mock Graph Responses**: Create a mock Graph API provider for unit testing
3. **Test Coverage Reporting**: Integrate with coverage tools to track test coverage
4. **Performance Benchmarking**: Store baseline performance metrics for regression testing

## Migration Notes

### For Test Developers
- Replace any usage of `$env:SKIP_INTERACTIVE` with `-testMode` parameter
- Remove custom test settings files (settings.psd1 with testMode = $true)
- Use `-testMode` directly instead of `-testmode` (case correction)

### For Main Application Users
- No changes required - testMode is opt-in only
- Normal execution flow unchanged

## Related Files

- `main.ps1` - Core application with testMode support
- `functions/encryptionFunctions/Get-SecurePassword.ps1` - Silent password retrieval
- `functions/encryptionFunctions/Load-EncryptedConfigFile.ps1` - Silent config loading
- `functions/encryptionFunctions/Initialize-ConfigurationSession.ps1` - Silent session init
- `TestScripts/test-performance-optimized.ps1` - Updated to use testMode
- `TestScripts/test-performance-baseline.ps1` - Updated to use testMode

## References

- Issue: Tests should not run interactively
- PR: #161 - Tests refactor
- Documentation: AGENTS.md, TEST_HARNESS_GUIDE.md
