function Resolve-MigratedAutopilotProfiles()
{
    <#
    .SYNOPSIS
        Resolves IDs for migrated Autopilot profiles and saves them to domain configuration.
    
    .DESCRIPTION
        Processes migrated Autopilot profiles, attempts to resolve their IDs using Microsoft Graph,
        and saves the updated profiles to the domain configuration file.
    
    .PARAMETER accessToken
        The access token for Microsoft Graph API authentication.
    
    .PARAMETER autopilotProfiles
        Array of autopilot profile objects to process (with 'name' and 'id' properties).
    
    .PARAMETER domain
        The domain name for which to resolve and save profiles.
    
    .PARAMETER SettingsFile
        Path to the settings.psd1 file. Used to determine the location for domain configuration files.
        Defaults to "settings.psd1" in the current directory.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a detailed status object with the following keys:
        - success: Overall success status (boolean)
        - totalProcessed: Total number of profiles processed (int)
        - resolvedCount: Number of profiles successfully resolved with IDs (int)
        - savedWithoutIdCount: Number of profiles saved without IDs (int)
        - skippedCount: Number of profiles skipped by user (int)
        - alreadyHadIdCount: Number of profiles that already had IDs (int)
        - savedToConfig: Whether profiles were saved to configuration file (boolean)
        - configSaveSuccess: Whether the config save operation succeeded (boolean)
        - resolvedProfiles: Array of successfully resolved profiles with IDs (array)
        - savedWithoutIdProfiles: Array of profiles saved without IDs (array)
        - skippedProfiles: Array of profile names that were skipped (array)
        - alreadyHadIdProfiles: Array of profiles that already had IDs (array)
        - errorMessages: Array of error messages encountered (array)
    
    .EXAMPLE
        $result = Resolve-MigratedAutopilotProfiles -accessToken $token -autopilotProfiles $profiles -domain "contoso.com"
        if ($result.success) {
            Write-Host "Successfully resolved $($result.resolvedCount) profiles"
        }
    
    .EXAMPLE
        $result = Resolve-MigratedAutopilotProfiles -accessToken $token -autopilotProfiles $profiles -domain "contoso.com" -SettingsFile "$PWD\settings.psd1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [array]$autopilotProfiles,
        [Parameter(Mandatory = $true)]
        [string]$domain,
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = "settings.psd1"
    )

    $functionName = $MyInvocation.MyCommand.Name
    
    # Initialize return object with detailed tracking
    $returnObject = @{
        success                = $false
        totalProcessed         = 0
        resolvedCount          = 0
        savedWithoutIdCount    = 0
        skippedCount           = 0
        alreadyHadIdCount      = 0
        savedToConfig          = $false
        configSaveSuccess      = $false
        resolvedProfiles       = @()
        savedWithoutIdProfiles = @()
        skippedProfiles        = @()
        alreadyHadIdProfiles   = @()
        errorMessages          = @()
    }
    
    $updatedProfiles = @()
    $profilesNeedingSave = $false

    foreach ($autopilotProfile in $autopilotProfiles)
    {
        $returnObject.totalProcessed++
        Write-Verbose "[$functionName] Processing profile: $($autopilotProfile.name)"
        
        try
        {
            if ($null -eq $autopilotProfile.id)
            {
                Write-Host "  Resolving ID for Autopilot profile: '$($autopilotProfile.name)'..." -ForegroundColor Yellow
                Write-Log -LogFile $logFile -Module $functionName -Message "Attempting to resolve ID for profile: $($autopilotProfile.name)" -LogLevel "Information"
                
                # Try to resolve the profile ID silently first
                $resolvedProfile = Resolve-SingleAutopilotProfileInteractive -ProfileName $autopilotProfile.name -AccessToken $accessToken -ExistingItems $updatedProfiles -Silent
                
                if ($resolvedProfile -and $resolvedProfile.id)
                {
                    # Successfully resolved the profile ID
                    Write-Host "  Resolved profile ID: $($resolvedProfile.id)" -ForegroundColor Green
                    Write-Log -LogFile $logFile -Module $functionName -Message "Successfully resolved profile ID for '$($resolvedProfile.name)': $($resolvedProfile.id)" -LogLevel "Information"
                    $updatedProfiles += $resolvedProfile
                    $returnObject.resolvedProfiles += $resolvedProfile
                    $returnObject.resolvedCount++
                    $profilesNeedingSave = $true
                }
                elseif ($resolvedProfile -and -not $resolvedProfile.id)
                {
                    # Profile was resolved but without ID (user chose to save without ID)
                    # Note: We track this but don't save to config since it has no ID
                    Write-Host "  Profile '$($resolvedProfile.name)' saved without ID (not persisted to config)" -ForegroundColor Yellow
                    Write-Log -LogFile $logFile -Module $functionName -Message "Profile '$($resolvedProfile.name)' saved without ID (not persisted to config)" -LogLevel "Warning"
                    $returnObject.savedWithoutIdProfiles += $resolvedProfile
                    $returnObject.savedWithoutIdCount++
                    # Do NOT add to $updatedProfiles or set $profilesNeedingSave for profiles without IDs
                }
                else
                {
                    # User skipped the profile
                    Write-Host "  Profile '$($autopilotProfile.name)' skipped" -ForegroundColor Gray
                    Write-Log -LogFile $logFile -Module $functionName -Message "Profile '$($autopilotProfile.name)' skipped by user" -LogLevel "Verbose"
                    $returnObject.skippedProfiles += $autopilotProfile.name
                    $returnObject.skippedCount++
                }
            }
            else
            {
                # Profile already has an ID
                Write-Host "  Profile '$($autopilotProfile.name)' already has ID: $($autopilotProfile.id)" -ForegroundColor Green
                Write-Log -LogFile $logFile -Module $functionName -Message "Profile '$($autopilotProfile.name)' already has ID" -LogLevel "Verbose"
                $updatedProfiles += $autopilotProfile
                $returnObject.alreadyHadIdProfiles += $autopilotProfile
                $returnObject.alreadyHadIdCount++
                $profilesNeedingSave = $true
            }
        }
        catch
        {
            $errorMsg = "Error processing profile '$($autopilotProfile.name)': $($_.Exception.Message)"
            Write-Warning "  $errorMsg"
            Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $returnObject.errorMessages += $errorMsg
            $returnObject.skippedProfiles += $autopilotProfile.name
            $returnObject.skippedCount++
        }
    }
    
    # Save updated profiles to domain configuration if any changes were made
    # Only save if we have profiles with IDs (resolved or already had IDs)
    if ($profilesNeedingSave -and $updatedProfiles.Count -gt 0)
    {
        Write-Host ""
        Write-Host "  Saving updated Autopilot profiles to domain configuration..." -ForegroundColor Cyan
        Write-Log -LogFile $logFile -Module $functionName -Message "Saving $($updatedProfiles.Count) updated profile(s) to domain configuration" -LogLevel "Information"
        
        $returnObject.savedToConfig = $true
        
        try
        {
            # Update the autopilotProfilesToInclude setting
            # Update-Setting will handle domain file creation via Get-DomainConfigurationFromFiles if it doesn't exist
            $domainSettings = @{
                autopilotProfilesToInclude = $updatedProfiles
            }
            
            Write-Verbose "[$functionName] Calling Update-Setting with SettingsFile: $SettingsFile"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using settings file: $SettingsFile" -LogLevel "Verbose"
            $saveSuccess = Update-Setting -SettingType "Domain" -DomainName $domain -Settings $domainSettings -SettingsFile $SettingsFile -MergeSettings
            
            if ($saveSuccess)
            {
                Write-Host "  Successfully saved Autopilot profiles to domain configuration" -ForegroundColor Green
                Write-Log -LogFile $logFile -Module $functionName -Message "Successfully saved Autopilot profiles to domain configuration" -LogLevel "Information"
                $returnObject.configSaveSuccess = $true
            }
            else
            {
                $errorMsg = "Failed to save Autopilot profiles to domain configuration"
                Write-Warning "  $errorMsg"
                Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
                $returnObject.errorMessages += $errorMsg
                $returnObject.configSaveSuccess = $false
            }
        }
        catch
        {
            $errorMsg = "Error saving Autopilot profiles: $($_.Exception.Message)"
            Write-Warning "  $errorMsg"
            Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $returnObject.errorMessages += $errorMsg
            $returnObject.configSaveSuccess = $false
        }
    }
    elseif ($updatedProfiles.Count -eq 0)
    {
        Write-Host "  No Autopilot profiles to save (all were skipped or saved without IDs)" -ForegroundColor Gray
        Write-Log -LogFile $logFile -Module $functionName -Message "No Autopilot profiles to save" -LogLevel "Verbose"
    }
    
    # Set overall success status
    # Success if: at least one profile was processed AND (no errors OR all errors were user skips)
    $returnObject.success = (
        $returnObject.totalProcessed -gt 0 -and
        (
            $returnObject.errorMessages.Count -eq 0 -or
            ($returnObject.savedToConfig -and $returnObject.configSaveSuccess)
        )
    )
    
    # Display summary
    Write-Host ""
    Write-Host "=== Autopilot Profile Resolution Summary ===" -ForegroundColor Cyan
    Write-Host "Total profiles processed: $($returnObject.totalProcessed)" -ForegroundColor White
    Write-Host "Successfully resolved with IDs: $($returnObject.resolvedCount)" -ForegroundColor Green
    Write-Host "Saved without IDs: $($returnObject.savedWithoutIdCount)" -ForegroundColor Yellow
    Write-Host "Already had IDs: $($returnObject.alreadyHadIdCount)" -ForegroundColor Green
    Write-Host "Skipped by user: $($returnObject.skippedCount)" -ForegroundColor Gray
    
    if ($returnObject.savedToConfig)
    {
        if ($returnObject.configSaveSuccess)
        {
            Write-Host "Configuration save: SUCCESS" -ForegroundColor Green
        }
        else
        {
            Write-Host "Configuration save: FAILED" -ForegroundColor Red
        }
    }
    
    if ($returnObject.errorMessages.Count -gt 0)
    {
        Write-Host ""
        Write-Host "Errors encountered:" -ForegroundColor Red
        foreach ($errMsg in $returnObject.errorMessages)
        {
            Write-Host "  - $errMsg" -ForegroundColor Red
        }
    }
    
    Write-Host "" # Blank line for spacing
    Write-Log -LogFile $logFile -Module $functionName -Message "Profile resolution complete: Success=$($returnObject.success), Processed=$($returnObject.totalProcessed), Resolved=$($returnObject.resolvedCount)" -LogLevel "Information"
    
    return $returnObject
}