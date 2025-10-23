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
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles nested hashtables recursively
        - Preserves array values from existing configuration
        - Uses regular hashtables for broader compatibility
        - For force overwrite scenarios, use Get-ApplicationDefaults -DefaultType "Overwrite"
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$ExistingConfig,
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$DefaultConfig,
        [bool]$PreserveExisting = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting configuration merge"
    Write-Log -logFile $logFile -module $functionName -Message "Starting configuration merge"
    
    # Helper function to perform recursive merge
    function MergeHashtables()
    {
        [CmdletBinding()]
        param(
            [System.Collections.Hashtable]$existing,
            [System.Collections.Hashtable]$defaults,
            [bool]$preserveExisting
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Starting hashtable merge"
        Write-Log -logFile $logFile -module $functionName -Message "Starting hashtable merge"
        $merged = @{}
        $changesMade = $false
        
        # First, copy all existing values
        Write-Verbose "[$functionName] Copying existing values"
        Write-Log -logFile $logFile -module $functionName -Message "Copying existing values"
        foreach ($key in $existing.Keys)
        {
            $merged[$key] = $existing[$key]
            Write-Verbose "[$functionName] Copied existing key: $key"
            Write-Log -logFile $logFile -module $functionName -Message "Copied existing key: $key"
        }
        
        # Then, add any missing keys from defaults
        Write-Verbose "[$functionName] Adding missing keys from defaults"
        Write-Log -logFile $logFile -module $functionName -Message "Adding missing keys from defaults"
        foreach ($key in $defaults.Keys)
        {
            Write-Verbose "[$functionName] Checking key: $key"
            Write-Log -logFile $logFile -module $functionName -Message "Checking key: $key"
            if (-not $merged.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Adding missing key: $key"
                $merged[$key] = $defaults[$key]
                $changesMade = $true
            }
            elseif ($merged[$key] -is [System.Collections.Hashtable] -and $defaults[$key] -is [System.Collections.Hashtable])
            {
                # Recursively merge nested hashtables
                Write-Verbose "[$functionName] Merging nested hashtable: $key"
                Write-Log -logFile $logFile -module $functionName -Message "Merging nested hashtable: $key"
                $nestedResult = MergeHashtables -existing $merged[$key] -defaults $defaults[$key] -preserveExisting $preserveExisting
                if ($nestedResult[0])  # Changes were made
                {
                    $merged[$key] = $nestedResult[1]
                    $changesMade = $true
                    Write-Log -logFile $logFile -module $functionName -Message "Merged nested hashtable: $key"
                    Write-Verbose "[$functionName] Merged nested hashtable: $key"
                }
            }
            elseif (-not $preserveExisting)
            {
                # Overwrite existing value with default if PreserveExisting is false
                Write-Verbose "[$functionName] Overwriting existing key: $key"              
                Write-Log -logFile $logFile -module $functionName -Message "Overwriting existing key: $key"
                $merged[$key] = $defaults[$key]
            }
            elseif (-not $preserveExisting)
            {
                # Overwrite existing value with default if PreserveExisting is false
                Write-Verbose "[$functionName] Overwriting existing key: $key"
                Write-Log -logFile $logFile -module $functionName -Message "Overwriting existing key: $key"
                $merged[$key] = $defaults[$key]
                $changesMade = $true
            }
            #If the key is 'domain' and it has a string or whitespace, we consider it a change
            if ($key -eq 'domain' -and $merged[$key] -is [string] -and ([string]::IsNullOrWhiteSpace($merged[$key]) -or $merged[$key] -ne $domain))
            {
                Write-Verbose "[$functionName] Domain key is empty or whitespace"
                Write-Log -logFile $logFile -module $functionName -Message "Domain key is empty or whitespace"
                #set the value of the key to $domain
                $merged[$key] = $domain
                $changesMade = $true
            }
        }
        Write-Verbose "[$functionName] Hashtable merge completed"
        Write-Verbose "[$functionName] Changes made: $changesMade"
        Write-Log -logFile $logFile -module $functionName -Message "Hashtable merge completed"
        Write-Log -logFile $logFile -module $functionName -Message "Changes made: $changesMade"
        return $changesMade, $merged
    }
    
    try
    {
        # Perform the merge
        Write-Verbose "[$functionName] Performing hashtable merge"
        Write-Log -logFile $logFile -module $functionName -Message "Performing hashtable merge"
        $mergeResult = MergeHashtables -existing $ExistingConfig -defaults $DefaultConfig -preserveExisting $PreserveExisting
        $changesMade = $mergeResult[0]
        Write-Verbose "[$functionName] Changes made: $changesMade"
        Write-Log -logFile $logFile -module $functionName -Message "Changes made: $changesMade"
        $mergedConfig = $mergeResult[1]
        Write-Verbose "[$functionName] Merged configuration: $($mergeResult[1])"
        Write-Log -logFile $logFile -module $functionName -Message "Merged configuration: $($mergeResult[1])"
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
        Write-Log -logFile $logFile -module $functionName -Message "Error during configuration merge: $($_.Exception.Message)"
        throw
    }
}

