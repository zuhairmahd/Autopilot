function Initialize-GlobalSettings()
{
    <#
    .SYNOPSIS
        Processes global settings from configuration file with overwrite support.
    #>
    [CmdletBinding()]
    param(
        [object]$GlobalConfigData,
        [hashtable]$PSBoundParameters,
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
        # Conditional verbose logging - only log individual settings when explicit verbose is used
        if ($VerbosePreference -eq 'Continue')
        {
        }
        Write-Log -logFile $logFile -Message "Processing global setting: $key" -module $functionName -logLevel "Verbose"
        
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $GlobalConfigData.$key)
        {
            if ($VerbosePreference -eq 'Continue')
            {
            }
            Write-Log -logFile $logFile -Message "Checking if $key is a boolean" -module $functionName -logLevel "Verbose"
            
            if ($GlobalConfigData.$key -in ('true', 'false'))
            {
                if ($VerbosePreference -eq 'Continue')
                {
                }
                Write-Log -logFile $logFile -Message "$key is a boolean" -module $functionName -logLevel "Verbose"
                $keyBooleanValue = [bool]::Parse($GlobalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                if ($VerbosePreference -eq 'Continue')
                {
                }
                Write-Log -logFile $logFile -Message "Set global $key to boolean: $keyBooleanValue" -module $functionName -logLevel "Verbose"
                $booleanCount++
            }
            else
            {
                $globalSettings.add($key, $GlobalConfigData.$key)
                if ($VerbosePreference -eq 'Continue')
                {
                }
                Write-Log -logFile $logFile -Message "Set global $key to: $($GlobalConfigData.$key)" -module $functionName -logLevel "Verbose"
            }
            $processedCount++
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $globalSettings.add($key, $PSBoundParameters[$key])
            if ($VerbosePreference -eq 'Continue')
            {
            }
            Write-Log -logFile $logFile -Message "Used command-line override for global $key" -module $functionName -logLevel "Verbose"
            $overrideCount++
        }
    }
    
    # Batch summary logging for performance optimization
    Write-Log -logFile $logFile -Message "Completed processing $processedCount global settings ($booleanCount boolean, $overrideCount overrides)" -module $functionName -LogLevel "Verbose"
    
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
    return @{ GlobalSettings = $globalSettings }
}
