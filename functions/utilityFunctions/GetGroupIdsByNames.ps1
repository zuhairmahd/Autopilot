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
    Write-Verbose "[$functionName] Retrieving group IDs for names: $($GroupNames -join ', ')"
    write-log -logFile $LogFile -module $functionName -message "Retrieving group IDs for names: $($GroupNames -join ', ')" -logLevel "Information"
    if (-not $GroupNames -or $GroupNames.Count -eq 0)
    {
        Write-Verbose "[$functionName] No group identifiers provided. Returning empty array."
        write-log -logFile $LogFile -module $functionName -message "No group identifiers provided. Returning empty array." -logLevel "Information"
        return @()
    }

    # Normalize inputs
    Write-Verbose "[$functionName] Normalizing group names."
    write-log -logFile $LogFile -module $functionName -message "Normalizing group names." -logLevel "Information"
    $inputs = @($GroupNames | Where-Object { $_ } | ForEach-Object { ("$_").Trim() } | Where-Object { $_ -ne '' })
    Write-Verbose "[$functionName] Normalized $($inputs.Count) inputs: $($inputs -join ', ')"
    write-log -logFile $LogFile -module $functionName -message "Normalized $($inputs.Count) inputs: $($inputs -join ', ')" -logLevel "Information"
    if ($inputs.Count -eq 0) 
    { 
        Write-Verbose "[$functionName] No valid group identifiers after normalization. Returning empty array."
        write-log -logFile $LogFile -module $functionName -message "No valid group identifiers after normalization. Returning empty array." -logLevel "Information"
        return @() 
    }
    # Partition into IDs vs names
    Write-Verbose "[$functionName] Partitioning inputs into IDs and names."
    write-log -logFile $LogFile -module $functionName -message "Partitioning inputs into IDs and names." -logLevel "Information"
    $guidRegex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $inputIds = @()
    $inputNames = @()
    foreach ($v in $inputs)
    {
        Write-Verbose "[$functionName] Processing input: $v"
        write-log -logFile $LogFile -module $functionName -message "Processing input: $v" -logLevel "Information"
        if ($v -match $guidRegex) 
        { 
            Write-Verbose "[$functionName] Detected GUID: $v"
            write-log -logFile $LogFile -module $functionName -message "Detected GUID: $v" -logLevel "Information"
            $inputIds += $v.ToLower() 
        } 
        else 
        { 
            Write-Verbose "[$functionName] Detected name: $v"
            write-log -logFile $LogFile -module $functionName -message "Detected name: $v" -logLevel "Information"
            $inputNames += $v 
        }
    }

    # Determine mode (default behavior): IDs in -> names out, Names in -> IDs out
    Write-Verbose "[$functionName] Determining input mode based on provided identifiers."
    write-log -logFile $LogFile -module $functionName -message "Determining input mode based on provided identifiers." -logLevel "Information"
    $mode = if ($inputNames.Count -eq 0 -and $inputIds.Count -gt 0)
    {
        'ids-input' 
    }
    else
    {
        'names-input' 
    }
    Write-Verbose "[$functionName] Input mode determined as: $mode"
    write-log -logFile $LogFile -module $functionName -message "Input mode determined as: $mode" -logLevel "Information"
    # Initialize caches/indexes
    Write-Verbose "[$functionName] Initializing group response cache and indexes."
    write-log -logFile $LogFile -module $functionName -message "Initializing group response cache and indexes." -logLevel "Information"
    if (-not $script:GroupResponseCache) 
    { 
        Write-Verbose "[$functionName] Creating new group response cache."
        write-log -logFile $LogFile -module $functionName -message "Creating new group response cache." -logLevel "Information"
        $script:GroupResponseCache = @{} 
    }
    if (-not $script:GroupNameIdIndex) 
    { 
        Write-Verbose "[$functionName] Creating new group name-to-ID index."
        write-log -logFile $LogFile -module $functionName -message "Creating new group name-to-ID index." -logLevel "Information"
        $script:GroupNameIdIndex = @{} 
    }  
    if (-not $script:GroupIdNameIndex) 
    { 
        Write-Verbose "[$functionName] Creating new group ID-to-name index."
        write-log -logFile $LogFile -module $functionName -message "Creating new group ID-to-name index." -logLevel "Information"
        $script:GroupIdNameIndex = @{} 
    }  # key: lower(id) -> displayName
    
    # Helper: try satisfy from indexes
    function Resolve-FromIndex
    {
        param(
            [string[]] $Names,
            [string[]] $Ids
        )
        $functionName = $myInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Resolving group IDs and names from indexes."
        write-log -logFile $LogFile -module $functionName -message "Resolving group IDs and names from indexes." -logLevel "Information"
        $resolvedIds = @()
        $missingNames = @()
        foreach ($n in @($Names))
        {
            Write-Verbose "[$functionName] Checking name: $n"
            write-log -logFile $LogFile -module $functionName -message "Checking name: $n" -logLevel "Information"
            $key = $n.ToLower()
            if ($script:GroupNameIdIndex.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Found ID for name '$n': $($script:GroupNameIdIndex[$key])"
                write-log -logFile $LogFile -module $functionName -message "Found ID for name '$n': $($script:GroupNameIdIndex[$key])" -logLevel "Information"
                $resolvedIds += $script:GroupNameIdIndex[$key] 
            }
            else
            {
                Write-Verbose "[$functionName] No ID found for name '$n'."
                write-log -logFile $LogFile -module $functionName -message "No ID found for name '$n'." -logLevel "Warning"
                $missingNames += $n 
            }
        }
        $resolvedNames = @()
        $missingIds = @()
        foreach ($i in @($Ids))
        {
            Write-Verbose "[$functionName] Checking ID: $i"
            write-log -logFile $LogFile -module $functionName -message "Checking ID: $i" -logLevel "Information"
            $key = $i.ToLower()
            if ($script:GroupIdNameIndex.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Found name for ID '$i': $($script:GroupIdNameIndex[$key])"
                write-log -logFile $LogFile -module $functionName -message "Found name for ID '$i': $($script:GroupIdNameIndex[$key])" -logLevel "Information"
                $resolvedNames += $script:GroupIdNameIndex[$key] 
            }
            else
            {
                Write-Verbose "[$functionName] No name found for ID '$i'."
                write-log -logFile $LogFile -module $functionName -message "No name found for ID '$i'." -logLevel "Warning"
                $missingIds += $i 
            }
        }
        Write-Verbose "[$functionName] Resolved IDs: $($resolvedIds -join ', '), Missing Names: $($missingNames -join ', '), Resolved Names: $($resolvedNames -join ', '), Missing IDs: $($missingIds -join ', ')"
        write-log -logFile $LogFile -module $functionName -message "Resolved IDs: $($resolvedIds -join ', '), Missing Names: $($missingNames -join ', '), Resolved Names: $($resolvedNames -join ', '), Missing IDs: $($missingIds -join ', ')" -logLevel "Information"
        return @{ ResolvedIds = $resolvedIds; MissingNames = $missingNames; ResolvedNames = $resolvedNames; MissingIds = $missingIds }
    }

    $ix = Resolve-FromIndex -Names $inputNames -Ids $inputIds
    Write-Verbose "[$functionName] Index resolution summary — ResolvedIds: $($ix.ResolvedIds.Count), MissingNames: $($ix.MissingNames.Count), ResolvedNames: $($ix.ResolvedNames.Count), MissingIds: $($ix.MissingIds.Count)"
    write-log -logFile $LogFile -module $functionName -message "Index resolution summary — ResolvedIds: $($ix.ResolvedIds.Count), MissingNames: $($ix.MissingNames.Count), ResolvedNames: $($ix.ResolvedNames.Count), MissingIds: $($ix.MissingIds.Count)" -logLevel "Information"
    # Attempt to use cached API response for identical input sets
    $resp = $null
    $usedCache = $false
    $namesCacheKey = if ($inputNames.Count -gt 0)
    {
        Write-Verbose "[$functionName] Creating names cache key."
        write-log -logFile $LogFile -module $functionName -message "Creating names cache key." -logLevel "Information"
        "groups|names|" + (($inputNames | ForEach-Object { ("$_").ToLower() } | Sort-Object) -join '|') 
    }
    else
    {
        Write-Verbose "[$functionName] No names provided, skipping names cache key."
        write-log -logFile $LogFile -module $functionName -message "No names provided, skipping names cache key." -logLevel "Information"
        $null 
    }
    $idsCacheKey = if ($inputIds.Count -gt 0)
    {
        Write-Verbose "[$functionName] Creating IDs cache key."
        write-log -logFile $LogFile -module $functionName -message "Creating IDs cache key." -logLevel "Information"
        "groups|ids|" + (($inputIds | ForEach-Object { ("$_").ToLower() } | Sort-Object) -join '|') 
    }
    else
    {
        Write-Verbose "[$functionName] No IDs provided, skipping IDs cache key."
        write-log -logFile $LogFile -module $functionName -message "No IDs provided, skipping IDs cache key." -logLevel "Information"
        $null 
    }
    
    if ($mode -eq 'ids-input' -and $idsCacheKey -and $script:GroupResponseCache.ContainsKey($idsCacheKey))
    {
        Write-Verbose "[$functionName] Using cached API response for IDs key: $idsCacheKey"
        write-log -logFile $LogFile -module $functionName -message "Using cached API response for IDs key: $idsCacheKey" -logLevel "Information"
        $resp = $script:GroupResponseCache[$idsCacheKey]
        $usedCache = $true
    }
    elseif ($mode -eq 'names-input' -and $namesCacheKey -and $script:GroupResponseCache.ContainsKey($namesCacheKey))
    {
        Write-Verbose "[$functionName] Using cached API response for names key: $namesCacheKey"
        write-log -logFile $LogFile -module $functionName -message "Using cached API response for names key: $namesCacheKey" -logLevel "Information"
        $resp = $script:GroupResponseCache[$namesCacheKey]
        $usedCache = $true
    }

    if ($resp)
    {
        $cachedItems = if ($resp -and $resp.PSObject.Properties.Match('value').Count -gt 0)
        {
            @($resp.value).Count 
        }
        elseif ($resp)
        {
            1 
        }
        else
        {
            0 
        }
        Write-Verbose "[$functionName] Cached response contains $cachedItems item(s)."
        write-log -logFile $LogFile -module $functionName -message "Cached response contains $cachedItems item(s)." -logLevel "Information"
    }

    # Decide if we need to call the API (only once)
    $needCall = $false
    $conditions = @()
    if (-not $resp)
    {
        Write-Verbose "[$functionName] No cached response found, preparing API call."
        write-log -logFile $LogFile -module $functionName -message "No cached response found, preparing API call." -logLevel "Information"
        if ($ix.MissingNames.Count -gt 0)
        {
            # Escape single quotes for OData
            Write-Verbose "[$functionName] Missing names detected: $($ix.MissingNames -join ', ')"
            write-log -logFile $LogFile -module $functionName -message "Missing names detected: $($ix.MissingNames -join ', ')" -logLevel "Information"
            $escaped = $ix.MissingNames | ForEach-Object { ("$_").Trim().Replace("'", "''") }
            $conditions += ($escaped | ForEach-Object { "displayName eq '$_'" })
        }
        if ($ix.MissingIds.Count -gt 0)
        {
            Write-Verbose "[$functionName] Missing IDs detected: $($ix.MissingIds -join ', ')"
            write-log -logFile $LogFile -module $functionName -message "Missing IDs detected: $($ix.MissingIds -join ', ')" -logLevel "Information"
            $conditions += ($ix.MissingIds | ForEach-Object { "id eq '$_'" })
        }
        $needCall = ($conditions.Count -gt 0)
    }

    if (-not $needCall)
    {
        if ($resp -and $usedCache)
        {
            Write-Verbose "[$functionName] API call not needed; using cached data."
            write-log -logFile $LogFile -module $functionName -message "API call not needed; using cached data." -logLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] API call not needed; all requested mappings satisfied by index."
            write-log -logFile $LogFile -module $functionName -message "API call not needed; all requested mappings satisfied by index." -logLevel "Information"
        }
    }

    if ($needCall)
    {
        Write-Verbose "[$functionName] Conditions for API call: $($conditions -join ' or ')"
        write-log -logFile $LogFile -module $functionName -message "Conditions for API call: $($conditions -join ' or ')" -logLevel "Information"
        $filter = ($conditions -join ' or ')
        $extra = 'select=id,displayName'
        Write-Verbose "[$functionName] Calling the API with filter: $filter and extra parameters: $extra"
        write-log -logFile $LogFile -module $functionName -message "Calling the API with filter: $filter and extra parameters: $extra" -logLevel "Information"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try
        {
            if (-not $AccessToken)
            {
                Write-Verbose "[$functionName] No AccessToken provided; relying on default authentication in CallGraphAPI."
                write-log -logFile $LogFile -module $functionName -message "No AccessToken provided; relying on default authentication in CallGraphAPI." -logLevel "Warning"
            }
            $resp = CallGraphAPI -accessToken $AccessToken -ResourcePath 'groups' -APIVersion 'beta' -method 'get' -Filter $filter -ExtraParameters $extra -consistencyLevel
            $script:LastGroupResponse = $resp
            $sw.Stop()
            Write-Verbose "[$functionName] API call completed in $($sw.ElapsedMilliseconds) ms."
            write-log -logFile $LogFile -module $functionName -message "API call completed in $($sw.ElapsedMilliseconds) ms." -logLevel "Information"
        }
        catch
        {
            $sw.Stop()
            Write-Verbose "[$functionName] API call failed after $($sw.ElapsedMilliseconds) ms: $($_.Exception.Message)"
            write-log -logFile $LogFile -module $functionName -message "API call failed: $($_.Exception.Message)" -logLevel "Error"
            # Keep $resp as $null so downstream logic can continue with whatever was resolved via index
        }
        # Update caches and indexes
        $items = if ($resp -and $resp.PSObject.Properties.Match('value').Count -gt 0)
        {
            Write-Verbose "[$functionName] API response contains 'value' property."
            write-log -logFile $LogFile -module $functionName -message "API response contains 'value' property." -logLevel "Information"
            $resp.value 
        }
        else
        {
            Write-Verbose "[$functionName] API response does not contain 'value' property, using raw response."
            write-log -logFile $LogFile -module $functionName -message "API response does not contain 'value' property, using raw response." -logLevel "Warning"
            $resp 
        }
        $itemCount = @($items).Count
        Write-Verbose "[$functionName] Processing $itemCount group item(s) from API response."
        write-log -logFile $LogFile -module $functionName -message "Processing $itemCount group item(s) from API response." -logLevel "Information"
        foreach ($it in @($items))
        {
            Write-Verbose "[$functionName] Processing group item: $($it.displayName) with ID: $($it.id)"
            write-log -logFile $LogFile -module $functionName -message "Processing group item: $($it.displayName) with ID: $($it.id)" -logLevel "Information"
            if ($it)
            {
                Write-Verbose "[$functionName] Adding group to indexes: Name='$($it.displayName)', ID='$($it.id)'"
                write-log -logFile $LogFile -module $functionName -message "Adding group to indexes: Name='$($it.displayName)', ID='$($it.id)'" -logLevel "Information"
                if ($it.displayName)
                {
                    $script:GroupNameIdIndex[$it.displayName.ToLower()] = $it.id 
                }
                if ($it.id)
                {
                    $script:GroupIdNameIndex[$it.id.ToLower()] = $it.displayName 
                }
            }
        }
        if ($namesCacheKey)
        {
            Write-Verbose "[$functionName] Caching API response for names key: $namesCacheKey"
            write-log -logFile $LogFile -module $functionName -message "Caching API response for names key: $namesCacheKey" -logLevel "Information"
            $script:GroupResponseCache[$namesCacheKey] = $resp 
        }
        if ($idsCacheKey)
        {
            Write-Verbose "[$functionName] Caching API response for IDs key: $idsCacheKey"
            write-log -logFile $LogFile -module $functionName -message "Caching API response for IDs key: $idsCacheKey" -logLevel "Information"
            $script:GroupResponseCache[$idsCacheKey] = $resp 
        }
    }
    # Produce output
    if ($DisplayNames.IsPresent)
    {
        Write-Verbose "[$functionName] Display names requested, returning all display names."
        write-log -logFile $LogFile -module $functionName -message "Display names requested, returning all display names." -logLevel "Information"
        # Always return display names when requested
        $result = @()
        foreach ($i in @($inputIds))
        {
            $key = $i.ToLower()
            if ($script:GroupIdNameIndex.ContainsKey($key))
            {
                $val = $script:GroupIdNameIndex[$key]
                Write-Verbose "[$functionName] Resolved display name for ID '$i' => '$val'"
                write-log -logFile $LogFile -module $functionName -message "Resolved display name for ID '$i' => '$val'" -logLevel "Information"
                $result += $val 
            }
            else
            {
                Write-Verbose "[$functionName] No display name found for ID '$i'"
                write-log -logFile $LogFile -module $functionName -message "No display name found for ID '$i'" -logLevel "Warning"
            }
        }
        foreach ($n in @($inputNames))
        {
            # Prefer canonical name from index if available; otherwise echo input
            $key = $n.ToLower()
            if ($script:GroupNameIdIndex.ContainsKey($key))
            {
                # If we have an ID, and also have Name in the reverse index, use that; else keep original
                $id = $script:GroupNameIdIndex[$key]
                if ($id -and $script:GroupIdNameIndex.ContainsKey($id.ToLower()))
                {
                    $canonical = $script:GroupIdNameIndex[$id.ToLower()]
                    Write-Verbose "[$functionName] Using canonical display name for '$n' => '$canonical'"
                    write-log -logFile $LogFile -module $functionName -message "Using canonical display name for '$n' => '$canonical'" -logLevel "Information"
                    $result += $canonical 
                }
                else
                {
                    Write-Verbose "[$functionName] ID found for '$n' but reverse lookup missing; using original value."
                    write-log -logFile $LogFile -module $functionName -message "ID found for '$n' but reverse lookup missing; using original value." -logLevel "Warning"
                    $result += $n 
                }
            }
            else
            {
                Write-Verbose "[$functionName] Name '$n' not found in index; echoing input."
                write-log -logFile $LogFile -module $functionName -message "Name '$n' not found in index; echoing input." -logLevel "Warning"
                $result += $n 
            }
        }
        Write-Verbose "[$functionName] Returning $($result.Count) display name(s)."
        write-log -logFile $LogFile -module $functionName -message "Returning $($result.Count) display name(s)." -logLevel "Information"
        return $result
    }
    elseif ($mode -eq 'ids-input')
    {
        Write-Verbose "[$functionName] IDs provided; returning corresponding display names."
        write-log -logFile $LogFile -module $functionName -message "IDs provided; returning corresponding display names." -logLevel "Information"
        # Default for ID inputs: return names
        $result = @()
        foreach ($i in @($inputIds))
        {
            $key = $i.ToLower()
            if ($script:GroupIdNameIndex.ContainsKey($key))
            {
                $name = $script:GroupIdNameIndex[$key]
                Write-Verbose "[$functionName] ID '$i' => Name '$name'"
                write-log -logFile $LogFile -module $functionName -message "ID '$i' => Name '$name'" -logLevel "Information"
                $result += $name 
            }
            else
            {
                Write-Verbose "[$functionName] No name found for ID '$i'"
                write-log -logFile $LogFile -module $functionName -message "No name found for ID '$i'" -logLevel "Warning"
            }
        }
        Write-Verbose "[$functionName] Returning $($result.Count) name(s) for provided ID(s)."
        write-log -logFile $LogFile -module $functionName -message "Returning $($result.Count) name(s) for provided ID(s)." -logLevel "Information"
        return $result
    }
    else
    {
        Write-Verbose "[$functionName] Names provided; returning corresponding IDs."
        write-log -logFile $LogFile -module $functionName -message "Names provided; returning corresponding IDs." -logLevel "Information"
        # Default for name inputs: return IDs
        $result = @()
        foreach ($n in @($inputNames))
        {
            $key = $n.ToLower()
            if ($script:GroupNameIdIndex.ContainsKey($key))
            {
                $id = $script:GroupNameIdIndex[$key]
                Write-Verbose "[$functionName] Name '$n' => ID '$id'"
                write-log -logFile $LogFile -module $functionName -message "Name '$n' => ID '$id'" -logLevel "Information"
                $result += $id 
            }
            else
            {
                Write-Verbose "[$functionName] No ID found for name '$n'"
                write-log -logFile $LogFile -module $functionName -message "No ID found for name '$n'" -logLevel "Warning"
            }
        }
        Write-Verbose "[$functionName] Returning $($result.Count) ID(s) for provided name(s)."
        write-log -logFile $LogFile -module $functionName -message "Returning $($result.Count) ID(s) for provided name(s)." -logLevel "Information"
        return $result
    }
}
