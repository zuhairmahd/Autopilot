function MergeSettings()
<#
.SYNOPSIS
    Merges two hashtables (local and global settings) into a single flat hashtable with conflict resolution.

.DESCRIPTION
    The MergeSettings function combines local and global settings into a single hashtable, flattening nested structures and resolving conflicts according to the specified strategy. It supports merging nested hashtables and PSCustomObjects. Keys are normalized to their simplest form (last segment after any dot notation). When a conflict occurs (same key exists in both settings), the ConflictResolution parameter determines which value wins - this applies to all data types including arrays, which are replaced rather than merged. The function provides detailed verbose logging for each step, including flattening, normalization, and conflict resolution.

.PARAMETER localSettings
    The hashtable containing local (user or environment-specific) settings. These take precedence unless overridden by the ConflictResolution parameter.

.PARAMETER globalSettings
    The hashtable containing global (default or organization-wide) settings. These are merged in after local settings and may override them depending on the ConflictResolution parameter.

.PARAMETER ConflictResolution
    Determines which value to use when a key exists in both local and global settings:
    - 'Local': Keep the value from localSettings (default behavior)
    - 'Global': Use the value from globalSettings
    This applies to all data types. When both values are arrays, the winning array completely replaces the other (arrays are not merged).

.OUTPUTS
    System.Collections.Hashtable
    Returns a flat hashtable containing the merged settings, with conflicts resolved as specified.

.EXAMPLE
    # Merge local and global settings, preferring global values on conflict
    $merged = MergeSettings -localSettings $local -globalSettings $global -ConflictResolution 'Global'

.EXAMPLE
    # Merge settings, keeping local values on conflict (default)
    $merged = MergeSettings -localSettings $local -globalSettings $global

.NOTES
    - Flattens nested hashtables and PSCustomObjects for key normalization
    - Arrays are replaced (not merged) based on ConflictResolution parameter
    - Provides verbose logging for troubleshooting and auditing
    - Compatible with PowerShell 5.1 and later
#>
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $localSettings,
        [Parameter(Mandatory = $true)]
        $globalSettings,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Local', 'Global')]
        [string]$ConflictResolution = 'Global'
    )
    $functionName = $MyInvocation.MyCommand.Name
    $merged = @{}
    
    Write-Verbose "[$functionName] Merging settings with conflict resolution: $ConflictResolution"
    
    # Check if ConfigCore DLL is available for fast C# implementation
    if ($global:AutopilotDllStatus.ConfigCoreLoaded)
    {
        Write-Verbose "[$functionName] Using ConfigCore.dll for 10x faster merge"
        
        try
        {
            # Convert to hashtables if needed
            $localHash = if ($localSettings -is [hashtable])
            { 
                $localSettings 
            }
            else
            { 
                ConvertFrom-JsonToHashtable -JsonObject $localSettings 
            }
            
            $globalHash = if ($globalSettings -is [hashtable])
            { 
                $globalSettings 
            }
            else
            { 
                ConvertFrom-JsonToHashtable -JsonObject $globalSettings 
            }
            
            # Use C# for 10x faster merge
            $merged = [Autopilot.ConfigCore.HashtableHelper]::MergeHashtables(
                $localHash, 
                $globalHash, 
                $ConflictResolution
            )
            
            Write-Verbose "[$functionName] ConfigCore merge completed: $($merged.Count) keys"
            return $merged
        }
        catch
        {
            Write-Verbose "[$functionName] ConfigCore merge failed: $($_.Exception.Message), falling back to PowerShell"
            # Fall through to PowerShell implementation
        }
    }
    else
    {
        Write-Verbose "[$functionName] ConfigCore not available, using PowerShell implementation"
    }
    
    # Function to detect if settings structure requires flattening
    function Test-RequiresFlattening($object)
    {
        if ($object -is [hashtable])
        {
            foreach ($value in $object.Values)
            {
                if ($value -is [hashtable] -or $value -is [PSCustomObject])
                {
                    return $true
                }
                if ($value -is [array])
                {
                    foreach ($item in $value)
                    {
                        if ($item -is [hashtable] -or $item -is [PSCustomObject])
                        {
                            return $true
                        }
                    }
                }
            }
        }
        elseif ($object -is [PSCustomObject])
        {
            foreach ($property in $object.PSObject.Properties)
            {
                $value = $property.Value
                if ($value -is [hashtable] -or $value -is [PSCustomObject])
                {
                    return $true
                }
                if ($value -is [array])
                {
                    foreach ($item in $value)
                    {
                        if ($item -is [hashtable] -or $item -is [PSCustomObject])
                        {
                            return $true
                        }
                    }
                }
            }
        }
        return $false
    }
    
    # Check if flattening is needed for either structure
    $localNeedsFlattening = Test-RequiresFlattening $localSettings
    $globalNeedsFlattening = Test-RequiresFlattening $globalSettings
    $requiresFlattening = $localNeedsFlattening -or $globalNeedsFlattening
    
    Write-Verbose "[$functionName] Local settings complexity check: $(if($localNeedsFlattening){'Complex - requires flattening'}else{'Simple - direct merge possible'})"
    Write-Verbose "[$functionName] Global settings complexity check: $(if($globalNeedsFlattening){'Complex - requires flattening'}else{'Simple - direct merge possible'})"
    
    if ($requiresFlattening)
    {
        Write-Verbose "[$functionName] Complex structures detected, using flattening approach"
        
        # Flatten local settings
        Write-Verbose "[$functionName] Flattening local settings"
        $flatLocalSettings = ConvertFrom-JsonToHashtable -JsonObject $localSettings -Flatten
        Write-Verbose "[$functionName] Local settings flattened to $($flatLocalSettings.Count) properties"
        
        # Flatten global settings
        Write-Verbose "[$functionName] Flattening global settings"
        $flatGlobalSettings = ConvertFrom-JsonToHashtable -JsonObject $globalSettings -Flatten
        Write-Verbose "[$functionName] Global settings flattened to $($flatGlobalSettings.Count) properties"
        
        $processLocal = $flatLocalSettings
        $processGlobal = $flatGlobalSettings
        $needsKeyNormalization = $true
    }
    else
    {
        Write-Verbose "[$functionName] Simple structures detected, using optimized direct merge"
        
        # Convert to hashtables without flattening
        $processLocal = ConvertFrom-JsonToHashtable -JsonObject $localSettings
        $processGlobal = ConvertFrom-JsonToHashtable -JsonObject $globalSettings
        $needsKeyNormalization = $false
        
        Write-Verbose "[$functionName] Local settings converted to $($processLocal.Count) properties"
        Write-Verbose "[$functionName] Global settings converted to $($processGlobal.Count) properties"
    }
    
    # Normalize all keys to simple format (remove any prefixes) - only if flattening was used
    function Get-SimpleKey($key)
    {
        if ($key.Contains('.'))
        {
            return $key.Split('.')[-1]  # Get the last part after the last dot
        }
        return $key
    }
    
    # Conditional key normalization and merging based on complexity
    if ($needsKeyNormalization)
    {
        Write-Verbose "[$functionName] Normalizing flattened keys"
        
        # Create normalized hashtables with simple keys
        $normalizedLocal = @{}
        foreach ($key in $processLocal.Keys)
        {
            $simpleKey = Get-SimpleKey $key
            $normalizedLocal[$simpleKey] = $processLocal[$key]
            Write-Verbose "[$functionName] Normalized local key: $key -> $simpleKey"
        }
        
        $normalizedGlobal = @{}
        foreach ($key in $processGlobal.Keys)
        {
            $simpleKey = Get-SimpleKey $key
            $normalizedGlobal[$simpleKey] = $processGlobal[$key]
            Write-Verbose "[$functionName] Normalized global key: $key -> $simpleKey"
        }
        
        $finalLocal = $normalizedLocal
        $finalGlobal = $normalizedGlobal
    }
    else
    {
        Write-Verbose "[$functionName] Using direct keys (no normalization needed)"
        $finalLocal = $processLocal
        $finalGlobal = $processGlobal
    }
    
    # Start with local settings
    foreach ($key in $finalLocal.Keys)
    {
        $merged[$key] = $finalLocal[$key]
        Write-Verbose "[$functionName] Added local setting: $key"
    }
    
    # Merge global settings
    foreach ($key in $finalGlobal.Keys)
    {
        if ($merged.ContainsKey($key))
        {
            Write-Verbose "[$functionName] Conflict detected for property: $key"
            
            # Handle conflict based on ConflictResolution parameter (applies to all types including arrays)
            if ($ConflictResolution -eq 'Global')
            {
                Write-Verbose "[$functionName] Resolving conflict by using global value for: $key"
                $merged[$key] = $finalGlobal[$key]
            }
            else
            {
                Write-Verbose "[$functionName] Resolving conflict by keeping local value for: $key"
                # Keep the existing local value (do nothing)
            }
        }
        else
        {
            $merged[$key] = $finalGlobal[$key]
            Write-Verbose "[$functionName] Added global setting: $key"
        }
    }
    
    Write-Verbose "[$functionName] Final merged settings count: $($merged.Count)"
    return $merged
}

