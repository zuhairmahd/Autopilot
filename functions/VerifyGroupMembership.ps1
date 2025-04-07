function VerifyGroupMembership()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [string[]]$groupsToInclude,
        [string[]]$groupsToExclude
    )

    #region write a verbose log of the received parameters and define variables.
    Write-Verbose "The user name is $userName"
    Write-Verbose "The groups to include are $($groupsToInclude -join ', ')"
    Write-Verbose "The groups to exclude are $($groupsToExclude -join ', ')"
    $success = $false
    $missingIncludeGroups = @()
    $invalidExcludeGroups = @()
    $groupsToReturn = @{}
    #endregion

    #region get the user id and group membership
    Write-Verbose "Getting the user id for $userName"
    $userUri = "https://graph.microsoft.com/beta/users/$($userName)" 
    $accessToken = GetGraphAccessToken -configFile $configFile
    try
    {
        $user = Invoke-RestMethod -Uri $userUri -Authentication Bearer -Token (ConvertTo-SecureString -String $accessToken -AsPlainText -Force) -Method Get -StatusCodeVariable 'UserStatusCode'
        Write-Verbose "The status code is $userStatusCode"
    }
    catch
    {
        $statusCode = $_.Exception.statuscode.value__
        $statusCodeMessage = $_.Exception.statuscode
        $statusMessage = $_.Exception.Message
        switch ($statusCode)
        {
            400
            {
                Write-Host 'Bad request. Please check the user name.' -ForegroundColor Red 
            }
            401
            {
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Host "Not found. The user $userName does not exist." -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message.' -ForegroundColor Red 
            }
        }
        Write-Host "Error: $statusMessage" -ForegroundColor Red
        Write-Host "The status code is $statusCode"
        Write-Host "$statusCode indicates $statusCodeMessage"
        Write-Host "The status message is $statusMessage"
        Write-Host 'The full error message follows below:'
        Write-Host '----------------------------------------------------------'
        Write-Host "$_"
        return $success
    }
    Write-Verbose "The Azure Directory id for $userName ($($user.DisplayName)) is $($user.ID)."
    Write-Verbose "Checking whether the user $userName is a member of the required groups."
    Write-Verbose "Getting group membership for user $userName ($($user.displayName)) with id $userID"
    $groupUri = "https://graph.microsoft.com/beta/users/$($userName)/memberOf/microsoft.graph.group?`$top=500"
    try
    {
        $response = Invoke-RestMethod -Uri $groupUri -Authentication Bearer -Token (ConvertTo-SecureString -String $accessToken -AsPlainText -Force) -Method Get -StatusCodeVariable 'GroupStatusCode'
        $groups = $response.value | Select-Object -ExpandProperty displayName
        Write-Verbose "The status code is $GroupStatusCode"
    }
    catch
    {
        $statusCode = $_.Exception.statuscode.value__
        $statusCodeMessage = $_.Exception.statuscode
        $statusMessage = $_.Exception.Message
        switch ($statusCode)
        {
            400
            {
                Write-Host 'Bad request. Please check the user name.' -ForegroundColor Red 
            }
            401
            {
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Host "Not found. The user $userName is not a member of any groups." -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message.' -ForegroundColor Red 
            }
        }
        Write-Host "Error: $statusMessage" -ForegroundColor Red
        Write-Host "$statusCode indicates $statusCodeMessage"
        Write-Host "The status message is $statusMessage"
        Write-Host 'The full error message follows below:'
        Write-Host '----------------------------------------------------------'
        Write-Host "$_"
        return $success
    }
    Write-Verbose "The user $userName is a member of $($($groups.Count)) groups."
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
        $success = $true
        return $success
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
    return $success
}