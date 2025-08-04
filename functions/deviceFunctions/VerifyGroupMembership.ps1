function VerifyGroupMembership()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [Parameter()]
        [string[]]$groupsToInclude,
        [Parameter()]
        [string[]]$groupsToExclude
    )

    #region Initialize result object and logging
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting VerifyGroupMembership function"

    # Create a consistent return object structure that will always be returned
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
        Write-Host "Access token is required." -ForegroundColor Red
        $result.Error = "Access token is required."
        return $result
    }

    Write-Verbose "[$functionName] User name: $userName"
    Write-Verbose "[$functionName] Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })"
    Write-Verbose "[$functionName] Groups to exclude count: $(if ($groupsToExclude) { $groupsToExclude.Count } else { 0 })"
    
    if ($groupsToInclude)
    {
        Write-Verbose "[$functionName] Groups to include: $($groupsToInclude -join ', ')"
    }
    
    if ($groupsToExclude)
    {
        Write-Verbose "[$functionName] Groups to exclude: $($groupsToExclude -join ', ')"
    }
    #endregion
    
    #region Get user information
    try
    {
        Write-Verbose "[$functionName] Getting user information for $userName"
        $userUri = "users/$($userName)" 
        $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri -extraparameters "select=displayName,mail,userPrincipalName,id"
        # Check if user was found
        if ($user -is [string] -and $user -match '^\d+$')
        {
            Write-Verbose "[$functionName] User $userName not found in Azure AD (Error code: $user)"
            Write-Host "The user $userName was not found in Azure AD." -ForegroundColor Red
            Write-Host "Please check the user name and try again." -ForegroundColor Red
            $result.Error = "User not found in Azure AD (Error code: $user)"
            return $result
        }
        $result.UserInfo = $user
        Write-Verbose "[$functionName] Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting user information: $_"
        Write-Host "Error getting user information: $_" -ForegroundColor Red
        $result.Error = "Error getting user information: $_"
        return $result
    }
    #endregion
    
    #region Get group membership
    try
    {
        Write-Verbose "[$functionName] Getting group membership for user $userName"
        Write-Host "Getting group membership for user $userName ($($user.displayName))."
        $groupUri = "users/$($userName)/memberOf/microsoft.graph.group"
        $groupSelection = "select=displayName&top=999&orderby=displayName"
        $response = CallGraphAPI -accessToken $accessToken -ResourcePath $groupUri -extraparameters $groupSelection
        if ($response -is [string] -and $response -match '^\d+$')
        {
            Write-Verbose "[$functionName] Failed to get group membership (Error code: $response)"
            Write-Host "The group membership for $userName could not be determined." -ForegroundColor Red
            Write-Host "Please try again or contact an Intune administrator." -ForegroundColor Red
            $result.Error = "Failed to get group membership (Error code: $response)"
            return $result
        }
        $groups = $response.value | Select-Object -ExpandProperty displayName | Sort-Object
        $result.UserGroups = $groups
        Write-Verbose "[$functionName] User $userName is a member of $($groups.Count) groups"
        Write-Host "User $userName is a member of $($groups.Count) groups."
        Write-Verbose "[$functionName] Groups: $($groups -join ', ')"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting group membership: $_"
        Write-Host "Error getting group membership: $_" -ForegroundColor Red
        $result.Error = "Error getting group membership: $_"
        return $result
    }
    #endregion
    
    #region Check include group membership
    $missingGroups = @()
    if ($null -eq $groupsToInclude -or $groupsToInclude.Count -eq 0)
    {
        Write-Verbose "[$functionName] No groups to include were specified. Skipping this check."
    }
    else
    {
        Write-Verbose "[$functionName] Checking memberships for user $userName in $($groupsToInclude.Count) required groups"
        foreach ($group in $groupsToInclude)
        {
            Write-Verbose "[$functionName] Checking membership in required group: $group"
            if ($groups -notcontains $group)
            {
                Write-Verbose "[$functionName] User $userName is NOT a member of the required group: $group"
                $missingGroups += $group
            }
            else
            {
                Write-Verbose "[$functionName] User $userName is a member of the required group: $group"
            }
        }
        $result.MissingGroups = $missingGroups
        if ($missingGroups.Count -gt 0)
        {
            Write-Verbose "[$functionName] User $userName is missing membership in $($missingGroups.Count) required groups: $($missingGroups -join ', ')"
        }
        else
        {
            Write-Verbose "[$functionName] User $userName is a member of all required groups"
        }
    }
    #endregion
    
    #region Check exclude group membership
    $forbiddenGroups = @()
    if ($null -eq $groupsToExclude -or $groupsToExclude.Count -eq 0)
    {
        Write-Verbose "[$functionName] No groups to exclude were specified. Skipping this check."
    }
    else
    {
        Write-Verbose "[$functionName] Checking user $userName isn't in $($groupsToExclude.Count) excluded groups"
        foreach ($group in $groupsToExclude)
        {
            Write-Verbose "[$functionName] Checking membership in excluded group: $group"
            if ($groups -contains $group)
            {
                Write-Verbose "[$functionName] User $userName is a member of the excluded group: $group (should not be)"
                $forbiddenGroups += $group
            }
            else
            {
                Write-Verbose "[$functionName] User $userName is not a member of the excluded group: $group (correct)"
            }
        }
        $result.ForbiddenGroups = $forbiddenGroups
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Verbose "[$functionName] User $userName is a member of $($forbiddenGroups.Count) excluded groups: $($forbiddenGroups -join ', ')"
        }
        else
        {
            Write-Verbose "[$functionName] User $userName is not a member of any excluded groups"
        }
    }
    #endregion
    
    #region Determine result and return
    if ($missingGroups.Count -eq 0 -and $forbiddenGroups.Count -eq 0)
    {
        Write-Verbose "[$functionName] User $userName has correct group memberships"
        $result.Success = $true
    }
    else
    {
        Write-Verbose "[$functionName] User $userName does not have correct group memberships"
        $result.Success = $false
        if ($missingGroups.Count -gt 0)
        {
            Write-Host "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')" -ForegroundColor Yellow
        }
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Host "User $userName is a member of the following forbidden groups: $($forbiddenGroups -join ', ')" -ForegroundColor Yellow
        }
    }
    Write-Verbose "[$functionName] Completed VerifyGroupMembership function with Success=$($result.Success)"
    return $result
    #endregion
}

