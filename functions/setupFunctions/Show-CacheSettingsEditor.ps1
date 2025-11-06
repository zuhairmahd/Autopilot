function Show-CacheSettingsEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for cache settings configuration.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify cache configuration
        settings in globalSettings.cacheSettings. These settings control caching
        behavior, expiration times, and cache size limits. Uses the existing 
        Update-Setting infrastructure to maintain consistency with other settings management.
    
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
        - Uses existing Update-Setting function for data persistence
        - Provides intuitive interface for managing cache settings
        - Handles nested cacheTypes configuration
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting cache settings editor" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Starting cache settings editor"
    
    try
    {
        # Check if settings file exists
        Write-Log -LogFile $logFile -Module $functionName -Message "Checking settings file: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Checking settings file: $SettingsFile"
        
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Error"
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Load current settings using Import-PowerShellDataFile
        try
        {
            $configData = Import-PowerShellDataFile -Path $SettingsFile
            Write-Log -LogFile $logFile -Module $functionName -Message "Settings file loaded successfully" -LogLevel "Information"
            Write-Verbose "[$functionName] Settings file loaded successfully"
        }
        catch
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load settings file: $($_.Exception.Message)" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to load settings file: $($_.Exception.Message)"
            return $false
        }
        
        if ($null -eq $configData -or $null -eq $configData.globalSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "globalSettings section not found" -LogLevel "Error"
            Write-Warning "[$functionName] globalSettings section not found"
            return $false
        }
        
        # Get current cacheSettings
        $currentCacheSettings = $configData.globalSettings.cacheSettings
        if ($null -eq $currentCacheSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "cacheSettings section not found, using defaults" -LogLevel "Warning"
            Write-Verbose "[$functionName] cacheSettings section not found, using defaults"
            $currentCacheSettings = @{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = @{
                    Configuration    = @{
                        enabled           = $true
                        expirationMinutes = 60
                    }
                    DirectoryObjects = @{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                    Devices          = @{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                }
            }
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Loaded current cache settings" -LogLevel "Information"
        Write-Verbose "[$functionName] Loaded current cache settings"
        
        if (-not $Silent)
        {
            Write-Host "`n" -NoNewline
            Write-Host "=" -NoNewline -ForegroundColor Cyan
            Write-Host "=" -NoNewline -ForegroundColor Cyan
            Write-Host " Cache Settings Editor " -NoNewline -ForegroundColor Cyan
            Write-Host "=" -NoNewline -ForegroundColor Cyan
            Write-Host "=" -ForegroundColor Cyan
            Write-Host "Manage caching behavior, expiration times, and size limits." -ForegroundColor Gray
            Write-Host ""
        }
        
        # Create cache settings editing menu
        if (-not $Silent)
        {
            # Create menu from configuration
            $cacheSettingsEditMenu = NewMenu -MenuName "cacheSettingsEditMenu"
            
            # Set actions for the menu items
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "Toggle global cache enabled/disabled" -Action {
                Write-Host "Selected: Toggle global cache enabled/disabled" -ForegroundColor Green
                return 'enabled'
            } -ReturnsValue
            
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "Edit default expiration minutes" -Action {
                Write-Host "Selected: Edit default expiration minutes" -ForegroundColor Green
                return 'defaultExpirationMinutes'
            } -ReturnsValue
            
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "Edit max cache size" -Action {
                Write-Host "Selected: Edit max cache size" -ForegroundColor Green
                return 'maxCacheSize'
            } -ReturnsValue
            
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "Edit Configuration cache type" -Action {
                Write-Host "Selected: Edit Configuration cache type" -ForegroundColor Green
                return 'Configuration'
            } -ReturnsValue
            
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "Edit DirectoryObjects cache type" -Action {
                Write-Host "Selected: Edit DirectoryObjects cache type" -ForegroundColor Green
                return 'DirectoryObjects'
            } -ReturnsValue
            
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "Edit Devices cache type" -Action {
                Write-Host "Selected: Edit Devices cache type" -ForegroundColor Green
                return 'Devices'
            } -ReturnsValue
            
            $cacheSettingsEditMenu = AddMenuItem -Menu $cacheSettingsEditMenu -Name "View current settings" -Action {
                Write-Host "Selected: View current settings" -ForegroundColor Cyan
                return 'view'
            } -ReturnsValue
            
            # Loop: after editing, return to the menu
            while ($true)
            {
                $choice = ShowMenu -Menu $cacheSettingsEditMenu -CalledBy 'Action'
                
                # Validate that we got a proper choice, not a navigation option
                if ($null -eq $choice -or $choice -eq "Back" -or $choice -eq "Main Menu" -or $choice -eq 0 -or $choice -eq "0")
                {
                    Write-Verbose "[$functionName] ShowMenu returned navigation option: '$choice', treating as navigation"
                    break
                }
                
                # Process the user's choice
                if ($choice -eq 'enabled')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Global Cache Enabled " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "Controls whether caching is globally enabled or disabled." -ForegroundColor Gray
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentCacheSettings.enabled -ForegroundColor Yellow
                    Write-Host ""
                    
                    $shouldModify = Show-EditorInteractiveChoice -PromptText "Do you want to toggle this setting? (y/n)"
                    if ($shouldModify)
                    {
                        $currentCacheSettings.enabled = -not $currentCacheSettings.enabled
                        $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "cacheSettings" -SettingValue $currentCacheSettings
                        if ($success)
                        {
                            Write-Host "Global cache enabled setting updated to: " -NoNewline -ForegroundColor Green
                            Write-Host $currentCacheSettings.enabled -ForegroundColor Yellow
                        }
                        else
                        {
                            Write-Host "Failed to update global cache enabled setting!" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -eq 'defaultExpirationMinutes')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Default Expiration Minutes " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "Default cache expiration time in minutes for cache types without specific settings." -ForegroundColor Gray
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentCacheSettings.defaultExpirationMinutes -ForegroundColor Yellow
                    Write-Host ""
                    
                    $newValue = Read-Host "Enter new default expiration minutes (or press Enter to cancel)"
                    if (-not [string]::IsNullOrWhiteSpace($newValue))
                    {
                        if ($newValue -match '^\d+$')
                        {
                            $currentCacheSettings.defaultExpirationMinutes = [int]$newValue
                            $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "cacheSettings" -SettingValue $currentCacheSettings
                            if ($success)
                            {
                                Write-Host "Default expiration minutes updated successfully!" -ForegroundColor Green
                            }
                            else
                            {
                                Write-Host "Failed to update default expiration minutes!" -ForegroundColor Red
                            }
                        }
                        else
                        {
                            Write-Host "Invalid value. Please enter a positive integer." -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -eq 'maxCacheSize')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Max Cache Size " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "Maximum number of items to keep in the cache." -ForegroundColor Gray
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentCacheSettings.maxCacheSize -ForegroundColor Yellow
                    Write-Host ""
                    
                    $newValue = Read-Host "Enter new max cache size (or press Enter to cancel)"
                    if (-not [string]::IsNullOrWhiteSpace($newValue))
                    {
                        if ($newValue -match '^\d+$')
                        {
                            $currentCacheSettings.maxCacheSize = [int]$newValue
                            $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "cacheSettings" -SettingValue $currentCacheSettings
                            if ($success)
                            {
                                Write-Host "Max cache size updated successfully!" -ForegroundColor Green
                            }
                            else
                            {
                                Write-Host "Failed to update max cache size!" -ForegroundColor Red
                            }
                        }
                        else
                        {
                            Write-Host "Invalid value. Please enter a positive integer." -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -in @('Configuration', 'DirectoryObjects', 'Devices'))
                {
                    $cacheType = $choice
                    
                    # Ensure the cache type exists
                    if ($null -eq $currentCacheSettings.cacheTypes)
                    {
                        $currentCacheSettings.cacheTypes = @{}
                    }
                    if ($null -eq $currentCacheSettings.cacheTypes[$cacheType])
                    {
                        $currentCacheSettings.cacheTypes[$cacheType] = @{
                            enabled           = $true
                            expirationMinutes = $currentCacheSettings.defaultExpirationMinutes
                        }
                    }
                    
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host " $cacheType Cache Type " -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -ForegroundColor Cyan
                    Write-Host "Configure settings for $cacheType cache type." -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Current settings:" -ForegroundColor White
                    Write-Host "  Enabled:            " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentCacheSettings.cacheTypes[$cacheType].enabled -ForegroundColor Yellow
                    Write-Host "  Expiration Minutes: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentCacheSettings.cacheTypes[$cacheType].expirationMinutes -ForegroundColor Yellow
                    Write-Host ""
                    
                    Write-Host "What would you like to modify?" -ForegroundColor White
                    Write-Host "  1. Toggle enabled/disabled" -ForegroundColor White
                    Write-Host "  2. Change expiration minutes" -ForegroundColor White
                    Write-Host "  3. Cancel" -ForegroundColor White
                    
                    $subChoice = Read-Host "Enter your choice (1-3)"
                    
                    if ($subChoice -eq '1')
                    {
                        $currentCacheSettings.cacheTypes[$cacheType].enabled = -not $currentCacheSettings.cacheTypes[$cacheType].enabled
                        $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "cacheSettings" -SettingValue $currentCacheSettings
                        if ($success)
                        {
                            Write-Host "$cacheType cache enabled setting updated to: " -NoNewline -ForegroundColor Green
                            Write-Host $currentCacheSettings.cacheTypes[$cacheType].enabled -ForegroundColor Yellow
                        }
                        else
                        {
                            Write-Host "Failed to update $cacheType cache enabled setting!" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                    elseif ($subChoice -eq '2')
                    {
                        $newValue = Read-Host "Enter new expiration minutes for $cacheType (or press Enter to cancel)"
                        if (-not [string]::IsNullOrWhiteSpace($newValue))
                        {
                            if ($newValue -match '^\d+$')
                            {
                                $currentCacheSettings.cacheTypes[$cacheType].expirationMinutes = [int]$newValue
                                $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "cacheSettings" -SettingValue $currentCacheSettings
                                if ($success)
                                {
                                    Write-Host "$cacheType expiration minutes updated successfully!" -ForegroundColor Green
                                }
                                else
                                {
                                    Write-Host "Failed to update $cacheType expiration minutes!" -ForegroundColor Red
                                }
                            }
                            else
                            {
                                Write-Host "Invalid value. Please enter a positive integer." -ForegroundColor Red
                            }
                            Write-Host "Press any key to continue..." -ForegroundColor Yellow
                            [void][System.Console]::ReadKey($true)
                        }
                    }
                }
                elseif ($choice -eq 'view')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host " Current Cache Settings " -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Global Cache Enabled:       " -NoNewline -ForegroundColor White
                    Write-Host $currentCacheSettings.enabled -ForegroundColor Yellow
                    Write-Host "Default Expiration Minutes: " -NoNewline -ForegroundColor White
                    Write-Host $currentCacheSettings.defaultExpirationMinutes -ForegroundColor Yellow
                    Write-Host "Max Cache Size:             " -NoNewline -ForegroundColor White
                    Write-Host $currentCacheSettings.maxCacheSize -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Cache Types:" -ForegroundColor Cyan
                    
                    foreach ($cacheType in @('Configuration', 'DirectoryObjects', 'Devices'))
                    {
                        if ($currentCacheSettings.cacheTypes -and $currentCacheSettings.cacheTypes[$cacheType])
                        {
                            Write-Host "  $cacheType" -NoNewline -ForegroundColor White
                            Write-Host ":"
                            Write-Host "    Enabled:            " -NoNewline -ForegroundColor Gray
                            Write-Host $currentCacheSettings.cacheTypes[$cacheType].enabled -ForegroundColor Yellow
                            Write-Host "    Expiration Minutes: " -NoNewline -ForegroundColor Gray
                            Write-Host $currentCacheSettings.cacheTypes[$cacheType].expirationMinutes -ForegroundColor Yellow
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "Press any key to continue..." -ForegroundColor Yellow
                    [void][System.Console]::ReadKey($true)
                }
            }
            
            Write-Log -LogFile $logFile -Module $functionName -Message "User finished editing cache settings, returning $choice" -LogLevel "Information"
            if ($null -eq $choice -or $choice -eq 0 -or $choice -eq "0" -or $choice -eq "Back" -or $choice -eq "Main Menu")
            {
                return $choice
            }
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Cache settings editor completed" -LogLevel "Information"
        Write-Verbose "[$functionName] Cache settings editor completed"
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in cache settings editor: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in cache settings editor: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}
