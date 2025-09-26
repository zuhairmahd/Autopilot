function Update-AppModeSettings()
{
    <#
    .SYNOPSIS
        Updates app mode settings with support for both single and multiple modes.
    
    .DESCRIPTION
        Handles the transition between single appMode and multiple appModes configurations
        while maintaining backward compatibility. Manages both legacy single mode settings
        and new multiple mode arrays in the global settings.
    
    .PARAMETER AppModeConfiguration
        App mode configuration (single string or array) to save
        
    .PARAMETER SettingsFile
        Path to the settings file to update
        
    .PARAMETER MaintainLegacy
        If true, maintains both appMode and appModes properties for maximum compatibility
        
    .OUTPUTS
        Boolean - True if settings were updated successfully
        
    .EXAMPLE
        $success = Update-AppModeSettings -AppModeConfiguration 'helpDesk' -SettingsFile 'settings.psd1'
        
    .EXAMPLE
        $success = Update-AppModeSettings -AppModeConfiguration @('helpDesk', 'registration') -SettingsFile 'settings.psd1'
        
    .NOTES
        - Handles both single mode and multiple mode configurations
        - Maintains backward compatibility with legacy appMode property
        - Updates both appMode (primary mode) and appModes (all modes) for maximum compatibility
        - Validates mode values before saving
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $AppModeConfiguration,
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = "settings.psd1",
        [Parameter(Mandatory = $false)]
        [switch]$MaintainLegacy = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Updating app mode settings. Configuration: $(if ($AppModeConfiguration -is [array]) { "[$($AppModeConfiguration -join ', ')]" } else { "'$AppModeConfiguration'" })" -LogLevel "Information"
    
    try
    {
        # Normalize and validate the configuration
        $normalizedModes = @()
        $primaryMode = $null
        
        if ($AppModeConfiguration -is [array])
        {
            $normalizedModes = $AppModeConfiguration | Where-Object { $_ -and $_.ToString().Trim() -ne '' }
            $primaryMode = if ($normalizedModes.Count -gt 0) { $normalizedModes[0] } else { 'full' }
        }
        elseif ($AppModeConfiguration -and $AppModeConfiguration.ToString().Trim() -ne '')
        {
            $primaryMode = $AppModeConfiguration.ToString().Trim()
            $normalizedModes = @($primaryMode)
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Invalid app mode configuration provided, using default 'full'" -LogLevel "Warning"
            $primaryMode = 'full'
            $normalizedModes = @('full')
        }
        
        # Validate all modes
        $validModes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
        $validatedModes = @()
        $invalidModes = @()
        
        foreach ($mode in $normalizedModes)
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
            $primaryMode = 'full'
        }
        else
        {
            $primaryMode = $validatedModes[0]  # Ensure primary mode is valid
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Validated modes: [$($validatedModes -join ', ')], Primary mode: '$primaryMode'" -LogLevel "Verbose"
        
        # Update the settings
        $success = $true
        
        if ($MaintainLegacy)
        {
            # Update legacy appMode property (primary mode for backward compatibility)
            Write-Log -LogFile $logFile -Module $functionName -Message "Updating legacy appMode property to '$primaryMode'" -LogLevel "Debug"
            $legacySuccess = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "appMode" -SettingValue $primaryMode
            
            if (-not $legacySuccess)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update legacy appMode property" -LogLevel "Warning"
                $success = $false
            }
        }
        
        # Update new appModes array property
        if ($validatedModes.Count -eq 1)
        {
            # For single mode, store as single mode for simplicity (but still use array internally)
            Write-Log -LogFile $logFile -Module $functionName -Message "Storing single mode '$($validatedModes[0])' as appModes array" -LogLevel "Debug"
            $appModesSuccess = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "appModes" -SettingValue $validatedModes
        }
        else
        {
            # For multiple modes, store as array
            Write-Log -LogFile $logFile -Module $functionName -Message "Storing multiple modes [$($validatedModes -join ', ')] as appModes array" -LogLevel "Debug"
            $appModesSuccess = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "appModes" -SettingValue $validatedModes
        }
        
        if (-not $appModesSuccess)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update appModes array property" -LogLevel "Error"
            $success = $false
        }
        
        if ($success)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "App mode settings updated successfully. Primary: '$primaryMode', All modes: [$($validatedModes -join ', ')]" -LogLevel "Information"
            
            # Log configuration summary
            if ($validatedModes.Count -eq 1)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Configuration: Single mode '$($validatedModes[0])'" -LogLevel "Verbose"
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Configuration: Multiple modes with '$primaryMode' as primary, additional modes: [$($validatedModes[1..$($validatedModes.Length-1)] -join ', ')]" -LogLevel "Verbose"
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update app mode settings" -LogLevel "Error"
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