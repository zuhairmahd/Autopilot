function GetEntraGroup()
{
    [CmdletBinding()]
    param (
        [string]$accessToken,
        [string]$GroupName,
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
    
    Write-Verbose "[$functionName] Attempting exact match for group displayName: $GroupName"
    $groupUri = "groups"
    $filter = "displayName eq '$($GroupName -replace "'", "''")'"
    $groupExtraParameters = "select=id,displayName,description"
    $groupInfo = CallGraphAPI -accessToken $AccessToken -ResourcePath $groupUri -filter $filter -extraParameters $groupExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($groupInfo | Out-String)"
    
    if ($groupInfo -notin 400, 401, 403, 404 -and $groupInfo.value -and $groupInfo.value.Count -gt 0)
    {
        Write-Verbose "[$functionName] Exact match found for group displayName: $GroupName"
        Write-Verbose "[$functionName] Group found: $($groupInfo.value[0].displayName) ($($groupInfo.value[0].id))"
        
        # Return the response in the same format as Graph API for consistency
        return $groupInfo, $substringSearch
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($groupInfo -in 400, 401, 403, 404 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $groupInfo"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Group lookup failed with error code: $groupInfo" -LogLevel "Error"
        
        # Display appropriate error message to user based on error code
        switch ($groupInfo)
        {
            400
            {
                Write-Host "Bad request. Please check the group name format." -ForegroundColor Red 
            }
            401
            {
                Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red 
            }
            403
            {
                Write-Host "Forbidden. You do not have permission to access groups." -ForegroundColor Red 
            }
            404
            {
                Write-Host "Group '$GroupName' not found in Entra ID." -ForegroundColor Red 
            }
        }
        
        return $returnValues.noGroupFoundInDirectoryMessage
    }
    
    # Step 2: If no exact match found, perform substring search if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $groupInfo). Performing substring search using Graph API search."
        # Clean the search term for better results
        $searchTerm = $GroupName
        Write-Verbose "[$functionName] Search term: $searchTerm"
        $searchUri = "groups"
        $filterExpression = "startswith(displayName, '$($searchTerm -replace "'", "''")')"
        Write-Verbose "[$functionName] Searching for substring matches in group properties for: $searchTerm"
        Write-Verbose "[$functionName] Trying filter: $filterExpression" 
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $groupExtraParameters
        
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            $substringSearch = $true
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            
            # Initialize filtered results array
            $filteredGroups = @()
            
            # Filter out excluded groups if needed
            foreach ($group in $fallbackResults.value)
            {
                Write-Verbose "[$functionName] Processing group: $($group.displayName) ($($group.id))"
                if ($filteredGroups.id -contains $group.id)
                {
                    Write-Verbose "[$functionName] Group $($group.id) is a duplicate, skipping."
                    continue
                }
                
                $excludeGroup = $false
                # Check if any of the exclusion patterns match this group (if configured)
                Write-Verbose "Checking against $($settings.groupPatternsToExclude.Count) patterns to exclude."
                if ($settings.groupPatternsToExclude -and $settings.groupPatternsToExclude.Count -gt 0)
                {
                    foreach ($pattern in $settings.groupPatternsToExclude)
                    {
                        Write-Verbose "[$functionName] Checking group: $($group.displayName) ($($group.id)) against exclusion pattern: $pattern"
                        if ($group.displayName.Contains($pattern) -or $group.displayName -match $pattern)
                        {
                            # If the group matches any exclusion pattern, mark them for exclusion
                            Write-Verbose "[$functionName] Group matches exclusion pattern: $pattern"
                            Write-Verbose "[$functionName] Excluding group: $($group.displayName) ($($group.id)) - Matched exclusion pattern: $pattern"
                            $excludeGroup = $true
                            break
                        }
                    }
                }
                
                # Add group to filtered results if not excluded
                if (-not $excludeGroup)
                {
                    Write-Verbose "[$functionName] Including group: $($group.displayName) ($($group.id))"
                    $filteredGroups += $group
                }
            }
            
            # Create a response object in the same format as the original Graph API response
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredGroups | Sort-Object -Property displayName -Unique)  # Force array creation
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique groups after exclusions"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            return $returnValues.noGroupFoundInDirectoryMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] No matches found for group displayName: $GroupName"
        return $returnValues.noGroupFoundInDirectoryMessage
    }
}