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
        LegacyAppMode     = $null
        AppModes          = @()
        EffectiveModes    = @()
        ConfigurationType = "Unknown"
        IsValid           = $false
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
            $result.ConfigurationType = if ($result.AppModes.Count -eq 1)
            {
                "SingleMode" 
            }
            else
            {
                "MultipleMode" 
            }
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