function getGroupMembership()
{
    <#
    .SYNOPSIS
    Retrieves group membership information for a user.

    .DESCRIPTION
    This function queries Microsoft Graph to determine which groups from a provided list
    a user is a member of. It accepts group names or GUIDs as input and can return results
    as either group names or IDs. The function automatically detects whether input is in
    GUID or name format and handles the conversion appropriately.

    .PARAMETER accessToken
    The Microsoft Graph API access token for authentication. This parameter is mandatory.

    .PARAMETER userName
    The user principal name of the user to check group membership for. This parameter is mandatory.

    .PARAMETER groups
    An array of group names or GUIDs to check membership against. This parameter is mandatory.

    .PARAMETER returnType
    Specifies the format of the return value. Valid values: "Names" (default), "Ids".

    .OUTPUTS
    System.String[] or System.Collections.Hashtable
    Returns an array of group names/IDs that the user is a member of, or a hashtable
    containing membership details. Returns $null on error.

    .EXAMPLE
    $membership = getGroupMembership -accessToken $token -userName "john.doe@contoso.com" -groups @("IT-Admins", "Developers")
    $membership = getGroupMembership -accessToken $token -userName "jane@contoso.com" -groups $groupGuids -returnType "Ids"

    .NOTES
    Automatically detects if input groups are GUIDs or names.
    Converts group names to IDs internally for Graph API queries.
    Requires appropriate Microsoft Graph permissions to query group membership.
    Compatible with PowerShell 5.1.
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [Parameter(Mandatory = $true)]
        [string[]]$groups,
        [ValidateSet("Names", "Ids")]
        [string]$returnType = "Names"
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
    #validate if the first element is a GUID or a name.
    $isGUID = $false
    if ($groups[0] -match '^[{(]?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}[)}]?$')
    {
        Write-Verbose "[$functionName] Detected GUID format for groups."
        Write-Log -logFile $logFile -module $functionName -Message "Detected GUID format for groups."
        $isGUID = $true
    }
    else
    {
        Write-Verbose "[$functionName] Detected Name format for groups."
        Write-Log -logFile $logFile -module $functionName -Message "Detected Name format for groups."
    }
    if (-not $isGUID)
    {
        # Convert group names to IDs
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
    }
    else
    {
        $GroupIds = $groups
        Write-Verbose "[$functionName] Using provided group IDs: $($GroupIds -join ', ')"
        Write-Log -logFile $logFile -module $functionName -Message "Using provided group IDs: $($GroupIds -join ', ')"
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
    if ($returnType -eq "Ids")
    {
        Write-Verbose "[$functionName] Returning group IDs."
        Write-Log -logFile $logFile -module $functionName -Message "Returning group IDs."
        return $response.value
    }
    $groupNames = GetGroupIdsByNames -accessToken $accessToken -groupNames $response.value
    Write-Log -logFile $logFile -module $functionName -Message "Resolved group IDs to names: $($groupNames -join ', ')"
    return $groupNames
}

