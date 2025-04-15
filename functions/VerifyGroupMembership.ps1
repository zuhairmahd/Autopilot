function VerifyGroupMembership()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [string[]]$groupsToInclude,
        [string[]]$groupsToExclude
    )

    #region write a verbose log of the received parameters and define variables.
    if ($accessToken)
    {
        Write-Verbose "Access token was provided"
    }
    else
    {
        Write-Verbose "Access token was not provided"
        return $false
    }
    Write-Verbose "The user name is $userName"
    Write-Verbose "The groups to include are $($groupsToInclude -join ', ')"
    Write-Verbose "The groups to exclude are $($groupsToExclude -join ', ')"
    $missingIncludeGroups = @()
    $invalidExcludeGroups = @()
    $groupsToReturn = @{}
    #endregion

    #region get the user id and group membership
    Write-Verbose "Getting the user id for $userName"
    $userUri = "users/$($userName)" 
    $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri 
    #check if the user is a numeric string.
    if ($user -is [string] -and $user -match '^\d+$')
    {
        Write-Verbose "The user $userName was not found in Azure AD."
        Write-Host "The user $userName was not found in Azure AD." -ForegroundColor Red
        Write-Host "Please check the user name and try again." -ForegroundColor Red
        return $false
    }
    Write-Verbose "The Azure Directory id for $userName ($($user.DisplayName)) is $($user.ID)."
    Write-Verbose "Checking whether the user $userName is a member of the required groups."
    Write-Host "Getting group membership for user $userName ($($user.displayName)) with id $($user.ID)"
    $groupUri = "users/$($userName)/memberOf/microsoft.graph.group"
    $response = CallGraphAPI -accessToken $accessToken -ResourcePath $groupUri
    if ($response -is [string] -and $response -match '^\d+$')
    {
        Write-Host "The group membership for $userName could not be determined."
        Write-Host "Please try again or contact an intune administrator." -ForegroundColor Red
        return $false
    }
    $groups = $response.value | Select-Object -ExpandProperty displayName
    Write-Host "The user $username is a member of $($groups.Count) groups."
    Write-Verbose "The user $userName is a member of the following groups:`n$($groups -join "`n")"
    #endregion
    
    #region check group membership
    if ($groupsToInclude.Count -eq 0)
    {
        Write-Verbose 'No groups to include were specified. Skipping this check.'
        $groupsToInclude = $null
    }
    else
    {
        Write-Verbose "The user $userName is a member of the following groups: $($groups -join ', ')"
        Write-Verbose "Checking whether the user $userName is a member of the required groups."
        foreach ($group in $groupsToInclude)
        {
            Write-Verbose "Checking membership in $group"
            if (-not ($groups -contains $group))
            {
                Write-Verbose "The user $userName is not a member of the required group $group"
                $missingIncludeGroups += $group
            }
            else
            {
                Write-Verbose "The user $userName is a member of the required group $group"
            }
        }
    }

    if ($groupsToExclude.Count -eq 0)
    {
        Write-Verbose 'No groups to exclude were specified. Skipping this check.'
        $groupsToExclude = $null
    }
    else
    {
        Write-Verbose "Checking whether the user $userName is a member of the excluded groups."
        foreach ($group in $groupsToExclude)
        {
            Write-Verbose "Checking membership in $group"
            if ($groups -contains $group)
            {
                Write-Verbose "The user $userName is a member of the excluded group $group"
                $invalidExcludeGroups += $group
            }
            else
            {
                Write-Verbose "The user $userName is not a member of the excluded group $group"
            }
        }
    }
    #endregion

    if (($missingIncludeGroups.Count -eq 0) -and ($invalidExcludeGroups.Count -eq 0))
    {
        Write-Verbose "The user $userName is a member of all required groups and not a member of any excluded groups."
        return $true
    }
    else
    {
        if ($missingIncludeGroups.Count -gt 0)
        {
            Write-Verbose "The user $userName is missing membership in the following required groups: $($missingIncludeGroups -join ', ')"
            $groupsToReturn.add('missingIncludeGroups', $missingIncludeGroups)
        }
        if ($invalidExcludeGroups.Count -gt 0)
        {
            Write-Verbose "The user $userName is a member of the following excluded groups: $($invalidExcludeGroups -join ', ')"
            $groupsToReturn.add('invalidExcludeGroups', $invalidExcludeGroups)
        }
        return $groupsToReturn
    }
}