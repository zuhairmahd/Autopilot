function Resolve-MigratedLegacyObjects()
{
    <#
    .SYNOPSIS
        Resolves IDs for migrated legacy Autopilot profiles and groups, and saves them to domain configuration.
    
    .DESCRIPTION
        Processes migrated Autopilot profiles, GroupsToInclude, and GroupsToExclude arrays from the settings object.
        Attempts to resolve their IDs using Microsoft Graph in silent mode (auto-accepts exact matches),
        and saves the updated objects to the domain configuration file.
        
        Handles arrays in multiple formats:
        - String arrays (e.g., @("ProfileName1", "ProfileName2"))
        - Hashtable arrays with 'name' and 'id' keys
        - Hashtable arrays with only 'name' key (missing 'id')
        
        Automatically converts string arrays and hashtables without 'id' to proper format.
    
    .PARAMETER accessToken
        The access token for Microsoft Graph API authentication.
    
    .PARAMETER settings
        Hashtable containing domain settings with autopilotProfilesToInclude, groupsToInclude, 
        and groupsToExclude arrays.
    
    .PARAMETER domain
        The domain name for which to resolve and save objects.
    
    .PARAMETER SettingsFile
        Path to the settings.psd1 file. Used to determine the location for domain configuration files.
        Defaults to "settings.psd1" in the current directory.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a detailed status object with the following keys:
        - success: Overall success status (boolean)
        - autopilotProfiles: Hashtable with detailed statistics for Autopilot profiles
        - groupsToInclude: Hashtable with detailed statistics for GroupsToInclude
        - groupsToExclude: Hashtable with detailed statistics for GroupsToExclude
        - totalProcessed: Total number of all objects processed (int)
        - totalResolved: Total number of all objects successfully resolved with IDs (int)
        - totalAlreadyHadId: Total number of all objects that already had IDs (int)
        - totalSkipped: Total number of all objects skipped (int)
        - savedToConfig: Whether objects were saved to configuration file (boolean)
        - configSaveSuccess: Whether the config save operation succeeded (boolean)
        - errorMessages: Array of error messages encountered (array)
    
    .EXAMPLE
        $domainSettings = Get-DomainConfigurationFromFiles -DomainName "contoso.com"
        $result = Resolve-MigratedLegacyObjects -accessToken $token -settings $domainSettings -domain "contoso.com"
        if ($result.success) {
            Write-Host "Successfully resolved $($result.totalResolved) legacy objects"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [hashtable]$settings,
        [Parameter(Mandatory = $true)]
        [string]$domain,
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = "settings.psd1"
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting legacy object resolution for domain: $domain" -LogLevel "Information"
    
    # Display introduction message to user
    Write-Host ""
    Write-Host "========================================================================================================" -ForegroundColor Cyan
    Write-Host "  Legacy Configuration Migration - Object Resolution" -ForegroundColor Yellow
    Write-Host "========================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your configuration has been migrated from JSON to the new PSD1 format." -ForegroundColor White
    Write-Host ""
    Write-Host "Purpose:" -ForegroundColor Cyan
    Write-Host "  This process will resolve Microsoft Graph IDs for Autopilot profiles and group names" -ForegroundColor White
    Write-Host "  that were migrated from your legacy configuration. IDs are required for the" -ForegroundColor White
    Write-Host "  application to function correctly with the new configuration format." -ForegroundColor White
    Write-Host ""
    Write-Host "What to expect:" -ForegroundColor Cyan
    Write-Host "  - Autopilot profiles will be matched against your tenant" -ForegroundColor White
    Write-Host "  - Include/Exclude groups will be matched against Entra ID" -ForegroundColor White
    Write-Host "  - Exact matches will be resolved automatically (silent mode)" -ForegroundColor White
    Write-Host "  - Multiple matches may require your selection" -ForegroundColor White
    Write-Host "  - Results will be saved to your domain configuration file" -ForegroundColor White
    Write-Host ""
    Write-Host "This is typically a one-time process after migration." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Prompt user to continue or defer
    $userChoice = Read-Host "Do you want to proceed with object resolution now? (yes/no)"
    while ($userChoice -notin @('yes', 'no', 'y', 'n'))
    {
        Write-Host "Invalid choice. Please enter 'yes' or 'no'." -ForegroundColor Yellow
        [console]::beep()
        $userChoice = Read-Host "Do you want to proceed with object resolution now? (yes/no)"
    }
    
    if ($userChoice -in @('no', 'n'))
    {
        Write-Host ""
        Write-Host "Object resolution deferred. You will be prompted again on next startup." -ForegroundColor Yellow
        Write-Host ""
        Write-Log -LogFile $logFile -Module $functionName -Message "User deferred legacy object resolution" -LogLevel "Information"
        
        # Return object indicating user deferred
        return @{
            success           = $false
            userDeferred      = $true
            autopilotProfiles = @{
                totalProcessed      = 0
                resolvedCount       = 0
                savedWithoutIdCount = 0
                skippedCount        = 0
                alreadyHadIdCount   = 0
                resolvedItems       = @()
                savedWithoutIdItems = @()
                skippedItems        = @()
                alreadyHadIdItems   = @()
            }
            groupsToInclude   = @{
                totalProcessed      = 0
                resolvedCount       = 0
                savedWithoutIdCount = 0
                skippedCount        = 0
                alreadyHadIdCount   = 0
                resolvedItems       = @()
                savedWithoutIdItems = @()
                skippedItems        = @()
                alreadyHadIdItems   = @()
            }
            groupsToExclude   = @{
                totalProcessed      = 0
                resolvedCount       = 0
                savedWithoutIdCount = 0
                skippedCount        = 0
                alreadyHadIdCount   = 0
                resolvedItems       = @()
                savedWithoutIdItems = @()
                skippedItems        = @()
                alreadyHadIdItems   = @()
            }
            totalProcessed    = 0
            totalResolved     = 0
            totalAlreadyHadId = 0
            totalSkipped      = 0
            savedToConfig     = $false
            configSaveSuccess = $false
            errorMessages     = @()
        }
    }
    
    Write-Host "Proceeding with object resolution..." -ForegroundColor Green
    Write-Host ""
    Write-Log -LogFile $logFile -Module $functionName -Message "User confirmed proceeding with legacy object resolution" -LogLevel "Information"
    
    # Helper function to normalize array items to hashtable format
    function ConvertTo-NormalizedArray()
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]$InputArray,
            [Parameter(Mandatory = $true)]
            [string]$ObjectTypeName
        )

        $functionName = $MyInvocation.MyCommand.Name
        $normalizedArray = @()
        Write-Verbose "[$functionName] Processing $($InputArray.Count) arrays of type $ObjectTypeName"
        Write-Log -LogFile $logFile -Module $functionName -Message "Processing $($InputArray.Count) arrays of type $ObjectTypeName"
        foreach ($item in $InputArray)
        {
            Write-Verbose "[$functionName] Processing item in $ObjectTypeName array"
            Write-Log -LogFile $logFile -Module $functionName -Message "Processing item in $ObjectTypeName array"
            if ($item -is [string])
            {
                # String element - convert to hashtable with name and null id
                Write-Verbose "[$functionName] Converting string '$item' to hashtable for $ObjectTypeName"
                Write-Log -LogFile $logFile -Module $functionName -Message "Converting string '$item' to hashtable for $ObjectTypeName"
                $normalizedArray += @{
                    name = $item
                    id   = $null
                }
            }
            elseif ($item -is [hashtable] -or $item -is [PSCustomObject])
            {
                # Hashtable or PSCustomObject - ensure it has both name and id keys
                Write-Verbose "[$functionName] Processing hashtable or PSCustomObject item in $ObjectTypeName array"
                Write-Log -LogFile $logFile -Module $functionName -Message "Processing hashtable or PSCustomObject item in $ObjectTypeName array"
                $itemHash = if ($item -is [PSCustomObject])
                {
                    # Convert PSCustomObject to hashtable
                    $hash = @{}
                    $item.PSObject.Properties | ForEach-Object { $hash[$_.Name] = $_.Value }
                    $hash
                }
                else
                {
                    $item
                }
                
                # Ensure 'name' key exists
                if (-not $itemHash.ContainsKey('name'))
                {
                    Write-Warning "[$functionName] $ObjectTypeName item missing 'name' key, skipping: $($itemHash | ConvertTo-Json -Compress)"
                    Write-Log -LogFile $logFile -Module $functionName -Message "$ObjectTypeName item missing 'name' key, skipping: $($itemHash | ConvertTo-Json -Compress)" -LogLevel "Warning"
                    continue
                }
                
                # Ensure 'id' key exists (add if missing)
                if (-not $itemHash.ContainsKey('id'))
                {
                    Write-Verbose "[$functionName] Adding missing 'id' key (null) to $ObjectTypeName item: $($itemHash.name)"
                    Write-Log -LogFile $logFile -Module $functionName -Message "Adding missing 'id' key (null) to $ObjectTypeName item: $($itemHash.name)"
                    $itemHash['id'] = $null
                }
                
                $normalizedArray += $itemHash
            }
            else
            {
                Write-Warning "[$functionName] Unexpected $ObjectTypeName item type: $($item.GetType().Name), skipping"
                Write-Log -LogFile $logFile -Module $functionName -Message "Unexpected $ObjectTypeName item type: $($item.GetType().Name), skipping" -LogLevel "Warning"
            }
        }
        
        return $normalizedArray
    }
    
    # Extract and normalize arrays from settings
    $autopilotProfiles = @()
    $groupsToInclude = @()
    $groupsToExclude = @()
    
    if ($settings.ContainsKey('autopilotProfilesToInclude') -and $null -ne $settings.autopilotProfilesToInclude)
    {
        Write-Verbose "[$functionName] Extracting autopilotProfilesToInclude from settings"
        $autopilotProfiles = ConvertTo-NormalizedArray -InputArray $settings.autopilotProfilesToInclude -ObjectTypeName "AutopilotProfile"
        Write-Log -LogFile $logFile -Module $functionName -Message "Extracted $($autopilotProfiles.Count) autopilot profile(s) from settings" -LogLevel "Verbose"
    }
    
    if ($settings.ContainsKey('groupsToInclude') -and $null -ne $settings.groupsToInclude)
    {
        Write-Verbose "[$functionName] Extracting groupsToInclude from settings"
        $groupsToInclude = ConvertTo-NormalizedArray -InputArray $settings.groupsToInclude -ObjectTypeName "GroupToInclude"
        Write-Log -LogFile $logFile -Module $functionName -Message "Extracted $($groupsToInclude.Count) group(s) to include from settings" -LogLevel "Verbose"
    }
    
    if ($settings.ContainsKey('groupsToExclude') -and $null -ne $settings.groupsToExclude)
    {
        Write-Verbose "[$functionName] Extracting groupsToExclude from settings"
        $groupsToExclude = ConvertTo-NormalizedArray -InputArray $settings.groupsToExclude -ObjectTypeName "GroupToExclude"
        Write-Log -LogFile $logFile -Module $functionName -Message "Extracted $($groupsToExclude.Count) group(s) to exclude from settings" -LogLevel "Verbose"
    }
    
    # Initialize return object with comprehensive tracking for each object type
    $returnObject = @{
        success           = $false
        autopilotProfiles = @{
            totalProcessed      = 0
            resolvedCount       = 0
            savedWithoutIdCount = 0
            skippedCount        = 0
            alreadyHadIdCount   = 0
            resolvedItems       = @()
            savedWithoutIdItems = @()
            skippedItems        = @()
            alreadyHadIdItems   = @()
        }
        groupsToInclude   = @{
            totalProcessed      = 0
            resolvedCount       = 0
            savedWithoutIdCount = 0
            skippedCount        = 0
            alreadyHadIdCount   = 0
            resolvedItems       = @()
            savedWithoutIdItems = @()
            skippedItems        = @()
            alreadyHadIdItems   = @()
        }
        groupsToExclude   = @{
            totalProcessed      = 0
            resolvedCount       = 0
            savedWithoutIdCount = 0
            skippedCount        = 0
            alreadyHadIdCount   = 0
            resolvedItems       = @()
            savedWithoutIdItems = @()
            skippedItems        = @()
            alreadyHadIdItems   = @()
        }
        totalProcessed    = 0
        totalResolved     = 0
        totalAlreadyHadId = 0
        totalSkipped      = 0
        savedToConfig     = $false
        configSaveSuccess = $false
        errorMessages     = @()
    }

    # Define object types to process with their resolution functions
    $objectTypesToProcess = @(
        @{
            TypeName         = "AutopilotProfiles"
            DisplayName      = "Autopilot profile"
            Items            = $autopilotProfiles
            ResolverFunction = { param($name, $token, $existing) Resolve-SingleAutopilotProfileInteractive -ProfileName $name -AccessToken $token -ExistingItems $existing -Silent }
            ConfigKey        = "autopilotProfilesToInclude"
            StatsKey         = "autopilotProfiles"
        },
        @{
            TypeName         = "GroupsToInclude"
            DisplayName      = "group (include)"
            Items            = $groupsToInclude
            ResolverFunction = { param($name, $token, $existing) Resolve-SingleGroupInteractive -GroupName $name -AccessToken $token -ExistingItems $existing -Silent }
            ConfigKey        = "groupsToInclude"
            StatsKey         = "groupsToInclude"
        },
        @{
            TypeName         = "GroupsToExclude"
            DisplayName      = "group (exclude)"
            Items            = $groupsToExclude
            ResolverFunction = { param($name, $token, $existing) Resolve-SingleGroupInteractive -GroupName $name -AccessToken $token -ExistingItems $existing -Silent }
            ConfigKey        = "groupsToExclude"
            StatsKey         = "groupsToExclude"
        }
    )

    $domainSettings = @{}
    $anyChanges = $false

    # Process each object type
    foreach ($objectType in $objectTypesToProcess)
    {
        if ($objectType.Items.Count -eq 0)
        {
            Write-Verbose "[$functionName] No $($objectType.TypeName) to process, skipping"
            continue
        }

        Write-Host ""
        Write-Host "=== Processing $($objectType.TypeName) ===" -ForegroundColor Cyan
        Write-Log -LogFile $logFile -Module $functionName -Message "Processing $($objectType.Items.Count) $($objectType.TypeName)" -LogLevel "Information"
        
        $updatedItems = @()
        $stats = $returnObject[$objectType.StatsKey]

        foreach ($item in $objectType.Items)
        {
            $stats.totalProcessed++
            $returnObject.totalProcessed++
            Write-Verbose "[$functionName] Processing $($objectType.DisplayName): $($item.name)"
            
            try
            {
                if ($null -eq $item.id)
                {
                    Write-Host "  Resolving ID for $($objectType.DisplayName): '$($item.name)'..." -ForegroundColor Yellow
                    Write-Log -LogFile $logFile -Module $functionName -Message "Attempting to resolve ID for $($objectType.DisplayName): $($item.name)" -LogLevel "Information"
                    
                    # Call the appropriate resolver function in silent mode
                    $resolvedItem = & $objectType.ResolverFunction $item.name $accessToken $updatedItems
                    
                    if ($resolvedItem -and $resolvedItem.id)
                    {
                        # Successfully resolved the item ID
                        Write-Host "  Resolved $($objectType.DisplayName) ID: $($resolvedItem.id)" -ForegroundColor Green
                        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully resolved $($objectType.DisplayName) ID for '$($resolvedItem.name)': $($resolvedItem.id)" -LogLevel "Information"
                        $updatedItems += $resolvedItem
                        $stats.resolvedItems += $resolvedItem
                        $stats.resolvedCount++
                        $returnObject.totalResolved++
                        $anyChanges = $true
                    }
                    elseif ($resolvedItem -and -not $resolvedItem.id)
                    {
                        # Item was resolved but without ID (user chose to save without ID)
                        Write-Host "  $($objectType.DisplayName) '$($resolvedItem.name)' saved without ID (not persisted to config)" -ForegroundColor Yellow
                        Write-Log -LogFile $logFile -Module $functionName -Message "$($objectType.DisplayName) '$($resolvedItem.name)' saved without ID (not persisted to config)" -LogLevel "Warning"
                        $stats.savedWithoutIdItems += $resolvedItem
                        $stats.savedWithoutIdCount++
                    }
                    else
                    {
                        # User skipped the item
                        Write-Host "  $($objectType.DisplayName) '$($item.name)' skipped" -ForegroundColor Gray
                        Write-Log -LogFile $logFile -Module $functionName -Message "$($objectType.DisplayName) '$($item.name)' skipped by user" -LogLevel "Verbose"
                        $stats.skippedItems += $item.name
                        $stats.skippedCount++
                        $returnObject.totalSkipped++
                    }
                }
                else
                {
                    # Item already has an ID
                    Write-Host "  $($objectType.DisplayName) '$($item.name)' already has ID: $($item.id)" -ForegroundColor Green
                    Write-Log -LogFile $logFile -Module $functionName -Message "$($objectType.DisplayName) '$($item.name)' already has ID" -LogLevel "Verbose"
                    $updatedItems += $item
                    $stats.alreadyHadIdItems += $item
                    $stats.alreadyHadIdCount++
                    $returnObject.totalAlreadyHadId++
                    $anyChanges = $true
                }
            }
            catch
            {
                $errorMsg = "Error processing $($objectType.DisplayName) '$($item.name)': $($_.Exception.Message)"
                Write-Warning "  $errorMsg"
                Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
                $returnObject.errorMessages += $errorMsg
                $stats.skippedItems += $item.name
                $stats.skippedCount++
                $returnObject.totalSkipped++
            }
        }
        
        # Add updated items to domain settings if there are any with IDs
        if ($updatedItems.Count -gt 0)
        {
            $domainSettings[$objectType.ConfigKey] = $updatedItems
            Write-Verbose "[$functionName] Prepared $($updatedItems.Count) $($objectType.TypeName) for saving"
        }
    }
    
    # Save all updated objects to domain configuration if any changes were made
    if ($anyChanges -and $domainSettings.Keys.Count -gt 0)
    {
        Write-Host ""
        Write-Host "  Saving updated objects to domain configuration..." -ForegroundColor Cyan
        Write-Log -LogFile $logFile -Module $functionName -Message "Saving updated objects to domain configuration" -LogLevel "Information"
        
        $returnObject.savedToConfig = $true
        
        try
        {
            Write-Verbose "[$functionName] Calling Update-Setting with SettingsFile: $SettingsFile"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using settings file: $SettingsFile" -LogLevel "Verbose"
            $saveSuccess = Update-Setting -SettingType "Domain" -DomainName $domain -Settings $domainSettings -SettingsFile $SettingsFile -MergeSettings
            
            if ($saveSuccess)
            {
                Write-Host "  Successfully saved objects to domain configuration" -ForegroundColor Green
                Write-Log -LogFile $logFile -Module $functionName -Message "Successfully saved objects to domain configuration" -LogLevel "Information"
                $returnObject.configSaveSuccess = $true
            }
            else
            {
                $errorMsg = "Failed to save objects to domain configuration"
                Write-Warning "  $errorMsg"
                Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
                $returnObject.errorMessages += $errorMsg
                $returnObject.configSaveSuccess = $false
            }
        }
        catch
        {
            $errorMsg = "Error saving objects to configuration: $($_.Exception.Message)"
            Write-Warning "  $errorMsg"
            Write-Log -LogFile $logFile -Module $functionName -Message $errorMsg -LogLevel "Error"
            $returnObject.errorMessages += $errorMsg
            $returnObject.configSaveSuccess = $false
        }
    }
    elseif ($domainSettings.Keys.Count -eq 0)
    {
        Write-Host "  No objects to save (all were skipped or saved without IDs)" -ForegroundColor Gray
        Write-Log -LogFile $logFile -Module $functionName -Message "No objects to save" -LogLevel "Verbose"
    }
    
    # Set overall success status
    $returnObject.success = (
        $returnObject.totalProcessed -gt 0 -and
        (
            $returnObject.errorMessages.Count -eq 0 -or
            ($returnObject.savedToConfig -and $returnObject.configSaveSuccess)
        )
    )
    
    # Display comprehensive summary
    Write-Host ""
    Write-Host "=== Legacy Object Resolution Summary ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Autopilot Profiles summary
    if ($autopilotProfiles.Count -gt 0)
    {
        $apStats = $returnObject.autopilotProfiles
        Write-Host "Autopilot Profiles:" -ForegroundColor Yellow
        Write-Host "  Total processed: $($apStats.totalProcessed)" -ForegroundColor White
        Write-Host "  Resolved with IDs: $($apStats.resolvedCount)" -ForegroundColor Green
        Write-Host "  Already had IDs: $($apStats.alreadyHadIdCount)" -ForegroundColor Green
        Write-Host "  Saved without IDs: $($apStats.savedWithoutIdCount)" -ForegroundColor Yellow
        Write-Host "  Skipped: $($apStats.skippedCount)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # GroupsToInclude summary
    if ($groupsToInclude.Count -gt 0)
    {
        $giStats = $returnObject.groupsToInclude
        Write-Host "Groups To Include:" -ForegroundColor Yellow
        Write-Host "  Total processed: $($giStats.totalProcessed)" -ForegroundColor White
        Write-Host "  Resolved with IDs: $($giStats.resolvedCount)" -ForegroundColor Green
        Write-Host "  Already had IDs: $($giStats.alreadyHadIdCount)" -ForegroundColor Green
        Write-Host "  Saved without IDs: $($giStats.savedWithoutIdCount)" -ForegroundColor Yellow
        Write-Host "  Skipped: $($giStats.skippedCount)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # GroupsToExclude summary
    if ($groupsToExclude.Count -gt 0)
    {
        $geStats = $returnObject.groupsToExclude
        Write-Host "Groups To Exclude:" -ForegroundColor Yellow
        Write-Host "  Total processed: $($geStats.totalProcessed)" -ForegroundColor White
        Write-Host "  Resolved with IDs: $($geStats.resolvedCount)" -ForegroundColor Green
        Write-Host "  Already had IDs: $($geStats.alreadyHadIdCount)" -ForegroundColor Green
        Write-Host "  Saved without IDs: $($geStats.savedWithoutIdCount)" -ForegroundColor Yellow
        Write-Host "  Skipped: $($geStats.skippedCount)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Overall totals
    Write-Host "Overall Totals:" -ForegroundColor Cyan
    Write-Host "  Total objects processed: $($returnObject.totalProcessed)" -ForegroundColor White
    Write-Host "  Total resolved: $($returnObject.totalResolved)" -ForegroundColor Green
    Write-Host "  Total already had IDs: $($returnObject.totalAlreadyHadId)" -ForegroundColor Green
    Write-Host "  Total skipped: $($returnObject.totalSkipped)" -ForegroundColor Gray
    
    if ($returnObject.savedToConfig)
    {
        Write-Host ""
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
    Write-Log -LogFile $logFile -Module $functionName -Message "Legacy object resolution complete: Success=$($returnObject.success), Total Processed=$($returnObject.totalProcessed), Total Resolved=$($returnObject.totalResolved)" -LogLevel "Information"
    
    return $returnObject
}