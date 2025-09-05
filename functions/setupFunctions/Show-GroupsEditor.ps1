function Show-GroupsEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for domain-level group inclusion and exclusion settings.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify groupsToInclude and groupsToExclude
        arrays at the domain level. These settings control which groups are included or excluded
        from various operations within the application. Uses the existing Update-Setting
        infrastructure to maintain consistency with other settings management.
    
    .PARAMETER SettingsFile
        Path to the settings.psd1 file. Defaults to "settings.psd1".
    
    .PARAMETER DomainName
        The domain name for which to edit group settings. If not provided, will attempt 
        to use the currently loaded domain from the session. If no loaded domain is 
        available, will prompt user to select from available domains.
    
    .PARAMETER Silent
        If specified, uses defaults and minimal output.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully updated, $false otherwise.
    
    .EXAMPLE
        Show-GroupsEditor -DomainName "contoso.com"
    
    .EXAMPLE
        Show-GroupsEditor -SettingsFile "settings.psd1"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses existing Update-Setting function for data persistence
        - Provides intuitive interface for managing group arrays
        - Handles domain selection when not specified (prioritizes loaded domain)
        - Supports both groupsToInclude and groupsToExclude editing
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [string]$DomainName,
        [string]$AccessToken,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $logFile -Module $functionName -Message "Starting groups editor for domain: '$DomainName'" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Starting groups editor for domain: '$DomainName'"
    
    try
    {
        # Check if settings file exists for configuration path determination
        Write-Log -LogFile $logFile -Module $functionName -Message "Checking settings file: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Checking settings file: $SettingsFile"
        
        if (-not (Test-Path -Path $SettingsFile))
        {
Write-Log -LogFile $logFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Verbose"
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Get domain name if not specified (following domain settings editor pattern)
        if ([string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No domain specified, attempting to determine current domain" -LogLevel "Verbose"
            Write-Verbose "[$functionName] No domain specified, attempting to determine current domain"
            
            # Try to get the current domain from calling scope (same logic as domain settings editor)
            $currentDomain = $null
            try
            {
                # Check if $domain variable exists in calling scope
                $currentDomain = Get-Variable -Name "domain" -Scope 1 -ValueOnly -ErrorAction SilentlyContinue
                if (-not [string]::IsNullOrWhiteSpace($currentDomain))
                {
Write-Log -LogFile $logFile -Module $functionName -Message "Found loaded domain from scope: '$currentDomain'" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Found loaded domain from scope: '$currentDomain'"
                    $DomainName = $currentDomain
                }
            }
            catch
            {
Write-Log -LogFile $logFile -Module $functionName -Message "Unable to access domain variable from calling scope: $($_.Exception.Message)" -LogLevel "Warning"
                Write-Verbose "[$functionName] Unable to access domain variable from calling scope: $($_.Exception.Message)"
            }
            
            # If no current domain found, fall back to domain selection
            if ([string]::IsNullOrWhiteSpace($DomainName))
            {
Write-Log -LogFile $logFile -Module $functionName -Message "No loaded domain found, falling back to domain selection" -LogLevel "Warning"
                Write-Verbose "[$functionName] No loaded domain found, falling back to domain selection"
                
                $configPath = Split-Path $SettingsFile -Parent
                $availableDomains = Get-AvailableDomains -ConfigurationPath $configPath -SettingsFile $SettingsFile
                if ($availableDomains.Count -eq 0)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "No domains available" -LogLevel "Error"
                    Write-Warning "[$functionName] No domains available"
                    return $false
                }
                
                if ($availableDomains.Count -eq 1)
                {
                    $DomainName = $availableDomains[0]
                    Write-Log -LogFile $logFile -Module $functionName -Message "Auto-selected single domain: '$DomainName'" -LogLevel "Information"
                    Write-Verbose "[$functionName] Auto-selected single domain: '$DomainName'"
                }
                else
                {
                    if (-not $Silent)
                    {
                        Write-Host "`nAvailable domains:" -ForegroundColor Cyan
                        for ($i = 0; $i -lt $availableDomains.Count; $i++)
                        {
                            Write-Host "$($i + 1). $($availableDomains[$i])" -ForegroundColor White
                        }
                        
                        do
                        {
                            $choice = Read-Host "Select domain (1-$($availableDomains.Count))"
                            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $availableDomains.Count)
                            {
                                $DomainName = $availableDomains[[int]$choice - 1]
                                break
                            }
                            Write-Host "Invalid choice. Please enter a number between 1 and $($availableDomains.Count)." -ForegroundColor Red
                        } while ($true)
                    }
                    else
                    {
                        $DomainName = $availableDomains[0]  # Use first domain in silent mode
                    }
                    
                    Write-Log -LogFile $logFile -Module $functionName -Message "User selected domain: '$DomainName'" -LogLevel "Information"
                    Write-Verbose "[$functionName] User selected domain: '$DomainName'"
                }
            }
        }
        
        # Validate domain exists and load domain configuration using new architecture
        $configPath = Split-Path $SettingsFile -Parent
        Write-Log -LogFile $logFile -Module $functionName -Message "Loading domain configuration for '$DomainName' from: $configPath" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Loading domain configuration for '$DomainName' from: $configPath"
        
        $domainConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
        if ($null -eq $domainConfig)
        {
Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$DomainName' configuration not found" -LogLevel "Verbose"
            Write-Warning "[$functionName] Domain '$DomainName' configuration not found"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully loaded domain configuration for '$DomainName'" -LogLevel "Information"
        Write-Verbose "[$functionName] Successfully loaded domain configuration for '$DomainName'"
        
        # Get current group settings - preserve arrays even if empty
        $currentIncludeGroups = if ($null -ne $domainConfig.groupsToInclude) 
        { 
            $domainConfig.groupsToInclude 
        } 
        else 
        { 
            @() 
        }
        
        $currentExcludeGroups = if ($null -ne $domainConfig.groupsToExclude) 
        { 
            $domainConfig.groupsToExclude 
        } 
        else 
        { 
            @() 
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$DomainName' has $($currentIncludeGroups.Count) include groups and $($currentExcludeGroups.Count) exclude groups" -LogLevel "Information"
        Write-Verbose "[$functionName] Domain '$DomainName' has $($currentIncludeGroups.Count) include groups and $($currentExcludeGroups.Count) exclude groups"
        
        if (-not $Silent)
        {
            Write-Host "`n══ Groups Editor ══" -ForegroundColor Cyan
            Write-Host "Managing group inclusion/exclusion settings for domain: " -ForegroundColor White
            Write-Host "    $DomainName" -ForegroundColor Yellow
            Write-Host "These settings control which groups are included or excluded from operations.`n" -ForegroundColor Gray
        }
        
        # Create groups editing menu using the well-documented menu system
        if (-not $Silent)
        {
            # Create menu from configuration, will update title with dynamic variable
            $groupsEditMenu = NewMenu -MenuName "groupsEditMenu"
            # Update the title to include the actual domain name
            $groupsEditMenu.Title = $groupsEditMenu.Title -replace '\$DomainName', $DomainName
            
            # Set actions for the menu items
            $groupsEditMenu = AddMenuItem -Menu $groupsEditMenu -Name "Edit Groups to Include" -Action {
                Write-Host "Selected: Edit Groups to Include" -ForegroundColor Green
                return 'include'
            } -ReturnsValue
            $groupsEditMenu = AddMenuItem -Menu $groupsEditMenu -Name "Edit Groups to Exclude" -Action {
                Write-Host "Selected: Edit Groups to Exclude" -ForegroundColor Red
                return 'exclude'
            } -ReturnsValue
            $groupsEditMenu = AddMenuItem -Menu $groupsEditMenu -Name "View Current Group Settings" -Action {
                Write-Host "Selected: View Current Group Settings" -ForegroundColor Cyan
                return 'view'
            } -ReturnsValue
            # Loop: after editing groups, return to the group type selection menu
            while ($true)
            {
                # Use proper stack operation to maintain menu navigation integrity
                $groupChoice = ShowMenu -Menu $groupsEditMenu -CalledBy 'Custom_GroupsEditorSubmenu' -StackOperation 'Push'
                # Validate that we got a proper choice, not a navigation option
                if ($null -eq $groupChoice -or $groupChoice -eq "Back" -or $groupChoice -eq "Main Menu" -or $groupChoice -eq 0 -or $groupChoice -eq "0")
                {
                    Write-Verbose "[$functionName] ShowMenu returned navigation option: '$groupChoice', treating as navigation"
                    break
                }
                # Process the user's choice
                if ($groupChoice -eq 'include')
                {
                    Write-Host "`n══ Groups to Include ══" -ForegroundColor Green
                    Write-Host "Groups in this list will be specifically included in operations." -ForegroundColor Gray
                    Write-Host "Current groups to include:" -ForegroundColor Cyan
                    write-log -logFile $logFile -module $functionName -Message "Found $($currentIncludeGroups.Count) groups to include"
                    Write-Verbose "[$functionName] Current groups to include count: $($currentIncludeGroups.Count)"
                    if ($currentIncludeGroups -and $currentIncludeGroups.Count -gt 0)
                    {
                        # Detect format and display accordingly
                        $firstElement = $currentIncludeGroups | Select-Object -First 1
                        Write-Verbose "[$functionName] Current groups to include format: $($firstElement.GetType().Name)"
                        write-log -logFile $logFile -module $functionName -Message "Current groups to include format: $($firstElement.GetType().Name)"
                        if ($firstElement -is [string])
                        {
                            # Old string format
                            foreach ($group in $currentIncludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                            Write-Host "  (Note: Groups are in old format - will be upgraded)" -ForegroundColor Yellow
                        }
                        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
                            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name')) -or 
                            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name'))))
                        {
                            # New hashtable format
                            foreach ($group in $currentIncludeGroups)
                            {
                                Write-Host "  - Name: $($group.name)" -ForegroundColor White
                                if ($group.id)
                                {
                                    Write-Host "    ID:   $($group.id)" -ForegroundColor Gray
                                }
                                else
                                {
                                    Write-Host "    ID:   (not resolved)" -ForegroundColor Yellow
                                }
                            }
                        }
                        else
                        {
                            # Fallback for unknown format
                            foreach ($group in $currentIncludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                        }
                    }
                    else
                    {
                        Write-Host "  (no groups specified)" -ForegroundColor Gray
                    }
                    
                    $choice = Read-Host "`nDo you want to modify groups to include? (y/n)"
                    while ($choice -ne 'y' -and $choice -ne 'Y' -and $choice -ne 'n' -and $choice -ne 'N')
                    {
                        Write-Host "Invalid selection. Please enter 'y' or 'n'." -ForegroundColor Red
                        [console]::beep(1000, 500)
                        $choice = Read-Host "`nDo you want to modify groups to include? (y/n)"
                    }

                    if ($choice -eq 'y' -or $choice -eq 'Y')
                    {
                        $updatedIncludeGroups = Get-GroupArrayInput -CurrentGroups $currentIncludeGroups -GroupType "include" -AccessToken $AccessToken
                        if ($null -ne $updatedIncludeGroups -and (Compare-ArrayContents -Array1 $currentIncludeGroups -Array2 $updatedIncludeGroups))
                        {
                            Write-Log -LogFile $logFile -Module $functionName -Message "Groups to include changed" -LogLevel "Information"
                            Write-Verbose "[$functionName] Groups to include changed"
                            
                            # Save changes immediately
                            Write-Host "`nSaving changes..." -ForegroundColor Yellow
                            $includeSuccess = Update-DomainGroupSetting -SettingsFile $SettingsFile -DomainName $DomainName -GroupType "groupsToInclude" -Groups $updatedIncludeGroups
                            if ($includeSuccess)
                            {
                                Write-Host "Group settings updated successfully!" -ForegroundColor Green
                                Write-Host "`nGroup settings updated successfully. Changes will take effect immediately." -ForegroundColor Green
                                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                                [void][System.Console]::ReadKey($true)
                                # Update current values for future operations
                                $currentIncludeGroups = $updatedIncludeGroups
                            }
                            else
                            {
                                Write-Host "Failed to update group settings!" -ForegroundColor Red
                                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                                [void][System.Console]::ReadKey($true)
                            }
                        }
                    }
                }
                elseif ($groupChoice -eq 'exclude')
                {
                    Write-Host "`n══ Groups to Exclude ══" -ForegroundColor Red
                    Write-Host "Groups in this list will be specifically excluded from operations." -ForegroundColor Gray
                    Write-Host "Current groups to exclude:" -ForegroundColor Cyan
                    Write-Verbose "[$functionName] $($currentExcludeGroups.count) groups to exclude: $($currentExcludeGroups -join ', ')"
                    write-log -logFile $logFile -module $functionName -Message "$($currentExcludeGroups.count) groups to exclude: $($currentExcludeGroups -join ', ')"
                    if ($currentExcludeGroups -and $currentExcludeGroups.Count -gt 0)
                    {
                        # Detect format and display accordingly
                        $firstElement = $currentExcludeGroups | Select-Object -First 1
                        Write-Verbose "[$functionName] Current groups to exclude format: $($firstElement.GetType().Name)"
                        write-log -logFile $logFile -module $functionName -Message "Current groups to exclude format: $($firstElement.GetType().Name)"
                        if ($firstElement -is [string])
                        {
                            # Old string format
                            foreach ($group in $currentExcludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                            Write-Host "  (Note: Groups are in old format - will be upgraded)" -ForegroundColor Yellow
                        }
                        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
                            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name')) -or 
                            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name'))))
                        {
                            # New hashtable format
                            foreach ($group in $currentExcludeGroups)
                            {
                                Write-Host "  - Name: $($group.name)" -ForegroundColor White
                                if ($group.id)
                                {
                                    Write-Host "    ID:   $($group.id)" -ForegroundColor Gray
                                }
                                else
                                {
                                    Write-Host "    ID:   (not resolved)" -ForegroundColor Yellow
                                }
                            }
                        }
                        else
                        {
                            # Fallback for unknown format
                            foreach ($group in $currentExcludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                        }
                    }
                    else
                    {
                        Write-Host "  (no groups specified)" -ForegroundColor Gray
                    }
                    
                    $choice = Read-Host "`nDo you want to modify groups to exclude? (y/n)"
                    while ($choice -ne 'y' -and $choice -ne 'Y' -and $choice -ne 'n' -and $choice -ne 'N')
                    {
                        Write-Host "Invalid selection. Please enter 'y' or 'n'." -ForegroundColor Red
                        [console]::beep(1000, 500)
                        $choice = Read-Host "`nDo you want to modify groups to exclude? (y/n)"
                    }
                    if ($choice -eq 'y' -or $choice -eq 'Y')
                    {
                        $updatedExcludeGroups = Get-GroupArrayInput -CurrentGroups $currentExcludeGroups -GroupType "exclude" -AccessToken $AccessToken
                        if ($null -ne $updatedExcludeGroups -and (Compare-ArrayContents -Array1 $currentExcludeGroups -Array2 $updatedExcludeGroups))
                        {
                            Write-Log -LogFile $logFile -Module $functionName -Message "Groups to exclude changed" -LogLevel "Information"
                            Write-Verbose "[$functionName] Groups to exclude changed"
                            
                            # Save changes immediately
                            Write-Host "`nSaving changes..." -ForegroundColor Yellow
                            $excludeSuccess = Update-DomainGroupSetting -SettingsFile $SettingsFile -DomainName $DomainName -GroupType "groupsToExclude" -Groups $updatedExcludeGroups
                            if ($excludeSuccess)
                            {
                                Write-Host "Group settings updated successfully!" -ForegroundColor Green
                                Write-Host "`nGroup settings updated successfully. Changes will take effect immediately." -ForegroundColor Green
                                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                                [void][System.Console]::ReadKey($true)
                                # Update current values for future operations
                                $currentExcludeGroups = $updatedExcludeGroups
                            }
                            else
                            {
                                Write-Host "Failed to update group settings!" -ForegroundColor Red
                                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                                [void][System.Console]::ReadKey($true)
                            }
                        }
                    }
                }
                elseif ($groupChoice -eq 'view')
                {
                    Write-Host "`n══ Current Group Settings ══" -ForegroundColor Cyan
                    Write-Host "Domain: $DomainName`n" -ForegroundColor Yellow
                    
                    Write-Host "Groups to Include:" -ForegroundColor Green
                    if ($currentIncludeGroups -and $currentIncludeGroups.Count -gt 0)
                    {
                        # Detect format and display accordingly
                        $firstElement = $currentIncludeGroups[0]
                        if ($firstElement -is [string])
                        {
                            # Old string format
                            foreach ($group in $currentIncludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentIncludeGroups.Count) group(s) [Legacy Format]" -ForegroundColor Yellow
                        }
                        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
                            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name')) -or 
                            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name'))))
                        {
                            # New hashtable format
                            foreach ($group in $currentIncludeGroups)
                            {
                                Write-Host "  - Name: $($group.name)" -ForegroundColor White
                                if ($group.id)
                                {
                                    Write-Host "    ID:   $($group.id)" -ForegroundColor Gray
                                }
                                else
                                {
                                    Write-Host "    ID:   (not resolved)" -ForegroundColor Yellow
                                }
                            }
                            Write-Host "  Total: $($currentIncludeGroups.Count) group(s) [Enhanced Format]" -ForegroundColor Green
                        }
                        else
                        {
                            # Fallback for unknown format
                            foreach ($group in $currentIncludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentIncludeGroups.Count) group(s)" -ForegroundColor Gray
                        }
                    }
                    else
                    {
                        Write-Host "  (no groups specified)" -ForegroundColor Gray
                    }
                    
                    Write-Host "`nGroups to Exclude:" -ForegroundColor Red
                    if ($currentExcludeGroups -and $currentExcludeGroups.Count -gt 0)
                    {
                        # Detect format and display accordingly
                        $firstElement = $currentExcludeGroups[0]
                        if ($firstElement -is [string])
                        {
                            # Old string format
                            foreach ($group in $currentExcludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentExcludeGroups.Count) group(s) [Legacy Format]" -ForegroundColor Yellow
                        }
                        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
                            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name')) -or 
                            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name'))))
                        {
                            # New hashtable format
                            foreach ($group in $currentExcludeGroups)
                            {
                                Write-Host "  - Name: $($group.name)" -ForegroundColor White
                                if ($group.id)
                                {
                                    Write-Host "    ID:   $($group.id)" -ForegroundColor Gray
                                }
                                else
                                {
                                    Write-Host "    ID:   (not resolved)" -ForegroundColor Yellow
                                }
                            }
                            Write-Host "  Total: $($currentExcludeGroups.Count) group(s) [Enhanced Format]" -ForegroundColor Green
                        }
                        else
                        {
                            # Fallback for unknown format
                            foreach ($group in $currentExcludeGroups)
                            {
                                Write-Host "  - $group" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentExcludeGroups.Count) group(s)" -ForegroundColor Gray
                        }
                    }
                    else
                    {
                        Write-Host "  (no groups specified)" -ForegroundColor Gray
                    }
                    
                    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                    [void][System.Console]::ReadKey($true)
                }
                # Continue the loop to allow for multiple edits
            }
Write-Log -LogFile $logFile -Module $functionName -Message "User finished editing groups, returning $groupChoice" -LogLevel "Information"
            if ($null -eq $groupChoice -or $groupChoice -eq 0 -or $groupChoice -eq "0" -or $groupChoice -eq "Back" -or $groupChoice -eq "Main Menu")
            {
                return $groupChoice
            }
        }
        
        # Since settings are now saved immediately after each edit operation,
        # we no longer need to defer saving until the end
        Write-Log -LogFile $logFile -Module $functionName -Message "Groups editor completed" -LogLevel "Information"
        Write-Verbose "[$functionName] Groups editor completed"
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in groups editor: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in groups editor: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Get-GroupArrayInput()
{
    <#
    .SYNOPSIS
        Gets array input for group names and IDs with interactive resolution.
        Supports both old string array format and new hashtable format.
        Uses getEntraGroup for enhanced search capabilities.
    #>
    [CmdletBinding()]
    param(
        [array]$CurrentGroups,
        [string]$GroupType,
        [string]$AccessToken  # Added for group ID resolution
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting group array input for $GroupType groups" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Getting group array input for $GroupType groups"
    
    # Detect current format and display appropriately
    $currentFormat = "Empty"
    if ($CurrentGroups -and $CurrentGroups.Count -gt 0)
    {
        $firstElement = $CurrentGroups[0]
        if ($firstElement -is [string])
        {
            $currentFormat = "StringArray"
        }
        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name') -and $firstElement.ContainsKey('id')) -or 
            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name') -and ($firstElement.PSObject.Properties.Name -contains 'id'))))
        {
            $currentFormat = "HashTableArray"
        }
        else
        {
            $currentFormat = "Unknown"
        }
    }
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Current groups format: $currentFormat" -LogLevel "Verbose"
    
    # Display current groups in appropriate format
    if ($CurrentGroups -and $CurrentGroups.Count -gt 0)
    {
        Write-Host "`nCurrent groups:" -ForegroundColor Cyan
        if ($currentFormat -eq "HashTableArray")
        {
            foreach ($group in $CurrentGroups)
            {
                Write-Host "  - Name: $($group.name)" -ForegroundColor White
                Write-Host "    ID:   $($group.id)" -ForegroundColor Gray
            }
        }
        else
        {
            foreach ($group in $CurrentGroups)
            {
                Write-Host "  - $group" -ForegroundColor White
            }
        }
    }
    
    # Determine if we should ask about replace vs add
    $shouldReplaceExisting = $true
    if ($CurrentGroups -and $CurrentGroups.Count -gt 0)
    {
        Write-Host "`nYou have existing groups in this list." -ForegroundColor Yellow
        Write-Host "Do you want to:" -ForegroundColor White
        Write-Host "  1. Replace all existing groups with new ones" -ForegroundColor White
        Write-Host "  2. Add new groups to the existing ones" -ForegroundColor White
        Write-Host "  3. Keep current groups unchanged" -ForegroundColor White
        
        do
        {
            $choice = Read-Host "Enter your choice (1-3)"
            switch ($choice)
            {
                '1'
                {
                    $shouldReplaceExisting = $true
                    Write-Log -LogFile $logFile -Module $functionName -Message "User chose to replace existing $GroupType groups" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User chose to replace existing $GroupType groups"
                    break
                }
                '2'
                {
                    $shouldReplaceExisting = $false
                    Write-Log -LogFile $logFile -Module $functionName -Message "User chose to add to existing $GroupType groups" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User chose to add to existing $GroupType groups"
                    break
                }
                '3'
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current $GroupType groups unchanged" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User chose to keep current $GroupType groups unchanged"
                    return $CurrentGroups
                }
                default
                {
                    Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                    continue
                }
            }
            break
        } while ($true)
    }
    
    Write-Host "`nEnter group names to $GroupType (one per line)." -ForegroundColor Yellow
    Write-Host "Group names will be searched and resolved interactively." -ForegroundColor Green
    Write-Host "Press Enter on empty line to finish." -ForegroundColor Gray
    if (-not $shouldReplaceExisting)
    {
        Write-Host "New groups will be added to the existing ones." -ForegroundColor Green
    }
    Write-Host "Leave first line empty to cancel." -ForegroundColor Gray
    
    $newGroupsHashTable = @()
    $firstInput = $true
    
    do
    {
        if ($firstInput)
        {
            $input = Read-Host "Group name"
            $firstInput = $false
            
            # If first input is empty, return current groups
            if ([string]::IsNullOrWhiteSpace($input))
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "User cancelled input, keeping current $GroupType groups" -LogLevel "Verbose"
                Write-Verbose "[$functionName] User cancelled input, keeping current $GroupType groups"
                return $CurrentGroups
            }
            
            # Process the first group name
            $resolvedGroup = Resolve-SingleGroupInteractive -GroupName $input.Trim() -AccessToken $AccessToken -FunctionName $functionName
            if ($resolvedGroup)
            {
                $newGroupsHashTable += $resolvedGroup
                Write-Log -LogFile $logFile -Module $functionName -Message "Added first $GroupType group: '$($resolvedGroup.name)'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Added first $GroupType group: '$($resolvedGroup.name)'"
            }
        }
        else
        {
            $input = Read-Host "Group name"
            if ([string]::IsNullOrWhiteSpace($input))
            {
                break
            }
            
            # Process each additional group name
            $resolvedGroup = Resolve-SingleGroupInteractive -GroupName $input.Trim() -AccessToken $AccessToken -FunctionName $functionName
            if ($resolvedGroup)
            {
                $newGroupsHashTable += $resolvedGroup
                Write-Log -LogFile $logFile -Module $functionName -Message "Added $GroupType group: '$($resolvedGroup.name)'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Added $GroupType group: '$($resolvedGroup.name)'"
            }
        }
    } while ($true)
    
    # Determine final result based on user choice and format compatibility
    if ($shouldReplaceExisting -or -not $CurrentGroups -or $CurrentGroups.Count -eq 0)
    {
        # Replace existing groups
        $result = $newGroupsHashTable
    }
    else
    {
        # Add to existing groups - need to handle format conversion
        $combinedGroups = @()
        
        # Add existing groups in hashtable format
        if ($currentFormat -eq "HashTableArray")
        {
            $combinedGroups += $CurrentGroups
        }
        elseif ($currentFormat -eq "StringArray")
        {
            # Convert old string format to hashtable format
            Write-Host "`nConverting existing groups to new format..." -ForegroundColor Yellow
            foreach ($groupName in $CurrentGroups)
            {
                $combinedGroups += @{
                    name = $groupName
                    id   = $null  # Will be resolved when VerifyGroupMembership is called
                }
            }
        }
        
        # Add new groups
        $combinedGroups += $newGroupsHashTable
        $result = $combinedGroups
    }
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Returning $GroupType group array with $($result.Count) groups in hashtable format" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning $GroupType group array with $($result.Count) groups in hashtable format"
    return $result
}

function Compare-ArrayContents()
{
    <#
    .SYNOPSIS
        Compares two arrays to determine if they have different contents.
        Supports both string arrays and hashtable arrays with name/id properties.
    #>
    [CmdletBinding()]
    param(
        [array]$Array1,
        [array]$Array2
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Comparing array contents"
    
    # Handle null or empty arrays
    if (($null -eq $Array1 -or $Array1.Count -eq 0) -and ($null -eq $Array2 -or $Array2.Count -eq 0))
    {
        Write-Verbose "[$functionName] Both arrays are null or empty - no change"
        return $false  # No change
    }
    
    if (($null -eq $Array1 -or $Array1.Count -eq 0) -and ($Array2.Count -gt 0))
    {
        Write-Verbose "[$functionName] Array1 is empty but Array2 has content - change detected"
        return $true  # Change detected
    }
    
    if (($Array1.Count -gt 0) -and ($null -eq $Array2 -or $Array2.Count -eq 0))
    {
        Write-Verbose "[$functionName] Array1 has content but Array2 is empty - change detected"
        return $true  # Change detected
    }
    
    # Detect array formats
    $format1 = if ($Array1[0] -is [string]) { "String" } elseif ($Array1[0].name -and $Array1[0].id) { "HashTable" } else { "Unknown" }
    $format2 = if ($Array2[0] -is [string]) { "String" } elseif ($Array2[0].name -and $Array2[0].id) { "HashTable" } else { "Unknown" }
    
    Write-Verbose "[$functionName] Array1 format: $format1, Array2 format: $format2"
    
    # If formats are different, there's definitely a change
    if ($format1 -ne $format2)
    {
        Write-Verbose "[$functionName] Different array formats detected - change detected"
        return $true
    }
    
    # Compare based on format
    if ($format1 -eq "HashTable" -and $format2 -eq "HashTable")
    {
        # Compare hashtable arrays by name and id
        if ($Array1.Count -ne $Array2.Count)
        {
            Write-Verbose "[$functionName] Different array lengths - change detected"
            return $true
        }
        
        for ($i = 0; $i -lt $Array1.Count; $i++)
        {
            $item1 = $Array1[$i]
            $item2 = $Array2[$i]
            
            if ($item1.name -ne $item2.name -or $item1.id -ne $item2.id)
            {
                Write-Verbose "[$functionName] Hashtable content difference detected at index $i"
                return $true
            }
        }
        
        Write-Verbose "[$functionName] Hashtable arrays are identical - no change"
        return $false
    }
    else
    {
        # Use standard Compare-Object for string arrays
        $comparison = Compare-Object -ReferenceObject $Array1 -DifferenceObject $Array2
        $hasChanges = $null -ne $comparison
        
        Write-Verbose "[$functionName] Array comparison result: hasChanges = $hasChanges"
        return $hasChanges
    }
}

function Update-DomainGroupSetting()
{
    <#
    .SYNOPSIS
        Updates domain-level group settings using separate domain configuration files.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile,
        [string]$DomainName,
        [ValidateSet('groupsToInclude', 'groupsToExclude')]
        [string]$GroupType,
        [array]$Groups
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Updating $GroupType for domain '$DomainName'" -LogLevel "Information"
    Write-Verbose "[$functionName] Updating $GroupType for domain '$DomainName'"
    
    try
    {
        # Determine configuration path from settings file
        $configPath = Split-Path $SettingsFile -Parent
        Write-Log -LogFile $logFile -Module $functionName -Message "Configuration path: $configPath" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Configuration path: $configPath"
        
        # Load current domain configuration
        $domainConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
        if ($null -eq $domainConfig)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load domain configuration for '$DomainName'" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to load domain configuration for '$DomainName'"
            return $false
        }
        
Write-Log -LogFile $logFile -Module $functionName -Message "Successfully loaded domain configuration for '$DomainName'" -LogLevel "Information"
        Write-Verbose "[$functionName] Successfully loaded domain configuration for '$DomainName'"
        
        # Update the specific group setting
        Write-Log -LogFile $logFile -Module $functionName -Message "Setting $GroupType to array with $($Groups.Count) groups" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Setting $GroupType to array with $($Groups.Count) groups"
        
        # Ensure Groups is always an array, even for single items
        $groupsArray = @($Groups)
        
        # Update the domain configuration
        if ($GroupType -eq 'groupsToInclude')
        {
            $domainConfig.groupsToInclude = $groupsArray
        }
        elseif ($GroupType -eq 'groupsToExclude')
        {
            $domainConfig.groupsToExclude = $groupsArray
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Updated $GroupType in domain configuration object" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Updated $GroupType in domain configuration object"
        
        # Save the updated domain configuration
        Write-Log -LogFile $logFile -Module $functionName -Message "Saving updated domain configuration" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Saving updated domain configuration"
        
        $success = Save-DomainConfiguration -DomainName $DomainName -DomainConfiguration $domainConfig -ConfigurationPath $configPath
        if ($success)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully saved updated domain configuration" -LogLevel "Information"
            Write-Verbose "[$functionName] Successfully saved updated domain configuration"
            
            # Verify the update by reloading
            Write-Log -LogFile $logFile -Module $functionName -Message "Verifying update by reloading domain configuration" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Verifying update by reloading domain configuration"
            
            $verifyConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
            if ($verifyConfig)
            {
                $rawActualGroups = if ($GroupType -eq 'groupsToInclude')
                {
                    $verifyConfig.groupsToInclude 
                }
                else
                {
                    $verifyConfig.groupsToExclude 
                }
                
                # Enhanced logging for debugging array handling issues - handle null cases
                $rawType = if ($null -eq $rawActualGroups) { "null" } else { $rawActualGroups.GetType().Name }
                $rawJson = if ($null -eq $rawActualGroups) { "null" } else { $rawActualGroups | ConvertTo-Json -Compress }
                Write-Log -LogFile $logFile -Module $functionName -Message "Raw data from config: Type=$rawType, Value=$rawJson" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Raw data: Type=$rawType, IsNull=$($null -eq $rawActualGroups), IsArray=$($rawActualGroups -is [array])"
                
                # Ensure actualGroups is always an array for consistent comparison
                # This handles the JSON serialization issue where single items become individual objects
                $actualGroups = if ($null -eq $rawActualGroups)
                {
                    @()
                }
                elseif ($rawActualGroups -is [array])
                {
                    $rawActualGroups
                }
                else
                {
                    # Single item was deserialized as individual object - wrap in array
                    @($rawActualGroups)
                }
                
                # Enhanced logging for array conversion results - use safe count methods
                $actualGroupsCount = if ($actualGroups -is [array]) { $actualGroups.Count } elseif ($null -eq $actualGroups) { 0 } else { 1 }
                $groupsArrayCount = if ($groupsArray -is [array]) { $groupsArray.Count } elseif ($null -eq $groupsArray) { 0 } else { 1 }
                
                $actualType = if ($null -eq $actualGroups) { "null" } else { $actualGroups.GetType().Name }
                $actualJson = if ($null -eq $actualGroups) { "null" } else { $actualGroups | ConvertTo-Json -Compress }
                Write-Log -LogFile $logFile -Module $functionName -Message "After array conversion: Type=$actualType, SafeCount=$actualGroupsCount, Value=$actualJson" -LogLevel "Verbose"
                Write-Verbose "[$functionName] After conversion: Type=$actualType, SafeCount=$actualGroupsCount"
                
                Write-Log -LogFile $logFile -Module $functionName -Message "Verification: Saved $groupsArrayCount groups, Loaded $actualGroupsCount groups" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Verification: Saved $groupsArrayCount groups, Loaded $actualGroupsCount groups"
                
                # Handle different comparison strategies based on content type
                $comparisonResult = $null
                if ($groupsArrayCount -eq 0 -and $actualGroupsCount -eq 0)
                {
                    # Both are empty - verification successful
                    $comparisonResult = $null
                }
                elseif ($groupsArrayCount -ne $actualGroupsCount)
                {
                    # Different counts - verification failed
                    $savedType = if ($null -eq $groupsArray) { "null" } else { $groupsArray.GetType().Name }
                    $loadedType = if ($null -eq $actualGroups) { "null" } else { $actualGroups.GetType().Name }
                    Write-Log -LogFile $logFile -Module $functionName -Message "Count mismatch detected: savedCount=$groupsArrayCount, loadedCount=$actualGroupsCount, savedType=$savedType, loadedType=$loadedType" -LogLevel "Warning"
                    Write-Verbose "[$functionName] Count mismatch: savedCount=$groupsArrayCount, loadedCount=$actualGroupsCount, savedType=$savedType, loadedType=$loadedType"
                    $comparisonResult = @("Count mismatch: saved $groupsArrayCount, loaded $actualGroupsCount")
                }
                else
                {
                    # Same count, need to compare content
                    if ($groupsArrayCount -gt 0 -and $groupsArray[0] -is [hashtable])
                    {
                        # Hashtable comparison - compare by ID and name
                        for ($i = 0; $i -lt $groupsArrayCount; $i++)
                        {
                            $saved = $groupsArray[$i]
                            $loaded = $actualGroups[$i]
                            
                            # Handle case where loaded item might be PSCustomObject instead of hashtable
                            $loadedName = if ($loaded -is [hashtable]) { $loaded.name } else { $loaded.name }
                            $loadedId = if ($loaded -is [hashtable]) { $loaded.id } else { $loaded.id }
                            
                            if (($saved.name -ne $loadedName) -or ($saved.id -ne $loadedId))
                            {
                                $comparisonResult = @("Hashtable content mismatch at index $i`: saved($($saved.name),$($saved.id)) vs loaded($loadedName,$loadedId)")
                                break
                            }
                        }
                    }
                    else
                    {
                        # String or simple object comparison
                        $comparisonResult = Compare-Object -ReferenceObject $groupsArray -DifferenceObject $actualGroups
                    }
                }
                
                if ($null -eq $comparisonResult)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Successfully updated and verified $GroupType" -LogLevel "Information"
                    Write-Verbose "[$functionName] Successfully updated and verified $GroupType"
                    return $true
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Verification failed for $GroupType. Details: $($comparisonResult -join ', ')" -LogLevel "Warning"
                    Write-Verbose "[$functionName] Verification failed for $GroupType. Saved: $groupsArrayCount items, Loaded: $actualGroupsCount items"
                    Write-Verbose "[$functionName] Verification failed for $GroupType. Comparison result: $($comparisonResult -join ', ')"
                    Write-Warning "[$functionName] Verification failed for $GroupType"
                    return $false
                }
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to reload domain configuration for verification" -LogLevel "Warning"
                Write-Warning "[$functionName] Failed to reload domain configuration for verification"
                return $false
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to save updated domain configuration" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to save updated domain configuration"
            return $false
        }
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error updating $($GroupType): $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error updating $($GroupType): $($_.Exception.Message)"
        return $false
    }
}

function Resolve-SingleGroupInteractive()
{
    <#
    .SYNOPSIS
        Resolves a single group name to group object using interactive search.
        Uses getEntraGroup function for better search capabilities.
    #>
    [CmdletBinding()]
    param(
        [string]$GroupName,
        [string]$AccessToken,
        [string]$FunctionName
    )
    
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Resolving group: '$GroupName'" -LogLevel "Verbose"
    
    if (-not $AccessToken)
    {
        Write-Host "  No access token available - saving group without ID resolution" -ForegroundColor Yellow
        return @{
            name = $GroupName
            id   = $null
        }
    }
    
    try
    {
        # First try exact match
        Write-Host "  Searching for group: '$GroupName'..." -ForegroundColor Cyan
        $result, $wasSubstringSearch = GetEntraGroup -accessToken $AccessToken -groupName $GroupName
        
        if ($result -and $result.value -and $result.value.Count -gt 0)
        {
            if ($result.value.Count -eq 1)
            {
                # Single exact match found
                $group = $result.value[0]
                Write-Host "  Found group: '$($group.displayName)' (ID: $($group.id))" -ForegroundColor Green
                return @{
                    name = $group.displayName
                    id   = $group.id
                }
            }
            else
            {
                # Multiple matches found, let user choose
                Write-Host "  Multiple groups found matching '$GroupName':" -ForegroundColor Yellow
                for ($i = 0; $i -lt $result.value.Count; $i++)
                {
                    $group = $result.value[$i]
                    Write-Host "    $($i + 1). $($group.displayName) (ID: $($group.id))" -ForegroundColor White
                }
                Write-Host "    0. Skip this group" -ForegroundColor Gray
                
                do
                {
                    $choice = Read-Host "  Select group (0-$($result.value.Count))"
                    if ($choice -eq "0")
                    {
                        Write-Host "  Skipping group '$GroupName'" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped group: '$GroupName'" -LogLevel "Verbose"
                        return $null
                    }
                    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $result.value.Count)
                    {
                        $selectedGroup = $result.value[[int]$choice - 1]
                        Write-Host "  Selected: '$($selectedGroup.displayName)'" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected group: '$($selectedGroup.displayName)' (ID: $($selectedGroup.id))" -LogLevel "Verbose"
                        return @{
                            name = $selectedGroup.displayName
                            id   = $selectedGroup.id
                        }
                    }
                    Write-Host "  Invalid choice. Please enter a number between 0 and $($result.value.Count)." -ForegroundColor Red
                } while ($true)
            }
        }
        else
        {
            # No exact match, try similarity search
            Write-Host "  No exact match found. Searching for similar groups..." -ForegroundColor Yellow
            $similarResult, $wasSubstringSearch = GetEntraGroup -accessToken $AccessToken -groupName $GroupName -FindSimilar
            
            if ($similarResult -and $similarResult.value -and $similarResult.value.Count -gt 0)
            {
                Write-Host "  Similar groups found:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $similarResult.value.Count; $i++)
                {
                    $group = $similarResult.value[$i]
                    Write-Host "    $($i + 1). $($group.displayName) (ID: $($group.id))" -ForegroundColor White
                }
                Write-Host "    0. Enter different group name" -ForegroundColor Gray
                Write-Host "    00. Skip this group" -ForegroundColor Gray
                
                do
                {
                    $choice = Read-Host "  Select group, try different name, or skip (0/00/1-$($similarResult.value.Count))"
                    if ($choice -eq "00")
                    {
                        Write-Host "  Skipping group '$GroupName'" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped group: '$GroupName'" -LogLevel "Verbose"
                        return $null
                    }
                    elseif ($choice -eq "0")
                    {
                        # Let user enter a different group name
                        $newGroupName = Read-Host "  Enter different group name"
                        if (-not [string]::IsNullOrWhiteSpace($newGroupName))
                        {
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User trying different group name: '$($newGroupName.Trim())'" -LogLevel "Verbose"
                            return Resolve-SingleGroupInteractive -GroupName $newGroupName.Trim() -AccessToken $AccessToken -FunctionName $FunctionName
                        }
                        else
                        {
                            Write-Host "  No name entered, skipping group" -ForegroundColor Yellow
                            return $null
                        }
                    }
                    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $similarResult.value.Count)
                    {
                        $selectedGroup = $similarResult.value[[int]$choice - 1]
                        Write-Host "  Selected: '$($selectedGroup.displayName)'" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected similar group: '$($selectedGroup.displayName)' (ID: $($selectedGroup.id))" -LogLevel "Verbose"
                        return @{
                            name = $selectedGroup.displayName
                            id   = $selectedGroup.id
                        }
                    }
                    Write-Host "  Invalid choice. Please enter 0, 00, or a number between 1 and $($similarResult.value.Count)." -ForegroundColor Red
                } while ($true)
            }
            else
            {
                # No similar groups found either
                Write-Host "  No groups found matching '$GroupName'." -ForegroundColor Red
                Write-Host "  Options:" -ForegroundColor White
                Write-Host "    1. Try different group name" -ForegroundColor White
                Write-Host "    2. Save group name without ID (will resolve later)" -ForegroundColor White
                Write-Host "    3. Skip this group" -ForegroundColor White
                
                do
                {
                    $choice = Read-Host "  Select option (1-3)"
                    switch ($choice)
                    {
                        '1'
                        {
                            $newGroupName = Read-Host "  Enter different group name"
                            if (-not [string]::IsNullOrWhiteSpace($newGroupName))
                            {
                                Write-Log -LogFile $logFile -Module $FunctionName -Message "User trying different group name: '$($newGroupName.Trim())'" -LogLevel "Verbose"
                                return Resolve-SingleGroupInteractive -GroupName $newGroupName.Trim() -AccessToken $AccessToken -FunctionName $FunctionName
                            }
                            else
                            {
                                Write-Host "  No name entered, please choose again" -ForegroundColor Yellow
                                continue
                            }
                        }
                        '2'
                        {
                            Write-Host "  Saving group '$GroupName' without ID" -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to save group without ID: '$GroupName'" -LogLevel "Verbose"
                            return @{
                                name = $GroupName
                                id   = $null
                            }
                        }
                        '3'
                        {
                            Write-Host "  Skipping group '$GroupName'" -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped group: '$GroupName'" -LogLevel "Verbose"
                            return $null
                        }
                        default
                        {
                            Write-Host "  Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                            continue
                        }
                    }
                    break
                } while ($true)
            }
        }
    }
    catch
    {
        Write-Warning "[$FunctionName] Error resolving group '[REDACTED]': $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Error resolving group '[REDACTED]': $($_.Exception.Message)" -LogLevel "Warning"
        
        Write-Host "  Error occurred while searching for group. Save without ID? (y/n)" -ForegroundColor Red
        $choice = Read-Host
        if ($choice -eq 'y' -or $choice -eq 'Y')
        {
            return @{
                name = $GroupName
                id   = $null
            }
        }
        else
        {
            return $null
        }
    }
}