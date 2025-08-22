function getGroupMembership()
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [Parameter(Mandatory = $true)]
        [string[]]$groups
    )

    $functionName = $MyInvocation.MyCommand.Name
    #print verbose and log received parameters.
    Write-Verbose "[$functionName] Received parameters:"
    Write-Log -logFile $logFile -module $functionName -Message "Received parameters: AccessToken: $($accessToken.Substring(0, 4))****, UserName: $userName, Groups: $($groups -join ', ')"
    Write-Verbose "[$functionName] AccessToken: $($accessToken.Substring(0, 4))****"
    Write-Log -logFile $logFile -module $functionName -Message "AccessToken: $($accessToken.Substring(0, 4))****"
    Write-Verbose "[$functionName] UserName: $userName"
    Write-Log -logFile $logFile -module $functionName -Message "UserName: $userName"
    Write-Verbose "[$functionName] Groups: $($groups -join ', ')"
    Write-Log -logFile $logFile -module $functionName -Message "Groups: $($groups -join ', ')"
    if (-not $accessToken)
    {
        Write-Error "AccessToken is required."
        Write-Log -logFile $logFile -module $functionName -Message "AccessToken is required." -logLevel "error"
        return $null
    }
    # Validate input
    if (-not $groups -or $groups.Count -eq 0)
    {
        Write-Error "Groups are required."
        Write-Log -logFile $logFile -module $functionName -Message "Groups are required." -logLevel "error"
        return $null
    }
    Write-Verbose "[$functionName] Resolving group names to IDs..."
    Write-Log -logFile $logFile -module $functionName -Message "Resolving group names to IDs..."
    $GroupIds = GetGroupIdsByNames -accessToken $accessToken -groupNames $groups
    Write-Verbose "[$functionName] Resolved group names to IDs: $($GroupIds -join ', ')"
    Write-Log -logFile $logFile -module $functionName -Message "Resolved group names to IDs: $($GroupIds -join ', ')"
    if ($groups.count -eq $GroupIds.count)
    {
        Write-Verbose "[$functionName] All group names were resolved to IDs."
        Write-Log -logFile $logFile -module $functionName -Message "All group names were resolved to IDs."
    }
    else
    {
        Write-Warning "[$functionName] Some group names could not be resolved to IDs."
        Write-Log -logFile $logFile -module $functionName -Message "Some group names could not be resolved to IDs." -logLevel "warning"
    }
    #build a json object with the group ids
    $body = @{
        groupIds = $GroupIds
    } | ConvertTo-Json
    $resourcePath = "users/$userName/checkMemberGroups"
    Write-Verbose "[$functionName] Calling Graph API with the following parameters:"
    Write-Verbose "Resource Path: $resourcePath"
    Write-Verbose "Body: $body"
    Write-Log -logFile $logFile -module $functionName -Message "Calling Graph API with Resource Path: $resourcePath and Body: $body"
    $response = CallGraphAPI -Method POST -ResourcePath $resourcePath -Body $body -AccessToken $accessToken
    Write-Verbose "[$functionName] Graph API response: $($response | ConvertTo-Json -Depth 10)"
    Write-Log -logFile $logFile -module $functionName -Message "Graph API response: $($response | ConvertTo-Json -Depth 10)"
    Write-Verbose "[$functionName] Resolving group IDs to names..."
    Write-Log -logFile $logFile -module $functionName -Message "Resolving group IDs to names..."
    $groupNames = GetGroupIdsByNames -accessToken $accessToken -groupNames $response.value
    Write-Log -logFile $logFile -module $functionName -Message "Resolved group IDs to names: $($groupNames -join ', ')"
    return $groupNames
}

