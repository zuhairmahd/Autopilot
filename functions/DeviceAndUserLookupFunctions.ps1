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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received serial number: $serialNumber" -LogLevel "Information"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $autopilotDevices = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI).value
    Write-Verbose "[$functionName] Received $($autopilotDevices.Count) devices from Autopilot."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received $($autopilotDevices.Count) devices from Autopilot." -LogLevel "Information"
    for ($i = 0; $i -lt $autopilotDevices.Count; $i++)
    {
        $device = $autopilotDevices[$i]
        Write-Verbose "[$functionName] Processing device with serial number $($device.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing device with serial number $($device.serialNumber)" -LogLevel "Verbose"
        $filteredDeviceSerialNumber = $device.serialNumber -replace '\s', ''
        Write-Verbose "[$functionName] Filtered device serial number: $filteredDeviceSerialNumber"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered device serial number: $filteredDeviceSerialNumber" -LogLevel "Information"
        if ($serialNumber -match '\s')
        {
            Write-Verbose "[$functionName] Also filtering input serial number $serialNumber since it contains spaces."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Also filtering input serial number $serialNumber since it contains spaces." -LogLevel "Information"
            $serialNumber = $serialNumber -replace '\s', ''
            Write-Verbose "[$functionName] Filtered input serial number: $serialNumber"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered input serial number: $serialNumber" -LogLevel "Information"
        }
        if ($filteredDeviceSerialNumber -eq $serialNumber)
        {
            Write-Verbose "[$functionName] Found a match for serial number $serialNumber in Autopilot."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found a match for serial number $serialNumber in Autopilot." -LogLevel "Information"
            return $device.id
        }
        else
        {
            Write-Verbose "[$functionName] No match for serial number $serialNumber in Autopilot."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match for serial number $serialNumber in Autopilot." -LogLevel "Information"
        }
    }
    Write-Verbose "[$functionName] Filtered device serial number: $filteredDeviceSerialNumber"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered device serial number: $filteredDeviceSerialNumber" -LogLevel "Information"
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
    Write-Verbose "[$functionName] Device ID:     $ManagedDeviceId"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device ID:     $ManagedDeviceId" -LogLevel "Information"
    Write-Verbose "[$functionName] Command: $Command"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Command: $Command" -LogLevel "Information"
    Write-Verbose "[$functionName] MaxRetries: $MaxRetries"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "MaxRetries: $MaxRetries" -LogLevel "Information"
    Write-Verbose "[$functionName] RetryDelaySeconds: $RetryDelaySeconds"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "RetryDelaySeconds: $RetryDelaySeconds" -LogLevel "Information"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No AccessToken provided." -LogLevel "Information"
        return $false
    }
    $returnSuccessMessage = $null
    $returnFailureMessage = $null
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $response = ""
    #endregion

    if (-not $NoConfirmation)
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
    
    switch ($Command)
    {
        "clean"
        {
            Write-Host 'Cleaning the device...' -ForegroundColor Yellow
            $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
            $body = @{ 'keepUserData' = $false } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0' 
            Write-Verbose "[$functionName] Response: $response"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $response" -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $response" -LogLevel "Information"
            $returnSuccessMessage = $returnValues.deviceWipeSuccessMessage
            $returnFailureMessage = $returnValues.deviceWipeFailedMessage
        }
        "sync"
        {
            Write-Host 'Syncing the device...' -ForegroundColor Yellow
            $syncUri = "$deviceManagementUri/syncDevice"
            $response = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $response" -LogLevel "Information"
            $returnSuccessMessage = $returnValues.deviceSyncSuccessMessage
            $returnFailureMessage = $returnValues.deviceSyncFailedMessage
        }
        "restart"
        {
            Write-Host 'Restarting the device...' -ForegroundColor Yellow
            $restartUri = "$deviceManagementUri/rebootNow"
            $response = callGraphApi -AccessToken $accessToken -Method 'POST' -ResourcePath $restartUri -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $response" -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Sync Response: $syncResponse" -LogLevel "Information"
        }
        return $returnSuccessMessage
    }
    else
    {
        Write-Host "Failed to send $Command command to device." -ForegroundColor Red
        Write-Verbose "[$functionName] Failed to send command. Response: $response"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to send command. Response: $response" -LogLevel "Error"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial Number: $SerialNumber" -LogLevel "Information"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No AccessToken provided." -LogLevel "Information"
        return $false
    }
    #endregion    # Query the device enrollment status using Microsoft Graph API
    # Fetch the device details using the serial number
    $response = CallGraphApi -AccessToken $AccessToken -ResourcePath $managedDeviceUri -filter $filter -ExtraParameters $extraParameters -Method GET
    if ($response)
    {
        $device = $response.value.Id
        Write-Verbose "[$functionName] Device found with ID: $($device)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device found with ID: $($device)" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Device with serial number $SerialNumber not found."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device with serial number $SerialNumber not found." -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting VerifyGroupMembership function" -LogLevel "Information"

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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token is empty or null" -LogLevel "Information"
        Write-Host "Access token is required." -ForegroundColor Red
        $result.Error = "Access token is required."
        return $result
    }

    Write-Verbose "[$functionName] User name: $userName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "User name: $userName" -LogLevel "Information"
    Write-Verbose "[$functionName] Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })" -LogLevel "Information"
    Write-Verbose "[$functionName] Groups to exclude count: $(if ($groupsToExclude) { $groupsToExclude.Count } else { 0 })"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Groups to exclude count: $(if ($groupsToExclude) { $groupsToExclude.Count } else { 0 })" -LogLevel "Information"
    
    if ($groupsToInclude)
    {
        Write-Verbose "[$functionName] Groups to include: $($groupsToInclude -join ', ')"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Groups to include: $($groupsToInclude -join ', ')" -LogLevel "Information"
    }
    
    if ($groupsToExclude)
    {
        Write-Verbose "[$functionName] Groups to exclude: $($groupsToExclude -join ', ')"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Groups to exclude: $($groupsToExclude -join ', ')" -LogLevel "Information"
    }
    #endregion
    
    #region Get user information
    try
    {
        Write-Verbose "[$functionName] Getting user information for $userName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting user information for $userName" -LogLevel "Information"
        $userUri = "users/$($userName)" 
        $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri -extraparameters "select=displayName,mail,userPrincipalName,id"
        # Check if user was found
        if ($user -is [string] -and $user -match '^\d+$')
        {
            Write-Verbose "[$functionName] User $userName not found in Azure AD (Error code: $user)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName not found in Azure AD (Error code: $user)" -LogLevel "Error"
            Write-Host "The user $userName was not found in Azure AD." -ForegroundColor Red
            Write-Host "Please check the user name and try again." -ForegroundColor Red
            $result.Error = "User not found in Azure AD (Error code: $user)"
            return $result
        }
        $result.UserInfo = $user
        Write-Verbose "[$functionName] Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))" -LogLevel "Information"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting user information: $_"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error getting user information: $_" -LogLevel "Error"
        Write-Host "Error getting user information: $_" -ForegroundColor Red
        $result.Error = "Error getting user information: $_"
        return $result
    }
    #endregion
    
    #region Get group membership
    try
    {
        Write-Verbose "[$functionName] Getting group membership for user $userName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting group membership for user $userName" -LogLevel "Information"
        Write-Host "Getting group membership for user $userName ($($user.displayName))."
        $groupUri = "users/$($userName)/memberOf/microsoft.graph.group"
        $groupSelection = "select=displayName&top=999&orderby=displayName"
        $response = CallGraphAPI -accessToken $accessToken -ResourcePath $groupUri -extraparameters $groupSelection
        if ($response -is [string] -and $response -match '^\d+$')
        {
            Write-Verbose "[$functionName] Failed to get group membership (Error code: $response)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to get group membership (Error code: $response)" -LogLevel "Error"
            Write-Host "The group membership for $userName could not be determined." -ForegroundColor Red
            Write-Host "Please try again or contact an Intune administrator." -ForegroundColor Red
            $result.Error = "Failed to get group membership (Error code: $response)"
            return $result
        }
        $groups = $response.value | Select-Object -ExpandProperty displayName | Sort-Object
        $result.UserGroups = $groups
        Write-Verbose "[$functionName] User $userName is a member of $($groups.Count) groups"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is a member of $($groups.Count) groups" -LogLevel "Information"
        Write-Host "User $userName is a member of $($groups.Count) groups."
        Write-Verbose "[$functionName] Groups: $($groups -join ', ')"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Groups: $($groups -join ', ')" -LogLevel "Information"
    }
    catch
    {
        Write-Verbose "[$functionName] Error getting group membership: $_"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error getting group membership: $_" -LogLevel "Error"
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No groups to include were specified. Skipping this check." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Checking memberships for user $userName in $($groupsToInclude.Count) required groups"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking memberships for user $userName in $($groupsToInclude.Count) required groups" -LogLevel "Verbose"
        foreach ($group in $groupsToInclude)
        {
            Write-Verbose "[$functionName] Checking membership in required group: $group"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking membership in required group: $group" -LogLevel "Verbose"
            if ($groups -notcontains $group)
            {
                Write-Verbose "[$functionName] User $userName is NOT a member of the required group: $group"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is NOT a member of the required group: $group" -LogLevel "Information"
                $missingGroups += $group
            }
            else
            {
                Write-Verbose "[$functionName] User $userName is a member of the required group: $group"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is a member of the required group: $group" -LogLevel "Information"
            }
        }
        $result.MissingGroups = $missingGroups
        if ($missingGroups.Count -gt 0)
        {
            Write-Verbose "[$functionName] User $userName is missing membership in $($missingGroups.Count) required groups: $($missingGroups -join ', ')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is missing membership in $($missingGroups.Count) required groups: $($missingGroups -join ', ')" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] User $userName is a member of all required groups"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is a member of all required groups" -LogLevel "Information"
        }
    }
    #endregion
    
    #region Check exclude group membership
    $forbiddenGroups = @()
    if ($null -eq $groupsToExclude -or $groupsToExclude.Count -eq 0)
    {
        Write-Verbose "[$functionName] No groups to exclude were specified. Skipping this check."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No groups to exclude were specified. Skipping this check." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Checking user $userName isn't in $($groupsToExclude.Count) excluded groups"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking user $userName isn't in $($groupsToExclude.Count) excluded groups" -LogLevel "Verbose"
        foreach ($group in $groupsToExclude)
        {
            Write-Verbose "[$functionName] Checking membership in excluded group: $group"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking membership in excluded group: $group" -LogLevel "Verbose"
            if ($groups -contains $group)
            {
                Write-Verbose "[$functionName] User $userName is a member of the excluded group: $group (should not be)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is a member of the excluded group: $group (should not be)" -LogLevel "Information"
                $forbiddenGroups += $group
            }
            else
            {
                Write-Verbose "[$functionName] User $userName is not a member of the excluded group: $group (correct)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is not a member of the excluded group: $group (correct)" -LogLevel "Information"
            }
        }
        $result.ForbiddenGroups = $forbiddenGroups
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Verbose "[$functionName] User $userName is a member of $($forbiddenGroups.Count) excluded groups: $($forbiddenGroups -join ', ')"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is a member of $($forbiddenGroups.Count) excluded groups: $($forbiddenGroups -join ', ')" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] User $userName is not a member of any excluded groups"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName is not a member of any excluded groups" -LogLevel "Information"
        }
    }
    #endregion
    
    #region Determine result and return
    if ($missingGroups.Count -eq 0 -and $forbiddenGroups.Count -eq 0)
    {
        Write-Verbose "[$functionName] User $userName has correct group memberships"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName has correct group memberships" -LogLevel "Information"
        $result.Success = $true
    }
    else
    {
        Write-Verbose "[$functionName] User $userName does not have correct group memberships"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $userName does not have correct group memberships" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Completed VerifyGroupMembership function with Success=$($result.Success)" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting total registered devices for user: $UserName" -LogLevel "Information"
    if ($null -eq $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken is null or empty. Cannot proceed." -LogLevel "Error"
        return 0
    }
    Write-Verbose "[$functionName] AccessToken provided."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken provided." -LogLevel "Information"
    $registeredDevices = (CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri).value
    Write-Verbose "[$functionName] Registered devices count: $($registeredDevices.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Registered devices count: $($registeredDevices.Count)" -LogLevel "Information"
    if ($registeredDevices -and $registeredDevices.Count -gt 0)
    {
        Write-Verbose "[$functionName] Returning count of registered devices: $($registeredDevices.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning count of registered devices: $($registeredDevices.Count)" -LogLevel "Information"
        return $registeredDevices.Count
    }
    else
    {
        Write-Verbose "[$functionName] No registered devices found for user: $UserName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No registered devices found for user: $UserName" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting function to get user from Entra ID" -LogLevel "Information"
    # Validate access token
    if (-not $accessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken is null or empty. Cannot proceed." -LogLevel "Error"
        return $returnValues.noAccessTokenMessage
    }
    Write-Verbose "[$functionName] Attempting exact match for userPrincipalName: $UserName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting exact match for userPrincipalName: $UserName" -LogLevel "Information"
    $userUri = "users/$UserName"
    $userExtraParameters = "select=givenName,surName,displayName,userPrincipalName,mail,id"    
    $userInfo = CallGraphAPI -accessToken $AccessToken -ResourcePath $userUri -extraParameters $userExtraParameters
    Write-Verbose "[$functionName] Exact match API response: $($userInfo | Out-String)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match API response: $($userInfo | Out-String)" -LogLevel "Information"
    
    if ($userInfo -notin 400, 401, 403, 404)
    {
        Write-Verbose "[$functionName] Exact match found for userPrincipalName: $UserName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match found for userPrincipalName: $UserName" -LogLevel "Information"
        Write-Verbose "[$functionName] User found: $($userInfo.displayName) ($($userInfo.userPrincipalName))"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User found: $($userInfo.displayName) ($($userInfo.userPrincipalName))" -LogLevel "Information"
        
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exact match failed with error code: $userInfo" -LogLevel "Error"
        
        # Display appropriate error message to user based on error code
        switch ($userInfo)
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
                Write-Host "Forbidden. You do not have permission to access this user." -ForegroundColor Red 
            }
            404
            {
                Write-Host "User '$UserName' not found in Entra ID." -ForegroundColor Red 
            }
        }
        
        return $returnValues.noUserFoundInDirectoryMessage
    }
    
    # Step 2: If no exact match found, perform substring search using $search parameter if the $findSimilar switch is set
    if ($FindSimilar)
    {
        Write-Verbose "[$functionName] No exact match found (Error code: $userInfo). Performing substring search using Graph API search."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No exact match found (Error code: $userInfo). Performing substring search using Graph API search." -LogLevel "Error"
        # Remove the @ portion from the username if it exists for better search results
        $searchTerm = $UserName -replace '@.*$', ''
        Write-Verbose "[$functionName] Cleaned search term: $searchTerm"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cleaned search term: $searchTerm" -LogLevel "Information"
        $searchUri = "users"
        $filterExpression = "startswith(givenName, '$searchTerm') or startsWith(surname, '$searchTerm')"
        Write-Verbose "[$functionName] Searching for substring matches in user properties for: $searchTerm"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Searching for substring matches in user properties for: $searchTerm" -LogLevel "Information"
        Write-Verbose "[$functionName] Trying filter: $filterExpression" 
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trying filter: $filterExpression" " -LogLevel "Information"
        $fallbackResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $searchUri -filter $filterExpression -extraParameters $userExtraParameters
        if ($fallbackResults -notin 400, 401, 403, 404 -and $fallbackResults.value -and $fallbackResults.value.Count -gt 0)
        {
            $substringSearch = $true
            Write-Verbose "[$functionName] Filter approach succeeded with $($fallbackResults.value.Count) results"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filter approach succeeded with $($fallbackResults.value.Count) results" -LogLevel "Information"
            # Initialize filtered results array
            $filteredUsers = @()
            # Filter out excluded users
            foreach ($user in $fallbackResults.value)
            {
                #Check if the user is a duplicate record of a previous record
                Write-Verbose "[$functionName] Processing user: $($user.displayName) ($($user.userPrincipalName))"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing user: $($user.displayName) ($($user.userPrincipalName))" -LogLevel "Verbose"
                if ($filteredUsers -contains $user.userPrincipalName)
                {
                    Write-Verbose "[$functionName] User $($user.userPrincipalName) is a duplicate, skipping."
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "User $($user.userPrincipalName) is a duplicate, skipping." -LogLevel "Information"
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
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking user: $($user.displayName) ($($user.userPrincipalName)) against exclusion pattern: $pattern" -LogLevel "Verbose"
                        if ($user.userPrincipalName.Contains($pattern) -or $user.displayName -match $pattern)
                        {
                            # If the user matches any exclusion pattern, mark them for exclusion
                            Write-Verbose "[$functionName] User matches exclusion pattern: $pattern"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User matches exclusion pattern: $pattern" -LogLevel "Information"
                            Write-Verbose "[$functionName] Excluding user: $($user.displayName) ($($user.userPrincipalName)) - Matched exclusion pattern: $pattern"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Excluding user: $($user.displayName) ($($user.userPrincipalName)) - Matched exclusion pattern: $pattern" -LogLevel "Information"
                            $excludeUser = $true
                            break
                        }
                    }
                }
                # Add user to filtered results if not excluded
                if (-not $excludeUser)
                {
                    Write-Verbose "[$functionName] Including user: $($user.displayName) ($($user.userPrincipalName))"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Including user: $($user.displayName) ($($user.userPrincipalName))" -LogLevel "Information"
                    $filteredUsers += $user
                }
            }            # Create a response object in the same format as the original Graph API response
            $filteredResponse = [PSCustomObject]@{
                '@odata.context' = $fallbackResults.'@odata.context'
                value            = @($filteredUsers | Sort-Object -Property userPrincipalName -Unique)  # Force array creation
            }
            Write-Verbose "[$functionName] Filtered results to $($filteredResponse.value.Count) unique users after exclusions"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtered results to $($filteredResponse.value.Count) unique users after exclusions" -LogLevel "Information"
            return $filteredResponse, $substringSearch
        }
        else        
        {
            Write-Verbose "[$functionName] Search approach failed (Error code: $fallbackResults)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Search approach failed (Error code: $fallbackResults)" -LogLevel "Error"
            return $returnValues.noUserFoundInDirectoryMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] No matches found for userPrincipalName: $UserName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No matches found for userPrincipalName: $UserName" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "UserName: $UserName" -LogLevel "Information"
    Write-Verbose "[$functionName] Operating system: $OperatingSystem"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Operating system: $OperatingSystem" -LogLevel "Information"
    if ($null -ne $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "AccessToken not provided." -LogLevel "Information"
        return $null
    }
    $UserName = $UserName.Trim()
    Write-Verbose "[$functionName] Trimmed user name: $UserName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Trimmed user name: $UserName" -LogLevel "Information"
    $extraparameters = "select=deviceName,serialNumber,userDisplayName,model,manufacturer,complianceState"
    Write-Verbose "[$functionName] Extra parameters for API call: $extraparameters"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extra parameters for API call: $extraparameters" -LogLevel "Information"
    $filter = "startswith(userPrincipalName,'$UserName') and operatingSystem eq '$OperatingSystem'"
    Write-Verbose "[$functionName] Filter for API call: $filter"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filter for API call: $filter" -LogLevel "Information"
    $managedDeviceUri = "deviceManagement/managedDevices"
    Write-Verbose "[$functionName] Managed device URI: $managedDeviceUri"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Managed device URI: $managedDeviceUri" -LogLevel "Information"
    #endregion

    $deviceInfo = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -Filter $filter -extraParameters $extraparameters
    Write-Verbose "[$functionName] Device value count: $($deviceInfo.value.Count)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device value count: $($deviceInfo.value.Count)" -LogLevel "Information"
    Write-Verbose "[$functionName] Device Info: $($deviceInfo | Out-String)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device Info: $($deviceInfo | Out-String)" -LogLevel "Information"
    if ($deviceInfo -notin 400, 401, 403, 404)
    {
        if ($deviceInfo.value.Count -eq 0)
        {
            Write-Verbose "[$functionName] No devices found for user: $UserName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found for user: $UserName" -LogLevel "Information"
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
            $deviceMenu = NewMenu -Title "Device Selection" -Description "Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))"
            Write-Verbose "[$functionName] Creating device menu with $($devices.Count) devices"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating device menu with $($devices.Count) devices" -LogLevel "Information"
            # Add each device as a menu item
            foreach ($device in $devices)
            {
                
                # Create a display name for the menu
                $menuItemName = "Device: $($device.deviceName) ($($device.manufacturer) $($device.model) SN: $($device.serialNumber)) ($($device.complianceState))"
                Write-Verbose "[$functionName] Adding menu item: $menuItemName"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Adding menu item: $menuItemName" -LogLevel "Information"
                # Create a scriptblock action that returns this specific device's serial number when selected
                $serialNumber = $device.serialNumber
                Write-Verbose "[$functionName] Creating action for serial number: $serialNumber"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating action for serial number: $serialNumber" -LogLevel "Information"
                $action = {
                    Write-Verbose "[$functionName] Returning Serial Number: $serialNumber"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning Serial Number: $serialNumber" -LogLevel "Information"
                    return $serialNumber
                }.GetNewClosure()
                # Add the menu item with the action
                $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $menuItemName -Action $action -ReturnsValue
            }
            Write-Verbose "[$functionName] Showing device selection menu with $($deviceMenu.Items.Count) items"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Showing device selection menu with $($deviceMenu.Items.Count) items" -LogLevel "Information"
            Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current navigation - Depth: $Depth, History count: $($History.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName] Current menu title: $($deviceMenu.Title)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Current menu title: $($deviceMenu.Title)" -LogLevel "Information"
            $selectedSerialNumber = ShowMenu -Menu $deviceMenu -CalledBy 'Action'
            if ($null -ne $selectedSerialNumber -and $selectedSerialNumber -is [string])
            {
                Write-Verbose "[$functionName] Selected serial number: $selectedSerialNumber"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected serial number: $selectedSerialNumber" -LogLevel "Information"
            }
            else
            {
                Write-Verbose "[$functionName] Selected serial number is null or not a string"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Selected serial number is null or not a string" -LogLevel "Information"
            }
            
            # Validate that we got a proper serial number, not a navigation option
            if ($selectedSerialNumber -eq "Back" -or $selectedSerialNumber -eq "Main Menu" -or $selectedSerialNumber -eq 0 -or $selectedSerialNumber -eq "0")
            {
                Write-Verbose "[$functionName] ShowMenu returned navigation option: '$selectedSerialNumber', treating as navigation"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned navigation option: '$selectedSerialNumber', treating as navigation" -LogLevel "Information"
                return $selectedSerialNumber
            }
            
            Write-Verbose "[$functionName] Returning valid selected serial number: $selectedSerialNumber"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning valid selected serial number: $selectedSerialNumber" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial Number: $serialNumber" -LogLevel "Information"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Received Access Token"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received Access Token" -LogLevel "Information"
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "VMware device detected." -LogLevel "Verbose"
        $isVMWareDevice = $true
        # $autopilotDeviceFilter = "AzureActiveDirectoryDeviceId eq '$($managedDevice.AzureAdDeviceId)'"
        # Alternative approach if the above doesn't work
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)'"
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)' or AzureActiveDirectoryDeviceId eq '$AzureActiveDirectoryDeviceId'"
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "[$functionName] Received $($autoPilotVMDevice.count) devices from Autopilot."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received $($autoPilotVMDevice.count) devices from Autopilot." -LogLevel "Information"
        if ($autoPilotVMDevice -and $autoPilotVMDevice.count -gt 0)
        {
            Write-Verbose "[$functionName] Got an Autopilot Device with device id $($autoPilotVMDevice)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Got an Autopilot Device with device id $($autoPilotVMDevice)" -LogLevel "Information"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $params = @{
                AccessToken  = $accessToken
                ResourcePath = $autopilotDeviceUriWithId
            }
        }
        else
        {
            Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No match for device with serial number $serialNumber found in Autopilot." -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Not a VMWare device. Continuing"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Not a VMWare device. Continuing" -LogLevel "Information"
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
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot Device Response: $($autopilotDeviceResponse | Out-String)" -LogLevel "Information"
    Write-Verbose "[$functionName] Autopilot Device Response Count: $($autopilotDeviceResponse.'@odata.count')"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot Device Response Count: $($autopilotDeviceResponse.'@odata.count')" -LogLevel "Information"
    if ($null -ne $autopilotDeviceResponse -and $autopilotDeviceResponse.'@odata.count' -gt 0)
    {
        Write-Verbose "[$functionName] Got a device count of $($autopilotDeviceResponse.'@odata.count') from Autopilot."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Got a device count of $($autopilotDeviceResponse.'@odata.count') from Autopilot." -LogLevel "Information"
        $autopilotDevice = $autopilotDeviceResponse.value
    }
    elseif ($isVMWareDevice -and $null -ne $autopilotDeviceResponse -and ($null -ne $autopilotDeviceResponse.id -and $autopilotDeviceResponse.id -ne ''))
    {
        Write-Verbose "[$functionName] Got a single autopilot device with id $($autopilotDeviceResponse.id)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Got a single autopilot device with id $($autopilotDeviceResponse.id)" -LogLevel "Information"
        $autopilotDevice = $autopilotDeviceResponse
    }
    else
    {
        Write-Verbose "[$functionName] Did not get a good response for device with serial number $serialNumber"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Did not get a good response for device with serial number $serialNumber" -LogLevel "Information"
        $inAutopilot = $false
    }
    if ($autopilotDevice)
    {
        $inAutopilot = $true
        Write-Verbose "[$functionName] Getting deployment profile information for device with serial number $($autopilotDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting deployment profile information for device with serial number $($autopilotDevice.serialNumber)" -LogLevel "Information"
        # $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)?`$expand=deploymentProfile(`$select=displayName)"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)?`$expand=deploymentProfile"
        $autopilotDevice = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -APIVersion 'beta' 
        Write-Verbose "[$functionName] Got $($autopilotDevice.count) devices from Autopilot."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Got $($autopilotDevice.count) devices from Autopilot." -LogLevel "Information"
        Write-Verbose "[$functionName] Enrollment Profile name: $($autopilotDevice.deploymentProfile.displayname)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Enrollment Profile name: $($autopilotDevice.deploymentProfile.displayname)" -LogLevel "Information"
        Write-Verbose "[$functionName] Device is in Autopilot: $inAutopilot to true."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is in Autopilot: $inAutopilot to true." -LogLevel "Information"
        $returnedAutopilotDevice = $autopilotDevice 
        Write-Verbose "[$functionName] Getting latest events for device with serial number $($autopilotDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting latest events for device with serial number $($autopilotDevice.serialNumber)" -LogLevel "Information"
        $autopilotDeviceEventsFilter = "deviceSerialNumber eq '$($autopilotDevice.serialNumber)'"
        $autopilotEvents = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotEventsURI -filter $autopilotDeviceEventsFilter
        Write-Verbose "[$functionName] Found $($autopilotEvents.value.count) Autopilot events."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($autopilotEvents.value.count) Autopilot events." -LogLevel "Information"
        if ($autopilotEvents)
        {
            Write-Verbose "[$functionName] Returning $($autopilotEvents.value.count) Events found for device with serial number $($autopilot.serialNumber)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning $($autopilotEvents.value.count) Events found for device with serial number $($autopilot.serialNumber)" -LogLevel "Information"
            $returnedAutopilotEvents = ($autopilotEvents | Sort-Object createdDateTime -Descending).value 
            Write-Verbose "[$functionName] Autopilot Events: $($returnedAutopilotEvents.count)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot Events: $($returnedAutopilotEvents.count)" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No events found for device in Autopilot"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No events found for device in Autopilot" -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Device is not an autopilot device."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is not an autopilot device." -LogLevel "Information"
        $inAutopilot = $false
    }
    if ($autopilotDevice)
    {
        Write-Verbose "[$functionName] Getting imported Autopilot device info for serial number $($autopilotDevice.serialNumber) from autopilot object."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting imported Autopilot device info for serial number $($autopilotDevice.serialNumber) from autopilot object." -LogLevel "Information"
        $importedDeviceFilter = "serialNumber eq '$($autopilotDevice.serialNumber)'"
    }
    else
    {
        Write-Verbose "[$functionName] Getting imported Autopilot device info for serial number $serialNumber from serial number."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting imported Autopilot device info for serial number $serialNumber from serial number." -LogLevel "Information"
        $importedDeviceFilter = "serialNumber eq '$serialNumber'"
        $importedAutopilotDeviceResult = CallGraphAPI -AccessToken $accessToken -ResourcePath $importedAutopilotDeviceURI -Filter $importedDeviceFilter
        $importedAutopilotDevice = $importedAutopilotDeviceResult.value
        Write-Verbose "[$functionName] Returned Imported Autopilot Device serial number: $($autopilotDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returned Imported Autopilot Device serial number: $($autopilotDevice.serialNumber)" -LogLevel "Information"
        if ($importedAutopilotDevice)
        {
            Write-Verbose "[$functionName] Device found in Imported Autopilot device list with serial number $($importedAutopilotDevice.serialNumber)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device found in Imported Autopilot device list with serial number $($importedAutopilotDevice.serialNumber)" -LogLevel "Information"
            $imported = $true
            $returnedImportedDevice = $importedAutopilotDevice
        }
        else
        {
            Write-Verbose "[$functionName] Device not found in the list of imported Autopilot devices"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not found in the list of imported Autopilot devices" -LogLevel "Information"
            Write-Verbose "[$functionName] This means the device may have already been registered."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "This means the device may have already been registered." -LogLevel "Information"
        }
    }
    #endregion

    #region Get the managed device info
    #If the serial number contains spaces, remove them.
    if ($serialNumber -match '\s')
    {
        Write-Verbose "[$functionName] Serial number contains spaces. Removing them."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Serial number contains spaces. Removing them." -LogLevel "Information"
        $serialNumber = $serialNumber -replace '\s', ''
    }
    $managedDeviceFilter = "serialNumber eq '$serialNumber'"
    $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -Filter $managedDeviceFilter).value
    Write-Verbose "[$functionName] Device serial number: $($managedDevice.serialNumber)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device serial number: $($managedDevice.serialNumber)" -LogLevel "Information"
    if ($managedDevice)
    {
        Write-Verbose "[$functionName] Device found in Intune with serial number $($managedDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device found in Intune with serial number $($managedDevice.serialNumber)" -LogLevel "Information"
        $inManagedDevices = $true
        $returnedManagedDevice = $managedDevice
        
        #region Check device memory
        Write-Verbose "[$functionName] Checking device memory information."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking device memory information." -LogLevel "Verbose"
        $hardwareResourcePath = "$deviceManagementUri/$($autopilotDevice.managedDeviceId)" 
        Write-Verbose "[$functionName] Calling graph using the path $hardwareResourcePath with the extra parameters         $deviceHardwareExtraparameters"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Calling graph using the path $hardwareResourcePath with the extra parameters         $deviceHardwareExtraparameters" -LogLevel "Information"
        $deviceMemory = (CallGraphAPI -AccessToken $accessToken -ResourcePath $hardwareResourcePath -APIVersion 'beta' -ExtraParameters $deviceHardwareExtraparameters).physicalMemoryInBytes
        Write-Verbose "[$functionName] Device memory in bytes: $deviceMemory"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device memory in bytes: $deviceMemory" -LogLevel "Information"
        if ($deviceMemory -gt 0) 
        {   
            Write-Verbose "[$functionName] Converting memory to gigabytes."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting memory to gigabytes." -LogLevel "Verbose"
            $deviceMemory = [math]::round($deviceMemory / 1GB, 2)
            Write-Verbose "[$functionName] Device memory: $deviceMemory GB"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device memory: $deviceMemory GB" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "Device memory not found."
            $deviceMemory = $null
        }
        Write-Verbose "[$functionName] Got device memory: $deviceMemory"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Got device memory: $deviceMemory" -LogLevel "Information"
        #endregion

        #region check device users
        Write-Verbose "[$functionName] Checking for logged on users for device with serial number $($managedDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking for logged on users for device with serial number $($managedDevice.serialNumber)" -LogLevel "Verbose"
        Write-Verbose "[$functionName] managedDevice.usersLoggedOn: $($managedDevice.usersLoggedOn)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "managedDevice.usersLoggedOn: $($managedDevice.usersLoggedOn)" -LogLevel "Information"
        Write-Verbose "[$functionName] managedDevice.userPrincipalName: $($managedDevice.userPrincipalName)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "managedDevice.userPrincipalName: $($managedDevice.userPrincipalName)" -LogLevel "Information"
        Write-Verbose "[$functionName] managedDevice.emailAddress: $($managedDevice.emailAddress)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "managedDevice.emailAddress: $($managedDevice.emailAddress)" -LogLevel "Information"
        Write-Verbose "[$functionName] ManagedDevice.userDisplayName: $($managedDevice.userDisplayName)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "ManagedDevice.userDisplayName: $($managedDevice.userDisplayName)" -LogLevel "Information"
        if ($nnull -ne $managedDevice.usersLoggedOn )
        {
            Write-Verbose "[$functionName] Device has logged on users."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has logged on users." -LogLevel "Information"
            $hasUserObject = $true
            $hasUser = $true
            $lastLogonDateTime = $managedDevice.usersLoggedOn.lastLogonDateTime
            Write-Verbose "[$functionName] Last logon date: $lastLogonDateTime"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last logon date: $lastLogonDateTime" -LogLevel "Information"
        }
        elseif ($null -ne $managedDevice.userPrincipalName -and $managedDevice.userPrincipalName -match $settings.domain)
        {
            Write-Verbose "[$functionName] Device has a userPrincipalName."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has a userPrincipalName." -LogLevel "Information"
            $azureUser = $true
            $hasUser = $true
            Write-Verbose "[$functionName] The last logon date is unavailable."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The last logon date is unavailable." -LogLevel "Information"
        }
        elseif ($null -ne $managedDevice.emailAddress -and $managedDevice.userPrincipalName -match $settings.domain) 
        {
            Write-Verbose "[$functionName] Device has an email address."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has an email address." -LogLevel "Information"
            $azureUser = $true
            $hasUser = $true
            Write-Verbose "[$functionName] The last logon date is unavailable."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The last logon date is unavailable." -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No associated users found for device in Intune"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No associated users found for device in Intune" -LogLevel "Information"
        }
        if ($hasUser -and $hasUserObject -eq $false)
        {
            Write-Verbose "[$functionName] No user object detected.  Returning device values."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No user object detected.  Returning device values." -LogLevel "Verbose"
            if ($managedDevice.userPrincipalName -match $settings.domain)
            {
                Write-Verbose "[$functionName] User is an Azure AD user"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User is an Azure AD user" -LogLevel "Information"
                $azureUser = $true
            }
            else
            {
                Write-Verbose "[$functionName] User is not an Azure AD user"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User is not an Azure AD user" -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieving the logged on user for device with serial number $($managedDevice.serialNumber) and ID $($managedDevice.Id)" -LogLevel "Information"
            Write-Verbose "[$functionName] Passing $deviceManagementUri/$($managedDevice.Id)/$userUri to graph."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Passing $deviceManagementUri/$($managedDevice.Id)/$userUri to graph." -LogLevel "Information"
            $user = (CallGraphAPI -AccessToken $accessToken -ResourcePath "$deviceManagementUri/$($managedDevice.Id)/$userUri" -APIVersion 'beta').value
            Write-Verbose "[$functionName] User Display Name: $($user.displayName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "User Display Name: $($user.displayName)" -LogLevel "Information"
            Write-Verbose "[$functionName] userPrincipalName: $($user.userPrincipalName)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "userPrincipalName: $($user.userPrincipalName)" -LogLevel "Information"
            if ($user.userPrincipalName -match $settings.domain)
            {
                Write-Verbose "[$functionName] User is an Azure AD user"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User is an Azure AD user" -LogLevel "Information"
                $azureUser = $true
            }
            else
            {
                Write-Verbose "[$functionName] User is not an Azure AD user"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "User is not an Azure AD user" -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "LoggedOn Users: $($loggedOnUsers.Count)" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No logged on users found for device in Intune"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No logged on users found for device in Intune" -LogLevel "Information"
        }
        #endregion

        #region Check for LAPS credentials
        $lapsUri = "directory/deviceLocalCredentials/$($managedDevice.azureADDeviceId)"
        $lapsExtraParameters = "select=credentials" 
        $laps = CallGraphAPI -accessToken $AccessToken -ResourcePath $lapsUri -extraParameters $lapsExtraParameters 
        if ($null -ne $laps -and $laps -ne $returnValues.noLAPSFoundMessage)
        {
            Write-Verbose "[$functionName] LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
        }
        #endregion

        #region Get bitlocker recovery objects.
        $bitlockerURI = "informationProtection/bitlocker/recoveryKeys"
        $bitlockerFilter = "deviceId eq '$($managedDevice.azureADDeviceId)'"
        $bitlockerExtraParameters = "select=id,createdDateTime,volumeType,deviceId" 
        Write-Verbose "[$scriptName] Getting BitLocker recovery keys for device: $($managedDevice.azureADDeviceId)"
        Write-Log -LogFile $LogFile -Module "$scriptName" -Message "Getting BitLocker recovery keys for device: $($managedDevice.azureADDeviceId)" -LogLevel "Information"
        $bitlockerKeys = CallGraphApi -accessToken $accessToken -ResourcePath $bitlockerURI -filter $bitlockerFilter -extraParameters $bitlockerExtraParameters 
        if ($bitlockerKeys.value.count -gt 0)
        {
            Write-Verbose "[$functionName] $($bitlockerKeys.value.count) BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "$($bitlockerKeys.value.count) BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
            #get the latest BitLocker recovery key
            $latestBitlockerKey = $bitlockerKeys.value | Sort-Object createdDateTime -Descending | Select-Object -First 1
        }
        else
        {
            Write-Verbose "[$functionName] No BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)" 
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)" " -LogLevel "Information"
            $bitlockerKeys = $returnValues.noBitLockerKeysFoundMessage
            $latestBitlockerKey = $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Intune"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not found in Intune" -LogLevel "Information"
    }
    #Getting the unmanaged device object from Intune
    if ($managedDevice )
    {
        Write-Verbose "[$functionName] Looking up device with Azure Active Directory id $($managedDevice.azureActiveDirectoryDeviceId)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Looking up device with Azure Active Directory id $($managedDevice.azureActiveDirectoryDeviceId)" -LogLevel "Information"
        $deviceId = $managedDevice.azureActiveDirectoryDeviceId
        $deviceFilter = "deviceId eq '$deviceId'"
    }
    else
    {
        Write-Verbose "[$functionName] Attempting to find device with serial number."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting to find device with serial number." -LogLevel "Information"
        $deviceFilter = "endswith(displayName, '$serialNumber')"
    }
    $device = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceUri -filter $deviceFilter -consistencyLevel).value
    if ($device -and $device.count -gt 0)
    {
        Write-Verbose "[$functionName] Device found in Intune with serial number $($device.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device found in Intune with serial number $($device.serialNumber)" -LogLevel "Information"
        $hasDeviceObject = $true
        $returnedDevice = $device
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Intune"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not found in Intune" -LogLevel "Information"
    }
    #endregion
    
    #region Verbose logging
    if ($inAutopilot)
    {
        Write-Verbose "[$functionName] Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device found in Autopilot with serial number $($autopilotDevice.serialNumber)" -LogLevel "Information"
        Write-Verbose "[$functionName] Autopilot Registered: $inAutopilot"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot Registered: $inAutopilot" -LogLevel "Information"
        if ($returnedAutopilotEvents)
        {
            Write-Verbose "[$functionName] The device has had $($returnedAutopilotEvents.count) events."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device has had $($returnedAutopilotEvents.count) events." -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] No Autopilot events found"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No Autopilot events found" -LogLevel "Information"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Autopilot"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not found in Autopilot" -LogLevel "Information"
    }
    if ($inManagedDevices)
    {
        Write-Verbose "[$functionName] Device is managed in Intune with serial number $($device.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is managed in Intune with serial number $($device.serialNumber)" -LogLevel "Information"
        Write-Verbose "[$functionName] Device managed: $inManagedDevices"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device managed: $inManagedDevices" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Device not managed in Intune"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not managed in Intune" -LogLevel "Information"
    }
    if ($imported)
    {
        Write-Verbose "[$functionName] Device is imported into Autopilot with serial number $($importedAutopilotDevice.serialNumber)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is imported into Autopilot with serial number $($importedAutopilotDevice.serialNumber)" -LogLevel "Information"
        Write-Verbose "[$functionName] Device Imported: $imported"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device Imported: $imported" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Device not imported into Autopilot"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not imported into Autopilot" -LogLevel "Information"
    }
    if ($hasDeviceObject)
    {
        Write-Verbose "[$functionName] Device found in Intune with display name: $($device.displayName)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device found in Intune with display name: $($device.displayName)" -LogLevel "Information"
        Write-Verbose "[$functionName] Device has device object: $hasDeviceObject"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has device object: $hasDeviceObject" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Device not found in Intune"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device not found in Intune" -LogLevel "Information"
    }
    if ($hasUserObject)
    {
        Write-Verbose "[$functionName] Device has user object: $hasUserObject"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has user object: $hasUserObject" -LogLevel "Information"
        Write-Verbose "[$functionName] Device has user: $hasUser"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has user: $hasUser" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Device does not have user object: $hasUserObject"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device does not have user object: $hasUserObject" -LogLevel "Information"
        Write-Verbose "[$functionName] Device does not have user: $hasUser"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device does not have user: $hasUser" -LogLevel "Information"
    }
    if ($loggedOnUsers)
    {
        Write-Verbose "[$functionName] Logged on users: $($loggedOnUsers.Count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Logged on users: $($loggedOnUsers.Count)" -LogLevel "Information"
        Write-Verbose "[$functionName] Logged on user display name: $($loggedOnUsers.userDisplayName)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Logged on user display name: $($loggedOnUsers.userDisplayName)" -LogLevel "Information"
        Write-Verbose "[$functionName] Logged on user principal name: $($loggedOnUsers.userPrincipalName)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Logged on user principal name: $($loggedOnUsers.userPrincipalName)" -LogLevel "Information"
        Write-Verbose "[$functionName] Logged on user email address: $($loggedOnUsers.emailAddress)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Logged on user email address: $($loggedOnUsers.emailAddress)" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No logged on users found for device in Intune"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No logged on users found for device in Intune" -LogLevel "Information"
    }
    if ($laps)
    {
        Write-Verbose "[$functionName] LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
        Write-Verbose "[$functionName] LAPS credentials count: $($laps.credentials.count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS credentials count: $($laps.credentials.count)" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
    }
    if ($bitlockerKeys -and $bitlockerKeys.value.count -gt 0)
    {
        Write-Verbose "[$functionName] BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
        Write-Verbose "[$functionName] BitLocker recovery keys count: $($bitlockerKeys.value.count)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker recovery keys count: $($bitlockerKeys.value.count)" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] No BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)" -LogLevel "Information"
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
        Device             = $returnedManagedDevice
        Memory             = $deviceMemory
        Users              = $loggedOnUsers
        LAPS               = $laps
        BitLocker          = $bitlockerKeys
        LatestBitLockerKey = $latestBitlockerKey
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
        $enrollmentState
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting LAPS credentials for device with Azure ID: $($enrollmentState.managedDevice.Device.azureADDeviceId)."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting LAPS credentials for device with Azure ID: $($enrollmentState.managedDevice.Device.azureADDeviceId)." -LogLevel "Information"

    if ($enrollmentState.managedDevice.laps -notin $returnValues.values)
    {
        Write-Host "LAPS credentials found for device with serial number $($enrollmentState.managedDevice.Device.serialNumber)" -ForegroundColor Green
        Write-Verbose "Found $($enrollmentState.managedDevice.laps.credentials.count ) LAPS credentials for device with Azure ID: $DeviceId"
        #If there is more than $lapsCredentials.credentials.count, return the latest (by date) $lapsCredential.accountName, backupDateTime and a clear text password derived from passwordBase64
        if ($enrollmentState.managedDevice.laps.credentials.count -gt 1)
        {
            Write-Verbose "[$functionName] More than one LAPS credential found. Sorting by backupDateTime and getting the latest credential."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "More than one LAPS credential found. Sorting by backupDateTime and getting the latest credential." -LogLevel "Information"
            $latestCredential = $enrollmentState.managedDevice.laps.credentials | Sort-Object backupDateTime -Descending | Select-Object -First 1
        }
        else
        {
            Write-Verbose "[$functionName] Only one LAPS credential found. Using that credential."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Only one LAPS credential found. Using that credential." -LogLevel "Information"
            $latestCredential = $enrollmentState.managedDevice.laps.credentials
        }
        $clearTextPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($latestCredential.passwordBase64))
        $returnObject = @{
            AccountName       = $latestCredential.accountName
            BackupDateTime    = $latestCredential.backupDateTime
            ClearTextPassword = $clearTextPassword
        }
        #display the LAPS credentials
        Write-Host "LAPS Credentials for device: $DeviceId" -ForegroundColor Cyan
        Write-Host "Account Name: $($returnObject.AccountName)" -ForegroundColor Cyan
        Write-Host "Backup DateTime: $($returnObject.BackupDateTime | FormatDateWithTimeZone)" -ForegroundColor Cyan
        Write-Host "Clear Text Password: $($returnObject.ClearTextPassword)" -ForegroundColor Cyan
        return "`n"
        # return $lapsCredentials 
        return "`n"
    }
    else
    {
        Write-Verbose "[$functionName] No LAPS credentials found for device: $DeviceId"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No LAPS credentials found for device: $DeviceId" -LogLevel "Information"
        Write-Host "No LAPS credentials found for device: $DeviceId" -ForegroundColor Red
        return $returnValues.noLAPSFoundMessage
    }
}

function GetBitLockerRecoveryKey()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        $key,
        [parameter(Mandatory = $true)]
        [string]$accessToken
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving BitLocker recovery key for key ID: $($key.id)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieving BitLocker recovery key for key ID: $($key.id)" -LogLevel "Information"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access Token provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access Token provided." -LogLevel "Information"
    }
    $volumeTypes = @{
        "0" = "Unknown"
        "1" = "OperatingSystem"
        "2" = "FixedData"
        "3" = "RemovableData"
    }
    # Define the resource path for BitLocker recovery keys
    $bitLockerUri = "informationProtection/bitlocker/recoveryKeys/$($key.id)"
    $bitlockerExtraParameters = "select=key"
    Write-Verbose "[$functionName] Retrieving actual BitLocker recovery key..."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Retrieving actual BitLocker recovery key..." -LogLevel "Information"
    Write-Verbose "[$functionName] BitLocker URI: $bitLockerUri"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker URI: $bitLockerUri" -LogLevel "Information"
    Write-Verbose "[$functionName] Extra parameters for BitLocker API call: $bitlockerExtraParameters"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extra parameters for BitLocker API call: $bitlockerExtraParameters" -LogLevel "Information"
    # Call the Graph API to get BitLocker recovery keys
    try
    {
        $recoveryKeyDetails = CallGraphApi -accessToken $accessToken -ResourcePath $bitLockerUri -extraParameters $bitlockerExtraParameters
        # Display the recovery key information
        Write-Host "Latest BitLocker recovery key:" -ForegroundColor Cyan
        Write-Host "Key: $($recoveryKeyDetails.key)" -ForegroundColor Yellow
        Write-Host "Created: $($key.createdDateTime |FormatDateWithTimeZone)" -ForegroundColor Yellow
        Write-Host "Volume Type: $($volumeTypes[$key.volumeType])" -ForegroundColor Yellow
    }
    catch
    {
        Write-Error "[$scriptName] Failed to retrieve BitLocker recovery key: $($_.Exception.Message)"
        Write-Host "Key metadata available:" -ForegroundColor Yellow
        Write-Host "Created: $($latestKeyInfo.createdDateTime |FormatDateWithTimeZone)" 
        Write-Host "Volume Type: $($volumeTypes[$latestKeyInfo.volumeType])" 
        Write-Host "Device ID: $($latestKeyInfo.deviceId)" 
        Write-Host "Key ID: $($latestKeyInfo.id)" -ForegroundColor Yellow
    }
    return "`n"
}
