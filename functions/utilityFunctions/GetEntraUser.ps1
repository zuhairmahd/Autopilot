function GetEntraUser()    
{
    [CmdletBinding()]
    param (
        [string]$accessToken,
        [string]$UserName,
        [switch]$FindSimilar
    )

    $functionName = $MyInvocation.MyCommand.Name
    $substringSearch = $false
    Write-Verbose "[$functionName] Starting function to get user from Entra ID"
    # Validate access token
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return $returnValues.noAccessTokenMessage
    }
    Write-Verbose "[$functionName] Attempting exact match for userPrincipalName: $UserName"
    $userUri = "users/$UserName"
    $userExtraParameters = "select=givenName,surName,displayName,userPrincipalName,mail,id"    
    $userInfo = CallGraphAPI -accessToken $AccessToken -ResourcePath $userUri -extraParameters $userExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($userInfo | Out-String)"
    
    if ($userInfo -notin 400, 401, 403, 404)
    {
        Write-Verbose "[$functionName] Exact match found for userPrincipalName: $UserName"
        Write-Verbose "[$functionName] User found: $($userInfo.displayName) ($($userInfo.userPrincipalName))"
        
        # Create a response object in the same format as Graph API for consistency
        $exactMatchResponse = [PSCustomObject]@{
            '@odata.context' = $null
            value            = @($userInfo)  # Force array creation even for single item
        }
        
        return $exactMatchResponse, $substringSearch
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($userInfo -in 400, 401, 403, 404 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $userInfo"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User lookup failed with error code: $userInfo" -LogLevel "Error"
        
        # Display appropriate error message to user based on error code
        switch ($userInfo)
        {
            400
            {
                Write-Host "Bad request. Please check the username format." -ForegroundColor Red 
            }
            401
            {
                Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red 
            }
            403
            {
                Write-Host "Forbidden. You do not have permission to access this user." -ForegroundColor Red 
            }
            404
            {
                Write-Host "User '$UserName' not found in Entra ID." -ForegroundColor Red 
            }
        }
        
        return $returnValues.noUserFoundInDirectoryMessage
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $userInfo). Performing substring search using Graph API search."
        # Remove the @ portion from the username if it exists for better search results
        $searchTerm = $UserName -replace '@.*$', ''
        Write-Verbose "[$functionName] Cleaned search term: $searchTerm"
        $searchUri = "users"
        $filterExpression = "startswith(givenName, '$searchTerm') or startsWith(surname, '$searchTerm')"
        Write-Verbose "[$functionName] Searching for substring matches in user properties for: $searchTerm"
        Write-Verbose "[$functionName] Trying filter: $filterExpression" 
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $userExtraParameters
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            $substringSearch = $true
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            # Initialize filtered results array
            $filteredUsers = @()
            # Filter out excluded users
            foreach ($user in $fallbackResults.value)
            {
                #Check if the user is a duplicate record of a previous record
                Write-Verbose "[$functionName] Processing user: $($user.displayName) ($($user.userPrincipalName))"
                if ($filteredUsers -contains $user.userPrincipalName)
                {
                    Write-Verbose "[$functionName] User $($user.userPrincipalName) is a duplicate, skipping."
                    continue
                }
                $excludeUser = $false
                # Check if any of the exclusion patterns match this user
                Write-Verbose "Checking against $($settings.userPatternsToExclude.Count) patterns to exclude."
                if ($settings.userPatternsToExclude -and $settings.userPatternsToExclude.Count -gt 0)
                {
                    foreach ($pattern in $settings.userPatternsToExclude)
                    {
                        Write-Verbose "[$functionName] Checking user: $($user.displayName) ($($user.userPrincipalName)) against exclusion pattern: $pattern"
                        if ($user.userPrincipalName.Contains($pattern) -or $user.displayName -match $pattern)
                        {
                            # If the user matches any exclusion pattern, mark them for exclusion
                            Write-Verbose "[$functionName] User matches exclusion pattern: $pattern"
                            Write-Verbose "[$functionName] Excluding user: $($user.displayName) ($($user.userPrincipalName)) - Matched exclusion pattern: $pattern"
                            $excludeUser = $true
                            break
                        }
                    }
                }
                # Add user to filtered results if not excluded
                if (-not $excludeUser)
                {
                    Write-Verbose "[$functionName] Including user: $($user.displayName) ($($user.userPrincipalName))"
                    $filteredUsers += $user
                }
            }            # Create a response object in the same format as the original Graph API response
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredUsers | Sort-Object -Property userPrincipalName -Unique)  # Force array creation
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique users after exclusions"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            return $returnValues.noUserFoundInDirectoryMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] No matches found for userPrincipalName: $UserName"
        return $returnValues.noUserFoundInDirectoryMessage
    }
}

