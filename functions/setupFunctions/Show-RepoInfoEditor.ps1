function Show-RepoInfoEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for repository information settings.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify repository configuration
        settings in repoInfo. These settings control repository URLs and paths used 
        for updates and source code references. This is now a lightweight wrapper 
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
        Show-RepoInfoEditor
    
    .EXAMPLE
        Show-RepoInfoEditor -SettingsFile "settings.psd1"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Wrapper around Show-SettingsEditor with SettingsType='repoInfo'
        - Provides consistent interface with other settings editors
        - Edits repoName, baseSourceURL, baseURL, and repoPath
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Calling Show-SettingsEditor for repository info settings" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Calling Show-SettingsEditor for repository info settings"
    
    # Call the unified settings editor with SettingsType='repoInfo'
    return Show-SettingsEditor -SettingsType 'repoInfo' -SettingsFile $SettingsFile -Silent:$Silent
}
