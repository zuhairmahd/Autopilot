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
        $currentAutopilotProfiles = if ($null -ne $domainConfig.autopilotProfilesToInclude) 
        { 
            $domainConfig.autopilotProfilesToInclude 
        } 
        else 
        { 
            @() 
        }
        
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
                $profileChoice = ShowMenu -Menu $autopilotProfilesEditMenu -CalledBy 'Custom_AutopilotProfilesEditorSubmenu' -StackOperation 'Push'
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
                        $success = Update-DomainArraySetting -SettingsFile $SettingsFile -DomainName $DomainName -SettingName "autopilotProfiles" -SettingValue $updatedProfiles
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
                    if ($currentAutopilotProfiles -and $currentAutopilotProfiles.Count -gt 0)
                    {
                        # Detect format and display accordingly
                        $firstElement = $currentAutopilotProfiles[0]
                        if ($firstElement -is [string])
                        {
                            # Old string format
                            foreach ($profile in $currentAutopilotProfiles)
                            {
                                Write-Host "  - $profile" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentAutopilotProfiles.Count) profile(s) [Legacy Format]" -ForegroundColor Yellow
                        }
                        elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and 
                            (($firstElement -is [hashtable] -and $firstElement.ContainsKey('name')) -or 
                            ($firstElement -is [PSCustomObject] -and ($firstElement.PSObject.Properties.Name -contains 'name'))))
                        {
                            # New hashtable format
                            foreach ($profile in $currentAutopilotProfiles)
                            {
                                Write-Host "  - Name: $($profile.name)" -ForegroundColor White
                                if ($profile.id)
                                {
                                    Write-Host "    ID:   $($profile.id)" -ForegroundColor Gray
                                }
                                else
                                {
                                    Write-Host "    ID:   (not resolved)" -ForegroundColor Yellow
                                }
                            }
                            Write-Host "  Total: $($currentAutopilotProfiles.Count) profile(s) [Enhanced Format]" -ForegroundColor Green
                        }
                        else
                        {
                            # Fallback for unknown format
                            foreach ($profile in $currentAutopilotProfiles)
                            {
                                Write-Host "  - $profile" -ForegroundColor White
                            }
                            Write-Host "  Total: $($currentAutopilotProfiles.Count) profile(s)" -ForegroundColor Gray
                        }
                    }
                    else
                    {
                        Write-Host "  (no Autopilot profiles specified)" -ForegroundColor Gray
                    }
                    
                    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                    [void][System.Console]::ReadKey($true)
                }
            }
        }
        
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
    
    # Display current profiles in appropriate format
    if ($CurrentProfiles -and $CurrentProfiles.Count -gt 0)
    {
        Write-Host "`nCurrent Autopilot profiles:" -ForegroundColor Cyan
        if ($currentFormat -eq "HashTableArray")
        {
            foreach ($profile in $CurrentProfiles)
            {
                Write-Host "  - Name: $($profile.name)" -ForegroundColor White
                Write-Host "    ID:   $($profile.id)" -ForegroundColor Gray
            }
        }
        else
        {
            foreach ($profile in $CurrentProfiles)
            {
                Write-Host "  - $profile" -ForegroundColor White
            }
        }
    }
    
    # Determine if we should ask about replace vs add
    $shouldReplaceExisting = $true
    if ($CurrentProfiles -and $CurrentProfiles.Count -gt 0)
    {
        Write-Host "`nYou have existing Autopilot profiles in this list." -ForegroundColor Yellow
        Write-Host "Do you want to:" -ForegroundColor White
        Write-Host "  1. Replace all existing profiles with new ones" -ForegroundColor White
        Write-Host "  2. Add new profiles to the existing ones" -ForegroundColor White
        Write-Host "  3. Keep current profiles unchanged" -ForegroundColor White
        
        do
        {
            $choice = Read-Host "Enter your choice (1-3)"
            switch ($choice)
            {
                '1'
                {
                    $shouldReplaceExisting = $true
                    Write-Log -LogFile $logFile -Module $functionName -Message "User chose to replace existing Autopilot profiles" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User chose to replace existing Autopilot profiles"
                    break
                }
                '2'
                {
                    $shouldReplaceExisting = $false
                    Write-Log -LogFile $logFile -Module $functionName -Message "User chose to add to existing Autopilot profiles" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User chose to add to existing Autopilot profiles"
                    break
                }
                '3'
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current Autopilot profiles unchanged" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] User chose to keep current Autopilot profiles unchanged"
                    return $CurrentProfiles
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
    
    Write-Host "`nEnter Autopilot profile names (one per line)." -ForegroundColor Yellow
    Write-Host "Profile names will be searched and resolved interactively." -ForegroundColor Green
    Write-Host "Press Enter on empty line to finish." -ForegroundColor Gray
    if (-not $shouldReplaceExisting)
    {
        Write-Host "New profiles will be added to the existing ones." -ForegroundColor Green
    }
    Write-Host "Leave first line empty to cancel." -ForegroundColor Gray
    
    $newProfilesHashTable = @()
    $firstInput = $true
    
    do
    {
        if ($firstInput)
        {
            $input = Read-Host "Autopilot profile name"
            $firstInput = $false
            
            # If first input is empty, return current profiles
            if ([string]::IsNullOrWhiteSpace($input))
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "User cancelled input, keeping current Autopilot profiles" -LogLevel "Verbose"
                Write-Verbose "[$functionName] User cancelled input, keeping current Autopilot profiles"
                return $CurrentProfiles
            }
            
            # Process the first profile name
            $resolvedProfile = Resolve-SingleAutopilotProfileInteractive -ProfileName $input.Trim() -AccessToken $AccessToken
            if ($resolvedProfile)
            {
                $newProfilesHashTable += $resolvedProfile
                Write-Log -LogFile $logFile -Module $functionName -Message "Added first Autopilot profile: '$($resolvedProfile.name)'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Added first Autopilot profile: '$($resolvedProfile.name)'"
            }
        }
        else
        {
            $input = Read-Host "Autopilot profile name"
            if ([string]::IsNullOrWhiteSpace($input))
            {
                break
            }
            
            # Process each additional profile name
            $resolvedProfile = Resolve-SingleAutopilotProfileInteractive -ProfileName $input.Trim() -AccessToken $AccessToken
            if ($resolvedProfile)
            {
                $newProfilesHashTable += $resolvedProfile
                Write-Log -LogFile $logFile -Module $functionName -Message "Added Autopilot profile: '$($resolvedProfile.name)'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Added Autopilot profile: '$($resolvedProfile.name)'"
            }
        }
    } while ($true)
    
    # Determine final result based on user choice and format compatibility
    if ($shouldReplaceExisting -or -not $CurrentProfiles -or $CurrentProfiles.Count -eq 0)
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
    #>
    [CmdletBinding()]
    param(
        [string]$ProfileName,
        [string]$AccessToken,
        [string]$FunctionName
    )
    
    Write-Log -LogFile $logFile -Module $FunctionName -Message "Resolving Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
    
    if (-not $AccessToken)
    {
        Write-Host "  No access token available - saving profile without ID resolution" -ForegroundColor Yellow
        return @{
            name = $ProfileName
            id   = $null
        }
    }
    
    try
    {
        # First try exact match
        Write-Host "  Searching for Autopilot profile: '$ProfileName'..." -ForegroundColor Cyan
        $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $AccessToken -ProfileName $ProfileName
        
        if ($result -and $result.value -and $result.value.Count -gt 0)
        {
            if ($result.value.Count -eq 1)
            {
                # Single exact match found
                $profile = $result.value[0]
                Write-Host "  Found profile: '$($profile.displayName)' (ID: $($profile.id))" -ForegroundColor Green
                return @{
                    name = $profile.displayName
                    id   = $profile.id
                }
            }
            else
            {
                # Multiple matches found, let user choose
                Write-Host "  Multiple Autopilot profiles found matching '$ProfileName':" -ForegroundColor Yellow
                for ($i = 0; $i -lt $result.value.Count; $i++)
                {
                    $profile = $result.value[$i]
                    Write-Host "    $($i + 1). $($profile.displayName) (ID: $($profile.id))" -ForegroundColor White
                }
                Write-Host "    0. Skip this profile" -ForegroundColor Gray
                
                do
                {
                    $choice = Read-Host "  Select profile (0-$($result.value.Count))"
                    if ($choice -eq "0")
                    {
                        Write-Host "  Skipping Autopilot profile '$ProfileName'" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
                        return $null
                    }
                    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $result.value.Count)
                    {
                        $selectedProfile = $result.value[[int]$choice - 1]
                        Write-Host "  Selected: '$($selectedProfile.displayName)'" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected Autopilot profile: '$($selectedProfile.displayName)' (ID: $($selectedProfile.id))" -LogLevel "Verbose"
                        return @{
                            name = $selectedProfile.displayName
                            id   = $selectedProfile.id
                        }
                    }
                    Write-Host "  Invalid choice. Please enter a number between 0 and $($result.value.Count)." -ForegroundColor Red
                } while ($true)
            }
        }
        else
        {
            # No exact match, try similarity search
            Write-Host "  No exact match found. Searching for similar Autopilot profiles..." -ForegroundColor Yellow
            $similarResult, $wasSubstringSearch = GetAutopilotProfile -AccessToken $AccessToken -ProfileName $ProfileName -FindSimilar
            
            if ($similarResult -and $similarResult.value -and $similarResult.value.Count -gt 0)
            {
                Write-Host "  Similar Autopilot profiles found:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $similarResult.value.Count; $i++)
                {
                    $profile = $similarResult.value[$i]
                    Write-Host "    $($i + 1). $($profile.displayName) (ID: $($profile.id))" -ForegroundColor White
                }
                Write-Host "    0. Enter different profile name" -ForegroundColor Gray
                Write-Host "    00. Skip this profile" -ForegroundColor Gray
                
                do
                {
                    $choice = Read-Host "  Select profile, try different name, or skip (0/00/1-$($similarResult.value.Count))"
                    if ($choice -eq "00")
                    {
                        Write-Host "  Skipping Autopilot profile '$ProfileName'" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
                        return $null
                    }
                    elseif ($choice -eq "0")
                    {
                        # Let user enter a different profile name
                        $newProfileName = Read-Host "  Enter different Autopilot profile name"
                        if (-not [string]::IsNullOrWhiteSpace($newProfileName))
                        {
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User trying different Autopilot profile name: '$($newProfileName.Trim())'" -LogLevel "Verbose"
                            return Resolve-SingleAutopilotProfileInteractive -ProfileName $newProfileName.Trim() -AccessToken $AccessToken
                        }
                        else
                        {
                            Write-Host "  No name entered, skipping profile" -ForegroundColor Yellow
                            return $null
                        }
                    }
                    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $similarResult.value.Count)
                    {
                        $selectedProfile = $similarResult.value[[int]$choice - 1]
                        Write-Host "  Selected: '$($selectedProfile.displayName)'" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $FunctionName -Message "User selected similar Autopilot profile: '$($selectedProfile.displayName)' (ID: $($selectedProfile.id))" -LogLevel "Verbose"
                        return @{
                            name = $selectedProfile.displayName
                            id   = $selectedProfile.id
                        }
                    }
                    Write-Host "  Invalid choice. Please enter 0, 00, or a number between 1 and $($similarResult.value.Count)." -ForegroundColor Red
                } while ($true)
            }
            else
            {
                # No similar profiles found either
                Write-Host "  No Autopilot profiles found matching '$ProfileName'." -ForegroundColor Red
                Write-Host "  Options:" -ForegroundColor White
                Write-Host "    1. Try different profile name" -ForegroundColor White
                Write-Host "    2. Save profile name without ID (will resolve later)" -ForegroundColor White
                Write-Host "    3. Skip this profile" -ForegroundColor White
                
                do
                {
                    $choice = Read-Host "  Select option (1-3)"
                    switch ($choice)
                    {
                        '1'
                        {
                            $newProfileName = Read-Host "  Enter different Autopilot profile name"
                            if (-not [string]::IsNullOrWhiteSpace($newProfileName))
                            {
                                Write-Log -LogFile $logFile -Module $FunctionName -Message "User trying different Autopilot profile name: '$($newProfileName.Trim())'" -LogLevel "Verbose"
                                return Resolve-SingleAutopilotProfileInteractive -ProfileName $newProfileName.Trim() -AccessToken $AccessToken
                            }
                            else
                            {
                                Write-Host "  No name entered, please choose again" -ForegroundColor Yellow
                                continue
                            }
                        }
                        '2'
                        {
                            Write-Host "  Saving Autopilot profile '$ProfileName' without ID" -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User chose to save Autopilot profile without ID: '$ProfileName'" -LogLevel "Verbose"
                            return @{
                                name = $ProfileName
                                id   = $null
                            }
                        }
                        '3'
                        {
                            Write-Host "  Skipping Autopilot profile '$ProfileName'" -ForegroundColor Yellow
                            Write-Log -LogFile $logFile -Module $FunctionName -Message "User skipped Autopilot profile: '$ProfileName'" -LogLevel "Verbose"
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
        Write-Warning "[$FunctionName] Error resolving Autopilot profile '[REDACTED]': $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $FunctionName -Message "Error resolving Autopilot profile '[REDACTED]': $($_.Exception.Message)" -LogLevel "Warning"
        
        Write-Host "  Error occurred while searching for Autopilot profile. Save without ID? (y/n)" -ForegroundColor Red
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