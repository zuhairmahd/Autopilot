function Resolve-UserWithMatching
{
    <#
    .SYNOPSIS
        Resolves a username to a valid Entra user with support for fuzzy matching.
    
    .DESCRIPTION
        This function attempts to find an exact match for the provided username in Entra ID.
        If no exact match is found, it searches for similar users and prompts the user to 
        select from a list of possible matches. The function handles all user interaction 
        and returns a validated username or appropriate status codes for navigation.
    
    .PARAMETER UserName
        The username (email address) to search for in Entra ID.
    
    .PARAMETER AccessToken
        The access token for authenticating with Microsoft Graph API.
    
    .PARAMETER Settings
        The settings object containing configuration such as maxUserMatchDisplay.
    
    .PARAMETER ReturnValues
        The return values hashtable containing navigation messages.
    
    .OUTPUTS
        Returns the validated userPrincipalName if a user is found and confirmed,
        or a return value code for navigation (back, exit, etc.).
    
    .EXAMPLE
        $resolvedUser = Resolve-UserWithMatching -UserName "john.doe@contoso.com" -AccessToken $token -Settings $settings -ReturnValues $returnValues
        if ($resolvedUser -notin $returnValues.Values) {
            # Proceed with the resolved username
        }
    
    .NOTES
        This function encapsulates the user lookup and matching workflow that was previously
        inline in the main.ps1 "give a device to a user" action.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$UserName,
        
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ReturnValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Resolving user: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting user resolution for: $UserName" -LogLevel "Verbose"
    
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($UserName))
    {
        Write-Verbose "[$functionName] Username is null or empty"
        return $ReturnValues.noUserFoundInDirectoryMessage
    }
    
    if ([string]::IsNullOrWhiteSpace($AccessToken))
    {
        Write-Verbose "[$functionName] AccessToken is null or empty"
        Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken is required but was not provided" -LogLevel "Error"
        return $ReturnValues.noAccessTokenMessage
    }
    
    # Attempt to find the user with similar matches enabled
    $userInfo = GetEntraUser -userName $UserName -AccessToken $AccessToken -findSimilar
    Write-Verbose "[$functionName] User search returned: $($userInfo[0].value.count) results (fuzzy search: $($userInfo[1]))"
    Write-Log -LogFile $LogFile -Module $functionName -Message "User search completed. Results: $($userInfo[0].value.count), Fuzzy: $($userInfo[1])" -LogLevel "Verbose"
    
    # Handle exact match found
    if ($null -ne $userInfo -and $userInfo[1] -eq $false)
    {
        Write-Host "Found user: $($userInfo[0].value.displayName) ($($userInfo[0].value.userPrincipalName))" -ForegroundColor Green
        $resolvedUserName = $userInfo[0].value.userPrincipalName
        Write-Verbose "[$functionName] Exact match found. Resolved username: $resolvedUserName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exact match found for user: $resolvedUserName" -LogLevel "Information"
        return $resolvedUserName
    }
    
    # Handle fuzzy matches found
    if ($null -ne $userInfo -and $userInfo[1] -eq $true)
    {
        Write-Verbose "[$functionName] No exact match found. Processing $($userInfo[0].value.count) similar users"
        
        # Display appropriate message based on match count
        Write-Host "Could not find an exact match for user $($UserName)." -ForegroundColor Yellow
        
        if ($userInfo[0].value.count -eq 1)
        {
            Write-Host "Found a user with a similar name." -ForegroundColor Cyan
        }
        else
        {
            Write-Host "Found $($userInfo[0].value.count) users with similar names:" -ForegroundColor Cyan
        }
        
        # Check if we need to truncate the display
        $maxDisplay = [int]$Settings.maxUserMatchDisplay
        if ($userInfo[0].value.count -gt $maxDisplay)
        {
            Write-Host "Displaying the first $maxDisplay matches:" -ForegroundColor Yellow
        }
        elseif ($userInfo[0].value.count -eq 1)
        {
            Write-Host "Is this the correct user?" -ForegroundColor Cyan
        }
        else
        {
            Write-Host "Displaying all $($userInfo[0].value.count) matches:" -ForegroundColor Cyan
        }
        
        # Show the user list and get selection
        $possibleUserName = DisplayUserList -UserList $userInfo[0].value -maxDisplay $maxDisplay
        Write-Verbose "[$functionName] User selection result: $possibleUserName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected from list: $possibleUserName" -LogLevel "Verbose"
        
        # Process the selection result
        $result = ConvertFrom-UserSelection -SelectedValue $possibleUserName -ReturnValues $ReturnValues
        Write-Verbose "[$functionName] Processed user selection: $result"
        return $result
    }
    
    # Handle no matches found
    if ($userInfo -eq $ReturnValues.noUserFoundInDirectoryMessage)
    {
        Write-Verbose "[$functionName] No user found in directory"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No user found in directory for: $UserName" -LogLevel "Warning"
        return $ReturnValues.noUserFoundInDirectoryMessage
    }
    
    # Default fallback
    Write-Verbose "[$functionName] User resolution failed - returning noUserFoundInDirectoryMessage"
    Write-Log -LogFile $LogFile -Module $functionName -Message "User resolution failed for: $UserName" -LogLevel "Warning"
    return $ReturnValues.noUserFoundInDirectoryMessage
}
