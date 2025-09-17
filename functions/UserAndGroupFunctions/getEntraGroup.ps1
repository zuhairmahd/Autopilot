function GetEntraGroup()    
{
    [CmdletBinding()]
    param (
        [string]$accessToken,
        [string]$groupName,
        [switch]$FindSimilar
    )

    $functionName = $MyInvocation.MyCommand.Name
    $substringSearch = $false
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting function to get group from Entra ID" -LogLevel "Verbose"
    
    # Initialize group cache if it doesn't exist
    if (-not $global:GroupCache)
    {
        $global:GroupCache = @{}
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initialized group cache" -LogLevel "Verbose"
    }
    
    # Create cache key including FindSimilar flag for different search types
    $cacheKey = "$groupName|$FindSimilar"
    
    # Check cache first
    if ($global:GroupCache.ContainsKey($cacheKey))
    {
        Write-Verbose "[$functionName] Found cached result for group: $groupName (FindSimilar: $FindSimilar)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found cached result for group: $groupName" -LogLevel "Verbose"
        return $global:GroupCache[$cacheKey]
    }
    
    # Validate access token
    if (-not $accessToken)
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken is null or empty. Cannot proceed." -LogLevel "Warning"
        return $returnValues.noAccessTokenMessage
    }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting exact match for group: $groupName" -LogLevel "Verbose"
    $Uri = "groups"
    $filter = "displayName eq '$groupName'"
    $ExtraParameters = "select=displayName,id"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Calling Graph API with $Uri/$filter/$ExtraParameters" -LogLevel "Information"
    $Info = CallGraphAPI -AccessToken $accessToken -ResourcePath $Uri -Filter $filter -ExtraParameters $ExtraParameters
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match API response: $($Info | Out-String)" -LogLevel "Information"
    if ($Info -notin 400, 401, 403, 404 -and $Info.value -and $Info.value.count -gt 0)
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match found for group: $groupName" -LogLevel "Verbose"
Write-Log -LogFile $LogFile -Module "$functionName" -Message "group found: $($Info.value[0].displayName)" -LogLevel "Verbose"
        # Cache the result before returning
        $result = $Info, $substringSearch
        $global:GroupCache[$cacheKey] = $result
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached result for group: $groupName" -LogLevel "Verbose"
        # Return the response directly as it's already in the correct format
        return $result
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($Info -in 400, 401, 403, 404 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $Info"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "group lookup failed with error code: $Info" -LogLevel "Error"
        # Display appropriate error message to user based on error code
        switch ($Info)
        {
            400
            {
                Write-Host "Bad request. Please check the username format." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Bad request. Please check the username format." -LogLevel "Error"
            }
            401
            {
                Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Unauthorized. Please check your access token." -LogLevel "Error"
            }
            403
            {
                Write-Host "Forbidden. You do not have permission to access this group." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Forbidden. You do not have permission to access this group." -LogLevel "Error"
            }
            404
            {
                Write-Host "Group '$groupName' not found in Entra ID." -ForegroundColor Red 
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group '$groupName' not found in Entra ID." -LogLevel "Verbose"
            }
        }
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group '$groupName' not found in Entra ID." -LogLevel "Verbose"
        return $returnValues.noGroupFoundMessage
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No exact match found (Error code: $Info). Performing similarity search." -LogLevel "Verbose"
        $searchTerm = $groupName
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using search term: $searchTerm" -LogLevel "Information"
        # 2a. Prefer $search for tokenized matching on displayName (advanced queries with ConsistencyLevel: eventual)
        #     See: https://learn.microsoft.com/graph/search-query-parameter#use-$search-on-directory-object-collections
        $searchClause = '"displayName:{0}"' -f $searchTerm
        $encodedSearch = [uri]::EscapeDataString($searchClause)
        $searchExtra = if ($ExtraParameters)
        {
            "search=$encodedSearch&$ExtraParameters"
        }
        else
        {
            "search=$encodedSearch"
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying $search with clause: $searchClause" -LogLevel "Information"
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $Uri -extraParameters $searchExtra -consistencyLevel
        if ($fallbackResults -is [int])
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "$search call returned status code: $fallbackResults" -LogLevel "Error"
        }
        # 2b. If $search returns nothing (tenant restrictions/B2C/unsupported), fallback to filters
        if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "$search returned no results or failed. Falling back to $filter startsWith/contains flow." -LogLevel "Information"
            # First try simple startsWith filter (doesn't require advanced query)
            $filterExpression = "startsWith(displayName, '$searchTerm')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying basic filter: $filterExpression" -LogLevel "Information"
            $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $ExtraParameters
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Basic filter call returned status code: $($fallbackResults.StatusCode)" -LogLevel "Information"
            # If basic filter doesn't return results, try advanced query with contains (ConsistencyLevel + $count)
            if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Basic filter returned no results. Trying advanced query with contains." -LogLevel "Information"
                $advancedFilterExpression = "contains(displayName, '$searchTerm')"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying advanced filter: $advancedFilterExpression" -LogLevel "Information"
                $advancedExtraParameters = if ($ExtraParameters)
                {
                    "$ExtraParameters&count=true" 
                }
                else
                {
                    "count=true" 
                }
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using advanced filter: $advancedFilterExpression" -LogLevel "Information"
                $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $advancedFilterExpression -extraParameters $advancedExtraParameters -consistencyLevel
                if ($fallbackResults -is [int])
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Advanced filter call returned status code: $fallbackResults" -LogLevel "Error"
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Advanced query completed with $($fallbackResults.value.Count) results" -LogLevel "Information"
                }
            }
        }
        # $fallbackResults is already set from the group search logic above
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Similarity search returned $($fallbackResults.value.Count) results" -LogLevel "Information"
            $substringSearch = $true
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Proceeding to apply exclusion patterns and deduplicate by displayName" -LogLevel "Information"
            # Initialize filtered results array
            $filteredResults = @()
            # Filter out excluded items
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering out excluded items" -LogLevel "Information"
            foreach ($item in $fallbackResults.value)
            {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing group: $($item.displayName)" -LogLevel "Verbose"
                #Check if the object is a duplicate record of a previous record
                $uniqueKey = $item.displayName 
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing group: $($item.displayName) (Key: $uniqueKey)" -LogLevel "Verbose"
                if ($filteredResults -contains $uniqueKey)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "group $($item.displayName) is a duplicate, skipping." -LogLevel "Information"
                    continue
                }
                $excludeItem = $false
                # Check exclusion patterns based on object type
                Write-Verbose "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude."
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude." -LogLevel "Verbose"
                if ($settings.groupPatternsToExclude -and $settings.groupPatternsToExclude.Count -gt 0)
                {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude." -LogLevel "Verbose"
                    foreach ($pattern in $settings.groupPatternsToExclude)
                    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking $(Group-Object): $($item.displayName) against exclusion pattern: $pattern" -LogLevel "Verbose"
                        if ($item.displayName -match $pattern)
                        {
                            Write-Verbose "[$functionName] $(Group-Object) $($item.displayName) matches exclusion pattern: $pattern"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Excluding $(Group-Object): $($item.displayName) - Matched exclusion pattern: $pattern" -LogLevel "Information"
                            $excludeItem = $true
                            break
                        }
                    }
                }
                # Add item to filtered results if not excluded
                if (-not $excludeItem)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Including $(Group-Object): $($item.displayName)" -LogLevel "Information"
                    $filteredResults += $item
                }
            }            
            # Create a response object in the same format as the original Graph API response
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering results to unique groups based on displayName" -LogLevel "Information"
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredResults | Sort-Object -Property displayName -Unique)
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered results to $($filteredResponse.value.Count) unique objects after exclusions" -LogLevel "Information"
            # Cache the similarity search result before returning
            $result = $filteredResponse, $substringSearch
            $global:GroupCache[$cacheKey] = $result
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached similarity search result for group: $groupName" -LogLevel "Verbose"
            return $result
        }
        else        
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search approach failed (Error code: $fallbackResults)" -LogLevel "Error"
            return $returnValues.noGroupFoundMessage
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Match Similar switch was not used." -LogLevel "Information"
    }
}