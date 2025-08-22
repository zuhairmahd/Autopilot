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
    Write-Log -logFile $logFile -module $functionName -Message "Starting VerifyGroupMembership function" -logLevel "Verbose"

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

    Write-Verbose "[$functionName] User name: $userName"
    Write-Log -logFile $logFile -module $functionName -Message "User name: $userName"
    Write-Verbose "[$functionName] Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })"
    Write-Log -logFile $logFile -module $functionName -Message "Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })" 
    Write-Verbose "[$functionName] Groups to exclude count: $(if ($groupsToExclude) { $groupsToExclude.Count } else { 0 })"
    if ($groupsToInclude)
    {
        Write-Verbose "[$functionName] Groups to include: $($groupsToInclude -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Groups to include: $($groupsToInclude -join ', ')"
    }
    if ($groupsToExclude)
    {
        Write-Verbose "[$functionName] Groups to exclude: $($groupsToExclude -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Groups to exclude: $($groupsToExclude -join ', ')"
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
        if ($groupsToInclude.count -gt 0)
        {
            Write-Verbose "[$functionName] Checking membership in $($groupsToInclude.Count) required groups for user $userName"
            Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($groupsToInclude.Count) required groups for user $userName"
            $includedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $groupsToInclude
            Write-Verbose "[$functionName] Number of included groups: $($includedGroupMembership.Count)"
            Write-Log -logFile $logFile -module $functionName -Message "Number of included groups: $($includedGroupMembership.Count)"
            Write-Verbose "[$functionName] Included group membership: $($includedGroupMembership -join ', ')"
            Write-Log -logFile $logFile -module $functionName -Message "Included group membership: $($includedGroupMembership -join ', ')"
            # Determine missing required groups
            $missingGroups = $groupsToInclude | Where-Object { $includedGroupMembership -notcontains $_ }
            $result.MissingGroups = $missingGroups
            if ($missingGroups.Count -gt 0)
            {
                Write-Verbose "[$functionName] User $userName is missing membership in the following required groups: $($missingGroups -join ', ')"
                Write-Log -logFile $logFile -module $functionName -Message "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')" -logLevel "Warning"
            }
        }
        if ($groupsToExclude.count -gt 0)
        {
            Write-Verbose "[$functionName] Checking membership in $($groupsToExclude.Count) excluded groups for user $userName"
            Write-Log -logFile $logFile -module $functionName -Message "Checking membership in $($groupsToExclude.Count) excluded groups for user $userName"
            $excludedGroupMembership = getGroupMembership -accessToken $accessToken -userName $userName -Groups $groupsToExclude
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

