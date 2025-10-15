# Fix: Domain Configuration Save Issue in Resolve-MigratedAutopilotProfiles

## Problem
The `Resolve-MigratedAutopilotProfiles` function was failing to save Autopilot profiles to domain configuration files with the error:

```
WARNING: [Update-Setting] Error updating Domain setting: Cannot bind argument to parameter 'Path' because it is an empty string.
WARNING:   Failed to save Autopilot profiles to domain configuration
```

## Root Cause
The `Resolve-MigratedAutopilotProfiles` function was calling `Update-Setting` without providing the `-SettingsFile` parameter. When `Update-Setting` tried to use the default value of `"settings.psd1"`, the path resolution failed because it wasn't provided with the proper context (working directory or full path).

The chain of calls was:
1. `main.ps1` → `Resolve-MigratedAutopilotProfiles` (✗ no settings path passed)
2. `Resolve-MigratedAutopilotProfiles` → `Update-Setting` (✗ no settings path passed)
3. `Update-Setting` → `Get-DomainConfigurationFromFiles` (✗ received empty/invalid path)

## Solution
Added `SettingsFile` parameter to `Resolve-MigratedAutopilotProfiles` and ensured it's passed through the call chain:

1. `main.ps1` passes `$InitFile` (which defaults to `"$pwd\settings.psd1"`)
2. `Resolve-MigratedAutopilotProfiles` receives and passes it to `Update-Setting`
3. `Update-Setting` uses it to determine domain configuration file location

## Changes Made

### 1. Resolve-MigratedAutopilotProfiles.ps1

#### Added Parameter
```powershell
[Parameter(Mandatory = $false)]
[string]$SettingsFile = "settings.psd1"
```

#### Updated Documentation
```powershell
.PARAMETER SettingsFile
    Path to the settings.psd1 file. Used to determine the location for domain configuration files.
    Defaults to "settings.psd1" in the current directory.
```

#### Updated Update-Setting Call
```powershell
$saveSuccess = Update-Setting `
    -SettingType "Domain" `
    -DomainName $domain `
    -Settings $domainSettings `
    -SettingsFile $SettingsFile `  # NEW: Pass settings file path
    -MergeSettings
```

#### Added Logging
```powershell
Write-Verbose "[$functionName] Calling Update-Setting with SettingsFile: $SettingsFile"
Write-Log -LogFile $logFile -Module $functionName -Message "Using settings file: $SettingsFile" -LogLevel "Verbose"
```

### 2. main.ps1

#### Updated Function Call
```powershell
# Before:
$profileResolutionResult = Resolve-MigratedAutopilotProfiles `
    -accessToken $accessToken `
    -autopilotProfiles $autopilotProfiles `
    -domain $domain

# After:
$profileResolutionResult = Resolve-MigratedAutopilotProfiles `
    -accessToken $accessToken `
    -autopilotProfiles $autopilotProfiles `
    -domain $domain `
    -SettingsFile $InitFile  # NEW: Pass settings file path from main.ps1
```

## Testing

### Test Scenario 1: Migration with Profile Resolution
```powershell
# Run main.ps1 with a JSON file that needs migration
.\main.ps1 -Verbose

# Expected behavior:
# 1. Migration detects autopilot profiles
# 2. Profiles are resolved (with new case-insensitive search)
# 3. Profiles are saved to domain configuration file (e.g., contoso.com.psd1)
# 4. No "empty string" error
```

### Test Scenario 2: Direct Function Call
```powershell
# Test function directly with explicit settings file
$profiles = @(
    @{ name = "Corporate Profile"; id = $null }
)

$result = Resolve-MigratedAutopilotProfiles `
    -accessToken $token `
    -autopilotProfiles $profiles `
    -domain "test.com" `
    -SettingsFile "$PWD\settings.psd1"

# Expected: Profiles saved to test.com.psd1 successfully
```

### Verification Steps
1. Check that domain configuration file is created (e.g., `domain.psd1`)
2. Verify file contains `autopilotProfilesToInclude` array with resolved profiles
3. Confirm no WARNING messages about empty strings
4. Check logs for "Using settings file: ..." message

## Related Issues
- Initial issue: Domain configuration save failing during migration
- Related to: PR #324 (migration feature)
- Connected to: Case-insensitive search enhancement (same session)

## Benefits
1. **Reliable path resolution**: Settings file path explicitly passed through call chain
2. **Better debugging**: Added verbose logging of settings file path being used
3. **Backward compatible**: Default value maintains existing behavior for other callers
4. **Consistent pattern**: Follows same parameter pattern used in other functions

## Related Files
- `functions/setupFunctions/Resolve-MigratedAutopilotProfiles.ps1`
- `functions/setupFunctions/Update-Setting.ps1`
- `functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1`
- `main.ps1`
