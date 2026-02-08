function Get-AutopilotEventAnalysis()
{
    <#
    .SYNOPSIS
        Gathers and analyzes autopilot event data.

    .DESCRIPTION
        Retrieves autopilot events from Graph API and performs comprehensive analysis
        including success/failure counts, durations, user patterns, and device information.

    .PARAMETER Events
        Array of autopilot events to analyze. If not provided, will fetch from Graph API.

    .PARAMETER AccessToken
        Access token for Graph API calls (required if Events not provided).

    .PARAMETER StartDate
        Optional start date to filter events.

    .PARAMETER EndDate
        Optional end date to filter events.

    .PARAMETER UserPrincipalName
        Optional user principal name to filter events.

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token -StartDate "2025-01-01"

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token -UserPrincipalName "user@contoso.com"

    .OUTPUTS
        PSCustomObject with analyzed autopilot event data
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [array]$Events,
        [Parameter()]
        [string]$AccessToken,
        [Parameter()]
        [DateTime]$StartDate,
        [Parameter()]
        [DateTime]$EndDate,
        [Parameter()]
        [string]$UserPrincipalName
    )

    $functionName = $MyInvocation.MyCommand.Name
    $filterMsg = "Starting autopilot event analysis"
    $userURI = "users"
    $autopilotEventsURI = "deviceManagement/autopilotEvents"
    $autopilotExtraparameters = "top=999&count=true"
    $signInActivityURI = "auditLogs/signIns"

    if ($UserPrincipalName)
    {
        $filterMsg += " for user: $UserPrincipalName"
    }

    Write-Verbose "[$functionName] $filterMsg"
    Write-Log -LogFile $LogFile -Module $functionName -Message $filterMsg -LogLevel "Information"

    # Fetch events if not provided
    if (-not $PSBoundParameters.ContainsKey('Events'))
    {
        if (-not $AccessToken)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken is required when Events are not provided" -LogLevel "Error"
            throw "AccessToken is required when Events are not provided"
        }
        Write-Verbose "[$functionName] Fetching autopilot events from Graph API"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching autopilot events from Graph API" -LogLevel "Information"
        $Events = (CallGraphAPI -ResourcePath $autopilotEventsURI -accessToken $AccessToken -consistencyLevel -extraParameters $autopilotExtraparameters ).value
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($Events.Count) events from Graph API" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using provided events array with $($Events.Count) events" -LogLevel "Verbose"
    }

    # Enrich autopilot events with Azure AD Device ID from managed devices
    # This enables accurate correlation with sign-in logs which use Azure AD Device ID
    # Only enrich when AccessToken is available (skip when Events are provided directly without token)
    $deviceIdToAzureADDeviceIdCache = @{}
    if ($AccessToken)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Enriching autopilot events with Azure AD Device IDs" -LogLevel "Information"
        Write-Verbose "[$functionName] Fetching Azure AD Device IDs for $($Events.Count) autopilot events"

        # Extract unique device IDs (Intune Managed Device IDs) from autopilot events
        $uniqueDeviceIds = @($Events | Where-Object { $_.deviceId } | Select-Object -ExpandProperty deviceId -Unique)
        Write-Verbose "[$functionName] Found $($uniqueDeviceIds.Count) unique device IDs requiring Azure AD Device ID lookup"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($uniqueDeviceIds.Count) unique device IDs for Azure AD Device ID resolution" -LogLevel "Information"

        # Create deviceId to azureADDeviceId lookup cache
        $deviceIdToAzureADDeviceIdCache = @{}
        if ($uniqueDeviceIds.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching Azure AD Device IDs using batch processing for $($uniqueDeviceIds.Count) devices" -LogLevel "Information"
            Write-Verbose "[$functionName] Using batch processing to fetch $($uniqueDeviceIds.Count) Azure AD Device IDs"

            # Build resource paths for batch request
            $deviceResourcePaths = @($uniqueDeviceIds | ForEach-Object { "deviceManagement/managedDevices/$_?`$select=id,azureADDeviceId,deviceName" })

            try
            {
                # CallGraphAPI supports batch processing when ResourcePath is an array
                $batchResponse = CallGraphAPI -ResourcePath $deviceResourcePaths -accessToken $accessToken

                if ($batchResponse -and $batchResponse.Count -gt 0)
                {
                    foreach ($response in $batchResponse)
                    {
                        if ($response.id -and $response.azureADDeviceId)
                        {
                            $deviceIdToAzureADDeviceIdCache[$response.id] = $response.azureADDeviceId
                            Write-Verbose "[$functionName] Cached Azure AD Device ID for device: $($response.deviceName) - Intune ID: $($response.id) -> Azure AD ID: $($response.azureADDeviceId)"
                        }
                        elseif ($response.id)
                        {
                            Write-Verbose "[$functionName] No Azure AD Device ID found for device: $($response.id)"
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Device $($response.id) has no Azure AD Device ID (may not be Azure AD joined)" -LogLevel "Verbose"
                        }
                    }
                }
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Batch request for Azure AD Device IDs failed: $_" -LogLevel "Warning"
                Write-Verbose "[$functionName] Batch request failed, attempting individual lookups"

                # Fallback to individual requests
                foreach ($deviceId in $uniqueDeviceIds)
                {
                    try
                    {
                        $deviceResponse = CallGraphAPI -ResourcePath "deviceManagement/managedDevices/$deviceId" -accessToken $accessToken -extraParameters "select=id,azureADDeviceId,deviceName"
                        if ($deviceResponse.azureADDeviceId)
                        {
                            $deviceIdToAzureADDeviceIdCache[$deviceId] = $deviceResponse.azureADDeviceId
                            Write-Verbose "[$functionName] Retrieved Azure AD Device ID for device: $deviceId -> $($deviceResponse.azureADDeviceId)"
                        }
                    }
                    catch
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to retrieve Azure AD Device ID for device ${deviceId}: $_" -LogLevel "Verbose"
                    }
                }
            }

            Write-Verbose "[$functionName] Resolved $($deviceIdToAzureADDeviceIdCache.Keys.Count) Azure AD Device IDs from $($uniqueDeviceIds.Count) devices"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Azure AD Device ID resolution complete: $($deviceIdToAzureADDeviceIdCache.Keys.Count) devices resolved" -LogLevel "Information"

            # Enrich events with Azure AD Device IDs
            $devicesEnrichedCount = 0
            foreach ($event in $Events)
            {
                if ($event.deviceId -and $deviceIdToAzureADDeviceIdCache.ContainsKey($event.deviceId))
                {
                    $event | Add-Member -NotePropertyName "azureADDeviceId" -NotePropertyValue $deviceIdToAzureADDeviceIdCache[$event.deviceId] -Force
                    $devicesEnrichedCount++
                }
            }

            Write-Verbose "[$functionName] Enriched $devicesEnrichedCount events with Azure AD Device IDs"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Enriched $devicesEnrichedCount events with Azure AD Device IDs" -LogLevel "Information"
        }
    } # end if ($AccessToken) for device enrichment

    # Filter out events with invalid dates to prevent downstream errors
    $validEvents = @($Events | Where-Object {
            $hasValidDate = $false
            if ($_.eventDateTime)
            {
                try
                {
                    [void][DateTime]$_.eventDateTime
                    $hasValidDate = $true
                }
                catch
                {
                    Write-Verbose "[$functionName] Skipping event with invalid date: $($_.eventDateTime)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Skipping event with invalid eventDateTime: $($_.eventDateTime)" -LogLevel "Warning"
                }
            }
            return $hasValidDate
        })

    if ($validEvents.Count -ne $Events.Count)
    {
        $invalidCount = $Events.Count - $validEvents.Count
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered out $invalidCount events with invalid dates" -LogLevel "Information"
    }

    $Events = $validEvents
    # Filter events by date range if specified
    $filteredEvents = $Events
    if ($StartDate -or $EndDate)
    {
        $dateRangeMsg = "Filtering events"
        if ($StartDate)
        {
            $dateRangeMsg += " from $($StartDate.ToString('yyyy-MM-dd'))"
            $signInLogsStartDate = $StartDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        else
        {
            # If no start date provided, use 30 days before end date or 30 days ago
            $defaultStart = if ($EndDate)
            {
                $EndDate.AddDays(-30)
            }
            else
            {
                (Get-Date).AddDays(-30)
            }
            $signInLogsStartDate = $defaultStart.ToString("yyyy-MM-ddTHH:mm:ssZ")
            Write-Log -LogFile $LogFile -Module $functionName -Message "No StartDate provided, using default start date for sign-in logs: $($defaultStart.ToString('yyyy-MM-dd'))" -LogLevel "Verbose"
        }
        if ($EndDate)
        {
            $dateRangeMsg += " to $($EndDate.ToString('yyyy-MM-dd'))"
            $signInLogsEndDate = $EndDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        else
        {
            # If no end date provided, use current date
            $defaultEnd = Get-Date
            $signInLogsEndDate = $defaultEnd.ToString("yyyy-MM-ddTHH:mm:ssZ")
            Write-Log -LogFile $LogFile -Module $functionName -Message "No EndDate provided, using default end date for sign-in logs: $($defaultEnd.ToString('yyyy-MM-dd'))" -LogLevel "Verbose"
        }
        Write-Log -LogFile $LogFile -Module $functionName -Message $dateRangeMsg -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in log date range: $signInLogsStartDate to $signInLogsEndDate" -LogLevel "Verbose"

        $filteredEvents = $Events | Where-Object {
            $eventDate = $null
            try
            {
                $eventDate = [DateTime]$_.eventDateTime
            }
            catch
            {
                return $false
            }

            $afterStart = (-not $StartDate) -or ($eventDate -ge $StartDate)
            $beforeEnd = (-not $EndDate) -or ($eventDate -le $EndDate)
            return ($afterStart -and $beforeEnd)
        }
        Write-Verbose "[$functionName] Filtered to $($filteredEvents.Count) events from $($Events.Count) total"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered to $($filteredEvents.Count) events from $($Events.Count) total" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No date filtering applied, analyzing all $($Events.Count) events" -LogLevel "Verbose"
        $signInLogsStartDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $signInLogsEndDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in log date range (default): $signInLogsStartDate to $signInLogsEndDate" -LogLevel "Verbose"
    }

    # Filter events by UserPrincipalName if specified
    if ($UserPrincipalName)
    {
        if ($AccessToken)
        {
            $userObject = CallGraphAPI -ResourcePath "$userURI/$UserPrincipalName" -accessToken $accessToken
            write-log -logFile $LogFile -Module $functionName -Message "Retrieved user object for $UserPrincipalName with id $($userObject.id)" -LogLevel "Information"
        }
        $beforeUserFilter = $filteredEvents.Count
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtering events by UserPrincipalName: $UserPrincipalName" -LogLevel "Information"
        $filteredEvents = $filteredEvents | Where-Object {
            $_.userPrincipalName -eq $UserPrincipalName
        }
        Write-Verbose "[$functionName] Filtered to $($filteredEvents.Count) events from $beforeUserFilter for user $UserPrincipalName ($($userObject.displayName))"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered to $($filteredEvents.Count) events from $beforeUserFilter for user $UserPrincipalName" -LogLevel "Information"
    }

    # Helper function to convert ISO 8601 duration to TimeSpan
    function ConvertFrom-ISO8601Duration
    {
        param([string]$Duration)

        if ([string]::IsNullOrWhiteSpace($Duration))
        {
            return $null
        }

        try
        {
            return [System.Xml.XmlConvert]::ToTimeSpan($Duration)
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to parse duration: $Duration"
            return $null
        }
    }

    # Enrich events with user IDs where missing (only when AccessToken is available)
    $upnToUserIdCache = @{}
    $signInCache = @{}
    $totalSignInsRetrieved = 0
    if ($AccessToken)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Enriching $($filteredEvents.Count) events with user IDs" -LogLevel "Information"

        # Extract unique UPNs from filtered events that need user ID resolution
        $uniqueUPNs = @($filteredEvents | Where-Object { $_.userPrincipalName} | Select-Object -ExpandProperty userPrincipalName -Unique)
        Write-Verbose "[$functionName] Found $($uniqueUPNs.Count) unique UPNs requiring user ID lookup"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($uniqueUPNs.Count) unique UPNs requiring user ID resolution" -LogLevel "Information"

        # Create UPN to userId lookup cache
        $upnToUserIdCache = @{}
        if ($uniqueUPNs.Count -gt 0)
        {
            # Use batch processing for efficient API calls
            Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching user IDs using batch processing for $($uniqueUPNs.Count) UPNs" -LogLevel "Information"
            Write-Verbose "[$functionName] Using batch processing to fetch $($uniqueUPNs.Count) user IDs"

            # Build resource paths for batch request
            $userResourcePaths = @($uniqueUPNs | ForEach-Object { "$userURI/$_" })

            try
            {
                # CallGraphAPI supports batch processing when ResourcePath is an array
                $batchResponse = CallGraphAPI -ResourcePath $userResourcePaths -accessToken $accessToken
                Write-Log -LogFile $LogFile -Module $functionName -Message "Batch API call completed with successCount: $($batchResponse.successCount), failureCount: $($batchResponse.failureCount)" -LogLevel "Information"

                # Check for batch response in 'value' property (standard Graph API batch format)
                if ($batchResponse -and $batchResponse.value)
                {
                    <<<<<<< HEAD
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing $($batchResponse.value.Count) batch responses" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Processing $($batchResponse.value.Count) batch responses"
                    =======
                    $result = $batchResponse.value[$i]
                    $originalUpn = if ($result.body -and $result.body.userPrincipalName)
                    {
                        $result.body.userPrincipalName
                    }
                    else
                    {
                        'Unknown'
                    }
                    >>>>>>> cdca3d5f280c7467307cfb6318e8d3cb4c6334b2
                    'Unknown'
                }

                Write-Verbose "[$functionName] Processing batch item $($i + 1)/$($batchResponse.value.Count): UPN=$originalUpn, Status=$($result.status)"

                # Check if response was successful (status 200)
                if ($result.status -eq 200 -and $result.body)
                {
                    # Extract user ID from response body
                    if ($result.body.id -and $result.body.userPrincipalName)
                    {
                        $upnToUserIdCache[$result.body.userPrincipalName] = $result.body.id
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Resolved $($result.body.userPrincipalName) to user ID: $($result.body.id)" -LogLevel "Verbose"
                    }
                    else
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Batch response for $originalUpn missing id or userPrincipalName in body" -LogLevel "Warning"
                    }
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to resolve user ID for UPN: $originalUpn (Status: $($result.status))" -LogLevel "Warning"
                }
            }

            Write-Verbose "[$functionName] Batch processing complete: $($upnToUserIdCache.Keys.Count) user IDs resolved"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Batch processing complete: $($upnToUserIdCache.Keys.Count) user IDs resolved" -LogLevel "Information"
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Batch response did not contain expected 'value' property. Response structure: $($batchResponse.PSObject.Properties.Name -join ', ')" -LogLevel "Warning"
            Write-Verbose "[$functionName] Batch response missing 'value' property. Available properties: $($batchResponse.PSObject.Properties.Name -join ', ')"
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Batch user ID fetch failed, falling back to individual requests: $_" -LogLevel "Warning"
        Write-Verbose "[$functionName] Batch request failed, falling back to individual requests"

        # Fallback to individual requests
        $upnIndex = 0
        foreach ($upn in $uniqueUPNs)
        {
            $upnIndex++
            if ($upnIndex % 5 -eq 0 -or $upnIndex -eq 1)
            {
                Write-Verbose "[$functionName] Fetching user ID for UPN $upnIndex/$($uniqueUPNs.Count): $upn"
            }

            try
            {
                $userObject = CallGraphAPI -ResourcePath "$userURI/$upn" -accessToken $accessToken

                if ($userObject -and $userObject.id)
                {
                    $upnToUserIdCache[$upn] = $userObject.id
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Resolved $upn to user ID: $($userObject.id)" -LogLevel "Verbose"
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No user ID found for UPN: $upn" -LogLevel "Warning"
                }
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to fetch user ID for UPN $upn : $_" -LogLevel "Warning"
            }
        }
    }

    Write-Verbose "[$functionName] Resolved $($upnToUserIdCache.Keys.Count) user IDs from $($uniqueUPNs.Count) UPNs"
    Write-Log -LogFile $LogFile -Module $functionName -Message "User ID resolution complete: $($upnToUserIdCache.Keys.Count) UPNs resolved out of $($uniqueUPNs.Count) requested" -LogLevel "Information"

    # Enrich filtered events with user IDs
    $eventsEnrichedCount = 0
    foreach ($event in $filteredEvents)
    {
        if ($event.userPrincipalName -and -not $event.userId -and $upnToUserIdCache.ContainsKey($event.userPrincipalName))
        {
            # Handle both hashtables and PSCustomObjects
            if ($event -is [hashtable])
            {
                $event['userId'] = $upnToUserIdCache[$event.userPrincipalName]
            }
            else
            {
                $event | Add-Member -NotePropertyName "userId" -NotePropertyValue $upnToUserIdCache[$event.userPrincipalName] -Force
            }
            $eventsEnrichedCount++
        }
    }

    Write-Verbose "[$functionName] Enriched $eventsEnrichedCount events with user IDs"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Enriched $eventsEnrichedCount events with user IDs" -LogLevel "Information"
}

# Fetch sign-in activity data per user (more efficient than fetching all sign-ins)
Write-Log -LogFile $LogFile -Module $functionName -Message "Extracting unique user IDs from $($filteredEvents.Count) autopilot events" -LogLevel "Information"
# Get unique userIds from autopilot events (now that they're enriched)
$uniqueUserIds = @($filteredEvents | Where-Object { $_.userId } | Select-Object -ExpandProperty userId -Unique)
Write-Verbose "[$functionName] Found $($uniqueUserIds.Count) unique user IDs in autopilot events"
Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($uniqueUserIds.Count) unique user IDs to fetch sign-in data for" -LogLevel "Information"

if ($uniqueUserIds.Count -gt 0)
{
    Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching sign-in data for $($uniqueUserIds.Count) users using batch processing" -LogLevel "Information"
    Write-Verbose "[$functionName] Using batch processing to fetch sign-in data for $($uniqueUserIds.Count) users"

    # Build resource paths with filters for batch request
    # Note: Graph API $batch doesn't support query parameters in the URL for batch items,
    # so we need to construct full URLs with encoded filters
    $signInResourcePaths = @()
    foreach ($userId in $uniqueUserIds)
    {
        # Construct the filter for this specific user
        $filterPart = "userId eq '$userId' and createdDateTime ge $signInLogsStartDate and createdDateTime le $signInLogsEndDate"
        $fullPath = "$signInActivityURI`?`$filter=$filterPart&`$orderby=createdDateTime desc&`$top=50"
        $signInResourcePaths += $fullPath
    }

    try
    {
        # Use batch processing for sign-in requests
        $batchResponse = CallGraphAPI -ResourcePath $signInResourcePaths -accessToken $accessToken
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in batch API call completed with successCount: $($batchResponse.successCount), failureCount: $($batchResponse.failureCount)" -LogLevel "Information"
        Write-Verbose "[$functionName] Sign-in batch API call completed: successCount=$($batchResponse.successCount), failureCount=$($batchResponse.failureCount)"
        # Check for batch response in 'value' property
        if ($batchResponse -and $batchResponse.value)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Processing $($batchResponse.value.Count) sign-in batch responses" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Processing $($batchResponse.value.Count) sign-in batch responses"

            # Process each batch response item
            # Match responses to original userIds by index (batch preserves request order)
            for ($i = 0; $i -lt $batchResponse.value.Count; $i++)
            {
                $result = $batchResponse.value[$i]
                $userId = if ($i -lt $uniqueUserIds.Count)
                {
                    $uniqueUserIds[$i]
                }
                else
                {
                    'Unknown'
                }

                Write-Verbose "[$functionName] Processing sign-in batch item $($i + 1)/$($batchResponse.value.Count): userId=$userId, Status=$($result.status)"

                # Check if response was successful (status 200)
                if ($result.status -eq 200 -and $result.body)
                {
                    # Extract sign-ins from response body
                    $userSignIns = if ($result.body.value)
                    {
                        @($result.body.value)
                    }
                    else
                    {
                        @()
                    }

                    if ($userSignIns.Count -gt 0)
                    {
                        $signInCache[$userId] = $userSignIns
                        $totalSignInsRetrieved += $userSignIns.Count
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($userSignIns.Count) sign-ins for userId: $userId" -LogLevel "Verbose"
                    }
                    else
                    {
                        $signInCache[$userId] = @()
                        Write-Log -LogFile $LogFile -Module $functionName -Message "No sign-ins found for userId: $userId" -LogLevel "Verbose"
                    }
                }
                else
                {
                    $signInCache[$userId] = @()
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to fetch sign-ins for userId: $userId (Status: $($result.status))" -LogLevel "Warning"
                }
            }

            Write-Verbose "[$functionName] Sign-in batch processing complete: $totalSignInsRetrieved sign-ins retrieved for $($signInCache.Keys.Count) users"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in batch processing complete: $totalSignInsRetrieved sign-ins retrieved for $($signInCache.Keys.Count) users" -LogLevel "Information"
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in batch response did not contain expected 'value' property" -LogLevel "Warning"
            Write-Verbose "[$functionName] Sign-in batch response missing 'value' property"
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in batch fetch failed, falling back to individual requests: $_" -LogLevel "Warning"
        Write-Verbose "[$functionName] Sign-in batch request failed, falling back to individual requests"

        # Fallback to individual requests
        $userIndex = 0
        foreach ($userId in $uniqueUserIds)
        {
            $userIndex++

            if ($userIndex % 5 -eq 0 -or $userIndex -eq 1)
            {
                Write-Verbose "[$functionName] Fetching sign-ins for user $userIndex/$($uniqueUserIds.Count)"
            }

            # Construct filter for this specific user
            $userSignInFilter = "filter=userId eq '$userId' and createdDateTime ge $signInLogsStartDate and createdDateTime le $signInLogsEndDate&orderby=createdDateTime desc&top=50"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching sign-ins for user $userIndex/$($uniqueUserIds.Count) with filter: $userSignInFilter" -LogLevel "Verbose"

            try
            {
                $signInResponse = CallGraphAPI -ResourcePath $signInActivityURI -AccessToken $accessToken -ExtraParameters $userSignInFilter
                $userSignIns = if ($signInResponse.value)
                {
                    $signInResponse.value
                }
                else
                {
                    @()
                }

                if ($userSignIns.Count -gt 0)
                {
                    $signInCache[$userId] = @($userSignIns)
                    $totalSignInsRetrieved += $userSignIns.Count
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($userSignIns.Count) sign-ins for userId: $userId" -LogLevel "Verbose"
                }
                else
                {
                    $signInCache[$userId] = @()
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No sign-ins found for userId: $userId" -LogLevel "Verbose"
                }
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to fetch sign-ins for userId $userId : $_" -LogLevel "Warning"
                $signInCache[$userId] = @()
            }
        }

        Write-Verbose "[$functionName] Retrieved $totalSignInsRetrieved total sign-in records for $($signInCache.Keys.Count) users (fallback mode)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in data retrieval complete (fallback): $totalSignInsRetrieved sign-ins for $($signInCache.Keys.Count) users" -LogLevel "Information"
    }
}
else
{
    Write-Log -LogFile $LogFile -Module $functionName -Message "No user IDs to fetch sign-in data for" -LogLevel "Verbose"
    Write-Verbose "[$functionName] No user IDs to fetch sign-in data for"
}
} # end if ($AccessToken) for user enrichment and sign-in data

# Helper function to match sign-in activity to autopilot event
function Get-SignInMatch()
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$Event,
        [Parameter(Mandatory = $true)]
        [hashtable]$Cache
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting sign-in match for event ID: $($Event.id), userId: $($Event.userId)" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Attempting to match sign-in for event ID: $($Event.id)"

    $matchResult = [PSCustomObject]@{
        MatchFound          = $false
        ConfidenceScore     = 0
        MatchedOn           = @()
        Location_City       = $null
        Location_State      = $null
        Location_Country    = $null
        IPAddress           = $null
        SignInStatus        = $null
        SignInFailureReason = $null
        SignInErrorCode     = $null
        AppDisplayName      = $null
        DeviceDisplayName   = $null
        IsCompliant         = $null
        IsManaged           = $null
    }

    # Minimum requirement: userId must match
    if (-not $Event.userId -or -not $Cache.ContainsKey($Event.userId))
    {
        Write-Verbose "[$functionName] No userId or user not in cache, skipping match"
        $inCache = if ($Event.userId)
        {
            $Cache.ContainsKey($Event.userId)
        }
        else
        {
            "N/A"
        }
        Write-Log -LogFile $LogFile -Module $functionName -Message "No userId match possible - userId: $($Event.userId), in cache: $inCache" -LogLevel "Verbose"
        return $matchResult
    }

    $candidateSignIns = $Cache[$Event.userId]
    if ($candidateSignIns.Count -eq 0)
    {
        Write-Verbose "[$functionName] No candidate sign-ins found in cache for userId: $($Event.userId)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No candidate sign-ins found for userId: $($Event.userId)" -LogLevel "Verbose"
        return $matchResult
    }

    Write-Verbose "[$functionName] Found $($candidateSignIns.Count) candidate sign-ins for userId: $($Event.userId)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Evaluating $($candidateSignIns.Count) candidate sign-ins" -LogLevel "Verbose"

    # Parse event date
    $eventDate = $null
    try
    {
        $eventDate = [DateTime]$Event.eventDateTime
        Write-Verbose "[$functionName] Event date parsed: $eventDate"
    }
    catch
    {
        Write-Verbose "[$functionName] Failed to parse event date: $($Event.eventDateTime)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to parse event date: $($Event.eventDateTime)" -LogLevel "Warning"
        return $matchResult
    }

    # Check if we have Azure AD Device ID for this event (from enrichment)
    $eventAzureADDeviceId = $Event.azureADDeviceId
    if ($eventAzureADDeviceId)
    {
        Write-Verbose "[$functionName] Event has Azure AD Device ID: $eventAzureADDeviceId - will use for high-confidence matching"
    }
    else
    {
        Write-Verbose "[$functionName] Event has no Azure AD Device ID - will use fallback matching (device name, time proximity)"
    }

    # Score each candidate sign-in
    $bestMatch = $null
    $bestScore = 0
    $candidateIndex = 0

    foreach ($signIn in $candidateSignIns)
    {
        $candidateIndex++
        $score = 0
        $matchedCriteria = @()
        Write-Verbose "[$functionName] Evaluating candidate $candidateIndex/$($candidateSignIns.Count) - SignIn date: $($signIn.createdDateTime)"

        # 1. UserId match (minimum - already confirmed)
        $score += 25
        $matchedCriteria += "UserId"

        # 2. Azure AD Device ID match (HIGHEST CONFIDENCE - definitive match)
        # This is the most reliable correlation between Autopilot events and sign-in logs
        # Autopilot events have Intune Device ID; we enriched them with Azure AD Device ID
        # Sign-in logs have Azure AD Device ID in deviceDetail.deviceId
        if ($eventAzureADDeviceId -and
            $signIn.deviceDetail -and
            $signIn.deviceDetail.deviceId -and
            $eventAzureADDeviceId -eq $signIn.deviceDetail.deviceId)
        {
            $score += 100
            $matchedCriteria += "AzureADDeviceId"
            Write-Verbose "[$functionName] DEFINITIVE MATCH: Azure AD Device ID match! Event azureADDeviceId: $eventAzureADDeviceId = SignIn deviceId: $($signIn.deviceDetail.deviceId)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Azure AD Device ID match (definitive): $eventAzureADDeviceId" -LogLevel "Verbose"
        }

        # 3. Device Name match (fallback if Azure AD Device ID not available)
        if ($Event.managedDeviceName -and
            $signIn.deviceDetail -and
            $signIn.deviceDetail.displayName -and
            $Event.managedDeviceName -eq $signIn.deviceDetail.displayName)
        {
            $score += 35
            $matchedCriteria += "DeviceName"
            Write-Verbose "[$functionName] Device name match: '$($Event.managedDeviceName)'"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Device name match: $($Event.managedDeviceName)" -LogLevel "Verbose"
        }

        # 4. Time proximity (high value)
        try
        {
            $signInDate = [DateTime]$signIn.createdDateTime
            $timeDiff = [Math]::Abs(($eventDate - $signInDate).TotalMinutes)
            Write-Verbose "[$functionName] Time difference: $([Math]::Round($timeDiff, 2)) minutes"

            if ($timeDiff -le 60)
            {
                $score += 30
                $matchedCriteria += "Time_Within1Hour"
                Write-Verbose "[$functionName] Time match: Within 1 hour"
            }
            elseif ($timeDiff -le 120)
            {
                $score += 20
                $matchedCriteria += "Time_Within2Hours"
                Write-Verbose "[$functionName] Time match: Within 2 hours"
            }
            elseif ($timeDiff -le 360)
            {
                $score += 10
                $matchedCriteria += "Time_Within6Hours"
                Write-Verbose "[$functionName] Time match: Within 6 hours"
            }
            else
            {
                Write-Verbose "[$functionName] Time difference too large: $([Math]::Round($timeDiff, 2)) minutes"
            }
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to parse sign-in date: $($signIn.createdDateTime)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to parse sign-in date for scoring" -LogLevel "Verbose"
        }

        # 5. AppId match for Microsoft Intune enrollment (bonus)
        # Common Intune/Enrollment app IDs:
        # - d4ebce55-015a-49b5-a083-c84d1797ae8c (Microsoft Intune Enrollment)
        # - 0000000a-0000-0000-c000-000000000000 (Microsoft Intune)
        if ($signIn.appId)
        {
            $intuneAppIds = @('d4ebce55-015a-49b5-a083-c84d1797ae8c', '0000000a-0000-0000-c000-000000000000')
            if ($intuneAppIds -contains $signIn.appId)
            {
                $score += 10
                $matchedCriteria += "IntuneApp"
                Write-Verbose "[$functionName] Intune app match found: $($signIn.appId)"
            }
        }

        Write-Verbose "[$functionName] Candidate $candidateIndex final score: $score (Criteria: $($matchedCriteria -join ', '))"

        # Track best match
        if ($score -gt $bestScore)
        {
            $bestScore = $score
            $bestMatch = $signIn
            $matchResult.MatchedOn = $matchedCriteria
            Write-Verbose "[$functionName] New best match with score: $bestScore"
            Write-Log -LogFile $LogFile -Module $functionName -Message "New best match found with score $bestScore (Criteria: $($matchedCriteria -join ', '))" -LogLevel "Verbose"
        }
    }

    # If we found a match (score > 25 means more than just userId)
    if ($bestMatch)
    {
        $matchResult.MatchFound = $true
        $matchResult.ConfidenceScore = $bestScore
        Write-Verbose "[$functionName] Best match selected with confidence score: $bestScore"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in match found with confidence score $bestScore for event ID: $($Event.id)" -LogLevel "Verbose"

        # Extract location data
        if ($bestMatch.location)
        {
            $matchResult.Location_City = $bestMatch.location.city
            $matchResult.Location_State = $bestMatch.location.state
            $matchResult.Location_Country = $bestMatch.location.countryOrRegion
            Write-Verbose "[$functionName] Location extracted: $($matchResult.Location_City), $($matchResult.Location_State), $($matchResult.Location_Country)"
        }

        # Extract IP address
        $matchResult.IPAddress = $bestMatch.ipAddress

        # Extract sign-in status
        if ($bestMatch.status)
        {
            if ($bestMatch.status.errorCode -eq 0)
            {
                $matchResult.SignInStatus = "Success"
            }
            else
            {
                $matchResult.SignInStatus = "Failure"
                $matchResult.SignInFailureReason = $bestMatch.status.failureReason
                $matchResult.SignInErrorCode = $bestMatch.status.errorCode
            }
        }

        # Extract app info
        $matchResult.AppDisplayName = $bestMatch.appDisplayName

        # Extract device compliance info
        if ($bestMatch.deviceDetail)
        {
            $matchResult.DeviceDisplayName = $bestMatch.deviceDetail.displayName
            $matchResult.IsCompliant = $bestMatch.deviceDetail.isCompliant
            $matchResult.IsManaged = $bestMatch.deviceDetail.isManaged
            Write-Verbose "[$functionName] Device compliance extracted: Compliant=$($matchResult.IsCompliant), Managed=$($matchResult.IsManaged)"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No suitable match found (best score: $bestScore)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No sign-in match found for event ID: $($Event.id) (best score: $bestScore)" -LogLevel "Verbose"
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message "Sign-in matching completed for event ID: $($Event.id)" -LogLevel "Verbose"
    return $matchResult
}

# Enrich all filtered events with sign-in data
Write-Verbose "[$functionName] Enriching $($filteredEvents.Count) events with sign-in activity data"
Write-Log -LogFile $LogFile -Module $functionName -Message "Starting event enrichment with sign-in data for $($filteredEvents.Count) events" -LogLevel "Information"

$enrichedEvents = @()
$matchStats = @{
    TotalEvents      = 0
    MatchedEvents    = 0
    HighConfidence   = 0
    MediumConfidence = 0
    LowConfidence    = 0
}
$enrichmentIndex = 0

foreach ($filteredEvent in $filteredEvents)
{
    $enrichmentIndex++
    $matchStats.TotalEvents++

    if ($enrichmentIndex % 10 -eq 0 -or $enrichmentIndex -eq 1)
    {
        Write-Verbose "[$functionName] Processing event $enrichmentIndex/$($filteredEvents.Count)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Event enrichment progress: $enrichmentIndex/$($filteredEvents.Count)" -LogLevel "Verbose"
    }

    # Get sign-in match
    Write-Verbose "[$functionName] Matching sign-in for event: $($filteredEvent.id), User: $($filteredEvent.userPrincipalName), Device: $($filteredEvent.managedDeviceName)"
    $signInMatch = Get-SignInMatch -Event $filteredEvent -Cache $signInCache

    # Track match statistics
    if ($signInMatch.MatchFound)
    {
        $matchStats.MatchedEvents++
        $confidenceLevel = ""
        # With new scoring:
        # - Azure AD Device ID match = 100 pts + 25 (userId) = 125+ = Definitive/High
        # - Device Name + Time = 35 + 25 + up to 30 = up to 90 = High/Medium
        # - Time only = 25 + up to 30 = up to 55 = Low/Medium
        if ($signInMatch.ConfidenceScore -ge 100)
        {
            $matchStats.HighConfidence++
            $confidenceLevel = "High"
        }
        elseif ($signInMatch.ConfidenceScore -ge 60)
        {
            $matchStats.MediumConfidence++
            $confidenceLevel = "Medium"
        }
        else
        {
            $matchStats.LowConfidence++
            $confidenceLevel = "Low"
        }
        Write-Verbose "[$functionName] Event $($enrichmentIndex): Match found with $confidenceLevel confidence (Score: $($signInMatch.ConfidenceScore))"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Event ID $($filteredEvent.id): Matched with $confidenceLevel confidence (Score: $($signInMatch.ConfidenceScore), Criteria: $($signInMatch.MatchedOn -join ', '))" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] Event $($enrichmentIndex): No match found"
    }

    # Create enriched event object
    $enrichedEvent = $filteredEvent | Select-Object *
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_MatchFound" -NotePropertyValue $signInMatch.MatchFound -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_ConfidenceScore" -NotePropertyValue $signInMatch.ConfidenceScore -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_MatchedOn" -NotePropertyValue ($signInMatch.MatchedOn -join ", ") -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_Location_City" -NotePropertyValue $signInMatch.Location_City -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_Location_State" -NotePropertyValue $signInMatch.Location_State -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_Location_Country" -NotePropertyValue $signInMatch.Location_Country -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_IPAddress" -NotePropertyValue $signInMatch.IPAddress -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_Status" -NotePropertyValue $signInMatch.SignInStatus -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_FailureReason" -NotePropertyValue $signInMatch.SignInFailureReason -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_ErrorCode" -NotePropertyValue $signInMatch.SignInErrorCode -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_AppDisplayName" -NotePropertyValue $signInMatch.AppDisplayName -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_DeviceDisplayName" -NotePropertyValue $signInMatch.DeviceDisplayName -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_IsCompliant" -NotePropertyValue $signInMatch.IsCompliant -Force
    $enrichedEvent | Add-Member -NotePropertyName "SignIn_IsManaged" -NotePropertyValue $signInMatch.IsManaged -Force

    $enrichedEvents += $enrichedEvent
}

Write-Log -LogFile $LogFile -Module $functionName -Message "Event enrichment complete: $($matchStats.MatchedEvents)/$($matchStats.TotalEvents) events matched with sign-in data" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module $functionName -Message "Match confidence: High=$($matchStats.HighConfidence), Medium=$($matchStats.MediumConfidence), Low=$($matchStats.LowConfidence)" -LogLevel "Verbose"

# Update filtered events to enriched events
$filteredEvents = $enrichedEvents

# 1. Earliest event date
$earliestEvent = $filteredEvents |
    Where-Object { $_.eventDateTime -and $null -ne $_.deploymentState } |
    Sort-Object eventDateTime |
    Select-Object -First 1

$earliestDate = if ($earliestEvent)
{
    [DateTime]$earliestEvent.eventDateTime
}
else
{
    $null
}

# 2. Total number of events
$totalEvents = $filteredEvents.Count

# 3, 4 & 4b. Successful, failed, and in-progress events
$successfulEvents = @($filteredEvents | Where-Object { $_.deploymentState -eq 'success' })
$inProgressEvents = @($filteredEvents | Where-Object { $_.deploymentState -eq 'inProgress' })
$failedEvents = @($filteredEvents | Where-Object {
        ($null -ne $_.deploymentState -and $_.deploymentState -notin @('success', 'inProgress', 'notStarted')) -or
        ($_.deploymentState -eq 'notStarted' -and
        (
            ($null -ne $_.deviceSetupStatus -and $_.deviceSetupStatus -notin @('success', 'inProgress', 'notStarted')) -or
            ($null -ne $_.accountSetupStatus -and $_.accountSetupStatus -notin @('success', 'inProgress', 'notStarted'))
        ))
    })

# 5. Average duration of successful deployments
$successDurations = @($successfulEvents | ForEach-Object {
        $duration = ConvertFrom-ISO8601Duration -Duration $_.deploymentTotalDuration
        if ($duration)
        {
            $duration
        }
    })

$avgSuccessDuration = if ($successDurations.Count -gt 0)
{
    $totalTicks = ($successDurations | Measure-Object -Property Ticks -Sum).Sum
    New-Object TimeSpan($totalTicks / $successDurations.Count)
}
else
{
    $null
}

# 6. Average duration of failed deployments
$failureDurations = @($failedEvents | ForEach-Object {
        $duration = ConvertFrom-ISO8601Duration -Duration $_.deploymentTotalDuration
        if ($duration)
        {
            $duration
        }
    })

$avgFailureDuration = if ($failureDurations.Count -gt 0)
{
    $totalTicks = ($failureDurations | Measure-Object -Property Ticks -Sum).Sum
    New-Object TimeSpan($totalTicks / $failureDurations.Count)
}
else
{
    $null
}

# 6b. Categorize in-progress devices by phase
$devicePhaseInProgress = @($inProgressEvents | Where-Object {
        $_.deviceSetupStatus -eq 'inProgress'
    })

$userPhaseInProgress = @($inProgressEvents | Where-Object {
        $_.deviceSetupStatus -eq 'success' -and
        $_.accountSetupStatus -eq 'inProgress'
    })

# 7. Categorize failures into mutually exclusive groups
# Device phase only: Device failed, account not started or success
$devicePhaseOnlyFailures = @($failedEvents | Where-Object {
        $deviceFailed = $_.deviceSetupStatus -and
        $_.deviceSetupStatus -notin @('success', 'notStarted', 'inProgress') -and
        $null -ne $_.deviceSetupStatus
        $accountNotFailed = (-not $_.accountSetupStatus) -or
        $_.accountSetupStatus -in @('success', 'notStarted', 'inProgress')
        $deviceFailed -and $accountNotFailed
    })

# User/Account phase only: Device succeeded, account failed
$userPhaseOnlyFailures = @($failedEvents | Where-Object {
        $deviceSuccess = $_.deviceSetupStatus -eq 'success'
        $accountFailed = $_.accountSetupStatus -and
        $_.accountSetupStatus -notin @('success', 'notStarted', 'inProgress') -and
        $null -ne $_.accountSetupStatus
        $deviceSuccess -and $accountFailed
    })

# Both phases failed: Both device and account show failure
$bothPhasesFailures = @($failedEvents | Where-Object {
        $deviceFailed = $_.deviceSetupStatus -and
        $_.deviceSetupStatus -notin @('success', 'notStarted', 'inProgress') -and
        $null -ne $_.deviceSetupStatus
        $accountFailed = $_.accountSetupStatus -and
        $_.accountSetupStatus -notin @('success', 'notStarted', 'inProgress') -and
        $null -ne $_.accountSetupStatus
        $deviceFailed -and $accountFailed
    })

# Unknown/Other: Failures that don't clearly fall into above categories
$unknownPhaseFailures = @($failedEvents | Where-Object {
        $deviceFailed = $_.deviceSetupStatus -and
        $_.deviceSetupStatus -notin @('success', 'notStarted', 'inProgress') -and
        $null -ne $_.deviceSetupStatus
        $accountFailed = $_.accountSetupStatus -and
        $_.accountSetupStatus -notin @('success', 'notStarted', 'inProgress') -and
        $null -ne $_.accountSetupStatus
        $deviceSuccess = $_.deviceSetupStatus -eq 'success'
        $accountNotFailed = (-not $_.accountSetupStatus) -or
        $_.accountSetupStatus -in @('success', 'notStarted', 'inProgress')

        # Not in any of the three categories above
        -not (($deviceFailed -and $accountNotFailed) -or
            ($deviceSuccess -and $accountFailed) -or
            ($deviceFailed -and $accountFailed))
    })

# 8. Users with multiple enrollment failures
$userFailureGroups = $failedEvents |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.userPrincipalName) } |
    Group-Object -Property userPrincipalName |
    Where-Object { $_.Count -gt 1 } |
    Sort-Object -Property Count -Descending

$usersWithMultipleFailures = @()
foreach ($userGroup in $userFailureGroups)
{
    # Check for eventual success
    $userSuccesses = $successfulEvents |
        Where-Object { $_.userPrincipalName -eq $userGroup.Name } |
        Sort-Object eventDateTime

    $lastFailureDate = ($userGroup.Group | Sort-Object eventDateTime -Descending | Select-Object -First 1).eventDateTime

    $firstSuccessAfterFailures = $userSuccesses |
        Where-Object {
            if ($lastFailureDate)
            {
                ([DateTime]$_.eventDateTime) -gt ([DateTime]$lastFailureDate)
            }
            else
            {
                $true
            }
        } |
        Select-Object -First 1

    $usersWithMultipleFailures += [PSCustomObject]@{
        UserPrincipalName = $userGroup.Name
        FailureCount      = $userGroup.Count
        FailedDevices     = @($userGroup.Group | Sort-Object eventDateTime)
        EventualSuccess   = $null -ne $firstSuccessAfterFailures
        SuccessDevice     = $firstSuccessAfterFailures
        LastFailureDate   = $lastFailureDate
    }
}

# 8b. Users with single failure followed by success
$singleFailureUsers = $failedEvents |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.userPrincipalName) } |
    Group-Object -Property userPrincipalName |
    Where-Object { $_.Count -eq 1 }

$singleFailureWithSuccess = @()
foreach ($userGroup in $singleFailureUsers)
{
    $userSuccesses = $successfulEvents | Where-Object { $_.userPrincipalName -eq $userGroup.Name }

    if ($userSuccesses)
    {
        $failureDate = $userGroup.Group[0].eventDateTime
        $successAfter = $userSuccesses |
            Where-Object {
                if ($failureDate)
                {
                    ([DateTime]$_.eventDateTime) -gt ([DateTime]$failureDate)
                }
                else
                {
                    $false
                }
            } |
            Sort-Object eventDateTime |
            Select-Object -First 1

        if ($successAfter)
        {
            $singleFailureWithSuccess += [PSCustomObject]@{
                UserPrincipalName = $userGroup.Name
                FailureDate       = $failureDate
                FailureDevice     = $userGroup.Group[0]
                SuccessDate       = $successAfter.eventDateTime
                SuccessDevice     = $successAfter
            }
        }
    }
}

# 9. Failed devices sorted chronologically
$failedDevicesSorted = $failedEvents |
    Where-Object { $_.deviceSerialNumber } |
    Sort-Object eventDateTime

# 10. Location-based analysis (from sign-in data)
Write-Log -LogFile $LogFile -Module $functionName -Message "Performing location-based analysis from sign-in data" -LogLevel "Information"
Write-Verbose "[$functionName] Analyzing events by location"

# Filter events that have location data from sign-in matching
$eventsWithLocation = @($filteredEvents | Where-Object { $_.SignIn_Location_Country -or $_.SignIn_Location_City })
Write-Verbose "[$functionName] Found $($eventsWithLocation.Count) events with location data"
Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($eventsWithLocation.Count) events with location data" -LogLevel "Verbose"

$locationStats = @{}

foreach ($event in $eventsWithLocation)
{
    # Create location key (Country-State-City)
    $locationKey = @(
        $event.SignIn_Location_Country,
        $event.SignIn_Location_State,
        $event.SignIn_Location_City
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }

    $locationString = if ($locationKey.Count -gt 0)
    {
        $locationKey -join ', '
    }
    else
    {
        'Unknown'
    }

    # Initialize location entry if not exists
    if (-not $locationStats.ContainsKey($locationString))
    {
        $locationStats[$locationString] = @{
            Country         = $event.SignIn_Location_Country
            State           = $event.SignIn_Location_State
            City            = $event.SignIn_Location_City
            TotalEvents     = 0
            SuccessCount    = 0
            FailureCount    = 0
            InProgressCount = 0
            Events          = [System.Collections.ArrayList]::new()
        }
    }

    # Increment counters
    $locationStats[$locationString].TotalEvents++
    [void]$locationStats[$locationString].Events.Add($event)

    # Categorize by deployment state
    if ($event.deploymentState -eq 'success')
    {
        $locationStats[$locationString].SuccessCount++
    }
    elseif ($event.deploymentState -eq 'inProgress')
    {
        $locationStats[$locationString].InProgressCount++
    }
    else
    {
        # Failed or other non-success states
        $locationStats[$locationString].FailureCount++
    }
}

# Convert to sorted array of location statistics
Write-Log -LogFile $LogFile -Module $functionName -Message "Converting location statistics to sorted array with unique user/device counts" -LogLevel "Verbose"
$locationAnalysis = @($locationStats.GetEnumerator() | ForEach-Object {
        # Calculate unique users and devices for this location
        $locationEvents = $_.Value.Events
        $uniqueUsers = @($locationEvents | Where-Object { $_.userId -or $_.userPrincipalName } |
                ForEach-Object { if ($_.userId)
                    {
                        $_.userId
                    }
                    else
                    {
                        $_.userPrincipalName
                    } } |
                Select-Object -Unique).Count
            $uniqueDevices = @($locationEvents | Where-Object { $_.managedDeviceName -or $_.deviceId } |
                    ForEach-Object { if ($_.deviceId)
                        {
                            $_.deviceId
                        }
                        else
                        {
                            $_.managedDeviceName
                        } } |
                    Select-Object -Unique).Count

                [PSCustomObject]@{
                    Location         = $_.Key
                    Country          = $_.Value.Country
                    State            = $_.Value.State
                    City             = $_.Value.City
                    TotalEvents      = $_.Value.TotalEvents
                    SuccessCount     = $_.Value.SuccessCount
                    FailureCount     = $_.Value.FailureCount
                    InProgressCount  = $_.Value.InProgressCount
                    SuccessfulEvents = $_.Value.SuccessCount
                    FailedEvents     = $_.Value.FailureCount
                    InProgressEvents = $_.Value.InProgressCount
                    UniqueUsers      = $uniqueUsers
                    UniqueDevices    = $uniqueDevices
                    SuccessRate      = if ($_.Value.TotalEvents -gt 0)
                    {
                        [Math]::Round(($_.Value.SuccessCount / $_.Value.TotalEvents) * 100, 2)
                    }
                    else
                    {
                        0
                    }
                    FailureRate      = if ($_.Value.TotalEvents -gt 0)
                    {
                        [Math]::Round(($_.Value.FailureCount / $_.Value.TotalEvents) * 100, 2)
                    }
                    else
                    {
                        0
                    }
                    Events           = $_.Value.Events
                }
            } | Sort-Object -Property TotalEvents -Descending)

Write-Verbose "[$functionName] Location analysis complete: $($locationAnalysis.Count) unique locations"
Write-Log -LogFile $LogFile -Module $functionName -Message "Location analysis complete: $($locationAnalysis.Count) unique locations identified" -LogLevel "Information"

# Log top locations by event count
if ($locationAnalysis.Count -gt 0)
{
    $topLocations = $locationAnalysis | Select-Object -First 5
    Write-Log -LogFile $LogFile -Module $functionName -Message "Top locations by event count:" -LogLevel "Verbose"
    foreach ($loc in $topLocations)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "  $($loc.Location): $($loc.TotalEvents) events, $($loc.UniqueUsers) users, $($loc.UniqueDevices) devices (Success: $($loc.SuccessCount), Failure: $($loc.FailureCount), Success Rate: $($loc.SuccessRate)%)" -LogLevel "Verbose"
    }
}

Write-Log -LogFile $LogFile -Module $functionName -Message "Analysis complete: $totalEvents total events, $($successfulEvents.Count) successful, $($failedEvents.Count) failed, $($inProgressEvents.Count) in progress" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module $functionName -Message "In-progress breakdown: Device phase=$($devicePhaseInProgress.Count), User phase=$($userPhaseInProgress.Count)" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module $functionName -Message "Failure breakdown: Device only=$($devicePhaseOnlyFailures.Count), User only=$($userPhaseOnlyFailures.Count), Both=$($bothPhasesFailures.Count), Unknown=$($unknownPhaseFailures.Count)" -LogLevel "Information"
Write-Log -LogFile $LogFile -Module $functionName -Message "Users with multiple failures: $($usersWithMultipleFailures.Count), Single failure with success: $($singleFailureWithSuccess.Count)" -LogLevel "Verbose"

# Build result object
$result = [PSCustomObject]@{
    TotalEvents                 = $totalEvents
    TotalEventsBeforeFilter     = $Events.Count
    StartDate                   = $StartDate
    EndDate                     = $EndDate
    UserPrincipalName           = $UserPrincipalName
    EarliestEventDate           = $earliestDate
    SuccessfulEvents            = $successfulEvents
    SuccessCount                = $successfulEvents.Count
    InProgressEvents            = $inProgressEvents
    InProgressCount             = $inProgressEvents.Count
    DevicePhaseInProgress       = $devicePhaseInProgress
    DevicePhaseInProgressCount  = $devicePhaseInProgress.Count
    UserPhaseInProgress         = $userPhaseInProgress
    UserPhaseInProgressCount    = $userPhaseInProgress.Count
    FailedEvents                = $failedEvents
    FailureCount                = $failedEvents.Count
    AverageSuccessDuration      = $avgSuccessDuration
    AverageFailureDuration      = $avgFailureDuration
    DevicePhaseOnlyFailures     = $devicePhaseOnlyFailures
    DevicePhaseOnlyFailureCount = $devicePhaseOnlyFailures.Count
    UserPhaseOnlyFailures       = $userPhaseOnlyFailures
    UserPhaseOnlyFailureCount   = $userPhaseOnlyFailures.Count
    BothPhasesFailures          = $bothPhasesFailures
    BothPhasesFailureCount      = $bothPhasesFailures.Count
    UnknownPhaseFailures        = $unknownPhaseFailures
    UnknownPhaseFailureCount    = $unknownPhaseFailures.Count
    UsersWithMultipleFailures   = $usersWithMultipleFailures
    SingleFailureWithSuccess    = $singleFailureWithSuccess
    FailedDevicesChronological  = $failedDevicesSorted
    AllFilteredEvents           = $filteredEvents
    AllEvents                   = $Events
    SignInMatchStats            = $matchStats
    LocationAnalysis            = $locationAnalysis
    LocationAnalysisCount       = $locationAnalysis.Count
}

Write-Verbose "[$functionName] Analysis complete"
Write-Log -LogFile $LogFile -Module $functionName -Message "Autopilot event analysis completed successfully" -LogLevel "Information"
return $result
}
    Write-Log -LogFile $LogFile -Module $functionName -Message "Autopilot event analysis completed successfully" -LogLevel "Information"
    return $result
}

