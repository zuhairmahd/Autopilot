function Get-EntraDirectoryObject()
{
    <#
    .SYNOPSIS
        Unified function to retrieve users or groups from Entra ID with optional fuzzy matching.
    
    .DESCRIPTION
        This function consolidates the logic from GetEntraUser and getEntraGroup into a single
        unified implementation. It supports exact and fuzzy matching for both users and groups,
        maintains a unified cache, applies exclusion patterns, and provides consistent error handling.
        
        The function returns a tuple: (EntityInfo, IsFuzzyMatch)
        - EntityInfo: The Graph API response with matching entities
        - IsFuzzyMatch: Boolean indicating if fuzzy search was used
    
    .PARAMETER EntityType
        Specifies whether to search for 'User' or 'Group'. Required.
    
    .PARAMETER EntityName
        The name to search for (userPrincipalName for users, displayName for groups).
    
    .PARAMETER AccessToken
        The access token for authenticating with Microsoft Graph API.
    
    .PARAMETER FindSimilar
        If specified, performs fuzzy matching when exact match fails.
    
    .OUTPUTS
        Returns a tuple: (EntityInfo, IsFuzzyMatch)
        - EntityInfo: PSCustomObject with '@odata.context' and 'value' properties
        - IsFuzzyMatch: Boolean ($true for fuzzy, $false for exact)
    
    .EXAMPLE
        # Search for user with exact match
        $result = Get-EntraDirectoryObject -EntityType User -EntityName "john.doe@contoso.com" -AccessToken $token
        if ($result[1] -eq $false) {
            Write-Host "Exact match found: $($result[0].value[0].displayName)"
        }
    
    .EXAMPLE
        # Search for group with fuzzy matching
        $result = Get-EntraDirectoryObject -EntityType Group -EntityName "Marketing" -AccessToken $token -FindSimilar
        Write-Host "Found $($result[0].value.Count) matches (Fuzzy: $($result[1]))"
    
    .NOTES
        Author: Windows Autopilot Management Tool Team
        Version: 1.0.0
        This function replaces GetEntraUser and getEntraGroup to eliminate code duplication.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("User", "Group")]
        [string]$EntityType,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$EntityName,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [switch]$FindSimilar
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $substringSearch = $false
    Write-Verbose "[$functionName] Starting function to get $EntityType from Entra ID"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting $EntityType search for: $EntityName" -LogLevel "Verbose"
    
    # Initialize unified cache if it doesn't exist
    if (-not $global:DirectoryObjectCache)
    {
        $global:DirectoryObjectCache = @{}
        Write-Verbose "[$functionName] Initialized directory object cache"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Initialized directory object cache" -LogLevel "Verbose"
    }
    
    # Create cache key including EntityType and FindSimilar flag
    $cacheKey = "$EntityType|$EntityName|$FindSimilar"
    
    # Check cache first
    if ($global:DirectoryObjectCache.ContainsKey($cacheKey))
    {
        Write-Verbose "[$functionName] Found cached result for $EntityType`: $EntityName (FindSimilar: $FindSimilar)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found cached result for $EntityType`: $EntityName" -LogLevel "Verbose"
        return $global:DirectoryObjectCache[$cacheKey]
    }
    
    # Validate access token
    if ([string]::IsNullOrWhiteSpace($AccessToken))
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken is required but was not provided" -LogLevel "Error"
        return $returnValues.noAccessTokenMessage
    }
    
    # Step 1: Attempt exact match
    Write-Verbose "[$functionName] Attempting exact match for $EntityType`: $EntityName"
    
    if ($EntityType -eq "User")
    {
        # User exact match by userPrincipalName
        $resourcePath = "users/$EntityName"
        $extraParameters = "select=givenName,surName,displayName,userPrincipalName,mail,id"
        $entityInfo = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourcePath -extraParameters $extraParameters
    }
    else
    {
        # Group exact match by displayName (case-insensitive using tolower)
        $resourcePath = "groups"
        $filter = "displayName eq '$EntityName'"
        $extraParameters = "select=displayName,id"
        $entityInfo = CallGraphAPI -AccessToken $AccessToken -ResourcePath $resourcePath -Filter $filter -ExtraParameters $extraParameters
    }
    
    Write-Verbose "[$functionName] Exact match API response: $($entityInfo | Out-String)"
    
    # Check if exact match succeeded
    $exactMatchFound = $false
    if ($EntityType -eq "User")
    {
        # For users, direct resource path returns object or error code
        $exactMatchFound = ($entityInfo -notin 400, 401, 403, 404)
    }
    else
    {
        # For groups, filter returns object with value array
        $exactMatchFound = ($entityInfo -notin 400, 401, 403, 404 -and $entityInfo.value -and $entityInfo.value.Count -gt 0)
    }
    
    if ($exactMatchFound)
    {
        Write-Verbose "[$functionName] Exact match found for $EntityType`: $EntityName"
        
        # Create consistent response format
        if ($EntityType -eq "User")
        {
            $exactMatchResponse = [PSCustomObject]@{
                '@odata.context' = $null
                value            = @($entityInfo)  # Wrap single user in array
            }
            Write-Verbose "[$functionName] User found: $($entityInfo.displayName) ($($entityInfo.userPrincipalName))"
        }
        else
        {
            $exactMatchResponse = $entityInfo  # Already in correct format
            Write-Verbose "[$functionName] Group found: $($entityInfo.value[0].displayName)"
        }
        
        # Cache and return
        $result = $exactMatchResponse, $substringSearch
        $global:DirectoryObjectCache[$cacheKey] = $result
        Write-Verbose "[$functionName] Cached exact match result for $EntityType`: $EntityName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Cached exact match for $EntityType`: $EntityName" -LogLevel "Verbose"
        
        return $result
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($entityInfo -in 400, 401, 403, 404 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $entityInfo"
        Write-Log -LogFile $LogFile -Module $functionName -Message "$EntityType lookup failed with error code: $entityInfo" -LogLevel "Error"
        
        # Display appropriate error message
        switch ($entityInfo)
        {
            400
            {
                Write-Host "Bad request. Please check the $EntityType name format." -ForegroundColor Red 
            }
            401
            {
                Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red 
            }
            403
            {
                Write-Host "Forbidden. You do not have permission to access this $EntityType." -ForegroundColor Red 
            }
            404
            {
                Write-Host "$EntityType '$EntityName' not found in Entra ID." -ForegroundColor Red 
            }
        }
        
        $noEntityMessage = if ($EntityType -eq "User")
        {
            $returnValues.noUserFoundInDirectoryMessage 
        }
        else
        {
            $returnValues.noGroupFoundMessage 
        }
        return $noEntityMessage
    }
    
    # Step 2: Perform fuzzy search if FindSimilar is enabled
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found. Performing fuzzy search for $EntityType"
        $substringSearch = $true
        
        if ($EntityType -eq "User")
        {
            # User fuzzy search: filter on givenName/surname
            $searchTerm = $EntityName -replace '@.*$', ''  # Remove domain for better matching
            Write-Verbose "[$functionName] Cleaned search term: $searchTerm"
            
            $resourcePath = "users"
            $filterExpression = "startswith(givenName, '$searchTerm') or startsWith(surname, '$searchTerm')"
            $extraParameters = "select=givenName,surName,displayName,userPrincipalName,mail,id"
            
            Write-Verbose "[$functionName] Trying filter: $filterExpression"
            $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourcePath -filter $filterExpression -extraParameters $extraParameters
        }
        else
        {
            # Group fuzzy search: try $search first, then filters
            $searchTerm = $EntityName
            $resourcePath = "groups"
            $extraParameters = "select=displayName,id"
            
            # Try $search with advanced query
            $searchClause = '"displayName:{0}"' -f $searchTerm
            $encodedSearch = [uri]::EscapeDataString($searchClause)
            $searchExtra = "search=$encodedSearch&$extraParameters"
            
            Write-Verbose "[$functionName] Trying `$search with clause: $searchClause"
            $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourcePath -extraParameters $searchExtra -consistencyLevel
            
            # Fallback to filters if $search fails
            if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
            {
                Write-Verbose "[$functionName] `$search failed. Trying startsWith filter"
                $filterExpression = "startsWith(displayName, '$searchTerm')"
                $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourcePath -filter $filterExpression -extraParameters $extraParameters
                
                # If startsWith fails, try contains with advanced query
                if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
                {
                    Write-Verbose "[$functionName] startsWith failed. Trying contains filter with advanced query"
                    $advancedFilterExpression = "contains(displayName, '$searchTerm')"
                    $advancedExtraParameters = "$extraParameters&count=true"
                    $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourcePath -filter $advancedFilterExpression -extraParameters $advancedExtraParameters -consistencyLevel
                }
            }
        }
        
        # Process fuzzy search results
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            Write-Verbose "[$functionName] Fuzzy search returned $($fallbackResults.value.Count) results"
            
            # Apply exclusion patterns
            $exclusionPatterns = if ($EntityType -eq "User")
            {
                $settings.userPatternsToExclude 
            }
            else
            {
                $settings.groupPatternsToExclude 
            }
            $filteredResults = @()
            
            foreach ($item in $fallbackResults.value)
            {
                # Check for duplicates
                $uniqueKey = if ($EntityType -eq "User")
                {
                    $item.userPrincipalName 
                }
                else
                {
                    $item.displayName 
                }
                
                if ($filteredResults.userPrincipalName -contains $uniqueKey -or $filteredResults.displayName -contains $uniqueKey)
                {
                    Write-Verbose "[$functionName] Skipping duplicate: $uniqueKey"
                    continue
                }
                
                # Check exclusion patterns
                $excludeItem = $false
                if ($exclusionPatterns -and $exclusionPatterns.Count -gt 0)
                {
                    foreach ($pattern in $exclusionPatterns)
                    {
                        $matchField = if ($EntityType -eq "User")
                        {
                            $item.userPrincipalName 
                        }
                        else
                        {
                            $item.displayName 
                        }
                        if ($matchField -match $pattern -or $item.displayName -match $pattern)
                        {
                            Write-Verbose "[$functionName] Excluding $EntityType`: $matchField (matched pattern: $pattern)"
                            $excludeItem = $true
                            break
                        }
                    }
                }
                
                if (-not $excludeItem)
                {
                    Write-Verbose "[$functionName] Including $EntityType`: $uniqueKey"
                    $filteredResults += $item
                }
            }
            
            # Create filtered response
            $sortProperty = if ($EntityType -eq "User")
            {
                "userPrincipalName" 
            }
            else
            {
                "displayName" 
            }
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredResults | Sort-Object -Property $sortProperty -Unique)
            }
            
            Write-Verbose "[$functionName] Filtered to $($filteredResponse.value.Count) unique $EntityType entities after exclusions"
            
            # Cache and return
            $result = $filteredResponse, $substringSearch
            $global:DirectoryObjectCache[$cacheKey] = $result
            Write-Verbose "[$functionName] Cached fuzzy search result for $EntityType`: $EntityName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cached fuzzy search result for $EntityType`: $EntityName" -LogLevel "Verbose"
            
            return $result
        }
        else
        {
            Write-Verbose "[$functionName] Fuzzy search failed (Error code: $fallbackResults)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Fuzzy search failed for $EntityType`: $EntityName" -LogLevel "Warning"
        }
    }
    
    # No matches found
    Write-Verbose "[$functionName] No matches found for $EntityType`: $EntityName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "No matches found for $EntityType`: $EntityName" -LogLevel "Warning"
    
    $noEntityMessage = if ($EntityType -eq "User")
    {
        $returnValues.noUserFoundInDirectoryMessage 
    }
    else
    {
        $returnValues.noGroupFoundMessage 
    }
    return $noEntityMessage
}
