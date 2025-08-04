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
                $nestedMerge = Merge-ConfigurationDefaults -ExistingConfig $mergedConfig[$key] -DefaultConfig $DefaultConfig[$key] -PreserveExisting $PreserveExisting
                if ($nestedMerge)
                {
                    $mergedConfig[$key] = $nestedMerge
                    $changesMade = $true
                }
            }
            elseif (-not $PreserveExisting)
            {
                # Overwrite existing value with default if PreserveExisting is false
                Write-Verbose "[$functionName] Overwriting existing key: $key"
                $mergedConfig[$key] = $DefaultConfig[$key]
                $changesMade = $true
            }
            # If PreserveExisting is true and key exists, keep the existing value
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

