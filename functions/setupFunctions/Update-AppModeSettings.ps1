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
        
    .PARAMETER Settings
        Hashtable containing the settings object (required for Domain storage to access domain name)
        
    .OUTPUTS
        Boolean - True if settings were updated successfully
        
    .EXAMPLE
        $success = Update-AppModeSettings -Configuration 'helpDesk' -SettingsFile 'settings.psd1' -UseGlobalSettings:$true
        
    .EXAMPLE
        $success = Update-AppModeSettings -Configuration @('helpDesk', 'registration') -SettingsFile 'settings.psd1' -Settings $settings
        
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
        [switch]$UseGlobalSettings,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Updating app mode settings. Configuration: $(if ($Configuration -is [array]) { "[$($Configuration -join ', ')]" } else { "'$Configuration'" })" -LogLevel "Information"
    Write-Verbose "[$functionName] Received parameters: Configuration=$Configuration, SettingsFile=$SettingsFile, UseGlobalSettings=$UseGlobalSettings"
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
        }        
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
        
        if ($UseGlobalSettings)
        {
            $settingType = "Global"
            $updateParams = @{
                SettingsFile  = $SettingsFile
                SettingType   = "Global"
                SettingName   = "appModes"
                SettingValue  = $validatedModes
                MergeSettings = $true
            }
        }
        else
        {
            $settingType = "Domain"
            if (-not $Settings -or -not $Settings.domain)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Settings parameter with domain property is required for Domain storage" -LogLevel "Error"
                return $false
            }
            # For Domain type, Update-Setting expects Settings parameter (not SettingName/SettingValue)
            # Create a hashtable with just the setting we want to update
            $settingsToUpdate = @{
                appModes = $validatedModes
            }
            $updateParams = @{
                SettingsFile  = $SettingsFile
                SettingType   = "Domain"
                DomainName    = $Settings.domain
                Settings      = $settingsToUpdate
                MergeSettings = $true
            }
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Updating appModes property in $settingType settings" -LogLevel "Debug"
        $settingsSuccess = Update-Setting @updateParams

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
