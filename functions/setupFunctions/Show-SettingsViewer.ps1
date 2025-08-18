function Show-SettingsViewer()
{
    <#
    .SYNOPSIS
        Read-only viewer for application settings displaying values and descriptions.
    
    .DESCRIPTION
        Provides a read-only interface for users to view application settings with their
        current values and descriptions. Uses the same infrastructure as Show-SettingsEditor
        but displays information without modification capabilities. Supports viewing
        global, domain-specific, and authentication settings.
    
    .PARAMETER SettingsType
        Specifies whether to view 'Global', 'Domain', or 'Auth' settings.
    
    .PARAMETER SettingsFile
        Path to the settings.json file. Defaults to "settings.json".
    
    .PARAMETER DomainName
        Required when SettingsType is 'Domain'. Specifies which domain's settings to view.
    
    .PARAMETER Silent
        If specified, uses minimal output for programmatic usage.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully displayed, $false otherwise.
    
    .EXAMPLE
        Show-SettingsViewer -SettingsType "Global"
    
    .EXAMPLE
        Show-SettingsViewer -SettingsType "Domain" -DomainName "contoso.com"
    
    .EXAMPLE
        Show-SettingsViewer -SettingsType "Auth"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Leverages existing infrastructure from Show-SettingsEditor
        - Read-only display with no modification capabilities
        - Supports same settings structure as the editor
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Domain', 'Auth')]
        [string]$SettingsType,
        [string]$SettingsFile = "settings.json",
        [string]$DomainName,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting settings viewer for $SettingsType settings" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting settings viewer for $SettingsType settings"
    
    try
    {
        # Validate parameters
        if ($SettingsType -eq 'Domain' -and [string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "DomainName is required when viewing Domain settings" -LogLevel "Error"
            Write-Warning "[$functionName] DomainName is required when viewing Domain settings"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Parameter validation passed. SettingsType: $SettingsType, SettingsFile: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Parameter validation passed. SettingsType: $SettingsType, SettingsFile: $SettingsFile"
        
        # For auth settings, ensure auth defaults are in place
        if ($SettingsType -eq 'Auth')
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Ensuring auth defaults are present for display" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Ensuring auth defaults are present for display"
            $authDefaultsSuccess = Test-AuthDefaults -SettingsFile $SettingsFile -Silent
            if (-not $authDefaultsSuccess)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to ensure auth defaults" -LogLevel "Error"
                Write-Warning "[$functionName] Failed to ensure auth defaults"
                return $false
            }
        }
        
        # Get default settings structure from existing infrastructure
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving default settings structure for display" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving default settings structure for display"
        $defaultSettings = Get-DefaultSettingsStructure
        if (-not $defaultSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to get default settings structure" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to get default settings structure"
            return $false
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully retrieved default settings structure" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Successfully retrieved default settings structure"
        
        # Load current settings
        Write-Log -LogFile $logFile -Module $functionName -Message "Loading current settings from: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Loading current settings from: $SettingsFile"
        $currentSettings = Get-CurrentSettings -SettingsFile $SettingsFile -SettingsType $SettingsType -DomainName $DomainName
        if (-not $currentSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load current settings" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to load current settings"
            return $false
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully loaded current settings" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Successfully loaded current settings"
        
        # Get settings template and current values to display
        if ($SettingsType -eq 'Global')
        {
            $settingsTemplate = $defaultSettings.globalSettings
            $currentValues = $currentSettings.globalSettings
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying global settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Displaying global settings"
            if (-not $Silent)
            {
                Write-Host "`n══ Global Settings Viewer ══" -ForegroundColor Cyan
                Write-Host "Current global application settings that apply to all domains." -ForegroundColor White
                Write-Host "These settings control the overall behavior of the application.`n" -ForegroundColor Gray
            }
        }
        elseif ($SettingsType -eq 'Auth')
        {
            $settingsTemplate = Get-AuthDefaults
            $currentValues = $currentSettings.auth
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying auth settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Displaying auth settings"
            if (-not $Silent)
            {
                Write-Host "`n══ Authentication Settings Viewer ══" -ForegroundColor Cyan
                Write-Host "Current authentication and authorization settings." -ForegroundColor White
                Write-Host "These settings control how the application authenticates with Microsoft Graph API.`n" -ForegroundColor Gray
            }
        }
        else
        {
            # Load domain settings from separate domain configuration file
            $configPath = Split-Path $SettingsFile -Parent
            Write-Log -LogFile $logFile -Module $functionName -Message "Loading domain configuration for '$DomainName' from path: '$configPath'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Loading domain configuration for '$DomainName' from path: '$configPath'"
            
            $domainConfig = Load-DomainConfiguration -DomainName $DomainName -ConfigurationPath $configPath
            
            if ($null -eq $domainConfig -or $null -eq $domainConfig.settings)
            {
                Write-Warning "[$functionName] Failed to load domain configuration for: $DomainName"
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load domain configuration for: $DomainName" -LogLevel "Warning"
                return $false
            }
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully loaded domain configuration for '$DomainName'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Successfully loaded domain configuration for '$DomainName'"
            
            # Get domain settings template from centralized defaults (fixed approach)
            Write-Log -LogFile $logFile -Module $functionName -Message "Getting domain settings template from centralized defaults for domain: '$DomainName'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Getting domain settings template from centralized defaults for domain: '$DomainName'"
            
            try {
                $domainTemplate = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
                if ($null -eq $domainTemplate -or $null -eq $domainTemplate.settings) {
                    Write-Warning "[$functionName] Failed to get domain template from centralized defaults"
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to get domain template from centralized defaults" -LogLevel "Warning"
                    return $false
                }
                
                $settingsTemplate = $domainTemplate.settings
                Write-Log -LogFile $logFile -Module $functionName -Message "Successfully retrieved domain settings template with $($settingsTemplate.Count) properties" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Successfully retrieved domain settings template with $($settingsTemplate.Count) properties"
            }
            catch {
                Write-Warning "[$functionName] Error retrieving domain template: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Module $functionName -Message "Error retrieving domain template: $($_.Exception.Message)" -LogLevel "Error"
                return $false
            }
            
            # Use the actual domain configuration for current values
            $currentValues = $domainConfig.settings
            Write-Log -LogFile $logFile -Module $functionName -Message "Using current domain settings with $($currentValues.PSObject.Properties.Count) properties" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Using current domain settings with $($currentValues.PSObject.Properties.Count) properties"
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying domain settings for domain: '$DomainName' from separate configuration file" -LogLevel "Information"
            Write-Verbose "[$functionName] Displaying domain settings for domain: '$DomainName' from separate configuration file"
            if (-not $Silent)
            {
                Write-Host "`n══ Domain Settings Viewer ══" -ForegroundColor Cyan
                Write-Host "Current settings specific to domain: " -NoNewline -ForegroundColor White
                Write-Host "$DomainName" -ForegroundColor Yellow -BackgroundColor DarkMagenta
                Write-Host "These settings override global settings for this specific domain.`n" -ForegroundColor Gray
                Write-Host "Configuration loaded from: " -NoNewline -ForegroundColor Gray
                Write-Host "$DomainName.json" -ForegroundColor Yellow
                Write-Host ""
            }
        }
        
        if (-not $settingsTemplate)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No settings template found for $SettingsType" -LogLevel "Error"
            Write-Warning "[$functionName] No settings template found for $SettingsType"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Settings template loaded successfully. Found $($settingsTemplate.PSObject.Properties.Count) settings to display" -LogLevel "Information"
        Write-Verbose "[$functionName] Settings template loaded successfully. Found $($settingsTemplate.PSObject.Properties.Count) settings to display"
        
        $settingsCount = 0
        
        # Display each setting in the template
        if ($settingsTemplate -is [hashtable])
        {
            # Handle hashtable (auth settings)
            foreach ($settingName in $settingsTemplate.Keys)
            {
                $defaultValue = $settingsTemplate[$settingName]
                $currentValue = if ($currentValues.PSObject.Properties.Name -contains $settingName)
                {
                    $currentValues.$settingName 
                }
                else
                {
                    $defaultValue 
                }
                
                Write-Log -LogFile $logFile -Module $functionName -Message "Displaying setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Displaying setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'"
                
                if (-not $Silent)
                {
                    # Display setting in formatted way
                    Display-SettingInfo -SettingName $settingName -CurrentValue $currentValue -DefaultValue $defaultValue
                }
                
                $settingsCount++
            }
        }
        else
        {
            # Handle PSCustomObject (global and domain settings)
            foreach ($setting in $settingsTemplate.PSObject.Properties)
            {
                $settingName = $setting.Name
                $defaultValue = $setting.Value
                $currentValue = if ($currentValues.PSObject.Properties.Name -contains $settingName)
                {
                    $currentValues.$settingName 
                }
                else
                {
                    $defaultValue 
                }
                
                Write-Log -LogFile $logFile -Module $functionName -Message "Displaying setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Displaying setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'"
                
                if (-not $Silent)
                {
                    # Display setting in formatted way
                    Display-SettingInfo -SettingName $settingName -CurrentValue $currentValue -DefaultValue $defaultValue
                }
                
                $settingsCount++
            }
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully displayed $settingsCount settings" -LogLevel "Information"
        Write-Verbose "[$functionName] Successfully displayed $settingsCount settings"
        
        if (-not $Silent)
        {
            Write-Host "`n══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "Total settings displayed: $settingsCount" -ForegroundColor White
            Write-Host "Use the settings editor to modify these values." -ForegroundColor Gray
        }
        
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in settings viewer: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in settings viewer: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Display-SettingInfo()
{
    <#
    .SYNOPSIS
        Displays a setting with its value and description in a formatted way.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingName,
        $CurrentValue,
        $DefaultValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying setting info for: '$SettingName'"
    
    # Get description using existing infrastructure
    $description = Get-SettingDescription -SettingName $SettingName
    
    # Format the current value for display
    $displayValue = if ($CurrentValue -is [array])
    {
        if ($CurrentValue.Count -eq 0)
        {
            "(empty array)"
        }
        else
        {
            "[$($CurrentValue -join ', ')]"
        }
    }
    elseif ($CurrentValue -is [bool])
    {
        $CurrentValue.ToString().ToLower()
    }
    elseif ([string]::IsNullOrWhiteSpace($CurrentValue))
    {
        "(not set)"
    }
    else
    {
        $CurrentValue.ToString()
    }
    
    # Display the setting
    Write-Host "Setting: " -NoNewline -ForegroundColor Yellow
    Write-Host "$SettingName" -ForegroundColor White
    Write-Host "  Value: " -NoNewline -ForegroundColor Cyan
    Write-Host "$displayValue" -ForegroundColor Green
    Write-Host "  Description: " -NoNewline -ForegroundColor Gray
    Write-Host "$description" -ForegroundColor White
    
    # Show if value differs from default
    if ($CurrentValue -ne $DefaultValue)
    {
        $defaultDisplayValue = if ($DefaultValue -is [array])
        {
            if ($DefaultValue.Count -eq 0)
            {
                "(empty array)"
            }
            else
            {
                "[$($DefaultValue -join ', ')]"
            }
        }
        elseif ($DefaultValue -is [bool])
        {
            $DefaultValue.ToString().ToLower()
        }
        else
        {
            $DefaultValue.ToString()
        }
        
        Write-Host "  Default: " -NoNewline -ForegroundColor Gray
        Write-Host "$defaultDisplayValue" -ForegroundColor DarkGray
    }
    
    Write-Host ""  # Empty line for spacing
}