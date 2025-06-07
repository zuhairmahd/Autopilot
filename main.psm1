#region Inlined Functions
# This section contains inlined functions from multiple files
# Generated on: 2025-06-06 22:56:22
# Source files:
#   - C:\Users\zuhai\code\Autopilot\functions\DeviceAndUserLookupFunctions.ps1
#   - C:\Users\zuhai\code\Autopilot\functions\DeviceFunctions.ps1
#   - C:\Users\zuhai\code\Autopilot\functions\DeviceReportingFunctions.ps1
#   - C:\Users\zuhai\code\Autopilot\functions\GraphAPIFunctions.ps1
#   - C:\Users\zuhai\code\Autopilot\functions\MenuFunctions.ps1
#   - C:\Users\zuhai\code\Autopilot\functions\MiscFunctions.ps1
#   - C:\Users\zuhai\code\Autopilot\functions\ScriptUpdateFunctions.ps1

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
    Write-Verbose "[$($MyInvocation.MyCommand)] Starting VerifyGroupMembership function"
    
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
        Write-Verbose "[$($MyInvocation.MyCommand)] Access token is empty or null"
        Write-Host "Access token is required." -ForegroundColor Red
        $result.Error = "Access token is required."
        return $result
    }

    Write-Verbose "[$($MyInvocation.MyCommand)] User name: $userName"
    Write-Verbose "[$($MyInvocation.MyCommand)] Groups to include count: $(if ($groupsToInclude) { $groupsToInclude.Count } else { 0 })"
    Write-Verbose "[$($MyInvocation.MyCommand)] Groups to exclude count: $(if ($groupsToExclude) { $groupsToExclude.Count } else { 0 })"
    
    if ($groupsToInclude)
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Groups to include: $($groupsToInclude -join ', ')"
    }
    
    if ($groupsToExclude)
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Groups to exclude: $($groupsToExclude -join ', ')"
    }
    #endregion

    #region Get user information
    try
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Getting user information for $userName"
        $userUri = "users/$($userName)" 
        $user = CallGraphApi -accessToken $accessToken -ResourcePath $userUri -extraparameters "select=displayName,mail,userPrincipalName,id"
        # Check if user was found
        if ($user -is [string] -and $user -match '^\d+$')
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] User $userName not found in Azure AD (Error code: $user)"
            Write-Host "The user $userName was not found in Azure AD." -ForegroundColor Red
            Write-Host "Please check the user name and try again." -ForegroundColor Red
            $result.Error = "User not found in Azure AD (Error code: $user)"
            return $result
        }
        $result.UserInfo = $user
        Write-Verbose "[$($MyInvocation.MyCommand)] Successfully retrieved user information for $userName (Display Name: $($user.DisplayName), ID: $($user.id))"
    }
    catch
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Error getting user information: $_"
        Write-Host "Error getting user information: $_" -ForegroundColor Red
        $result.Error = "Error getting user information: $_"
        return $result
    }
    #endregion

    #region Get group membership
    try
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Getting group membership for user $userName"
        Write-Host "Getting group membership for user $userName ($($user.displayName))."
        $groupUri = "users/$($userName)/memberOf/microsoft.graph.group"
        $groupSelection = "select=displayName&top=999&orderby=displayName"
        $response = CallGraphAPI -accessToken $accessToken -ResourcePath $groupUri -extraparameters $groupSelection
        if ($response -is [string] -and $response -match '^\d+$')
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] Failed to get group membership (Error code: $response)"
            Write-Host "The group membership for $userName could not be determined." -ForegroundColor Red
            Write-Host "Please try again or contact an Intune administrator." -ForegroundColor Red
            $result.Error = "Failed to get group membership (Error code: $response)"
            return $result
        }
        $groups = $response.value | Select-Object -ExpandProperty displayName | Sort-Object
        $result.UserGroups = $groups
        Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is a member of $($groups.Count) groups"
        Write-Host "User $userName is a member of $($groups.Count) groups."
        Write-Verbose "[$($MyInvocation.MyCommand)] Groups: $($groups -join ', ')"
    }
    catch
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Error getting group membership: $_"
        Write-Host "Error getting group membership: $_" -ForegroundColor Red
        $result.Error = "Error getting group membership: $_"
        return $result
    }
    #endregion
    
    #region Check include group membership
    $missingGroups = @()
    if ($null -eq $groupsToInclude -or $groupsToInclude.Count -eq 0)
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] No groups to include were specified. Skipping this check."
    }
    else
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Checking memberships for user $userName in $($groupsToInclude.Count) required groups"
        foreach ($group in $groupsToInclude)
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] Checking membership in required group: $group"
            if ($groups -notcontains $group)
            {
                Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is NOT a member of the required group: $group"
                $missingGroups += $group
            }
            else
            {
                Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is a member of the required group: $group"
            }
        }
        $result.MissingGroups = $missingGroups
        if ($missingGroups.Count -gt 0)
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is missing membership in $($missingGroups.Count) required groups: $($missingGroups -join ', ')"
        }
        else
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is a member of all required groups"
        }
    }
    #endregion
    
    #region Check exclude group membership
    $forbiddenGroups = @()
    if ($null -eq $groupsToExclude -or $groupsToExclude.Count -eq 0)
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] No groups to exclude were specified. Skipping this check."
    }
    else
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] Checking user $userName isn't in $($groupsToExclude.Count) excluded groups"
        foreach ($group in $groupsToExclude)
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] Checking membership in excluded group: $group"
            if ($groups -contains $group)
            {
                Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is a member of the excluded group: $group (should not be)"
                $forbiddenGroups += $group
            }
            else
            {
                Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is not a member of the excluded group: $group (correct)"
            }
        }
        $result.ForbiddenGroups = $forbiddenGroups
        if ($forbiddenGroups.Count -gt 0)
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is a member of $($forbiddenGroups.Count) excluded groups: $($forbiddenGroups -join ', ')"
        }
        else
        {
            Write-Verbose "[$($MyInvocation.MyCommand)] User $userName is not a member of any excluded groups"
        }
    }
    #endregion
    
    #region Determine result and return
    if ($missingGroups.Count -eq 0 -and $forbiddenGroups.Count -eq 0)
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] User $userName has correct group memberships"
        $result.Success = $true
    }
    else
    {
        Write-Verbose "[$($MyInvocation.MyCommand)] User $userName does not have correct group memberships"
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
    Write-Verbose "[$($MyInvocation.MyCommand)] Completed VerifyGroupMembership function with Success=$($result.Success)"
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
    $filter = "userPrincipalName ne null and userPrincipalName ne '' and contains(userPrincipalName, '$username') and operatingSystem eq '$OperatingSystem'"
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
            return $null
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
            $selectedSerialNumber = ShowMenu -Menu $deviceMenu 
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
        return $null
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
            return $false
        }
    }

    Write-Host "Sending $Command command to device with identifier $ManagedDeviceId" -ForegroundColor Cyan
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $success = $false
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
        }
        "sync"
        {
            Write-Host 'Syncing the device...' -ForegroundColor Yellow
            $syncUri = "$deviceManagementUri/syncDevice"
            $response = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "syncDevice"
        }
        "restart"
        {
            Write-Host 'Restarting the device...' -ForegroundColor Yellow
            $restartUri = "$deviceManagementUri/rebootNow"
            $response = callGraphApi -AccessToken $accessToken -Method 'POST' -ResourcePath $restartUri -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "rebootNow"
        }
        default
        {
            Write-Host "Invalid command. Please use 'clean', 'wipe', 'sync', or 'restart'." -ForegroundColor Red
            return $false
        }
    }  
    # Monitor action status for all operations
    if ($MonitorAction)
    {
        if ($response -eq '')
        {
            Write-Host "Command sent successfully. Performing automatic device sync..." -ForegroundColor Green
        
            # Only send additional sync for non-sync operations to avoid redundancy
            if ($Command -ne "sync")
            {
                $syncUri = "$deviceManagementUri/syncDevice"
                $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
                Write-Verbose "[$functionName] Sync Response: $syncResponse"
            }

            # Begin monitoring the action status
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
                                $success = $true
                            }
                            "failed"
                            {
                                Write-Host "$Command action failed with error: $($actionResult.errorCode)" -ForegroundColor Red
                                if ($actionResult.errorDescription)
                                {
                                    Write-Host "Error description: $($actionResult.errorDescription)" -ForegroundColor Red
                                }
                                $actionFailed = $true
                                $success = $false
                            }
                            "timeout"
                            {
                                Write-Host "$Command action timed out." -ForegroundColor Red
                                $actionFailed = $true
                                $success = $false
                            }
                            "canceled"
                            {
                                Write-Host "$Command action was canceled." -ForegroundColor Red
                                $actionFailed = $true
                                $success = $false
                            }
                            "notFound"
                            {
                                Write-Verbose "[$functionName] Action not found yet or device may no longer be available."
                                if ($retryCount -gt 3)
                                {
                                    Write-Verbose "[$functionName] Action not found after multiple attempts, assuming device is no longer available."
                                    $actionFailed = $false
                                    $success = $true
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
                            $success = $true
                        }
                    }
                }
            }

            # Final status report
            if ($actionCompleted)
            {
                Write-Host "$Command action has completed successfully." -ForegroundColor Green
            }
            elseif ($actionFailed)
            {
                Write-Host "$Command action has failed with status: $actionState" -ForegroundColor Red
            }
            else
            {
                Write-Host "$Command action monitoring timed out after $MaxRetries attempts." -ForegroundColor Yellow
                Write-Host "Last known status: $actionState" -ForegroundColor Yellow
                Write-Warning "The action may still be in progress. You can check the device status in the Intune portal."
            }
        }
        else
        {
            Write-Host "Failed to send $Command command to device." -ForegroundColor Red
            Write-Verbose "[$functionName] Failed to send command. Response: $response"
        }
    }
    return $success
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

#region Autopilot functions
function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput
    )

    #Get the function name
    $functionName = $MyInvocation.MyCommand.Name
    $MaxSerialNumberLength = '11'
    $MinSerialNumberLength = '7'
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    $returnValue = @{}
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
    if ($UserInput.Length -gt $MaxSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
        Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
    }
    elseif ($UserInput.Length -lt $MinSerialNumberLength)
    {
        Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
        Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
    }
    elseif ($UserInput -match '^[a-zA-Z0-9]+$') 
    {
        Write-Verbose "[$functionName] Serial number validation passed"
        $returnValue.valid = $true
        $returnValue.value = $UserInput
    }
    else
    {
        Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    return $returnValue
}

function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt
    )
    #Get the function name
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 
    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $BackoutText."
            return $null # Return null to signal going back
        }
        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value
        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            # The loop will continue, prompting the user again
        }
    }
}

function PrepareImportDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $accessToken,
        [switch]$CustomImport
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Preparing to import device with serial number: $($deviceObject.serialNumber)."
    Write-Verbose "[$functionName] Getting the serial number for this device..."
    Write-Verbose "[$functionName] Checking whether the script has sufficient permissions to run."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$functionName] The script is running with sufficient permissions."
        Write-Verbose "[$functionName] Getting device object."
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please run the script as an administrator.' -ForegroundColor Red
        return $null
    }
    if ($deviceObject)
    {
        if ($customImport) 
        {
            Write-Verbose "[$functionName] Custom import is enabled."
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import' -CustomImport
            if ($result -eq $backoutText)
            {
                Write-Verbose "[$functionName] Custom import aborted. Returning $backoutText."
                return $backoutText
            }
        }
        else 
        {
            Write-Host "This will import the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) to Intune."
            Write-Verbose "[$functionName] Importing device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
            $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            while ($choice -notin @('yes', 'no'))
            {
                Write-Host "Invalid choice. Please enter 'yes' or 'no'."
                #beep
                [console]::beep(1000, 500)
                $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            }
            if ($choice -eq 'no')
            {
                Write-Host "Exiting..."
                return $backoutText
            }
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import'
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
}

function DisplayDeviceAssignmentStatus()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $deviceAssignment,
        [Parameter(Mandatory = $true)]
        [string]$functionName
    )

    Write-Verbose "[$functionName] The device assignment status is $($deviceAssignment.deploymentProfileAssignmentStatus)"
    
    if ($deviceAssignment.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
    {
        Write-Host 'The device is already in Intune and is assigned to a profile.' -ForegroundColor Green
        Write-Verbose "[$functionName] The assignment date is $($deviceAssignment.deploymentProfileAssignedDateTime)."
        $profileAssignmentDate = ($deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
        Write-Host "The device was assigned to the deployment profile $($deviceAssignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
        Write-Host "The device enrollment state is $($deviceAssignment.enrollmentState)." -ForegroundColor Green
        return $true
    }
    elseif ($deviceAssignment.deploymentProfileAssignmentStatus -eq 'unassigned')
    {
        Write-Host 'The device is not assigned to a deployment profile.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        return $false
    }
    elseif ($deviceAssignment.deploymentProfileAssignmentStatus -eq 'pending')
    {
        Write-Host 'The device is pending assignment to a deployment profile.' -ForegroundColor Yellow
        Write-Host 'Please check again after a little while.' -ForegroundColor Yellow
        return $false
    }
    else 
    {
        Write-Host "The device is in Intune but there is an issue with its profile assignment: $($deviceAssignment.deploymentProfileAssignmentStatus)" -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        return $false
    }
}

function HandleDeviceEnrollmentState()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $deviceAssignment,
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$domain
    )

    $enrollmentState = $deviceAssignment.enrollmentState
    Write-Verbose "[$functionName] Processing enrollment state: $enrollmentState"
    
    switch ($enrollmentState)
    {
        'notContacted'
        {
            Write-Host 'The device has not contacted the enrollment service.' -ForegroundColor Green
            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
            Write-Verbose "[$functionName] Returning the message $($returnValues.notContactedMessage)"
            return $returnValues.notContactedMessage
        }
        'enrolled'
        {
            Write-Host 'The device appears to have been enrolled.' -ForegroundColor Red
            Write-Host "Looking up user information..."
            $deviceManagementUri = "deviceManagement/managedDevices"
            $managedDeviceFilter = "serialNumber eq '$serialNumber'"
            $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -Filter $managedDeviceFilter).value
            Write-Verbose "[$functionName] Managed device user principal name: $($managedDevice.userPrincipalName)"
            Write-Verbose "[$functionName] Managed device user display name: $($managedDevice.userDisplayName)"
            Write-Verbose "[$functionName] Managed device last logon date: $($managedDevice.usersLoggedOn.lastLogOnDateTime)"

            $hasUser = $false
            if ($managedDevice.userPrincipalName -match $domain)
            {
                $normalizedUser = NormalizeADUserDisplayName -UserDisplayName $managedDevice.userDisplayName
                Write-Host "The device is registered to the user $($normalizedUser.Fullname) with the email address $($managedDevice.userPrincipalName)." -ForegroundColor Red
                $hasUser = $true
            }
            else 
            {
                Write-Host "Cannot determine logged on user."
            }

            if ($null -ne $managedDevice.usersLoggedOn.lastLogOnDateTime)
            {
                $LastLogonDate = ($managedDevice.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
                if ($hasUser)
                {
                    Write-Host "The last logon date for $($normalizedUser.FirstName) was $LastLogonDate." -ForegroundColor Red
                }
                else
                {
                    Write-Host "The last logon date was $LastLogonDate." -ForegroundColor Red
                }
            }
            else 
            {
                Write-Host "The last logon date is not available." -ForegroundColor Red
            }
            
            Write-Host "The device needs to be cleaned before giving to another user." -ForegroundColor Red
            return $returnValues.EnrolledMessage
        }
        'pendingReset'
        {
            Write-Host 'The device is pending a reset.' -ForegroundColor Yellow
            Write-Host "The device needs to be allowed to finish the reset." -ForegroundColor Yellow
            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Yellow
            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Yellow
            return $returnValues.PendingResetMessage
        }
        'enrollmentFailed'
        {
            Write-Host 'The device enrollment failed.' -ForegroundColor Red
            Write-Host 'This may cause issues when the user logs on for the first time.' -ForegroundColor Red
            Write-Host "This means someone has already unsuccessfully tried to enroll the device." -ForegroundColor Red
            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Red
            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
            return $returnValues.EnrollmentFailedMessage
        }
        default
        {
            Write-Host "The device enrollment state is $enrollmentState." -ForegroundColor Red
            Write-Host 'Please check the Intune portal or contact an Intune administrator before you give the device to a user.' -ForegroundColor Red
            return $null
        }
    }
}

function HandleCustomImportSettings()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        [ref]$maxWaitTimeRef,
        [Parameter(Mandatory = $true)]
        [ref]$timeInSecondsRef,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Handling custom import settings"
    $maxWaitTime = $maxWaitTimeRef.Value
    $timeInSeconds = $timeInSecondsRef.Value
    
    Write-Host "Enter how many times you would like to check for a profile assignment."
    Write-Host "Press enter to keep the default value of $maxWaitTime."
    Write-Host "Press 0 to skip the wait."
    $customMaxWaitTime = Read-Host 'Enter the number of retries or press enter to skip'
    
    if ($customMaxWaitTime -eq '0')
    {
        Write-Host "Skipping the wait for profile assignment."
        return $returnValues.ImportSuccessMessage
    }
    elseif ($customMaxWaitTime -as [int] -and [int]$customMaxWaitTime -ge 0 -and [int]$customMaxWaitTime -le 60)
    {
        $maxWaitTimeRef.Value = [int]$customMaxWaitTime
        Write-Host "Will check $($maxWaitTimeRef.Value) times for proper profile assignment."
    }
    else
    {
        do
        {
            Write-Host "Invalid input. Please enter a number between 0 and 60." -ForegroundColor Yellow
            $customMaxWaitTime = Read-Host 'Enter the number of retries or press enter to skip'
        } while (($customMaxWaitTime -as [int]) -and ([int]$customMaxWaitTime -lt 0 -or [int]$customMaxWaitTime -gt 60))
    }
    
    Write-Host "Enter how many seconds to wait between each check."
    Write-Host "Press enter to keep the default value of $timeInSeconds."
    Write-Host "Press 0 to skip the wait."
    $customTimeInSeconds = Read-Host 'Enter the number of seconds or press enter to skip'
    
    if ($customTimeInSeconds -eq '0')
    {
        Write-Host "Skipping the wait for profile assignment."
        return $returnValues.ImportSuccessMessage
    }
    elseif ($customTimeInSeconds -as [int] -and [int]$customTimeInSeconds -ge 0 -and [int]$customTimeInSeconds -le 60)
    {
        $timeInSecondsRef.Value = [int]$customTimeInSeconds
        Write-Host "Will check every $($timeInSecondsRef.Value) seconds for proper profile assignment."
    }
    else
    {
        do
        {
            Write-Host "Invalid input. Please enter a number between 0 and 60." -ForegroundColor Yellow
            $customTimeInSeconds = Read-Host 'Enter the number of seconds or press enter to skip'
        } while (($customTimeInSeconds -as [int]) -and ([int]$customTimeInSeconds -lt 0 -or [int]$customTimeInSeconds -gt 60))
    }
    
    Write-Host "The device will be checked $($maxWaitTimeRef.Value) times with a wait of $($timeInSecondsRef.Value) seconds between each check."
    return $null
}

function ProcessImportResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $device,
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    if ($device.state.deviceImportStatus -eq 'complete')
    {
        $serialNumber = $device.SerialNumber
        Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
        return $true
    }
    elseif ($device.state.deviceImportStatus -eq 'error')
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
        return $returnValues.ImportFailedMessage
    }
    else
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
        return $returnValues.ImportFailedMessage
    }
}

function ProcessAssignmentResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $assignment,
        [Parameter(Mandatory = $true)]
        [string]$functionName,
        [Parameter(Mandatory = $true)]
        [datetime]$importStart,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Processing assignment result"
    Write-Verbose "[$functionName] The assignment details are: $($assignment | ConvertTo-Json)"
    
    if (-not $assignment)
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        return $returnValues.notInIntuneMessage
    }
    
    Write-Verbose "[$functionName] The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    
    if (($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or 
            $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync') -and 
        $null -ne $assignment.deploymentProfile.displayName)
    {
        $profileAssignmentDate = if ($assignment.deploymentProfileAssignedDateTime)
        {
            $assignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K" 
        }
        
        Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
        Write-Host "The device is successfully assigned to the deployment profile $($assignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
        Write-Host "The device enrollment state is $($assignment.enrollmentState). " -ForegroundColor Green -NoNewline
        
        if ($assignment.enrollmentState -eq 'notContacted')
        {
            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
        }
        
        $importDuration = (Get-Date) - $importStart
        $importMinutes = [int]$importDuration.TotalMinutes
        $importSeconds = $importDuration.Seconds
        Write-Host "Elapsed time to complete: $importMinutes minutes, $importSeconds seconds"
        
        if (-not (RestartDevice))
        {
            return $returnValues.ImportSuccessMessage
        }
    }
    else
    {
        Write-Host 'The device could not be assigned to a deployment profile.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        Write-Host "The device current assignment status is $($assignment.deploymentProfileAssignmentStatus)."
        Write-Host "The device assignment profile name is $($assignment.deploymentProfile.displayName)."
        Write-Host "The device profile assignment date is $($assignment.deploymentProfileAssignmentDateTime)."
        return $returnValues.ImportFailedMessage
    }
}

function ProcessDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $DeviceObject,
        $returnValues = $returnValues,
        [Parameter(Mandatory = $true)]
        [ValidateSet('import', 'check', 'delete')]
        [string]$action,
        [switch]$CustomImport
    )
    
    #region check and initialize variables
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking access token..."
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    else
    {
        Write-Verbose "[$functionName] Access token not provided. Returning Null."
        return $null
    }
    Write-Verbose "[$functionName] Processing serial number: $($deviceObject.SerialNumber)."
    Write-Verbose "[$functionName] Action: $action"
    Write-Verbose "[$functionName] Custom import: $CustomImport"
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "[$functionName] The serial number is $serialNumber."
    $make = $deviceObject.manufacturer
    Write-Verbose "[$functionName] The manufacturer is $make"
    $model = $deviceObject.model
    Write-Verbose "[$functionName] The model is $model"
    #endregion check and initialize variables

    switch ($action)
    {
        'import'
        {
            Write-Host "Checking to make sure the device hash is not already in Intune..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($deviceAssignment)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment -functionName $functionName
                if (-not $isAssigned)
                {
                    return $returnValues.UnassignedMessage
                }
            }
            else
            {
                Write-Host "The device is not in Intune." 
            }
            #region Add the device to Intune
            $importStart = Get-Date
            $device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $GroupTag -AssignedUser $AssignedUser -TimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime -CustomImport $CustomImport
            if ($device -eq $backoutText)
            {
                Write-Verbose "[$functionName] The import function returned $device."
                return $backoutText
            }
            $importResult = ProcessImportResult -device $device -functionName $functionName -returnValues $returnValues
            if ($importResult -ne $true)
            {
                return $importResult
            }
            
            #region Handle CustomImport settings if needed
            # if ($CustomImport)
            # {
            #   $maxWaitTimeRef = [ref]$maxWaitTime
            #   $timeInSecondsRef = [ref]$timeInSeconds
            #   $customResult = HandleCustomImportSettings -functionName $functionName -maxWaitTimeRef $maxWaitTimeRef -timeInSecondsRef $timeInSecondsRef -returnValues $returnValues
            #   if ($customResult)
            #   {
            #     return $customResult
            #   }
            #   $maxWaitTime = $maxWaitTimeRef.Value
            #   $timeInSeconds = $timeInSecondsRef.Value
            # }
            #endregion Handle CustomImport settings if needed
            
            Write-Host "Waiting for $timeInSeconds seconds to allow for profile assignment."
            Start-Sleep -Seconds $timeInSeconds
            
            $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
            return ProcessAssignmentResult -assignment $assignment -functionName $functionName -importStart $importStart -returnValues $returnValues
            #endregion Add the device to Intune.
        }
        'check'
        {
            Write-Host "Checking device with serial number $serialNumber..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            
            if ($deviceAssignment)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment -functionName $functionName
                
                if ($isAssigned)
                {
                    # Handle enrollment state for assigned devices
                    return HandleDeviceEnrollmentState -deviceAssignment $deviceAssignment -serialNumber $serialNumber -accessToken $accessToken -functionName $functionName -returnValues $returnValues -domain $domain
                }
                else
                {
                    # Handle unassigned devices
                    switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                    {
                        'unassigned'
                        {
                            return $returnValues.UnassignedMessage
                        }
                        'pending'
                        {
                            return $returnValues.PendingMessage
                        }
                    }
                    
                    # Show options for problem devices
                    Write-Host "What would you like to do?"
                    $choices = @('Restart the device', 'Continue to wait for profile assignment', 'Delete from Autopilot')
                    $choice = DisplayNumericMenu -Choices $choices 
                    
                    switch ($choice)
                    {
                        'Restart the device'
                        {
                            Write-Host 'Restarting the device...'
                            RestartDevice
                        }
                        'Continue to wait for profile assignment'
                        {
                            Write-Host 'Continuing to wait for profile assignment...'
                            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
                        }
                        'Delete from Autopilot'
                        {
                            Write-Host 'Deleting the device from Autopilot...'
                            if (DeleteAutopilotDevice -DeviceIdentifyer $deviceAssignment.id -IdentifyerType 'DeviceId')
                            {
                                Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                            }
                            else
                            {
                                Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                                return $null
                            }
                        }
                    }
                    return $true
                }
            }
            else
            {
                Write-Host 'The device is not in Intune.'
            }
        }
        'delete'
        {
            Write-Host "Deleting device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
            if (DeleteAutopilotDevice -DeviceIdentifyer $serialNumber -IdentifyerType 'serialNumber')
            {
                Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                return $returnValues.DeleteSuccessMessage
            }
            else
            {
                Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                return $returnValues.DeleteFailedMessage
            }
        }
        default
        {
            Write-Verbose "[$functionName] Invalid action: $action"
            return $false
        }
    }
}

function ImportAutopilotDevice() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [object]$DeviceObject,
        [Parameter(Mandatory = $false)]
        [string]$GroupTag = '',
        [Parameter(Mandatory = $false)]
        [string]$AssignedUser = '',
        [Parameter(Mandatory = $false)]
        [int]$maxWaitTime = 30,
        [Parameter(Mandatory = $false)]
        [int]$timeInSeconds = 60,
        [bool]$CustomImport = $false
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region print verbose log of the parameters and define variables
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        return $false
    }
    Write-Verbose "[$functionName] DeviceObject: $DeviceObject"
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Verbose "[$functionName] MaxWaitTime: $maxWaitTime"
    Write-Verbose "[$functionName] TimeInSeconds: $timeInSeconds"
    Write-Verbose "[$functionName] CustomImport: $CustomImport"
    $uri = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $serialNumber = $DeviceObject.serialNumber
    Write-Verbose "[$functionName] Serial Number: $serialNumber"
    $make = $DeviceObject.manufacturer
    Write-Verbose "[$functionName] Make: $make"
    $model = $DeviceObject.model
    Write-Verbose "[$functionName] Model: $model"
    $hash = $DeviceObject.hardwareHash
    #endregion  
    #region prepare import object.
    if ($CustomImport -eq $true)
    {
        do
        {
            Write-Verbose "[$functionName] CustomImport is set to true."
            Write-Host "Enter the desired Group Tag for the device:"
            Write-Host "Press enter to keep the default value of $GroupTag."
            Write-Host "Enter 'None' to enter a blank Group Tag"
            $customGroupTag = Read-Host "Enter Group Tag"
            if ($customGroupTag -eq 'None')
            {
                $groupTag = ''
            }
            elseif ($customGroupTag -ne '')
            {
                $groupTag = $customGroupTag
            }
            Write-Host "Enter the desired Assigned User for the device:"
            Write-Host "Press enter to keep the default value of $AssignedUser."
            Write-Host "Enter 'None' to enter a blank Assigned User"
            $customAssignedUser = Read-Host "Enter Assigned User"
            if ($customAssignedUser -eq 'None')
            {
                $AssignedUser = ''
            }
            elseif ($customAssignedUser -ne '')
            {
                $AssignedUser = $customAssignedUser
            }
            Write-Host "How many times do you want to check for import completion and assignment?"
            $customMaxWaitTime = Read-Host "Press enter to keep the default value of $maxWaitTime."
            if ($customMaxWaitTime -ne '')
            {
                while ($maxWaitTime -notmatch '^\d+$')
                {
                    Write-Host "Please enter a valid number."
                    [console]::beep(1000, 500)
                    $customMaxWaitTime = Read-Host "Enter Max Wait Time in minutes"
                    if ($customMaxWaitTime -ne '')
                    {
                        $maxWaitTime = $customMaxWaitTime
                    }
                }
            }
            Write-Host "How long do you want to wait between checks?"
            $customTimeInSeconds = Read-Host "Press enter to keep the default value of $timeInSeconds seconds."
            if ($customTimeInSeconds -ne '')
            {
                while ($timeInSeconds -notmatch '^\d+$')
                {
                    Write-Host "Please enter a valid number."
                    [console]::beep(1000, 500)
                    $customTimeInSeconds = Read-Host "Enter Time In Seconds"
                    if ($customTimeInSeconds -ne '')
                    {
                        $timeInSeconds = $customTimeInSeconds
                    }
                }
            }
            Write-Host "The device will be imported with the following parameters:"
            Write-Host "Group Tag: $groupTag"
            Write-Host "Assigned User: $AssignedUser"
            Write-Host "Max Wait Time: $maxWaitTime minutes"
            Write-Host "Time In Seconds: $timeInSeconds seconds"
            Write-Host "Is this correct?"
            Write-Host "Enter C to continue, R to reenter or press enter to return to the previous menu."
            $ImportChoice = Read-Host "Enter C, R or press enter"
            if ($ImportChoice -eq 'C')
            {
                $ProceedWithImport = $true
                Write-Host "Continuing with the import."
            }
            elseif ($ImportChoice -eq 'R')
            {
                $ProceedWithImport = $false
                Write-Host "Reentering the parameters."
            }
            else
            {
                $ProceedWithImport = $false
                Write-Verbose "[$functionName] Returning to the previous menu."
                return $backoutText
            }
        } while ($ProceedWithImport -eq $false)
    }
    else
    {
        Write-Verbose "[$functionName] CustomImport is set to false."
    }
    $json = @"
{
  "@odata.type": "#microsoft.graph.importedWindowsAutopilotDeviceIdentity",
  "groupTag": "$groupTag",
  "serialNumber": "$serialNumber",
  "productKey": "",
  "importId": "",
  "hardwareIdentifier": "$hash",
  "state": {
    "@odata.type": "microsoft.graph.importedWindowsAutopilotDeviceIdentityState",
    "deviceImportStatus": "pending",
    "deviceRegistrationId": "",
    "deviceErrorCode": 15,
    "deviceErrorName": ""
  },
  "assignedUserPrincipalName": "$AssignedUser",
}    
"@
  
    $imported = callGraphApi -AccessToken $AccessToken -ResourcePath $uri -Method POST -Body $json
    if ($null -eq $imported)
    {
        Write-Host "The device import failed."
        Write-Host "Please check the Intune portal or contact an Intune administrator."
        return $null
    }
    Write-Host "The device import was successfully started."
    Write-Host "The imported device ID is $($imported.id)."
    #wait for the device to be imported
    Write-Host "Waiting for the import for device with device ID $($imported.id) to be completed."
    $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
    $index = 0
    while ($index -lt $maxWaitTime)
    {
        Write-Verbose "[$functionName] The device import status is $($device.state.deviceImportStatus)"
        if (($device.state.deviceImportStatus -ne 'unknown') -or ($index -gt $maxWaitTime))
        {
            break
        }
        Write-Host "The import status is $($device.state.deviceImportStatus)."
        Write-Host "Will check again in $timeInSeconds seconds."
        $index++
        Write-Host "Pass $index of $maxWaitTime"
        Start-Sleep -Seconds $timeInSeconds
        $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
    }
    Write-Host "The device import status is $($device.state.deviceImportStatus)"
    Write-Verbose "[$functionName] The index count is $index."
    if (($device.state.deviceImportStatus -eq 'unknown') -and ($index -gt $maxWaitTime))
    {
        Write-Host "The import is taking too long (over $maxWaitTime minutes)." 
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        return $null
    }
    else
    {
        Write-Verbose "[$functionName] The device import state is $($device.state.deviceImportStatus)"
        return $device
    }
}

function CheckDeviceAssignment()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [switch]$WaitForAssignment,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$waitTimeInSeconds = $waitTimeInSeconds,
        [Parameter(Mandatory = $false, ParameterSetName = 'WaitForAssignment')]
        [int]$maxWaitTime = $maxWaitTime
    )
    
    #region variables and logs
    #get the function name.
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Received parameters: serialNumber=$serialNumber."
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    Write-Verbose "[$functionName] WaitForAssignment switch: $WaitForAssignment."
    if ($WaitForAssignment)
    {
        Write-Verbose "[$functionName] Wait time in seconds: $waitTimeInSeconds."
        Write-Verbose "[$functionName] Max wait time: $maxWaitTime."
    }
    $autoPilotDeviceURI = 'deviceManagement/windowsAutopilotDeviceIdentities'
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $assignment = $null
    #endregion
    
    Write-Verbose "[$functionName] Checking whether the device with serial number $serialNumber is already in Intune."
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "[$functionName] VMware device detected."
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "[$functionName] Received $($autoPilotVMDevice.count) devices from Autopilot."
        if ($autoPilotVMDevice -ne '' -and $null -ne $autoPilotVMDevice)
        {
            Write-Verbose "[$functionName] Got an Autopilot Device with device id $($autoPilotVMDevice)"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUriWithId
        }
        else
        {
            Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] Not a VMWare device. Continuing"
        $assignment = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotDeviceUri -filter $autopilotDeviceFilter).value
    }
    Write-Verbose "[$functionName] Found $($assignment.count) Autopilot devices."
    if ($null -ne $assignment -and $assignment -ne '')
    {
        Write-Verbose "[$functionName] Found the device matching serial number $serialNumber."
        Write-Verbose "[$functionName] The device is registered in Autopilot."
        Write-Verbose "[$functionName] Checking profile assignment"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($assignment.id)"
        $extraProfileParameters = "expand=deploymentProfile"
        $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -extraparameters $extraProfileParameters
        Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
        if ($WaitForAssignment -and ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync')))
        {
            Write-Host "Checking up to $maxWaitTime times for the device to be assigned to a deployment profile."
            $index = 0
            while ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -lt $maxWaitTime)
            {
                Write-Host "Waiting for $waitTimeInSeconds  more seconds before checking again..." -ForegroundColor Yellow
                Start-Sleep -Seconds $waitTimeInSeconds
                $index++
                Write-Host "Checking again..."
                Write-Host "Pass $index of $maxWaitTime"
                $assignment = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -extraparameters $extraProfileParameters
                Write-Host "Deployment Profile Assignment Status: $($assignment.deploymentProfileAssignmentStatus)."
            }
            Write-Verbose "[$functionName] Gop final device assignment status: $($assignment.deploymentProfileAssignmentStatus)."
            if ($assignment.deploymentProfileAssignmentStatus -notin @('assignedUnkownSyncState', 'assignedInSync') -and $index -gt $maxWaitTime)
            {
                Write-Host "Finished checking $maxWaitTime times."
                Write-Host "The device assignment is taking too long."
                Write-Host 'Please check the Intune portal or contact an Intune administrator.'
            }
            elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Congratulations!!! " 
                Write-Verbose "[$functionName] The device is successfully assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($assignment.deploymentProfileAssignedDateTime)."
            }
        }
        else
        {
            if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync')
            {
                Write-Verbose "[$functionName] Device details: $($assignment | ConvertTo-Json -Depth 10)"
                Write-Verbose "[$functionName] The device was assigned to the $($assignment.deploymentProfile.displayName) deployment profile on $($autopilotDevice.deploymentProfileAssignedDateTime)."
                Write-Verbose "[$functionName] The device is ready for enrollment."
            }
            else
            {
                Write-Host "The device is not assigned to a deployment profile."
                Write-Host "Please check the Intune portal or contact an Intune administrator."
                Write-Verbose "[$functionName] The device is not ready for enrollment."
            }
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device is not found in Intune."
    }
    Write-Verbose "[$functionName] Returning $assignment."
    return $assignment
}

function GetDeviceHash()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $true)]
        $device
    )
    $success = $false

    Write-Verbose 'Creating DeviceHash with the following parameters:'
    Write-Verbose "OutputFile=$outputFile"
    Write-Verbose "SerialNumber=$($device.SerialNumber)"
    $csvObject = [PSCustomObject]@{
        'Device Serial Number' = $device.serialNumber
        'Windows Product ID'   = $device.product
        'Hardware Hash'        = $device.hardwareHash
        'Group Tag'            = $device.GroupTag
        'Assigned User'        = $device.AssignedUser
    }
    $csvObject | Select-Object 'Device Serial Number', 'Windows Product ID', 'Hardware Hash', 'Group Tag' | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | Out-File $OutputFile
    if ($outputFile)
    {
        Write-Host "Device hash saved to $outputFile" -ForegroundColor Green
        Write-Host 'In case of problems, you can manually upload the file to Intune or contact an Intune admin.'
        $success = $true
    }
    else
    {
        Write-Host 'Failed to save the device hash' -ForegroundColor Red
    }
    return $success 
}

function GetDeviceInfo()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$GroupTag,
        [Parameter(Mandatory = $false)]
        [string]$AssignedUser = '',
        [string]$Name,
        [switch]$NoHash
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose logs of the received parameters.
    Write-Verbose "[$functionName] GroupTag: $GroupTag"
    Write-Verbose "[$functionName] AssignedUser: $AssignedUser"
    Write-Verbose "[$functionName] NoHash: $NoHash"

    $device = @{}
    $session = New-CimSession
    $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
    #Add the serial number to the hash table.
    $device.Add('SerialNumber', $serial)
    Write-Verbose "[$functionName] The serial number is $serial."
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    $make = $cs.Manufacturer.Trim()
    $device.Add('Manufacturer', $make)
    Write-Verbose "[$functionName] The manufacturer is $make."
    $model = $cs.Model.Trim()
    $device.Add('Model', $model)
    Write-Verbose "[$functionName] The model is $model."
    $product = ''
    $device.add('Product', $product)
    Write-Verbose "[$functionName] The group tag is $GroupTag"
    $device.add('GroupTag', $GroupTag)
    Write-Verbose "[$functionName] The assigned user is $AssignedUser"
    $device.add('AssignedUser', $AssignedUser)
    if (-not $NoHash)
    {
        Write-Verbose "[$functionName] Checking for hardware hash."
        $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
        Write-Verbose "[$functionName] The device details are: $($devDetail | ConvertTo-Json -Depth 5)"
        if ($devDetail)
        {
            $hash = $devDetail.DeviceHardwareData
            $device.Add('HardwareHash', $hash)
            Write-Verbose "[$functionName] The hardware hash is $hash."
        }
        else
        {
            Write-Error 'No hardware hash was found.'
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] No hardware hash was requested."
    }
    Remove-CimSession $session
    return $device
}

function DeleteAutopilotDevice()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$DeviceIdentifyer,
        [ValidateSet('SerialNumber', 'DeviceId')]
        [string]$IdentifyerType = 'SerialNumber',
        [string]$accessToken = $accessToken,
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 20
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region variables and logs.
    Write-Verbose "[$functionName] Received parameters:" 
    if ($accessToken)
    {
        Write-Verbose "[$functionName]     AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName]     No AccessToken provided."
        return $null
    }
    Write-Verbose "[$functionName] Device identifier: $DeviceIdentifyer."
    Write-Verbose "[$functionName] Identifyer type: $IdentifyerType."
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "[$functionName] Identifyer Type is $IdentifyerType."
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "[$functionName] VMware device detected."
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "[$functionName] Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "[$functionName] Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Verbose "[$functionName] Returning device id: $autoPilotDeviceId"
                }
                else
                {
                    Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
                }
            }
            else
            {
                Write-Verbose "[$functionName] Not a VMWare device. Continuing"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "[$functionName] Found $($autopilotDevice.count) Autopilot devices."
                Write-Verbose "[$functionName] Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "[$functionName] Autopilot Device Id: $($autoPilotDeviceId)"
            }
        }
        'DeviceId'
        {
            Write-Verbose "[$functionName] Parameter type is DeviceId."
            Write-Verbose "[$functionName] $IdentifyerType is $deviceIdentifyer."
            $autoPilotDeviceId = $deviceIdentifyer
        }
    }
    if ($autoPilotDeviceId)
    {
        Write-Verbose "[$functionName] Found device with id $autoPilotDeviceId in Autopilot."
        Write-Verbose "[$functionName] Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
        Write-Verbose "[$functionName] Delete URI: $deleteUri"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "[$functionName] Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Passing the uri $deleteUri"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "[$functionName] Delete request initiated successfully. Beginning monitoring of device deletion..."
            
            #region Monitor the deletion process
            $retryCount = 0
            $isDeleted = $false
            $deviceInfo = $null
            
            while (-not $isDeleted -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Verifying device deletion, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)"
                
                # Sleep before checking
                Start-Sleep -Seconds $RetryDelaySeconds
                
                # Check if the device still exists
                if ($IdentifyerType -eq 'SerialNumber')
                {
                    $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
                    $deviceInfo = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                }
                else # DeviceId
                {
                    $checkUri = "$autoPilotDeviceURI/$autoPilotDeviceId"
                    try
                    {
                        $deviceInfo = CallGraphAPI -AccessToken $accessToken -ResourcePath $checkUri -Method GET
                        Write-Verbose "[$functionName] Device check response: $($deviceInfo | Out-String)"
                    } 
                    catch
                    {
                        # If the call fails with 404 (not found), the device is deleted
                        Write-Verbose "[$functionName] Error checking device: $_"
                        if ($_.Exception.Response.StatusCode -eq 404)
                        {
                            $deviceInfo = $null
                        }
                    }
                }
                
                if ($null -eq $deviceInfo -or ($deviceInfo.Count -eq 0) -or ($deviceInfo -eq ''))
                {
                    $isDeleted = $true
                    Write-Host "Device deletion confirmed!" -ForegroundColor Green
                    Write-Verbose "[$functionName] Device deletion confirmed at attempt $retryCount."
                }
                else
                {
                    Write-Verbose "[$functionName] Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check."
                }
            }
            
            if ($isDeleted)
            {
                Write-Verbose "[$functionName] Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
                $success = $true
            }
            else
            {
                Write-Host "Device deletion verification timed out after $MaxRetries attempts." -ForegroundColor Red
                Write-Verbose "[$functionName] Delete operation may have been queued but not completed within the monitoring period."
                Write-Warning "Device may still be in the process of being deleted. Please check again later."
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
        }
    }
    else
    {
        Write-Host "No autopilot device found with $IdentifyerType $DeviceIdentifyer."
    }
    return $success
}

function RestartDevice()
{
    [CmdletBinding()]
    param (
        [string]$question = 'Do you want to reboot the device now? (Y/N)',
        [string]$bootMessage = 'Rebooting the device...',
        [string]$reminderMessage = 'Remember to reboot the device to start the device enrollment.'
    )
    $functionName = $MyInvocation.MyCommand.Name
    $reboot = Read-Host -Prompt $question
    while ($reboot -notin ('Y', 'N'))
    {
        $reboot = Read-Host -Prompt $question
        Write-Verbose "[$functionName] User input: $reboot"
        if ($reboot -notin ('Y', 'N'))
        {
            Write-Host "Invalid input. Please enter 'Y' for Yes or 'N' for No." -ForegroundColor Red
            [console]::beep(1000, 500)
        }
    }
    if ($reboot -eq 'Y')
    {
        Write-Verbose "[$functionName] User chose to reboot the device."
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Verbose "[$functionName] User chose not to reboot the device."
        Write-Host $reminderMessage -ForegroundColor Red
        return $false
    }
}
#endregion 

function ExportDeviceReport()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$formattedOutput,
        [Parameter(Mandatory = $false)]
        [string]$outputFile,
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV")]
        [string]$ExportFormat = "HTML"
    )

    $functionName = "ExportDeviceReport"
    Write-Verbose "[$functionName] Starting export with parameters: output file='$outputFile', ExportFormat='$ExportFormat'"
    # Validate ExportFormat
    if ($ExportFormat -notin @("HTML", "CSV"))
    {
        Write-Error "[$functionName] Invalid ExportFormat specified: $ExportFormat. Valid options are 'HTML' or 'CSV'."
        return $false
    }
    
    # Determine device name for file naming
    if (-not $outputFile -or $null -eq $outputFile)
    {
        if (-not $DeviceName)
        {
            $DeviceName = "Device"
            Write-Verbose "[$functionName] Using default device name for export"
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$DeviceName`_Report_$timestamp"
        Write-Verbose "[$functionName] Generated filename: $fileName"
    }
    else
    {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($outputFile)
        Write-Verbose "[$functionName] Using provided output file name: $fileName"
    }
    
    # Determine final export format
    $finalExportFormat = $ExportFormat.ToUpper()
    if ($finalExportFormat -eq "HTML")
    {
        $htmlPath = "$pwd\$fileName.html"
        Write-Verbose "[$functionName] Exporting to HTML: $htmlPath"
        $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Device Report: $DeviceName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        h1 { color: #333; }
        .meta { color: #666; font-style: italic; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Device Report: $DeviceName</h1>
    <div class="meta">Generated on $(Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")</div>
    <table>
        <thead>
            <tr>
                <th>Property</th>
                <th>Value</th>
            </tr>
        </thead>
        <tbody>
"@
        $htmlRows = ""
        foreach ($key in $formattedOutput.Keys)
        {
            $value = [System.Web.HttpUtility]::HtmlEncode($formattedOutput[$key])
            $htmlRows += "            <tr><td>$([System.Web.HttpUtility]::HtmlEncode($key))</td><td>$value</td></tr>`n"
        }
        $htmlFooter = @"
        </tbody>
    </table>
</body>
</html>
"@
        try
        {
            $htmlContent = $htmlHeader + $htmlRows + $htmlFooter
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Host "HTML report exported to: $htmlPath" -ForegroundColor Green
            Write-Verbose "[$functionName] Successfully exported HTML report to $htmlPath"
        }
        catch
        {
            Write-Error "[$functionName] Failed to export HTML report: $($_.Exception.Message)"
            Write-Verbose "[$functionName] HTML export error details: $($_.Exception)"
            return $false
        }
    }
    elseif ($finalExportFormat -eq "CSV")
    {
        $csvPath = "$pwd\$fileName.csv"
        Write-Verbose "[$functionName] Exporting to CSV: $csvPath"
        try
        {
            $csvData = foreach ($key in $formattedOutput.Keys)
            {
                [PSCustomObject]@{
                    Property = $key
                    Value    = $formattedOutput[$key]
                }
            }
            $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "CSV report exported to: $csvPath" -ForegroundColor Green
            Write-Verbose "[$functionName] Successfully exported CSV report to $csvPath"
        }
        catch
        {
            Write-Error "[$functionName] Failed to export CSV report: $($_.Exception.Message)"
            Write-Verbose "[$functionName] CSV export error details: $($_.Exception)"
            return $false
        }
    }
    else
    {
        Write-Error "[$functionName] Unsupported export format: $finalExportFormat"
        return $false
    }
    Write-Verbose "[$functionName] Export completed successfully."
    return $true
}

function ExportDeviceStorage()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $false)]
        [string]$Filter = $null,
        [Parameter(Mandatory = $false)]
        [int]$BatchSize = 20,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeStorageInfo
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    $managedDeviceFilter = "operatingSystem eq 'Windows'"
    $success = $false
    if ($filter)
    {
        Write-Verbose "[$functionName] - Using filter: $filter"
        $managedDeviceFilter = $Filter
    }
    else 
    {
        Write-Verbose "[$functionName] - No filter provided, using default filter: $managedDeviceFilter"
    }
    Write-Verbose "[$functionName] - Starting device memory export process"
    Write-Verbose "[$functionName] - Using batch size of $BatchSize for API requests"
    
    # Store all devices in an array
    $allDevices = [System.Collections.ArrayList]@()
    
    try
    {
        Write-Verbose "[$functionName] - Getting device list from Graph API"
        $deviceListResponse = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $AccessToken -Filter $managedDeviceFilter -consistencyLevel -extraParameters "top=999"
        
        if ($null -eq $deviceListResponse -or $null -eq $deviceListResponse.value -or $deviceListResponse.value.count -eq 0)
        {
            Write-Host "[$functionName] - No devices found. Exiting script." -ForegroundColor Red
            return $false
        }
        
        # Add all devices to our collection (pagination already handled by CallGraphApi)
        $deviceListResponse.value | ForEach-Object { $null = $allDevices.Add($_) }
        
        Write-Verbose "[$functionName] - Retrieved a total of $($allDevices.Count) devices"
        
        # Create CSV object to store the results
        $CSVObject = [System.Collections.ArrayList]@()
        
        # Process devices in batches to reduce API calls
        for ($batchIndex = 0; $batchIndex -lt $allDevices.Count; $batchIndex += $BatchSize)
        {
            $batch = $allDevices | Select-Object -Skip $batchIndex -First $BatchSize
            
            # Create batch request
            $batchRequestBody = @{
                requests = @()
            }
            
            foreach ($device in $batch)
            {
                $deviceId = $device.id
                if ($null -eq $deviceId)
                {
                    continue 
                }
                
                $batchRequestBody.requests += @{
                    id     = $deviceId
                    method = "GET"
                    url    = "/deviceManagement/managedDevices/$deviceId`?`$select=id,hardwareInformation,physicalMemoryInBytes,totalStorageSpaceInBytes,freeStorageSpaceInBytes"
                }
            }
            
            Write-Verbose "[$functionName] - Sending batch request for devices $batchIndex to $($batchIndex + $batch.Count)"
            $batchResponse = CallGraphApi -ResourcePath "`$batch" -accessToken $AccessToken -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth 10)
            
            # Process batch responses
            if ($null -ne $batchResponse -and $null -ne $batchResponse.responses)
            {
                foreach ($response in $batchResponse.responses)
                {
                    if ($response.status -eq 200)
                    {
                        $deviceDetail = $response.body
                        $deviceBasic = $batch | Where-Object { $_.id -eq $response.id } | Select-Object -First 1
                        
                        if ($null -ne $deviceBasic)
                        {
                            $memoryGB = if ($deviceDetail.physicalMemoryInBytes)
                            {
                                [math]::Round($deviceDetail.physicalMemoryInBytes / 1GB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $totalStorageGB = if ($deviceDetail.totalStorageSpaceInBytes)
                            {
                                [math]::Round($deviceDetail.totalStorageSpaceInBytes / 1GB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $freeStorageGB = if ($deviceDetail.freeStorageSpaceInBytes)
                            {
                                [math]::Round($deviceDetail.freeStorageSpaceInBytes / 1GB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $usedStorageGB = if ($totalStorageGB -gt 0 -and $freeStorageGB -gt 0)
                            {
                                [math]::Round($totalStorageGB - $freeStorageGB, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $usedStoragePercent = if ($totalStorageGB -gt 0)
                            {
                                [math]::Round(($usedStorageGB / $totalStorageGB) * 100, 2)
                            }
                            else
                            {
                                0 
                            }
                            
                            $osVersion = if ($deviceBasic.operatingSystem -match "Windows")
                            {
                                "$($deviceBasic.operatingSystem) $($deviceBasic.osVersion)"
                            }
                            else
                            {
                                $deviceBasic.operatingSystem 
                            }
                            
                            # Create export object with expanded properties
                            $exportObject = [PSCustomObject]@{
                                DeviceId              = $deviceBasic.id
                                SerialNumber          = $deviceBasic.serialNumber
                                DeviceName            = $deviceBasic.deviceName
                                Manufacturer          = $deviceBasic.manufacturer
                                Model                 = $deviceBasic.model
                                SystemFamily          = $deviceBasic.systemFamily
                                UserPrincipalName     = $deviceBasic.userPrincipalName
                                UserDisplayName       = $deviceBasic.userDisplayName
                                OperatingSystem       = $osVersion
                                LastSyncDateTime      = $deviceBasic.lastSyncDateTime
                                MemoryGB              = $memoryGB
                                TotalStorageGB        = $totalStorageGB
                                FreeStorageGB         = $freeStorageGB
                                UsedStorageGB         = $usedStorageGB
                                UsedStoragePercent    = $usedStoragePercent
                                EnrollmentProfileName = $deviceBasic.enrollmentProfileName
                                JoinType              = $deviceBasic.joinType
                                ComplianceState       = $deviceBasic.complianceState
                            }
                            
                            Write-Verbose "[$functionName] - Processed device: $($deviceBasic.deviceName) (Memory: $memoryGB GB, Storage: $totalStorageGB GB)"
                            $null = $CSVObject.Add($exportObject)
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] - Failed to get details for device ID $($response.id). Status: $($response.status)"
                    }
                }
            }
            
            # Add a slight delay to prevent throttling
            Start-Sleep -Milliseconds 900
        }
        
        # Export results to CSV
        if ($CSVObject.Count -gt 0)
        {
            Write-Verbose "[$functionName] - Exporting data for $($CSVObject.Count) devices to file $OutputFile"
            $CSVObject | Export-Csv -Path $OutputFile -NoTypeInformation -Force
            Write-Host "[$functionName] - Successfully exported device information to $OutputFile" -ForegroundColor Green
            Write-Host "[$functionName] - Exported $($CSVObject.Count) devices with memory and storage information" -ForegroundColor Green
            $success = $true
        }
        else
        {
            Write-Host "[$functionName] - No device information was collected to export" -ForegroundColor Yellow
            $success = $false
        }
    }
    catch
    {
        Write-Host "[$functionName] - Error processing device information: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] - Exception detail: $($_.Exception | Format-List -Force | Out-String)"
        $success = $false
    }
    return $success
}

function ExportDeviceList()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$outputPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet('autopilot', 'imported', 'unmanaged', 'managed')]
        [string]$deviceType,
        [ValidateSet('Append', 'Overwrite')]
        [string]$fileMode = 'overwrite'
    )

    #region Define variables.
    $functionName = $MyInvocation.MyCommand
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = "$outputPath\$deviceType-DeviceList-$currentDateTime.csv"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    # $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus"
    $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $importedAutopilotExtraParameters = "select=serialNumber,importId,groupTag,state"
    $unmanagedDeviceUri = "devices"
    $unmanagedDeviceFilter = "operatingSystem eq 'Windows'"
    $unmanagedDeviceExtraParameters = "select=id,displayName,manufacturer,model,operatingSystemVersion,profileType,createdDateTime,registrationDateTime,accountEnabled,approximateLastSignInDateTime,enrollmentProfileName,enrollmentType,isCompliant"
    $managedDeviceUri = "deviceManagement/managedDevices"
    $managedDeviceFilter = "operatingSystem eq Windows"
    $managedDeviceExtraParameters = "select=serialNumber,deviceName,manufacturer,model,osVersion,autopilotEnrolled,enrolledDateTime,lastSyncDateTime,complianceState,userPrincipalName,userDisplayName,usersLoggedOn"
    $CSVObject = [System.Collections.ArrayList]@()
    $success = $false
    #endregion

    #region Prepare export object
    switch ($deviceType )
    {
        'autopilot'
        {
            Write-Verbose "[$functionName] fetching Autopilot devices."
            $devices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) Autopilot devices."
        }
        'imported'
        {
            Write-Verbose "[$functionName] fetching Imported Autopilot devices."
            $devices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -extraParameters $importedAutopilotExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) imported Autopilot devices."
        }
        'unmanaged'
        {
            Write-Verbose "[$functionName] fetching Unmanaged devices."
            $devices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken -filter $unmanagedDeviceFilter -extraParameters $unmanagedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) unmanaged devices."
        }
        'managed'
        {
            Write-Verbose "[$functionName] fetching Managed devices."
            $devices = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken -filter $managedDeviceFilter -extraParameters $managedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) managed devices."
        }
    }
    
    Write-Verbose "[$functionName] Processing $($devices.value.Count) $deviceType devices for export."
    for ($i = 0; $i -lt $devices.value.count; $i++)
    {
        $device = $devices.value[$i]
        if (-not $device)
        {
            Write-Verbose "[$functionName] Skipping null or invalid $deviceType device at index $i."
            continue
        }
        switch ($deviceType)
        {
            'autopilot'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
                if ($null -ne $device.lastContactedDateTime)
                {
                    $lastContactedDateTime = $device.lastContactedDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    serialNumber                      = $device.serialNumber
                    groupTag                          = $device.groupTag
                    manufacturer                      = $device.manufacturer
                    model                             = $device.model
                    systemFamily                      = $device.systemFamily
                    enrollmentState                   = $device.enrollmentState
                    deploymentProfileAssignmentStatus = $device.deploymentProfileAssignmentStatus
                    lastContactedDateTime             = $lastContactedDateTime
                }
            }
            'imported'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
                $exportObject = [PSCustomObject] @{
                    serialNumber         = $device.serialNumber
                    importId             = $device.importId
                    groupTag             = $device.groupTag
                    importStatus         = $device.state.deviceImportStatus
                    deviceRegistrationId = $device.state.deviceRegistrationId
                    deviceErrorCode      = $device.state.deviceErrorCode
                    deviceErrorName      = $device.state.deviceErrorName
                }
            }
            'unmanaged'
            {
                Write-Verbose "[$functionName] Preparing $devicetype device with display name $($device.displayName) for export."
                $createdDateTime = $device.createdDateTime
                $registrationDateTime = $device.registrationDateTime
                $approximateLastSignInDateTime = $device.approximateLastSignInDateTime
                if ($null -ne $device.createdDateTime)
                {
                    $createdDateTime = $device.createdDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.registrationDateTime)
                {
                    $registrationDateTime = $device.registrationDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.approximateLastSignInDateTime)
                {
                    $approximateLastSignInDateTime = $device.approximateLastSignInDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    id                            = $device.id
                    displayName                   = $device.displayName
                    manufacturer                  = $device.manufacturer
                    model                         = $device.model
                    operatingSystemVersion        = $device.operatingSystemVersion
                    profileType                   = $device.profileType
                    createdDateTime               = $createdDateTime
                    registrationDateTime          = $registrationDateTime
                    accountEnabled                = $device.accountEnabled
                    approximateLastSignInDateTime = $approximateLastSignInDateTime
                    enrollmentProfileName         = $device.enrollmentProfileName
                    enrollmentType                = $device.enrollmentType
                    isCompliant                   = $device.isCompliant
                }
            }
            'managed'
            {
                Write-Verbose "[$functionName] Preparing $devicetype device object for export."
                $enrollmentDate = $device.enrolledDateTime
                $LastSync = $device.lastSyncDateTime
                $lastLoggedOn = $device.usersLoggedOn.lastLogOnDateTime
                if ($null -ne $device.enrolledDateTime)
                {
                    $enrollmentDate = $device.enrolledDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.lastSyncDateTime)
                {
                    $LastSync = $device.lastSyncDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.usersLoggedOn.lastLogOnDateTime)
                {
                    $lastLoggedOn = $device.usersLoggedOn.lastLogOnDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    serialNumber      = $device.serialNumber
                    deviceName        = $device.deviceName
                    manufacturer      = $device.manufacturer
                    model             = $device.model
                    WindowsVersion    = $device.osVersion
                    autopilotEnrolled = $device.autopilotEnrolled
                    enrollmentDate    = $enrollmentDate
                    LastSync          = $LastSync
                    complianceState   = $device.complianceState
                    userPrincipalName = $device.userPrincipalName
                    userDisplayName   = $device.userDisplayName
                    lastLoggedOn      = $lastLoggedOn
                }
            }
        }
        $CSVObject.Add($exportObject) | Out-Null
    }
    #endregion    

    if ($CSVObject.Count -gt 0)
    {
        Write-Verbose "[$functionName] exporting $($CSVObject.Count) $deviceType devices to $outputFile."
        #Check if the file exists and ask if the user wants to overwrite.
        if (Test-Path $outputFile)
        {
            if ($fileMode -eq 'Append')
            {
                Write-Verbose "[$functionName] Appending to existing file $outputFile."
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append -Encoding UTF8 -Delimiter ','
            }
            else
            {
                Write-Verbose "[$functionName] Overwriting existing file $outputFile."
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
            }
        }
        else
        {
            Write-Verbose "[$functionName] Creating new file $outputFile."
        }
        $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
    }
    else
    {
        Write-Verbose "[$functionName] No devices found for export."
    }
    #check if the csv file exists.
    if (Test-Path $outputFile)
    {
        Write-Verbose "[$functionName] CSV file $outputFile created successfully."
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to create CSV file $outputFile."
        $success = $false
    }
    return $success, $outputFile
}

function ConvertUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $functionName = $MyInvocation.MyCommand.Name
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Verbose "[$functionName] Returning original display name."
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

function GetManagedDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceProperties = [ordered] @{}
    if ($null -eq $settings.MinimumDevicePhysicalMemoryInGB -or $settings.MinimumDevicePhysicalMemoryInGB -eq 0)
    {
        Write-Verbose "[$functionName] No minimum device physical memory specified in settings."
        Write-Verbose "[$functionName] Setting default value to 16GB."
        $MinimumDevicePhysicalMemoryInGB = 16
    }
    else
    {
        $MinimumDevicePhysicalMemoryInGB = $settings.MinimumDevicePhysicalMemoryInGB
        Write-Verbose "[$functionName] Minimum device physical memory specified in settings: $MinimumDevicePhysicalMemoryInGB"
    }
    Write-Host "Checking managed device..."
    Write-Verbose "[$functionName] Managed device: $($enrollmentState.managed)"
    if ($enrollmentState.managed)
    {
        Write-Verbose "[$functionName] Found a managed device."
        Write-Verbose "[$functionName] Checking whether this is an orphan device..."
        Write-Verbose "[$functionName] Autopilot managed device id: $($enrollmentState.autopilot.device.managedDeviceId)"
        Write-Verbose "[$functionName] Managed device id: $($enrollmentState.managedDevice.device.id)"
        Write-Verbose "[$functionName] Checking if they are the same..."
        if ($enrollmentState.managedDevice.device.id -eq $enrollmentState.autopilot.device.managedDeviceId)
        {
            Write-Verbose "[$functionName] Device Id's match."
            Write-Host "The device is not an orphan device."
            $orphanDevice = $false
            Write-Host "Checking whether the device has enough RAM..."
            if ($enrollmentState.managedDevice.memory -ge $MinimumDevicePhysicalMemoryInGB)
            {
                Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of ram, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                $correctRam = $true
            }
            else
            {
                Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                Write-Host "Contact Hardware and Logistics."
                $correctRam = $false
            }   
            Write-Host "Checking for a user association on the manage device..."
            if ($enrollmentState.managedDevice.device.userId -ne '' -and $null -ne $enrollmentState.managedDevice.device.userId)
            {
                Write-Verbose "[$functionName] Found a user..."
                Write-Verbose "[$functionName] User display name: $($enrollmentState.managedDevice.users.userDisplayName)"
                Write-Verbose "[$functionName] User id: $($enrollmentState.managedDevice.device.userId)"
                Write-Verbose "[$functionName] User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)"
                $hasUser = $true
                if ($enrollmentState.managedDevice.users.azureUser)
                {
                    $validUser = $true
                    $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.users.userDisplayName
                    Write-Host "This device is registered to $($normalizedUsername.FullName) ($($enrollmentState.managedDevice.users.userPrincipalName))"
                    if ($null -ne $enrollmentState.managedDevice.users.lastLogOnDateTime)
                    {
                        $lastLogonDate = $enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone
                        Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $lastLogonDate."
                    }
                    else
                    {
                        $lastLogonDate = $null
                        Write-Host "Cannot determine the last time $($normalizedUsername.FirstName) logged on..."
                    }
                }
                else 
                {
                    Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                    Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                    $validUser = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] The managed device is not associated with a user."
                $hasUser = $false
            }
        }
        else
        {
            $orphanDevice = $true
            Write-Verbose "[$functionName] Device Id's do not match."
            Write-Verbose "[$functionName] The device is an orphan device."
        }
    }

    if ($OrphanDevice -eq $false -and $CorrectRam -and -not ($HasUser -and $ValidUser))
    {
        $readyForNextUser = $true
        Write-Verbose "[$functionName] Device is ready for the next user"
    }
    else
    {
        $readyForNextUser = $false
        Write-Verbose "[$functionName] Device is not ready for the next user"
    }
    $managedDeviceProperties.Add('OrphanDevice', $orphanDevice)
    $managedDeviceProperties.Add('CorrectRam', $correctRam)
    $managedDeviceProperties.Add('HasUser', $hasUser)
    $managedDeviceProperties.Add('ValidUser', $validUser)
    $managedDeviceProperties.Add('LastLogonDate', $lastLogonDate)
    $managedDeviceProperties.Add('ReadyForNextUser', $readyForNextUser)
    return $managedDeviceProperties
}

function GetAutopilotDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    $autopilotDeviceProperties = [ordered] @{}
    if ($null -eq $settings.DesiredAutopilotProfiles -or $settings.DesiredAutopilotProfiles.Count -eq 0)
    {
        Write-Verbose "[$functionName] No desired autopilot profiles specified in settings."
        Write-Verbose "[$functionName] Setting default value to 'None'."
        $desiredAutopilotProfiles = $null
    }
    else
    {
        $desiredAutopilotProfiles = $settings.DesiredAutopilotProfiles
        Write-Verbose "[$functionName] Desired autopilot profiles specified in settings: $desiredAutopilotProfiles"
    }
    if ($null -ne $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -and $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedUnkownSyncState', 'assignedInSync'))
    {
        Write-Verbose "[$functionName] The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        $profileAssigned = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        $profileAssigned = $false
    }
    if ($null -ne $desiredAutopilotProfiles -and $enrollmentState.autopilot.device.deploymentProfile.displayName -in $desiredAutopilotProfiles -and $profileAssigned -eq $true)
    {
        Write-Host "The device is assigned to the correct autopilot profile."
        $correctProfile = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device is not assigned to the correct autopilot profile."
        $correctProfile = $false
    }
    Write-Host "Autopilot profile Deployment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
    Write-Host "Assigned profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayname)"
    Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)"
    #Check remediation state.
    $lastRemediationDate = $enrollmentState.autopilot.device.remediationStateLastModifiedDateTime | FormatDateWithTimeZone
    if ($null -ne $enrollmentState.autopilot.device.remediationState -and $enrollmentState.autopilot.device.remediationState -in @('noRemediationRequired', 'unknownFutureValue'))
    {
        Write-Verbose "[$functionName] The device profile remediation state is valid: $($enrollmentState.autopilot.device.remediationState)."
        $remediationStateGood = $true
        Write-Verbose "[$functionName] Remediation state last modified date: $lastRemediationDate"
    }
    else
    {
        Write-Verbose "[$functionName] The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)."
        $remediationStateGood = $false
    }
    Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
    Write-Host "Remediation state last modified date: $lastRemediationDate"
    #Now check enrollment status.
    if ($null -ne $enrollmentState.autopilot.device.enrollmentState -and $enrollmentState.autopilot.device.enrollmentState -in @('enrolled', 'notContacted'))
    {
        Write-Verbose "[$functionName] The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)."
        $enrollmentStateGood = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)."
        $enrollmentStateGood = $false
    }
    Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
    if ($CorrectProfile -and $ProfileAssigned -and $RemediationStateGood -and $EnrollmentStateGood)
    {
        Write-Verbose "[$functionName] Autopilot assignment is good..."
        $AutopilotAssignmentGood = $true
    }
    else
    {
        Write-Verbose "[$functionName] There are issues with this device's autopilot assignment."
        $AutopilotAssignmentGood = $false
        
    }
    Write-Verbose "[$functionName] Autopilot assignment good: $AutopilotAssignmentGood"
    #Add what we got the the autopilotDeviceProperties hashtable
    $autopilotDeviceProperties.Add('CorrectProfile', $correctProfile)
    $autopilotDeviceProperties.Add('ProfileAssigned', $profileAssigned)
    $autopilotDeviceProperties.Add('RemediationStateGood', $remediationStateGood)
    $autopilotDeviceProperties.Add('EnrollmentStateGood', $enrollmentStateGood)
    $autopilotDeviceProperties.Add('AutopilotAssignmentGood', $AutopilotAssignmentGood)
    return $autopilotDeviceProperties
}

function AssessDeviceState() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings,
        [Parameter(Mandatory = $true)]
        [ValidateSet('PropperEnrollmentVerification', 'NextUserReadiness', 'TroubleShooting')]
        [string]$AssessmentType
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region Write verbose log of received parameters.
    Write-Verbose "[$functionName] Received parameters:"
    Write-Verbose "[$functionName] Enrollment state: $($enrollmentState | ConvertTo-Json -Depth 10)"
    Write-Verbose "[$functionName] Assessment type: $AssessmentType"
    Write-Verbose "[$functionName] Settings: $($settings | ConvertTo-Json -Depth 10)"
    $returnValue = [ordered] @{}
    $readinessState = $null
    $action = $null
    $device = $null
    #endregion

    Write-Verbose "[$functionName] Type of assessment: $AssessmentType"
    switch ($AssessmentType)
    {
        'PropperEnrollmentVerification'
        {
            Write-Host "Place holder text..."
            Write-Host "Checking if the device is properly enrolled..."
        }
        'NextUserReadiness'
        {
            Write-Host "Checking if the device is ready for the next user..."
            Write-Verbose "[$functionName] Checking if the device is registered in Autopilot..."
            Write-Verbose "[$functionName] In Autopilot: $($enrollmentState.inAutopilot)"
            if ($enrollmentState.inAutopilot)
            {
                $autopilotReadiness = GetAutopilotDeviceRelevantProperties -enrollmentState $enrollmentState
                $managedDeviceReadiness = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState
                Write-Host "Autopilot assignment good: $($autopilotReadiness.AutopilotAssignmentGood)"
                Write-Host "Managed device readiness good: $($managedDeviceReadiness.ReadyForNextUser)"
                if ($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser)
                {
                    Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of RAM, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                    $readinessState = 'Ready'
                    $action = 'None'
                    $device = $enrollmentState.managedDevice.device.id
                }
                else
                {
                    Write-Host "The device is not ready for the next user."
                    Write-Host "See below for more information."
                    #let us explain to the user what the problem is.
                    if ($autopilotReadiness.CorrectProfile -eq $false)
                    {
                        Write-Host "The device is not assigned to the correct autopilot profile."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.ProfileAssigned -eq $false)
                    {
                        Write-Host "The device is not assigned to an autopilot profile."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.RemediationStateGood -eq $false)
                    {
                        Write-Host "The device has a remediation state that is not valid."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.EnrollmentStateGood -eq $false)
                    {
                        Write-Host "The device has an enrollment state that is not valid."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.OrphanDevice -eq $true)
                    {
                        Write-Host "The device is an orphan device."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.CorrectRam -eq $false)
                    {
                        Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                        Write-Host "Contact Hardware and Logistics."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.HasUser)
                    {
                        Write-Host "The managed device is associated with a user."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = 'NotReady'
                        $action = 'WipeOrClean'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.ValidUser -eq $false)
                    {
                        Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = 'NotReady'
                        $action = 'WipeOrClean'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    else
                    {
                        Write-Host "The device is not ready for the next user."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                }
            }
            else
            {
                Write-Host "The device is not registered in Autopilot."
                Write-Host "You may want to contact an Intune admin."
                $readinessState = 'NotReady'
                $action = 'ContactAdmin'
                $device = $enrollmentState.managedDevice.device.id
            }
        }
        'TroubleShooting'
        {
            Write-Host "Place holder text..."
            Write-Host "Troubleshooting the device..."
        }
    }        
    $returnValue.Add('ReadinessState', $readinessState)
    $returnValue.Add('Action', $action)
    $returnValue.Add('Device', $device)
    Write-Verbose "[$functionName] Returning readiness state: $readinessState"
    Write-Verbose "[$functionName] Returning action: $action"
    Write-Verbose "[$functionName] Returning device: $device"
    return $returnValue
}

function ShowDeviceReport()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'EnrollmentState')]
        $enrollmentState,
        [Parameter(Mandatory = $true, ParameterSetName = 'HashTable')]
        [hashtable]$report,
        [Parameter(Mandatory = $false)]
        [string[]]$PrefixList = @('Intune', 'Autopilot'),
        [string]$DeviceName,
        [Parameter(Mandatory = $false)]
        [string]$SerialNumber
    )
    #region usage info
    # Use with enrollment state (original ShowDeviceReport functionality)
    #ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
    # Use with hashtable (original DisplayReport functionality)
    #Show-DeviceReport -report $myHashtable -PrefixList @('Custom', 'Prefix')
    # Direct export without prompting
    #Show-DeviceReport -enrollmentState $state -Export -ExportFormat "CSV"   
    #endregion usage info
    $functionName = $MyInvocation.MyCommand.Name
    #region write verbose log of received parameters
    Write-Verbose "[$functionName] Starting device report generation"
    Write-Verbose "[$functionName] Parameter Set: $($PSCmdlet.ParameterSetName)"
    Write-Verbose "[$functionName] Export: $Export"
    Write-Verbose "[$functionName] ExportFormat: $ExportFormat"
    Write-Verbose "[$functionName] OutputFile: $OutputFile"
    Write-Verbose "[$functionName] PrefixList: $($PrefixList -join ', ')"
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Verbose "[$functionName] Enrollment state provided"
    }
    else
    {
        Write-Verbose "[$functionName] Report hashtable provided with $($report.Keys.Count) properties"
    }
    Write-Verbose "[$functionName] DeviceName: $DeviceName"
    Write-Verbose "[$functionName] SerialNumber: $SerialNumber"
    #endregion write verbose log of received parameters
    #region Build report data
    $output = [ordered]@{}
    
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Verbose "[$functionName] Building report from enrollment state"
        
        # Get latest autopilot event
        if ($enrollmentState.autopilot.events -and $enrollmentState.autopilot.events.Count -gt 0)
        {
            $latestAutopilotEvent = $enrollmentState.autopilot.events | Select-Object -First 1
            Write-Verbose "[$functionName] Found $($enrollmentState.autopilot.events.Count) autopilot events"
        }
        else
        {
            $latestAutopilotEvent = $null
            Write-Verbose "[$functionName] No autopilot events found"
        }
        
        $output = [ordered] @{
            InputIdentifier               = $SerialNumber
            IntuneDeviceName              = $enrollmentState.managedDevice.device.deviceName
            IntuneSerialNumber            = $enrollmentState.managedDevice.device.serialNumber
            IntuneDeviceMemory            = "$($enrollmentState.managedDevice.memory) GB"
            IntuneManagedDeviceId         = $enrollmentState.managedDevice.device.Id
            IntuneEnrollmentDate          = if ($enrollmentState.managedDevice.device.enrolledDateTime)
            {
                $enrollmentState.managedDevice.device.enrolledDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneLastSync                = if ($enrollmentState.managedDevice.device.lastSyncDateTime)
            {
                $enrollmentState.managedDevice.device.lastSyncDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneEnrollmentProfile       = $enrollmentState.managedDevice.device.enrollmentProfileName
            IntunePrimaryUPN              = $enrollmentState.managedDevice.device.userPrincipalName
            IntuneAzureUser               = $enrollmentState.managedDevice.users.AzureUser
            IntuneUserDisplayName         = $enrollmentState.managedDevice.users.userDisplayName
            IntuneReportedUserDisplayName = $enrollmentState.managedDevice.device.userDisplayName
            IntuneLastLogon               = if ($enrollmentState.managedDevice.users.lastLogOnDateTime)
            {
                $enrollmentState.managedDevice.users.lastLogOnDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneActionResults           = $enrollmentState.managedDevice.device.deviceActionResults
            IntuneCertExpiration          = if ($enrollmentState.managedDevice.device.managementCertificateExpirationDate)
            {
                $enrollmentState.managedDevice.device.managementCertificateExpirationDate | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneComplianceExpiry        = if ($enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime)
            {
                $enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneAutopilotEnrolled       = $enrollmentState.managedDevice.device.autopilotEnrolled
            IntuneRegistrationState       = $enrollmentState.managedDevice.device.deviceRegistrationState
            IntuneIsEncrypted             = $enrollmentState.managedDevice.device.isEncrypted
            IntuneEnrollmentType          = $enrollmentState.managedDevice.device.deviceEnrollmentType
            IntunesVersion                = $enrollmentState.managedDevice.device.sVersion
            IntuneComplianceState         = $enrollmentState.managedDevice.device.complianceState
            IntuneManagementState         = $enrollmentState.managedDevice.device.managementState
            IntuneOwnerType               = $enrollmentState.managedDevice.device.managedDeviceOwnerType
            AutopilotDeviceId             = $enrollmentState.autopilot.device.id
            AutopilotState                = $enrollmentState.autopilot.device.enrollmentState
            AutopilotProfileAssigned      = $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus
            AutopilotProfileAssignedDate  = if ($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime)
            {
                $enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotProfileName          = $enrollmentState.autopilot.device.deploymentProfile.displayName
            AutopilotAssignedUser         = $enrollmentState.autopilot.device.userPrincipalName
            AutopilotLastContacted        = if ($enrollmentState.autopilot.device.lastContactedDateTime)
            {
                $enrollmentState.autopilot.device.lastContactedDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotLatestEventTime      = if ($latestAutopilotEvent -and $latestAutopilotEvent.eventDateTime)
            {
                $latestAutopilotEvent.eventDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotLatestProfile        = $latestAutopilotEvent.windowsAutopilotDeploymentProfileDisplayName
            AutopilotLatestStatus         = $latestAutopilotEvent.deploymentState
            AutopilotLatestError          = $latestAutopilotEvent.enrollmentFailureDetails
        }
        
        # Set device name for export if not provided
        if (-not $DeviceName)
        {
            $DeviceName = $enrollmentState.managedDevice.device.deviceName
        }
    }
    else
    {
        Write-Verbose "[$functionName] Using provided report hashtable"
        $output = $report
    }
    #endregion Build report data
    
    #region Format property names and display report
    Write-Verbose "[$functionName] Formatting output for display"
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    
    foreach ($key in $output.Keys)
    {
        Write-Verbose "[$functionName] Processing property: $key"
        
        # Format the property name to be more readable
        $readableKey = $key
        $matchedPrefix = $null
        
        # Check for prefix matches
        foreach ($prefix in $PrefixList)
        {
            if ($key -match "^($prefix)(.+)$")
            {
                $matchedPrefix = $prefix
                Write-Verbose "[$functionName] Found prefix '$prefix' for key '$key'"
                break
            }
        }
        
        if ($matchedPrefix)
        {
            $prefix = $matches[1]
            $remainder = $matches[2]
            # Insert spaces before capital letters in the remainder
            $formattedRemainder = [regex]::Replace($remainder, '(?<=[a-z])(?=[A-Z])', ' ')
            $readableKey = "$prefix $formattedRemainder"
        }
        else
        {
            # Insert spaces before capital letters
            $readableKey = [regex]::Replace($key, '(?<=[a-z])(?=[A-Z])', ' ')
        }
        
        # Format the value based on type
        $formattedValue = $output[$key]
        if ($output[$key] -is [DateTime])
        {
            Write-Verbose "[$functionName] Formatting DateTime value for key '$key'"
            $formattedValue = FormatDateWithTimeZone -DateTime $output[$key]
        }
        elseif ($null -eq $output[$key])
        {
            $formattedValue = "N/A"
        }
        
        $formattedOutput[$readableKey] = $formattedValue
        
        # Display each property and value
        Write-Host "$readableKey`: $formattedValue"
    }
    Write-Verbose "[$functionName] Formatted $($formattedOutput.Keys.Count) properties for display"    #endregion Format property names and display report
    
    #region Handle export decision
    $HTMLAction = {
        Write-Verbose "[$functionName] User selected HTML export"
        $exportResult = ExportDeviceReport -formattedOutput $formattedOutput -ExportFormat "HTML"
        if ($exportResult)
        {
            Write-Host "Report exported to HTML successfully."
        }
        else
        {
            Write-Host "Failed to export report to HTML."
        }
        return $exportResult 
    } 
    $CSVAction = {
        Write-Verbose "[$functionName] User selected CSV export"
        $exportResult = ExportDeviceReport -formattedOutput $formattedOutput -ExportFormat "CSV"
        if ($exportResult)
        {
            Write-Host "Report exported to CSV successfully."
        }
        else
        {
            Write-Host "Failed to export report to CSV."
        }
        return $exportResult 
    } 
    Write-Verbose "[$functionName] Prompting user for export decision"
    $exportMenu = NewMenu -Title "Export report" -Description "Select the format to which you would like to export the report"
    $exportMenu = AddMenuItem -Menu $exportMenu -Name "Export to HTML" -Action $HTMLAction -ReturnsValue
    $exportMenu = AddMenuItem -Menu $exportMenu -Name "Export to CSV" -Action $CSVAction -ReturnsValue
    $selection = ShowMenu -Menu $exportMenu
    if ($null -ne $selection )
    {
        Write-Verbose "[$functionName] ShowMenu returned: '$selection' (Type: $($selection.GetType().Name))"
        # Validate that we got a proper selection, not a navigation option
        if ($selection -eq "Back" -or $selection -eq "Main Menu" -or $selection -eq 0 -or $selection -eq "0")
        {
            Write-Verbose "[$functionName] ShowMenu returned navigation option: '$selection', treating as navigation"
            return $selection
        }
    }
    else
    {
        Write-Verbose "[$functionName] No export selected. Exiting."
        return $null
    }
    #endregion Handle export decision
    Write-Verbose "[$functionName] Device report generation completed"
    return $true
}
#region Encryption functions
$excludeFields = @('domain', 'name', 'scope', 'auth')
function TestIsBase64String()
{
    param (
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value))
    {
        return $false
    }
    # A common check: length must be a multiple of 4.
    # And it should not contain characters outside the Base64 character set.
    # This is a basic check; more robust validation might be needed for edge cases.
    if (($Value.Length % 4 -ne 0) -or ($Value -notmatch "^[a-zA-Z0-9+/]*=*$"))
    {
        return $false
    }

    try
    {
        $null = [Convert]::FromBase64String($Value)
        return $true
    }
    catch
    {
        return $false
    }
}

function isEncrypted()
{
    [CmdletBinding()]
    param (
        [psObject]$data,
        [string[]]$excludeFields = $excludeFields
    )
    
    function CountEncryptionStatus
    {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields = $excludeFields
        )
        
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Initializing encryption status count object."
        $result = [PSCustomObject]@{
            EncryptedCount   = 0
            UnencryptedCount = 0
        }
        Write-Verbose "[$functionName] Checking whether the input object is null."
        if ($null -eq $InputObject)
        {
            Write-Verbose "[$functionName] Input object is null, returning default counts."
            return $result
        }
        Write-Verbose "[$functionName] Checking input object type"
        if ($InputObject -is [array])
        {
            Write-Verbose "[$functionName] Input object is an array, iterating through its items."
            foreach ($item in $InputObject)
            {
                Write-Verbose "[$functionName] Checking item $item."
                $itemStatus = CountEncryptionStatus -InputObject $item
                Write-Verbose "[$functionName] Item encryption status: EncryptedCount=$($itemStatus.EncryptedCount), UnencryptedCount=$($itemStatus.UnencryptedCount)"
                $result.EncryptedCount += $itemStatus.EncryptedCount
                $result.UnencryptedCount += $itemStatus.UnencryptedCount
                Write-Verbose "[$functionName] Updated counts: EncryptedCount=$($result.EncryptedCount), UnencryptedCount=$($result.UnencryptedCount)"
            }
            Write-Verbose "[$functionName] Finished processing array. Returning counts."
        }
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            Write-Verbose "[$functionName] Input object is a PSCustomObject or hashtable, iterating through its properties."
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[$functionName] Checking property $($prop.Name) with value $($prop.Value)."
                if ($prop.Name -notin $ExcludeFields)
                {
                    Write-Verbose "[$functionName] Property $($prop.Name) is not excluded, checking its value."
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                    {
                        Write-Verbose "[$functionName] Property $($prop.Name) is a nested object or array, recursing into it."
                        $nestedStatus = CountEncryptionStatus -InputObject $prop.Value
                        $result.EncryptedCount += $nestedStatus.EncryptedCount
                        $result.UnencryptedCount += $nestedStatus.UnencryptedCount
                        Write-Verbose "[$functionName] Nested property $($prop.Name) counts: EncryptedCount=$($nestedStatus.EncryptedCount), UnencryptedCount=$($nestedStatus.UnencryptedCount)"
                    }
                    elseif ($prop.Value -is [string] -and $prop.Value.Length -gt 0)
                    {
                        Write-Verbose "[$functionName] Checking if the value of $($prop.Name) is encrypted."
                        if (TestIsBase64String -Value $prop.Value)
                        {
                            Write-Verbose "[$functionName] The value of $($prop.Name) is encrypted."
                            $result.EncryptedCount++
                        }
                        else
                        {
                            Write-Verbose "[$functionName] The value of $($prop.Name) is not encrypted."
                            $result.UnencryptedCount++
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] The value of $($prop.Name) is not a string, skipping."
                        $result.UnencryptedCount++
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Property $($prop.Name) is excluded, skipping."
                }
            }
        }
        else
        {
            if ($InputObject -is [string] -and $InputObject.Length -gt 0)
            {
                Write-Verbose "[$functionName] Input object is a string, checking if it is encrypted."
                if ($inputObject -notin $ExcludeFields)
                {

                    if (TestIsBase64String -Value $InputObject)
                    {
                        Write-Verbose "[$functionName] The input string is encrypted."
                        $result.EncryptedCount++
                    }
                    else
                    {
                        Write-Verbose "[$functionName] The input string is not encrypted."
                        $result.UnencryptedCount++
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] Input object is not a string or is empty, treating as unencrypted."
                $result.UnencryptedCount++
            }
        }
        Write-Verbose "[$functionName] Final counts: EncryptedCount=$($result.EncryptedCount), UnencryptedCount=$($result.UnencryptedCount)"
        return $result
    }

    $functionName = $MyInvocation.MyCommand.Name
    $isEncrypted = $false
    Write-Verbose "[$functionName] Checking if the data is encrypted."
    
    $encryptionStatus = CountEncryptionStatus -InputObject $data
    $encryptedCount = $encryptionStatus.EncryptedCount
    $unencryptedCount = $encryptionStatus.UnencryptedCount
    Write-Verbose "[$functionName] The number of encrypted values is $encryptedCount"
    Write-Verbose "[$functionName] The number of unencrypted values is $unencryptedCount"
    
    # If the number of encrypted values is greater than the number of unencrypted values, the data is encrypted.
    if ($encryptedCount -gt $unencryptedCount -and $encryptedCount -gt 0)
    {
        Write-Verbose "[$functionName] The data is considered encrypted."
        $isEncrypted = $true
    }
    Write-Verbose "[$functionName] The data is encrypted: $isEncrypted"
    return $isEncrypted
}

function DecryptObject()
{
    [CmdletBinding()]
    param (
        [object]$encryptedObject,
        [string[]]$excludeFields = $excludeFields
    )
    
    function Invoke-RecursiveDecryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            return $null 
        }
        Write-Verbose "[DECRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[DECRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveDecryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[DECRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
        
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
            
                Write-Verbose "[DECRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[DECRYPT] Value type: $($value.GetType().FullName)"
            
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
            
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveDecryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($value -is [string] -and (TestIsBase64String -Value $value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($value))
                            $result[$key] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for key '$key' at path '$currentPropertyPath'. Value: '$value'. Assigning original value."
                            $result[$key] = $value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Hashtable key '$key' is not a decodable string. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
        
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[DECRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[DECRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[decrypt] Property type: $($prop.Value.GetType().FullName)"
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($prop.Value -is [string] -and (TestIsBase64String -Value $prop.Value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($prop.Value))
                            $result[$prop.Name] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for property '$($prop.Name)' at path '$currentPropertyPath'. Value: '$($prop.Value)'. Assigning original value."
                            $result[$prop.Name] = $prop.Value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Property '$($prop.Name)' is not a decodable string. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string element directly in an array)
        elseif ($InputObject -is [string])
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this string) was excluded
            {
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            elseif (TestIsBase64String -Value $InputObject)
            {
                Write-Verbose ("[DECRYPT] Attempting to decrypt primitive string value at path '{0}'" -f $ParentPath)
                try
                {
                    $decodedValuePrim = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
                    Write-Verbose ("[DECRYPT] Decrypted primitive value at path '{0}': {1}" -f $ParentPath, $decodedValuePrim)
                    return $decodedValuePrim
                }
                catch
                {
                    Write-Warning "[DECRYPT] Failed to decode Base64 string for primitive at path '$ParentPath'. Value: '$InputObject'. Returning original value."
                    return $InputObject # Keep original if not valid Base64 or UTF8
                }
            }
            else
            {
                # Not Base64, return as is
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is not Base64. Returning as-is."
                return $InputObject
            }
        }
        else # Other primitive types (int, bool, etc.) or other object types, return as is
        {
            Write-Verbose "[DECRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not a string or already handled. Returning as-is."
            return $InputObject
        }
    }
    
    $result = Invoke-RecursiveDecryption -InputObject $encryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were decrypted.'
        return $null
    }
    
    Write-Verbose "Decryption complete"
    return $result
}

function EncryptObject()
{
    [CmdletBinding()]
    param (
        [object]$decryptedObject,
        [string[]]$excludeFields = $excludeFields
    )


    function Invoke-RecursiveEncryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            Write-Verbose "[ENCRYPT] InputObject is null at path '$ParentPath'. Returning null."; return $null 
        }
        Write-Verbose "[ENCRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[ENCRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveEncryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[ENCRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
        
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
            
                Write-Verbose "[ENCRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Value type: $($value.GetType().FullName)"
                Write-Verbose "[ENCRYPT] Value: $value"
            
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
            
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[ENCRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($null -eq $value)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' has null value. Assigning null."
                    $result[$key] = $null
                }
                elseif ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveEncryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$key] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, $encodedValue)
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Hashtable key '$key' value type '$($value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
        
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[ENCRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[ENCRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Property type: $($prop.Value.GetType().FullName)"
                if ($prop.Name -in $excludeFields)
                {
                    Write-Verbose "[ENCRYPT] Property value: $($prop.Value)"    
                }
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded
                Write-Verbose "[ENCRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"
                if ($null -eq $prop.Value)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is null. Assigning null."
                    $result[$prop.Name] = $null
                }
                elseif ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $prop.Value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$prop.Name] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, 'redacted')
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Property '$($prop.Name)' type '$($prop.Value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string/number/bool element directly in an array)
        elseif (($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [bool] -or $InputObject -is [double]))
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this primitive) was excluded
            {
                Write-Verbose "[ENCRYPT] Primitive value at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            else
            {
                Write-Verbose ("[ENCRYPT] Encrypting primitive value at path '{0}'" -f $ParentPath)
                $stringValuePrim = $InputObject.ToString()
                $encodedValuePrim = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValuePrim))
                Write-Verbose ("[ENCRYPT] Encrypted primitive value at path '{0}': {1}" -f $ParentPath, $encodedValuePrim)
                return $encodedValuePrim
            }
        }
        else # Other types not explicitly handled (e.g. custom objects not PSCustomObject/hashtable, or other primitive types if any), return as is.
        {
            Write-Verbose "[ENCRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not processed for encryption. Returning as-is."
            return $InputObject
        }
    }

    $result = Invoke-RecursiveEncryption -InputObject $decryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were encrypted.'
        return $null
    }
    
    Write-Verbose "Encryption complete"
    return $result
}

function DecryptAndEncrypt()
{
    param (
        $data,
        [string[]]$excludeFields = $excludeFields,
        [string]$operation
    )
    
    # ### Main script ###
    if ($operation -eq 'encrypt')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is already encrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = EncryptObject -decryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'decrypt')
    {
        if (!(isEncrypted -data $data))
        {
            Write-Host 'The data is already decrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = DecryptObject -encryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'check')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is encrypted.'
        }
        else
        {
            Write-Host "The data in $inputFile is not encrypted."
        }
        exit
    }
    else
    {
        Write-Error 'No operation was specified.'
        exit
    }


    #make sure the output file exists.  If so, prompt to overwrite., otherwise create, unless the Force switch is set.
    if (Test-Path $outputFile)
    {
        if ($Force)
        {
            Clear-Content -Path $OutputFile
        }
        else
        {
            $overwrite = Read-Host -Prompt "The file $outputFile already exists.  Do you want to overwrite it? (Y/N)"
            if ($overwrite -eq 'Y')
            {
                Clear-Content -Path $OutputFile
            }
            else
            {
                Write-Host "The file $outputFile was not overwritten.  Exiting."
                exit
            }
        }
    }
    else
    {
        New-Item -Path $OutputFile -ItemType File -Force | Out-Null
    }


    #write the encoded data to the output file if it is not null.
    if ($encodedData)
    {
        Write-Host "Processing data in $inputFile"
        Write-Host "Writing data to $outputFile"
        Write-Verbose "The encoded data is: $($encodedData | ConvertTo-Json)"
       
        $encodedData | ConvertTo-Json | Set-Content -Path $outputFile -ErrorAction Stop
        Write-Host 'Data processed successfully.'
    }
    else
    {
        Write-Host 'No data was processed.'
        exit
    }
}
#endregion Encryption functions

function FormatScopes()
{
    [CmdletBinding()]
    param(
        [string]$scopes,
        [switch]$AsIs,
        [switch]$Reverse
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] [FormatScopes] Called with AsIs=$AsIs, Reverse=$Reverse"
    #Check for null or empty scopes.
    if (-not $scopes)
    {
        Write-Verbose "[$functionName] [FormatScopes] No scopes provided. Returning empty string."
        return ""
    }
    #region Format scopes properly if necessary
    $scopesFormatted = $scopes
    Write-Verbose "[$functionName] [FormatScopes] Received a scope string of length $($scopes.Length) characters"
    if (!$AsIs -and $scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
    {
        Write-Verbose "[$functionName] [FormatScopes] Formatting scopes to include Graph API prefix"
        $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $formattedScopesArray = @()
        Write-Verbose "[$functionName] [FormatScopes] Processing scope array with $($scopesArray.Count) items"
        foreach ($scope in $scopesArray)
        {
            Write-Verbose "[$functionName] Processing scope: $scope"
            if ($scope -eq "offline_access")
            {
                $formattedScopesArray += $scope
                Write-Verbose "[$functionName] [FormatScopes] Added as is: $scope"
            }
            else
            {
                # Check if the scope already has the Graph prefix
                if (-not $scope.StartsWith("https://graph.microsoft.com/"))
                {
                    $formattedScopesArray += "https://graph.microsoft.com/$scope"
                    Write-Verbose "[$functionName] [FormatScopes] Added prefix: https://graph.microsoft.com/$scope"
                }
                else
                {
                    $formattedScopesArray += $scope
                    Write-Verbose "[$functionName] [FormatScopes] Added as is (already has prefix): $scope"
                }
            }
        }
        Write-Verbose "[$functionName] [FormatScopes] Count of Scopes formatted to include Graph API prefix: $($formattedScopesArray.count)"
        Write-Verbose "[$functionName] [FormatScopes] Converting from array back to string."
        $scopesFormatted = $formattedScopesArray -join ' '
    }
    elseif ($AsIs -and $scopes -and $scopes.Contains("https://graph.microsoft.com/"))
    {
        Write-Verbose "[$functionName] [FormatScopes] Reversing scopes already formatted with Graph API prefix"
        Write-Verbose "[$functionName] [FormatScopes] The type of scopes received is: $($scopes.GetType())"
        Write-Verbose "[$functionName] [FormatScopes] Converting into an array."
        $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $FormattedScopesArray = @()
        Write-Verbose "[$functionName] [FormatScopes] Processing scope array with $($scopesArray.Count) items"
        foreach ($scope in $scopesArray)
        {
            Write-Verbose "[$functionName] [FormatScopes] Processing scope: $scope"
            if ($scope.StartsWith("https://graph.microsoft.com/"))
            {
                Write-Verbose "[$functionName] [FormatScopes] Removing prefix from scope: $scope"
                $formattedScope = $scope -replace "https://graph.microsoft.com/", ""
                $formattedScopesArray += $formattedScope
                Write-Verbose "[$functionName] [FormatScopes] Scope is now $formattedScope"
            }
            else
            {
                $formattedScopesArray += $scope
                Write-Verbose "[$functionName] [FormatScopes] Added as is (no prefix): $scope"
            }
        }
        $scopesFormatted = $FormattedScopesArray
    }
    else
    {
        Write-Verbose "[$functionName] [FormatScopes] Scopes already properly formatted or empty"
    }
    Write-Verbose "[$functionName] [FormatScopes] Using scopes: $($scopesFormatted.count)"
    if (!$AsIs -and !$Reverse)
    {
        Write-Verbose "[$functionName] [FormatScopes] Checking for openid."
        if (-not $scopesFormatted.Contains("openid"))
        {
            $scopesFormatted = "openid $scopesFormatted"
            Write-Verbose "[$functionName] [FormatScopes] Added openid to scopes: $scopesFormatted"
        }
        else
        {
            Write-Verbose "[$functionName] [FormatScopes] openid already present in scopes."
        }
        Write-Verbose "[$functionName] [FormatScopes] Checking for offline_access."
        if (-not $scopesFormatted.Contains("offline_access"))
        {
            $scopesFormatted = "offline_access $scopesFormatted"
            Write-Verbose "[$functionName] [FormatScopes] Added offline_access to scopes: $scopesFormatted"
        }
        else
        {
            Write-Verbose "[$functionName] [FormatScopes] offline_access already present in scopes."
        }
    }
    else
    {
        Write-Verbose "[$functionName] [FormatScopes] Skipping openid and offline_access addition."
    }
    #endregion Format scopes
    return $scopesFormatted
}    

function Get-TokenFromResponse()
{
    param($tokenResponse, $domain, $refreshToken)
    $functionName = $MyInvocation.MyCommand.Name
    $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
    Write-Verbose "[$functionName] Token absolute expiry time: $($tokenExpiryTime)"
    $cachedToken = [ordered] @{
        'domain'           = $domain
        access_token       = $tokenResponse.access_token
        AbsoluteExpiryTime = $tokenExpiryTime
        'expires_in'       = $tokenResponse.expires_in
    }
        
    # Add refresh token if available
    if ($refreshToken -or $tokenResponse.refresh_token)
    {
        $cachedToken.Add('refresh_token', $tokenResponse.refresh_token)
    }
        
    # Add scope if available
    if ($tokenResponse.scope)
    {
        $cachedToken.Add('scope', $tokenResponse.scope)
    }
        
    return $cachedToken
}

function Start-HttpListener()
{
    param (
        [string]$redirectUri
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting HTTP listener function with redirectUri: $redirectUri"
    # Result object to return
    $result = @{
        Success      = $false
        Code         = $null
        ErrorMessage = $null
    }
    try
    {
        # Get local IP address for diagnostics
        try
        {
            $localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*Virtual*"}).IPAddress
            Write-Verbose "[$functionName] Local IP addresses: $($localIp -join ', ')"
        }
        catch
        {
            Write-Verbose "[$functionName] Could not get local IP address: $_"
        }
        # Create HTTP listener
        $listener = New-Object System.Net.HttpListener
        # Make sure redirect URI ends with a slash for matching
        $redirectUri = $redirectUri.TrimEnd('/') + '/'
        Write-Verbose "[$functionName] Using redirect URI: $redirectUri"
        # Add prefix
        $listener.Prefixes.Add($redirectUri)
        Write-Verbose "[$functionName] Added listener prefix: $redirectUri"
        # Start listener
        Write-Verbose "[$functionName] Starting HTTP listener..."
        $listener.Start()
        Write-Host "Waiting for authorization response. Please complete the sign in within your browser..."
        # Set timeout for listener
        $timeout = New-TimeSpan -Minutes 5
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        # Wait for the callback
        while ($stopwatch.Elapsed -lt $timeout)
        {
            # Check for pending request with a timeout
            if ($listener.IsListening)
            {
                try
                {
                    # Try to get context with a 15-second timeout
                    $task = $listener.GetContextAsync()
                    $timeoutTask = [System.Threading.Tasks.Task]::Delay(15000)
                    $completedTask = [System.Threading.Tasks.Task]::WhenAny($task, $timeoutTask).GetAwaiter().GetResult()
                    # If the HTTP request came in before timeout
                    if ($completedTask -eq $task)
                    {
                        $context = $task.GetAwaiter().GetResult()
                        Write-Verbose "[$functionName] Received HTTP request"
                        # Get request details for diagnostics
                        $request = $context.Request
                        Write-Verbose "[$functionName] Request URL: $($request.Url)"
                        Write-Verbose "[$functionName] Request headers: $($request.Headers)"
                        # Check if QueryString exists and has keys
                        if ($null -ne $request.QueryString -and $request.QueryString.Count -gt 0)
                        {
                            Write-Verbose "[$functionName] Query string keys: $($request.QueryString.AllKeys -join ', ')"
                            # Check for code
                            $code = $request.QueryString.Get("code")
                            if ($null -ne $code)
                            {
                                Write-Verbose "[$functionName] Successfully retrieved authorization code"
                                $result.Success = $true
                                $result.Code = $code
                            }
                            else
                            {
                                # Check if there's an error
                                $authError = $request.QueryString.Get("error")
                                $errorDescription = $request.QueryString.Get("error_description")
                                if ($authError)
                                {
                                    Write-Verbose "[$functionName] Error in response: $authError - $errorDescription"
                                    $result.ErrorMessage = "Authentication error: $authError - $errorDescription"
                                }
                                else
                                {
                                    Write-Verbose "[$functionName] No code or error found in query string"
                                    $result.ErrorMessage = "Authorization code not found in the response"
                                }
                            }
                        }
                        else
                        {
                            Write-Verbose "[$functionName] Query string is empty or null"
                            $result.ErrorMessage = "Empty query string in redirect response"
                        }
                        # Send response to browser
                        $response = $context.Response
                        $responseHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authentication Complete</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f0f0f0; }
        .container { background-color: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); padding: 40px; text-align: center; max-width: 600px; }
        h1 { color: #0078d4; margin-bottom: 20px; }
        p { color: #333; font-size: 16px; line-height: 1.6; }
        .status { font-weight: bold; margin: 20px 0; padding: 10px; border-radius: 4px; }
        .success { background-color: #dff6dd; color: #107c10; }
        .error { background-color: #fde7e9; color: #d13438; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Authentication Response</h1>
        $(if ($result.Success) {
            '<div class="status success">Authentication successful! You can close this window and return to the application.</div>'
        } else {
            "<div class='status error'>Authentication error: $($result.ErrorMessage)</div>"
        })
        <p>You may close this window and return to the PowerShell window.</p>
    </div>
</body>
</html>
"@
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
                        $response.ContentLength64 = $buffer.Length
                        $response.ContentType = "text/html"
                        $response.StatusCode = 200
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                        $response.Close()
                        # Break out of the loop
                        break
                    }
                }
                catch
                {
                    Write-Verbose "[$functionName] Error while waiting for request: $_"
                    Write-Verbose "[$functionName] Exception details: $($_.Exception.ToString())"
                    $result.ErrorMessage = "HTTP listener error: $($_.Exception.Message)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Listener is no longer listening"
                $result.ErrorMessage = "HTTP listener stopped unexpectedly"
                break
            }
            # Brief pause before checking again
            Start-Sleep -Milliseconds 100
        }
        # Check for timeout
        if ($stopwatch.Elapsed -ge $timeout)
        {
            Write-Verbose "[$functionName] Timeout waiting for authentication response"
            $result.ErrorMessage = "Timed out waiting for authentication response"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error in HTTP listener: $_"
        Write-Verbose "[$functionName] Exception details: $($_.Exception.ToString())"
        $result.ErrorMessage = "Failed to start HTTP listener: $($_.Exception.Message)"
    }
    finally
    {
        # Clean up
        if ($listener -and $listener.IsListening)
        {
            $listener.Stop()
            $listener.Close()
            Write-Verbose "[$functionName] HTTP listener stopped"
        }
    }
    return $result
}

function Save-TokenToCache()
{
    param($cachedToken, $cacheType, $cacheTokenFile, $cacheFolder)
    $functionName = $MyInvocation.MyCommand.Name
    # Save access token according to cache type
    if ($cacheType -eq 'memory')
    {
        Write-Verbose "[$functionName] Saving access token to memory cache."
        $Global:MemoryCache['accessToken'] = $cachedToken
    }
    else
    {
        Write-Verbose "[$functionName] Saving access token to cache file: $cacheTokenFile"
        if (-not (Test-Path -Path $cacheFolder))
        {
            Write-Verbose "[$functionName] Creating cache folder: $cacheFolder"
            New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
        }
        $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
        Write-Verbose "[$functionName] Access token saved to $cacheTokenFile"
    }
}

function Save-RefreshTokenToConfig()
{
    param($refreshToken, $configFilePath)
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] [Save-RefreshTokenToConfig] Called with configFilePath=$configFilePath, refreshToken provided=$($null -ne $refreshToken)"
    if (-not $refreshToken)
    {
        Write-Verbose "[$functionName] No refresh token to save"
        return
    }

    $DeligatedCredentials = @{}
    try
    {
        Write-Verbose "[$functionName] Saving refresh token to config file: $configFilePath"
        # Read the current config
        $config = Get-Content -Raw -Path $configFilePath | ConvertFrom-Json
        if (isEncrypted -data $config)
        {
            Write-Verbose "[$functionName] Config file is encrypted. Decrypting."
            $decryptedConfig = DecryptObject -encryptedObject $config
            if ($decryptedConfig.deligatedCredentials)
            {
                Write-Verbose "[$functionName] Updating existing deligatedCredentials property"
                $decryptedConfig.deligatedCredentials.refresh_token = $refreshToken.refresh_token
                if ($refreshToken.scope)
                {
                    Write-Verbose "[$functionName] Updating existing scope in deligatedCredentials"
                    $formattedScopes = FormatScopes -scopes $refreshToken.scope -AsIs -Reverse
                    $decryptedConfig.deligatedCredentials.scope = $formattedScopes 
                }
            }
            else
            {
                Write-Verbose "[$functionName] Creating new deligatedCredentials property"
                $decryptedConfig | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $DeligatedCredentials
                $decryptedConfig.deligatedCredentials.refresh_token = $refreshToken.refresh_token
                if ($refreshToken.scope)
                {
                    Write-Verbose "[$functionName] Adding scope to new deligatedCredentials"
                    $formattedScopes = FormatScopes -scopes $refreshToken.scope -AsIs -Reverse
                    $decryptedConfig.deligatedCredentials.scope = $formattedScopes
                }
            }
            # Re-encrypt the config
            Write-Verbose "[$functionName] Re-encrypting config with refresh token"
            $Config = EncryptObject -DecryptedObject $decryptedConfig 
        }
        else
        {
            Write-Verbose "[$functionName] Config is not encrypted, updating directly"
            if (-not $config.deligatedCredentials)
            {
                Write-Verbose "[$functionName] Creating new deligatedCredentials property"
                $config | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $emptyDeligatedCredentials
            }
        }
        # Save the updated config
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -Force
        Write-Verbose "[$functionName] Refresh token saved to config file"
    }
    catch
    {
        Write-Error "Failed to save refresh token to config: $_"
    }
}

function Format-TokenOutput()
{
    param($token, $secureString)
    $functionName = $MyInvocation.MyCommand.Name
    if ($secureString)
    {
        Write-Verbose "[$functionName] Converting access token to secure string"
        $secureAccessToken = ConvertTo-SecureString -String $token -AsPlainText -Force
        Write-Verbose "[$functionName] Returning secure token"
        return $secureAccessToken
    }
    else
    {
        Write-Verbose "[$functionName] Returning plain text access token"
        return $token
    }
}

function Test-RefreshTokenValidity()
{
    param(
        $refreshToken,
        $clientId,
        $clientSecret,
        $tenantId,
        $scopes,
        $domain,
        $AuthType
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Testing refresh token validity..."
    try
    {
        # Ensure scopes are properly formatted for the token refresh
        $scopesFormatted = $scopes
        if ($scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
        {
            $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
            $formattedScopesArray = @()
            foreach ($scope in $scopesArray)
            {
                if ($scope -eq "offline_access")
                {
                    $formattedScopesArray += $scope
                }
                else
                {
                    $formattedScopesArray += "https://graph.microsoft.com/$scope"
                }
            }
            $scopesFormatted = $formattedScopesArray -join ' '
        }
        $refreshTokenRequestBody = @{
            client_id     = $clientId
            refresh_token = $refreshToken
            grant_type    = 'refresh_token'
            scope         = $scopesFormatted
        }
        if ($AuthType -eq 'PublicAuthFlow')
        {
            $refreshTokenRequestBody.Add('client_secret', $clientSecret)
        }
        $refreshTokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        Write-Verbose "[$functionName] Attempting to validate refresh token by getting a new access token..."
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $refreshTokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $refreshTokenRequestBody
        Write-Verbose "[$functionName] Refresh token is valid. Successfully obtained a new access token."
        return $true, $tokenResponse
    }
    catch
    {
        Write-Verbose "[$functionName] Refresh token validation failed: $_"
        Write-Verbose "[$functionName] Refresh token appears to be invalid or expired."
        return $false, $null
    }
}

function Get-RefreshToken()
{
    param(
        $accessTokenObject,
        $clientId,
        $clientSecret,
        $tenantId,
        $scopes,
        $domain,
        $cacheType,
        $cacheTokenFile,
        $cacheFolder,
        $configFilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Host "Using refresh token to get a new access token..."
    try
    {
        # First test if the refresh token is valid
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $accessTokenObject.refresh_token -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
        if (-not $isValid)
        {
            Write-Host "Refresh token is invalid or expired."
            return $null
        }
        Write-Host "Successfully refreshed access token."
        $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $tokenResponse.refresh_token
        # Cache the access token based on cache type
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        # Only save the refresh token if it's different from the one we already have
        Write-Verbose "[$functionName] Checking whether to save the refresh token..."
        if ($tokenResponse.refresh_token -and $tokenResponse.refresh_token -ne $accessTokenObject.refresh_token)
        {
            Write-Verbose "[$functionName] Saving new refresh token as it differs from the existing one."
            Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
        }
        else
        {
            Write-Verbose "[$functionName] No need to save refresh token as it hasn't changed."
        }
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
    }
    catch
    {
        Write-Host "Failed to use refresh token: $_. Will request new authorization."
        Write-Host "Refresh token might be expired or revoked, proceeding with new authorization."
        return $null
    }
}

function Get-TokenFromCache()
{
    param(
        $cacheType,
        $domain,
        $renewalLeadTime,
        $clientId,
        $clientSecret,
        $tenantId,
        $scopes,
        $deligated,
        $cacheFolder,
        $cacheTokenFile,
        $secureString,
        $configFilePath,
        $configRefreshToken
    )
    $functionName = $MyInvocation.MyCommand.Name
    $accessTokenObject = $null
    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
        
    # Get token from memory cache
    if ($cacheType -eq 'memory')
    {
        Write-Verbose "[$functionName] Using memory cache for access token."
        if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
        {
            Write-Verbose "[$functionName] Initializing memory cache."
            New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
        }
            
        if ($Global:MemoryCache.ContainsKey('accessToken'))
        {
            $accessTokenObject = $Global:MemoryCache['accessToken']
                
            if ($accessTokenObject.domain -eq $domain)
            {
                Write-Verbose "[$functionName] Domain matches. Using cached token."
                Write-Verbose "[$functionName] Token for $domain found in memory cache."
                    
                # Check if token is still valid
                if ($accessTokenObject.access_token -and 
                    $accessTokenObject.AbsoluteExpiryTime -and 
                    $accessTokenObject.AbsoluteExpiryTime -gt $timeBuffer)
                {
                    Write-Host "Access token is valid until $($accessTokenObject.AbsoluteExpiryTime)."
                    Write-Host "Using cached access token for $($accessTokenObject.domain) from memory."
                    return $accessTokenObject.access_token
                }
                else
                {
                    Write-Host "Access token in memory is expired or invalid."
                    # Try to use refresh token if available
                    if ($Deligated)
                    {
                        # First check if the object has a refresh token
                        if ($accessTokenObject.refresh_token)
                        {
                            return Get-RefreshToken -accessTokenObject $accessTokenObject -clientId $clientId -clientSecret $clientSecret `
                                -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                        }
                        # If not, check if we have one in the config
                        elseif ($configRefreshToken)
                        {
                            $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                            return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                                -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                        }
                    }
                }
            }
            else
            {
                Write-Host "Domain does not match. Requesting a new token from $domain."
            }
        }
        else
        {
            Write-Verbose "[$functionName] No token found in memory cache."
            # Check if we have a refresh token in config even if there's no memory cache
            if ($Deligated -and $configRefreshToken)
            {
                Write-Verbose "[$functionName] No access token in memory, but found refresh token in config."
                $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                    -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                    -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
            }
        }
    }
    # Get token from file cache
    elseif ($cacheType -eq 'file')
    {
        if (Test-Path -Path $cacheTokenFile)
        {
            Write-Verbose "[$functionName] Cache file exists: $cacheTokenFile"
            try
            {
                $accessTokenObject = Get-Content -Path $cacheTokenFile -Raw -Force | ConvertFrom-Json
                    
                if ($accessTokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Domain matches. Using cached token."
                    $accessToken = $accessTokenObject.access_token
                        
                    # Handle time formats
                    if ($accessTokenObject.AbsoluteExpiryTime -is [string])
                    {
                        $absoluteExpiryTime = [datetime]::Parse($accessTokenObject.absoluteExpiryTime).ToLocalTime()
                        if ($absoluteExpiryTime -lt $accessTokenObject.AbsoluteExpiryTime)
                        {
                            Write-Verbose "[$functionName] Resolving time differences between UTC and local time."
                            $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                        }
                    }
                    else
                    {
                        $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                    }
                        
                    Write-Verbose "[$functionName] Absolute Expiry Time: $absoluteExpiryTime"
                    Write-Verbose "[$functionName] We will renew the token $($renewalLeadTime) minutes before it expires."
                        
                    # Check if token is still valid
                    if ($accessToken -and $absoluteExpiryTime -gt $timeBuffer)
                    {
                        Write-Host "Access token for $($accessTokenObject.domain) is valid until $absoluteExpiryTime."
                        Write-Host "Using cached access token from disk."
                        return $accessToken
                    }
                    else
                    {
                        Write-Host "Access token is expired or invalid."
                        # Try to use refresh token if available
                        if ($Deligated)
                        {
                            # First check if the cache file has a refresh token
                            if ($accessTokenObject.refresh_token)
                            {
                                return Get-RefreshToken -accessTokenObject $accessTokenObject -clientId $clientId -clientSecret $clientSecret `
                                    -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                    -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                            }
                            # If not, check if we have one in the config
                            elseif ($configRefreshToken)
                            {
                                $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                                return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                                    -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                    -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                            }
                            else
                            {
                                Write-Host "Requesting a new token for $domain."
                            }
                        }
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Domain $domain does not match cached token domain $($accessTokenObject.domain)."
                }
            }
            catch
            {
                Write-Host "Failed to read cache file: $_"
                Write-Host "Cache file may be corrupted or invalid. Requesting a new token."
            }
        }
        else
        {
            Write-Host "No cache file found."
            # Check if we have a refresh token in config even if there's no cache file
            if ($Deligated -and $configRefreshToken)
            {
                Write-Verbose "[$functionName] No access token in file cache, but found refresh token in config."
                $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                    -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                    -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
            }
        }
    }
    else
    {
        Write-Error "Invalid cache type. Use 'file' or 'memory'."
        return $null
    }
        
    return $null
}

function LaunchBrowser()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$url,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Chrome", "Edge", "Firefox")]
        [string]$browser
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #print log of incoming parameters.
    Write-Verbose "[$functionName] Launching browser with URL: $url"
    Write-Verbose "[$functionName] Browser preference: $browser"
    Write-Verbose "[$functionName] Launching browser with URL: $url"
    Write-Verbose "[$functionName] Browser preference: $browser"
    switch ($Browser)
    {
        'Edge'
        {
            Write-Verbose "[$functionName] Opening Edge browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
                    ArgumentList = "--inprivate", $authUrl
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
                    ArgumentList = $authUrl
                }
            }
        }
        'Chrome'
        {
            Write-Verbose "[$functionName] Opening Chrome browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                    ArgumentList = "--incognito", $authUrl
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                    ArgumentList = $authUrl
                }
            }
        }
        'Firefox'
        {
            Write-Verbose "[$functionName] Opening Firefox browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    ArgumentList = "-private-window", $authUrl
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    ArgumentList = $authUrl
                }
            }
        }
        default
        {
            Write-Verbose "[$functionName] Opening default browser for authentication"
            $urlParams = @{
                FilePath     = "start"
                ArgumentList = $authUrl
            }
        }
    }
    Write-Verbose "[$functionName] Launching $browser with URL: $url"
    try
    {
        # Start the browser with the specified URL
        Start-Process @urlParams 
        Write-Verbose "[$functionName] Browser launched successfully."
    }
    catch
    {
        Write-Error "Failed to launch browser: $_"
        return $false
    }
    return $true
}

function Get-DelegatedToken()
{
    param($tenantId, $clientId, $clientSecret, $scopes, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $configFilePath, $configRefreshToken, $AuthType, $NoSaveRefreshToken, $settings = $settings)
    $functionName = $MyInvocation.MyCommand.Name
    # First check if we have a valid refresh token in config
    if ($configRefreshToken)
    {
        Write-Verbose "[$functionName] Found refresh token in config. Testing its validity before requesting new authorization..."
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -AuthType $AuthType
        if ($isValid)
        {
            Write-Host "Existing refresh token is valid. Using it without requesting a new authorization."
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $configRefreshToken
            # Cache the access token
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            # We don't need to save the refresh token again since it's the same one
            Write-Verbose "[$functionName] Using existing refresh token that is still valid."
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
        else
        {
            Write-Verbose "[$functionName] Existing refresh token is invalid. Will proceed with new authorization."
        }
    }
    # Generate a random state string
    Write-Verbose "[$functionName] Generating random state string."
    $state = [System.Guid]::NewGuid().ToString()
    $scopesFormatted = FormatScopes -scopes $scopes
    $encodedScopes = [uri]::EscapeDataString($scopesFormatted)
    
    $automaticFlowSuccess = $false
    switch ($AuthType)
    {
        PublicAuthFlow
        {
            Write-Verbose "[$functionName] Using device auth flow."
            $deviceCodeRequestUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"
            Write-Verbose "[$functionName] Device code request URL: $deviceCodeRequestUrl"
            $deviceCodeRequestBody = @{
                client_id = $clientId
                scope     = $scopesFormatted
            }
            Write-Verbose "[$functionName] Requesting device code with body: $($deviceCodeRequestBody | ConvertTo-Json -Depth 3)"
            try
            {
                $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri $deviceCodeRequestUrl -Body $deviceCodeRequestBody
                Write-Verbose "[$functionName] Device code response: $($deviceCodeResponse | ConvertTo-Json -Depth 3)"
            }
            catch
            {
                Write-Error "Error requesting device code: $($_.Exception.Message)"
                Write-Error "Response: $($_.Exception.Response.GetResponseStream() | ForEach-Object { New-Object System.IO.StreamReader($_) } | ForEach-Object { $_.ReadToEnd() })"
                return $null
            }
            Write-Host ""
            Write-Host $deviceCodeResponse.message
            Write-Host "Waiting for authentication..."
            Write-Host ""
            # --- Poll for Access Token ---
            Write-Verbose "[$functionName] Polling for access token using device code."
            $tokenRequestUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            $tokenRequestBody = @{
                grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                client_id   = $clientId
                device_code = $deviceCodeResponse.device_code
            }
            $accessToken = $null
            $timeoutSeconds = $deviceCodeResponse.expires_in # Typically 15 minutes
            Write-Verbose "[$functionName] Token request URL: $tokenRequestUrl"
            Write-Verbose "[$functionName] Token request body: $($tokenRequestBody | ConvertTo-Json -Depth 3)"
            Write-Verbose "Timeout for polling: $timeoutSeconds seconds"
            $intervalSeconds = $deviceCodeResponse.interval # Typically 5 seconds
            Write-Verbose "Polling interval: $intervalSeconds seconds"
            $startTime = Get-Date
            Write-Verbose "[$functionName] Start time for polling: $startTime"
            while ((Get-Date -UFormat %s) -lt ($startTime.AddSeconds($timeoutSeconds) | Get-Date -UFormat %s))
            {
                Write-Verbose "[$functionName] Polling for access token..."
                Start-Sleep -Seconds $intervalSeconds 
                try
                {
                    $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenRequestUrl -Body $tokenRequestBody -ErrorAction SilentlyContinue
                    Write-Verbose "[$functionName] Polling attempt successful."
                    Write-Verbose "[$functionName] Token response: $($tokenResponse | ConvertTo-Json -Depth 3)"
                    if ($tokenResponse.access_token)
                    {
                        $accessToken = $tokenResponse.access_token
                        Write-Host "Authentication successful. Access token acquired."
                        $automaticFlowSuccess = $true
                        break
                    }
                    elseif ($tokenResponse.error -ne "authorization_pending")
                    {
                        Write-Error "Error polling for token: $($tokenResponse.error_description)"
                        return $null
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Authorization still pending, continuing to poll..."
                    }
                }
                catch
                {
                    # Check if this is the expected "authorization_pending" error (400 Bad Request)
                    $isAuthPending = $false
                    
                    # Check the HTTP status code first
                    if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 400)
                    {
                        Write-Verbose "[$functionName] Received 400 Bad Request during polling - checking if authorization is pending..."
                        
                        # Multiple ways to detect authorization_pending:
                        # 1. Check the exception message for common patterns
                        $exceptionMessage = $_.Exception.Message
                        if ($exceptionMessage -like "*authorization_pending*" -or 
                            $exceptionMessage -like "*Bad Request*" -or
                            $exceptionMessage -like "*400*")
                        {
                            $isAuthPending = $true
                            Write-Verbose "[$functionName] Detected authorization_pending from exception message pattern"
                        }
                        
                        # 2. Try to parse the response body if available
                        if (-not $isAuthPending)
                        {
                            try
                            {
                                $errorResponse = $_.Exception.Response.GetResponseStream()
                                if ($errorResponse -and $errorResponse.CanRead)
                                {
                                    $streamReader = New-Object System.IO.StreamReader($errorResponse)
                                    $errorMessage = $streamReader.ReadToEnd()
                                    $streamReader.Close()
                                    
                                    if ($errorMessage)
                                    {
                                        $errorJson = $errorMessage | ConvertFrom-Json
                                        if ($errorJson.error -eq "authorization_pending")
                                        {
                                            $isAuthPending = $true
                                            Write-Verbose "[$functionName] Confirmed authorization_pending from response body"
                                        }
                                    }
                                }
                            }
                            catch
                            {
                                Write-Verbose "[$functionName] Could not parse error response, but assuming authorization_pending for 400 status"
                                # For 400 errors during OAuth device flow polling, assume it's authorization_pending
                                $isAuthPending = $true
                            }
                        }
                        
                        if ($isAuthPending)
                        {
                            Write-Verbose "[$functionName] Authorization still pending (from catch block), continuing to poll..."
                        }
                    }
                    
                    # Only show warning for unexpected errors, not for authorization_pending
                    if (-not $isAuthPending)
                    {
                        Write-Warning "Polling attempt failed: $($_.Exception.Message)"
                        Write-Verbose "[$functionName] Unexpected error during polling: $($_.Exception | Out-String)"
                    }
                }
                Write-Host -NoNewline "."
            }
            if (-not $accessToken)
            {
                Write-Error "Authentication timed out or failed."
                return $null
            }
        }
        'interactive'
        {
            Write-Verbose "[$functionName] Using interactive authentication flow."
            $redirectUri = "http://localhost:8080/"
            Write-Verbose "[$functionName] Redirect URI: $redirectUri"
            $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
            Write-Verbose "[$functionName] Encoded Redirect URI: $encodedRedirectUri"
            Write-Verbose "[$functionName] Attempting automatic HTTP listener flow"
            try
            {
                Write-Verbose "[$functionName] Starting HTTP listener at $redirectUri"
                $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=$encodedScopes&state=$state"
                Write-Verbose "[$functionName] Authorization URL: $authUrl"
                Write-Host "Opening browser for user authentication and consent..."
                if (-not (LaunchBrowser -url $authUrl -browser $settings.preferredBrowser))
                {
                    Write-Error "Failed to launch browser. Please open the URL manually: $authUrl"
                    return $null
                }
                $listenerResult = Start-HttpListener -redirectUri $redirectUri
                if ($listenerResult.Success)
                {
                    Write-Verbose "[$functionName] HTTP listener successfully captured the authorization code"
                    $code = $listenerResult.Code
                    $automaticFlowSuccess = $true
                }
                else
                {
                    Write-Warning "HTTP listener failed to capture the authorization code: $($listenerResult.ErrorMessage)"
                    Write-Verbose "[$functionName] Will fall back to manual code input"
                    $automaticFlowSuccess = $false
                }
            }
            catch
            {
                Write-Warning "Error in automatic HTTP listener flow: $_"
                Write-Verbose "[$functionName] Will fall back to manual code input"
                $automaticFlowSuccess = $false
            }
        }
        'Private'
        {
            Write-Verbose "[$functionName] Using non-interactive mode (manual code input)"
            $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
            Write-Verbose "[$functionName] Redirect URI: $redirectUri"
            $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
            Write-Verbose "[$functionName] Encoded Redirect URI: $encodedRedirectUri"
        }
        default
        {
            Write-Error "Invalid AuthType specified. Use 'interactive' or 'device'."
            return $null
        }
    }
    
    # Fall back to manual code input if automatic flow failed
    if (-not $automaticFlowSuccess)
    {
        # Step 1: Open the authorization URL
        $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=$encodedScopes&state=$state"
        Write-Verbose "[$functionName] Authorization URL: $authUrl"
        Write-Host "Opening browser for user authentication and consent..."
        if (-not (LaunchBrowser -url $authUrl -browser $settings.preferredBrowser))
        {
            Write-Error "Failed to launch browser. Please open the URL manually: $authUrl"
            return $null
        }        
        Write-Host "After granting consent, copy the 'code' parameter from the redirected URL and paste it below."
        $code = Read-Host "Enter the authorization code"
        Write-Verbose "[$functionName] Received authorization code input from user"
        #The $code string above contains the intire URL. Extract the code from the URL.
        if ($code -match '.*code=([^&]+).*')
        {
            $code = $Matches[1]
            Write-Verbose "[$functionName] Extracted code from URL: $($code.Substring(0, [Math]::Min(10, $code.Length)))..."
        }
        else
        {
            Write-Warning "Could not extract code parameter from the provided URL"
            Write-Verbose "[$functionName] Input received: $($code.Substring(0, [Math]::Min(30, $code.Length)))..."
        }
    }           
    # Regardless of how we got the code, exchange it for a token
    if ($code -and $AuthType -ne 'PublicAuthFlow')
    {
        Write-Verbose "[$functionName] Exchanging authorization code for access token"
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $tokenRequestBody = @{
            client_id     = $clientId
            client_secret = $clientSecret
            code          = $code
            redirect_uri  = $redirectUri
            grant_type    = "authorization_code"
            scope         = $scopesFormatted
        }
        Write-Verbose "[$functionName] Token request parameters:"
        Write-Verbose "[$functionName]   Endpoint: $tokenEndpoint"
        Write-Verbose "[$functionName]   Client ID: $clientId"
        Write-Verbose "[$functionName]   Redirect URI: $redirectUri"
        Write-Verbose "[$functionName]   Grant Type: authorization_code"
        Write-Verbose "[$functionName]   Scopes: $scopesFormatted"
        try
        {
            Write-Verbose "[$functionName] Sending token request to $tokenEndpoint"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $tokenRequestBody -ErrorVariable tokenError
            Write-Verbose "[$functionName] Access token received successfully"
        }            
        catch
        {
            Write-Error "Failed to get delegated access token: $_"
            if ($tokenError)
            {
                Write-Verbose "[$functionName] Error details: $($tokenError | Out-String)"
                if ($_.ErrorDetails.Message)
                {
                    Write-Verbose "[$functionName] Error message details: $($_.ErrorDetails.Message)"
                    try
                    {
                        $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                        Write-Verbose "[$functionName] Error JSON: $($errorJson | ConvertTo-Json -Depth 3)"
                        Write-Verbose "[$functionName] Error code: $($errorJson.error)"
                        Write-Verbose "[$functionName] Error description: $($errorJson.error_description)"
                    }
                    catch
                    {
                        Write-Verbose "[$functionName] Could not convert error details to JSON: $_"
                    }
                }
            }
            if ($_.Exception.Response)
            {
                Write-Verbose "[$functionName] Status code: $($_.Exception.Response.StatusCode)"
                # Try to get more information from the response
                try
                {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    Write-Verbose "[$functionName] Response body: $responseBody"
                    try
                    {
                        $responseJson = $responseBody | ConvertFrom-Json
                        Write-Verbose "[$functionName] Error code: $($responseJson.error)"
                        Write-Verbose "[$functionName] Error description: $($responseJson.error_description)"
                    }
                    catch
                    {
                        Write-Verbose "[$functionName] Could not parse response body as JSON"
                    }
                }
                catch
                {
                    Write-Verbose "[$functionName] Could not read response stream: $_"
                }
            }
            return $null
        }
    }
    
    # Log the token response properties (without exposing the actual token)
    if ($tokenResponse)
    {
        Write-Verbose "[$functionName] Token response contains the following properties:"
        foreach ($prop in $tokenResponse.PSObject.Properties.Name)
        {
            if ($prop -eq "access_token" -or $prop -eq "refresh_token" -or $prop -eq "id_token")
            {
                {
                    $tokenLength = $tokenResponse.$prop.Length
                    Write-Verbose "[$functionName]   $($prop): [Token of length $tokenLength]"
                }
                else
                {
                    Write-Verbose "[$functionName]   $($prop): $($tokenResponse.$prop)"
                }
            }
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain
            # Cache the access token based on cache type
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            # Save the refresh token to config file regardless of cache type
            if ($tokenResponse.refresh_token)
            {
                if (-not $NoSaveRefreshToken)
                {
                    Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
                }
            }
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
    }
    else 
    {
        Write-Verbose "[$functionName] Token response is null. Authorization code exchange failed."
        return $null
    }
}

function Get-ClientCredentialsToken()
{
    param($tenantId, $clientId, $clientSecret, $domain, $cacheType, $cacheTokenFile, $cacheFolder)
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Using non-delegated access..."
    Write-Verbose "[$functionName] Requesting new access token with client credentials flow"
    $body = @{
        client_id     = $clientId
        scope         = 'https://graph.microsoft.com/.default'
        client_secret = $clientSecret
        grant_type    = 'client_credentials'
    }
    Write-Verbose "[$functionName] Token request body: client_id=$clientId, scope=https://graph.microsoft.com/.default, grant_type=client_credentials"
    try
    {
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        Write-Verbose "[$functionName] Sending request to token endpoint: $tokenEndpoint"
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorVariable restError
            
        Write-Verbose "[$functionName] Access token received successfully"
        Write-Verbose "[$functionName] Token expires in: $($tokenResponse.expires_in) seconds"
            
        $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain
            
        # Cache the token
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
    }
    catch
    {
        Write-Error "Failed to get access token: $_"
            
        if ($restError)
        {
            Write-Verbose "[$functionName] Error details: $($restError | Out-String)"
        }
            
        if ($_.Exception.Response)
        {
            Write-Verbose "[$functionName] Status code: $($_.Exception.Response.StatusCode)"
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorMessage = $streamReader.ReadToEnd()
            $streamReader.Close()
            Write-Error "Server Response: $errorMessage"
            
            try
            {
                $errorJson = $errorMessage | ConvertFrom-Json
                Write-Verbose "[$functionName] Error code: $($errorJson.error)"
                Write-Verbose "[$functionName] Error description: $($errorJson.error_description)"
            }
            catch
            {
                Write-Verbose "[$functionName] Could not parse error message as JSON: $_"
            }
        }
        return $null
    }
}

function BuildAuthSplatTable()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $auth
    )
    
    # Dynamic splatting approach - iterate over all auth properties
    # Create clean splatting hashtable starting with required parameter
    $getTokenParams = @{
        configFile = $configFile
    }
    
    # Define valid parameters for GetGraphAccessToken function
    $validParams = @('renewalLeadTime', 'SecureString', 'NoSaveRefreshToken', 'Deligated', 'Scope', 'AuthType', 'ForceNewToken', 'CacheType', 'configFile')
    # Define parameters that are only valid when Deligated is true (parameterSetName = 'Deligated')
    $deligatedOnlyParams = @('NoSaveRefreshToken', 'Deligated', 'Scope', 'AuthType')    # Iterate over all properties in the auth object
    foreach ($property in $auth.PSObject.Properties)
    {
        $paramName = $property.Name
        $paramValue = $property.Value
        # Skip if not a valid parameter for the function
        if ($paramName -notin $validParams)
        {
            Write-Verbose "Skipping parameter '$paramName' as it's not valid for GetGraphAccessToken"
            continue
        }
        # Skip if value is null, empty, or false for switch parameters
        if ($null -eq $paramValue -or $paramValue -eq '' -or $paramValue -eq $false)
        {
            Write-Verbose "Skipping parameter '$paramName' due to null/empty/false value"
            continue
        }
        # Check if this is a delegated-only parameter
        if ($paramName -in $deligatedOnlyParams)
        {
            # Only add if Deligated is true in the auth object
            if ($auth.PSObject.Properties.Name -contains 'Deligated' -and $auth.Deligated)
            {
                Write-Verbose "Adding delegated parameter '$paramName' with value: $paramValue"
                #Check if the parameter is an array, and if so convert it to a space seperated string
                if ($paramValue -is [array])
                {
                    $paramValue = $paramValue -join ' '
                    Write-Verbose "Converted array parameter '$paramName' to space-separated string: $paramValue"
                }
                $getTokenParams[$paramName] = $paramValue
            }
            else
            {
                Write-Verbose "Skipping delegated parameter '$paramName' because Deligated is not true"
            }
        }
        else
        {
            # Add general parameters (not restricted to delegated mode)
            Write-Verbose "Adding parameter '$paramName' with value: $paramValue"
            $getTokenParams[$paramName] = $paramValue
        }
    }

    # Log the final splatting parameters for verification
    Write-Verbose "Final splatting parameters:"
    foreach ($param in $getTokenParams.GetEnumerator())
    {
        if ($param.Key -eq 'configFile')
        {
            Write-Verbose "  $($param.Key): $($param.Value)"
        }
        elseif ($param.Value -is [bool])
        {
            Write-Verbose "  $($param.Key): $($param.Value)"
        }
        else
        {
            Write-Verbose "  $($param.Key): '$($param.Value)'"
        }
    }
    # Return the splatting hashtable
    return $getTokenParams
}

function ProcessFilterCondition()
{
    [CmdletBinding()]
    param(
        [string]$condition
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing filter condition: $condition"
    # Check if this is a function-based filter (contains, startswith, endswith)
    Write-Verbose "[$functionName] Checking for function-based filter..."
    if ($condition -match '(startswith|contains|endswith)\s*\(([^,]+),\s*([^)]+)\)')
    {
        Write-Verbose "[$functionName] Found function-based filter: $($Matches[1])"
        $filterOperator = $Matches[1]
        Write-Verbose "[$functionName] Filter Operator: $filterOperator"
        $filterKey = $Matches[2].Trim()
        Write-Verbose "[$functionName] Filter Key: $filterKey"
        $filterValue = $Matches[3].Trim()
        Write-Verbose "[$functionName] Filter Value: $filterValue"
        # Remove quotes if present in the value
        Write-Verbose "[$functionName] Removing quotes from filter value..."
        $filterValue = $filterValue -replace "^'|'$", ""
        Write-Verbose "[$functionName] Filter Value after removing double quotes: $filterValue"
        $filterValue = $filterValue -replace '^"|"$', ""
        Write-Verbose "[$functionName] Filter Value after removing single quotes: $filterValue"
        Write-Verbose "[$functionName] Filter Key after removing quotes: $FilterKey"
        Write-Verbose "[$functionName] Filter Value: $FilterValue"
        Write-Verbose "[$functionName] Filter Operator: $FilterOperator"
        $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
        Write-Verbose "[$functionName] Encoded Filter Value: $encodedFilterValue"
        # Rebuild the function call with encoded value
        $returnFilter = "$filterOperator($filterKey,'$encodedFilterValue')"
        Write-Verbose "[$functionName] Returning filter: $returnFilter"
        return $returnFilter
    }
    # Check for standard comparison operators
    elseif ($condition -match '([^\s]+)\s+(eq|ne|gt|lt|ge|le)\s+(.+)')
    {
        Write-Verbose "[$functionName] Not a function based filter. Checking for standard comparison operators..."
        $filterKey = $Matches[1].Trim()
        $filterOperator = $Matches[2].Trim()
        $filterValue = $Matches[3].Trim()
        Write-Verbose "[$functionName] Filter Key: $FilterKey"
        Write-Verbose "[$functionName] Filter Operator: $FilterOperator"
        Write-Verbose "[$functionName] Filter Value: $FilterValue"
        # Special handling for null and empty string
        Write-Verbose "[$functionName] Checking for null or empty string..."
        if ($filterValue -eq "null" -or $filterValue -eq "''" -or $filterValue -eq '""')
        {
            Write-Verbose "[$functionName] Filter value is null or empty string."
            Write-Verbose "[$functionName] Returning filter without encoding: $filterKey $filterOperator $filterValue"
            # Don't encode null or empty string values
            return "$filterKey $filterOperator $filterValue"
        }
        else
        {
            # Remove quotes if present
            Write-Verbose "[$functionName] Checking for quotes and removing from value if present..."
            Write-Verbose "[$functionName] Value before processing: $filterValue"
            $filterValue = $filterValue -replace "^'|'$", ""
            Write-Verbose "[$functionName] Value after removing double quotes: $filterValue"
            $filterValue = $filterValue -replace '^"|"$', ""
            Write-Verbose "[$functionName] Value after removing single quotes: $filterValue"
            Write-Verbose "[$functionName] Filter Key: $FilterKey"
            Write-Verbose "[$functionName] Filter Value: $FilterValue"
            $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
            Write-Verbose "[$functionName] Encoded Filter Value: $encodedFilterValue"
            # Add quotes back for the encoded value
            $returnFilter = "$filterKey $filterOperator '$encodedFilterValue'"
            Write-Verbose "[$functionName] Returning filter: $returnFilter"
            return $returnFilter
        }
    }
    else
    {
        Write-Verbose "[$functionName] Unrecognized filter condition format: $condition"
        return $condition
    }
}

function GetGraphAccessToken()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$configFile,
        [int]$renewalLeadTime = 5,
        [switch]$SecureString,
        [parameter(parameterSetName = 'Deligated')]
        [switch]$NoSaveRefreshToken,
        [parameter(parameterSetName = 'Deligated')]
        [switch]$Deligated,
        [parameter(parameterSetName = 'Deligated')]
        [string]$Scope,
        [parameter(parameterSetName = 'Deligated')]
        [ValidateSet('PublicAuthFlow', 'Interactive', 'Private')]
        [string]$AuthType = 'Private',
        [switch]$ForceNewToken,
        [ValidateSet('file', 'memory')]
        [string]$CacheType = 'Memory'
    )
    
    #region Process config files
    $functionName = $MyInvocation.MyCommand.Name
    # Read and process configuration file
    if (-not $configFile)
    {
        Write-Error "Config file not found. Please provide a valid config file."
        return $null
    }
    Write-Verbose "[$functionName] Reading config file $configFile"
    try
    {
        $config = Get-Content -Raw -Path $configFile -Force | ConvertFrom-Json
        Write-Verbose "[$functionName] Config file loaded successfully"
    }
    catch
    {
        Write-Error "Failed to read or process config file: $_"
        return $null
    }
    Write-Verbose "[$functionName] Decrypting values from $configFile"
    $configRefreshToken = $null
    if (isEncrypted -data $config)
    {
        Write-Verbose "[$functionName] Config file is encrypted. Decrypting."
        $config = DecryptObject -encryptedObject $config
    }
    else
    {
        Write-Verbose "[$functionName] Config file is not encrypted. Using as is."
    }
    # Extract the refresh token if it exists
    if ($config.deligatedCredentials.refresh_token)
    {
        $configRefreshToken = $config.deligatedCredentials.refresh_token
        Write-Verbose "[$functionName] Found refresh token in encrypted config."
    }
    else
    {
        Write-Verbose "[$functionName] No refresh token found in config."
    }
    if ($config.tenantId)
    {
        $tenantId = $config.tenantId
        Write-Verbose "[$functionName] Tenant ID found in config: $tenantId"
    }
    else
    {
        Write-Error "Tenant ID not found in config file."
        return $null
    }
    if ($config.appId)
    {
        $clientId = $config.appId
        Write-Verbose "[$functionName] Client ID found in config: $clientId"
    }
    else
    {
        Write-Error "Client ID not found in config file."
        return $null
    }
    if ($config.AppSecret)
    {
        $clientSecret = $config.AppSecret
        Write-Verbose "[$functionName] Client Secret found in config."
    }
    else
    {
        Write-Verbose "[$functionName] Client Secret not found in config file."
        Write-Verbose "Checking whether the authtype is public flow which does not require client secret."
        if ($AuthType -ne 'PublicAuthFlow')
        {
            Write-Error "Client Secret is required for the selected authentication type."
            return $null
        }
        Write-Verbose "[$functionName] Public Auth Flow does not require Client Secret."
    }
    #endregion Process config files
    
    #region Log parameters
    Write-Verbose "[$functionName] Received parameters:"
    Write-Verbose "[$functionName] Configuration File: $configFile"
    Write-Verbose "[$functionName] Renewal Lead Time: $renewalLeadTime"
    Write-Verbose "[$functionName] Secure String: $SecureString"
    Write-Verbose "[$functionName] Force New Token: $ForceNewToken"
    Write-Verbose "[$functionName] Use Public Auth Flow: $UsePublicAuthFlow"
    Write-Verbose "[$functionName] Interactive: $Interactive"
    Write-Verbose "[$functionName] Cache Type: $CacheType"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] Deligated: $Deligated"
    Write-Verbose "[$functionName] Scopes: $Scope"
    Write-Verbose "[$functionName] Config has refresh token: $($null -ne $configRefreshToken)"
    #endregion Log parameters
    
    # Set up cache paths
    $cacheFolder = Split-Path $configFile
    $cacheTokenFile = Join-Path $cacheFolder "accessToken.json"
    
    #region Try to get token from cache if not forcing new token
    $accessToken = $null
    if (-not $ForceNewToken)
    {
        $accessToken = Get-TokenFromCache -cacheType $CacheType -domain $domain -renewalLeadTime $renewalLeadTime `
            -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $Scope `
            -deligated $Deligated -cacheFolder $cacheFolder -cacheTokenFile $cacheTokenFile `
            -secureString $SecureString -configFilePath $configFile -configRefreshToken $configRefreshToken
        if ($accessToken)
        {
            return $accessToken
        }
    }
    else
    {
        Write-Host "Force new token requested. Ignoring cache."
    }
    #endregion Try to get token from cache if not forcing new token
    
    #region Authentication flow
    if ($deligated)
    {
        Write-Verbose "[$functionName] Deligated authentication flow selected."
        $params = @{
            tenantId           = $tenantId 
            clientId           = $clientId 
            scopes             = $Scope
            domain             = $domain 
            cacheType          = $CacheType
            AuthType           = $AuthType
            cacheTokenFile     = $cacheTokenFile
            cacheFolder        = $cacheFolder 
            configFilePath     = $configFile
            configRefreshToken = $configRefreshToken
        }
        switch ($AuthType)
        {
            PublicAuthFlow
            {
                Write-Verbose "[$functionName] Using public authentication flow for delegated token."
            }
            Interactive
            {
                Write-Verbose "[$functionName] Using interactive authentication flow for delegated token."
                $params += @{
                    clientSecret = $clientSecret
                }
            }
            Private
            {
                Write-Verbose "[$functionName] Using private authentication flow for delegated token."
                $params += @{
                    clientSecret = $clientSecret
                }
            }
        }
        if ($NoSaveRefreshToken)
        {
            Write-Verbose "[$functionName] No save refresh token option selected. Not saving refresh token."
            $params += @{
                NoSaveRefreshToken = $NoSaveRefreshToken
            }
        }
        return Get-DelegatedToken @params
    }
    else
    {
        if ($tenantId -and $clientId -and $clientSecret)
        {
            return Get-ClientCredentialsToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret `
                -domain $domain -cacheType $CacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        }
        else
        {
            Write-Error "Missing required authentication parameters (tenantId, clientId, or clientSecret)"
            return $null
        }
    }
    #endregion Authentication flow
}

function CallGraphAPI()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$ResourcePath,
        [string]$APIVersion = 'beta',
        [string]$method = 'get',
        [string]$Filter = $null,
        [string]$ExtraParameters = $null,
        [string]$body = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    else
    {
        Write-Host 'Access token not provided. Please provide a valid access token.' -ForegroundColor Red
        return
    }
    Write-Verbose "[$functionName] Resource Path: $ResourcePath"
    Write-Verbose "[$functionName] Method: $method"
    Write-Verbose "[$functionName] Filter: $filter"
    Write-Verbose "[$functionName] Extra Parameters: $ExtraParameters"
    Write-Verbose "[$functionName] Version: $APIVersion"
    Write-Verbose "[$functionName] Consistency Level: $consistencyLevel"
    Write-Verbose "[$functionName] Body: $body"
    Write-Verbose "[$functionName] SecureString: $secureString"
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    $statusCode = $null
    Write-Verbose "[$functionName] Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose "[$functionName] Processing filter string: $Filter"
        Write-Verbose "[$functionName] Splitting filter by logical operators while preserving operators."
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
        Write-Verbose "[$functionName] Found $($logicalOperaterMatches.Count) logical operators."
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
            Write-Verbose "[$functionName] No logical operators found. Processing as a single filter condition."
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Verbose "[$functionName] Processed single filter condition: $processedFilter"
            $encodedFilter = $processedFilter
            Write-Verbose "[$functionName] Encoded filter: $encodedFilter"
        }
        else
        {
            # Process each part of the filter
            Write-Verbose "[$functionName] Logical operators found. Processing filter as multiple conditions."
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
                Write-Verbose "[$functionName] Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))"
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Verbose "[$functionName] Condition to process: $condition"
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Verbose "[$functionName] Logical operators so far: $($logicalOperators -join ', ')"
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
                Write-Verbose "[$functionName] Processing filter condition after the last logical operator."
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Verbose "[$functionName] Rebuilding the filter string with processed parts and logical operators."
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Verbose "[$functionName] Adding logical operator: $($logicalOperators[$i])"
            }
            Write-Verbose "[$functionName] Processed complex filter: $encodedFilter"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Verbose "[$functionName] Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Verbose "[$functionName] No filter provided."
        $encodedUri = $uri
    }
    
    if ($extraParameters)
    {
        Write-Verbose "[$functionName] Extra parameters provided."
        Write-Verbose "[$functionName] Splitting the extra parameters by ampersand to get individual key-value pairs."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Verbose "[$functionName] Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Verbose "[$functionName] Processing key-value pair: $pair"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Verbose "[$functionName] Key: $key"
                Write-Verbose "[$functionName] Value: $value"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Verbose "[$functionName] Formatted Key with $ prefix: $formattedKey"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
            }
        }
        Write-Verbose "[$functionName] Final parameter list:"
        $paramsList | ForEach-Object { Write-Verbose $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Verbose "[$functionName] Final query string: $queryString"
        if ($filter) 
        {
            Write-Verbose "[$functionName] Adding extra parameters to the uri along with the filter."
            $encodedUri = "$encodedUri`&$queryString"
        }
        else
        {
            Write-Verbose "[$functionName] No filter provided. Adding extra parameters to the uri."
            $encodedUri = "$encodedUri`?$queryString"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No extra parameters provided."
    }
    if ($consistencyLevel)
    {
        Write-Verbose "[$functionName] Adding consistency level to the headers."
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Verbose "[$functionName] No consistency level provided."
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion

    #region prepare the call
    # Create parameter hashtable for splatting
    Write-Verbose "[$functionName] Preparing parameters for Invoke-RestMethod call."
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        Write-Verbose "[$functionName] Body parameter provided. Adding to the request."
        $restParams['Body'] = $body
    }
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        Write-Verbose "[$functionName] PowerShell version is $($PSVersionTable.PSVersion.Major ). Adding StatusCodeVariable to the request."
        Write-Verbose "[$functionName] Added StatusCodeVariable."
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Verbose "[$functionName] Making the following call to Microsoft Graph:" 
    Write-Verbose "[$functionName] URI: $encodedUri." 
    Write-Verbose "[$functionName] Method: $method."
    #endregion
    try
    {
        $response = Invoke-RestMethod @restParams
        Write-Verbose "[$functionName] NextLink: $($response.'@odata.nextLink')"
        Write-Verbose "[$functionName] Response count: $($response.value.count)"
        if ($response.'@odata.nextLink')
        {
            Write-Verbose "[$functionName] NextLink found. Fetching additional pages."
            # Initialize an array to hold all items
            $allItems = @()
            $allItems += $response.value
            $nextLink = $response.'@odata.nextLink'
            while ($nextLink)
            {
                $nextGroup = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing
                Write-Verbose "[$functionName] Fetched next page with $($nextGroup.value.Count) items."
                if ($nextGroup.value)
                {
                    Write-Verbose "[$functionName] Adding items from next page to the collection."
                    $allItems += $nextGroup.value
                }
                $nextLink = $nextGroup.'@odata.nextLink'
            }
            # Optionally, reconstruct a response object if needed
            $response.value = $allItems
            Write-Verbose "[$functionName] All items collected. Total count: $($Response.value.Count)"
        }
        else 
        {
            Write-Verbose "[$functionName] No nextLink found. Single page response received."
        }
        Write-Verbose "[$functionName] The call was successful."
        if ($response.count)
        {
            Write-Verbose "[$functionName] Number of objects returned: $($response.count)."
        }
        if ($response.value.Count)
        {
            Write-Verbose "[$functionName] Number of items returned: $($response.value.Count)."
        }
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            Write-Verbose "[$functionName] Status code: $statusCode"
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
        }
    }
    catch
    {
        if ($null -eq $_.Exception.statusCode)
        {
            $statusCode = [regex]::Match($_.Exception.Message, '\d+').Value
            Write-Verbose "[$functionName] Status code: $statusCode"
            $statusCodeMessage = $_.Exception | Out-String
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
            $statusMessage = $statusCodeMessage
        }
        else
        {
            $statusCode = $_.Exception.statuscode.value__
            $statusCodeMessage = $_.Exception.statuscode
            $statusMessage = $_.Exception.Message
        }
        switch ($statusCode)
        {
            400
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Not found. The resource does not exist.' -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message below.' -ForegroundColor Red 
                Write-Host "Error: $statusMessage" -ForegroundColor Red
                Write-Host "The status code is $statusCode"
                Write-Host "$statusCode indicates $statusCodeMessage"
                Write-Host "Status message: $statusMessage"
                Write-Host 'The full error message follows below:'
                Write-Host '----------------------------------------------------------'
                Write-Host "$_"
                if ($_.Exception.Response)
                {
                    $errorResponse = $_.Exception.Response.GetResponseStream()
                    $streamReader = New-Object System.IO.StreamReader($errorResponse)
                    $errorMessage = $streamReader.ReadToEnd()
                    $streamReader.Close()
                    Write-Error "Server Response: $errorMessage"
                }   
            }
        }
        Write-Verbose "[$functionName] Failed to call the Graph API: $_"
        Write-Verbose "[$functionName] The status code is $statusCode"
        Write-Verbose "[$functionName] $statusCode indicates $statusCodeMessage"
        Write-Verbose "[$functionName] Status message: $statusMessage"
        Write-Verbose "[$functionName] The full error message follows below:"
        Write-Verbose "[$functionName] ----------------------------------------------------------"
        Write-Verbose "[$functionName] Error: $($_)"
        Write-Verbose "[$functionName] Exception message: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Exception response: $($_.Exception.Response)"
        if ($_.Exception.Response -and $psversionTable.PSVersion.Major -ge 7)
        {
            {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Verbose "[$functionName] Server Response: $errorMessage"
            }   
        }
        # return $statusCode
        return $null
    }
    Write-Verbose "[$functionName] Response: $($response)"
    Write-Verbose "[$functionName] Response value: $($response.value)"
    return $response
}


function DisplayNumericMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$choices,
        [string]$banner = "Please press the number of your choice and press enter.",
        [string]$Prompt = "Please select an option",
        $errorMessage = "Invalid selection. Please try again.",
        [switch]$RequireEnter
    )
    #region Print a verbose message with received parameters
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Received parameters: $($choices | Out-String)"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] ErrorMessage: $errorMessage"
    Write-Verbose "[$functionName] Banner: $banner"
    #endregion

    # Display the menu options
    Write-Host $banner -ForegroundColor Green
    for ($i = 0; $i -lt $choices.Count; $i++)
    {
        Write-Host "$($i + 1). $($choices[$i])"
    }
    Write-Host "0. Exit"
    
    # Prepare valid key options
    $validKeys = @()
    for ($i = 0; $i -le $choices.Count; $i++)
    {
        $validKeys += $i.ToString()
    }
    Write-Verbose "[$functionName] Valid keys: $($validKeys -join ', ')"
    
    if ($RequireEnter)
    {
        # Original behavior with ReadLine
        Write-Verbose "[$functionName] Using ReadLine for input (requires Enter key)..."
        Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
        $selection = $host.UI.ReadLine()
        Start-Sleep -Milliseconds 600
        # Clean input
        $selection = $selection.Trim()
        Write-Verbose "[$functionName] Raw user input received: '$selection'"
    }
    else
    {
        # New behavior with immediate keystroke capture
        Write-Verbose "[$functionName] Waiting for keystroke input (no Enter required)..."
        Write-Host "$Prompt " -NoNewline -ForegroundColor Yellow
        $keyInfo = $null
        $selection = $null
        # Keep reading keys until a valid one is pressed
        do
        {
            Write-Verbose "[$functionName] Waiting for key press..."
            try
            {
                $keyInfo = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $selection = $keyInfo.Character.ToString()
                $keyCode = [int]$keyInfo.VirtualKeyCode
                Write-Verbose "[$functionName] Key pressed: '$selection' (Character code: $([int]$keyInfo.Character), VK: $keyCode)"
                # Handle special case for numpad keys which might have different character codes
                if ($keyCode -ge 96 -and $keyCode -le 105)
                {
                    # Convert numpad key codes (96-105) to numbers (0-9)
                    $selection = ($keyCode - 96).ToString()
                    Write-Verbose "[$functionName] Converted numpad key to: $selection"
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Error reading key: $_"
                $selection = $null
            }
        } until ($validKeys -contains $selection)
        
        # Echo the selection so user can see what was chosen
        Write-Host $selection
        Write-Verbose "[$functionName] Valid key pressed: '$selection'"
    }
    
    # Validate the selection
    while ($selection -notmatch '^\d+$' -or [int]$selection -lt 0 -or [int]$selection -gt $choices.Count)
    {
        Write-Host $errorMessage -ForegroundColor Red
        Write-Verbose "[$functionName] Invalid selection: '$selection'"
        [console]::beep(1000, 500)
        
        if ($RequireEnter)
        {
            # Re-prompt with ReadLine
            $selection = Read-Host -Prompt $Prompt
            $selection = $selection.Trim()
        }
        else
        {
            # Re-prompt
            $selection = $null
            $keyInfo = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            $selection = [string]$keyInfo.Character.ToString()
        }
    }
    if ($selection -ne "0")
    {
        # Convert to integer explicitly to avoid any type conversion issues
        $index = [int]$selection - 1
        Write-Verbose "[$functionName] Returning choice at index $($index): '$($choices[$index])'"
        # Return the selected choice
        return $choices[$index]
    }
    else
    {
        Write-Verbose "[$functionName] Exiting script with selection: $selection"
        # Return integer 0 for exit option to ensure proper type matching
        return [int]$selection
    }
}

function NewMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $false)]
        [string]$Description
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating new menu with title: $Title and description: $Description"    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

function AddMenuItem()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $false)]
        [hashtable]$Submenu,
        [Parameter(Mandatory = $false)]
        [switch]$ReturnsValue
    )
    $functionName = $MyInvocation.MyCommand.Name
    if ($Action -and $Submenu)
    {
        throw "A menu item cannot have both an Action and a Submenu."
    }
    
    if (-not $Action -and -not $Submenu)
    {
        throw "A menu item must have either an Action or a Submenu."
    }
    
    $item = [ordered] @{
        Name         = $Name
        Action       = $Action
        Submenu      = $Submenu
        ReturnsValue = $ReturnsValue
    }
    Write-Verbose "[$functionName] Adding the following menu item:"
    Write-Verbose "[$functionName] name: $Name"
    if ($null -ne $action -or $action -eq '')
    {
        Write-Verbose "[$functionName] Type: action"
    }
    if ($null -ne $Submenu -or $Submenu -eq '')
    {
        Write-Verbose "[$functionName] Type: submenu"
    }
    Write-Verbose "[$functionName] returns value: $ReturnsValue"
    $Menu.Items += $item
    return $Menu
}

function ShowMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Menu,
        [Parameter(Mandatory = $false)]
        [string]$BackoutText = $backoutText
    )
    #region Validate parameters
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] ===== MENU NAVIGATION DEBUG ====="
    Write-Verbose "[$functionName] Entering ShowMenu for: $($Menu.Title)"
    Write-Verbose "[$functionName] Current Depth: $Depth"
    Write-Verbose "[$functionName] History Count: $(if ($History) {$History.Count} else {'null'})"
    Write-Verbose "[$functionName] MenuHistory Count: $(if ($MenuHistory) {$MenuHistory.Count} else {'null'})"
    if ($History -and $History.Count -gt 0)
    {
        Write-Verbose "[$functionName] History Contents: $($History -join ' > ')"
        $depth = $History.Count
    }
    Write-Verbose "[$functionName] MenuHistory title: $($MenuHistory.Title)"
    Write-Verbose "[$functionName] BackoutText: $BackoutText"
    Write-Verbose "[$functionName] =================================="
    #endregion
    # Clear screen for better readability
    # Clear-Host
    Write-Verbose "[$functionName] Clearing the screen for better readability." 
    
    #display choices    
    $choices = @()
    $menuItems = @()
    Write-Verbose "[$functionName] Initializing choices and menu items."
    # Loop through menu items and add to choices
    foreach ($item in $Menu.Items)
    {
        Write-Verbose "[$functionName] Adding item: $($item.Name)"
        $choices += $item.Name
        Write-Verbose "[$functionName] Adding menu $($item.Name) to menu items."
        $menuItems += $item
    }
    
    # Add navigation options - use ASCII friendly characters instead of Unicode arrows
    if ($Depth -gt 0)
    {
        Write-Verbose "[$functionName] Adding navigation since the depth is $depth."
        $choices += "Back"
    }
    if ($Depth -gt 1)
    {
        Write-Verbose "[$functionName] Adding main menu since the depth is $depth."
        $choices += "Main Menu"
    }
    
    # Create banner text
    Write-Verbose "[$functionName] Creating banner text."
    $banner = $Menu.Title
    if (-not [string]::IsNullOrEmpty($Menu.Description))
    {
        Write-Verbose "[$functionName] Adding description to banner."
        $banner += "`n$($Menu.Description)"
    }
    # Add current path to banner - create proper breadcrumb
    if ($History.Count -gt 0)
    {
        Write-Verbose "[$functionName] Adding current path to banner, since history count is $($History.Count)"
        # Create a clean breadcrumb path without duplicates
        Write-Verbose "[$functionName] Cleaning history to remove duplicates."
        $cleanHistory = @()
        $previousItem = ""
        foreach ($item in $History)
        {
            if ($item -ne $previousItem -and ![string]::IsNullOrWhiteSpace($item))
            {
                Write-Verbose "[$functionName] Adding item to clean history: $item since it is not equal to $previousItem"
                $cleanHistory += $item
                $previousItem = $item
            }
        }
        if ($cleanHistory.Count -gt 0)
        {
            $path = $cleanHistory -join " > "
            # Check if the current menu title is already the last item in the clean history
            # to prevent duplicate entries in the breadcrumb
            if ($cleanHistory[-1] -eq $Menu.Title)
            {
                Write-Verbose "[$functionName] Current menu title already in breadcrumb, not duplicating"
                $banner += "`n[$path]"
            }
            else
            {
                $banner += "`n[$path > $($Menu.Title)]"
            }
        }
        else
        {
            $banner += "`n[$($Menu.Title)]"
        }
    }
    else
    {
        $banner += "`n[$($Menu.Title)]"
    }
    
    # Display menu and get selection
    $selectedOption = DisplayNumericMenu -choices $choices -banner $banner -Prompt "Please select an option" -RequireEnter
    Write-Verbose "[$functionName] option received $selectedOption"
    
    # Handle navigation options - check for both string and integer types
    if ($selectedOption -eq "Back" -or $selectedOption -eq "back")
    {
        Write-Verbose "[$functionName] Going back to previous menu."
        if ($History.Count -gt 0 -and $MenuHistory.Count -gt 0)
        {
            Write-Verbose "[$functionName] Removing last item from history since count is $($History.Count)"
            $History.RemoveAt($History.Count - 1)
            # Get previous menu from MenuHistory
            Write-Verbose "[$functionName] Getting previous menu from MenuHistory since count is $($MenuHistory.Count)"
            if ($MenuHistory.Count -gt 0)
            {
                Write-Verbose "[$functionName] Finding previous menu by removing last item from MenuHistory."
                $previousMenu = $MenuHistory[$MenuHistory.Count - 1]
                Write-Verbose "[$functionName] Previous menu found: $($previousMenu.Title)"
                Write-Verbose "[$functionName] Removing last menu from MenuHistory since count is $($MenuHistory.Count)"
                $MenuHistory.RemoveAt($MenuHistory.Count - 1)
                Write-Verbose "[$functionName] Decreasing depth since we are going back."
                $Depth = ($Depth - 1) 
                Write-Verbose "[]$functionName] Current depth after going back: $Depth"
                Write-Verbose "[$functionName] Returning to previous menu: $($previousMenu.Title)"
                return ShowMenu -Menu $previousMenu 
            }
        }
        else
        {
            Write-Verbose "[$functionName] Cannot go back - no previous menu available"
            return ShowMenu -Menu $Menu 
        }
    }
    elseif ($selectedOption -eq "Main Menu" -or $selectedOption -eq "main menu")
    {
        Write-Verbose "[$functionName] Going to main menu."
        # Go to main menu
        if ($MenuHistory.Count -gt 0)
        {
            $mainMenu = $MenuHistory[0]
            Write-Verbose "[$functionName] Clearing history and menu history since we are going to main menu."
            $History.Clear()
            $MenuHistory.Clear()
            [void]$MenuHistory.Add($mainMenu)
            Write-Verbose "[$functionName] Setting depth to 0 since we are going to main menu."
            $Depth = 0
            return ShowMenu -Menu $mainMenu
        }
        else
        {
            Write-Verbose "[$functionName] Cannot go to main menu - no main menu available"
            return ShowMenu -Menu $Menu 
        }
    }
    elseif ($selectedOption -eq 0 -or $selectedOption -eq "0")
    {
        Write-Verbose "[$functionName] Exiting script."
        return $null
    }
    else
    {
        # Find the selected item - check if it's a navigation option first
        Write-Verbose "[$functionName] Finding selected item. Selected option: '$selectedOption'"
        
        # Try to find the selected option in choices array
        $selectedIndex = -1
        for ($i = 0; $i -lt $choices.Count; $i++)
        {
            if ($choices[$i] -eq $selectedOption)
            {
                $selectedIndex = $i
                break
            }
        }
        
        Write-Verbose "[$functionName] Selected index: $selectedIndex"
        Write-Verbose "[$functionName] Total choices count: $($choices.Count), Menu items count: $($menuItems.Count)"
        $selectedItem = $menuItems[$selectedIndex]
        Write-Verbose "[$functionName] Selected item: $($selectedItem | Out-String)"        # Handle action or submenu        
        if ($selectedItem.Action)
        {
            Write-Verbose "[$functionName] Executing action for selected item."
            Write-Verbose "[$functionName] Updating menu context"
            
            try
            {
                [void]$History.Add($Menu.Title)
                Write-Verbose "[$functionName] Added current menu to history: $($Menu.Title)"
                [void]$MenuHistory.Add($Menu)
            }
            catch
            {
                Write-Verbose "[$functionName] Error adding to history: $_"
                # Fallback for PowerShell 5.1 compatibility
                Write-Verbose "[$functionName] Fallback for PowerShell 5.1 compatibility - using += operator"
                $History += $Menu.Title
                Write-Verbose "[$functionName] Added current menu to history using += operator: $($Menu.Title)"
                $MenuHistory += $Menu
            }
            Write-Verbose "[$functionName] Increasing depth for action execution."
            $Depth = ($Depth + 1)
            Write-Verbose "[$functionName] Current depth after action execution: $Depth"
            
            # Execute the action
            $result = & $selectedItem.Action
            #If you get the special return boolean, return the value directly.
            if ($selectedItem.ReturnsValue)
            {
                Write-Verbose "[$functionName] Action returned a value: $result"
                # Special handling: if the result is a navigation option that somehow got returned,
                # don't treat it as a return value but process it as navigation
                if ($result -eq "Back" -or $result -eq "Main Menu" -or $result -eq 0)
                {
                    Write-Verbose "[$functionName] Action returned navigation option: $result, processing as navigation instead of value"
                    # Process as navigation
                    if ($result -eq "Back" -and $Depth -gt 0 -and $History.Count -gt 0)
                    {
                        Write-Verbose "[$functionName] Going back to previous menu from action result."
                        $History.RemoveAt($History.Count - 1)
                        $previousMenu = $MenuHistory[$MenuHistory.Count - 1]
                        Write-Verbose "[$functionName] Previous menu found: $($previousMenu.Title)"
                        $MenuHistory.RemoveAt($MenuHistory.Count - 1)
                        Write-Verbose "[$functionName] Decreasing depth since we are going back from action result."
                        $Depth = ($Depth - 1) 
                        Write-Verbose "[$functionName] Current depth after going back: $Depth"
                        return ShowMenu -Menu $previousMenu 
                    }
                    elseif ($result -eq "Main Menu" -and $MenuHistory.Count -gt 0)
                    {
                        Write-Verbose "[$functionName] Going to main menu from action result."
                        $mainMenu = $MenuHistory[0]
                        Write-Verbose "[$functionName] Main menu found: $($mainMenu.Title)"
                        $History.Clear()
                        $MenuHistory.Clear()
                        [void]$MenuHistory.Add($mainMenu)
                        Write-Verbose "[$functionName] Setting depth to 0 since we are going to main menu from action result."
                        $depth = 0
                        return ShowMenu -Menu $mainMenu 
                    }
                    elseif ($result -eq 0)
                    {
                        return [int]$result  # Return integer 0 for exit option
                    }
                }
                Write-Verbose "[$functionName] Returning action result: $result"
                return $result
            }
            
            # Check if the action returned a signal to exit the application
            # This happens when actions internally handle exit requests from submenus
            if ($result -eq "EXIT_APPLICATION")
            {
                Write-Verbose "[$functionName] Action requested application exit, propagating exit signal"
                return $null
            }
            
            # If the action returned the backout text, respect it and don't show "press any key"
            if ($result -eq $backoutText)
            {
                Write-Verbose "[$functionName] Action returned backout text, returning to menu"
                return ShowMenu -Menu $Menu
            }
            
            # Display action result if any
            if ($null -ne $result)
            {
                Write-Host "`n$result" -ForegroundColor Cyan
            }
            
            Write-Verbose "[$functionName] Action executed: $($selectedItem.Name)"
            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            return ShowMenu -Menu $Menu 
        }
        elseif ($selectedItem.Submenu)
        {
            Write-Verbose "[$functionName] Navigating to submenu: $($selectedItem.Submenu.Title)"
            # Navigate to submenu - add current menu to navigation history
            # Use PowerShell 5.1 compatible method for ArrayList operations
            
            try
            {
                Write-Verbose "[$functionName] Adding current menu to history: $($Menu.Title)"
                [void]$History.Add($Menu.Title)
                [void]$MenuHistory.Add($Menu)
            }
            catch
            {
                Write-Verbose "[$functionName] Error adding to history: $_"
                # Fallback for PowerShell 5.1 compatibility
                Write-Verbose "[$functionName] Fallback for PowerShell 5.1 compatibility - using += operator"
                $History += $Menu.Title
                Write-Verbose "[$functionName] Added current menu to history using += operator: $($Menu.Title)"
                $MenuHistory += $Menu
            }
            Write-Verbose "[$functionName] Increasing depth for submenu navigation."
            $Depth = ($Depth + 1)
            Write-Verbose "[$functionName] Current depth after submenu navigation: $Depth"
            return ShowMenu -Menu $selectedItem.Submenu 
        }
    }
}


function CreateSecretsFile()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$SecretsFile = "$RootFolder\.secrets\secrets.json"
    )
    
    #region print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
    Write-Verbose "SecretsFile: $SecretsFile"
    #endregion
    
    if (-not(Test-Path $SecretsFile))
    {
        Write-Verbose "Creating secrets file at $SecretsFile."
        $secrets = @{}
        $secrets | ConvertTo-Json -Depth 10 | Set-Content -Path $SecretsFile -Force
        Write-Host "Secrets file created successfully at $SecretsFile."
    }
    else
    {
        Write-Host "Secrets file already exists at $SecretsFile."
    }
}

function InitializeConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [switch]$overwrite
    )
    
    #region print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
    Write-Verbose "InitFile: $InitFile"
    Write-Verbose "Overwrite: $overwrite"
    #endregion
    
    $initVars = @(
        [ordered] @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; default = ".\\.secrets\\config.json"; type = 'string'},
        [ordered] @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; default = 'vars.json'; type = 'string'},
        [ordered] @{ShowAdvancedOptions = @('True', 'False'); description = "Show advanced options in the GUI."; devdefault = 'True'; reldefault = 'True'; default = 'False'; type = 'array'},
        [ordered] @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; default = ''; type = 'string'},
        [ordered] @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        [ordered] @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        [ordered] @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Github'; default = 'Github'; type = 'array'}, 
        [ordered] @{name = 'Release'; value = "2.2"; description = 'The release branch to use.'; devdefault = 'main'; reldefault = '2.2'; default = 'main'; type = 'string'}
    )
    $vars = @()
    $success = $false
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "Creating configuration file at $InitFile."
        foreach ($var in $initVars)
        {
            $vars += [ordered] @{
                name        = $var.name
                value       = $var.value
                description = $var.description
                devdefault  = $var.devdefault
                reldefault  = $var.reldefault
                default     = $var.default
                type        = $var.type
            }
        }
        $Vars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
    }
    else
    {
        if ($overwrite)
        {
            Write-Verbose "Overwriting configuration file at $InitFile."
            $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
        }
        else
        {
            Write-Host "Initialization file already exists at $InitFile."
            Write-Host "Would you like to overwrite the file?"
            $choice = Read-Host "Overwrite? (y/n)"
            while ($choice -notin ('y', 'n'))
            {
                Write-Host "Invalid input. Please enter 'y' or 'n'."
                [console]::beep(1000, 500)
                $choice = Read-Host "Overwrite? (y/n)"
            }
            if ($choice -eq 'y')
            {
                Write-Verbose "Overwriting initialization file at $InitFile."
                $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
            }
            else
            {
                Write-Host "Initialization file not overwritten."
                return $success
            }
        }
    }
    if (Test-Path $InitFile)
    {
        Write-Host "Initialization file created successfully at $InitFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create initialization file at $InitFile."
    }
    return $success
}

function CreateConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'release'
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Root folder: $Folder"
    Write-Verbose "[$functionName] Init file: $InitFile"
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] ConfigurationType: $ConfigurationType"
    $success = $false
    if (Test-Path -Path $InitFile)
    {
        Write-Verbose "[$functionName] Found init file at $InitFile."
        $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    }
    else
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Init file created successfully."
            $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    $data = @{}
    #endregion
    
    Write-Verbose "[$functionName] Found $($valuesToEdit.PSCustomObject.Count) properties."
    #Iterate over the ValuesToEdit and create the config data
    foreach ($value in $valuesToEdit)
    {
        Write-Verbose "[$functionName] Processing property name: $($value.Name)"
        switch ($ConfigurationType)
        {
            'release'
            {
                Write-Verbose "[$functionName] Name: $($value.Name)"
                Write-Verbose "[$functionName] Release Value: $($value.reldefault)"
                $Data += [ordered] @{$value.Name = $value.relDefault}
            }
            'dev'
            {
                Write-Verbose "[$functionName] Name: $($value.Name)"
                Write-Verbose "[$functionName] Dev Value: $($value.devdefault)"
                $Data += [ordered] @{$value.Name = $value.devdefault}
            }
            'default'
            {
                Write-Verbose "[$functionName] Name: $($value.Name)"
                Write-Verbose "[$functionName] Default Value: $($value.default)"
                $Data += [ordered] @{$value.Name = $value.default}
            }
        }
    }
    Write-Verbose "[$functionName] Config data: $($Data | ConvertTo-Json -Depth 10)"
    #write the config data to the configuration file
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    #Check to make sure it was written.
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "[$functionName] Configuration file created successfully at $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create configuration file at $ConfigurationFile."
        $success = $false
    }
    #Return the success status
    return $success
}

function CreateFullConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [string]$InitFile = "$RootFolder\init.json"
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    $success = $false
    if (-not(Test-Path -Path $InitFile))
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder -InitFile $InitFile)
        {
            Write-Host "Init file created successfully."
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    Write-Verbose "[$functionName] Reading init file at $InitFile."
    $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    $configData = @()
    #endregion
    
    #region Load parameters from the configuration file if it exists
    if (-not(Test-Path -Path $ConfigurationFile))
    {
        Write-Host "No configuration file found at $ConfigurationFile."
        Write-Host "Creating configuration file at $ConfigurationFile."
        if (CreateConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Configuration file created successfully."
        }
        else
        {
            Write-Host "Failed to create configuration file."
            return $success
        }
    }
    Write-Host " Loading configuration values from $ConfigurationFile."
    $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
    Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    #endregion
    
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "[$functionName] Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            $configType = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).type
            $configDescription = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).description
            $configValue = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).value
            if ($configValue -eq '')
            {
                Write-Verbose "[$functionName] Config value is empty."
                Write-Verbose "[$functionName] Setting config value to 'none'."
                $configValue = 'none'
            }
            Write-Verbose "[$functionName] Stored Key name: $($config.Name)"
            Write-Verbose "[$functionName] Stored Key value: $($config.Value)"
            Write-Verbose "[$functionName] Possible Key values: $configValue"
            Write-Verbose "[$functionName] Key description: $configDescription"
            Write-Verbose "[$functionName] Key type: $configType"
            switch ($configType)
            {
                'string'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Description: $($configDescription)"
                    $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                    if ($value -eq '' -or $null -eq $value)
                    {
                        $value = $config.Value
                    }
                    Write-Host "New value: $value"
                    Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'array'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Press enter to keep the current value: $($config.Value)."
                    Write-Host "Description: $($configDescription)"
                    foreach ($item in $configValue)
                    {
                        Write-Host "[$($configValue.IndexOf($item)+1)] $item"
                        if ($config.Value -contains $item)
                        {
                            $currentlySelected = $configValue.IndexOf($item) + 1
                            Write-Verbose "[$functionName] The currently selected value is $currentlySelected"
                        }
                    }
                    $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -lt 1 -or $value -gt $configValue.Count -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500, 300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    }
                    if ($value -eq '')
                    {
                        $value = $config.Value
                    }
                    else
                    {
                        $value = $configValue[$value - 1]
                    }
                    Write-Host "Value: $value"
                    Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'static'
                {
                    Write-Verbose "[$functionName] This is a static value and cannot be changed."
                    Write-Host "Value: $($config.Value)"
                }
            }
        }
    } # Closing brace for foreach loop
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "[$functionName] New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "[$functionName] $($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "[$functionName] Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
    Write-Verbose "[$functionName] Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to save configuration to $ConfigurationFile."
    }
    return $success
}

function GetTimeZoneAbbreviation()
{
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$DateTime
    )
    $functionName = $MyInvocation.MyCommand.Name    
    # Get the current time zone
    Write-Verbose "[$functionName] Getting current time zone."
    $timeZone = [System.TimeZoneInfo]::Local
    Write-Verbose "[$functionName] Current time zone: $($timeZone.DisplayName)"
    
    # Check if it's daylight saving time
    Write-Verbose "[$functionName] Checking if it's daylight saving time."
    $isDaylightSavingTime = $timeZone.IsDaylightSavingTime($DateTime)
    Write-Verbose "[$functionName] Is daylight saving time: $isDaylightSavingTime"
    
    # Get the display name
    Write-Verbose "[$functionName] Getting display name."
    $displayName = if ($isDaylightSavingTime)
    {
        Write-Verbose "[$functionName] Getting daylight name."
        $timeZone.DaylightName 
        Write-Verbose "[$functionName] Daylight name: $($timeZone.DaylightName)"
    }
    else
    {
        Write-Verbose "[$functionName] Getting standard name."
        $timeZone.StandardName 
        Write-Verbose "[$functionName] Standard name: $($timeZone.StandardName)"
    }
    
    # Try to extract abbreviation from display name (usually in parentheses)
    Write-Verbose "[$functionName] Extracting abbreviation from display name."
    if ($displayName -match '\(([A-Z]{3})\)')
    {
        Write-Verbose "[$functionName] Found abbreviation in display name."
        return $matches[1]
    }
    
    # If no abbreviation in parentheses, create one from the time zone id
    Write-Verbose "[$functionName] No abbreviation found in display name. Creating one from time zone ID."
    $abbreviation = switch -Regex ($timeZone.Id)
    {
        'Eastern'
        {
            Write-Verbose "[$functionName] Time zone ID is Eastern."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'EDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: EDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'EST' 
                Write-Verbose "[$functionName] Standard time abbreviation: EST"
            } 
        }
        'Central'
        {
            Write-Verbose "[$functionName] Time zone ID is Central."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'CDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: CDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'CST' 
                Write-Verbose "[$functionName] Standard time abbreviation: CST"
            } 
        }
        'Mountain'
        {
            Write-Verbose "[$functionName] Time zone ID is Mountain."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'MDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: MDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'MST' 
                Write-Verbose "[$functionName] Standard time abbreviation: MST"
            } 
        }
        'Pacific'
        {
            Write-Verbose "[$functionName] Time zone ID is Pacific."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'PDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: PDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'PST' 
                Write-Verbose "[$functionName] Standard time abbreviation: PST"
            } 
        }
        'Alaska'
        {
            Write-Verbose "[$functionName] Time zone ID is Alaska."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'ADT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: ADT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'AST' 
                Write-Verbose "[$functionName] Standard time abbreviation: AST"
            } 
        }
        'Hawaii'
        {
            Write-Verbose "[$functionName] Time zone ID is Hawaii."
            'HST' 
            Write-Verbose "[$functionName] Standard time abbreviation: HST"
        }
        default
        { 
            Write-Verbose "[$functionName] Time zone ID is not recognized. Creating abbreviation from offset."
            # Create abbreviation from offset
            $offset = $timeZone.GetUtcOffset($DateTime)
            Write-Verbose "[$functionName] Offset: $offset"
            Write-Verbose "[$functionName] Total hours: $($offset.TotalHours)"
            $prefix = if ($offset.TotalHours -ge 0)
            {
                Write-Verbose "[$functionName] Offset is positive."
                '+' 
            }
            else
            {
                Write-Verbose "[$functionName] Offset is negative."
                '-' 
            }
            Write-Verbose "[$functionName] Prefix: $prefix"
            "UTC$prefix$([Math]::Abs($offset.TotalHours))"
            Write-Verbose "[$functionName] Abbreviation: UTC$prefix$([Math]::Abs($offset.TotalHours))"
        }
    }
    Write-Verbose "[$functionName] Final abbreviation: $abbreviation"
    return $abbreviation
}

function FormatDateWithTimeZone()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        $DateTime
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose log of parameters
    Write-Verbose "[$functionName] Received parameters $DateTime"
    #Verify the passed datetime is a valid date.
    Write-Verbose "[$functionName] Verifying DateTime: $($DateTime | Out-String)"
    #If the datetime is passed as a string, convert it to a datetime object.
    if ($DateTime -is [string])
    {
        Write-Verbose "[$functionName] Converting string to DateTime."
        $DateTime = [System.DateTime]::Parse($DateTime)
    }
    if ($null -eq $DateTime -or $DateTime -eq [System.DateTime]::MinValue)
    {
        Write-Verbose "[$functionName] Invalid DateTime provided."
        return $null
    }
    Write-Verbose "[$functionName] DateTime is valid."
    
    # Convert from UTC to local time if the datetime is in UTC
    if ($DateTime.Kind -eq [System.DateTimeKind]::Utc)
    {
        Write-Verbose "[$functionName] Converting UTC DateTime to local time."
        $DateTime = $DateTime.ToLocalTime()
    }
    
    Write-Verbose "[$functionName] Formatting DateTime: $($DateTime | Out-String)"
    # Get the timezone abbreviation
    $tzAbbreviation = GetTimeZoneAbbreviation -DateTime $DateTime
    Write-Verbose "[$functionName] Time zone abbreviation: $tzAbbreviation"
    
    # Format the date without timezone, then append our custom abbreviation
    $formattedDate = $DateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt"
    $formattedWithTz = "$formattedDate $tzAbbreviation"
    
    Write-Verbose "[$functionName] Formatted DateTime: $formattedWithTz"
    return $formattedWithTz
}

function normalizeADUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $functionName = $MyInvocation.MyCommand.Name
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Verbose "[$functionName] Returning original display name."
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

function MergeSettings()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $localSettings,
        [Parameter(Mandatory = $true)]
        $globalSettings,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Local', 'Global')]
        [string]$ConflictResolution = 'Global'
    )
    $functionName = $MyInvocation.MyCommand.Name
    $merged = @{}
    
    # Helper function to flatten a nested object into a flat hashtable
    function ConvertTo-FlatHashtable($object, $prefix = '')
    {
        $flatHash = @{}
        $functionName = $MyInvocation.MyCommand.Name
        if ($object -is [hashtable] -or $object -is [System.Collections.IDictionary])
        {
            Write-Verbose "[$functionName] Flattening hashtable/dictionary with $($object.Keys.Count) keys"
            foreach ($key in $object.Keys)
            {
                $fullKey = if ($prefix)
                {
                    "$prefix.$key" 
                }
                else
                {
                    $key 
                }
                $value = $object[$key]
                
                if (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                    ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0))
                {
                    Write-Verbose "[$functionName] Found nested object at key: $fullKey"
                    $nestedFlat = ConvertTo-FlatHashtable $value $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $flatHash[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding flat key: $fullKey"
                    $flatHash[$fullKey] = $value
                }
            }
        }
        elseif ($object -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Flattening PSCustomObject with $($object.PSObject.Properties.Count) properties"
            foreach ($property in $object.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
            {
                $fullKey = if ($prefix)
                {
                    "$prefix.$($property.Name)" 
                }
                else
                {
                    $property.Name 
                }
                $value = $property.Value
                
                if (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                    ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0))
                {
                    Write-Verbose "[$functionName] Found nested object at property: $fullKey"
                    $nestedFlat = ConvertTo-FlatHashtable $value $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $flatHash[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding flat property: $fullKey"
                    $flatHash[$fullKey] = $value
                }
            }
        }
        else
        {
            # If it's a simple value, just return it with the prefix as key
            if ($prefix)
            {
                $flatHash[$prefix] = $object
            }
        }
        
        return $flatHash
    }    Write-Verbose "[$functionName] Merging settings with conflict resolution: $ConflictResolution"
    
    # Flatten local settings
    Write-Verbose "[$functionName] Flattening local settings"
    $flatLocalSettings = ConvertTo-FlatHashtable $localSettings
    Write-Verbose "[$functionName] Local settings flattened to $($flatLocalSettings.Count) properties"
    
    # Flatten global settings
    Write-Verbose "[$functionName] Flattening global settings"
    $flatGlobalSettings = ConvertTo-FlatHashtable $globalSettings
    Write-Verbose "[$functionName] Global settings flattened to $($flatGlobalSettings.Count) properties"
    
    # Normalize all keys to simple format (remove any prefixes)
    function Get-SimpleKey($key)
    {
        if ($key.Contains('.'))
        {
            return $key.Split('.')[-1]  # Get the last part after the last dot
        }
        return $key
    }
    
    # Create normalized hashtables with simple keys
    $normalizedLocal = @{}
    foreach ($key in $flatLocalSettings.Keys)
    {
        $simpleKey = Get-SimpleKey $key
        $normalizedLocal[$simpleKey] = $flatLocalSettings[$key]
        Write-Verbose "[$functionName] Normalized local key: $key -> $simpleKey"
    }
    
    $normalizedGlobal = @{}
    foreach ($key in $flatGlobalSettings.Keys)
    {
        $simpleKey = Get-SimpleKey $key
        $normalizedGlobal[$simpleKey] = $flatGlobalSettings[$key]
        Write-Verbose "[$functionName] Normalized global key: $key -> $simpleKey"
    }
    
    # Start with local settings
    foreach ($key in $normalizedLocal.Keys)
    {
        $merged[$key] = $normalizedLocal[$key]
        Write-Verbose "[$functionName] Added local setting: $key"
    }
    
    # Merge global settings
    foreach ($key in $normalizedGlobal.Keys)
    {
        if ($merged.ContainsKey($key))
        {
            Write-Verbose "[$functionName] Conflict detected for property: $key"
            
            # If both are arrays, merge arrays
            if ($merged[$key] -is [System.Collections.IEnumerable] -and
                $normalizedGlobal[$key] -is [System.Collections.IEnumerable] -and
                ($merged[$key] -isnot [string]) -and
                ($normalizedGlobal[$key] -isnot [string]))
            {
                Write-Verbose "[$functionName] Both values are arrays, merging arrays for: $key"
                $merged[$key] = @($merged[$key] + $normalizedGlobal[$key])
            }
            else
            {
                # Handle conflict based on ConflictResolution parameter
                if ($ConflictResolution -eq 'Global')
                {
                    Write-Verbose "[$functionName] Resolving conflict by using global value for: $key"
                    $merged[$key] = $normalizedGlobal[$key]
                }
                else
                {
                    Write-Verbose "[$functionName] Resolving conflict by keeping local value for: $key"
                    # Keep the existing local value (do nothing)
                }
            }
        }
        else
        {
            $merged[$key] = $normalizedGlobal[$key]
            Write-Verbose "[$functionName] Added global setting: $key"
        }
    }
    
    Write-Verbose "[$functionName] Final merged settings count: $($merged.Count)"
    return $merged
}

function GetCachedDeviceEnrollmentState()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        $Settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    if ($script:DeviceEnrollmentCache.ContainsKey($SerialNumber) -eq $false)
    {
        Write-Verbose "[$functionName] Cache miss for serial number: $SerialNumber. Fetching from API."
        $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken -Settings $Settings
        if ($enrollmentState)
        {
            $script:DeviceEnrollmentCache[$SerialNumber] = $enrollmentState
            Write-Verbose "[$functionName] Cached enrollment state for serial number: $SerialNumber."
        }
        else
        {
            Write-Verbose "[$functionName] No enrollment state found for serial number: $SerialNumber. Not caching."
        }
        return $enrollmentState
    }
    else
    {
        Write-Verbose "[$functionName] Cache hit for serial number: $SerialNumber. Returning cached enrollment state."
        Write-Host "Using cached enrollment state for serial number: $SerialNumber" -ForegroundColor Cyan
        return $script:DeviceEnrollmentCache[$SerialNumber]
    }
}

function NormalizeUserName()
{
    [CmdletBinding()]
    param (
        [string]$UserName,
        $Settings = $settings # Use the script-level $settings by default
    )
    $functionName = $MyInvocation.MyCommand.Name
    $domain = $settings.domain
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] UserName: $UserName"
    Write-Verbose "[$functionName] Normalizing user name: $UserName"
    $UserName = $UserName.Trim()
    Write-Verbose "[$functionName] Checking if the user name $username is missing the $domain suffix."
    if ($userName -notmatch "@$domain$")
    {
        Write-Verbose "[$functionName] the user name $username is missing the $domain suffix."
        $UserName = "$UserName@$domain"
        Write-Verbose "[$functionName] The user name is now $userName"
    }
    else
    {
        Write-Verbose "[$functionName] The user name is already in the correct format: $UserName"
    }
    Write-Verbose "[$functionName] Final user name: $UserName"
    Write-Verbose "[$functionName] Returning user name: $UserName"
    return $UserName
}

function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput,
        [parameter(Mandatory = $true)]
        [string]$type,
        $settings = $settings # Use the script-level $settings by default
    )
    $functionName = $MyInvocation.MyCommand.Name
    $domain = $settings.domain
    $MaxUserNameLength = $settings.MaxUserNameLength
    $MaxSerialNumberLength = $settings.MaxSerialNumberLength
    $MinSerialNumberLength = $settings.MinSerialNumberLength
    $minUsernameLength = $settings.MinUsernameLength
    $returnValue = @{ valid = $false; value = $null } # Initialize return hash table
    Write-Verbose "[$functionName] Validating input of type '$type': '$UserInput'"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] MaxUserNameLength: $MaxUserNameLength"
    Write-Verbose "[$functionName] MinUserNameLength: $minUsernameLength"
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    switch ($type)
    {
        'serialNumber'
        {
            Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
                Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput.Length -lt $MinSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
                Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput -match '^[a-zA-Z0-9-\s]+$') 
            {
                Write-Verbose "[$functionName] Serial number validation passed"
                $returnValue.value = $UserInput
                $returnValue.valid = $true
                return $returnValue
            }
            else
            {
                Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
                return $returnValue
            }
        }
        'userName'
        {
            Write-Verbose "[$functionName] Checking user name length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxUserNameLength -or $UserInput.Length -lt $minUsernameLength -or $UserInput -match '^\d' -and $null -ne $UserInput)
            {
                Write-Verbose "[$functionName] Username exceeds maximum length of $MaxUserNameLength characters"
                Write-Host "Username needs to have a minimum of $minUsernameLength characters and cannot exceed $MaxUserNameLength characters." -ForegroundColor Red
                Write-Host "The username cannot start with a digit." -ForegroundColor Red
                return $returnValue
            }
            else
            {
                $normalizedUserInput = NormalizeUserName -UserName $UserInput -Settings $settings
                # Basic email format check
                if ($normalizedUserInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                {
                    Write-Verbose "[$functionName] Username validation passed"
                    $returnValue.valid = $true
                    $returnValue.value = $normalizedUserInput
                }
                else
                {
                    Write-Verbose "[$functionName] Username validation failed - must be a valid email format (e.g., user@$domain)"
                    Write-Host "Invalid user name format. Please enter a valid email address (e.g., user@$domain)." -ForegroundColor Red
                    return $returnValue
                }
            }
        }
        default
        {
            Write-Verbose "[$functionName] Unknown validation type: '$type'"
            Write-Host "Unknown validation type: '$type'" -ForegroundColor Red
            return $returnValue
        }
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    return $returnValue
}

function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt,
        [validateSet('userName', 'serialNumber')]
        [string]$InputType,
        $settings = $settings # Use the script-level $settings by default
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] InputType: $InputType"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 

    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity

        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $BackoutText."
            return $null # Return null to signal going back
        }

        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem -type $InputType -settings $settings
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value

        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            # The loop will continue, prompting the user again
        }
    }
}

function ProcessSerialNumber()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing device lookup for serial number: $SerialNumber"
    Write-Verbose "[$functionName] Validating serial number: $SerialNumber"
    if ([string]::IsNullOrWhiteSpace($SerialNumber))
    {
        Write-Host "Serial number cannot be empty or null." -ForegroundColor Red
        return $null # Return null to signal no valid serial number
    }
    
    $success = $false
    $SerialNumber = $SerialNumber.Trim()
    Write-Host "`nLooking up device information for serial number: $SerialNumber" -ForegroundColor Cyan
    $enrollmentState = GetCachedDeviceEnrollmentState -SerialNumber $SerialNumber -AccessToken $AccessToken -Settings $Settings
    if ($enrollmentState)
    {
        $success = $true
        Write-Verbose "[$functionName] Device lookup successful"
        # Display basic device information
        Write-Host "`n=== Device Information ===" -ForegroundColor Green
        Write-Host "Serial Number: $SerialNumber"
        Write-Verbose "[$scriptName] Device is managed: $($enrollmentState.managed)"
        Write-Verbose "[$scriptName] Has device object: $($enrollmentState.hasDeviceObject)"
        Write-Verbose "[$scriptName] In Autopilot: $($enrollmentState.inAutopilot)"
        Write-Verbose "[$scriptName] Device imported: $($enrollmentState.Imported)"
        if ($enrollmentState.inAutopilot)
        {
            Write-Host "This device is enrolled in Autopilot."
            if (-not $enrollmentState.managed)
            {
                Write-Host "Model: $($enrollmentState.autopilot.device.model)"
                Write-Host "Manufacturer: $($enrollmentState.autopilot.device.manufacturer)"
                Write-Host "System Family: $($enrollmentState.autopilot.device.systemFamily)"
                Write-Host "=============================`n" -ForegroundColor Green
            }
            Write-Host "Deployment profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
            {
                Write-Host "Deployment profile: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host "Deployment Profile Assignment Date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone)"
            }
            else
            {
                Write-Host "This device is not assigned to a deployment profile." -ForegroundColor Yellow
            }
            
        }
        else
        {
            Write-Host "This device is not enrolled in Autopilot." -ForegroundColor Yellow
            Write-Host "=============================`n" -ForegroundColor Yellow
        }
        if ($enrollmentState.Imported)
        {
            Write-Verbose "[$scriptName] Imported in Autopilot: $($enrollmentState.inAutopilot)"
            Write-Verbose "[$scriptName] Imported count: $($enrollmentState.ImportedAutopilotDevice.Count)"
            if ($enrollmentState.ImportedAutopilotDevice.Count -gt 1)
            {
                Write-Host "This device was imported into Autopilot $($enrollmentState.ImportedAutopilotDevice.Count) times." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice[$enrollmentState.ImportedAutopilotDevice.Count - 1]
            }
            else
            {
                Write-Host "This device was recently imported into Autopilot." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice
            }
            if (-not $enrollmentState.managed)
            {
                Write-Host "However, this device is not currently managed in Intune."
            }
            Write-Host "Here is the latest known import information:"
            Write-Host "Imported Device ID: $($importedDeviceInfo.id)"
            Write-Host "Last import registration id: $($importedDeviceInfo.state.deviceRegistrationId)"
            Write-Host "Last import status: $($importedDeviceInfo.state.deviceImportStatus)"
            Write-Host "Last import error: $($importedDeviceInfo.state.deviceErrorName)"
            Write-Host "Last import error code: $($importedDeviceInfo.state.deviceErrorCode)"
        }
        else
        {
            Write-Verbose "This device was not recently imported into Autopilot."
        }
        if ($enrollmentState.managed)
        {
            $deviceName = $enrollmentState.managedDevice.device.deviceName
            $model = $enrollmentState.managedDevice.device.model
            $manufacturer = $enrollmentState.managedDevice.device.manufacturer
            $managedDeviceId = $enrollmentState.managedDevice.device.id
            Write-Host "Device Name: $deviceName"
            Write-Host "Model: $model"
            Write-Host "Manufacturer: $manufacturer"
            Write-Host "Status: Managed by Intune" -ForegroundColor Green
            Write-Host "=============================`n" -ForegroundColor Green
            # Create and show device actions menu using main.ps1 menu structure
            $deviceActionsMenu = NewMenu -Title "Device Actions for $deviceName" -Description "Select an action to perform on this device:"
            # Add menu items for each device action
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Wipe Device" -Action {
                Write-Host "`nInitiating device wipe for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'wipe' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Clean Device" -Action {
                Write-Host "`nInitiating device clean for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'clean' -MonitorAction
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Sync Device" -Action {
                Write-Host "`nSyncing device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync' -MonitorAction
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
                Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
                $deviceReport = ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
                Write-Verbose "[$functionName] Device report: $deviceReport"
                # Handle navigation responses from ShowReport
                if ($deviceReport -eq "Back" -or $deviceReport -eq "back")
                {
                    Write-Verbose "[$scriptName] User selected Back from device selection, returning to previous menu"
                    return $backoutText
                }
                elseif ($deviceReport -eq "Main Menu" -or $deviceReport -eq "main menu")
                {
                    Write-Verbose "[$scriptName] User selected Main Menu from device selection"
                    return "EXIT_APPLICATION"
                }
                elseif ([string]::IsNullOrWhiteSpace($deviceReport) -or $null -eq $deviceReport)
                {
                    Write-Verbose "[$scriptName] User requested application exit from device selection."
                    return "EXIT_APPLICATION"
                }        
                elseif ($deviceReport -ne '0' -and $null -ne $deviceReport -and $deviceReport -ne "Back" -and $deviceReport -ne "Main Menu")
                {
                    if ($deviceReport -eq $true -or $deviceReport -in ("Export to HTML", "Export to CSV"))
                    {
                        Write-Host "`nDevice health status displayed successfully." -ForegroundColor Green
                    }
                    else
                    {
                        Write-Host "`nDevice health status could not be displayed." -ForegroundColor Red
                    }
                    Write-Verbose "[$scriptName] ShowDeviceReport returned: $deviceReport"
                }
                return $backoutText
            }
            # Show the device actions menu with navigation context
            Write-Verbose "[$functionName] Showing device actions menu with Depth: $depth, History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)"
            $result = ShowMenu -Menu $deviceActionsMenu
            Write-Verbose "Returning from device actions menu with result: $result"
            return $result
        }
        else
        {
            Write-Host "This device is not managed in Intune." -ForegroundColor Yellow
        }
        if ($enrollmentState.hasDeviceObject)
        {
            Write-Host "`nDevice object found in Intune." -ForegroundColor Green
            Write-Host "Device ID: $($enrollmentState.managedDevice.device.id)"
            Write-Host "Device Name: $($enrollmentState.managedDevice.device.deviceName)"
            Write-Host "Model: $($enrollmentState.managedDevice.device.model)"
        }
        else
        {
            Write-Host "This device does not have an associated object in Intune." -ForegroundColor Red
        }
    }
    else
    {
        # Explicitly return $null if no enrollmentState
        Write-Verbose "[$functionName] Device lookup failed or no enrollment state found"
        return $null
    }
    
    # Return success status for calling functions
    return $success
}

function GetLatestGitlabRelease()
{
    [CmdletBinding()]
    param (
        [string]$ProjectID
    )
    $functionName = $MyInvocation.MyCommand.Name
    $gitlabURL = 'https://git.gao.gov'
    $gitlabAPIEndpoint = "$gitlabURL/api/v4"
    $gitlabAPIProjectEndpoint = "$gitlabAPIEndpoint/projects/$ProjectID"
    $gitlabAPILatestReleaseEndpoint = "$gitlabAPIProjectEndpoint/releases/permalink/latest"
    $returnValue = $null
    Write-Verbose "[$functionName] GitLab URL: $gitlabURL"
    Write-Verbose "[$functionName] GitLab API Endpoint: $gitlabAPIEndpoint"
    Write-Verbose "[$functionName] GitLab API Project Endpoint: $gitlabAPIProjectEndpoint"
    Write-Verbose "[$functionName] GitLab API Latest Release Endpoint: $gitlabAPILatestReleaseEndpoint"
    Write-Verbose "[$functionName] Project ID: $ProjectID"
    Write-Verbose "[$functionName] Attempting to retrieve the latest release from GitLab..."
    Write-Verbose "[$functionName] getting latest release from $gitlabAPILatestReleaseEndpoint"
    $response = Invoke-RestMethod -Uri $gitlabAPILatestReleaseEndpoint -Method Get -ErrorAction SilentlyContinue
    if ($response)
    {
        Write-Verbose "[$functionName] Successfully retrieved the latest release. Tag Name: $($response.tag_name)"
        $returnValue = $response.tag_name
    }
    else 
    {
        Write-Verbose "[$functionName] Failed to retrieve the latest release from GitLab. Trying to get the default branch instead."
        Write-Verbose "[$functionName] Attempting to retrieve project details from: $gitlabAPIProjectEndpoint"
        $response = Invoke-RestMethod -Uri $gitlabAPIProjectEndpoint -Method Get -ErrorAction SilentlyContinue
        if ($response)
        {
            Write-Verbose "[$functionName] Successfully retrieved project details. Default Branch: $($response.default_branch)"
            $returnValue = $response.default_branch
        }
        else
        {
            Write-Verbose "[$functionName] Failed to retrieve project details from GitLab."
        }
    }
    Write-Verbose "[$functionName] Returning value: $returnValue"
    return $returnValue
}

function GetLatestGithubRelease()
{
    [CmdletBinding()]
    param (
        [string]$Repository
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking the latest release for Repository: $Repository"
    $url = "https://api.github.com/repos/$Repository/releases/latest"
    Write-Verbose "[$functionName] Requesting URL: $url"
    $response = Invoke-RestMethod -Uri $url -Method Get 
    Write-Verbose "[$functionName] Got response: $($response.tag_name)"
    if (($null -eq $response) -or ($null -eq $response.tag_name ))
    {
        Write-Host "Failed to retrieve the latest release information from GitHub."
        return $null
    }
    return $response.tag_name
}

function GetUpdates()
{
    param (
        $returnValues = $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$RootFolder,
        [Parameter(Mandatory = $false)]
        [string]$LocalVersion = $null,
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL,
        [Parameter(Mandatory = $true)]
        [string]$updateURL
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region write a verbose log of received parameters.
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] LocalVersion: $LocalVersion"
    Write-Verbose "[$functionName] remoteVersionURL: $remoteVersionURL"
    Write-Verbose "[$functionName] updateURL: $updateURL"
    #endregion

    #region get local version
    Write-Verbose "[$functionName] Checking if we received a local version."
    if ($null -eq $LocalVersion -or $LocalVersion -eq '')
    {
        Write-Verbose "[$functionName] LocalVersion is null or empty. Returning to calling function."
        return $null
    }
    Write-Host "LocalVersion: $LocalVersion"
    $localVersion = [System.Version]::Parse($LocalVersion)
    #endregion

    #region get the remote version.
    Write-Verbose "[$functionName] Getting remote version from $remoteVersionURL"
    try 
    {
        $remoteVersionResponse = Invoke-WebRequest -Uri $remoteVersionURL -Method Get -ErrorAction Stop
    }
    catch 
    {
        Write-Verbose "[$functionName] Response: $($remoteVersionResponse)"
        Write-Verbose "[$functionName] Remote version response content: $($remoteVersionResponse.Content)"
        Write-Verbose "[$functionName] Remote version status code: $($remoteVersionResponse.StatusCode)"
        return $null
    }    
    Write-Verbose "[$functionName] Returned remote version response: $remoteVersion"
    $remoteVersion = $remoteVersionResponse.content
    Write-Verbose "[$functionName] remoteVersion = $remoteVersion"
    if ($null -eq $remoteVersion -or $remoteVersion -eq '')
    {
        Write-Host "Failed to get remote version from response. Please provide a valid remote version."
        return $null
    }
    $remoteVersion = [regex]::Match($remoteVersion, '\d+\.\d+\.\d').Value
    Write-Verbose "[$functionName] processed remote version: $remoteVersion"
    $remoteVersion = [System.Version]::Parse($remoteVersion)
    #endregion
    
    #region compare versions
    Write-Verbose "[$functionName] Comparing local version $localVersion with remote version $remoteVersion"
    if ($remoteVersion -gt $localVersion)
    {
        Write-Verbose "[$functionName] Remote version $remoteVersion is greater than local version $localVersion. Proceeding with update."
        Write-Host "An update is available to version $remoteVersion. Downloading update from $updateURL."
        #make a backup of register.exe.
        $backupFile = Join-Path -Path $RootFolder -ChildPath "register.exe.bak"
        if (Test-Path $backupFile)
        {
            Write-Host "Backup file already exists. Deleting old backup file."
            Remove-Item -Path $backupFile -Force
        }
        Write-Host "Backing up current register.exe to $backupFile."
        Copy-Item -Path "$RootFolder\register.exe" -Destination $backupFile -Force
        #download the update file.
        $updateFile = Join-Path -Path $RootFolder -ChildPath "register.exe"
        $response = Invoke-WebRequest -Uri $updateURL -OutFile $updateFile -Method Get -ErrorAction Stop -PassThru
        #check the return code.
        if ($response.StatusCode -ne 200)
        {
            Write-Host "Failed to download update from $updateURL. Status code: $($response.StatusCode)"
            return $returnValues.UpdateFailedMessage
        }
        else
        {
            Write-Verbose "[$functionName] Update downloaded successfully to $updateFile."
            return $returnValues.UpdateSuccessMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Local version $localVersion is up to date with remote version $remoteVersion. No update required."
        return $returnValues.UpdateNotNeededMessage
    }
    #endregion
}


#endregion Inlined Functions

