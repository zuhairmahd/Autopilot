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
        
        # Get domain name if not specified - use consolidated logic
        if ([string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No domain specified, attempting to determine current domain" -LogLevel "Verbose"
            Write-Verbose "[$functionName] No domain specified, attempting to determine current domain"
            
            $DomainName = Get-DomainForEditor -DomainName $DomainName -SettingsFile $SettingsFile -Silent:$Silent
            if ([string]::IsNullOrWhiteSpace($DomainName))
            {
                Write-Warning "[$functionName] No domain could be determined"
                return $false
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
                # $groupChoice = ShowMenu -Menu $groupsEditMenu -CalledBy 'Custom_GroupsEditorSubmenu' -StackOperation 'Push'
                $groupChoice = ShowMenu -Menu $groupsEditMenu -CalledBy 'Action'
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
                    Write-Log -logFile $logFile -module $functionName -Message "Found $($currentIncludeGroups.Count) groups to include"
                    Write-Verbose "[$functionName] Current groups to include count: $($currentIncludeGroups.Count)"
                    if ($currentIncludeGroups -and $currentIncludeGroups.Count -gt 0)
                    {
                        Show-EditorArrayContents -Array $currentIncludeGroups -ArrayName "groups"
                    }
                    else
                    {
                        Write-Host "  (no groups specified)" -ForegroundColor Gray
                    }
                    
                    $shouldModify = Show-EditorInteractiveChoice -PromptText "`nDo you want to modify groups to include? (y/n)"
                    if ($shouldModify)
                    {
                        $updatedIncludeGroups = Get-GroupArrayInput -CurrentGroups $currentIncludeGroups -GroupType "include" -AccessToken $AccessToken
                        if ($null -ne $updatedIncludeGroups -and (Compare-EditorArrayContents -Array1 $currentIncludeGroups -Array2 $updatedIncludeGroups))
                        {
                            Write-Log -LogFile $logFile -Module $functionName -Message "Groups to include changed" -LogLevel "Information"
                            Write-Verbose "[$functionName] Groups to include changed"
                            
                            # Save changes immediately
                            Write-Host "`nSaving changes..." -ForegroundColor Yellow
                            $includeSuccess = Update-DomainArraySetting -SettingsFile $SettingsFile -DomainName $DomainName -SettingName "groupsToInclude" -SettingValue $updatedIncludeGroups
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
                    Write-Log -logFile $logFile -module $functionName -Message "$($currentExcludeGroups.count) groups to exclude: $($currentExcludeGroups -join ', ')"
                    if ($currentExcludeGroups -and $currentExcludeGroups.Count -gt 0)
                    {
                        Show-EditorArrayContents -Array $currentExcludeGroups -ArrayName "groups"
                    }
                    else
                    {
                        Write-Host "  (no groups specified)" -ForegroundColor Gray
                    }
                    
                    $shouldModify = Show-EditorInteractiveChoice -PromptText "`nDo you want to modify groups to exclude? (y/n)"
                    if ($shouldModify)
                    {
                        $updatedExcludeGroups = Get-GroupArrayInput -CurrentGroups $currentExcludeGroups -GroupType "exclude" -AccessToken $AccessToken
                        if ($null -ne $updatedExcludeGroups -and (Compare-EditorArrayContents -Array1 $currentExcludeGroups -Array2 $updatedExcludeGroups))
                        {
                            Write-Log -LogFile $logFile -Module $functionName -Message "Groups to exclude changed" -LogLevel "Information"
                            Write-Verbose "[$functionName] Groups to exclude changed"
                            
                            # Save changes immediately
                            Write-Host "`nSaving changes..." -ForegroundColor Yellow
                            $excludeSuccess = Update-DomainArraySetting -SettingsFile $SettingsFile -DomainName $DomainName -SettingName "groupsToExclude" -SettingValue $updatedExcludeGroups
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
            $groupChoice = Read-Host "Group name"
            $firstInput = $false
            
            # If first input is empty, return current groups
            if ([string]::IsNullOrWhiteSpace($groupChoice))
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "User cancelled input, keeping current $GroupType groups" -LogLevel "Verbose"
                Write-Verbose "[$functionName] User cancelled input, keeping current $GroupType groups"
                return $CurrentGroups
            }
            
            # Process the first group name
            # For replace mode, check against building list; for add mode, check against current + building list
            $checkList = if ($shouldReplaceExisting)
            {
                $newGroupsHashTable 
            }
            else
            {
                $CurrentGroups + $newGroupsHashTable 
            }
            $resolvedGroup = Resolve-SingleGroupInteractive -GroupName $groupChoice.Trim() -AccessToken $AccessToken -ExistingItems $checkList
            if ($resolvedGroup)
            {
                $newGroupsHashTable += $resolvedGroup
                Write-Log -LogFile $logFile -Module $functionName -Message "Added first $GroupType group: '$($resolvedGroup.name)'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Added first $GroupType group: '$($resolvedGroup.name)'"
            }
            else
            {
                Write-Verbose "[$functionName] First group input was null (likely duplicate), continuing to allow re-entry"
            }
        }
        else
        {
            $groupChoice = Read-Host "Group name"
            if ([string]::IsNullOrWhiteSpace($groupChoice))
            {
                break
            }
            
            # Process each additional group name
            # For replace mode, check against building list; for add mode, check against current + building list
            $checkList = if ($shouldReplaceExisting)
            {
                $newGroupsHashTable 
            }
            else
            {
                $CurrentGroups + $newGroupsHashTable 
            }
            $resolvedGroup = Resolve-SingleGroupInteractive -GroupName $groupChoice.Trim() -AccessToken $AccessToken -ExistingItems $checkList
            if ($resolvedGroup)
            {
                $newGroupsHashTable += $resolvedGroup
                Write-Log -LogFile $logFile -Module $functionName -Message "Added $GroupType group: '$($resolvedGroup.name)'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Added $GroupType group: '$($resolvedGroup.name)'"
            }
            else
            {
                Write-Verbose "[$functionName] Group input was null (likely duplicate), ignoring and continuing"
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

function Resolve-SingleGroupInteractive()
{
    <#
    .SYNOPSIS
        Resolves a single group name to group object using interactive search.
        Checks for duplicates against existing items.
    #>
    [CmdletBinding()]
    param(
        [string]$GroupName,
        [string]$AccessToken,
        [array]$ExistingItems = @()
    )
    $FunctionName = $MyInvocation.MyCommand.Name    
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
        $result = Get-EntraDirectoryObject -EntityType Group -EntityName $groupName -AccessToken $accessToken
        if ($result -and $result.value -and $result[1] -eq $false -and $result[0].value.count -eq 1)
        {
            # Single exact match found
            $group = $result.value[0]
            Write-Host "  Found group: '$($group.displayName)' (ID: $($group.id))" -ForegroundColor Green
            
            # Check for duplicate
            if (Test-ItemExists -ItemName $group.displayName -ItemId $group.id -ExistingList $ExistingItems)
            {
                Write-Host "  WARNING: Group '$($group.displayName)' is already in the list. Please choose a different group." -ForegroundColor Yellow
                Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate group detected: '$($group.displayName)'" -LogLevel "Warning"
                return $null
            }
            
            return @{
                name = $group.displayName
                id   = $group.id
            }
        }
        else
        {
            # No exact match, try similarity search
            Write-Host "  No exact match found. Searching for similar groups..." -ForegroundColor Yellow
            $similarResult, $wasSubstringSearch = Get-EntraDirectoryObject -EntityType Group -EntityName $groupName -AccessToken $accessToken -findSimilar
            
            if ($similarResult -and $similarResult.value -and $similarResult.value.Count -gt 0)
            {
                # Auto-select if only one match found
                if ($similarResult.value.Count -eq 1)
                {
                    $group = $similarResult.value[0]
                    Write-Host "  Found group: '$($group.displayName)' (ID: $($group.id))" -ForegroundColor Green
                    Write-Log -LogFile $logFile -Module $FunctionName -Message "Auto-selected single fuzzy match: '$($group.displayName)' (ID: $($group.id))" -LogLevel "Verbose"
                    
                    # Check for duplicate
                    if (Test-ItemExists -ItemName $group.displayName -ItemId $group.id -ExistingList $ExistingItems)
                    {
                        Write-Host "  WARNING: Group '$($group.displayName)' is already in the list. Please choose a different group." -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate group detected: '$($group.displayName)'" -LogLevel "Warning"
                        return $null
                    }
                    
                    return @{
                        name = $group.displayName
                        id   = $group.id
                    }
                }
                
                # Multiple matches found, let user choose
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
                            return Resolve-SingleGroupInteractive -GroupName $newGroupName.Trim() -AccessToken $AccessToken -ExistingItems $ExistingItems
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
                        
                        # Check for duplicate
                        if (Test-ItemExists -ItemName $selectedGroup.displayName -ItemId $selectedGroup.id -ExistingList $ExistingItems)
                        {
                            Write-Host "  WARNING: Group '$($selectedGroup.displayName)' is already in the list. Please choose a different group." -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate group detected: '$($selectedGroup.displayName)'" -LogLevel "Warning"
                            return $null
                        }
                        
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
                                return Resolve-SingleGroupInteractive -GroupName $newGroupName.Trim() -AccessToken $AccessToken
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