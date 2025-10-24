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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Group names to search: $($GroupNames -join ', ')" -LogLevel "Information"
    # Input validation
    if (-not $GroupNames -or $GroupNames.Count -eq 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No group names provided." -LogLevel "Warning"
        return @()
    }
    
    # Normalize inputs - remove empty/null values and trim
    Write-Log -LogFile $LogFile -Module $functionName -Message "Normalizing group names." -LogLevel "Information"
    $inputs = @($GroupNames | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne '' })
    Write-Log -LogFile $LogFile -Module $functionName -Message "Normalized group names: $($inputs -join ', ')" -LogLevel "Information"
    if ($inputs.Count -eq 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No valid group names found after normalization." -LogLevel "Verbose"
        return @()
    }
    
    # Determine if inputs are GUIDs or names
    $guidRegex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $inputIds = @()
    $inputNames = @()
    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing inputs." -LogLevel "Verbose" 
    foreach ($inputName in $inputs)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Processing input: $inputName" -LogLevel "Verbose"
        if ($inputName -match $guidRegex)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found GUID: $inputName" -LogLevel "Verbose"
            $inputIds += $inputName.ToLower()
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found Name: $inputName" -LogLevel "Verbose"
            $inputNames += $inputName
        }
    }
    
    # Determine operation mode
    Write-Log -LogFile $LogFile -Module $functionName -Message "Determining operation mode." -LogLevel "Information"
    if ($inputIds.Count -gt 0 -and $inputNames.Count -eq 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: IDs to Names" -LogLevel "Information"
        $mode = "ids-to-names"
    }
    elseif ($inputNames.Count -gt 0 -and $inputIds.Count -eq 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: Names to IDs" -LogLevel "Information"
        $mode = "names-to-ids"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Could not determine operation mode." -LogLevel "Error"
        return @()
    }
    
    $result = @()
    $needApiCall = $false
    $missingItems = @()
    
    # Check cache first
    Write-Log -LogFile $LogFile -Module $functionName -Message "Checking cache for group IDs and names." -LogLevel "Verbose"
    switch ($mode)
    {
        "ids-to-names"
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: IDs to Names" -LogLevel "Information"
            foreach ($id in $inputIds)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Checking cache for ID: $id" -LogLevel "Verbose"
                $cacheKey = "group:id:$id"
                $cachedName = Get-CachedData -CacheType 'DirectoryObjects' -Key $cacheKey -Settings $global:settings
                if ($null -ne $cachedName)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found ID in cache: $id" -LogLevel "Verbose"
                    $result += $cachedName
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "ID not found in cache: $id" -LogLevel "Verbose"
                    $needApiCall = $true
                    $missingItems += $id
                }
            }
        }
        "names-to-ids"
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Operation mode: Names to IDs" -LogLevel "Information"
            foreach ($name in $inputNames)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Checking cache for Name: $name" -LogLevel "Verbose"
                $cacheKey = "group:name:$($name.ToLower())"
                $cachedId = Get-CachedData -CacheType 'DirectoryObjects' -Key $cacheKey -Settings $global:settings
                if ($null -ne $cachedId)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found Name in cache: $name" -LogLevel "Verbose"
                    $result += $cachedId
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Name not found in cache: $name" -LogLevel "Verbose"
                    $needApiCall = $true
                    $missingItems += $name
                }
            }
        }
    }
    
    # Make API call if needed
    Write-Log -LogFile $LogFile -Module $functionName -Message "Need API call for missing items: $($missingItems -join ', ')" -LogLevel "Information"
    if ($needApiCall -and $missingItems.Count -gt 0)
    {
        try
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Making API call for missing items" -LogLevel "Information"
            # Build filter for API call
            $filterConditions = @()
            $extraParams = "select=id,displayName&top=999"
            $resourceURI = "groups"
            foreach ($item in $missingItems)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Processing missing item: $item" -LogLevel "Verbose"
                if ($item -match $guidRegex)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found GUID in missing items: $item" -LogLevel "Verbose"
                    # For GUID types, OData filter should NOT quote the GUID
                    # For GUID types, OData filter should quote the GUID
                    $filterConditions += "id eq '$item'"
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found Name in missing items: $item" -LogLevel "Verbose"
                    # Escape single quotes in OData string literals by doubling them
                    $escapedName = $item -replace "'", "''"
                    $filterConditions += "displayName eq '$escapedName'"
                    # $filterConditions     += "startsWith(displayName,'$item')"
                }
            }
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filter conditions count: $($filterConditions.Count)" -LogLevel "Information"
            if ($filterConditions.Count -gt 0)
            {
                # Join conditions with OR to match any of the requested IDs or names
                $filter = $filterConditions -join ' or '
                Write-Log -LogFile $LogFile -Module $functionName -Message "Built filter for API call: $filter" -LogLevel "Information"
                $apiResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $resourceURI -APIVersion 'beta' -method 'get' -Filter $filter -ExtraParameters $extraParams -consistencyLevel
                Write-Verbose "[$functionName] API response received: $($apiResponse | ConvertTo-Json -Depth $maxJsonDepth)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "API response received: $($apiResponse | ConvertTo-Json -Depth $maxJsonDepth | Out-String)" -LogLevel "Information"
                # Process API response and update cache
                if ($apiResponse -and $apiResponse.value)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "API response received with groups: $($apiResponse.value.Count)" -LogLevel "Information"
                    foreach ($group in $apiResponse.value)
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Processing group: $($group.id) - $($group.displayName)" -LogLevel "Verbose"
                        if ($group.id -and $group.displayName)
                        {
                            # Cache both directions using unified cache
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Caching group: $($group.id) - $($group.displayName)" -LogLevel "Information"
                            $idKey = "group:id:$($group.id.ToLower())"
                            $nameKey = "group:name:$($group.displayName.ToLower())"
                            
                            $metadata = @{
                                GroupId     = $group.id
                                DisplayName = $group.displayName
                            }
                            
                            # Cache ID -> Name mapping
                            Set-CachedData -CacheType 'DirectoryObjects' -Key $idKey -Data $group.displayName -Metadata $metadata -Settings $global:settings | Out-Null
                            # Cache Name -> ID mapping
                            Set-CachedData -CacheType 'DirectoryObjects' -Key $nameKey -Data $group.id.ToLower() -Metadata $metadata -Settings $global:settings | Out-Null
                            
                            # Add to result if it was requested
                            foreach ($item in $missingItems)
                            {
                                Write-Log -LogFile $LogFile -Module $functionName -Message "Checking item: $item" -LogLevel "Verbose"
                                if ($item -match $guidRegex -and $item.ToLower() -eq $group.id.ToLower())
                                {
                                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found matching item (ID): $item" -LogLevel "Verbose"
                                    if ($mode -eq "ids-to-names" -or $mode -eq "mixed-to-names")
                                    {
                                        Write-Log -LogFile $LogFile -Module $functionName -Message "Mapping ID to Name: $item -> $($group.displayName)" -LogLevel "Information"
                                        $result += $group.displayName
                                    }
                                }
                                elseif ($item -notmatch $guidRegex -and $item.ToLower() -eq $group.displayName.ToLower())
                                {
                                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found matching item (Name): $item" -LogLevel "Verbose"
                                    if ($mode -eq "names-to-ids" -or $mode -eq "mixed-to-ids")
                                    {
                                        Write-Log -LogFile $LogFile -Module $functionName -Message "Mapping Name to ID: $item -> $($group.id.ToLower())" -LogLevel "Information"
                                        $result += $group.id.ToLower()
                                    }
                                    elseif ($mode -eq "mixed-to-names")
                                    {
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
            Write-Log -LogFile $LogFile -Module $functionName -Message "API call failed: $($_.Exception.Message)" -LogLevel "Error"
        }
    }
    Write-Log -LogFile $LogFile -Module $functionName -Message "Completed processing" -LogLevel "Verbose"
    # Ensure we always return an array (even if empty or single element)
    return , @($result)
}
