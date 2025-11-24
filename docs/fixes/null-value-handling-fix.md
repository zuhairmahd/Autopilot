# Null Value Handling Fix

## Issue Description

When migrating the `arabictutor.com.json` file, the following error occurred:

```
ERROR: [Export-PowerShellDataFile] Export failed: You cannot call a method on a null-valued expression.
ERROR: [Convert-DomainJsonToPsd1] Failed to convert arabictutor.com.json: You cannot call a method on a null-valued expression.
```

## Root Cause

The error "You cannot call a method on a null-valued expression" was caused by attempting to access `.GetType().Name` on null values in two locations:

1. **ConvertTo-Psd1String.ps1** (line 52): When processing hashtable keys, the code tried to log the value type before checking if the value was null
2. **Empty array handling**: The `desiredAutopilotProfiles` field in the JSON contained an empty array, which depending on how it was processed, could become null

## Files Modified

### 1. ConvertTo-Psd1String.ps1

**Changes Made:**
- Added null check **before** attempting to access `.GetType().Name`
- Reordered the type checking logic to handle null values first
- Moved null check to the beginning of the value processing chain within arrays
- Removed duplicate null check that was occurring later in the flow

**Before:**
```powershell
$result += "$childIndent$validKey = "
Write-Verbose "[$functionName] Processing key: $key with value type: $($value.GetType().Name)"

if ($value -is [hashtable] -or $value -is [System.Collections.Specialized.OrderedDictionary])
{
    # ... process hashtable
}
elseif ($null -eq $value)
{
    # ... handle null (too late!)
}
```

**After:**
```powershell
$result += "$childIndent$validKey = "

# Handle null values first before trying to access GetType()
if ($null -eq $value)
{
    Write-Verbose "[$functionName] Processing key: $key with null value"
    $result += '$null'
}
elseif ($value -is [hashtable] -or $value -is [System.Collections.Specialized.OrderedDictionary])
{
    Write-Verbose "[$functionName] Processing key: $key with value type: $($value.GetType().Name)"
    # ... process hashtable safely
}
```

**Array Item Processing:**
```powershell
foreach ($item in $value)
{
    $result += "$childIndent    "
    
    if ($null -eq $item)
    {
        Write-Verbose "[$functionName] Processing null item in array"
        $result += '$null'
    }
    elseif ($item -is [hashtable] ...)
    {
        # Safe to access .GetType() here
    }
    # ... rest of type checks
}
```

### 2. Invoke-SettingsMigration.ps1

**Changes Made:**
- Added explicit null/empty array check for `desiredAutopilotProfiles` before processing
- Ensures empty arrays remain empty arrays instead of potentially becoming null

**Before:**
```powershell
elseif ($key -eq 'desiredAutopilotProfiles')
{
    $desiredProfiles = $settings['desiredAutopilotProfiles']
    $transformedProfiles = @()
    
    if ($desiredProfiles -is [array])
    {
        foreach ($profile in $desiredProfiles)
        {
            # ... transform profiles
        }
    }
    # ... else cases
}
```

**After:**
```powershell
elseif ($key -eq 'desiredAutopilotProfiles')
{
    $desiredProfiles = $settings['desiredAutopilotProfiles']
    $transformedProfiles = @()
    
    if ($null -eq $desiredProfiles -or ($desiredProfiles -is [array] -and $desiredProfiles.Count -eq 0))
    {
        # Null or empty array - keep as empty array
        Write-Verbose "[$functionName] desiredAutopilotProfiles is null or empty, setting empty array"
        $transformedProfiles = @()
    }
    elseif ($desiredProfiles -is [array])
    {
        foreach ($profile in $desiredProfiles)
        {
            # ... transform profiles
        }
    }
    # ... else cases
}
```

## Testing Scenarios

The fix now properly handles:

1. **Null values in hashtables**: `@{ key = $null }`
2. **Empty arrays**: `@{ profiles = @() }`
3. **Null array items**: `@{ items = @($null, "value", $null) }`
4. **Null in nested structures**: Any level of nesting with null values

## Expected Output for arabictutor.com.json

With `desiredAutopilotProfiles` being an empty array:

```powershell
autopilotProfilesToInclude = @()
```

## Prevention

**Best Practice:** Always check for null before accessing object methods or properties in PowerShell:

```powershell
# ❌ Bad - Can throw error
Write-Verbose "Type: $($value.GetType().Name)"

# ✅ Good - Safe
if ($null -eq $value) {
    Write-Verbose "Value is null"
} else {
    Write-Verbose "Type: $($value.GetType().Name)"
}

# ✅ Also Good - Using null-conditional
Write-Verbose "Type: $($value?.GetType()?.Name ?? 'null')"  # PowerShell 7+
```

## Impact

This fix ensures the migration wizard can handle:
- Empty configuration arrays
- Null configuration values
- Partially configured domain files
- Edge cases where JSON deserialization produces unexpected null values

All migration scenarios should now complete successfully without throwing method access errors.
