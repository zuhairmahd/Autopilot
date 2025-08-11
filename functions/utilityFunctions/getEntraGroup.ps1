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
    # Validate access token
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return $returnValues.noAccessTokenMessage
    }
    Write-Verbose "[$functionName] Attempting exact match for group: $groupName"
    $Uri = "groups"
    $filter = "displayName eq '$groupName'"
    $ExtraParameters = "select=displayName,id"
    
    $Info = CallGraphAPI -AccessToken $accessToken -ResourcePath $Uri -Filter $filter -ExtraParameters = $ExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($Info | Out-String)"
    if ($Info -notin 400, 401, 403, 404 -and $info.value.count -gt 0)
    {
        Write-Verbose "[$functionName] Exact match found for group: $groupName"
        Write-Verbose "[$functionName] group found: $($Info.displayName)"
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
            }
            401
            {
                Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red 
            }
            403
            {
                Write-Host "Forbidden. You do not have permission to access this group." -ForegroundColor Red 
            }
            404
            {
                Write-Host "Group '$groupName' not found in Entra ID." -ForegroundColor Red 
            }
        }
        Write-Verbose "[$functionName] Group '$groupName' not found in Entra ID."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group '$groupName' not found in Entra ID." -LogLevel "Error"
        return $returnValues.noGroupFoundMessage
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $Info). Performing substring search using Graph API search."
        $searchTerm = $groupName
        $searchUri = "groups"
        # First try simple startsWith filter (doesn't require advanced query)
        $filterExpression = "startsWith(displayName, '$searchTerm')"
        Write-Verbose "[$functionName] Searching for substring matches in group properties for: $searchTerm"
        Write-Verbose "[$functionName] Trying basic filter: $filterExpression" 
        # Try basic startsWith first
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $ExtraParameters
        # If basic filter doesn't return results, try advanced query with contains
        if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
        {
            Write-Verbose "[$functionName] Basic filter returned no results. Trying advanced query with contains."
            $advancedFilterExpression = "contains(displayName, '$searchTerm')"
            Write-Verbose "[$functionName] Trying advanced filter: $advancedFilterExpression"
            # Use advanced query capabilities with ConsistencyLevel and count
            $advancedExtraParameters = if ($ExtraParameters)
            {
                "$ExtraParameters&count=true" 
            }
            else
            {
                "count=true" 
            }
            $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $advancedFilterExpression -extraParameters $advancedExtraParameters -consistencyLevel
            Write-Verbose "[$functionName] Advanced query completed with $($fallbackResults.value.Count) results"
        }
        # $fallbackResults is already set from the group search logic above
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            $substringSearch = $true
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            # Initialize filtered results array
            $filteredResults = @()
            # Filter out excluded items
            foreach ($item in $fallbackResults.value)
            {
                Write-Verbose "[$functionName] Processing group: $($item.displayName)"
                #Check if the object is a duplicate record of a previous record
                $uniqueKey = $item.displayName 
                Write-Verbose "[$functionName] Processing group: $($item.displayName) (Key: $uniqueKey)"
                if ($filteredResults -contains $uniqueKey)
                {
                    Write-Verbose "[$functionName] group $($item.displayName) is a duplicate, skipping."
                    continue
                }
                $excludeItem = $false
                # Check exclusion patterns based on object type
                Write-Verbose "Checking against $($settings.groupPatternsToExclude.Count) group patterns to exclude."
                if ($settings.groupPatternsToExclude -and $settings.groupPatternsToExclude.Count -gt 0)
                {
                    foreach ($pattern in $settings.groupPatternsToExclude)
                    {
                        Write-Verbose "[$functionName] Checking $(Group-Object): $($item.displayName) against exclusion pattern: $pattern"
                        if ($item.displayName -match $pattern)
                        {
                            Write-Verbose "[$functionName] $(Group-Object) $($item.displayName) matches exclusion pattern: $pattern"
                            Write-Verbose "[$functionName] Excluding $(Group-Object): $($item.displayName) - Matched exclusion pattern: $pattern"
                            $excludeItem = $true
                            break
                        }
                    }
                }
                # Add item to filtered results if not excluded
                if (-not $excludeItem)
                {
                    Write-Verbose "[$functionName] Including $(Group-Object): $($item.displayName)"
                    $filteredResults += $item
                }
            }            
            # Create a response object in the same format as the original Graph API response
            Write-Verbose "[$functionName] Filtering results to unique groups based on displayName"
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredResults | Sort-Object -Property displayName -Unique)
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique objects after exclusions"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            return $returnValues.noGroupFoundMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Match Similar switch was not used."
    }
}