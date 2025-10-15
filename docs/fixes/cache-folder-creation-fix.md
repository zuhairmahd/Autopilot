# Cache Folder Creation Fix

## Issue

During Pester test runs, GUID-named folders were being created in the project root directory:
- `6d93c179-3c7c-4a84-802e-58026e237da2/`
- `dc2dc04f-586a-41c4-895d-21bb913a7e22/`
- `fdbd1da2-5ce3-4831-b693-2bb809748bf8/`

These folders were empty and should not have been created in the project root.

## Root Cause

The issue was in `GetGraphAccessToken.ps1` (line 259):

```powershell
# Old code
if ([string]::IsNullOrWhiteSpace($configFile) -or -not (Test-Path $configFile))
{
    Write-Verbose "[$functionName] Config file is empty or doesn't exist, using current directory for cache"
    $cacheFolder = $PWD.Path  # ← Problem: Uses current working directory
}
```

When tests run:
1. The current working directory (`$PWD.Path`) is the project root
2. If no config file is provided, `GetGraphAccessToken` sets `$cacheFolder` to the project root
3. Later, `Save-TokenToCache` creates the cache folder if it doesn't exist: 
   ```powershell
   New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
   ```
4. This creates GUID-named folders in the project root

## Why GUID Names?

The GUID names likely came from one of these scenarios:
- Test helper functions creating temporary folders with GUID names
- Config files being created in temp paths containing GUIDs
- Cache folder paths inheriting GUID components from test setup

## Solution

Modified `GetGraphAccessToken.ps1` to use the system temp directory instead of the current working directory:

```powershell
# New code
if ([string]::IsNullOrWhiteSpace($configFile) -or -not (Test-Path $configFile))
{
    # Use temp directory instead of current directory to avoid creating folders in project root
    $tempPath = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $cacheFolder = Join-Path $tempPath "AutopilotCache"
    Write-Verbose "[$functionName] Config file is empty or doesn't exist, using temp directory for cache: $cacheFolder"
}
```

### Benefits

1. **No project root pollution** - Cache folders are created in `$env:TEMP\AutopilotCache` instead of the project root
2. **Consistent behavior** - All test runs use the same cache location
3. **Automatic cleanup** - Temp directories are cleaned by the OS periodically
4. **Cross-platform compatible** - Falls back to `[System.IO.Path]::GetTempPath()` if `$env:TEMP` is not set

## Verification

After this fix, tests should:
- No longer create GUID folders in the project root
- Create cache folders in `%TEMP%\AutopilotCache` (typically `C:\Users\<username>\AppData\Local\Temp\AutopilotCache`)
- Continue to pass all existing tests without modification

## Cleanup

The existing GUID folders in the project root can be safely deleted:
```powershell
Remove-Item -Path "c:\Users\zuhai\code\Autopilot\6d93c179-3c7c-4a84-802e-58026e237da2" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "c:\Users\zuhai\code\Autopilot\dc2dc04f-586a-41c4-895d-21bb913a7e22" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "c:\Users\zuhai\code\Autopilot\fdbd1da2-5ce3-4831-b693-2bb809748bf8" -Force -Recurse -ErrorAction SilentlyContinue
```

## .gitignore Update (Optional)

Consider adding a pattern to `.gitignore` to prevent future GUID folders from being committed:
```
# Prevent accidental GUID-named folders
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]/
```

## Related Files

- Modified: `functions/graphFunctions/GetGraphAccessToken.ps1`
- Related: `functions/graphFunctions/Save-TokenToCache.ps1`
- Test helpers: `tests/Helpers/AutopilotTestHelpers.psm1`

## Date

October 15, 2025
