function Initialize-GlobalSettings()
{
    <#
    .SYNOPSIS
        Processes global settings from configuration file with overwrite support.
    #>
    [CmdletBinding()]
    param(
        [object]$GlobalConfigData,
        [hashtable]$BoundParameters,
        [switch]$processConfigOverwrite
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -Message "Initializing global settings" -module $functionName -logLevel "Information"
    $globalSettings = @{}
    
    if ($null -eq $GlobalConfigData)
    {
        Write-Log -logFile $logFile -Message "No global settings found" -module $functionName -LogLevel "Verbose"
        return @{ GlobalSettings = $globalSettings }
    }
    
    Write-Log -logFile $logFile -Message "Processing $($GlobalConfigData.PSObject.Properties.Name.count) global settings" -module $functionName -LogLevel "Verbose"
    
    # Batch processing counters for performance optimization
    $processedCount = 0
    $booleanCount = 0
    $overrideCount = 0
    
    foreach ($key in $GlobalConfigData.keys)
    {
        Write-Log -logFile $logFile -Message "Processing global setting: $key" -module $functionName -logLevel "Verbose"
        Write-Verbose "[$functionName] Processing global setting: $key"
        if ($BoundParameters.ContainsKey($key) -eq $false -and $null -ne $GlobalConfigData.$key)
        {
            Write-Log -logFile $logFile -Message "Checking if $key is a boolean" -module $functionName -logLevel "Verbose"
            Write-Verbose "[$functionName] Checking if $key is a boolean"
            if ($GlobalConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$functionName] $key is a boolean"
                Write-Log -logFile $logFile -Message "$key is a boolean" -module $functionName -logLevel "Verbose"
                $keyBooleanValue = [bool]::Parse($GlobalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                Write-Log -logFile $logFile -Message "Set global $key to boolean: $keyBooleanValue" -module $functionName -logLevel "Verbose"
                $booleanCount++
            }
            else
            {
                $globalSettings.add($key, $GlobalConfigData.$key)
                Write-Log -logFile $logFile -Message "Set global $key to: $($GlobalConfigData.$key)" -module $functionName -logLevel "Verbose"
                Write-Verbose "[$functionName] Set global $key to: $($GlobalConfigData.$key)"
            }
            $processedCount++
        }
        elseif ($BoundParameters.ContainsKey($key))
        {
            $globalSettings.add($key, $BoundParameters[$key])
            Write-Log -logFile $logFile -Message "Used command-line override for global $key" -module $functionName -logLevel "Verbose"
            Write-Verbose "[$functionName] Used command-line override for global $key"
            $overrideCount++
        }
    }
    
    # Batch summary logging for performance optimization
    Write-Log -logFile $logFile -Message "Completed processing $processedCount global settings ($booleanCount boolean, $overrideCount overrides)" -module $functionName -LogLevel "Verbose"
    Write-Verbose "[$functionName] Completed processing $processedCount global settings ($booleanCount boolean, $overrideCount overrides)"
    
    # Check against defaults and merge missing keys (direct call to Merge-ConfigurationDefaults)
    Write-Log -logFile $logFile -Message "Checking global settings against defaults and merging missing keys" -module $functionName -logLevel "Information"
    $changesMade = $false
    
    try
    {
        # Get global defaults
        $defaultGlobalSettings = Get-ApplicationDefaults -DefaultType "Global"
        
        if ($defaultGlobalSettings)
        {
            # Filter out keys that are present in BoundParameters (command-line overrides)
            $filteredDefaults = @{}
            foreach ($key in $defaultGlobalSettings.Keys)
            {
                if (-not $BoundParameters.ContainsKey($key))
                {
                    $filteredDefaults[$key] = $defaultGlobalSettings[$key]
                }
            }
            
            Write-Verbose "[$functionName] Checking $($filteredDefaults.Keys.Count) default keys after filtering overrides"
            Write-Log -logFile $logFile -Message "Checking $($filteredDefaults.Keys.Count) default keys after filtering overrides" -module $functionName -logLevel "Verbose"
            
            if ($filteredDefaults.Keys.Count -gt 0)
            {
                # Use Merge-ConfigurationDefaults directly
                $mergedGlobalSettings = Merge-ConfigurationDefaults -ExistingConfig $globalSettings -DefaultConfig $filteredDefaults -PreserveExisting $true
                
                if ($mergedGlobalSettings)
                {
                    Write-Log -logFile $logFile -Message "Merged missing keys into global settings" -module $functionName -logLevel "Information"
                    Write-Verbose "[$functionName] Merged missing keys into global settings"
                    $globalSettings = $mergedGlobalSettings
                    $changesMade = $true
                }
                else
                {
                    Write-Verbose "[$functionName] No missing keys to merge into global settings"
                    Write-Log -logFile $logFile -Message "No missing keys to merge into global settings" -module $functionName -logLevel "Verbose"
                }
            }
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error during global settings merge: $($_.Exception.Message)"
        Write-Log -logFile $logFile -Message "Error during global settings merge: $($_.Exception.Message)" -module $functionName -logLevel "Warning"
    }
    
    # Apply overwrite settings to global configuration
    if ($processConfigOverwrite)
    {
        Write-Log -logFile $logFile -Message "Applying overwrite configuration to global settings" -module $functionName -logLevel "Information"
        try
        {
            $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
            # Apply global-specific overwrites
            Write-Log -logFile $logFile -Message "Applying global-specific overwrite configuration" -module $functionName -logLevel "Information"
            if ($overwriteConfig.GlobalSettings)
            {
                Write-Log -logFile $logFile -Message "Applying $($overwriteConfig.GlobalSettings.Count) global overwrite settings" -module $functionName -logLevel "Information"
                foreach ($overwriteKey in $overwriteConfig.GlobalSettings.Keys)
                {
                    $oldValue = if ($globalSettings.ContainsKey($overwriteKey))
                    {
                        $globalSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $globalSettings[$overwriteKey] = $overwriteConfig.GlobalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied global overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.GlobalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
            # Apply universal overwrites
            Write-Log -logFile $logFile -Message "Applying universal overwrite configuration" -module $functionName -logLevel "Information"
            if ($overwriteConfig.UniversalSettings)
            {
                Write-Log -logFile $logFile -Message "Applying $($overwriteConfig.UniversalSettings.Count) universal overwrite settings to global" -module $functionName -logLevel "Information"
                foreach ($overwriteKey in $overwriteConfig.UniversalSettings.Keys)
                {
                    $oldValue = if ($globalSettings.ContainsKey($overwriteKey))
                    {
                        $globalSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $globalSettings[$overwriteKey] = $overwriteConfig.UniversalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied universal overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.UniversalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error applying overwrite configuration: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Error applying overwrite configuration: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
        }
    }    
    return @{ GlobalSettings = $globalSettings; Changed = $changesMade }
}
