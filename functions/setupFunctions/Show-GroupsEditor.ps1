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
        Path to the settings.json file. Defaults to "settings.json".
    
    .PARAMETER DomainName
        The domain name for which to edit group settings. If not provided, will prompt user
        to select from available domains or use current domain.
    
    .PARAMETER Silent
        If specified, uses defaults and minimal output.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully updated, $false otherwise.
    
    .EXAMPLE
        Show-GroupsEditor -DomainName "contoso.com"
    
    .EXAMPLE
        Show-GroupsEditor -SettingsFile "settings.json"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses existing Update-Setting function for data persistence
        - Provides intuitive interface for managing group arrays
        - Handles domain selection when not specified
        - Supports both groupsToInclude and groupsToExclude editing
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [string]$DomainName,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting groups editor for domain: '$DomainName'" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting groups editor for domain: '$DomainName'"
    
    try
    {
        # Load current settings
        Write-Log -LogFile $logFile -Module $functionName -Message "Loading current settings from: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Loading current settings from: $SettingsFile"
        
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Error"
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        $currentSettings = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
        if (-not $currentSettings.domains)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No domains section found in settings file" -LogLevel "Error"
            Write-Warning "[$functionName] No domains section found in settings file"
            return $false
        }
        
        # Get domain name if not specified
        if ([string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No domain specified, prompting user to select" -LogLevel "Verbose"
            Write-Verbose "[$functionName] No domain specified, prompting user to select"
            
            $availableDomains = $currentSettings.domains.PSObject.Properties.Name
            if ($availableDomains.Count -eq 0)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "No domains available in settings" -LogLevel "Error"
                Write-Warning "[$functionName] No domains available in settings"
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
        
        # Validate domain exists
        if (-not $currentSettings.domains.PSObject.Properties.Name -contains $DomainName)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$DomainName' not found in settings" -LogLevel "Error"
            Write-Warning "[$functionName] Domain '$DomainName' not found in settings"
            return $false
        }
        
        $domainSettings = $currentSettings.domains.$DomainName
        
        # Get current group settings with safe defaults
        $domainPropertyNames = $domainSettings.PSObject.Properties.Name
        
        # Get current group settings with safe defaults
        $currentIncludeGroups = if ($domainPropertyNames -contains 'groupsToInclude') 
        { 
            $domainSettings.groupsToInclude 
        } 
        else 
        { 
            @() 
        }
        
        $currentExcludeGroups = if ($domainSettings.PSObject.Properties.Name -contains 'groupsToExclude') 
        { 
            $domainSettings.groupsToExclude 
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
            Write-Host "Managing group inclusion/exclusion settings for domain: " -NoNewline -ForegroundColor White
            Write-Host "$DomainName" -ForegroundColor Yellow -BackgroundColor DarkMagenta
            Write-Host "These settings control which groups are included or excluded from operations.`n" -ForegroundColor Gray
        }
        
        $hasChanges = $false
        $updatedIncludeGroups = $null
        $updatedExcludeGroups = $null
        
        # Edit Groups to Include
        if (-not $Silent)
        {
            Write-Host "══ Groups to Include ══" -ForegroundColor Green
            Write-Host "Groups in this list will be specifically included in operations." -ForegroundColor Gray
            Write-Host "Current groups to include:" -ForegroundColor Cyan
            
            if ($currentIncludeGroups -and $currentIncludeGroups.Count -gt 0)
            {
                foreach ($group in $currentIncludeGroups)
                {
                    Write-Host "  - $group" -ForegroundColor White
                }
            }
            else
            {
                Write-Host "  (no groups specified)" -ForegroundColor Gray
            }
            
            $choice = Read-Host "`nDo you want to modify groups to include? (y/n)"
            if ($choice -eq 'y' -or $choice -eq 'Y')
            {
                $updatedIncludeGroups = Get-GroupArrayInput -CurrentGroups $currentIncludeGroups -GroupType "include"
                if ($null -ne $updatedIncludeGroups -and (Compare-ArrayContents -Array1 $currentIncludeGroups -Array2 $updatedIncludeGroups))
                {
                    $hasChanges = $true
                    Write-Log -LogFile $logFile -Module $functionName -Message "Groups to include changed" -LogLevel "Information"
                    Write-Verbose "[$functionName] Groups to include changed"
                }
            }
        }
        
        # Edit Groups to Exclude
        if (-not $Silent)
        {
            Write-Host "`n══ Groups to Exclude ══" -ForegroundColor Red
            Write-Host "Groups in this list will be specifically excluded from operations." -ForegroundColor Gray
            Write-Host "Current groups to exclude:" -ForegroundColor Cyan
            
            if ($currentExcludeGroups -and $currentExcludeGroups.Count -gt 0)
            {
                foreach ($group in $currentExcludeGroups)
                {
                    Write-Host "  - $group" -ForegroundColor White
                }
            }
            else
            {
                Write-Host "  (no groups specified)" -ForegroundColor Gray
            }
            
            $choice = Read-Host "`nDo you want to modify groups to exclude? (y/n)"
            if ($choice -eq 'y' -or $choice -eq 'Y')
            {
                $updatedExcludeGroups = Get-GroupArrayInput -CurrentGroups $currentExcludeGroups -GroupType "exclude"
                if ($null -ne $updatedExcludeGroups -and (Compare-ArrayContents -Array1 $currentExcludeGroups -Array2 $updatedExcludeGroups))
                {
                    $hasChanges = $true
                    Write-Log -LogFile $logFile -Module $functionName -Message "Groups to exclude changed" -LogLevel "Information"
                    Write-Verbose "[$functionName] Groups to exclude changed"
                }
            }
        }
        
        # Save changes if any were made
        if ($hasChanges)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Changes detected, saving updates" -LogLevel "Information"
            Write-Verbose "[$functionName] Changes detected, saving updates"
            
            if (-not $Silent)
            {
                Write-Host "`nSaving changes..." -ForegroundColor Yellow
            }
            
            $success = $true
            
            # Update groups to include if changed
            if ($null -ne $updatedIncludeGroups)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Updating groupsToInclude for domain '$DomainName'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Updating groupsToInclude for domain '$DomainName'"
                
                $includeSuccess = Update-DomainGroupSetting -SettingsFile $SettingsFile -DomainName $DomainName -GroupType "groupsToInclude" -Groups $updatedIncludeGroups
                if (-not $includeSuccess)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update groupsToInclude" -LogLevel "Error"
                    Write-Warning "[$functionName] Failed to update groupsToInclude"
                    $success = $false
                }
            }
            
            # Update groups to exclude if changed
            if ($null -ne $updatedExcludeGroups)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Updating groupsToExclude for domain '$DomainName'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Updating groupsToExclude for domain '$DomainName'"
                
                $excludeSuccess = Update-DomainGroupSetting -SettingsFile $SettingsFile -DomainName $DomainName -GroupType "groupsToExclude" -Groups $updatedExcludeGroups
                if (-not $excludeSuccess)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update groupsToExclude" -LogLevel "Error"
                    Write-Warning "[$functionName] Failed to update groupsToExclude"
                    $success = $false
                }
            }
            
            if ($success)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Group settings updated successfully" -LogLevel "Information"
                Write-Verbose "[$functionName] Group settings updated successfully"
                if (-not $Silent)
                {
                    Write-Host "Group settings updated successfully!" -ForegroundColor Green
                }
                return $true
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update some group settings" -LogLevel "Error"
                Write-Warning "[$functionName] Failed to update some group settings"
                if (-not $Silent)
                {
                    Write-Host "Failed to update some group settings!" -ForegroundColor Red
                }
                return $false
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No changes were made" -LogLevel "Information"
            Write-Verbose "[$functionName] No changes were made"
            if (-not $Silent)
            {
                Write-Host "No changes were made." -ForegroundColor Yellow
            }
            return $true
        }
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
        Gets array input for group names with user-friendly interface.
    #>
    [CmdletBinding()]
    param(
        [array]$CurrentGroups,
        [string]$GroupType
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting group array input for $GroupType groups" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Getting group array input for $GroupType groups"
    
    Write-Host "`nEnter group names to $GroupType (one per line)." -ForegroundColor Yellow
    Write-Host "Press Enter on empty line to finish." -ForegroundColor Gray
    Write-Host "Leave first line empty to keep current values." -ForegroundColor Gray
    
    $newGroups = @()
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
                Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current $GroupType groups" -LogLevel "Verbose"
                Write-Verbose "[$functionName] User chose to keep current $GroupType groups"
                return $CurrentGroups
            }
            
            $newGroups += $input.Trim()
            Write-Log -LogFile $logFile -Module $functionName -Message "Added first $GroupType group: '$($input.Trim())'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Added first $GroupType group: '$($input.Trim())'"
        }
        else
        {
            $input = Read-Host "Group name"
            if ([string]::IsNullOrWhiteSpace($input))
            {
                break
            }
            $newGroups += $input.Trim()
            Write-Log -LogFile $logFile -Module $functionName -Message "Added $GroupType group: '$($input.Trim())'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Added $GroupType group: '$($input.Trim())'"
        }
    } while ($true)
    
    # Ensure single values are still treated as arrays
    if ($newGroups.Count -eq 1)
    {
        $result = @($newGroups[0])
        Write-Log -LogFile $logFile -Module $functionName -Message "Single group converted to array to maintain type consistency" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Single group converted to array to maintain type consistency"
    }
    else
    {
        $result = $newGroups
    }
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Returning $GroupType group array with $($result.Count) groups" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning $GroupType group array with $($result.Count) groups"
    return $result
}

function Compare-ArrayContents()
{
    <#
    .SYNOPSIS
        Compares two arrays to determine if they have different contents.
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
    
    # Compare using Compare-Object
    $comparison = Compare-Object -ReferenceObject $Array1 -DifferenceObject $Array2
    $hasChanges = $null -ne $comparison
    
    Write-Verbose "[$functionName] Array comparison result: hasChanges = $hasChanges"
    return $hasChanges
}

function Update-DomainGroupSetting()
{
    <#
    .SYNOPSIS
        Updates domain-level group settings using manual JSON manipulation.
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
        # Load current settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settingsObj = $jsonContent | ConvertFrom-Json
        
        # Ensure the domain exists
        if (-not $settingsObj.domains.PSObject.Properties.Name -contains $DomainName)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$DomainName' not found" -LogLevel "Error"
            Write-Warning "[$functionName] Domain '$DomainName' not found"
            return $false
        }
        
        # Update the specific group setting
        Write-Log -LogFile $logFile -Module $functionName -Message "Setting $GroupType to array with $($Groups.Count) groups" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Setting $GroupType to array with $($Groups.Count) groups"
        
        # Ensure Groups is always an array, even for single items
        $groupsArray = @($Groups)
        # Ensure the property exists before assignment
        if (-not ($settingsObj.domains.$DomainName.PSObject.Properties.Name -contains $GroupType)) {
            $settingsObj.domains.$DomainName | Add-Member -MemberType NoteProperty -Name $GroupType -Value $null
        }
        $settingsObj.domains.$DomainName.$GroupType = $groupsArray
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Log -LogFile $logFile -Module $functionName -Message "Created backup: $backupFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settingsObj | ConvertTo-Json -Depth $global:maxJSONDepth | Set-Content -Path $SettingsFile -Force
        Write-Log -LogFile $logFile -Module $functionName -Message "Saved updated settings to $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Saved updated settings to $SettingsFile"
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.domains.$DomainName.PSObject.Properties.Name -contains $GroupType)
        {
            $actualGroups = $verifySettings.domains.$DomainName.$GroupType
            $comparisonResult = Compare-Object -ReferenceObject $groupsArray -DifferenceObject $actualGroups
            
            if ($null -eq $comparisonResult)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Successfully updated and verified $GroupType" -LogLevel "Information"
                Write-Verbose "[$functionName] Successfully updated and verified $GroupType"
                return $true
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Verification failed for $GroupType" -LogLevel "Warning"
                Write-Warning "[$functionName] Verification failed for $GroupType"
                return $false
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Property $GroupType not found after update" -LogLevel "Warning"
            Write-Warning "[$functionName] Property $GroupType not found after update"
            return $false
        }
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error updating ${GroupType}: $($_.Exception.Message)" -LogLevel "Error"
        Write-Warning "[$functionName] Error updating ${GroupType}: $($_.Exception.Message)"
        return $false
    }
}