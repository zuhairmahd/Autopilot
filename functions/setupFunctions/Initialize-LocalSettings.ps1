function Initialize-LocalSettings()
{
    <#
    .SYNOPSIS
        Processes domain-specific settings from separate domain configuration files.
    #>
    [CmdletBinding()]
    param(
        $InitFileContent,
        [string]$Domain,
        [hashtable]$BoundParameters,
        [hashtable]$GlobalSettings = @{},
        [string]$ConfigurationPath = $pwd,
        [switch]$processConfigOverwrite
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $localSettings = @{}
    Write-Log -LogFile $logFile -Message "Initializing local settings for domain: $Domain" -Module $functionName -LogLevel "Information"
    
    # Load domain configuration from separate file
    Write-Verbose "[$functionName] Loading domain configuration from separate file for: $Domain"
    $domainConfig = Get-DomainConfigurationFromFiles -DomainName $Domain -GlobalSettings $GlobalSettings -ConfigurationPath $ConfigurationPath
    
    if ($null -eq $domainConfig)
    {
        Write-Verbose "[$functionName] No domain-specific settings found for $Domain"
        return @{ LocalSettings = $localSettings }
    }
    
    Write-Verbose "[$functionName] Processing $($domainConfig.Count) settings keys"
    Write-Log -LogFile $logFile -Message "Processing $($domainConfig.Count) settings keys: $($domainConfig.Keys -join ', ')" -Module $functionName -LogLevel "Verbose"

    foreach ($key in $domainConfig.Keys)
    {
        if ($BoundParameters.ContainsKey($key) -eq $false -and $null -ne $domainConfig[$key])
        {
            if ($domainConfig[$key] -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($domainConfig[$key])
                $localSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$functionName] Set local $key to boolean: $keyBooleanValue"
            }
            else
            {
                $localSettings.add($key, $domainConfig.$key)
                Write-Verbose "[$functionName] Set local $key to: $($domainConfig.$key)"
            }
        }
        elseif ($BoundParameters.ContainsKey($key))
        {
            $localSettings.add($key, $BoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line override for local $key"
        }
    }
    
    # Apply overwrite settings to local/domain configuration
    if ($processConfigOverwrite)
    {
        Write-Log -logFile $logFile -Message "Applying overwrite configuration to local settings" -module $functionName -logLevel "Information"
        try
        {
            $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
            # Apply local-specific overwrites
            if ($overwriteConfig.LocalSettings)
            {
                Write-Log -logFile $logFile -Message "Applying $($overwriteConfig.LocalSettings.Count) local overwrite settings" -module $functionName -logLevel "Information"
                foreach ($overwriteKey in $overwriteConfig.LocalSettings.Keys)
                {
                    $oldValue = if ($localSettings.ContainsKey($overwriteKey))
                    {
                        $localSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $localSettings[$overwriteKey] = $overwriteConfig.LocalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied local overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.LocalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
            # Apply universal overwrites
            Write-Log -logFile $logFile -Message "Applying universal overwrite configuration to local settings" -module $functionName -logLevel "Information"
            if ($overwriteConfig.UniversalSettings)
            {
                Write-Verbose "[$functionName] Applying $($overwriteConfig.UniversalSettings.Count) universal overwrite settings to local"
                foreach ($overwriteKey in $overwriteConfig.UniversalSettings.Keys)
                {
                    $oldValue = if ($localSettings.ContainsKey($overwriteKey))
                    {
                        $localSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $localSettings[$overwriteKey] = $overwriteConfig.UniversalSettings[$overwriteKey]
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
    
    # Check against defaults and merge missing keys
    Write-Log -logFile $logFile -Message "Checking local settings against defaults and merging missing keys" -module $functionName -logLevel "Information"
    if (Get-Command "Merge-SettingsWithDefaults" -ErrorAction SilentlyContinue)
    {
        $mergedLocalSettings = Merge-SettingsWithDefaults -ExistingSettings $localSettings -SettingType "Local" -Domain $Domain -BoundParameters $BoundParameters
        if ($mergedLocalSettings)
        {
            Write-Log -logFile $logFile -Message "Merged missing keys into local settings for domain: $Domain" -module $functionName -logLevel "Information"
            $localSettings = $mergedLocalSettings
            
            # Save the merged domain configuration back to file
            Write-Log -logFile $logFile -Message "Saving merged domain configuration for: $Domain" -module $functionName -logLevel "Information"
            $saveResult = Save-DomainConfiguration -DomainName $Domain -DomainConfiguration $localSettings -ConfigurationPath $ConfigurationPath -CreateBackup $true
            if ($saveResult)
            {
                Write-Log -logFile $logFile -Message "Successfully saved merged domain configuration for: $Domain" -module $functionName -logLevel "Information"
            }
            else
            {
                Write-Warning "[$functionName] Failed to save merged domain configuration for: $Domain"
                Write-Log -logFile $logFile -Message "Failed to save merged domain configuration for: $Domain" -module $functionName -logLevel "Warning"
            }
        }
    }
    else
    {
        Write-Log -logFile $logFile -Message "Merge-SettingsWithDefaults function not available - skipping settings merge" -module $functionName -logLevel "Warning"
    }
    
    return @{ LocalSettings = $localSettings }
}
