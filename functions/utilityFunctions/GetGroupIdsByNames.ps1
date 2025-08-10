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
    
    # Input validation
    if (-not $GroupNames -or $GroupNames.Count -eq 0) {
        return @()
    }
    
    # Normalize inputs - remove empty/null values and trim
    $inputs = @($GroupNames | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne '' })
    if ($inputs.Count -eq 0) {
        return @()
    }
    
    # Initialize session cache if needed
    if (-not $script:GroupCache) {
        $script:GroupCache = @{}
    }
    
    # Determine if inputs are GUIDs or names
    $guidRegex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $inputIds = @()
    $inputNames = @()
    
    foreach ($input in $inputs) {
        if ($input -match $guidRegex) {
            $inputIds += $input.ToLower()
        } else {
            $inputNames += $input
        }
    }
    
    # Determine operation mode
    if ($inputIds.Count -gt 0 -and $inputNames.Count -eq 0) {
        $mode = "ids-to-names"
    } elseif ($inputNames.Count -gt 0 -and $inputIds.Count -eq 0) {
        $mode = "names-to-ids"
    } else {
        # Mixed input - handle both but return based on DisplayNames switch
        $mode = if ($DisplayNames.IsPresent) { "mixed-to-names" } else { "mixed-to-ids" }
    }
    
    $result = @()
    $needApiCall = $false
    $missingItems = @()
    
    # Check cache first
    switch ($mode) {
        "ids-to-names" {
            foreach ($id in $inputIds) {
                $cacheKey = "id:$id"
                if ($script:GroupCache.ContainsKey($cacheKey)) {
                    $result += $script:GroupCache[$cacheKey]
                } else {
                    $needApiCall = $true
                    $missingItems += $id
                }
            }
        }
        "names-to-ids" {
            foreach ($name in $inputNames) {
                $cacheKey = "name:$($name.ToLower())"
                if ($script:GroupCache.ContainsKey($cacheKey)) {
                    $result += $script:GroupCache[$cacheKey]
                } else {
                    $needApiCall = $true
                    $missingItems += $name
                }
            }
        }
        "mixed-to-names" {
            foreach ($id in $inputIds) {
                $cacheKey = "id:$id"
                if ($script:GroupCache.ContainsKey($cacheKey)) {
                    $result += $script:GroupCache[$cacheKey]
                } else {
                    $needApiCall = $true
                    $missingItems += $id
                }
            }
            foreach ($name in $inputNames) {
                $nameCacheKey = "name:$($name.ToLower())"
                if ($script:GroupCache.ContainsKey($nameCacheKey)) {
                    # Get the ID from cache, then get the name
                    $cachedId = $script:GroupCache[$nameCacheKey]
                    $idCacheKey = "id:$cachedId"
                    if ($script:GroupCache.ContainsKey($idCacheKey)) {
                        $result += $script:GroupCache[$idCacheKey]
                    } else {
                        $result += $name  # Fallback to original name
                    }
                } else {
                    $needApiCall = $true
                    $missingItems += $name
                }
            }
        }
        "mixed-to-ids" {
            foreach ($id in $inputIds) {
                $result += $id  # IDs stay as IDs
            }
            foreach ($name in $inputNames) {
                $cacheKey = "name:$($name.ToLower())"
                if ($script:GroupCache.ContainsKey($cacheKey)) {
                    $result += $script:GroupCache[$cacheKey]
                } else {
                    $needApiCall = $true
                    $missingItems += $name
                }
            }
        }
    }
    
    # Make API call if needed
    if ($needApiCall -and $missingItems.Count -gt 0) {
        try {
            # Build filter for API call
            $filterConditions = @()
            
            foreach ($item in $missingItems) {
                if ($item -match $guidRegex) {
                    $filterConditions += "id eq '$item'"
                } else {
                    $escapedName = $item.Replace("'", "''")
                    $filterConditions += "displayName eq '$escapedName'"
                }
            }
            
            if ($filterConditions.Count -gt 0) {
                $filter = $filterConditions -join ' or '
                $extraParams = 'select=id,displayName'
                
                $apiResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath 'groups' -APIVersion 'beta' -method 'get' -Filter $filter -ExtraParameters $extraParams -consistencyLevel
                
                # Process API response and update cache
                if ($apiResponse -and $apiResponse.value) {
                    foreach ($group in $apiResponse.value) {
                        if ($group.id -and $group.displayName) {
                            # Cache both directions
                            $idKey = "id:$($group.id.ToLower())"
                            $nameKey = "name:$($group.displayName.ToLower())"
                            
                            $script:GroupCache[$idKey] = $group.displayName
                            $script:GroupCache[$nameKey] = $group.id.ToLower()
                            
                            # Add to result if it was requested
                            foreach ($item in $missingItems) {
                                if ($item -match $guidRegex -and $item.ToLower() -eq $group.id.ToLower()) {
                                    if ($mode -eq "ids-to-names" -or $mode -eq "mixed-to-names") {
                                        $result += $group.displayName
                                    }
                                } elseif ($item -notmatch $guidRegex -and $item.ToLower() -eq $group.displayName.ToLower()) {
                                    if ($mode -eq "names-to-ids" -or $mode -eq "mixed-to-ids") {
                                        $result += $group.id.ToLower()
                                    } elseif ($mode -eq "mixed-to-names") {
                                        $result += $group.displayName
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "[$functionName] API call failed: $($_.Exception.Message)"
        }
    }
    
    return $result
}
