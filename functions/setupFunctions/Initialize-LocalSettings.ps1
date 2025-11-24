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
        Write-Log -LogFile $logFile -Message "No domain-specific settings found for $Domain" -Module $functionName -LogLevel "Information"
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
                Write-Log -LogFile $logFile -Message "Set local $key to boolean: $keyBooleanValue" -Module $functionName -LogLevel "Verbose"
            }
            else
            {
                $localSettings.add($key, $domainConfig.$key)
                Write-Verbose "[$functionName] Set local $key to: $($domainConfig.$key)"
                Write-Log -LogFile $logFile -Message "Set local $key to: $($domainConfig.$key)" -Module $functionName -LogLevel "Verbose"       
            }
        }
        elseif ($BoundParameters.ContainsKey($key))
        {
            $localSettings.add($key, $BoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line override for local $key"
            Write-Log -LogFile $logFile -Message "Used command-line override for local $key" -Module $functionName -LogLevel "Verbose"  
        }
    }
    # Check against defaults and merge missing keys (direct call to Merge-ConfigurationDefaults)
    Write-Log -logFile $logFile -Message "Checking local settings against defaults and merging missing keys" -module $functionName -logLevel "Information"
    $changesMade = $false
    try
    {
        # Get domain/local defaults
        $defaultLocalSettings = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $Domain
        
        if ($defaultLocalSettings)
        {
            # Filter out keys that are present in BoundParameters (command-line overrides)
            $filteredDefaults = @{}
            foreach ($key in $defaultLocalSettings.Keys)
            {
                if (-not $BoundParameters.ContainsKey($key))
                {
                    $filteredDefaults[$key] = $defaultLocalSettings[$key]
                }
            }
            
            Write-Verbose "[$functionName] Checking $($filteredDefaults.Keys.Count) default keys after filtering overrides"
            Write-Log -logFile $logFile -Message "Checking $($filteredDefaults.Keys.Count) default keys after filtering overrides" -module $functionName -logLevel "Verbose"
            
            if ($filteredDefaults.Keys.Count -gt 0)
            {
                # Use Merge-ConfigurationDefaults directly
                $mergedLocalSettings = Merge-ConfigurationDefaults -ExistingConfig $localSettings -DefaultConfig $filteredDefaults -PreserveExisting $true
                
                if ($mergedLocalSettings)
                {
                    Write-Log -logFile $logFile -Message "Merged missing keys into local settings for domain: $Domain" -module $functionName -logLevel "Information"
                    Write-Verbose "[$functionName] Merged missing keys into local settings for domain: $Domain"
                    $localSettings = $mergedLocalSettings
                    $changesMade = $true
                }
                else
                {
                    Write-Verbose "[$functionName] No missing keys to merge into local settings"
                    Write-Log -logFile $logFile -Message "No missing keys to merge into local settings" -module $functionName -logLevel "Verbose"
                }
            }
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error during local settings merge: $($_.Exception.Message)"
        Write-Log -logFile $logFile -Message "Error during local settings merge: $($_.Exception.Message)" -module $functionName -logLevel "Warning"
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
    
    return @{ LocalSettings = $localSettings; Changed = $changesMade; ConfigurationPath = $ConfigurationPath; Domain = $Domain }
}
