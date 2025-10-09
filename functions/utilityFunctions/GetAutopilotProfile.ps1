function GetAutopilotProfile()    
{
    <#
    .SYNOPSIS
        Gets Autopilot deployment profiles from Microsoft Graph API with search capabilities.
    
    .DESCRIPTION
        Retrieves Windows Autopilot deployment profiles from Microsoft Graph API with exact match 
        and similarity search capabilities. Supports caching and filtering similar to GetEntraGroup.
        Includes client-side case-insensitive filtering as fallback when API filters fail.
        
    .PARAMETER AccessToken
        Microsoft Graph access token with appropriate permissions.
        
    .PARAMETER ProfileName
        The display name of the Autopilot profile to search for.
        
    .PARAMETER FindSimilar
        Switch to enable similarity search if exact match is not found.
        
    .PARAMETER GetAll
        Switch to retrieve all Autopilot profiles without filtering.
        
    .OUTPUTS
        Returns a tuple: (API Response Object, Boolean indicating if substring search was used)
        
    .EXAMPLE
        $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $token -ProfileName "Corporate Profile"
        
    .EXAMPLE
        $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $token -ProfileName "Corp" -FindSimilar
        
    .EXAMPLE
        $result, $wasSubstringSearch = GetAutopilotProfile -AccessToken $token -GetAll
        
    .NOTES
        - Requires DeviceManagementServiceConfig.Read.All or higher permissions
        - Uses caching to improve performance on repeated searches
        - Implements client-side case-insensitive filtering when Graph API filters fail
        - Maintains PowerShell 5.1 compatibility
        - Uses beta endpoint for full autopilot profile features
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [string]$ProfileName,
        [switch]$FindSimilar,
        [switch]$GetAll
    )

    $functionName = $MyInvocation.MyCommand.Name
    $substringSearch = $false
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting function to get Autopilot profile from Microsoft Graph" -LogLevel "Verbose"
    
    # Handle GetAll mode - retrieve all profiles without filtering
    if ($GetAll)
    {
        Write-Verbose "[$functionName] Retrieving all Autopilot profiles"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieving all Autopilot profiles (GetAll mode)" -LogLevel "Information"
        
        # Validate access token
        if (-not $AccessToken)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken is null or empty. Cannot proceed." -LogLevel "Warning"
            Write-Warning "[$functionName] Access token is required"
            return $null, $false
        }
        
        $Uri = "deviceManagement/windowsAutopilotDeploymentProfiles"
        $ExtraParameters = "select=id,displayName,description,createdDateTime,lastModifiedDateTime"
        
        try
        {
            $Info = CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri -ExtraParameters $ExtraParameters -APIVersion 'beta'
            
            if ($Info -notin 400, 401, 403, 404 -and $Info.value)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieved $($Info.value.Count) total Autopilot profiles" -LogLevel "Information"
                Write-Verbose "[$functionName] Successfully retrieved $($Info.value.Count) profiles"
                return $Info, $false
            }
            else
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to retrieve profiles (Error code: $Info)" -LogLevel "Error"
                return $null, $false
            }
        }
        catch
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error retrieving all profiles: $($_.Exception.Message)" -LogLevel "Error"
            return $null, $false
        }
    }
    
    Write-Verbose "[$functionName] Searching for Autopilot profile: $ProfileName"
    
    # Initialize autopilot profile cache if it doesn't exist
    if (-not $global:AutopilotProfileCache)
    {
        $global:AutopilotProfileCache = @{}
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initialized Autopilot profile cache" -LogLevel "Verbose"
    }
    
    # Create cache key including FindSimilar flag for different search types
    $cacheKey = "$ProfileName|$FindSimilar"
    
    # Check cache first
    if ($global:AutopilotProfileCache.ContainsKey($cacheKey))
    {
        Write-Verbose "[$functionName] Found cached result for Autopilot profile: $ProfileName (FindSimilar: $FindSimilar)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found cached result for Autopilot profile: $ProfileName" -LogLevel "Verbose"
        return $global:AutopilotProfileCache[$cacheKey]
    }
    
    # Validate access token
    if (-not $AccessToken)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken is null or empty. Cannot proceed." -LogLevel "Warning"
        Write-Warning "[$functionName] Access token is required for Autopilot profile search"
        return $null, $false
    }

    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting exact match for Autopilot profile: $ProfileName" -LogLevel "Verbose"
    
    # Step 1: Try exact match using filter
    $Uri = "deviceManagement/windowsAutopilotDeploymentProfiles"
    $filter = "displayName eq '$ProfileName'"
    $ExtraParameters = "select=id,displayName,description,createdDateTime,lastModifiedDateTime"
    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Calling Graph API with $Uri | filter: $filter | params: $ExtraParameters" -LogLevel "Information"
    Write-Verbose "[$functionName] API Call: $Uri with filter '$filter'"
    
    try
    {
        $Info = CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri -Filter $filter -ExtraParameters $ExtraParameters -APIVersion 'beta'
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match API response received" -LogLevel "Information"
        Write-Verbose "[$functionName] Exact match API call completed"
        
        if ($Info -notin 400, 401, 403, 404 -and $Info.value -and $Info.value.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match found for Autopilot profile: $ProfileName" -LogLevel "Verbose"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Profile found: $($Info.value[0].displayName) (ID: $($Info.value[0].id))" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Found exact match: $($Info.value[0].displayName)"
            
            # Cache the result before returning
            $result = $Info, $substringSearch
            $global:AutopilotProfileCache[$cacheKey] = $result
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached result for Autopilot profile: $ProfileName" -LogLevel "Verbose"
            return $result
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error during exact match search: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error during exact match: $($_.Exception.Message)"
        $Info = 500  # Set error code for fallback logic
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($Info -in 400, 401, 403, 404, 500 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $Info"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot profile lookup failed with error code: $Info" -LogLevel "Error"
        
        # Display appropriate error message to user based on error code
        switch ($Info)
        {
            400
            {
                Write-Host "Bad request. Please check the profile name format." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Bad request. Please check the profile name format." -LogLevel "Error"
            }
            401
            {
                Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Unauthorized. Please check your access token." -LogLevel "Error"
            }
            403
            {
                Write-Host "Forbidden. You do not have permission to access Autopilot profiles." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Forbidden. You do not have permission to access Autopilot profiles." -LogLevel "Error"
            }
            404
            {
                Write-Host "Autopilot profile '$ProfileName' not found." -ForegroundColor Red 
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot profile '$ProfileName' not found." -LogLevel "Verbose"
            }
            500
            {
                Write-Host "Internal error occurred while searching for Autopilot profile." -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Internal error occurred while searching for Autopilot profile." -LogLevel "Error"
            }
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot profile '$ProfileName' not found." -LogLevel "Verbose"
        return $null, $false
    }
    
    # Step 2: If no exact match found, perform similarity search if the $FindSimilar switch is set
    if ($FindSimilar)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No exact match found (Error code: $Info). Performing similarity search." -LogLevel "Verbose"
        Write-Verbose "[$functionName] Performing similarity search for: $ProfileName"
        
        $searchTerm = $ProfileName
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using search term: $searchTerm" -LogLevel "Information"
        
        try
        {
            # Try startsWith filter first (simpler query)
            $filterExpression = "startsWith(displayName, '$searchTerm')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying basic filter: $filterExpression" -LogLevel "Information"
            Write-Verbose "[$functionName] Trying startsWith filter: $filterExpression"
            
            $fallbackResults = CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri -Filter $filterExpression -ExtraParameters $ExtraParameters -APIVersion 'beta'
            
            # If basic filter doesn't return results, try contains filter with advanced query
            if ($fallbackResults -in 400, 401, 403, 404 -or (-not $fallbackResults.value) -or $fallbackResults.value.Count -eq 0)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Basic filter returned no results. Trying advanced query with contains." -LogLevel "Information"
                Write-Verbose "[$functionName] Trying contains filter for broader search"
                
                $advancedFilterExpression = "contains(displayName, '$searchTerm')"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying advanced filter: $advancedFilterExpression" -LogLevel "Information"
                
                $advancedExtraParameters = if ($ExtraParameters)
                {
                    "$ExtraParameters&`$count=true" 
                }
                else
                {
                    "`$count=true" 
                }
                
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using advanced filter: $advancedFilterExpression" -LogLevel "Information"
                $fallbackResults = CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri -Filter $advancedFilterExpression -ExtraParameters $advancedExtraParameters -ConsistencyLevel -APIVersion 'beta'
                
                if ($fallbackResults -is [int])
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Advanced filter call returned status code: $fallbackResults" -LogLevel "Error"
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Advanced query completed with $($fallbackResults.value.Count) results" -LogLevel "Information"
                }
            }
            
            # Process similarity search results
            if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Similarity search returned $($fallbackResults.value.Count) results" -LogLevel "Information"
                Write-Verbose "[$functionName] Found $($fallbackResults.value.Count) similar profiles"
                
                $substringSearch = $true
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Proceeding to filter and deduplicate results" -LogLevel "Information"
                
                # Initialize filtered results array
                $filteredResults = @()
                
                # Filter out excluded items and deduplicate
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering and deduplicating results" -LogLevel "Information"
                $seenProfiles = @{}
                
                foreach ($item in $fallbackResults.value)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing Autopilot profile: $($item.displayName)" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Processing profile: $($item.displayName)"
                    
                    # Check if this is a duplicate (by displayName)
                    $uniqueKey = $item.displayName
                    if ($seenProfiles.ContainsKey($uniqueKey))
                    {
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot profile $($item.displayName) is a duplicate, skipping." -LogLevel "Information"
                        Write-Verbose "[$functionName] Skipping duplicate profile: $($item.displayName)"
                        continue
                    }
                    $seenProfiles[$uniqueKey] = $true
                    
                    # Add to filtered results (no exclusion patterns for autopilot profiles currently)
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Including Autopilot profile: $($item.displayName)" -LogLevel "Information"
                    $filteredResults += $item
                }
                
                # Create a response object in the same format as the original Graph API response
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating filtered response with $($filteredResults.Count) unique profiles" -LogLevel "Information"
                $filteredResponse = [PSCustomObject]@{
                    '@odata.context' = $fallbackResults.'@odata.context'
                    value            = @($filteredResults | Sort-Object -Property displayName -Unique)
                }
                
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered results to $($filteredResponse.value.Count) unique Autopilot profiles" -LogLevel "Information"
                Write-Verbose "[$functionName] Returning $($filteredResponse.value.Count) unique profiles"
                
                # Cache the similarity search result before returning
                $result = $filteredResponse, $substringSearch
                $global:AutopilotProfileCache[$cacheKey] = $result
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached similarity search result for Autopilot profile: $ProfileName" -LogLevel "Verbose"
                return $result
            }
            else        
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Similarity search failed (Error code: $fallbackResults). Attempting client-side filtering." -LogLevel "Verbose"
                Write-Verbose "[$functionName] Similarity search returned no results, trying client-side case-insensitive search"
                
                # Step 3: If API-based searches fail, retrieve ALL profiles and filter client-side
                # This works around Graph API case-sensitivity issues
                try
                {
                    Write-Verbose "[$functionName] Retrieving all Autopilot profiles for client-side filtering"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieving all Autopilot profiles for client-side case-insensitive filtering" -LogLevel "Information"
                    
                    $allProfilesResult = CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri -ExtraParameters $ExtraParameters -APIVersion 'beta'
                    
                    if ($allProfilesResult -notin 400, 401, 403, 404 -and $allProfilesResult.value -and $allProfilesResult.value.Count -gt 0)
                    {
                        Write-Verbose "[$functionName] Retrieved $($allProfilesResult.value.Count) profiles, performing client-side filtering"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieved $($allProfilesResult.value.Count) profiles for client-side filtering" -LogLevel "Information"
                        
                        # Client-side case-insensitive filtering using PowerShell
                        $searchTermLower = $searchTerm.ToLower()
                        $matchedProfiles = @()
                        
                        foreach ($profile in $allProfilesResult.value)
                        {
                            $displayNameLower = if ($profile.displayName) { $profile.displayName.ToLower() } else { "" }
                            
                            # Match if display name contains the search term (case-insensitive)
                            if ($displayNameLower.Contains($searchTermLower))
                            {
                                $matchedProfiles += $profile
                            }
                        }
                        
                        if ($matchedProfiles.Count -gt 0)
                        {
                            Write-Verbose "[$functionName] Client-side filtering found $($matchedProfiles.Count) matching profiles"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Client-side filtering found $($matchedProfiles.Count) matches" -LogLevel "Information"
                            
                            # Create filtered response
                            $clientFilteredResponse = [PSCustomObject]@{
                                '@odata.context' = $allProfilesResult.'@odata.context'
                                value            = @($matchedProfiles | Sort-Object -Property displayName -Unique)
                            }
                            
                            $substringSearch = $true
                            $result = $clientFilteredResponse, $substringSearch
                            $global:AutopilotProfileCache[$cacheKey] = $result
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached client-side filtered result" -LogLevel "Verbose"
                            return $result
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Client-side filtering found no matches for: $ProfileName" -LogLevel "Verbose"
                            Write-Verbose "[$functionName] Client-side filtering found no matches"
                            return $null, $false
                        }
                    }
                    else
                    {
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to retrieve all profiles for client-side filtering (Error code: $allProfilesResult)" -LogLevel "Error"
                        Write-Verbose "[$functionName] Failed to retrieve all profiles"
                        return $null, $false
                    }
                }
                catch
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error during client-side filtering: $($_.Exception.Message)" -LogLevel "Error"
                    Write-Verbose "[$functionName] Error during client-side filtering: $($_.Exception.Message)"
                    return $null, $false
                }
            }
        }
        catch
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error during similarity search: $($_.Exception.Message)" -LogLevel "Error"
            Write-Verbose "[$functionName] Error during similarity search: $($_.Exception.Message)"
            return $null, $false
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "FindSimilar switch was not used." -LogLevel "Information"
        Write-Verbose "[$functionName] FindSimilar not enabled, returning null"
        return $null, $false
    }
}