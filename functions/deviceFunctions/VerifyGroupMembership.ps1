function VerifyGroupMembership()
{
    <#
    .SYNOPSIS
    Verifies a user's membership in inclusion and exclusion groups for assignment filtering.

    .DESCRIPTION
    This function checks whether a user is a member of specified inclusion groups and not a member
    of exclusion groups. It supports multiple group input formats (string arrays or hashtable arrays
    with name/id properties), automatically detects and converts formats, and performs efficient
    group membership validation. The function is used for determining user eligibility based on
    group-based assignment filters.

    .PARAMETER accessToken
    The Microsoft Graph API access token for authentication. This parameter is mandatory.

    .PARAMETER userName
    The user principal name to check group membership for. This parameter is mandatory.

    .PARAMETER groupsToInclude
    Groups the user must be a member of. Accepts string array of group names/IDs or hashtable array
    with 'name' and 'id' properties.

    .PARAMETER groupsToExclude
    Groups the user must NOT be a member of. Accepts string array of group names/IDs or hashtable array
    with 'name' and 'id' properties.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns object with properties:
    - includeGroupsPass: Boolean indicating if user is in all required inclusion groups
    - excludeGroupsPass: Boolean indicating if user is not in any exclusion groups
    - overallPass: Boolean indicating if both include and exclude checks pass
    - includeGroupNames: Array of inclusion group names checked
    - excludeGroupNames: Array of exclusion group names checked
    - includeMembership: Array of groups user is actually a member of
    - excludeMembership: Array of exclusion groups user is a member of (should be empty for pass)

    .EXAMPLE
    $result = VerifyGroupMembership -accessToken $token -userName "john@contoso.com" -groupsToInclude @("IT-Staff", "Admins")
    if ($result.overallPass) {
        Write-Host "User passes group membership requirements"
    }

    $result = VerifyGroupMembership -accessToken $token -userName "john@contoso.com" `
        -groupsToInclude @(@{name="IT-Staff"; id="guid1"}) `
        -groupsToExclude @("Contractors")

    .NOTES
    Supports multiple input formats:
    - String array: @("GroupName1", "GroupName2")
    - Hashtable array: @(@{name="Group"; id="guid"})
    - Mixed format detection and automatic conversion

    Helper functions:
    - Test-GroupFormat: Detects input format
    - Convert-GroupsToStandardFormat: Normalizes to standard format

    Uses GetGroupIdsByNames for name-to-ID resolution.
    Uses getGroupMembership for actual membership checking.
    Provides detailed logging of membership verification process.
    Compatible with PowerShell 5.1.
    #>
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
    Write-Log -logFile $logFile -module $functionName -Message "Starting VerifyGroupMembership function" -logLevel "Verbose"

    #region Helper functions for format detection and conversion
    function Test-GroupFormat()
    {
        [CmdletBinding()]
        param($groups)
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Testing group format"
        Write-Log -logFile $logFile -module $functionName -Message "Testing group format"
        if (-not $groups -or $groups.Count -eq 0)
        {
            return "Empty"
        }

        # Check first element to determine format
        $firstElement = $groups[0]
        Write-Verbose "[$functionName] First element type: $($firstElement.GetType().Name)"
        Write-Log -logFile $logFile -module $functionName -Message "First element type: $($firstElement.GetType().Name)"
        if ($firstElement -is [string])
        {
            Write-Verbose "[$functionName] Detected StringArray format"
            Write-Log -logFile $logFile -module $functionName -Message "Detected StringArray format"
            return "StringArray"
        }
        elseif ($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject])
        {
            # Accept hashtables with either name OR id (not requiring both to have values)
            # Just check that the properties exist as keys, regardless of their values
            Write-Verbose "[$functionName] Detected HashTableArray format"
            Write-Log -logFile $logFile -module $functionName -Message "Detected HashTableArray format"
            $hasNameProperty = (($firstElement.PSObject -and $firstElement.PSObject.Properties.Name -contains "name") -or $firstElement.ContainsKey("name"))
            $hasIdProperty = (($firstElement.PSObject -and $firstElement.PSObject.Properties.Name -contains "id") -or $firstElement.ContainsKey("id"))

            if ($hasNameProperty -and $hasIdProperty)
            {
                Write-Verbose "[$functionName] Both 'name' and 'id' properties found"
                Write-Log -logFile $logFile -module $functionName -Message "Both 'name' and 'id' properties found"
                return "HashTableArray"
            }
        }
        Write-Verbose "[$functionName] Detected Unknown format"
        Write-Log -logFile $logFile -module $functionName -Message "Detected Unknown format"
        return "Unknown"
    }

    function Convert-GroupsToStandardFormat()
    {
        [CmdletBinding()]
        param($groups, $groupType)
        $functionName = $MyInvocation.MyCommand.Name
        $format = Test-GroupFormat -groups $groups
        Write-Verbose "[$functionName] Detected format for $groupType groups: $format"
        Write-Log -logFile $logFile -module $functionName -Message "Detected format for $groupType groups: $format"

        switch ($format)
        {
            "Empty"
            {
                return @(), @()
            }  # Return empty arrays for names and IDs
            "HashTableArray"
            {
                # Extract names and IDs from hashtable format
                # Handle cases where names might be null but IDs exist
                $groupNames = @()
                $groupIds = @()
                foreach ($group in $groups)
                {
                    # Extract name (could be null/empty)
                    $name = if ($group.name)
                    {
                        $group.name
                    }
                    else
                    {
                        $null
                    }
                    $groupNames += $name
                    # Extract ID (could be null/empty)
                    $id = if ($group.id)
                    {
                        $group.id
                    }
                    else
                    {
                        $null
                    }
                    $groupIds += $id
                }
                Write-Verbose "[$functionName] Extracted from hashtable format - Names: $($groupNames -join ', '), IDs: $($groupIds -join ', ')"
                Write-Log -logFile $logFile -module $functionName -Message "Extracted from hashtable format - Names: $($groupNames -join ', '), IDs: $($groupIds -join ', ')"
                # If we have IDs but some names are null, try to resolve names from IDs
                $hasNullNames = ($groupNames | Where-Object { $null -eq $_ -or $_ -eq "" }).Count -gt 0
                $hasValidIds = ($groupIds | Where-Object { $null -ne $_ -and $_ -ne "" }).Count -gt 0
                if ($hasNullNames -and $hasValidIds -and $accessToken)
                {
                    Write-Verbose "[$functionName] Some names are null but IDs exist, attempting to resolve names from IDs"
                    Write-Log -logFile $logFile -module $functionName -Message "Some names are null but IDs exist, attempting to resolve names from IDs"

                    try
                    {
                        # Get valid IDs for resolution
                        $validIds = $groupIds | Where-Object { $null -ne $_ -and $_ -ne "" }
                        if ($validIds.Count -gt 0)
                        {
                            $resolvedNames = GetGroupIdsByNames -accessToken $accessToken -groupNames $validIds
                            Write-Verbose "[$functionName] Resolved $($resolvedNames.Count) names from $($validIds.Count) IDs"
                            Write-Log -logFile $logFile -module $functionName -Message "Resolved $($resolvedNames.Count) names from $($validIds.Count) IDs"
                            # Update the names array with resolved names where possible
                            for ($i = 0; $i -lt $groupIds.Count; $i++)
                            {
                                if (($null -eq $groupNames[$i] -or $groupNames[$i] -eq "") -and ($null -ne $groupIds[$i] -and $groupIds[$i] -ne ""))
                                {
                                    # Find the resolved name for this ID
                                    $idIndex = [Array]::IndexOf($validIds, $groupIds[$i])
                                    if ($idIndex -ge 0 -and $idIndex -lt $resolvedNames.Count -and $resolvedNames[$idIndex])
                                    {
                                        $groupNames[$i] = $resolvedNames[$idIndex]
                                        Write-Verbose "[$functionName] Resolved name for ID $($groupIds[$i]): $($resolvedNames[$idIndex])"
                                        Write-Log -logFile $logFile -module $functionName -Message "Resolved name for ID $($groupIds[$i]): $($resolvedNames[$idIndex])"
                                    }
                                }
                            }
                        }
                    }
                    catch
                    {
                        Write-Warning "[$functionName] Failed to resolve names from IDs for $groupType groups: $($_.Exception.Message)"
                        Write-Log -logFile $logFile -module $functionName -Message "Failed to resolve names from IDs for $groupType groups: $($_.Exception.Message)" -logLevel "Warning"
                    }
                }

                return $groupNames, $groupIds
            }
            "StringArray"
            {
                # Old format - need to resolve group names to IDs
                Write-Verbose "[$functionName] Old string array format detected for $groupType groups, resolving IDs"
                Write-Log -logFile $logFile -module $functionName -Message "Old string array format detected for $groupType groups, resolving IDs"

                try
                {
                    $resolvedIds = GetGroupIdsByNames -accessToken $accessToken -groupNames $groups
                    Write-Verbose "[$functionName] Resolved IDs for $groupType groups: $($resolvedIds -join ', ')"
                    Write-Log -logFile $logFile -module $functionName -Message "Resolved IDs for $groupType groups: $($resolvedIds -join ', ')"
                    return $groups, $resolvedIds
                }
                catch
                {
                    Write-Warning "[$functionName] Failed to resolve group IDs for $groupType groups: $($_.Exception.Message)"
                    Write-Log -logFile $logFile -module $functionName -Message "Failed to resolve group IDs for $groupType groups: $($_.Exception.Message)" -logLevel "Warning"
                    return $groups, @()  # Return names with empty IDs array
                }
            }
            default
            {
                Write-Warning "[$functionName] Unknown group format for $groupType groups"
                Write-Log -logFile $logFile -module $functionName -Message "Unknown group format for $groupType groups" -logLevel "Warning"
                return @(), @()
            }
        }
    }

    function New-HashTableGroupFormat()
    {
        [CmdletBinding()]
        param($groupNames, $groupIds)
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Creating new hashtable group format"
        Write-Log -logFile $logFile -module $functionName -Message "Creating new hashtable group format"
        $hashTableGroups = @()
        for ($i = 0; $i -lt $groupNames.Count; $i++)
        {
            $groupId = if ($i -lt $groupIds.Count)
            {
                $groupIds[$i]
            }
            else
            {
                $null
            }
            $hashTableGroups += @{
                name = $groupNames[$i]
                id   = $groupId
            }
        }
        Write-Verbose "[$functionName] Created hashtable group format with $($hashTableGroups.Count) groups"
        Write-Log -logFile $logFile -module $functionName -Message "Created hashtable group format with $($hashTableGroups.Count) groups"
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
    if ((Test-GroupFormat -groups $groupsToInclude) -eq "StringArray" -and $includeGroupIds.Count -gt 0)
    {
        $needsConfigUpdate = $true
        $updatedIncludeGroups = New-HashTableGroupFormat -groupNames $includeGroupNames -groupIds $includeGroupIds
        Write-Verbose "[$functionName] Created updated include groups format with $($updatedIncludeGroups.Count) groups"
        Write-Log -logFile $logFile -module $functionName -Message "Created updated include groups format with $($updatedIncludeGroups.Count) groups"
    }

    if ((Test-GroupFormat -groups $groupsToExclude) -eq "StringArray" -and $excludeGroupIds.Count -gt 0)
    {
        $needsConfigUpdate = $true
        $updatedExcludeGroups = New-HashTableGroupFormat -groupNames $excludeGroupNames -groupIds $excludeGroupIds
        Write-Verbose "[$functionName] Created updated exclude groups format with $($updatedExcludeGroups.Count) groups"
        Write-Log -logFile $logFile -module $functionName -Message "Created updated exclude groups format with $($updatedExcludeGroups.Count) groups"
    }
    #endregion

    # Create a consistent return object structure that will always be returned
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
        $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri -extraparameters "select=displayName,mail,userPrincipalName,id,accountEnabled"
        Write-Verbose "[$functionName] Got user information: $($user | ConvertTo-Json -Depth 3)"
        Write-Log -logFile $logFile -module $functionName -Message "Got user information: $($user | ConvertTo-Json -Depth $maxJsonDepth)"
        # Check if user was found
        if ($user -is [string] -and $user -match '^\d+$')
        {
            Write-Log -logFile $logFile -module $functionName -Message "User $userName not found in Azure AD (Error code: $user)" -LogLevel "Verbose"
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
        Write-Verbose "[$functionName] Getting all group memberships for user $userName"
        if ($includeGroupNames.count -gt 0)
        {
            Write-Verbose "[$functionName] Checking membership in $($includeGroupNames.Count) required groups for user $userName"
            Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($includeGroupNames.Count) required groups for user $userName"

            # Use group IDs for membership check (prioritize IDs over names)
            if ($includeGroupIds.Count -gt 0)
            {
                Write-Verbose "[$functionName] Checking membership in $($includeGroupIds.Count) required groups (IDs) for user $userName"
                Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($includeGroupIds.Count) required groups (IDs) for user $userName"
                $includedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $includeGroupIds -returnType "Ids"
            }
            else
            {
                Write-Verbose "[$functionName] Checking membership in $($includeGroupNames.Count) required groups (Names) for user $userName"
                Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($includeGroupNames.Count) required groups (Names) for user $userName"
                $includedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $includeGroupNames
            }
            Write-Verbose "[$functionName] $($includedGroupMembership.count) Included group membership: $($includedGroupMembership -join ', ')"
            Write-Log -logFile $logFile -module $functionName -Message "$($includedGroupMembership.count) Included group membership: $($includedGroupMembership -join ', ')"

            # Determine missing required groups with enhanced logic to handle null names
            # Priority: Use IDs for comparison if available and names are unreliable
            $missingGroups = @()
            $missingGroupIds = @()

            # Determine comparison strategy based on available data
            $useIdComparison = ($includeGroupIds.Count -gt 0) -and ($includeGroupIds | Where-Object { $null -ne $_ -and $_ -ne "" }).Count -gt 0
            $hasReliableNames = ($includeGroupNames | Where-Object { $null -ne $_ -and $_ -ne "" }).Count -eq $includeGroupNames.Count

            Write-Verbose "[$functionName] Comparison strategy - UseIdComparison: $useIdComparison, HasReliableNames: $hasReliableNames"
            Write-Log -logFile $logFile -module $functionName -Message "Comparison strategy - UseIdComparison: $useIdComparison, HasReliableNames: $hasReliableNames"

            if ($useIdComparison)
            {
                # Use ID-based comparison when IDs are available
                Write-Verbose "[$functionName] Using ID-based comparison for missing groups"
                Write-Log -logFile $logFile -module $functionName -Message "Using ID-based comparison for missing groups"
                $membershipIds = $includedGroupMembership
                # Compare required IDs against membership IDs
                for ($i = 0; $i -lt $includeGroupIds.Count; $i++)
                {
                    $requiredId = $includeGroupIds[$i]
                    if ($null -ne $requiredId -and $requiredId -ne "" -and $membershipIds -notcontains $requiredId)
                    {
                        $missingGroupIds += $requiredId

                        # For reporting, prefer the name if available, otherwise use ID
                        $displayName = if ($i -lt $includeGroupNames.Count -and $null -ne $includeGroupNames[$i] -and $includeGroupNames[$i] -ne "")
                        {
                            $includeGroupNames[$i]
                        }
                        else
                        {
                            $requiredId  # Fallback to ID for user feedback
                        }
                        $missingGroups += $displayName
                    }
                }
            }
            elseif ($hasReliableNames)
            {
                # Use traditional name-based comparison when names are reliable
                Write-Verbose "[$functionName] Using name-based comparison for missing groups"
                Write-Log -logFile $logFile -module $functionName -Message "Using name-based comparison for missing groups"
                $missingGroups = $includeGroupNames | Where-Object { $includedGroupMembership -notcontains $_ }
            }
            else
            {
                # Handle mixed/unreliable data scenario
                Write-Warning "[$functionName] Cannot reliably determine missing groups - both names and IDs have issues"
                Write-Log -logFile $logFile -module $functionName -Message "Cannot reliably determine missing groups - both names and IDs have issues" -logLevel "Warning"

                # Provide what information we can
                for ($i = 0; $i -lt $includeGroupNames.Count; $i++)
                {
                    $name = $includeGroupNames[$i]
                    $id = if ($i -lt $includeGroupIds.Count)
                    {
                        $includeGroupIds[$i]
                    }
                    else
                    {
                        $null
                    }

                    # Use available identifier for comparison
                    $identifier = if ($null -ne $name -and $name -ne "")
                    {
                        $name
                    }
                    else
                    {
                        $id
                    }
                    if ($null -ne $identifier -and $identifier -ne "" -and $includedGroupMembership -notcontains $identifier)
                    {
                        $missingGroups += $identifier
                    }
                }
            }
            $result.MissingGroups = $missingGroups
            if ($missingGroups.Count -gt 0)
            {
                Write-Log -logFile $logFile -module $functionName -Message "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')" -logLevel "Warning"
            }
        }
        if ($excludeGroupNames.count -gt 0)
        {
            Write-Verbose "[$functionName] Checking membership in $($excludeGroupNames.Count) excluded groups for user $userName"
            Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($excludeGroupNames.Count) excluded groups for user $userName"
            # Use group IDs for membership check (prioritize IDs over names)
            if ($excludeGroupIds.Count -gt 0)
            {
                Write-Verbose "[$functionName] Checking membership in $($excludeGroupIds.Count) excluded groups (IDs) for user $userName"
                Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($excludeGroupIds.Count) excluded groups (IDs) for user $userName"
                $excludedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $excludeGroupIds -returnType "Ids"
            }
            else
            {
                Write-Verbose "[$functionName] Checking membership in $($excludeGroupNames.Count) excluded groups (Names) for user $userName"
                Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($excludeGroupNames.Count) excluded groups (Names) for user $userName"
                $excludedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $groupsToCheck -returnType "Names"
            }
            Write-Verbose "[$functionName] Number of excluded groups: $($excludedGroupMembership.Count)"
            Write-Log -logFile $logFile -module $functionName -Message "Number of excluded groups: $($excludedGroupMembership.Count)"
            Write-Verbose "[$functionName] Excluded group membership: $($excludedGroupMembership -join ', ')"
            Write-Log -logFile $logFile -module $functionName -Message "Excluded group membership: $($excludedGroupMembership -join ', ')"
            # Determine forbidden groups with enhanced logic to handle null names
            # Priority: Use IDs for comparison if available and names are unreliable
            $forbiddenGroups = @()
            $forbiddenGroupIds = @()

            # Determine comparison strategy based on available data
            $useIdComparison = ($excludeGroupIds.Count -gt 0) -and ($excludeGroupIds | Where-Object { $null -ne $_ -and $_ -ne "" }).Count -gt 0
            $hasReliableNames = ($excludeGroupNames | Where-Object { $null -ne $_ -and $_ -ne "" }).Count -eq $excludeGroupNames.Count

            Write-Verbose "[$functionName] Exclude comparison strategy - UseIdComparison: $useIdComparison, HasReliableNames: $hasReliableNames"
            Write-Log -logFile $logFile -module $functionName -Message "Exclude comparison strategy - UseIdComparison: $useIdComparison, HasReliableNames: $hasReliableNames"

            if ($useIdComparison)
            {
                # Use ID-based comparison when IDs are available
                Write-Verbose "[$functionName] Using ID-based comparison for forbidden groups"
                Write-Log -logFile $logFile -module $functionName -Message "Using ID-based comparison for forbidden groups"
                $membershipIdsExclude = $excludedGroupMembership
                # Check which excluded IDs the user is actually a member of
                for ($i = 0; $i -lt $excludeGroupIds.Count; $i++)
                {
                    $excludedId = $excludeGroupIds[$i]
                    if ($null -ne $excludedId -and $excludedId -ne "" -and $membershipIdsExclude -contains $excludedId)
                    {
                        $forbiddenGroupIds += $excludedId

                        # For reporting, prefer the name if available, otherwise use ID
                        $displayName = if ($i -lt $excludeGroupNames.Count -and $null -ne $excludeGroupNames[$i] -and $excludeGroupNames[$i] -ne "")
                        {
                            $excludeGroupNames[$i]
                        }
                        else
                        {
                            $excludedId  # Fallback to ID for user feedback
                        }
                        $forbiddenGroups += $displayName
                    }
                }
            }
            elseif ($hasReliableNames)
            {
                # Use traditional name-based comparison when names are reliable
                Write-Verbose "[$functionName] Using name-based comparison for forbidden groups"
                Write-Log -logFile $logFile -module $functionName -Message "Using name-based comparison for forbidden groups"
                $forbiddenGroups = $excludedGroupMembership
            }
            else
            {
                # Handle mixed/unreliable data scenario
                Write-Warning "[$functionName] Cannot reliably determine forbidden groups - both names and IDs have issues"
                Write-Log -logFile $logFile -module $functionName -Message "Cannot reliably determine forbidden groups - both names and IDs have issues" -logLevel "Warning"

                # Use membership results as-is since we can't improve the comparison
                $forbiddenGroups = $excludedGroupMembership
            }

            $result.ForbiddenGroups = $forbiddenGroups
            if ($result.ForbiddenGroups.Count -gt 0)
            {
                Write-Log -logFile $logFile -module $functionName -Message "User $userName is a member of the following forbidden groups: $($result.ForbiddenGroups -join ', ')" -logLevel "Warning"
            }
        }
    }
    catch
    {
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
                catch
                {
                    continue
                }
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
    if ($result.MissingGroups.Count -eq 0 -and $result.ForbiddenGroups.Count -eq 0)
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
        if ($result.MissingGroups.Count -gt 0)
        {
            Write-Host "User $userName is missing membership in the following required groups: $($result.MissingGroups -join ', ')" -ForegroundColor Yellow
            Write-Log -logFile $logFile -module $functionName -Message "User $userName is missing membership in the following required groups: $($result.MissingGroups -join ', ')"
        }
        if ($result.ForbiddenGroups.Count -gt 0)
        {
            Write-Host "User $userName is a member of the following forbidden groups: $($result.ForbiddenGroups -join ', ')" -ForegroundColor Yellow
            Write-Log -logFile $logFile -module $functionName -Message "User $userName is a member of the following forbidden groups: $($result.ForbiddenGroups -join ', ')"
        }
    }
    Write-Verbose "[$functionName] Completed VerifyGroupMembership function with Success=$($result.Success)"
    Write-Log -logFile $logFile -module $functionName -Message "Completed VerifyGroupMembership function with Success=$($result.Success)"
    return $result
    #endregion
}

