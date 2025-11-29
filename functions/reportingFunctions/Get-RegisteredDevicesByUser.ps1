function Get-RegisteredDevicesByUser()
{
    <#
    .SYNOPSIS
    Retrieves registered devices for specified users with optional filtering and caching.

    .DESCRIPTION
    Queries Microsoft Graph API to get registered devices for a list of users.
    Supports filtering by operating system and device name pattern.
    
    Uses the unified cache management system to cache device results per user,
    significantly improving performance for repeated queries. Cache keys include
    the operating system filter and device name prefix to ensure correct results.
    
    When caching is enabled, the function:
    - Checks cache first for each user before making API calls
    - Returns cached results immediately if all users are cached
    - Only queries the API for users not found in cache
    - Caches results after successful API queries
    - Handles mixed cache hits/misses efficiently

    .PARAMETER usersList
    Array of user principal names or user IDs to query.

    .PARAMETER accessToken
    Microsoft Graph API access token for authentication.

    .OUTPUTS
    Array of custom objects containing user and device information.

    .EXAMPLE
    $devices = Get-RegisteredDevicesByUser -usersList @('user1@domain.com', 'user2@domain.com') -accessToken $token

    .NOTES
    Compatible with PowerShell 5.1.
    Uses DirectoryObjects cache type with automatic expiration.
    Cache behavior controlled by global $cacheSettings configuration.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]$usersList,
        [Parameter(Mandatory = $true)]
        [string]$accessToken
    )

    # Private helper function to process and filter devices
    function ConvertTo-FilteredDeviceObject()
    {
        [CmdletBinding()                                    ]
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [object[]]$Devices,
            [Parameter(Mandatory = $true)]
            [string]$UserName,
            [string]$OperatingSystemFilter,
            [string]$DeviceNameFilter
        )

        $filteredResults = @()
        
        # Handle null or empty device array
        if ($null -eq $Devices -or $Devices.Count -eq 0)
        {
            return $filteredResults
        }
        
        foreach ($device in $Devices)
        {
            # Skip if device is null or empty
            if ($null -eq $device -or $device.IsManaged -eq $false -or $device -is [int]) { continue }
            # Apply client-side filtering (since registeredDevices endpoint doesn't support $filter)
            $includeDevice = $true
            # Filter by operating system if specified
            if (-not [string]::IsNullOrEmpty($OperatingSystemFilter))
            {
                if ($device.operatingSystem -ne $OperatingSystemFilter)
                {
                    $includeDevice = $false
                }
            }
            
            # Filter by device name pattern if specified
            if ($includeDevice -and -not [string]::IsNullOrEmpty($DeviceNameFilter))
            {
                if ($device.displayName -notlike "$DeviceNameFilter*")
                {
                    $includeDevice = $false
                }
            }
            
            # Only add device if it passes all filters
            if ($includeDevice)
            {
                # Format dates using FormatDateWithTimeZone for consistent display
                $formattedRegistrationDate = if ($device.registrationDateTime) { FormatDateWithTimeZone -DateTime $device.registrationDateTime } else { "N/A" }
                $formattedLastSignIn = if ($device.approximateLastSignInDateTime) { FormatDateWithTimeZone -DateTime $device.approximateLastSignInDateTime } else { "N/A" }
                
                $filteredResults += [PSCustomObject]@{
                    UserName                      = $UserName
                    DeviceId                      = $device.id
                    DisplayName                   = $device.displayName
                    Manufacturer                  = $device.manufacturer
                    Model                         = $device.model
                    OperatingSystem               = $device.operatingSystem
                    OperatingSystemVersion        = $device.operatingSystemVersion
                    AccountEnabled                = $device.accountEnabled
                    ApproximateLastSignInDateTime = $formattedLastSignIn
                    DeviceTrustType               = $device.trustType
                    IsCompliant                   = $device.isCompliant
                    IsManaged                     = $device.isManaged
                    DeviceOwnership               = $device.deviceOwnership
                    EnrollmentType                = $device.enrollmentType
                    RegistrationDateTime          = $formattedRegistrationDate
                }
            }
        }
        return $filteredResults
    }

    $functionName = $MyInvocation.MyCommand.Name
    $operatingSystem = $global:settings.operatingSystem
    $deviceNameFilter = $global:settings.deviceNamePrefix
    Write-Verbose "[$functionName] Starting device query for $($usersList.Count) user(s)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting device query for $($usersList.Count) user(s)" -LogLevel "Information"

    # Build resource paths for batch processing, checking cache first
    $resourcePaths = @()
    $cachedResults = @()
    $usersToQuery = @()
    
    foreach ($user in $usersList)
    {
        $userTrimmed = $user.Trim()
        if (-not [string]::IsNullOrEmpty($userTrimmed))
        {
            # Create cache key for this user's registered devices
            $cacheKey = "registeredDevices:${userTrimmed}:OS=${operatingSystem}:Prefix=${deviceNameFilter}"
            
            # Check unified cache
            $cachedDevices = Get-CachedData -CacheType 'DirectoryObjects' -Key $cacheKey -CacheSettings $global:cacheSettings
            
            # Check if we have cached data (including empty arrays)
            if ($null -ne $cachedDevices)
            {
                Write-Verbose "[$functionName] Cache hit for user: $userTrimmed ($($cachedDevices.Count) devices)"
                Write-Log -LogFile $logFile -Module $functionName -Message "Using cached devices for user: $userTrimmed" -LogLevel "Debug"
                if ($cachedDevices) { $cachedResults += $cachedDevices }
            }
            else
            {
                # Cache miss - add to query list
                Write-Verbose "[$functionName] Cache miss for user: $userTrimmed - will query API"
                $resourcePaths += "users/$userTrimmed/registeredDevices"
                $usersToQuery += $userTrimmed
                Write-Verbose "[$functionName] Added resource path for user: $userTrimmed"
            }
        }
    }

    # If all users were cached, return cached results immediately
    if ($resourcePaths.Count -eq 0)
    {
        Write-Verbose "[$functionName] All users found in cache ($($cachedResults.Count) devices)"
        Write-Log -LogFile $logFile -Module $functionName -Message "All users found in cache, returning $($cachedResults.Count) cached devices" -LogLevel "Information"
        return $cachedResults
    }
    
    Write-Verbose "[$functionName] Cache hits: $($cachedResults.Count) devices, API queries needed: $($resourcePaths.Count) user(s)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Cache hits: $($cachedResults.Count) devices, querying API for $($resourcePaths.Count) remaining user(s)" -LogLevel "Information"

    # Note: The /registeredDevices endpoint does NOT support OData $filter queries
    # We must retrieve all devices and filter client-side
    Write-Verbose "[$functionName] Operating system filter: $operatingSystem"
    Write-Verbose "[$functionName] Device name filter: $deviceNameFilter"
    Write-Log -LogFile $logFile -Module $functionName -Message "OS filter: $operatingSystem, Device name filter: $deviceNameFilter (client-side filtering will be applied)" -LogLevel "Information"

    # Call Graph API with batch processing (NO filter parameter - not supported by registeredDevices endpoint)
    Write-Verbose "[$functionName] Calling Graph API for $($resourcePaths.Count) resource path(s)"
    $response = CallGraphAPI -accessToken $accessToken -ResourcePath $resourcePaths

    if ($null -eq $response)
    {
        Write-Warning "[$functionName] No response received from Graph API"
        Write-Log -LogFile $logFile -Module $functionName -Message "No response received from Graph API" -LogLevel "Warning"
        # Return cached results if any, otherwise empty array
        if ($cachedResults.Count -gt 0)
        {
            Write-Verbose "[$functionName] API call failed, returning $($cachedResults.Count) cached devices"
            return $cachedResults
        }
        return @()
    }

    # Process the response - start with cached results
    $results = @()
    if ($cachedResults.Count -gt 0)
    {
        $results += $cachedResults
        Write-Verbose "[$functionName] Starting with $($cachedResults.Count) cached device(s)"
    }
    
    # Handle batch response
    if ($response.batchProcessed -eq $true)
    {
        Write-Verbose "[$functionName] Processing batch response: $($response.successCount) successful, $($response.failureCount) failed"
        Write-Log -LogFile $logFile -Module $functionName -Message "Batch response: $($response.successCount) successful, $($response.failureCount) failed" -LogLevel "Information"
        
        foreach ($batchItem in $response.value)
        {
            # Extract user from the request id (maps to original resource path)
            $requestId = $batchItem.id
            $userPath = if ($requestId -and $requestId -le $resourcePaths.Count) 
            { 
                $resourcePaths[$requestId - 1] 
            } 
            else 
            { 
                "Unknown" 
            }
            
            $userName = if ($userPath -match 'users/([^/]+)/') { $Matches[1] } else { "Unknown" }
            
            # Check if the batch item was successful
            if ($batchItem.status -ge 200 -and $batchItem.status -lt 300)
            {
                # Extract devices from the batch response body
                $devices = if ($batchItem.body.value) { $batchItem.body.value } else { @() }
                
                # Handle empty device array
                if ($null -eq $devices -or $devices.Count -eq 0)
                {
                    Write-Verbose "[$functionName] No devices found for user: $userName"
                    # Cache empty result to avoid repeated queries
                    $cacheKey = "registeredDevices:${userName}:OS=${operatingSystem}:Prefix=${deviceNameFilter}"
                    $metadata = @{
                        UserName     = $userName
                        OS           = $operatingSystem
                        DevicePrefix = $deviceNameFilter
                        DeviceCount  = 0
                    }
                    Set-CachedData -CacheType 'DirectoryObjects' -Key $cacheKey -Data @() -Metadata $metadata -CacheSettings $global:cacheSettings | Out-Null
                    continue
                }
                
                # Process devices using helper function
                $filteredDevices = ConvertTo-FilteredDeviceObject -Devices $devices -UserName $userName -OperatingSystemFilter $operatingSystem -DeviceNameFilter $deviceNameFilter
                if ($null -eq $filteredDevices) { $filteredDevices = @() }
                $results += $filteredDevices
                
                # Cache the filtered results for this user
                $cacheKey = "registeredDevices:${userName}:OS=${operatingSystem}:Prefix=${deviceNameFilter}"
                $metadata = @{
                    UserName     = $userName
                    OS           = $operatingSystem
                    DevicePrefix = $deviceNameFilter
                    DeviceCount  = $filteredDevices.Count
                    TotalDevices = $devices.Count
                }
                $cached = Set-CachedData -CacheType 'DirectoryObjects' -Key $cacheKey -Data $filteredDevices -Metadata $metadata -CacheSettings $global:cacheSettings
                if ($cached)
                {
                    Write-Verbose "[$functionName] Cached $($filteredDevices.Count) device(s) for user: $userName"
                    Write-Log -LogFile $logFile -Module $functionName -Message "Cached devices for user: $userName" -LogLevel "Debug"
                }
                
                Write-Verbose "[$functionName] Processed $($devices.Count) device(s) for user: $userName (after filtering: $($filteredDevices.Count) matching)"
            }
            else
            {
                Write-Warning "[$functionName] Failed to retrieve devices for user: $userName (Status: $($batchItem.status))"
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve devices for user: $userName (Status: $($batchItem.status))" -LogLevel "Warning"
            }
        }
    }
    # Handle single response
    else
    {
        Write-Verbose "[$functionName] Processing single response"
        # Extract user from the original request (single user scenario)
        $userName = if ($usersToQuery.Count -eq 1) { $usersToQuery[0] } else { "Unknown" }
        $devices = if ($response.value) { $response.value } else { @($response) }
        
        # Process devices using helper function
        $filteredDevices = ConvertTo-FilteredDeviceObject -Devices $devices -UserName $userName -OperatingSystemFilter $operatingSystem -DeviceNameFilter $deviceNameFilter
        if ($null -eq $filteredDevices) { $filteredDevices = @() }
        $results += $filteredDevices
        
        # Cache the filtered results for this user
        $cacheKey = "registeredDevices:${userName}:OS=${operatingSystem}:Prefix=${deviceNameFilter}"
        $metadata = @{
            UserName     = $userName
            OS           = $operatingSystem
            DevicePrefix = $deviceNameFilter
            DeviceCount  = $filteredDevices.Count
            TotalDevices = $devices.Count
        }
        $cached = Set-CachedData -CacheType 'DirectoryObjects' -Key $cacheKey -Data $filteredDevices -Metadata $metadata -CacheSettings $global:cacheSettings
        if ($cached)
        {
            Write-Verbose "[$functionName] Cached $($filteredDevices.Count) device(s) for single user query"
            Write-Log -LogFile $logFile -Module $functionName -Message "Cached devices for user: $userName" -LogLevel "Debug"
        }
        
        Write-Verbose "[$functionName] Processed $($devices.Count) device(s) for single user query (after filtering: $($filteredDevices.Count) matching)"
    }

    Write-Verbose "[$functionName] Total devices retrieved: $($results.Count)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Total devices retrieved: $($results.Count)" -LogLevel "Information"

    return $results
}