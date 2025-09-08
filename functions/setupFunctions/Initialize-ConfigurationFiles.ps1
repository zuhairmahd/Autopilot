function Initialize-ConfigurationFiles()
{
    <#
    .SYNOPSIS
        Ensures configuration files exist with proper defaults.
    #>
    [CmdletBinding()]
    param(
        [string]$InitFile,
        [string]$StringsFile,
        [string]$MenuFile,
        [string]$Domain
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $result = @{ Success = $false; ErrorMessage = "" }
    
    try
    {
        # Ensure settings.psd1 exists with defaults
        Write-Verbose "[$functionName] Ensuring settings.psd1 exists with defaults"
        $settingsCreated = $true # Get-ConfigurationData will handle defaults
        if (-not (Test-Path $InitFile))
        {
            try
            {
                # Get default settings and save as PSD1
                $defaultSettings = Get-ApplicationDefaults -DefaultType "Settings"
                Write-Verbose "[$functionName] Saving to path $InitFile"
                $defaultSettings | Export-PowerShellDataFile -Path $InitFile -validate -Force
                Write-Verbose "[$functionName] Created settings.psd1 with defaults"
            }
            catch
            {
                Write-Warning "[$functionName] Failed to create settings.psd1: $($_.Exception.Message)"
                $settingsCreated = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] settings.psd1 already exists, skipping creation"
        }
        if (-not $settingsCreated)
        {
            $result.ErrorMessage = "Failed to create or validate settings.psd1 file"
            Write-Verbose "[$functionName] $($result.ErrorMessage)"
            return $result
        }
        
        # Ensure strings.psd1 exists with defaults
        Write-Verbose "[$functionName] Ensuring strings.psd1 exists with defaults"
        $stringsCreated = $true # Get-ConfigurationData will handle defaults
        if (-not (Test-Path $StringsFile))
        {
            try
            {
                # Get default strings and save as PSD1
                $defaultStrings = Get-ApplicationDefaults -DefaultType "Strings"
                $defaultStrings | Export-PowerShellDataFile -Path $StringsFile -validate -Force
                Write-Verbose "[$functionName] Created strings.psd1 with defaults"
            }
            catch
            {
                Write-Warning "[$functionName] Failed to create strings.psd1: $($_.Exception.Message)"
                $stringsCreated = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] strings.psd1 already exists, skipping creation"
        }
        if (-not $stringsCreated)
        {
            $result.ErrorMessage = "Failed to create or validate strings.psd1 file"
            Write-Verbose "[$functionName] $($result.ErrorMessage)"
            return $result
        }

        #ensure menu.psd1 exists
        Write-Verbose "[$functionName] Ensuring menu.psd1 exists with defaults"
        $menuCreated = $true
        if (-not (Test-Path $MenuFile))
        {
            try
            {
                # Get default menu and save as PSD1
                $defaultMenu = Get-ApplicationDefaults -DefaultType "Menus"
                $defaultMenu | Export-PowerShellDataFile -Path $MenuFile -validate -Force
                Write-Verbose "[$functionName] Created menu.psd1 with defaults"
            }
            catch
            {
                Write-Warning "[$functionName] Failed to create menu.psd1: $($_.Exception.Message)"
                $menuCreated = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] menu.psd1 already exists, skipping creation"
        }
        if (-not $menuCreated)
        {
            $result.ErrorMessage = "Failed to create or validate menu.psd1 file"
            Write-Verbose "[$functionName] $($result.ErrorMessage)"
            return $result
        }   
        
        $result.Success = $true
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Error ensuring configuration files exist: $($_.Exception.Message)"
        Write-Verbose "[$functionName] $($result.ErrorMessage)"
        return $result
    }
}

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
        [hashtable]$PSBoundParameters,
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
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $domainConfig[$key])
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
                Write-Verbose "[$functionName] Set local $key to: $($domainConfig[$key])"
            }
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $localSettings.add($key, $PSBoundParameters[$key])
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
    return @{ LocalSettings = $localSettings }
}


