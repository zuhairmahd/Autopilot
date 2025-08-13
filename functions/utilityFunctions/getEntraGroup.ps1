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
    Write-Verbose "[$functionName] Starting function to get group from Entra ID"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting function to get group from Entra ID" -LogLevel "Information"
    # Validate access token
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken is null or empty. Cannot proceed." -LogLevel "Error"
        return $returnValues.noAccessTokenMessage
    }
    Write-Verbose "[$functionName] Attempting exact match for group: $groupName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting exact match for group: $groupName" -LogLevel "Information"
    $Uri = "groups"
    $filter = "displayName eq '$groupName'"
    $ExtraParameters = "select=displayName,id"
    Write-Verbose "[$functionName] Calling Graph API with $Uri/$filter/$ExtraParameters"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Calling Graph API with $Uri/$filter/$ExtraParameters" -LogLevel "Information"
    $Info = CallGraphAPI -AccessToken $accessToken -ResourcePath $Uri -Filter $filter -ExtraParameters $ExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($Info | Out-String)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match API response: $($Info | Out-String)" -LogLevel "Information"
    if ($Info -notin 400, 401, 403, 404 -and $info.value.count -gt 0)
    {
        Write-Verbose "[$functionName] Exact match found for group: $groupName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match found for group: $groupName" -LogLevel "Information"
        Write-Verbose "[$functionName] group found: $($Info.displayName)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "group found: $($Info.displayName)" -LogLevel "Information"
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
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group '$groupName' not found in Entra ID." -LogLevel "Error"
            }
        }
        Write-Verbose "[$functionName] Group '$groupName' not found in Entra ID."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group '$groupName' not found in Entra ID." -LogLevel "Error"
        return $returnValues.noGroupFoundMessage
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $Info). Performing similarity search."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No exact match found (Error code: $Info). Performing similarity search." -LogLevel "Information"
        $searchTerm = $groupName
        Write-Verbose "[$functionName] Using search term: $searchTerm"
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
        Write-Verbose "[$functionName] Trying $search with clause: $searchClause"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying $search with clause: $searchClause" -LogLevel "Information"
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $Uri -extraParameters $searchExtra -consistencyLevel
        if ($fallbackResults -is [int])
        {
            Write-Verbose "[$functionName] $search call returned status code: $fallbackResults" 
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "$search call returned status code: $fallbackResults" -LogLevel "Error"
        }
        # 2b. If $search returns nothing (tenant restrictions/B2C/unsupported), fallback to filters
        if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
        {
            Write-Verbose "[$functionName] $search returned no results or failed. Falling back to $filter startsWith/contains flow."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "$search returned no results or failed. Falling back to $filter startsWith/contains flow." -LogLevel "Information"
            # First try simple startsWith filter (doesn't require advanced query)
            $filterExpression = "startsWith(displayName, '$searchTerm')"
            Write-Verbose "[$functionName] Trying basic filter: $filterExpression"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying basic filter: $filterExpression" -LogLevel "Information"
            $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $ExtraParameters
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Basic filter call returned status code: $($fallbackResults.StatusCode)" -LogLevel "Information"
            # If basic filter doesn't return results, try advanced query with contains (ConsistencyLevel + $count)
            if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
            {
                Write-Verbose "[$functionName] Basic filter returned no results. Trying advanced query with contains."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Basic filter returned no results. Trying advanced query with contains." -LogLevel "Information"
                $advancedFilterExpression = "contains(displayName, '$searchTerm')"
                Write-Verbose "[$functionName] Trying advanced filter: $advancedFilterExpression"
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
                    Write-Verbose "[$functionName] Advanced filter call returned status code: $fallbackResults" 
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Advanced filter call returned status code: $fallbackResults" -LogLevel "Error"
                }
                else
                {
                    Write-Verbose "[$functionName] Advanced query completed with $($fallbackResults.value.Count) results" 
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Advanced query completed with $($fallbackResults.value.Count) results" -LogLevel "Information"
                }
            }
        }
        # $fallbackResults is already set from the group search logic above
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            Write-Verbose "[$functionName] Similarity search returned $($fallbackResults.value.Count) results"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Similarity search returned $($fallbackResults.value.Count) results" -LogLevel "Information"
            $substringSearch = $true
            Write-Verbose "[$functionName] Proceeding to apply exclusion patterns and deduplicate by displayName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Proceeding to apply exclusion patterns and deduplicate by displayName" -LogLevel "Information"
            # Initialize filtered results array
            $filteredResults = @()
            # Filter out excluded items
            Write-Verbose "[$functionName] Filtering out excluded items"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering out excluded items" -LogLevel "Information"
            foreach ($item in $fallbackResults.value)
            {
                Write-Verbose "[$functionName] Processing group: $($item.displayName)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing group: $($item.displayName)" -LogLevel "Information"
                #Check if the object is a duplicate record of a previous record
                $uniqueKey = $item.displayName 
                Write-Verbose "[$functionName] Processing group: $($item.displayName) (Key: $uniqueKey)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing group: $($item.displayName) (Key: $uniqueKey)" -LogLevel "Information"
                if ($filteredResults -contains $uniqueKey)
                {
                    Write-Verbose "[$functionName] group $($item.displayName) is a duplicate, skipping."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "group $($item.displayName) is a duplicate, skipping." -LogLevel "Information"
                    continue
                }
                $excludeItem = $false
                # Check exclusion patterns based on object type
                Write-Verbose "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude." -LogLevel "Information"
                if ($settings.groupPatternsToExclude -and $settings.groupPatternsToExclude.Count -gt 0)
                {
                    Write-Verbose "[$functionName] Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude." -LogLevel "Information"
                    foreach ($pattern in $settings.groupPatternsToExclude)
                    {
                        Write-Verbose "[$functionName] Checking $(Group-Object): $($item.displayName) against exclusion pattern: $pattern"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking $(Group-Object): $($item.displayName) against exclusion pattern: $pattern" -LogLevel "Information"
                        if ($item.displayName -match $pattern)
                        {
                            Write-Verbose "[$functionName] $(Group-Object) $($item.displayName) matches exclusion pattern: $pattern"
                            Write-Verbose "[$functionName] Excluding $(Group-Object): $($item.displayName) - Matched exclusion pattern: $pattern"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Excluding $(Group-Object): $($item.displayName) - Matched exclusion pattern: $pattern" -LogLevel "Information"
                            $excludeItem = $true
                            break
                        }
                    }
                }
                # Add item to filtered results if not excluded
                if (-not $excludeItem)
                {
                    Write-Verbose "[$functionName] Including $(Group-Object): $($item.displayName)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Including $(Group-Object): $($item.displayName)" -LogLevel "Information"
                    $filteredResults += $item
                }
            }            
            # Create a response object in the same format as the original Graph API response
            Write-Verbose "[$functionName] Filtering results to unique groups based on displayName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering results to unique groups based on displayName" -LogLevel "Information"
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredResults | Sort-Object -Property displayName -Unique)
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique objects after exclusions"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered results to $($filteredResponse.value.Count) unique objects after exclusions" -LogLevel "Information"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search approach failed (Error code: $fallbackResults)" -LogLevel "Error"
            return $returnValues.noGroupFoundMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Match Similar switch was not used."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Match Similar switch was not used." -LogLevel "Information"
    }
}