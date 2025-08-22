function GetGroupIdsByNames()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $AccessToken,
        [Parameter(Mandatory = $false)]
        [string[]] $GroupNames = $groupsToInclude,
        [switch] $DisplayNames
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Group names to search: $($GroupNames -join ', ')"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Group names to search: $($GroupNames -join ', ')" -LogLevel "Information"
    # Input validation
    if (-not $GroupNames -or $GroupNames.Count -eq 0)
    {
        Write-Verbose "[$functionName] No group names provided."
        Write-Log -LogFile $LogFile -Module $functionName -Message "No group names provided." -LogLevel "Warning"
        return @()
    }
    
    # Normalize inputs - remove empty/null values and trim
    Write-Verbose "[$functionName] Normalizing group names."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Normalizing group names." -LogLevel "Information"
    $inputs = @($GroupNames | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne '' })
    Write-Verbose "[$functionName] Normalized group names: $($inputs -join ', ')"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Normalized group names: $($inputs -join ', ')" -LogLevel "Information"
    if ($inputs.Count -eq 0)
    {
        Write-Verbose "[$functionName] No valid group names found after normalization."
        Write-Log -LogFile $LogFile -Module $functionName -Message "No valid group names found after normalization." -LogLevel "Warning"
        return @()
    }
    
    # Initialize session cache if needed
    Write-Verbose "[$functionName] Initializing group cache."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Initializing group cache." -LogLevel "Information"
    if (-not $script:GroupCache)
    {
        Write-Verbose "[$functionName] Group cache not found, creating new cache."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Group cache not found, creating new cache." -LogLevel "Information"
        $script:GroupCache = @{}
    }
    
    # Determine if inputs are GUIDs or names
    $guidRegex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $inputIds = @()
    $inputNames = @()
    Write-Verbose "[$functionName] Processing inputs."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing inputs." -LogLevel "Information" 
    foreach ($inputName in $inputs)
    {
        Write-Verbose "[$functionName] Processing input: $inputName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Processing input: $inputName" -LogLevel "Information"
        if ($inputName -match $guidRegex)
        {
            Write-Verbose "[$functionName] Found GUID: $inputName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found GUID: $inputName" -LogLevel "Information"
            $inputIds += $inputName.ToLower()
        }
        else
        {
            Write-Verbose "[$functionName] Found Name: $inputName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found Name: $inputName" -LogLevel "Information"
            $inputNames += $inputName
        }
    }
    
    # Determine operation mode
    Write-Verbose "[$functionName] Determining operation mode."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Determining operation mode." -LogLevel "Information"
    if ($inputIds.Count -gt 0 -and $inputNames.Count -eq 0)
    {
        Write-Verbose "[$functionName] Operation mode: IDs to Names"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: IDs to Names" -LogLevel "Information"
        $mode = "ids-to-names"
    }
    elseif ($inputNames.Count -gt 0 -and $inputIds.Count -eq 0)
    {
        Write-Verbose "[$functionName] Operation mode: Names to IDs"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: Names to IDs" -LogLevel "Information"
        $mode = "names-to-ids"
    }
    else
    {
        Write-Verbose "[$functionName] Could not determine operation mode."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Could not determine operation mode." -LogLevel "Error"
        return @()
    }
    
    $result = @()
    $needApiCall = $false
    $missingItems = @()
    
    # Check cache first
    Write-Verbose "[$functionName] Checking cache for group IDs and names."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking cache for group IDs and names." -LogLevel "Information"
    switch ($mode)
    {
        "ids-to-names"
        {
            Write-Verbose "[$functionName] Operation mode: IDs to Names"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: IDs to Names" -LogLevel "Information"
            foreach ($id in $inputIds)
            {
                Write-Verbose "[$functionName] Checking cache for ID: $id"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Checking cache for ID: $id" -LogLevel "Information"
                $cacheKey = "id:$id"
                if ($script:GroupCache.ContainsKey($cacheKey))
                {
                    Write-Verbose "[$functionName] Found ID in cache: $id"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found ID in cache: $id" -LogLevel "Information"
                    $result += $script:GroupCache[$cacheKey]
                }
                else
                {
                    Write-Verbose "[$functionName] ID not found in cache: $id"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "ID not found in cache: $id" -LogLevel "Information"
                    $needApiCall = $true
                    $missingItems += $id
                }
            }
        }
        "names-to-ids"
        {
            Write-Verbose "[$functionName] Operation mode: Names to IDs"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: Names to IDs" -LogLevel "Information"
            foreach ($name in $inputNames)
            {
                Write-Verbose "[$functionName] Checking cache for Name: $name"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Checking cache for Name: $name" -LogLevel "Information"
                $cacheKey = "name:$($name.ToLower())"
                if ($script:GroupCache.ContainsKey($cacheKey))
                {
                    Write-Verbose "[$functionName] Found Name in cache: $name"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found Name in cache: $name" -LogLevel "Information"
                    $result += $script:GroupCache[$cacheKey]
                }
                else
                {
                    Write-Verbose "[$functionName] Name not found in cache: $name"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Name not found in cache: $name" -LogLevel "Information"
                    $needApiCall = $true
                    $missingItems += $name
                }
            }
        }
    }
    
    # Make API call if needed
    Write-Verbose "[$functionName] Need API call for missing items: $($missingItems -join ', ')"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Need API call for missing items: $($missingItems -join ', ')" -LogLevel "Information"
    if ($needApiCall -and $missingItems.Count -gt 0)
    {
        try
        {
            Write-Verbose "[$functionName] Making API call for missing items"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Making API call for missing items" -LogLevel "Information"
            # Build filter for API call
            $filterConditions = @()
            $extraParams = "select=id,displayName&top=999"
            $resourceURI = "groups"
            foreach ($item in $missingItems)
            {
                Write-Verbose "[$functionName] Processing missing item: $item"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Processing missing item: $item" -LogLevel "Information"
                if ($item -match $guidRegex)
                {
                    Write-Verbose "[$functionName] Found GUID in missing items: $item"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found GUID in missing items: $item" -LogLevel "Information"
                    # For GUID types, OData filter should NOT quote the GUID
                    $filterConditions += "id eq $item"
                }
                else
                {
                    Write-Verbose "[$functionName] Found Name in missing items: $item"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found Name in missing items: $item" -LogLevel "Information"
                    # Escape single quotes in OData string literals by doubling them
                    $escapedName = $item -replace "'", "''"
                    $filterConditions += "displayName eq '$escapedName'"
                    # $filterConditions     += "startsWith(displayName,'$item')"
                }
            }
            Write-Verbose "[$functionName] Filter conditions count: $($filterConditions.Count)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filter conditions count: $($filterConditions.Count)" -LogLevel "Information"
            if ($filterConditions.Count -gt 0)
            {
                # Join conditions with OR to match any of the requested IDs or names
                $filter = $filterConditions -join ' or '
                Write-Verbose "[$functionName] Built filter for API call: $filter"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Built filter for API call: $filter" -LogLevel "Information"
                $apiResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourceURI -APIVersion 'beta' -method 'get' -Filter $filter -ExtraParameters $extraParams -consistencyLevel
                Write-Verbose "[$functionName] API response received: $($apiResponse | ConvertTo-Json -Depth $maxJsonDepth)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "API response received: $($apiResponse | ConvertTo-Json -Depth $maxJsonDepth | Out-String)" -LogLevel "Information"
                # Process API response and update cache
                if ($apiResponse -and $apiResponse.value)
                {
                    Write-Verbose "[$functionName] API response received with groups: $($apiResponse.value.Count)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "API response received with groups: $($apiResponse.value.Count)" -LogLevel "Information"
                    foreach ($group in $apiResponse.value)
                    {
                        Write-Verbose "[$functionName] Processing group: $($group.id) - $($group.displayName)"
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Processing group: $($group.id) - $($group.displayName)" -LogLevel "Information"
                        if ($group.id -and $group.displayName)
                        {
                            # Cache both directions
                            Write-Verbose "[$functionName] Caching group: $($group.id) - $($group.displayName)"
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Caching group: $($group.id) - $($group.displayName)" -LogLevel "Information"
                            $idKey = "id:$($group.id.ToLower())"
                            $nameKey = "name:$($group.displayName.ToLower())"
                            $script:GroupCache[$idKey] = $group.displayName
                            $script:GroupCache[$nameKey] = $group.id.ToLower()
                            # Add to result if it was requested
                            foreach ($item in $missingItems)
                            {
                                Write-Verbose "[$functionName] Checking item: $item"
                                Write-Log -LogFile $LogFile -Module $functionName -Message "Checking item: $item" -LogLevel "Information"
                                if ($item -match $guidRegex -and $item.ToLower() -eq $group.id.ToLower())
                                {
                                    Write-Verbose "[$functionName] Found matching item (ID): $item"
                                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found matching item (ID): $item" -LogLevel "Information"
                                    if ($mode -eq "ids-to-names" -or $mode -eq "mixed-to-names")
                                    {
                                        Write-Verbose "[$functionName] Mapping ID to Name: $item -> $($group.displayName)"
                                        Write-Log -LogFile $LogFile -Module $functionName -Message "Mapping ID to Name: $item -> $($group.displayName)" -LogLevel "Information"
                                        $result += $group.displayName
                                    }
                                }
                                elseif ($item -notmatch $guidRegex -and $item.ToLower() -eq $group.displayName.ToLower())
                                {
                                    Write-Verbose "[$functionName] Found matching item (Name): $item"
                                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found matching item (Name): $item" -LogLevel "Information"
                                    if ($mode -eq "names-to-ids" -or $mode -eq "mixed-to-ids")
                                    {
                                        Write-Verbose "[$functionName] Mapping Name to ID: $item -> $($group.id.ToLower())"
                                        Write-Log -LogFile $LogFile -Module $functionName -Message "Mapping Name to ID: $item -> $($group.id.ToLower())" -LogLevel "Information"
                                        $result += $group.id.ToLower()
                                    }
                                    elseif ($mode -eq "mixed-to-names")
                                    {
                                        Write-Verbose "[$functionName] Mapping mixed item to Name: $item -> $($group.displayName)"
                                        Write-Log -LogFile $LogFile -Module $functionName -Message "Mapping mixed item to Name: $item -> $($group.displayName)" -LogLevel "Information"
                                        $result += $group.displayName
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        catch
        {
            Write-Verbose "[$functionName] API call failed: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "API call failed: $($_.Exception.Message)" -LogLevel "Error"
        }
    }
    Write-Verbose "[$functionName] Completed processing"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Completed processing" -LogLevel "Information"
    return $result
}
