function Show-RepoInfoEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for repository information settings.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify repository configuration
        settings in globalSettings.repoInfo. These settings control repository URLs
        and paths used for updates and source code references. Uses the existing 
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
        Show-RepoInfoEditor
    
    .EXAMPLE
        Show-RepoInfoEditor -SettingsFile "settings.psd1"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses existing Update-Setting function for data persistence
        - Provides intuitive interface for managing repository settings
        - Edits repoName, baseSourceURL, baseURL, and repoPath
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting repository info editor" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Starting repository info editor"
    
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
        
        # Load current settings
        $configData = Get-ConfigurationData -ConfigurationFile $SettingsFile
        if ($null -eq $configData -or $null -eq $configData.globalSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load settings or globalSettings section not found" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to load settings or globalSettings section not found"
            return $false
        }
        
        # Get current repoInfo settings
        $currentRepoInfo = $configData.globalSettings.repoInfo
        if ($null -eq $currentRepoInfo)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "repoInfo section not found, using defaults" -LogLevel "Warning"
            Write-Verbose "[$functionName] repoInfo section not found, using defaults"
            $currentRepoInfo = @{
                repoName      = 'Autopilot'
                baseSourceURL = 'https://raw.githubusercontent.com'
                baseURL       = 'https://www.github.com'
                repoPath      = 'zuhairmahd'
            }
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Loaded current repoInfo settings" -LogLevel "Information"
        Write-Verbose "[$functionName] Loaded current repoInfo settings"
        
        if (-not $Silent)
        {
            Write-Host "`n" -NoNewline
            Write-Host "=" -NoNewline -ForegroundColor Cyan
            Write-Host "=" -NoNewline -ForegroundColor Cyan
            Write-Host " Repository Information Editor " -NoNewline -ForegroundColor Cyan
            Write-Host "=" -NoNewline -ForegroundColor Cyan
            Write-Host "=" -ForegroundColor Cyan
            Write-Host "Manage repository configuration settings for updates and source references." -ForegroundColor Gray
            Write-Host ""
        }
        
        # Create repository info editing menu
        if (-not $Silent)
        {
            # Create menu from configuration
            $repoInfoEditMenu = NewMenu -MenuName "repoInfoEditMenu"
            
            # Set actions for the menu items
            $repoInfoEditMenu = AddMenuItem -Menu $repoInfoEditMenu -Name "Edit repository name" -Action {
                Write-Host "Selected: Edit repository name" -ForegroundColor Green
                return 'repoName'
            } -ReturnsValue
            
            $repoInfoEditMenu = AddMenuItem -Menu $repoInfoEditMenu -Name "Edit base source URL" -Action {
                Write-Host "Selected: Edit base source URL" -ForegroundColor Green
                return 'baseSourceURL'
            } -ReturnsValue
            
            $repoInfoEditMenu = AddMenuItem -Menu $repoInfoEditMenu -Name "Edit base URL" -Action {
                Write-Host "Selected: Edit base URL" -ForegroundColor Green
                return 'baseURL'
            } -ReturnsValue
            
            $repoInfoEditMenu = AddMenuItem -Menu $repoInfoEditMenu -Name "Edit repository path" -Action {
                Write-Host "Selected: Edit repository path" -ForegroundColor Green
                return 'repoPath'
            } -ReturnsValue
            
            $repoInfoEditMenu = AddMenuItem -Menu $repoInfoEditMenu -Name "View current settings" -Action {
                Write-Host "Selected: View current settings" -ForegroundColor Cyan
                return 'view'
            } -ReturnsValue
            
            # Loop: after editing, return to the menu
            while ($true)
            {
                $choice = ShowMenu -Menu $repoInfoEditMenu -CalledBy 'Action'
                
                # Validate that we got a proper choice, not a navigation option
                if ($null -eq $choice -or $choice -eq "Back" -or $choice -eq "Main Menu" -or $choice -eq 0 -or $choice -eq "0")
                {
                    Write-Verbose "[$functionName] ShowMenu returned navigation option: '$choice', treating as navigation"
                    break
                }
                
                # Process the user's choice
                if ($choice -eq 'repoName')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Repository Name " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentRepoInfo.repoName -ForegroundColor Yellow
                    Write-Host ""
                    
                    $newValue = Read-Host "Enter new repository name (or press Enter to cancel)"
                    if (-not [string]::IsNullOrWhiteSpace($newValue))
                    {
                        $currentRepoInfo.repoName = $newValue.Trim()
                        $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "repoInfo" -SettingValue $currentRepoInfo
                        if ($success)
                        {
                            Write-Host "Repository name updated successfully!" -ForegroundColor Green
                        }
                        else
                        {
                            Write-Host "Failed to update repository name!" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -eq 'baseSourceURL')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Base Source URL " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "This is the base URL for raw source files (e.g., https://raw.githubusercontent.com)" -ForegroundColor Gray
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentRepoInfo.baseSourceURL -ForegroundColor Yellow
                    Write-Host ""
                    
                    $newValue = Read-Host "Enter new base source URL (or press Enter to cancel)"
                    if (-not [string]::IsNullOrWhiteSpace($newValue))
                    {
                        $currentRepoInfo.baseSourceURL = $newValue.Trim()
                        $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "repoInfo" -SettingValue $currentRepoInfo
                        if ($success)
                        {
                            Write-Host "Base source URL updated successfully!" -ForegroundColor Green
                        }
                        else
                        {
                            Write-Host "Failed to update base source URL!" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -eq 'baseURL')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Base URL " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "This is the base URL for the repository (e.g., https://www.github.com)" -ForegroundColor Gray
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentRepoInfo.baseURL -ForegroundColor Yellow
                    Write-Host ""
                    
                    $newValue = Read-Host "Enter new base URL (or press Enter to cancel)"
                    if (-not [string]::IsNullOrWhiteSpace($newValue))
                    {
                        $currentRepoInfo.baseURL = $newValue.Trim()
                        $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "repoInfo" -SettingValue $currentRepoInfo
                        if ($success)
                        {
                            Write-Host "Base URL updated successfully!" -ForegroundColor Green
                        }
                        else
                        {
                            Write-Host "Failed to update base URL!" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -eq 'repoPath')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host " Repository Path " -NoNewline -ForegroundColor Green
                    Write-Host "=" -NoNewline -ForegroundColor Green
                    Write-Host "=" -ForegroundColor Green
                    Write-Host "This is the organization or user path (e.g., zuhairmahd)" -ForegroundColor Gray
                    Write-Host "Current value: " -NoNewline -ForegroundColor Cyan
                    Write-Host $currentRepoInfo.repoPath -ForegroundColor Yellow
                    Write-Host ""
                    
                    $newValue = Read-Host "Enter new repository path (or press Enter to cancel)"
                    if (-not [string]::IsNullOrWhiteSpace($newValue))
                    {
                        $currentRepoInfo.repoPath = $newValue.Trim()
                        $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName "repoInfo" -SettingValue $currentRepoInfo
                        if ($success)
                        {
                            Write-Host "Repository path updated successfully!" -ForegroundColor Green
                        }
                        else
                        {
                            Write-Host "Failed to update repository path!" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        [void][System.Console]::ReadKey($true)
                    }
                }
                elseif ($choice -eq 'view')
                {
                    Write-Host "`n" -NoNewline
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host " Current Repository Settings " -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -NoNewline -ForegroundColor Cyan
                    Write-Host "=" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Repository Name:  " -NoNewline -ForegroundColor White
                    Write-Host $currentRepoInfo.repoName -ForegroundColor Yellow
                    Write-Host "Base Source URL:  " -NoNewline -ForegroundColor White
                    Write-Host $currentRepoInfo.baseSourceURL -ForegroundColor Yellow
                    Write-Host "Base URL:         " -NoNewline -ForegroundColor White
                    Write-Host $currentRepoInfo.baseURL -ForegroundColor Yellow
                    Write-Host "Repository Path:  " -NoNewline -ForegroundColor White
                    Write-Host $currentRepoInfo.repoPath -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Press any key to continue..." -ForegroundColor Yellow
                    [void][System.Console]::ReadKey($true)
                }
            }
            
            Write-Log -LogFile $logFile -Module $functionName -Message "User finished editing repository info, returning $choice" -LogLevel "Information"
            if ($null -eq $choice -or $choice -eq 0 -or $choice -eq "0" -or $choice -eq "Back" -or $choice -eq "Main Menu")
            {
                return $choice
            }
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Repository info editor completed" -LogLevel "Information"
        Write-Verbose "[$functionName] Repository info editor completed"
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in repository info editor: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in repository info editor: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}
