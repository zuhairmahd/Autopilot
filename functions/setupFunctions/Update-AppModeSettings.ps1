function Update-AppModeSettings()
{
    <#
    .SYNOPSIS
        Updates app mode settings with support for multiple modes and storage location choice.
    
    .DESCRIPTION
        Handles app mode configuration updates using appModes array format only.
        Single modes are stored as single-element arrays for consistency.
        Allows user choice between Global and Domain settings storage.
    
    .PARAMETER Configuration
        App mode configuration (single string or array) to save as appModes array
        
    .PARAMETER SettingsFile
        Path to the settings file to update
        
    .PARAMETER UseGlobalSettings
        If true, saves to Global settings; if false, saves to Domain settings
        
    .OUTPUTS
        Boolean - True if settings were updated successfully
        
    .EXAMPLE
        $success = Update-AppModeSettings -Configuration 'helpDesk' -SettingsFile 'settings.psd1' -UseGlobalSettings:$true
        
    .EXAMPLE
        $success = Update-AppModeSettings -Configuration @('helpDesk', 'registration') -SettingsFile 'settings.psd1' -UseGlobalSettings:$false
        
    .NOTES
        - Always stores configuration as appModes array (single modes become single-element arrays)
        - Legacy appMode property is no longer created or maintained
        - Validates mode values before saving
        - Supports user choice between Global and Domain settings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Configuration,
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = "settings.psd1",
        [Parameter(Mandatory = $false)]
        [switch]$UseGlobalSettings = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Updating app mode settings. Configuration: $(if ($Configuration -is [array]) { "[$($Configuration -join ', ')]" } else { "'$Configuration'" })" -LogLevel "Information"
    
    try
    {
        # Normalize configuration to array format only (eliminate legacy single mode)
        $appModesArray = @()
        
        if ($Configuration -is [array])
        {
            $appModesArray = $Configuration | Where-Object { $_ -and $_.ToString().Trim() -ne '' }
        }
        elseif ($Configuration -and $Configuration.ToString().Trim() -ne '')
        {
            # Single mode becomes single-element array
            $appModesArray = @($Configuration.ToString().Trim())
        }
        else
        {
            # Default fallback
            $appModesArray = @('full')
        
        # Validate all modes
        $validModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
        $validatedModes = @()
        $invalidModes = @()
        
        foreach ($mode in $appModesArray)
        {
            if ($mode -in $validModes)
            {
                if ($mode -notin $validatedModes)
                {
                    $validatedModes += $mode
                }
            }
            else
            {
                $invalidModes += $mode
                Write-Log -LogFile $logFile -Module $functionName -Message "Invalid app mode detected: '$mode' - will be ignored" -LogLevel "Warning"
            }
        }
        
        if ($invalidModes.Count -gt 0)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Invalid modes found and removed: [$($invalidModes -join ', ')]" -LogLevel "Warning"
        }
        
        if ($validatedModes.Count -eq 0)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No valid modes found, defaulting to 'full'" -LogLevel "Error"
            $validatedModes = @('full')
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Validated modes: [$($validatedModes -join ', ')]" -LogLevel "Verbose"
        
        # Update the settings using appModes array only (no legacy appMode support)
        $success = $true
        $settingType = if ($UseGlobalSettings) { "Global" } else { "Domain" }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Updating appModes property in $settingType settings" -LogLevel "Debug"
        $settingsSuccess = Update-Setting -SettingType $settingType -SettingsFile $SettingsFile -SettingName "appModes" -SettingValue $validatedModes
        
        if (-not $settingsSuccess)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update appModes property in $settingType settings" -LogLevel "Error"
            $success = $false
        }
        
        if ($success)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "App mode settings updated successfully in $settingType settings. Modes: [$($validatedModes -join ', ')]" -LogLevel "Information"
            
            # Log configuration summary
            if ($validatedModes.Count -eq 1)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Configuration: Single mode '$($validatedModes[0])' stored as array" -LogLevel "Verbose"
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Configuration: Multiple modes [$($validatedModes -join ', ')]" -LogLevel "Verbose"
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update app mode settings in $settingType settings" -LogLevel "Error"
        }
        
        return $success
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error updating app mode settings: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
}

function Get-AppModeSettingsFromFile()
{
    <#
    .SYNOPSIS
        Reads app mode settings from settings file with backward compatibility.
    
    .DESCRIPTION
        Reads both legacy appMode and new appModes properties from settings file
        and returns the effective configuration. Handles various storage formats
        and provides fallback behavior.
    
    .PARAMETER SettingsFile
        Path to the settings file to read
        
    .OUTPUTS
        Hashtable with current app mode configuration details
        
    .EXAMPLE
        $appModeConfig = Get-AppModeSettingsFromFile -SettingsFile 'settings.psd1'
        
    .NOTES
        - Returns both legacy and new format modes
        - Provides effective modes based on current configuration
        - Handles missing or corrupted settings gracefully
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = "settings.psd1"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Reading app mode settings from file: $SettingsFile" -LogLevel "Debug"
    
    $result = @{
        LegacyAppMode = $null
        AppModes = @()
        EffectiveModes = @()
        ConfigurationType = "Unknown"
        IsValid = $false
    }
    
    try
    {
        if (-not (Test-Path $SettingsFile))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Warning"
            $result.EffectiveModes = @('full')
            $result.ConfigurationType = "Default"
            return $result
        }
        
        $settings = Import-PowerShellDataFile -Path $SettingsFile -ErrorAction Stop
        
        if (-not $settings -or -not $settings.globalSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No globalSettings section found in settings file" -LogLevel "Warning"
            $result.EffectiveModes = @('full')
            $result.ConfigurationType = "Default"
            return $result
        }
        
        $globalSettings = $settings.globalSettings
        
        # Read legacy appMode
        if ($globalSettings.ContainsKey('appMode') -and $globalSettings.appMode)
        {
            $result.LegacyAppMode = $globalSettings.appMode.ToString()
            Write-Log -LogFile $logFile -Module $functionName -Message "Found legacy appMode: '$($result.LegacyAppMode)'" -LogLevel "Verbose"
        }
        
        # Read new appModes array
        if ($globalSettings.ContainsKey('appModes') -and $globalSettings.appModes)
        {
            if ($globalSettings.appModes -is [array])
            {
                $result.AppModes = $globalSettings.appModes | Where-Object { $_ -and $_.ToString().Trim() -ne '' }
            }
            else
            {
                $result.AppModes = @($globalSettings.appModes.ToString())
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "Found appModes array: [$($result.AppModes -join ', ')]" -LogLevel "Verbose"
        }
        
        # Determine effective configuration
        if ($result.AppModes.Count -gt 0)
        {
            $result.EffectiveModes = $result.AppModes
            $result.ConfigurationType = if ($result.AppModes.Count -eq 1) { "SingleMode" } else { "MultipleMode" }
            $result.IsValid = $true
        }
        elseif ($result.LegacyAppMode)
        {
            $result.EffectiveModes = @($result.LegacyAppMode)
            $result.ConfigurationType = "LegacyMode"
            $result.IsValid = $true
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No valid app mode configuration found, using default" -LogLevel "Warning"
            $result.EffectiveModes = @('full')
            $result.ConfigurationType = "Default"
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "App mode configuration: Type=$($result.ConfigurationType), Effective=[$($result.EffectiveModes -join ', ')]" -LogLevel "Information"
        return $result
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error reading app mode settings: $($_.Exception.Message)" -LogLevel "Error"
        $result.EffectiveModes = @('full')
        $result.ConfigurationType = "Error"
        return $result
    }
}