function Show-AutopilotProfilesEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for domain-level Autopilot profile settings.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify autopilotProfilesToInclude
        arrays at the domain level. These settings control which Autopilot profiles are 
        considered valid for device assignment operations. Uses the existing Update-Setting
        infrastructure to maintain consistency with other settings management.
    
    .PARAMETER SettingsFile
        Path to the settings.psd1 file. Defaults to "settings.psd1".
    
    .PARAMETER DomainName
        The domain name for which to edit Autopilot profile settings. If not provided, will attempt 
        to use the currently loaded domain from the session. If no loaded domain is 
        available, will prompt user to select from available domains.
    
    .PARAMETER AccessToken
        Microsoft Graph access token for Autopilot profile validation and search.
    
    .PARAMETER Silent
        If specified, uses defaults and minimal output.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully updated, $false otherwise.
    
    .EXAMPLE
        Show-AutopilotProfilesEditor -DomainName "contoso.com" -AccessToken $token
    
    .EXAMPLE
        Show-AutopilotProfilesEditor -SettingsFile "settings.psd1" -AccessToken $token
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses existing Update-Setting function for data persistence
        - Provides intuitive interface for managing Autopilot profile arrays
        - Handles domain selection when not specified (prioritizes loaded domain)
        - Supports both displayName and ID storage with validation
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [string]$DomainName,
        [string]$AccessToken,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting Autopilot profiles editor for domain: '$DomainName'" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Starting Autopilot profiles editor for domain: '$DomainName'"
    
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
        
        # Get current Autopilot profile settings - preserve arrays even if empty
        # Force array type to prevent PowerShell from unwrapping single-element arrays
        $currentAutopilotProfiles = @($domainConfig.autopilotProfilesToInclude)
        Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$DomainName' has $($currentAutopilotProfiles.Count) Autopilot profiles" -LogLevel "Information"
        Write-Verbose "[$functionName] Domain '$DomainName' has $($currentAutopilotProfiles.Count) Autopilot profiles"
        
        if (-not $Silent)
        {
            Write-Host "`n══ Autopilot Profiles Editor ══" -ForegroundColor Cyan
            Write-Host "Managing Autopilot profile settings for domain: " -ForegroundColor White
            Write-Host "    $DomainName" -ForegroundColor Yellow
            Write-Host "These settings control which Autopilot profiles are considered valid for device assignment.`n" -ForegroundColor Gray
        }
        
        # Create Autopilot profiles editing menu using the menu system
        if (-not $Silent)
        {
            # Create menu from configuration, will update title with dynamic variable
            $autopilotProfilesEditMenu = NewMenu -MenuName "autopilotProfilesEditMenu"
            # Update the title to include the actual domain name
            $autopilotProfilesEditMenu.Title = $autopilotProfilesEditMenu.Title -replace '\$DomainName', $DomainName
            
            # Set actions for the menu items
            $autopilotProfilesEditMenu = AddMenuItem -Menu $autopilotProfilesEditMenu -Name "Modify Autopilot profiles to include" -Action {
                Write-Host "Selected: Modify Autopilot profiles to include" -ForegroundColor Green
                return 'modify'
            } -ReturnsValue
            $autopilotProfilesEditMenu = AddMenuItem -Menu $autopilotProfilesEditMenu -Name "View current Autopilot profile settings" -Action {
                Write-Host "Selected: View current Autopilot profile settings" -ForegroundColor Cyan
                return 'view'
            } -ReturnsValue
            
            # Loop: after editing profiles, return to the profile management menu
            while ($true)
            {
                # Use proper stack operation to maintain menu navigation integrity
                $profileChoice = ShowMenu -Menu $autopilotProfilesEditMenu -CalledBy 'Action'
                # Validate that we got a proper choice, not a navigation option
                if ($null -eq $profileChoice -or $profileChoice -eq "Back" -or $profileChoice -eq "Main Menu" -or $profileChoice -eq 0 -or $profileChoice -eq "0")
                {
                    Write-Verbose "[$functionName] ShowMenu returned navigation option: '$profileChoice', treating as navigation"
                    break
                }
                
                # Process the user's choice
                if ($profileChoice -eq 'modify')
                {
                    Write-Host "`n══ Autopilot Profiles to Include ══" -ForegroundColor Green
                    Write-Host "Profiles in this list will be considered valid for device assignment." -ForegroundColor Gray
                    Write-Host "Current Autopilot profiles:" -ForegroundColor Cyan
                    Write-Log -LogFile $logFile -Module $functionName -Message "Found $($currentAutopilotProfiles.Count) Autopilot profiles" -LogLevel "Information"
                    Write-Verbose "[$functionName] Current Autopilot profiles count: $($currentAutopilotProfiles.Count)"
                    
                    if ($currentAutopilotProfiles -and $currentAutopilotProfiles.Count -gt 0)
                    {
                        Show-EditorArrayContents -Array $currentAutopilotProfiles -ArrayName "Autopilot profiles" 
                    }
                    else
                    {
                        Write-Host "  (no Autopilot profiles specified)" -ForegroundColor Gray
                    }
                    
                    # Get updated profiles
                    $updatedProfiles = Get-AutopilotProfileArrayInput -CurrentProfiles $currentAutopilotProfiles -AccessToken $AccessToken
                    if ($null -ne $updatedProfiles -and (Compare-EditorArrayContents -Array1 $currentAutopilotProfiles -Array2 $updatedProfiles))
                    {
                        Write-Log -LogFile $logFile -Module $functionName -Message "Autopilot profiles changed" -LogLevel "Information"
                        Write-Verbose "[$functionName] Autopilot profiles changed"
                        
                        # Save changes immediately
                        Write-Host "`nSaving changes..." -ForegroundColor Yellow
                        $success = Update-DomainArraySetting -SettingsFile $SettingsFile -DomainName $DomainName -SettingName "autopilotProfilesToInclude" -SettingValue $updatedProfiles
                        if ($success)
                        {
                            Write-Host "Autopilot profile settings updated successfully!" -ForegroundColor Green
                            Write-Host "`nAutopilot profile settings updated successfully. Changes will take effect immediately." -ForegroundColor Green
                            Write-Host "Press any key to continue..." -ForegroundColor Yellow
                            [void][System.Console]::ReadKey($true)
                            # Update current values for future operations
                            $currentAutopilotProfiles = $updatedProfiles
                        }
                        else
                        {
                            Write-Host "Failed to update Autopilot profile settings!" -ForegroundColor Red
                            Write-Host "Press any key to continue..." -ForegroundColor Yellow
                            [void][System.Console]::ReadKey($true)
                        }
                    }
                }
                elseif ($profileChoice -eq 'view')
                {
                    Write-Host "`n══ Current Autopilot Profile Settings ══" -ForegroundColor Cyan
                    Write-Host "Domain: $DomainName`n" -ForegroundColor Yellow
                    Write-Host "Autopilot Profiles to Include:" -ForegroundColor Green
                    Write-Verbose "[$functionName] Found $($currentAutopilotProfiles.count) Autopilot profiles"
                    write-log -LogFile $logFile -Module $functionName -Message "Found $($currentAutopilotProfiles.count) Autopilot profiles" -LogLevel "Information"
                    if ($currentAutopilotProfiles -and $currentAutopilotProfiles.Count -gt 0)
                    {
                        # Detect format and display accordingly
                        $firstElement = $currentAutopilotProfiles[0]
                        if ($null -ne $firstElement)
                        {
                            Write-Verbose "[$functionName] First element type: $($firstElement.GetType().FullName)"
                            write-log -LogFile $logFile -Module $functionName -Message "First element type: $($firstElement.GetType().FullName)" -LogLevel "Information"
                        }                       
                        if ($firstElement -is [string])
                        {
                            # Old string format
                            Write-Verbose "[$functionName] Detected string array format for Autopilot profiles"
                            write-log -LogFile $logFile -Module $functionName -Message "Detected string array format for Autopilot profiles" -LogLevel "Information"
                            foreach ($autopilotProfile in $currentAutopilotProfiles)
                            {
                                Write-Host "  - $autopilotProfile" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentAutopilotProfiles.Count) profile(s) [Legacy Format]" -ForegroundColor Yellow
                        }
                        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
                            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name')) -or 
                            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name'))))
                        {
                            # New hashtable format
                            Write-Verbose "[$functionName] Detected hashtable format for Autopilot profiles"
                            write-log -LogFile $logFile -Module $functionName -Message "Detected hashtable format for Autopilot profiles" -LogLevel "Information"           
                            foreach ($autopilotProfile in $currentAutopilotProfiles)
                            {
                                Write-Host " - Name: $($autopilotProfile.name)" -ForegroundColor White
                                if ($autopilotProfile.id)
                                {
                                    Write-Host " ID: $($autopilotProfile.id)" -ForegroundColor Gray
                                }
                                else
                                {
                                    Write-Host " ID: (not resolved)" -ForegroundColor Yellow
                                }
                            }
                            Write-Host " Total: $($currentAutopilotProfiles.Count) profile(s) [Enhanced Format]" -ForegroundColor Green
                        }
                        else
                        {
                            # Fallback for unknown format
                            Write-Verbose "[$functionName] Unknown format for Autopilot profiles, displaying raw values"
                            write-log -LogFile $logFile -Module $functionName -Message "Unknown format for Autopilot profiles, displaying raw values" -LogLevel "Warning"
                            foreach ($autopilotProfile in $currentAutopilotProfiles)
                            {   
                                Write-Host " - $autopilotProfile" -ForegroundColor White
                            }
                            Write-Host " Total: $($currentAutopilotProfiles.Count) profile(s)" -ForegroundColor Gray
                        }
                    }
                    else
                    {
                        Write-Host " (no Autopilot profiles specified)" -ForegroundColor Gray
                        write-log -LogFile $logFile -Module $functionName -Message "No Autopilot profiles specified" -LogLevel "Warning"
                    }
                    
                    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                    [void][System.Console]::ReadKey($true)
                }
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "User finished editing Autopilot profiles, returning $profileChoice" -LogLevel "Information"
            if ($null -eq $profileChoice -or $profileChoice -eq 0 -or $profileChoice -eq "0" -or $profileChoice -eq "Back" -or $profileChoice -eq "Main Menu")
            {
                return $profileChoice
            }
        }
        
        # Since settings are now saved immediately after each edit operation,
        # we no longer need to defer saving until the end
        Write-Log -LogFile $logFile -Module $functionName -Message "Autopilot profiles editor completed" -LogLevel "Information"
        Write-Verbose "[$functionName] Autopilot profiles editor completed"
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in Autopilot profiles editor: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in Autopilot profiles editor: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Get-AutopilotProfileArrayInput()
{
    <#
    .SYNOPSIS
        Gets array input for Autopilot profile names and IDs with interactive resolution.
        Supports both old string array format and new hashtable format.
        Uses GetAutopilotProfile for enhanced search capabilities.
    #>
    [CmdletBinding()]
    param(
        [array]$CurrentProfiles,
        [string]$AccessToken  # Added for profile ID resolution
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting Autopilot profile array input" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Getting Autopilot profile array input"
    
    # Detect current format and display appropriately
    $currentFormat = "Empty"
    if ($CurrentProfiles -and $CurrentProfiles.Count -gt 0)
    {
        $firstElement = $CurrentProfiles[0]
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
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Current Autopilot profiles format: $currentFormat" -LogLevel "Verbose"
    
    # Get user decision for replace/add/keep
    $decision = Get-EditorReplaceOrAddChoice -CurrentArray $CurrentProfiles -ItemType 'profile'
    
    if ($decision.ShouldProceed)
    {
        # Display operation mode banner
        if ($decision.ShouldReplaceExisting)
        {
            Write-Host "`n=======================================" -ForegroundColor Yellow
            Write-Host " MODE: REPLACE - Old profiles will be removed" -ForegroundColor Yellow
            Write-Host "=======================================" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "`n=======================================" -ForegroundColor Green
            Write-Host " MODE: ADD - New profiles will be added" -ForegroundColor Green
            Write-Host "=======================================" -ForegroundColor Green
        }
    
        if ($CurrentProfiles -and $CurrentProfiles.Count -gt 0)
        {
            Write-Host "`nCurrent profiles:" -ForegroundColor Cyan
            if ($currentFormat -eq "HashTableArray")
            {
                foreach ($autopilotProfile in $CurrentProfiles)
                {
                    Write-Host " - Name: $($autopilotProfile.name)" -ForegroundColor White
                    Write-Host " ID: $($autopilotProfile.id)" -ForegroundColor Gray
                }
            }
            else
            {
                foreach ($autopilotProfile in $CurrentProfiles)
                {
                    Write-Host " - $autopilotProfile" -ForegroundColor White
                }
            }
        }
        Write-Host ""
        if ($decision.ShouldReplaceExisting)
        {
            Write-Host "[!] REPLACE MODE: Enter new profiles (old profiles will be removed)" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "[ + ] ADD MODE: Enter new profiles (old profiles will be kept)" -ForegroundColor Green
        }
        Write-Host " * Enter profile names one per line" -ForegroundColor Gray
        Write-Host " * Profile names will be searched and resolved interactively" -ForegroundColor Gray
        Write-Host " * Press Enter on empty line to finish" -ForegroundColor Gray
        Write-Host " * Leave first line empty to cancel" -ForegroundColor Gray
    
        $newProfilesHashTable = @()
        $firstInput = $true
        do
        {
            if ($firstInput)
            {
                $choice = Read-Host "Profile name"
                $firstInput = $false
            
                # If first input is empty, return current profiles
                if ([string]::IsNullOrWhiteSpace($choice))
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "User cancelled input, keeping current Autopilot profiles" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User cancelled input, keeping current Autopilot profiles"
                    return $CurrentProfiles
                }
            
                # Process the first profile name
                # For replace mode, check against building list; for add mode, check against current + building list
                $checkList = if ($decision.ShouldReplaceExisting)
                {
                    $newProfilesHashTable 
                }
                else
                {
                    $CurrentProfiles + $newProfilesHashTable 
                }
                $resolvedProfile = Resolve-SingleAutopilotProfileInteractive -ProfileName $choice.Trim() -AccessToken $AccessToken -ExistingItems $checkList
                if ($resolvedProfile)
                {
                    $newProfilesHashTable += $resolvedProfile
                    Write-Log -LogFile $logFile -Module $functionName -Message "Added first Autopilot profile: '$($resolvedProfile.name)'" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Added first Autopilot profile: '$($resolvedProfile.name)'"
                }
                else
                {
                    Write-Verbose "[$functionName] First profile input was null (likely duplicate), continuing to allow re-entry"
                }
            }
            else
            {
                $choice = Read-Host "Profile name"
                if ([string]::IsNullOrWhiteSpace($choice))
                {
                    break
                }
            
                # Process each additional profile name
                # For replace mode, check against building list; for add mode, check against current + building list
                $checkList = if ($decision.ShouldReplaceExisting)
                {
                    $newProfilesHashTable 
                }
                else
                {
                    $CurrentProfiles + $newProfilesHashTable 
                }
                $resolvedProfile = Resolve-SingleAutopilotProfileInteractive -ProfileName $choice.Trim() -AccessToken $AccessToken -ExistingItems $checkList
                if ($resolvedProfile)
                {
                    $newProfilesHashTable += $resolvedProfile
                    Write-Log -LogFile $logFile -Module $functionName -Message "Added Autopilot profile: '$($resolvedProfile.name)'" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Added Autopilot profile: '$($resolvedProfile.name)'"
                }
                else
                {
                    Write-Verbose "[$functionName] Profile input was null (likely duplicate), ignoring and continuing"
                }
            }
        } while ($true)
        
        # Show summary of what will be saved
        Write-Host ""
        if ($decision.ShouldReplaceExisting)
        {
            Write-Host "=======================================" -ForegroundColor Yellow
            Write-Host " SUMMARY - REPLACE MODE" -ForegroundColor Yellow
            Write-Host "=======================================" -ForegroundColor Yellow
            Write-Host "Old profiles ($($CurrentProfiles.Count)): REMOVED" -ForegroundColor Red
            Write-Host "New profiles ($($newProfilesHashTable.Count)): WILL BE SAVED" -ForegroundColor Green
        }
        else
        {
            Write-Host "=======================================" -ForegroundColor Green
            Write-Host " SUMMARY - ADD MODE" -ForegroundColor Green
            Write-Host "=======================================" -ForegroundColor Green
            Write-Host "Old profiles ($($CurrentProfiles.Count)): KEPT" -ForegroundColor Green
            Write-Host "New profiles ($($newProfilesHashTable.Count)): ADDED" -ForegroundColor Green
            Write-Host "Total profiles: $($CurrentProfiles.Count + $newProfilesHashTable.Count)" -ForegroundColor Cyan
        }
        Write-Host ""
        
        # Determine final result based on user choice and format compatibility
    
        if ($decision.ShouldReplaceExisting -or -not $CurrentProfiles -or $CurrentProfiles.Count -eq 0)
        {
            # Replace existing profiles
            $result = $newProfilesHashTable
        }
        else
        {
            # Add to existing profiles - need to handle format conversion
            $combinedProfiles = @()
        
            # Add existing profiles in hashtable format
            if ($currentFormat -eq "HashTableArray")
            {
                $combinedProfiles += $CurrentProfiles
            }
            elseif ($currentFormat -eq "StringArray")
            {
                # Convert old string format to hashtable format
                Write-Host "`nConverting existing profiles to new format..." -ForegroundColor Yellow
                foreach ($profileName in $CurrentProfiles)
                {
                    $combinedProfiles += @{
                        name = $profileName
                        id   = $null  # Will be resolved when profile validation is called
                    }
                }
            }
        
            # Add new profiles
            $combinedProfiles += $newProfilesHashTable
            $result = $combinedProfiles
        }
    }
    else
    {
        # User chose to keep current profiles unchanged
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Host " NO CHANGES - Keeping $($CurrentProfiles.Count) existing profiles" -ForegroundColor Cyan
        Write-Host "=======================================" -ForegroundColor Cyan
        Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current Autopilot profiles unchanged" -LogLevel "Verbose"
        Write-Verbose "[$functionName] User chose to keep current Autopilot profiles unchanged"
        $result = $CurrentProfiles
    }
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Returning Autopilot profile array with $($result.Count) profiles in hashtable format" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning Autopilot profile array with $($result.Count) profiles in hashtable format"
    return $result
}

function Resolve-SingleAutopilotProfileInteractive()
{
    <#
    .SYNOPSIS
        Resolves a single Autopilot profile name to profile object using interactive search.
        Uses GetAutopilotProfile function for better search capabilities.
        Checks for duplicates against existing items.
    
    .PARAMETER Silent
        If specified and a single exact match is found, returns the profile without prompting.
        Interactive prompts still occur for multiple matches or no matches.
    #>
    [CmdletBinding()]
    param(
        [string]$ProfileName,
        [string]$AccessToken,
        [array]$ExistingItems = @(),
        [switch]$Silent
    )
    
    $FunctionName = $MyInvocation.MyCommand.Name    
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Resolving Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
    if (-not $AccessToken)
    {
        Write-Host " No access token available - saving profile without ID resolution" -ForegroundColor Yellow
        return @{
            name = $ProfileName
            id   = $null
        }
    }
    
    try
    {
        # First try exact match
        if (-not $Silent)
        {
            Write-Host " Searching for Autopilot profile: '$ProfileName'..." -ForegroundColor Cyan
        }
        else
        {
            Write-Verbose "[$FunctionName] Searching for Autopilot profile: '$ProfileName' (Silent mode)"
        }
        
        $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $AccessToken -ProfileName $ProfileName
        
        if ($result -and $result.value -and $result.value.Count -gt 0)
        {
            if ($result.value.Count -eq 1)
            {
                # Single exact match found
                $autopilotProfile = $result.value[0]
                
                # Check for duplicate
                if (Test-ItemExists -ItemName $autopilotProfile.displayName -ItemId $autopilotProfile.id -ExistingList $ExistingItems)
                {
                    if (-not $Silent)
                    {
                        Write-Host " WARNING: Profile '$($autopilotProfile.displayName)' is already in the list. Please choose a different profile." -ForegroundColor Yellow
                    }
                    Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate profile detected: '$($autopilotProfile.displayName)'" -LogLevel "Warning"
                    return $null
                }
                
                # In Silent mode with exact match, automatically accept without prompting
                if ($Silent)
                {
                    Write-Verbose "[$FunctionName] Silent mode: Auto-accepted exact match '$($autopilotProfile.displayName)' (ID: $($autopilotProfile.id))"
                    Write-Log -LogFile $logFile -Module $FunctionName -Message "Silent mode: Auto-accepted exact match '$($autopilotProfile.displayName)' (ID: $($autopilotProfile.id))" -LogLevel "Verbose"
                }
                else
                {
                    Write-Host " Found profile: '$($autopilotProfile.displayName)' (ID: $($autopilotProfile.id))" -ForegroundColor Green
                }
                
                return @{
                    name = $autopilotProfile.displayName
                    id   = $autopilotProfile.id
                }
            }
            else
            {
                # Multiple matches found, let user choose
                Write-Host " Multiple Autopilot profiles found matching '$ProfileName':" -ForegroundColor Yellow
                for ($i = 0; $i -lt $result.value.Count; $i++)
                {
                    $autopilotProfile = $result.value[$i]
                    Write-Host " $($i + 1). $($autopilotProfile.displayName) (ID: $($autopilotProfile.id))" -ForegroundColor White
                }
                Write-Host " 0. Skip this profile" -ForegroundColor Gray
                
                do
                {
                    $choice = Read-Host " Select profile (0 - $($result.value.Count))"
                    if ($choice -eq "0")
                    {
                        Write-Host " Skipping Autopilot profile '$ProfileName'" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
                        return $null
                    }
                    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $result.value.Count)
                    {
                        $selectedProfile = $result.value[[int]$choice - 1]
                        Write-Host " Selected: '$($selectedProfile.displayName)'" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected Autopilot profile: '$($selectedProfile.displayName)' (ID: $($selectedProfile.id))" -LogLevel "Verbose"
                        
                        # Check for duplicate
                        if (Test-ItemExists -ItemName $selectedProfile.displayName -ItemId $selectedProfile.id -ExistingList $ExistingItems)
                        {
                            Write-Host " WARNING: Profile '$($selectedProfile.displayName)' is already in the list. Please choose a different profile." -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate profile detected: '$($selectedProfile.displayName)'" -LogLevel "Warning"
                            return $null
                        }
                        
                        return @{
                            name = $selectedProfile.displayName
                            id   = $selectedProfile.id
                        }
                    }
                    Write-Host " Invalid choice. Please enter a number between 0 and $($result.value.Count)." -ForegroundColor Red
                } while ($true)
            }
        }
        else
        {
            # No exact match, try similarity search
            Write-Host " No exact match found. Searching for similar Autopilot profiles..." -ForegroundColor Yellow
            $similarResult, $wasSubstringSearch = GetAutopilotProfile -AccessToken $AccessToken -ProfileName $ProfileName -FindSimilar
            
            if ($similarResult -and $similarResult.value -and $similarResult.value.Count -gt 0)
            {
                Write-Host " Similar Autopilot profiles found:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $similarResult.value.Count; $i++)
                {
                    $autopilotProfile = $similarResult.value[$i]
                    Write-Host " $($i + 1). $($autopilotProfile.displayName) (ID: $($autopilotProfile.id))" -ForegroundColor White
                }
                Write-Host " 0. Enter different profile name" -ForegroundColor Gray
                Write-Host " 00. Skip this profile" -ForegroundColor Gray
                
                do
                {
                    $choice = Read-Host " Select profile, try different name, or skip (0 / 00 / 1 - $($similarResult.value.Count))"
                    if ($choice -eq "00")
                    {
                        Write-Host " Skipping Autopilot profile '$ProfileName'" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
                        return $null
                    }
                    elseif ($choice -eq "0")
                    {
                        # Let user enter a different profile name
                        $newProfileName = Read-Host " Enter different Autopilot profile name"
                        if (-not [string]::IsNullOrWhiteSpace($newProfileName))
                        {
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User trying different Autopilot profile name: '$($newProfileName.Trim())'" -LogLevel "Verbose"
                            return Resolve-SingleAutopilotProfileInteractive -ProfileName $newProfileName.Trim() -AccessToken $AccessToken -ExistingItems $ExistingItems
                        }
                        else
                        {
                            Write-Host " No name entered, skipping profile" -ForegroundColor Yellow
                            return $null
                        }
                    }
                    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $similarResult.value.Count)
                    {
                        $selectedProfile = $similarResult.value[[int]$choice - 1]
                        Write-Host " Selected: '$($selectedProfile.displayName)'" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected similar Autopilot profile: '$($selectedProfile.displayName)' (ID: $($selectedProfile.id))" -LogLevel "Verbose"
                        
                        # Check for duplicate
                        if (Test-ItemExists -ItemName $selectedProfile.displayName -ItemId $selectedProfile.id -ExistingList $ExistingItems)
                        {
                            Write-Host " WARNING: Profile '$($selectedProfile.displayName)' is already in the list. Please choose a different profile." -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate profile detected: '$($selectedProfile.displayName)'" -LogLevel "Warning"
                            return $null
                        }
                        
                        return @{
                            name = $selectedProfile.displayName
                            id   = $selectedProfile.id
                        }
                    }
                    Write-Host " Invalid choice. Please enter 0, 00, or a number between 1 and $($similarResult.value.Count)." -ForegroundColor Red
                } while ($true)
            }
            else
            {
                # No similar profiles found either
                Write-Host " No Autopilot profiles found matching '$ProfileName'." -ForegroundColor Red
                Write-Host " Options:" -ForegroundColor White
                Write-Host " 1. Try different profile name" -ForegroundColor White
                Write-Host " 2. View all Autopilot profiles" -ForegroundColor White
                Write-Host " 3. Save profile name without ID (will resolve later)" -ForegroundColor White
                Write-Host " 4. Skip this profile" -ForegroundColor White
                
                do
                {
                    $choice = Read-Host " Select option (1 - 4)"
                    switch ($choice)
                    {
                        '1'
                        {
                            $newProfileName = Read-Host " Enter different Autopilot profile name"
                            if (-not [string]::IsNullOrWhiteSpace($newProfileName))
                            {
                                Write-Log -LogFile $logFile -Module $FunctionName -Message "User trying different Autopilot profile name: '$($newProfileName.Trim())'" -LogLevel "Verbose"
                                return Resolve-SingleAutopilotProfileInteractive -ProfileName $newProfileName.Trim() -AccessToken $AccessToken -ExistingItems $ExistingItems
                            }
                            else
                            {
                                Write-Host " No name entered, please choose again" -ForegroundColor Yellow
                                continue
                            }
                        }
                        '2'
                        {
                            # View all Autopilot profiles
                            Write-Host ""
                            Write-Host " Retrieving all Autopilot profiles..." -ForegroundColor Cyan
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to view all Autopilot profiles" -LogLevel "Verbose"
                            
                            $allProfilesResult, $wasSubstringSearch = GetAutopilotProfile -AccessToken $AccessToken -GetAll
                            
                            if ($allProfilesResult -and $allProfilesResult.value -and $allProfilesResult.value.Count -gt 0)
                            {
                                Write-Host " All Autopilot profiles ($($allProfilesResult.value.Count) total):" -ForegroundColor Yellow
                                for ($i = 0; $i -lt $allProfilesResult.value.Count; $i++)
                                {
                                    $autopilotProfile = $allProfilesResult.value[$i]
                                    Write-Host " $($i + 1). $($autopilotProfile.displayName) (ID: $($autopilotProfile.id))" -ForegroundColor White
                                }
                                Write-Host " 0. Go back to options" -ForegroundColor Gray
                                
                                do
                                {
                                    $profileChoice = Read-Host " Select profile (0 - $($allProfilesResult.value.Count))"
                                    if ($profileChoice -eq "0")
                                    {
                                        Write-Host " Returning to options menu" -ForegroundColor Yellow
                                        continue  # This will go back to the outer do-while loop
                                    }
                                    elseif ($profileChoice -match '^\d+$' -and [int]$profileChoice -ge 1 -and [int]$profileChoice -le $allProfilesResult.value.Count)
                                    {
                                        $selectedProfile = $allProfilesResult.value[[int]$profileChoice - 1]
                                        Write-Host " Selected: '$($selectedProfile.displayName)'" -ForegroundColor Green
                                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected Autopilot profile from all profiles list: '$($selectedProfile.displayName)' (ID: $($selectedProfile.id))" -LogLevel "Verbose"
                                        
                                        # Check for duplicate
                                        if (Test-ItemExists -ItemName $selectedProfile.displayName -ItemId $selectedProfile.id -ExistingList $ExistingItems)
                                        {
                                            Write-Host " WARNING: Profile '$($selectedProfile.displayName)' is already in the list. Please choose a different profile." -ForegroundColor Yellow
                                            Write-Log -LogFile $logFile -Module $FunctionName -Message "Duplicate profile detected: '$($selectedProfile.displayName)'" -LogLevel "Warning"
                                            return $null
                                        }
                                        
                                        return @{
                                            name = $selectedProfile.displayName
                                            id   = $selectedProfile.id
                                        }
                                    }
                                    Write-Host " Invalid choice. Please enter a number between 0 and $($allProfilesResult.value.Count)." -ForegroundColor Red
                                } while ($true)
                            }
                            else
                            {
                                Write-Host " Failed to retrieve Autopilot profiles or no profiles exist" -ForegroundColor Red
                                Write-Log -LogFile $logFile -Module $FunctionName -Message "Failed to retrieve all Autopilot profiles" -LogLevel "Error"
                                continue  # Go back to options menu
                            }
                        }
                        '3'
                        {
                            Write-Host " Saving Autopilot profile '$ProfileName' without ID" -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to save Autopilot profile without ID: '$ProfileName'" -LogLevel "Verbose"
                            return @{
                                name = $ProfileName
                                id   = $null
                            }
                        }
                        '4'
                        {
                            Write-Host " Skipping Autopilot profile '$ProfileName'" -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
                            return $null
                        }
                        default
                        {
                            Write-Host " Invalid choice. Please enter 1, 2, 3, or 4." -ForegroundColor Red
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
        Write-Warning "[$FunctionName] Error resolving Autopilot profile '[REDACTED]': $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Error resolving Autopilot profile '[REDACTED]': $($_.Exception.Message)" -LogLevel "Warning"
        
        Write-Host " Error occurred while searching for Autopilot profile. Save without ID? (y/n)" -ForegroundColor Red
        $choice = Read-Host
        if ($choice -eq 'y' -or $choice -eq 'Y')
        {
            return @{
                name = $ProfileName
                id   = $null
            }
        }
        else
        {
            return $null
        }
    }
}