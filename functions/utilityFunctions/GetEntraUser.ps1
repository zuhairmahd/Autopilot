function GetEntraUser()    
{
    [CmdletBinding()]
    param (
        [string]$accessToken,
        [ValidateSet('User', 'Group')]
        [string]$ObjectType = 'User',
        [string]$Name,
        [switch]$FindSimilar
    )

    $functionName = $MyInvocation.MyCommand.Name
    $substringSearch = $false
    Write-Verbose "[$functionName] Starting function to get $ObjectType from Entra ID"
    # Validate access token
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return $returnValues.noAccessTokenMessage
    }
    if ($ObjectType -eq 'User')
    {
        Write-Verbose "[$functionName] Attempting exact match for userPrincipalName: $Name"
        $Uri = "users/$Name"
        $ExtraParameters = "select=givenName,surName,displayName,userPrincipalName,mail,id"
    }
    elseif ($ObjectType -eq 'Group')
    {
        Write-Verbose "[$functionName] Attempting exact match for group: $Name"
        $Uri = "groups/$Name"
        $ExtraParameters = "select=displayName,,id"
    }
    $Info = CallGraphAPI -accessToken $AccessToken -ResourcePath $Uri -extraParameters $ExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($Info | Out-String)"

    if ($Info -notin 400, 401, 403, 404)
    {
        Write-Verbose "[$functionName] Exact match found for $($ObjectType): $Name"
        Write-Verbose "[$functionName] $ObjectType found: $($Info.displayName)"
        # Create a response object in the same format as Graph API for consistency
        $exactMatchResponse = [PSCustomObject]@{
            '@odata.context' = $null
            value            = @($Info)  # Force array creation even for single item
        }
        
        return $exactMatchResponse, $substringSearch
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($Info -in 400, 401, 403, 404 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $Info"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "$objectType lookup failed with error code: $Info" -LogLevel "Error"

        # Display appropriate error message to user based on error code
        switch ($Info)
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
        if ($ObjectType -eq 'User')
        {
            Write-Verbose "[$functionName] User '$Name' not found in Entra ID."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User '$Name' not found in Entra ID." -LogLevel "Error"
            return $returnValues.noUserFoundInDirectoryMessage
        }
        else
        {
            Write-Verbose "[$functionName] Group '$Name' not found in Entra ID."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group '$Name' not found in Entra ID." -LogLevel "Error"
            return $returnValues.noGroupFoundMessage
        }
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $Info). Performing substring search using Graph API search."
        if ($objectType -eq 'User') 
        {
            Write-Verbose "[$functionName] Normalizing username for search."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Normalizing username for search: $UserName" -LogLevel "Information"
            $searchTerm = $UserName -replace '@.*$', ''
            Write-Verbose "[$functionName] Cleaned search term: $searchTerm"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cleaned search term: $searchTerm" -LogLevel "Information"
            $searchUri = "users"
            $filterExpression = "startswith(givenName, '$searchTerm') or startsWith(surname, '$searchTerm')"
            Write-Verbose "[$functionName] Searching for substring matches in user properties for: $searchTerm"
            Write-Verbose "[$functionName] Trying filter: $filterExpression" 
        }        
        elseif ($objectType -eq 'Group')
        {
            $searchTerm = $Name
            $searchUri = "groups"
            $filterExpression = "contains(displayName, '$searchTerm') or startsWith(displayName, '$searchTerm') or endsWith(displayName, '$searchTerm')"
            Write-Verbose "[$functionName] Searching for substring matches in group properties for: $searchTerm"
            Write-Verbose "[$functionName] Trying filter: $filterExpression" 
        }
        
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $ExtraParameters
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            $substringSearch = $true
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            # Initialize filtered results array
            $filteredResults = @()
            # Filter out excluded users
            foreach ($item in $fallbackResults.value)
            {
                #Check if the user is a duplicate record of a previous record
                Write-Verbose "[$functionName] Processing user: $($item.displayName) ($($item.userPrincipalName))"
                if ($filteredResults -contains $item.userPrincipalName -or $filteredResults -contains $item.displayName)
                {
                    Write-Verbose "[$functionName] $objectType $($item.displayName) is a duplicate, skipping."
                    continue
                }
                $excludeUser = $false
                # Check if any of the exclusion patterns match this user
                Write-Verbose "Checking against $($settings.userPatternsToExclude.Count) patterns to exclude."
                if ($settings.userPatternsToExclude -and $settings.userPatternsToExclude.Count -gt 0)
                {
                    foreach ($pattern in $settings.userPatternsToExclude)
                    {
                        Write-Verbose "[$functionName] Checking $($objectType): $($item.displayName) ($($item.userPrincipalName)) against exclusion pattern: $pattern"
                        if ($item.userPrincipalName.Contains($pattern) -or $item.displayName -match $pattern)
                        {
                            # If the user matches any exclusion pattern, mark them for exclusion
                            Write-Verbose "[$functionName] $($objectType) $($item.displayName) matches exclusion pattern: $pattern"
                            Write-Verbose "[$functionName] Excluding $($objectType): $($item.displayName) ($($item.userPrincipalName)) - Matched exclusion pattern: $pattern"
                            $excludeUser = $true
                            break
                        }
                    }
                }
                # Add user to filtered results if not excluded
                if (-not $excludeUser)
                {
                    Write-Verbose "[$functionName] Including $($objectType): $($item.displayName) ($($item.userPrincipalName))"
                    $filteredUsers += $item
                }
            }            # Create a response object in the same format as the original Graph API response
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredResults | Sort-Object -Property userPrincipalName -Unique)  # Force array creation
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique objects after exclusions"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            if ($objectType -eq 'user')
            {
                return $returnValues.noUserFoundInDirectoryMessage
            }
            else
            {
                return $returnValues.noGroupFoundMessage
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] No matches found for userPrincipalName: $UserName"
        return $returnValues.noUserFoundInDirectoryMessage
    }
}

