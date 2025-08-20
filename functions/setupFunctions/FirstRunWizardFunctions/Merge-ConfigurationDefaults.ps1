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
    function MergeHashtables($existing, $defaults, $preserveExisting)
    {
        $merged = @{}
        $changesMade = $false
        
        # First, copy all existing values
        foreach ($key in $existing.Keys)
        {
            $merged[$key] = $existing[$key]
        }
        
        # Then, add any missing keys from defaults
        foreach ($key in $defaults.Keys)
        {
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
                $nestedResult = MergeHashtables -existing $merged[$key] -defaults $defaults[$key] -preserveExisting $preserveExisting
                if ($nestedResult[0])  # Changes were made
                {
                    $merged[$key] = $nestedResult[1]
                    $changesMade = $true
                }
            }
            elseif (-not $preserveExisting)
            {
                # Overwrite existing value with default if PreserveExisting is false
                Write-Verbose "[$functionName] Overwriting existing key: $key"
                $merged[$key] = $defaults[$key]
                $changesMade = $true
            }
            # If PreserveExisting is true, keep the existing value
        }
        
        return $changesMade, $merged
    }
    
    try
    {
        # Perform the merge
        $mergeResult = MergeHashtables -existing $ExistingConfig -defaults $DefaultConfig -preserveExisting $PreserveExisting
        $changesMade = $mergeResult[0]
        $mergedConfig = $mergeResult[1]
        
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

