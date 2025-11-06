function Show-CacheSettingsEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for cache settings configuration.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify cache configuration
        settings in cacheSettings. These settings control caching behavior, 
        expiration times, and cache size limits. This is now a lightweight wrapper 
        around Show-SettingsEditor for consistency and maintainability.
    
    .PARAMETER SettingsFile
        Path to the settings.psd1 file. Defaults to "settings.psd1".
    
    .PARAMETER Silent
        If specified, uses defaults and minimal output.
    
    .OUTPUTS
        System.Boolean or navigation string
        Returns $true if settings were successfully updated, $false otherwise,
        or navigation strings like "Back" or "Main Menu".
    
    .EXAMPLE
        Show-CacheSettingsEditor
    
    .EXAMPLE
        Show-CacheSettingsEditor -SettingsFile "settings.psd1"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Wrapper around Show-SettingsEditor with SettingsType='cacheSettings'
        - Provides consistent interface with other settings editors
        - Handles nested cacheTypes configuration
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Calling Show-SettingsEditor for cache settings" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Calling Show-SettingsEditor for cache settings"
    
    # Call the unified settings editor with SettingsType='cacheSettings'
    return Show-SettingsEditor -SettingsType 'cacheSettings' -SettingsFile $SettingsFile -Silent:$Silent
}
