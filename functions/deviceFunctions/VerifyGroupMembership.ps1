function VerifyGroupMembership()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [Parameter()]
        $groupsToInclude,  # Accept both string[] and hashtable[] formats
        [Parameter()]
        $groupsToExclude   # Accept both string[] and hashtable[] formats
    )

    #region Initialize result object and logging
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting VerifyGroupMembership function"
    Write-Log -logFile $logFile -module $functionName -Message "Starting VerifyGroupMembership function" -logLevel "Verbose"

    #region Helper functions for format detection and conversion
    function Test-GroupFormat {
        param($groups)
        if (-not $groups -or $groups.Count -eq 0) { return "Empty" }
        
        # Check first element to determine format
        $firstElement = $groups[0]
        if ($firstElement -is [string]) {
            return "StringArray"
        }
        elseif ($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) {
            if ($firstElement.name -and $firstElement.id) {
                return "HashTableArray"
            }
        }
        return "Unknown"
    }

    function Convert-GroupsToStandardFormat {
        param($groups, $groupType)
        
        $format = Test-GroupFormat -groups $groups
        Write-Verbose "[$functionName] Detected format for $groupType groups: $format"
        Write-Log -logFile $logFile -module $functionName -Message "Detected format for $groupType groups: $format"
        
        switch ($format) {
            "Empty" { return @(), @() }  # Return empty arrays for names and IDs
            "HashTableArray" {
                # Extract names and IDs from hashtable format
                $groupNames = @($groups | ForEach-Object { $_.name })
                $groupIds = @($groups | ForEach-Object { $_.id })
                Write-Verbose "[$functionName] Extracted from hashtable format - Names: $($groupNames -join ', '), IDs: $($groupIds -join ', ')"
                return $groupNames, $groupIds
            }
            "StringArray" {
                # Old format - need to resolve group names to IDs
                Write-Verbose "[$functionName] Old string array format detected for $groupType groups, resolving IDs"
                Write-Log -logFile $logFile -module $functionName -Message "Old string array format detected for $groupType groups, resolving IDs"
                
                try {
                    $resolvedIds = GetGroupIdsByNames -accessToken $accessToken -groupNames $groups
                    Write-Verbose "[$functionName] Resolved IDs for $groupType groups: $($resolvedIds -join ', ')"
                    Write-Log -logFile $logFile -module $functionName -Message "Resolved IDs for $groupType groups: $($resolvedIds -join ', ')"
                    return $groups, $resolvedIds
                }
                catch {
                    Write-Warning "[$functionName] Failed to resolve group IDs for $groupType groups: $($_.Exception.Message)"
                    Write-Log -logFile $logFile -module $functionName -Message "Failed to resolve group IDs for $groupType groups: $($_.Exception.Message)" -logLevel "Warning"
                    return $groups, @()  # Return names with empty IDs array
                }
            }
            default {
                Write-Warning "[$functionName] Unknown group format for $groupType groups"
                Write-Log -logFile $logFile -module $functionName -Message "Unknown group format for $groupType groups" -logLevel "Warning"
                return @(), @()
            }
        }
    }

    function Create-HashTableGroupFormat {
        param($groupNames, $groupIds)
        
        $hashTableGroups = @()
        for ($i = 0; $i -lt $groupNames.Count; $i++) {
            $groupId = if ($i -lt $groupIds.Count) { $groupIds[$i] } else { $null }
            $hashTableGroups += @{
                name = $groupNames[$i]
                id = $groupId
            }
        }
        return $hashTableGroups
    }
    #endregion

    #region Process and standardize group formats
    Write-Verbose "[$functionName] Processing group formats"
    Write-Log -logFile $logFile -module $functionName -Message "Processing group formats"
    
    # Convert groups to standardized format and extract names/IDs
    $includeGroupNames, $includeGroupIds = Convert-GroupsToStandardFormat -groups $groupsToInclude -groupType "include"
    $excludeGroupNames, $excludeGroupIds = Convert-GroupsToStandardFormat -groups $groupsToExclude -groupType "exclude"
    
    # Track if we need to update configuration with new format
    $needsConfigUpdate = $false
    $updatedIncludeGroups = $null
    $updatedExcludeGroups = $null
    
    # Check if we detected old format and successfully resolved IDs
    if ((Test-GroupFormat -groups $groupsToInclude) -eq "StringArray" -and $includeGroupIds.Count -gt 0) {
        $needsConfigUpdate = $true
        $updatedIncludeGroups = Create-HashTableGroupFormat -groupNames $includeGroupNames -groupIds $includeGroupIds
        Write-Verbose "[$functionName] Created updated include groups format with $($updatedIncludeGroups.Count) groups"
        Write-Log -logFile $logFile -module $functionName -Message "Created updated include groups format with $($updatedIncludeGroups.Count) groups"
    }
    
    if ((Test-GroupFormat -groups $groupsToExclude) -eq "StringArray" -and $excludeGroupIds.Count -gt 0) {
        $needsConfigUpdate = $true
        $updatedExcludeGroups = Create-HashTableGroupFormat -groupNames $excludeGroupNames -groupIds $excludeGroupIds
        Write-Verbose "[$functionName] Created updated exclude groups format with $($updatedExcludeGroups.Count) groups"
        Write-Log -logFile $logFile -module $functionName -Message "Created updated exclude groups format with $($updatedExcludeGroups.Count) groups"
    }
    #endregion

    # Create a consistent return object structure that will always be returned
    Write-Verbose "[$functionName] Initializing result object"
    Write-Log -logFile $logFile -module $functionName -Message "Initializing result object" -logLevel "Information"
    $result = [PSCustomObject]@{
        Success         = $false
        UserInfo        = $null
        MissingGroups   = @()
        ForbiddenGroups = @()
        UserGroups      = @()
        Error           = $null
    }

    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] Access token is empty or null"
        Write-Log -logFile $logFile -module $functionName -Message "Access token is empty or null" -logLevel "Information"
        Write-Host "Access token is required." -ForegroundColor Red
        $result.Error = "Access token is required."
        return $result
    }

    # Log the processed groups
    Write-Verbose "[$functionName] User name: $userName"
    Write-Log -logFile $logFile -module $functionName -Message "User name: $userName"
    Write-Verbose "[$functionName] Groups to include count: $($includeGroupNames.Count)"
    Write-Log -logFile $logFile -module $functionName -Message "Groups to include count: $($includeGroupNames.Count)" 
    Write-Verbose "[$functionName] Groups to exclude count: $($excludeGroupNames.Count)"
    if ($includeGroupNames.Count -gt 0)
    {
        Write-Verbose "[$functionName] Groups to include: $($includeGroupNames -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Groups to include: $($includeGroupNames -join ', ')"
        Write-Verbose "[$functionName] Include group IDs: $($includeGroupIds -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Include group IDs: $($includeGroupIds -join ', ')"
    }
    if ($excludeGroupNames.Count -gt 0)
    {
        Write-Verbose "[$functionName] Groups to exclude: $($excludeGroupNames -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Groups to exclude: $($excludeGroupNames -join ', ')"
        Write-Verbose "[$functionName] Exclude group IDs: $($excludeGroupIds -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Exclude group IDs: $($excludeGroupIds -join ', ')"
    }
    #endregion
    
    #region Get user information
    Write-Verbose "[$functionName] Getting user information for $userName"
    Write-Log -logFile $logFile -module $functionName -Message "Getting user information for $userName"
    try
    {
        Write-Verbose "[$functionName] Getting user information for $userName"
        $userUri = "users/$($userName)" 
        $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri -extraparameters "select=displayName,mail,userPrincipalName,id"
        Write-Verbose "[$functionName] Got user information: $($user | ConvertTo-Json -Depth 3)"
        Write-Log -logFile $logFile -module $functionName -Message "Got user information: $($user | ConvertTo-Json -Depth $maxJsonDepth)"
        # Check if user was found
        if ($user -is [string] -and $user -match '^\d+$')
        {
            Write-Verbose "[$functionName] User $userName not found in Azure AD (Error code: $user)"
            Write-Log -logFile $logFile -module $functionName -Message "User $userName not found in Azure AD (Error code: $user)" -logLevel "Error"
            Write-Host "The user $userName was not found in Azure AD." -ForegroundColor Red
            Write-Host "Please check the user name and try again." -ForegroundColor Red
            $result.Error = "User not found in Azure AD (Error code: $user)"
            return $result
        }
        $result.UserInfo = $user
        Write-Verbose "[$functionName] Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))"
        Write-Log -logFile $logFile -module $functionName -Message "Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting user information: $_"
        Write-Log -logFile $logFile -module $functionName -Message "Error getting user information: $_" -logLevel "Error"
        Write-Host "Error getting user information: $_" -ForegroundColor Red
        $result.Error = "Error getting user information: $_"
        return $result
    }
    #endregion
    
    #region Get group membership
    Write-Verbose "[$functionName] Getting group membership for user $userName"
    Write-Log -logFile $logFile -module $functionName -Message "Getting group membership for user $userName"
    try
    {
        Write-Host "Getting group membership for user $userName ($($user.displayName))."
        if ($includeGroupNames.count -gt 0)
        {
            Write-Verbose "[$functionName] Checking membership in $($includeGroupNames.Count) required groups for user $userName"
            Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($includeGroupNames.Count) required groups for user $userName"
            
            # Use group IDs for membership check (prioritize IDs over names)
            $groupsToCheck = if ($includeGroupIds.Count -gt 0) { $includeGroupIds } else { $includeGroupNames }
            $includedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $groupsToCheck
            Write-Verbose "[$functionName] Number of included groups: $($includedGroupMembership.Count)"
            Write-Log -logFile $logFile -module $functionName -Message "Number of included groups: $($includedGroupMembership.Count)"
            Write-Verbose "[$functionName] Included group membership: $($includedGroupMembership -join ', ')"
            Write-Log -logFile $logFile -module $functionName -Message "Included group membership: $($includedGroupMembership -join ', ')"
            
            # Determine missing required groups - compare against group names for result consistency
            $missingGroups = $includeGroupNames | Where-Object { $includedGroupMembership -notcontains $_ }
            $result.MissingGroups = $missingGroups
            if ($missingGroups.Count -gt 0)
            {
                Write-Verbose "[$functionName] User $userName is missing membership in the following required groups: $($missingGroups -join ', ')"
                Write-Log -logFile $logFile -module $functionName -Message "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')" -logLevel "Warning"
            }
        }
        if ($excludeGroupNames.count -gt 0)
        {
            Write-Verbose "[$functionName] Checking membership in $($excludeGroupNames.Count) excluded groups for user $userName"
            Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($excludeGroupNames.Count) excluded groups for user $userName"
            
            # Use group IDs for membership check (prioritize IDs over names)
            $groupsToCheck = if ($excludeGroupIds.Count -gt 0) { $excludeGroupIds } else { $excludeGroupNames }
            $excludedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $groupsToCheck
            Write-Verbose "[$functionName] Number of excluded groups: $($excludedGroupMembership.Count)"
            Write-Log -logFile $logFile -module $functionName -Message "Number of excluded groups: $($excludedGroupMembership.Count)"
            Write-Verbose "[$functionName] Excluded group membership: $($excludedGroupMembership -join ', ')"
            Write-Log -logFile $logFile -module $functionName -Message "Excluded group membership: $($excludedGroupMembership -join ', ')"
            # Determine forbidden groups
            $result.ForbiddenGroups = $excludedGroupMembership 
            if ($forbiddenGroups.Count -gt 0)
            {
                Write-Verbose "[$functionName] User $userName is a member of the following forbidden groups: $($forbiddenGroups -join ', ')"
                Write-Log -logFile $logFile -module $functionName -Message "User $userName is a member of the following forbidden groups: $($forbiddenGroups -join ', ')" -logLevel "Warning"
            }
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting group membership: $_"
        Write-Log -logFile $logFile -module $functionName -Message "Error getting group membership: $_" -logLevel "Error"
        $result.Error = "Error getting group membership: $_"
        return $result
    }
    #endregion
    
    #region Update configuration if migration needed
    if ($needsConfigUpdate)
    {
        Write-Verbose "[$functionName] Migration needed - attempting to update configuration with new hashtable format"
        Write-Log -logFile $logFile -module $functionName -Message "Migration needed - attempting to update configuration with new hashtable format"
        
        try
        {
            # Try to determine domain context for configuration update
            # This attempts to get domain information from various scopes
            $domainName = $null
            
            # Check for domain variable in calling scopes
            for ($scope = 1; $scope -le 3; $scope++)
            {
                try
                {
                    $domainName = Get-Variable -Name "domain" -Scope $scope -ValueOnly -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($domainName))
                    {
                        Write-Verbose "[$functionName] Found domain name from scope $scope : $domainName"
                        Write-Log -logFile $logFile -module $functionName -Message "Found domain name from scope $scope : $domainName"
                        break
                    }
                }
                catch { continue }
            }
            
            if (-not [string]::IsNullOrWhiteSpace($domainName))
            {
                # Attempt to update the configuration
                if ($null -ne $updatedIncludeGroups)
                {
                    $includeSuccess = Update-DomainGroupSetting -SettingsFile "settings.json" -DomainName $domainName -GroupType "groupsToInclude" -Groups $updatedIncludeGroups
                    if ($includeSuccess)
                    {
                        Write-Verbose "[$functionName] Successfully migrated groupsToInclude to new format"
                        Write-Log -logFile $logFile -module $functionName -Message "Successfully migrated groupsToInclude to new format"
                    }
                    else
                    {
                        Write-Warning "[$functionName] Failed to migrate groupsToInclude to new format"
                        Write-Log -logFile $logFile -module $functionName -Message "Failed to migrate groupsToInclude to new format" -logLevel "Warning"
                    }
                }
                
                if ($null -ne $updatedExcludeGroups)
                {
                    $excludeSuccess = Update-DomainGroupSetting -SettingsFile "settings.json" -DomainName $domainName -GroupType "groupsToExclude" -Groups $updatedExcludeGroups
                    if ($excludeSuccess)
                    {
                        Write-Verbose "[$functionName] Successfully migrated groupsToExclude to new format"
                        Write-Log -logFile $logFile -module $functionName -Message "Successfully migrated groupsToExclude to new format"
                    }
                    else
                    {
                        Write-Warning "[$functionName] Failed to migrate groupsToExclude to new format"
                        Write-Log -logFile $logFile -module $functionName -Message "Failed to migrate groupsToExclude to new format" -logLevel "Warning"
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] Could not determine domain name for configuration update - migration skipped"
                Write-Log -logFile $logFile -module $functionName -Message "Could not determine domain name for configuration update - migration skipped" -logLevel "Warning"
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error during configuration migration: $($_.Exception.Message)"
            Write-Log -logFile $logFile -module $functionName -Message "Error during configuration migration: $($_.Exception.Message)" -logLevel "Warning"
        }
    }
    #endregion
    
    #region Determine result and return
    if ($missingGroups.Count -eq 0 -and $forbiddenGroups.Count -eq 0)
    {
        Write-Verbose "[$functionName] User $userName has correct group memberships"
        Write-Log -logFile $logFile -module $functionName -Message "User $userName has correct group memberships"
        $result.Success = $true
    }
    else
    {
        Write-Verbose "[$functionName] User $userName does not have correct group memberships"
        Write-Log -logFile $logFile -module $functionName -Message "User $userName does not have correct group memberships"
        $result.Success = $false
        if ($missingGroups.Count -gt 0)
        {
            Write-Host "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')" -ForegroundColor Yellow
            Write-Log -logFile $logFile -module $functionName -Message "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')"
        }
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Host "User $userName is a member of the following forbidden groups: $($forbiddenGroups -join ', ')" -ForegroundColor Yellow
            Write-Log -logFile $logFile -module $functionName -Message "User $userName is a member of the following forbidden groups: $($forbiddenGroups -join ', ')"
        }
    }
    Write-Verbose "[$functionName] Completed VerifyGroupMembership function with Success=$($result.Success)"
    Write-Log -logFile $logFile -module $functionName -Message "Completed VerifyGroupMembership function with Success=$($result.Success)"
    return $result
    #endregion
}

