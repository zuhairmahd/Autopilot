function Merge-ConfigurationDefaults()
{
    <#
    .SYNOPSIS
        Merges default configuration values into an existing configuration object.
    
    .DESCRIPTION
        This function performs a deep merge of default configuration values into an existing 
        configuration object. It preserves existing values while adding any missing keys 
        from the defaults. This is used to ensure configuration files stay up-to-date
        with new default settings when the application is updated.
    
    .PARAMETER ExistingConfig
        The existing configuration hashtable to merge defaults into.
    
    .PARAMETER DefaultConfig
        The default configuration hashtable containing all current default values.
    
    .PARAMETER PreserveExisting
        If $true (default), existing values in ExistingConfig are preserved.
        If $false, default values will overwrite existing values.
    
    .PARAMETER OverwriteSettings
        Optional PSCustomObject containing settings that should be forcibly overwritten
        regardless of the PreserveExisting parameter value. Keys found in this object
        will overwrite corresponding values in the merged configuration.
    
    .OUTPUTS
        System.Collections.Hashtable or $null
        Returns the merged configuration hashtable if changes were made, or $null if no merge was needed.
    
    .EXAMPLE
        $merged = Merge-ConfigurationDefaults -ExistingConfig $currentSettings -DefaultConfig $defaultSettings
        if ($merged) {
            # Configuration was updated with missing values
            $currentSettings = $merged
        } else {
            # No changes were needed
        }
        
        Merges default settings into current settings, preserving existing values.
    
    .EXAMPLE
        $overwrite = [PSCustomObject]@{ CheckForUpdates = $true }
        $merged = Merge-ConfigurationDefaults -ExistingConfig $currentSettings -DefaultConfig $defaultSettings -OverwriteSettings $overwrite
        
        Merges default settings and forces CheckForUpdates to be overwritten with the specified value.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles nested hashtables recursively
        - Preserves array values from existing configuration
        - Uses regular hashtables for broader compatibility
        - OverwriteSettings provides granular control over specific setting values
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$ExistingConfig,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$DefaultConfig,
        [bool]$PreserveExisting = $true,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$OverwriteSettings = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting configuration merge"
    Write-Log -logFile $logFile -module $functionName -Message "Starting configuration merge"
    
    # Convert OverwriteSettings to hashtable if provided
    $overwriteHash = $null
    if ($OverwriteSettings)
    {
        Write-Verbose "[$functionName] Converting OverwriteSettings to hashtable for processing"
        Write-Log -logFile $logFile -module $functionName -Message "Converting OverwriteSettings to hashtable for processing"
        
        # Use a simplified conversion approach for the overwrite settings
        $overwriteHash = @{}
        if ($OverwriteSettings -is [PSCustomObject])
        {
            $OverwriteSettings.PSObject.Properties | ForEach-Object {
                $overwriteHash[$_.Name] = $_.Value
            }
        }
        elseif ($OverwriteSettings -is [hashtable])
        {
            $overwriteHash = $OverwriteSettings
        }
        
        Write-Verbose "[$functionName] OverwriteSettings converted to $($overwriteHash.Count) properties"
        Write-Log -logFile $logFile -module $functionName -Message "OverwriteSettings converted to $($overwriteHash.Count) properties"
    }
    
    # Helper function to check if a key should be overwritten
    function ShouldOverwriteKey($key, $fullPath = '')
    {
        if (-not $overwriteHash) { return $false }
        
        # Check both the simple key and the full path
        $keysToCheck = @($key)
        if ($fullPath) { $keysToCheck += $fullPath }
        
        foreach ($checkKey in $keysToCheck)
        {
            if ($overwriteHash.ContainsKey($checkKey))
            {
                Write-Verbose "[$functionName] Key '$checkKey' found in OverwriteSettings - will be overwritten"
                Write-Log -logFile $logFile -module $functionName -Message "Key '$checkKey' found in OverwriteSettings - will be overwritten"
                return $true
            }
        }
        return $false
    }
    
    try
    {
        # Track whether any changes were made
        $changesMade = $false
        
        # Create a copy of the existing config to avoid modifying the original
        $mergedConfig = @{}
        
        # First, copy all existing values
        foreach ($key in $ExistingConfig.Keys)
        {
            $mergedConfig[$key] = $ExistingConfig[$key]
        }
        
        # Then, add any missing keys from defaults
        foreach ($key in $DefaultConfig.Keys)
        {
            if (-not $mergedConfig.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Adding missing key: $key"
                $mergedConfig[$key] = $DefaultConfig[$key]
                $changesMade = $true
            }
            elseif ($mergedConfig[$key] -is [System.Collections.Hashtable] -and $DefaultConfig[$key] -is [System.Collections.Hashtable])
            {
                # Recursively merge nested hashtables
                Write-Verbose "[$functionName] Merging nested hashtable: $key"
                
                # Create nested overwrite settings if any exist for this key
                $nestedOverwrite = $null
                if ($OverwriteSettings)
                {
                    $nestedOverwrite = [PSCustomObject]@{}
                    $hasNestedOverwrites = $false
                    
                    # Check for nested overwrite settings with dot notation
                    $OverwriteSettings.PSObject.Properties | ForEach-Object {
                        if ($_.Name.StartsWith("$key."))
                        {
                            $nestedKey = $_.Name.Substring($key.Length + 1)
                            $nestedOverwrite | Add-Member -MemberType NoteProperty -Name $nestedKey -Value $_.Value
                            $hasNestedOverwrites = $true
                        }
                    }
                    
                    if (-not $hasNestedOverwrites)
                    {
                        $nestedOverwrite = $null
                    }
                }
                
                $nestedMerge = Merge-ConfigurationDefaults -ExistingConfig $mergedConfig[$key] -DefaultConfig $DefaultConfig[$key] -PreserveExisting $PreserveExisting -OverwriteSettings $nestedOverwrite
                if ($nestedMerge)
                {
                    $mergedConfig[$key] = $nestedMerge
                    $changesMade = $true
                }
            }
            elseif (-not $PreserveExisting -or (ShouldOverwriteKey $key))
            {
                # Overwrite existing value with default if PreserveExisting is false OR if key is in OverwriteSettings
                if (ShouldOverwriteKey $key)
                {
                    Write-Verbose "[$functionName] Force overwriting existing key due to OverwriteSettings: $key"
                    Write-Log -logFile $logFile -module $functionName -Message "Force overwriting existing key due to OverwriteSettings: $key"
                }
                else
                {
                    Write-Verbose "[$functionName] Overwriting existing key: $key"
                }
                $mergedConfig[$key] = $DefaultConfig[$key]
                $changesMade = $true
            }
            # If PreserveExisting is true and key is not in OverwriteSettings, keep the existing value
        }
        
        # Apply any overwrite settings that specify values directly (not just forcing overwrite from defaults)
        if ($overwriteHash)
        {
            Write-Verbose "[$functionName] Applying direct overwrite settings"
            Write-Log -logFile $logFile -module $functionName -Message "Applying direct overwrite settings"
            foreach ($overwriteKey in $overwriteHash.Keys)
            {
                # Handle flattened keys (dot notation)
                if ($overwriteKey.Contains('.'))
                {
                    $keyParts = $overwriteKey.Split('.')
                    $currentConfig = $mergedConfig
                    
                    # Navigate to the nested location
                    for ($i = 0; $i -lt $keyParts.Length - 1; $i++)
                    {
                        $part = $keyParts[$i]
                        if (-not $currentConfig.ContainsKey($part))
                        {
                            $currentConfig[$part] = @{}
                        }
                        elseif ($currentConfig[$part] -isnot [System.Collections.Hashtable])
                        {
                            # Convert to hashtable if it's not already
                            $currentConfig[$part] = @{}
                        }
                        $currentConfig = $currentConfig[$part]
                    }
                    
                    # Set the final value
                    $finalKey = $keyParts[-1]
                    $oldValue = if ($currentConfig.ContainsKey($finalKey)) { $currentConfig[$finalKey] } else { "NOT_SET" }
                    $currentConfig[$finalKey] = $overwriteHash[$overwriteKey]
                    $changesMade = $true
                    
                    Write-Verbose "[$functionName] Applied overwrite setting '$overwriteKey': $oldValue -> $($overwriteHash[$overwriteKey])"
                    Write-Log -logFile $logFile -module $functionName -Message "Applied overwrite setting '$overwriteKey': $oldValue -> $($overwriteHash[$overwriteKey])"
                }
                else
                {
                    # Simple key
                    if ($mergedConfig.ContainsKey($overwriteKey))
                    {
                        $oldValue = $mergedConfig[$overwriteKey]
                        $mergedConfig[$overwriteKey] = $overwriteHash[$overwriteKey]
                        $changesMade = $true
                        
                        Write-Verbose "[$functionName] Applied overwrite setting '$overwriteKey': $oldValue -> $($overwriteHash[$overwriteKey])"
                        Write-Log -logFile $logFile -module $functionName -Message "Applied overwrite setting '$overwriteKey': $oldValue -> $($overwriteHash[$overwriteKey])"
                    }
                }
            }
        }
        
        if ($changesMade)
        {
            Write-Verbose "[$functionName] Configuration merge completed with changes"
            Write-Log -logFile $logFile -module $functionName -Message "Configuration merge completed with changes"
            return $mergedConfig
        }
        else
        {
            Write-Verbose "[$functionName] No configuration changes needed"
            Write-Log -logFile $logFile -module $functionName -Message "No configuration changes needed"
            return $null
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error during configuration merge: $($_.Exception.Message)"
        throw
    }
}

