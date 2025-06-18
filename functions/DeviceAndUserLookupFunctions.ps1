function GetVMAutopilotDeviceIdBySerialNumber() 
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write a verbose log  of receved parameters
    Write-Verbose "[$functionName] Received serial number: $serialNumber"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $autopilotDevices = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI).value
    Write-Verbose "[$functionName] Received $($autopilotDevices.Count) devices from Autopilot."
    for ($i = 0; $i -lt $autopilotDevices.Count; $i++)
    {
        $device = $autopilotDevices[$i]
        Write-Verbose "[$functionName] Processing device with serial number $($device.serialNumber)"
        $filteredDeviceSerialNumber = $device.serialNumber -replace '\s', ''
        Write-Verbose "[$functionName] Filtered device serial number: $filteredDeviceSerialNumber"
        if ($serialNumber -match '\s')
        {
            Write-Verbose "[$functionName] Also filtering input serial number $serialNumber since it contains spaces."
            $serialNumber = $serialNumber -replace '\s', ''
            Write-Verbose "[$functionName] Filtered input serial number: $serialNumber"
        }
        if ($filteredDeviceSerialNumber -eq $serialNumber)
        {
            Write-Verbose "[$functionName] Found a match for serial number $serialNumber in Autopilot."
            return $device.id
        }
        else
        {
            Write-Verbose "[$functionName] No match for serial number $serialNumber in Autopilot."
        }
    }
    Write-Verbose "[$functionName] Filtered device serial number: $filteredDeviceSerialNumber"
    return $null
}

function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [ValidateSet("clean", "wipe", "sync", "restart")]
        [string]$Command = "clean",
        [int]$MaxRetries = 20,
        [int]$RetryDelaySeconds = 15,
        [switch]$MonitorAction,
        [switch]$NoConfirmation
    )
    
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    $returnSuccessMessage = ''
    $returnFailureMessage = ''
    Write-Verbose "[$functionName] Device ID:     $ManagedDeviceId"
    Write-Verbose "[$functionName] Command: $Command"
    Write-Verbose "[$functionName] MaxRetries: $MaxRetries"
    Write-Verbose "[$functionName] RetryDelaySeconds: $RetryDelaySeconds"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        return $false
    }
    #endregion

    # Confirmation for destructive operations only
    if (-not $NoConfirmation -and ($Command -eq "clean" -or $Command -eq "wipe" -or $Command -eq "restart"))
    {
        Write-Host "Are you sure you want to $Command the device?" -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'yes' to confirm, or 'no' to cancel"
        if ($confirmation -ne 'yes')
        {
            Write-Host "Operation cancelled." -ForegroundColor Gray
            return $returnedValues.userCanceledMessage
        }
    }

    Write-Host "Sending $Command command to device with identifier $ManagedDeviceId" -ForegroundColor Cyan
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $actionType = ""
    $response = ""
    
    switch ($Command)
    {
        "clean"
        {
            Write-Host 'Cleaning the device...' -ForegroundColor Yellow
            $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
            $body = @{ 'keepUserData' = $false } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0' 
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "cleanWindows"
            $returnSuccessMessage = $returnValues.deviceCleanSuccessMessage
            $returnFailureMessage = $returnValues.deviceCleanFailedMessage
        }
        "wipe"
        {
            Write-Host 'Wiping the device...' -ForegroundColor Yellow
            $wipeURI = "$deviceManagementUri/wipe"
            $body = @{
                'keepEnrollmentData'   = $false
                'keepUserData'         = $false
                'obliterationBehavior' = "doNotObliterate"
            } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $wipeURI -body $body -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "wipe"
            $returnSuccessMessage = $returnValues.deviceWipeSuccessMessage
            $returnFailureMessage = $returnValues.deviceWipeFailedMessage
        }
        "sync"
        {
            Write-Host 'Syncing the device...' -ForegroundColor Yellow
            $syncUri = "$deviceManagementUri/syncDevice"
            $response = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "syncDevice"
            $returnSuccessMessage = $returnValues.deviceSyncSuccessMessage
            $returnFailureMessage = $returnValues.deviceSyncFailedMessage
        }
        "restart"
        {
            Write-Host 'Restarting the device...' -ForegroundColor Yellow
            $restartUri = "$deviceManagementUri/rebootNow"
            $response = callGraphApi -AccessToken $accessToken -Method 'POST' -ResourcePath $restartUri -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "rebootNow"
            $returnSuccessMessage = $returnValues.deviceRestartSuccessMessage
            $returnFailureMessage = $returnValues.deviceRestartFailedMessage
        }
        default
        {
            Write-Host "Invalid command. Please use 'clean', 'wipe', 'sync', or 'restart'." -ForegroundColor Red
            return $returnValues.unknownErrorMessage
        }
    }  

    # Report on action status for all operations
    if ($response -eq '')
    {
        Write-Host "Command sent successfully." -ForegroundColor Green
        # Only send additional sync for non-sync operations to avoid redundancy
        if ($Command -ne "sync")
        {
            Write-Host "Performing automatic device sync after $Command operation."
            $syncUri = "$deviceManagementUri/syncDevice"
            $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Sync Response: $syncResponse"
        }
        # Begin monitoring the action status
        if ($MonitorAction)            
        {
            Write-Host "Starting to monitor $Command action status..." -ForegroundColor Yellow
            $retryCount = 0
            $actionCompleted = $false
            $actionFailed = $false
            $actionState = "unknown"
            # Loop until action completes, fails, or max retries reached
            while (-not $actionCompleted -and -not $actionFailed -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Checking $Command status, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking action results (Attempt $retryCount of $MaxRetries)"
                # Wait before checking
                Write-Verbose "[$functionName] Waiting for $RetryDelaySeconds seconds before checking action status."
                Start-Sleep -Seconds $RetryDelaySeconds
                # Check action results
                $deviceDetails = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
                Write-Verbose "[$functionName] Device action results: $($deviceDetails | ConvertTo-Json -Depth 5)"
                Write-Host "Action results: $($deviceDetails.deviceActionResults)"
                if ($deviceDetails -and $deviceDetails.deviceActionResults)
                {
                    # Find the relevant action result based on action type
                    $actionResult = $null
                    foreach ($result in $deviceDetails.deviceActionResults)
                    {
                        if ($result.actionName -eq $actionType)
                        {
                            $actionResult = $result
                            break
                        }
                    }
                    if ($actionResult)
                    {
                        $actionState = $actionResult.status
                        Write-Host "Current $Command status: $actionState" -ForegroundColor Cyan
                        Write-Verbose "[$functionName] Action start time: $($actionResult.startDateTime)"
                        Write-Verbose "[$functionName] Action last updated: $($actionResult.lastUpdatedDateTime)"
                        # Check if action completed or failed
                        switch ($actionState)
                        {
                            "succeeded"
                            {
                                Write-Host "$Command action completed successfully!" -ForegroundColor Green
                                $actionCompleted = $true
                            }
                            "failed"
                            {
                                Write-Host "$Command action failed with error: $($actionResult.errorCode)" -ForegroundColor Red
                                if ($actionResult.errorDescription)
                                {
                                    Write-Host "Error description: $($actionResult.errorDescription)" -ForegroundColor Red
                                }
                                $actionFailed = $true
                            }
                            "timeout"
                            {
                                Write-Host "$Command action timed out." -ForegroundColor Red
                                $actionFailed = $true
                            }
                            "canceled"
                            {
                                Write-Host "$Command action was canceled." -ForegroundColor Red
                                $actionFailed = $true
                            }
                            "notFound"
                            {
                                Write-Verbose "[$functionName] Action not found yet or device may no longer be available."
                                if ($retryCount -gt 3)
                                {
                                    Write-Verbose "[$functionName] Action not found after multiple attempts, assuming device is no longer available."
                                    $actionFailed = $false
                                }
                            }
                            default
                            {
                                Write-Verbose "[$functionName] Action status is '$actionState', continuing to monitor."
                                # Continue monitoring for non-terminal states
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] No action of type '$actionType' found yet."
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] No device action results available or device might be offline/no longer accessible."
                    # If we can no longer get device details, check if device still exists
                    $deviceCheck = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0'
                    if (-not $deviceCheck)
                    {
                        Write-Host "Device is no longer accessible. This could be expected for wipe operations." -ForegroundColor Yellow
                        # For wipe operations, this might be expected behavior as device is reset
                        if ($Command -eq 'wipe')
                        {
                            Write-Host "Wipe command appears to have succeeded as device is no longer accessible." -ForegroundColor Green
                            $actionCompleted = $true
                        }
                    }
                }
            }
            # Final status report
            if ($actionCompleted)
            {
                Write-Host "$Command action has completed successfully." -ForegroundColor Green
                return $returnSuccessMessage
            }
            elseif ($actionFailed)
            {
                Write-Host "$Command action has failed with status: $actionState" -ForegroundColor Red
                return $returnFailureMessage
            }
            else
            {
                Write-Host "$Command action monitoring timed out after $MaxRetries attempts." -ForegroundColor Yellow
                Write-Host "Last known status: $actionState" -ForegroundColor Yellow
                Write-Warning "The action may still be in progress. You can check the device status in the Intune portal."
                return $returnValues.deviceUnknownActionMessage
            }
        }
        else
        {
            Write-Verbose "[$functionName] Monitoring not enabled, skipping action status checks."
            return $returnSuccessMessage
        }
    }
    else
    {
        Write-Host "Failed to send $Command command to device." -ForegroundColor Red
        Write-Verbose "[$functionName] Failed to send command. Response: $response"
        return $returnFailureMessage
    }
}

function GetDeviceIdFromSerial()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    #region Variables and verbose logs    
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    $filter = "serialNumber eq '$SerialNumber'"
    $extraParameters = "select=Id"
    $device = $null
    Write-Verbose "[$functionName] Serial Number: $SerialNumber"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        return $false
    }
    #endregion    # Query the device enrollment status using Microsoft Graph API
    # Fetch the device details using the serial number
    $response = CallGraphApi -AccessToken $AccessToken -ResourcePath $managedDeviceUri -filter $filter -ExtraParameters $extraParameters -Method GET
    if ($response)
    {
        $device = $response.value.Id
        Write-Verbose "[$functionName] Device found with ID: $($device)"
    }
    else
    {
        Write-Verbose "[$functionName] Device with serial number $SerialNumber not found."
    }
    return $device
}

function VerifyGroupMembership()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$userName,
        [Parameter()]
        [string[]]$groupsToInclude,
        [Parameter()]
        [string[]]$groupsToExclude
    )

    #region Initialize result object and logging
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting VerifyGroupMembership function"

    # Create a consistent return object structure that will always be returned
    $result = [PSCustomObject]@{
        Success         = $false
        UserInfo        = $null
        MissingGroups   = @()
        ForbiddenGroups = @()
        UserGroups      = @()
        Error           = $null
    }

    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] Access token is empty or null"
        Write-Host "Access token is required." -ForegroundColor Red
        $result.Error = "Access token is required."
        return $result
    }

    Write-Verbose "[$functionName] User name: $userName"
    Write-Verbose "[$functionName] Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })"
    Write-Verbose "[$functionName] Groups to exclude count: $(if ($groupsToExclude) { $groupsToExclude.Count } else { 0 })"
    
    if ($groupsToInclude)
    {
        Write-Verbose "[$functionName] Groups to include: $($groupsToInclude -join ', ')"
    }
    
    if ($groupsToExclude)
    {
        Write-Verbose "[$functionName] Groups to exclude: $($groupsToExclude -join ', ')"
    }
    #endregion
    
    #region Get user information
    try
    {
        Write-Verbose "[$functionName] Getting user information for $userName"
        $userUri = "users/$($userName)" 
        $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri -extraparameters "select=displayName,mail,userPrincipalName,id"
        # Check if user was found
        if ($user -is [string] -and $user -match '^\d+$')
        {
            Write-Verbose "[$functionName] User $userName not found in Azure AD (Error code: $user)"
            Write-Host "The user $userName was not found in Azure AD." -ForegroundColor Red
            Write-Host "Please check the user name and try again." -ForegroundColor Red
            $result.Error = "User not found in Azure AD (Error code: $user)"
            return $result
        }
        $result.UserInfo = $user
        Write-Verbose "[$functionName] Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting user information: $_"
        Write-Host "Error getting user information: $_" -ForegroundColor Red
        $result.Error = "Error getting user information: $_"
        return $result
    }
    #endregion
    
    #region Get group membership
    try
    {
        Write-Verbose "[$functionName] Getting group membership for user $userName"
        Write-Host "Getting group membership for user $userName ($($user.displayName))."
        $groupUri = "users/$($userName)/memberOf/microsoft.graph.group"
        $groupSelection = "select=displayName&top=999&orderby=displayName"
        $response = CallGraphAPI -accessToken $accessToken -ResourcePath $groupUri -extraparameters $groupSelection
        if ($response -is [string] -and $response -match '^\d+$')
        {
            Write-Verbose "[$functionName] Failed to get group membership (Error code: $response)"
            Write-Host "The group membership for $userName could not be determined." -ForegroundColor Red
            Write-Host "Please try again or contact an Intune administrator." -ForegroundColor Red
            $result.Error = "Failed to get group membership (Error code: $response)"
            return $result
        }
        $groups = $response.value | Select-Object -ExpandProperty displayName | Sort-Object
        $result.UserGroups = $groups
        Write-Verbose "[$functionName] User $userName is a member of $($groups.Count) groups"
        Write-Host "User $userName is a member of $($groups.Count) groups."
        Write-Verbose "[$functionName] Groups: $($groups -join ', ')"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting group membership: $_"
        Write-Host "Error getting group membership: $_" -ForegroundColor Red
        $result.Error = "Error getting group membership: $_"
        return $result
    }
    #endregion
    
    #region Check include group membership
    $missingGroups = @()
    if ($null -eq $groupsToInclude -or $groupsToInclude.Count -eq 0)
    {
        Write-Verbose "[$functionName] No groups to include were specified. Skipping this check."
    }
    else
    {
        Write-Verbose "[$functionName] Checking memberships for user $userName in $($groupsToInclude.Count) required groups"
        foreach ($group in $groupsToInclude)
        {
            Write-Verbose "[$functionName] Checking membership in required group: $group"
            if ($groups -notcontains $group)
            {
                Write-Verbose "[$functionName] User $userName is NOT a member of the required group: $group"
                $missingGroups += $group
            }
            else
            {
                Write-Verbose "[$functionName] User $userName is a member of the required group: $group"
            }
        }
        $result.MissingGroups = $missingGroups
        if ($missingGroups.Count -gt 0)
        {
            Write-Verbose "[$functionName] User $userName is missing membership in $($missingGroups.Count) required groups: $($missingGroups -join ', ')"
        }
        else
        {
            Write-Verbose "[$functionName] User $userName is a member of all required groups"
        }
    }
    #endregion
    
    #region Check exclude group membership
    $forbiddenGroups = @()
    if ($null -eq $groupsToExclude -or $groupsToExclude.Count -eq 0)
    {
        Write-Verbose "[$functionName] No groups to exclude were specified. Skipping this check."
    }
    else
    {
        Write-Verbose "[$functionName] Checking user $userName isn't in $($groupsToExclude.Count) excluded groups"
        foreach ($group in $groupsToExclude)
        {
            Write-Verbose "[$functionName] Checking membership in excluded group: $group"
            if ($groups -contains $group)
            {
                Write-Verbose "[$functionName] User $userName is a member of the excluded group: $group (should not be)"
                $forbiddenGroups += $group
            }
            else
            {
                Write-Verbose "[$functionName] User $userName is not a member of the excluded group: $group (correct)"
            }
        }
        $result.ForbiddenGroups = $forbiddenGroups
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Verbose "[$functionName] User $userName is a member of $($forbiddenGroups.Count) excluded groups: $($forbiddenGroups -join ', ')"
        }
        else
        {
            Write-Verbose "[$functionName] User $userName is not a member of any excluded groups"
        }
    }
    #endregion
    
    #region Determine result and return
    if ($missingGroups.Count -eq 0 -and $forbiddenGroups.Count -eq 0)
    {
        Write-Verbose "[$functionName] User $userName has correct group memberships"
        $result.Success = $true
    }
    else
    {
        Write-Verbose "[$functionName] User $userName does not have correct group memberships"
        $result.Success = $false
        if ($missingGroups.Count -gt 0)
        {
            Write-Host "User $userName is missing membership in the following required groups: $($missingGroups -join ', ')" -ForegroundColor Yellow
        }
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Host "User $userName is a member of the following forbidden groups: $($forbiddenGroups -join ', ')" -ForegroundColor Yellow
        }
    }
    Write-Verbose "[$functionName] Completed VerifyGroupMembership function with Success=$($result.Success)"
    return $result
    #endregion
}

function GetTotalRegisteredDevicesByUser()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserName,
        [parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $Uri = "users/$userName/registeredDevices"
    Write-Verbose "[$functionName] Getting total registered devices for user: $UserName"
    if ($null -eq $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return 0
    }
    Write-Verbose "[$functionName] AccessToken provided."
    $registeredDevices = (CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri).value
    Write-Verbose "[$functionName] Registered devices count: $($registeredDevices.Count)"
    if ($registeredDevices -and $registeredDevices.Count -gt 0)
    {
        Write-Verbose "[$functionName] Returning count of registered devices: $($registeredDevices.Count)"
        return $registeredDevices.Count
    }
    else
    {
        Write-Verbose "[$functionName] No registered devices found for user: $UserName"
        return 0
    }
}

function GetEntraUser()    
{
    [CmdletBinding()]
    param (
        [string]$accessToken,
        [string]$UserName,
        [switch]$FindSimilar
    )

    $functionName = $MyInvocation.MyCommand.Name
    $substringSearch = $false
    Write-Verbose "[$functionName] Starting function to get user from Entra ID"
    # Validate access token
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return $returnValues.noAccessTokenMessage
    }
    Write-Verbose "[$functionName] Attempting exact match for userPrincipalName: $UserName"
    $userUri = "users/$UserName"
    $userExtraParameters = "select=givenName,surName,displayName,userPrincipalName,mail,id"    
    $userInfo = CallGraphAPI -accessToken $AccessToken -ResourcePath $userUri -extraParameters $userExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($userInfo | Out-String)"
    
    if ($userInfo -notin 400, 401, 403, 404)
    {
        Write-Verbose "[$functionName] Exact match found for userPrincipalName: $UserName"
        Write-Verbose "[$functionName] User found: $($userInfo.displayName) ($($userInfo.userPrincipalName))"
        
        # Create a response object in the same format as Graph API for consistency
        $exactMatchResponse = [PSCustomObject]@{
            '@odata.context' = $null
            value            = @($userInfo)  # Force array creation even for single item
        }
        
        return $exactMatchResponse, $substringSearch
    }
    
    # Handle error cases - show error message only if FindSimilar is not enabled
    if ($userInfo -in 400, 401, 403, 404 -and -not $FindSimilar)
    {
        Write-Verbose "[$functionName] Exact match failed with error code: $userInfo"
        
        # Display appropriate error message to user based on error code
        switch ($userInfo)
        {
            400 { Write-Host "Bad request. Please check the username format." -ForegroundColor Red }
            401 { Write-Host "Unauthorized. Please check your access token." -ForegroundColor Red }
            403 { Write-Host "Forbidden. You do not have permission to access this user." -ForegroundColor Red }
            404 { Write-Host "User '$UserName' not found in Entra ID." -ForegroundColor Red }
        }
        
        return $returnValues.noUserFoundInDirectoryMessage
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $userInfo). Performing substring search using Graph API search."
        # Remove the @ portion from the username if it exists for better search results
        $searchTerm = $UserName -replace '@.*$', ''
        Write-Verbose "[$functionName] Cleaned search term: $searchTerm"
        $searchUri = "users"
        $filterExpression = "startswith(givenName, '$searchTerm') or startsWith(surname, '$searchTerm')"
        Write-Verbose "[$functionName] Searching for substring matches in user properties for: $searchTerm"
        Write-Verbose "[$functionName] Trying filter: $filterExpression" 
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $userExtraParameters
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            $substringSearch = $true
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            # Initialize filtered results array
            $filteredUsers = @()
            # Filter out excluded users
            foreach ($user in $fallbackResults.value)
            {
                #Check if the user is a duplicate record of a previous record
                Write-Verbose "[$functionName] Processing user: $($user.displayName) ($($user.userPrincipalName))"
                if ($filteredUsers -contains $user.userPrincipalName)
                {
                    Write-Verbose "[$functionName] User $($user.userPrincipalName) is a duplicate, skipping."
                    continue
                }
                $excludeUser = $false
                # Check if any of the exclusion patterns match this user
                Write-Verbose "Checking against $($settings.userPatternsToExclude.Count) patterns to exclude."
                if ($settings.userPatternsToExclude -and $settings.userPatternsToExclude.Count -gt 0)
                {
                    foreach ($pattern in $settings.userPatternsToExclude)
                    {
                        Write-Verbose "[$functionName] Checking user: $($user.displayName) ($($user.userPrincipalName)) against exclusion pattern: $pattern"
                        if ($user.userPrincipalName.Contains($pattern) -or $user.displayName -match $pattern)
                        {
                            # If the user matches any exclusion pattern, mark them for exclusion
                            Write-Verbose "[$functionName] User matches exclusion pattern: $pattern"
                            Write-Verbose "[$functionName] Excluding user: $($user.displayName) ($($user.userPrincipalName)) - Matched exclusion pattern: $pattern"
                            $excludeUser = $true
                            break
                        }
                    }
                }
                # Add user to filtered results if not excluded
                if (-not $excludeUser)
                {
                    Write-Verbose "[$functionName] Including user: $($user.displayName) ($($user.userPrincipalName))"
                    $filteredUsers += $user
                }
            }            # Create a response object in the same format as the original Graph API response
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredUsers | Sort-Object -Property userPrincipalName -Unique)  # Force array creation
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique users after exclusions"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            return $returnValues.noUserFoundInDirectoryMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] No matches found for userPrincipalName: $UserName"
        return $returnValues.noUserFoundInDirectoryMessage
    }
}

function GetDeviceByUser()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserName,
        [parameter(Mandatory = $true)]
        [string]$OperatingSystem,
        [parameter(Mandatory = $true)]
        [string]$AccessToken
    )    
    
    #region write verbose log of all parameters
    $functionName = $MyInvocation.MyCommand.Name    
    Write-Verbose "[$functionName] UserName: $UserName"
    Write-Verbose "[$functionName] Operating system: $OperatingSystem"
    if ($null -ne $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        return $null
    }
    $UserName = $UserName.Trim()
    Write-Verbose "[$functionName] Trimmed user name: $UserName"
    $extraparameters = "select=deviceName,serialNumber,userDisplayName,model,manufacturer,complianceState"
    Write-Verbose "[$functionName] Extra parameters for API call: $extraparameters"
    $filter = "startswith(userPrincipalName,'$UserName') and operatingSystem eq '$OperatingSystem'"
    Write-Verbose "[$functionName] Filter for API call: $filter"
    $managedDeviceUri = "deviceManagement/managedDevices"
    Write-Verbose "[$functionName] Managed device URI: $managedDeviceUri"
    #endregion

    $deviceInfo = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -Filter $filter -extraParameters $extraparameters
    Write-Verbose "[$functionName] Device value count: $($deviceInfo.value.Count)"
    Write-Verbose "[$functionName] Device Info: $($deviceInfo | Out-String)"
    if ($deviceInfo -notin 400, 401, 403, 404)
    {
        if ($deviceInfo.value.Count -eq 0)
        {
            Write-Verbose "[$functionName] No devices found for user: $UserName"
            return $returnValues.noDeviceFound
        }
        elseif ($deviceInfo.value.Count -eq 1)
        {
            # If only one device found, return its serial number directly
            Write-Host "Found one device for user: $UserName ($($deviceInfo.value[0].userDisplayName))." -ForegroundColor Green
            Write-Host "Device Name: $($deviceInfo.value[0].deviceName)" -ForegroundColor Cyan
            Write-Host "Serial Number: $($deviceInfo.value[0].serialNumber)."
            Write-Host "Device make and model: $($deviceInfo.value[0].manufacturer) $($deviceInfo.value[0].model)."
            Write-Host "Compliance state: $($deviceInfo.value[0].complianceState)."
            return $deviceInfo.value[0].serialNumber
        }
        else
        {
            # Create device selection menu
            $deviceMenu = NewMenu -Title "Device Selection" -Description "Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))"
            # Store devices in an array to reference later
            $devices = $deviceInfo.value
            Write-Verbose "[$functionName] Creating device menu with $($devices.Count) devices"
            # Add each device as a menu item
            foreach ($device in $devices)
            {
                # Create a display name for the menu
                $menuItemName = "Device: $($device.deviceName) ($($device.manufacturer) $($device.model) SN: $($device.serialNumber)) ($($device.complianceState))"
                Write-Verbose "[$functionName] Adding menu item: $menuItemName"
                # Create a scriptblock action that returns this specific device's serial number when selected
                $serialNumber = $device.serialNumber
                Write-Verbose "[$functionName] Creating action for serial number: $serialNumber"
                $action = {
                    Write-Verbose "[$functionName] Returning Serial Number: $serialNumber"
                    return $serialNumber
                }.GetNewClosure()
                # Add the menu item with the action
                $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $menuItemName -Action $action -ReturnsValue
            }
            Write-Verbose "[$functionName] Showing device selection menu with $($deviceMenu.Items.Count) items"
            Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
            Write-Verbose "[$functionName] Current menu title: $($deviceMenu.Title)"
            $selectedSerialNumber = ShowMenu -Menu $deviceMenu -CalledBy 'Action'
            if ($null -ne $selectedSerialNumber -and $selectedSerialNumber -is [string])
            {
                Write-Verbose "[$functionName] Selected serial number: $selectedSerialNumber"
            }
            else
            {
                Write-Verbose "[$functionName] Selected serial number is null or not a string"
            }
            
            # Validate that we got a proper serial number, not a navigation option
            if ($selectedSerialNumber -eq "Back" -or $selectedSerialNumber -eq "Main Menu" -or $selectedSerialNumber -eq 0 -or $selectedSerialNumber -eq "0")
            {
                Write-Verbose "[$functionName] ShowMenu returned navigation option: '$selectedSerialNumber', treating as navigation"
                return $selectedSerialNumber
            }
            
            Write-Verbose "[$functionName] Returning valid selected serial number: $selectedSerialNumber"
            return $selectedSerialNumber
            # #region Additional validation: check if the returned value is actually a serial number from one of our devices
            ##This section may be removed in the future if we are confident that ShowMenu always returns a valid serial number
            # $isValidSerialNumber = $false
            # foreach ($device in $devices)
            # {
            #     if ($selectedSerialNumber -match $device.serialNumber)
            #     {
            #         $selectedSerialNumber = $device.serialNumber
            #         Write-Verbose "[$functionName] Valid serial number found: $selectedSerialNumber"
            #         $isValidSerialNumber = $true
            #         break
            #     }
            # }
            # if (-not $isValidSerialNumber)
            # {
            #     Write-Verbose "[$functionName] ShowMenu returned invalid serial number: '$selectedSerialNumber', this might be a navigation option or error"
            #     Write-Warning "Unexpected return value from device selection: '$selectedSerialNumber'. Please try again."
            #     return $null
            # }            
            # Write-Verbose "[$functionName] Returning valid selected serial number: $selectedSerialNumber"
            # return $selectedSerialNumber
            # #endregion
        }
    }
    else
    {
        Write-Host "An error occured looking up device for user: $UserName" -ForegroundColor Red
        return $returnValues.noDeviceFound
    }
}

function GetDeviceEnrollmentStatus()
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken,
        $settings = $settings
    )

    #region Define variables
    $FunctionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Serial Number: $serialNumber"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Received Access Token"
    }
    $imported = $false
    $inManagedDevices = $false
    $inAutopilot = $false
    $hasDeviceObject = $false
    $azureUser = $false
    $hasUserObject = $false
    $hasUser = $false
    $returnedImportedDevice = [ordered] @{}
    $returnedAutopilotDevice = [ordered] @{}
    $returnedManagedDevice = [ordered] @{}
    $returnedDevice = [ordered] @{}
    $returnedAutopilotEvents = [ordered] @{}
    $loggedOnUsers = [ordered] @{}
    $deviceState = [ordered] @{}
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $autopilotEventsURI = "deviceManagement/autopilotEvents"
    $deviceManagementUri = "deviceManagement/managedDevices"
    $deviceUri = "devices"
    $userUri = "users"
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $deviceHardwareExtraparameters = "select=hardwareInformation,physicalMemoryInBytes"
    $isVMWareDevice = $false
    #endregion

    #region Get the autopilot device info
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "[$functionName] VMware device detected."
        $isVMWareDevice = $true
        # $autopilotDeviceFilter = "AzureActiveDirectoryDeviceId eq '$($managedDevice.AzureAdDeviceId)'"
        # Alternative approach if the above doesn't work
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)'"
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)' or AzureActiveDirectoryDeviceId eq '$AzureActiveDirectoryDeviceId'"
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "[$functionName] Received $($autoPilotVMDevice.count) devices from Autopilot."
        if ($autoPilotVMDevice -and $autoPilotVMDevice.count -gt 0)
        {
            Write-Verbose "[$functionName] Got an Autopilot Device with device id $($autoPilotVMDevice)"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $params = @{
                AccessToken  = $accessToken
                ResourcePath = $autopilotDeviceUriWithId
            }
        }
        else
        {
            Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
        }
    }
    else
    {
        Write-Verbose "[$functionName] Not a VMWare device. Continuing"
        $params = @{
            AccessToken  = $accessToken
            ResourcePath = $autoPilotDeviceURI
            Filter       = $autopilotDeviceFilter
        }
    }
    if ($null -ne $params)
    {
        $autopilotDeviceResponse = CallGraphAPI @params
    }
    Write-Verbose "[$functionName] Autopilot Device Response: $($autopilotDeviceResponse | Out-String)"
    Write-Verbose "[$functionName] Autopilot Device Response Count: $($autopilotDeviceResponse.'@odata.count')"
    if ($null -ne $autopilotDeviceResponse -and $autopilotDeviceResponse.'@odata.count' -gt 0)
    {
        Write-Verbose "[$functionName] Got a device count of $($autopilotDeviceResponse.'@odata.count') from Autopilot."
        $autopilotDevice = $autopilotDeviceResponse.value
    }
    elseif ($isVMWareDevice -and $null -ne $autopilotDeviceResponse -and ($null -ne $autopilotDeviceResponse.id -and $autopilotDeviceResponse.id -ne ''))
    {
        Write-Verbose "[$functionName] Got a single autopilot device with id $($autopilotDeviceResponse.id)"
        $autopilotDevice = $autopilotDeviceResponse
    }
    else
    {
        Write-Verbose "[$functionName] Did not get a good response for device with serial number $serialNumber"
        $inAutopilot = $false
    }
    if ($autopilotDevice)
    {
        $inAutopilot = $true
        Write-Verbose "[$functionName] Getting deployment profile information for device with serial number $($autopilotDevice.serialNumber)"
        # $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)?`$expand=deploymentProfile(`$select=displayName)"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)?`$expand=deploymentProfile"
        $autopilotDevice = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -APIVersion 'beta' 
        Write-Verbose "[$functionName] Got $($autopilotDevice.count) devices from Autopilot."
        Write-Verbose "[$functionName] Enrollment Profile name: $($autopilotDevice.deploymentProfile.displayname)"
        Write-Verbose "[$functionName] Device is in Autopilot: $inAutopilot to true."
        $returnedAutopilotDevice = $autopilotDevice 
        Write-Verbose "[$functionName] Getting latest events for device with serial number $($autopilotDevice.serialNumber)"
        $autopilotDeviceEventsFilter = "deviceSerialNumber eq '$($autopilotDevice.serialNumber)'"
        $autopilotEvents = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotEventsURI -filter $autopilotDeviceEventsFilter
        Write-Verbose "[$functionName] Found $($autopilotEvents.value.count) Autopilot events."
        if ($autopilotEvents)
        {
            Write-Verbose "[$functionName] Returning $($autopilotEvents.value.count) Events found for device with serial number $($autopilot.serialNumber)"
            $returnedAutopilotEvents = ($autopilotEvents | Sort-Object createdDateTime -Descending).value 
            Write-Verbose "[$functionName] Autopilot Events: $($returnedAutopilotEvents.count)"
        }
        else
        {
            Write-Verbose "[$functionName] No events found for device in Autopilot"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Device is not an autopilot device."
        $inAutopilot = $false
    }
    if ($autopilotDevice)
    {
        Write-Verbose "[$functionName] Getting imported Autopilot device info for serial number $($autopilotDevice.serialNumber) from autopilot object."
        $importedDeviceFilter = "serialNumber eq '$($autopilotDevice.serialNumber)'"
    }
    else
    {
        Write-Verbose "[$functionName] Getting imported Autopilot device info for serial number $serialNumber from serial number."
        $importedDeviceFilter = "serialNumber eq '$serialNumber'"
        $importedAutopilotDeviceResult = CallGraphAPI -AccessToken $accessToken -ResourcePath $importedAutopilotDeviceURI -Filter $importedDeviceFilter
        $importedAutopilotDevice = $importedAutopilotDeviceResult.value
        Write-Verbose "[$functionName] Returned Imported Autopilot Device serial number: $($autopilotDevice.serialNumber)"
        if ($importedAutopilotDevice)
        {
            Write-Verbose "[$functionName] Device found in Imported Autopilot device list with serial number $($importedAutopilotDevice.serialNumber)"
            $imported = $true
            $returnedImportedDevice = $importedAutopilotDevice
        }
        else
        {
            Write-Verbose "[$functionName] Device not found in the list of imported Autopilot devices"
            Write-Verbose "[$functionName] This means the device may have already been registered."
        }
    }
    #endregion

    #region Get the managed device info
    #If the serial number contains spaces, remove them.
    if ($serialNumber -match '\s')
    {
        Write-Verbose "[$functionName] Serial number contains spaces. Removing them."
        $serialNumber = $serialNumber -replace '\s', ''
    }
    $managedDeviceFilter = "serialNumber eq '$serialNumber'"
    $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -Filter $managedDeviceFilter).value
    Write-Verbose "[$functionName] Device serial number: $($managedDevice.serialNumber)"
    if ($managedDevice)
    {
        Write-Verbose "[$functionName] Device found in Intune with serial number $($managedDevice.serialNumber)"
        $inManagedDevices = $true
        $returnedManagedDevice = $managedDevice
        Write-Verbose "[$functionName] Checking device memory information."
        $hardwareResourcePath = "$deviceManagementUri/$($autopilotDevice.managedDeviceId)" 
        Write-Verbose "[$functionName] Calling graph using the path $hardwareResourcePath with the extra parameters         $deviceHardwareExtraparameters"
        $deviceMemory = (CallGraphAPI -AccessToken $accessToken -ResourcePath $hardwareResourcePath -APIVersion 'beta' -ExtraParameters $deviceHardwareExtraparameters).physicalMemoryInBytes
        Write-Verbose "[$functionName] Device memory in bytes: $deviceMemory"
        if ($deviceMemory -gt 0) 
        {   
            Write-Verbose "[$functionName] Converting memory to gigabytes."
            $deviceMemory = [math]::round($deviceMemory / 1GB, 2)
            Write-Verbose "[$functionName] Device memory: $deviceMemory GB"
        }
        else
        {
            Write-Verbose "Device memory not found."
            $deviceMemory = $null
        }
        Write-Verbose "[$functionName] Got device memory: $deviceMemory"
        Write-Verbose "[$functionName] Checking for logged on users for device with serial number $($managedDevice.serialNumber)"
        Write-Verbose "[$functionName] managedDevice.usersLoggedOn: $($managedDevice.usersLoggedOn)"
        Write-Verbose "[$functionName] managedDevice.userPrincipalName: $($managedDevice.userPrincipalName)"
        Write-Verbose "[$functionName] managedDevice.emailAddress: $($managedDevice.emailAddress)"
        Write-Verbose "[$functionName] ManagedDevice.userDisplayName: $($managedDevice.userDisplayName)"
        if ($nnull -ne $managedDevice.usersLoggedOn )
        {
            Write-Verbose "[$functionName] Device has logged on users."
            $hasUserObject = $true
            $hasUser = $true
            $lastLogonDateTime = $managedDevice.usersLoggedOn.lastLogonDateTime
            Write-Verbose "[$functionName] Last logon date: $lastLogonDateTime"
        }
        elseif ($null -ne $managedDevice.userPrincipalName -and $managedDevice.userPrincipalName -match $settings.domain)
        {
            Write-Verbose "[$functionName] Device has a userPrincipalName."
            $azureUser = $true
            $hasUser = $true
            Write-Verbose "[$functionName] The last logon date is unavailable."
        }
        elseif ($null -ne $managedDevice.emailAddress -and $managedDevice.userPrincipalName -match $settings.domain) 
        {
            Write-Verbose "[$functionName] Device has an email address."
            $azureUser = $true
            $hasUser = $true
            Write-Verbose "[$functionName] The last logon date is unavailable."
        }
        else
        {
            Write-Verbose "[$functionName] No associated users found for device in Intune"
        }
        if ($hasUser -and $hasUserObject -eq $false)
        {
            Write-Verbose "[$functionName] No user object detected.  Returning device values."
            if ($managedDevice.userPrincipalName -match $settings.domain)
            {
                Write-Verbose "[$functionName] User is an Azure AD user"
                $azureUser = $true
            }
            else
            {
                Write-Verbose "[$functionName] User is not an Azure AD user"
            }
            $loggedOnUsers = @{
                AzureUser         = $azureUser
                lastLogOnDateTime = $lastLogonDateTime
                userDisplayName   = $managedDevice.userDisplayName
                userPrincipalName = $managedDevice.userPrincipalName
                emailAddress      = $managedDevice.emailAddress
            }
        }
        if ($hasUserObject)
        {
            Write-Verbose "[$functionName] Retrieving the logged on user for device with serial number $($managedDevice.serialNumber) and ID $($managedDevice.Id)"
            Write-Verbose "[$functionName] Passing $deviceManagementUri/$($managedDevice.Id)/$userUri to graph."
            $user = (CallGraphAPI -AccessToken $accessToken -ResourcePath "$deviceManagementUri/$($managedDevice.Id)/$userUri" -APIVersion 'beta').value
            Write-Verbose "[$functionName] User Display Name: $($user.displayName)"
            Write-Verbose "[$functionName] userPrincipalName: $($user.userPrincipalName)"
            if ($user.userPrincipalName -match $settings.domain)
            {
                Write-Verbose "[$functionName] User is an Azure AD user"
                $azureUser = $true
            }
            else
            {
                Write-Verbose "[$functionName] User is not an Azure AD user"
            }
            $loggedOnUsers = @{
                AzureUser         = $azureUser
                lastLogOnDateTime = $lastLogonDateTime
                userDisplayName   = $user.displayName
                userPrincipalName = $user.userPrincipalName
                emailAddress      = $user.emailAddress
                user              = $user
            }
            Write-Verbose "[$functionName] LoggedOn Users: $($loggedOnUsers.Count)"
        }
        else
        {
            Write-Verbose "[$functionName] No logged on users found for device in Intune"
        }
        $laps = GetDeviceLAPSCredentials -DeviceId $managedDevice.azureADDeviceId -accessToken $accessToken -quiet
        if ($null -ne $laps -and $laps -ne $returnValues.noLAPSFoundMessage)
        {
            Write-Verbose "[$functionName] LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        }
        else
        {
            Write-Verbose "[$functionName] No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Intune"
    }
    #Getting the unmanaged device object from Intune
    if ($managedDevice )
    {
        Write-Verbose "[$functionName] Looking up device with Azure Active Directory id $($managedDevice.azureActiveDirectoryDeviceId)"
        $deviceId = $managedDevice.azureActiveDirectoryDeviceId
        $deviceFilter = "deviceId eq '$deviceId'"
    }
    else
    {
        Write-Verbose "[$functionName] Attempting to find device with serial number."
        $deviceFilter = "endswith(displayName, '$serialNumber')"
    }
    $device = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceUri -filter $deviceFilter -consistencyLevel).value
    if ($device -and $device.count -gt 0)
    {
        Write-Verbose "[$functionName] Device found in Intune with serial number $($device.serialNumber)"
        $hasDeviceObject = $true
        $returnedDevice = $device
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Intune"
    }
    #endregion
    
    #region Verbose logging
    if ($inAutopilot)
    {
        Write-Verbose "[$functionName] Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Autopilot Registered: $inAutopilot"
        if ($returnedAutopilotEvents)
        {
            Write-Verbose "[$functionName] The device has had $($returnedAutopilotEvents.count) events."
        }
        else
        {
            Write-Verbose "[$functionName] No Autopilot events found"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Autopilot"
    }
    if ($inManagedDevices)
    {
        Write-Verbose "[$functionName] Device is managed in Intune with serial number $($device.serialNumber)"
        Write-Verbose "[$functionName] Device managed: $inManagedDevices"
    }
    else
    {
        Write-Verbose "[$functionName] Device not managed in Intune"
    }
    if ($imported)
    {
        Write-Verbose "[$functionName] Device is imported into Autopilot with serial number $($importedAutopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Device Imported: $imported"
    }
    else
    {
        Write-Verbose "[$functionName] Device not imported into Autopilot"
    }
    if ($hasDeviceObject)
    {
        Write-Verbose "[$functionName] Device found in Intune with display name: $($device.displayName)"
        Write-Verbose "[$functionName] Device has device object: $hasDeviceObject"
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Intune"
    }
    #endregion

    #region return values
    $deviceState.Add('InAutopilot', $inAutopilot)
    $autopilotData = [ordered] @{
        Device = $returnedAutopilotDevice
        Events = $returnedAutopilotEvents
    }
    $deviceState.add('autopilot', $autopilotData)
    $deviceState.add('Managed', $inManagedDevices)
    $managedDeviceData = [ordered] @{
        Device = $returnedManagedDevice
        Memory = $deviceMemory
        Users  = $loggedOnUsers
        LAPS   = $laps
    }
    $deviceState.add('managedDevice', $managedDeviceData)
    $deviceState.add('imported', $imported)
    $deviceState.add('importedAutopilotDevice', $returnedImportedDevice)
    $deviceState.add('hasDeviceObject', $hasDeviceObject)
    $deviceState.add('device', $returnedDevice)
    #endregion
    $global:enrollment = $deviceState
    return $deviceState
}

function GetDeviceLAPSCredentials()
{
    [CmdletBinding()]
    param (
        [string]$DeviceId,
        [string]$accessToken,
        [switch]$quiet
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting LAPS credentials for device with ID: $DeviceId"
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return $returnValues.noAccessTokenMessage
    }
    $returnObject = @{}
    $lapsUri = "directory/deviceLocalCredentials/$DeviceId"
    Write-Verbose "[$functionName] LAPS URI: $lapsUri"
    $extraParameters = "select=credentials" 
    $lapsCredentials = CallGraphAPI -accessToken $AccessToken -ResourcePath $lapsUri -extraParameters $extraParameters
    Write-Verbose "[$functionName] LAPS credentials response: $($lapsCredentials | Out-String)"
    if ($lapsCredentials)
    {
        if (-not $quiet) {Write-Host "LAPS credentials found for device: $DeviceId" -ForegroundColor Green}
        Write-Verbose "Found $($lapsCredentials.credentials.count ) LAPS credentials for device: $DeviceId"
        #If there is more than $lapsCredentials.credentials.count, return the latest (by date) $lapsCredential.accountName, backupDateTime and a clear text password derived from passwordBase64
        if ($lapsCredentials.credentials.count -gt 1)
        {
            Write-Verbose "[$functionName] More than one LAPS credential found. Sorting by backupDateTime and getting the latest credential."
            $latestCredential = $lapsCredentials.credentials | Sort-Object backupDateTime -Descending | Select-Object -First 1
        }
        else
        {
            Write-Verbose "[$functionName] Only one LAPS credential found. Using that credential."
            $latestCredential = $lapsCredentials.credentials
        }
        $clearTextPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($latestCredential.passwordBase64))
        $returnObject = @{
            AccountName       = $latestCredential.accountName
            BackupDateTime    = $latestCredential.backupDateTime
            ClearTextPassword = $clearTextPassword
        }
        #display the LAPS credentials
        if (-not $quiet)
        {
            Write-Host "LAPS Credentials for device: $DeviceId" -ForegroundColor Cyan
            Write-Host "Account Name: $($returnObject.AccountName)" -ForegroundColor Cyan
            Write-Host "Backup DateTime: $($returnObject.BackupDateTime | FormatDateWithTimeZone)" -ForegroundColor Cyan
            Write-Host "Clear Text Password: $($returnObject.ClearTextPassword)" -ForegroundColor Cyan
            return "`n"
        }
        return $lapsCredentials 
    }
    else
    {
        Write-Verbose "[$functionName] No LAPS credentials found for device: $DeviceId"
        Write-Host "No LAPS credentials found for device: $DeviceId" -ForegroundColor Red
        return $returnValues.noLAPSFoundMessage
    }
}