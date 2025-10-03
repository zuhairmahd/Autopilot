function Merge-SettingsWithDefaults()
{
    <#
    .SYNOPSIS
        Checks settings against defaults and merges any missing keys.
    
    .DESCRIPTION
        This function compares existing settings against default values from Get-ApplicationDefaults
        and merges any missing keys while preserving existing values. It handles both global and
        local (domain) settings appropriately and respects overwrite configurations.
    
    .PARAMETER ExistingSettings
        The existing settings hashtable to check and merge.
    
    .PARAMETER SettingType
        The type of settings to process. Valid values: 'Global', 'Local'
    
    .PARAMETER Domain
        Domain name for local settings. Required when SettingType is 'Local'.
    
    .PARAMETER BoundParameters
        Parameters passed from calling script to preserve command-line overrides.
    
    .OUTPUTS
        System.Collections.Hashtable or $null
        Returns merged settings hashtable if changes were made, or $null if no merge was needed.
    
    .EXAMPLE
        $merged = Merge-SettingsWithDefaults -ExistingSettings $globalSettings -SettingType "Global"
        if ($merged) { $globalSettings = $merged }
    
    .EXAMPLE
        $merged = Merge-SettingsWithDefaults -ExistingSettings $localSettings -SettingType "Local" -Domain "contoso.com"
        if ($merged) { $localSettings = $merged }
    
    .NOTES
        - Uses Get-ApplicationDefaults as single source of truth for default values
        - Leverages existing Merge-ConfigurationDefaults function for deep merging
        - Preserves existing values while adding missing keys
        - Maintains PowerShell 5.1 compatibility
        - Respects command-line parameter overrides via BoundParameters
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ExistingSettings,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Local')]
        [string]$SettingType,
        [Parameter(Mandatory = $false)]
        [string]$Domain,
        [Parameter(Mandatory = $false)]
        [hashtable]$BoundParameters = @{}
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking $SettingType settings against defaults"
    
    # Safe logging helper - only use Write-Log if available
    $logFunction = Get-Command "Write-Log" -ErrorAction SilentlyContinue
    function Write-SafeLog($Message, $Level = "Information")
    {
        if ($logFunction -and $script:logFile)
        {
            Write-Log -logFile $script:logFile -module $functionName -Message $Message -logLevel $Level
        }
        else
        {
            Write-Verbose "[$functionName] $Message"
        }
    }
    
    Write-SafeLog "Checking $SettingType settings against defaults" "Information"
    
    if ($SettingType -eq 'Local' -and -not $Domain)
    {
        Write-Warning "[$functionName] Domain parameter is required for Local settings"
        Write-SafeLog "Domain parameter is required for Local settings" "Warning"
        return $null
    }
    
    try
    {
        # Get appropriate default settings based on type
        $defaultSettings = switch ($SettingType)
        {
            'Global'
            {
                Write-Verbose "[$functionName] Retrieving global defaults"
                Write-SafeLog "Retrieving global defaults" "Verbose"
                Get-ApplicationDefaults -DefaultType "Global"
            }
            'Local'
            {
                Write-Verbose "[$functionName] Retrieving domain defaults for: $Domain"
                Write-SafeLog "Retrieving domain defaults for: $Domain" "Verbose"
                Get-ApplicationDefaults -DefaultType "Domain" -DomainName $Domain
            }
        }
        
        if (-not $defaultSettings)
        {
            Write-Warning "[$functionName] Failed to retrieve default $SettingType settings"
            Write-SafeLog "Failed to retrieve default $SettingType settings" "Warning"
            return $null
        }
        
        Write-Verbose "[$functionName] Retrieved $($defaultSettings.Keys.Count) default settings keys"
        Write-SafeLog "Retrieved $($defaultSettings.Keys.Count) default settings keys" "Verbose"
        
        # Filter out keys that are present in BoundParameters (command-line overrides)
        # These should not be merged as they were explicitly set by the user
        $filteredDefaults = @{}
        $overrideCount = 0
        
        foreach ($key in $defaultSettings.Keys)
        {
            if (-not $BoundParameters.ContainsKey($key))
            {
                $filteredDefaults[$key] = $defaultSettings[$key]
            }
            else
            {
                $overrideCount++
                Write-Verbose "[$functionName] Skipping default for '$key' - command-line override present"
                Write-SafeLog "Skipping default for '$key' - command-line override present" "Verbose"
            }
        }
        
        Write-SafeLog "Filtered out $overrideCount command-line overrides, checking $($filteredDefaults.Keys.Count) defaults" "Verbose"
        
        if ($filteredDefaults.Keys.Count -eq 0)
        {
            Write-Verbose "[$functionName] No defaults to merge after filtering overrides"
            Write-SafeLog "No defaults to merge after filtering overrides" "Verbose"
            return $null
        }
        
        # Use existing Merge-ConfigurationDefaults function for consistent merging behavior
        Write-Verbose "[$functionName] Merging configuration defaults with existing settings"
        Write-SafeLog "Merging configuration defaults with existing settings" "Verbose"
        
        $mergedSettings = Merge-ConfigurationDefaults -ExistingConfig $ExistingSettings -DefaultConfig $filteredDefaults -PreserveExisting $true
        
        if ($mergedSettings)
        {
            Write-Verbose "[$functionName] Successfully merged default settings into $SettingType configuration"
            Write-SafeLog "Successfully merged default settings into $SettingType configuration" "Information"
            
            # Log the specific keys that were added for transparency
            $addedKeys = @()
            foreach ($key in $filteredDefaults.Keys)
            {
                if (-not $ExistingSettings.ContainsKey($key))
                {
                    $addedKeys += $key
                }
            }
            
            if ($addedKeys.Count -gt 0)
            {
                Write-Verbose "[$functionName] Added missing keys: $($addedKeys -join ', ')"
                Write-SafeLog "Added missing keys to $SettingType settings: $($addedKeys -join ', ')" "Information"
            }
            
            return $mergedSettings
        }
        else
        {
            Write-Verbose "[$functionName] No merge needed - all default keys already present in $SettingType settings"
            Write-SafeLog "No merge needed - all default keys already present in $SettingType settings" "Verbose"
            return $null
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error during settings merge: $($_.Exception.Message)"
        Write-SafeLog "Error during settings merge: $($_.Exception.Message)" "Error"
        throw
    }
}