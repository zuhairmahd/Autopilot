function MergeSettings()
<#
.SYNOPSIS
    Merges two hashtables (local and global settings) into a single flat hashtable with conflict resolution.

.DESCRIPTION
    The MergeSettings function combines local and global settings into a single hashtable, flattening nested structures and resolving conflicts according to the specified strategy. It supports merging arrays, nested hashtables, and PSCustomObjects. Keys are normalized to their simplest form (last segment after any dot notation). The function provides detailed verbose logging for each step, including flattening, normalization, and conflict resolution.

.PARAMETER localSettings
    The hashtable containing local (user or environment-specific) settings. These take precedence unless overridden by the ConflictResolution parameter.

.PARAMETER globalSettings
    The hashtable containing global (default or organization-wide) settings. These are merged in after local settings and may override them depending on the ConflictResolution parameter.

.PARAMETER ConflictResolution
    Determines which value to use when a key exists in both local and global settings:
    - 'Local': Keep the value from localSettings (default behavior)
    - 'Global': Use the value from globalSettings
    If both values are arrays, they are merged.

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
    - Merges arrays when both local and global values are arrays
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
    
    # Helper function to flatten a nested object into a flat hashtable
    function ConvertTo-FlatHashtable($object, $prefix = '')
    {
        $flatHash = @{}
        $functionName = $MyInvocation.MyCommand.Name
        if ($object -is [hashtable] -or $object -is [System.Collections.IDictionary])
        {
            Write-Verbose "[$functionName] Flattening hashtable/dictionary with $($object.Keys.Count) keys"
            foreach ($key in $object.Keys)
            {
                $fullKey = if ($prefix)
                {
                    "$prefix.$key" 
                }
                else
                {
                    $key 
                }
                $value = $object[$key]
                
                if (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                    ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0))
                {
                    Write-Verbose "[$functionName] Found nested object at key: $fullKey"
                    $nestedFlat = ConvertTo-FlatHashtable $value $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $flatHash[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding flat key: $fullKey"
                    $flatHash[$fullKey] = $value
                }
            }
        }
        elseif ($object -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Flattening PSCustomObject with $($object.PSObject.Properties.Count) properties"
            foreach ($property in $object.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
            {
                $fullKey = if ($prefix)
                {
                    "$prefix.$($property.Name)" 
                }
                else
                {
                    $property.Name 
                }
                $value = $property.Value
                
                if (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                    ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0))
                {
                    Write-Verbose "[$functionName] Found nested object at property: $fullKey"
                    $nestedFlat = ConvertTo-FlatHashtable $value $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $flatHash[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding flat property: $fullKey"
                    $flatHash[$fullKey] = $value
                }
            }
        }
        else
        {
            # If it's a simple value, just return it with the prefix as key
            if ($prefix)
            {
                $flatHash[$prefix] = $object
            }
        }
        
        return $flatHash
    }    Write-Verbose "[$functionName] Merging settings with conflict resolution: $ConflictResolution"
    
    # Flatten local settings
    Write-Verbose "[$functionName] Flattening local settings"
    $flatLocalSettings = ConvertTo-FlatHashtable $localSettings
    Write-Verbose "[$functionName] Local settings flattened to $($flatLocalSettings.Count) properties"
    
    # Flatten global settings
    Write-Verbose "[$functionName] Flattening global settings"
    $flatGlobalSettings = ConvertTo-FlatHashtable $globalSettings
    Write-Verbose "[$functionName] Global settings flattened to $($flatGlobalSettings.Count) properties"
    
    # Normalize all keys to simple format (remove any prefixes)
    function Get-SimpleKey($key)
    {
        if ($key.Contains('.'))
        {
            return $key.Split('.')[-1]  # Get the last part after the last dot
        }
        return $key
    }
    
    # Create normalized hashtables with simple keys
    $normalizedLocal = @{}
    foreach ($key in $flatLocalSettings.Keys)
    {
        $simpleKey = Get-SimpleKey $key
        $normalizedLocal[$simpleKey] = $flatLocalSettings[$key]
        Write-Verbose "[$functionName] Normalized local key: $key -> $simpleKey"
    }
    
    $normalizedGlobal = @{}
    foreach ($key in $flatGlobalSettings.Keys)
    {
        $simpleKey = Get-SimpleKey $key
        $normalizedGlobal[$simpleKey] = $flatGlobalSettings[$key]
        Write-Verbose "[$functionName] Normalized global key: $key -> $simpleKey"
    }
    
    # Start with local settings
    foreach ($key in $normalizedLocal.Keys)
    {
        $merged[$key] = $normalizedLocal[$key]
        Write-Verbose "[$functionName] Added local setting: $key"
    }
    
    # Merge global settings
    foreach ($key in $normalizedGlobal.Keys)
    {
        if ($merged.ContainsKey($key))
        {
            Write-Verbose "[$functionName] Conflict detected for property: $key"
            
            # If both are arrays, merge arrays
            if ($merged[$key] -is [System.Collections.IEnumerable] -and
                $normalizedGlobal[$key] -is [System.Collections.IEnumerable] -and
                ($merged[$key] -isnot [string]) -and
                ($normalizedGlobal[$key] -isnot [string]))
            {
                Write-Verbose "[$functionName] Both values are arrays, merging arrays for: $key"
                $merged[$key] = @($merged[$key] + $normalizedGlobal[$key])
            }
            else
            {
                # Handle conflict based on ConflictResolution parameter
                if ($ConflictResolution -eq 'Global')
                {
                    Write-Verbose "[$functionName] Resolving conflict by using global value for: $key"
                    $merged[$key] = $normalizedGlobal[$key]
                }
                else
                {
                    Write-Verbose "[$functionName] Resolving conflict by keeping local value for: $key"
                    # Keep the existing local value (do nothing)
                }
            }
        }
        else
        {
            $merged[$key] = $normalizedGlobal[$key]
            Write-Verbose "[$functionName] Added global setting: $key"
        }
    }
    
    Write-Verbose "[$functionName] Final merged settings count: $($merged.Count)"
    return $merged
}

