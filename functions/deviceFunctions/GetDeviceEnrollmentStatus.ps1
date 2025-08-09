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
        
        #region Check device memory
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
        #endregion

        #region check device users
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
        #endregion

        #region Check for LAPS credentials
        $lapsUri = "directory/deviceLocalCredentials/$($managedDevice.azureADDeviceId)"
        $lapsExtraParameters = "select=credentials" 
        $laps = CallGraphAPI -accessToken $AccessToken -ResourcePath $lapsUri -extraParameters $lapsExtraParameters 
        if ($null -ne $laps -and $laps -ne $returnValues.noLAPSFoundMessage)
        {
            Write-Verbose "[$functionName] LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        }
        else
        {
            Write-Verbose "[$functionName] No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        }
        #endregion
        #region Check device hardwre password
        $hwPassword = GetBIOSPassword -accessToken $accessToken -serialNumber $serialNumber
        if ($hwPassword -and $hwPassword.count -gt 0)
        {
            Write-Verbose "[$functionName] Hardware password found for device with ID $($managedDevice.azureADDeviceId)"
        }
        else
        {
            Write-Verbose "[$functionName] No hardware password found for device with ID $($managedDevice.azureADDeviceId)"
        }
        #endregion
        #region Get bitlocker recovery objects.
        $bitlockerURI = "informationProtection/bitlocker/recoveryKeys"
        $bitlockerFilter = "deviceId eq '$($managedDevice.azureADDeviceId)'"
        $bitlockerExtraParameters = "select=id,createdDateTime,volumeType,deviceId" 
        Write-Verbose "[$scriptName] Getting BitLocker recovery keys for device: $($managedDevice.azureADDeviceId)"
        $bitlockerKeys = CallGraphApi -accessToken $accessToken -ResourcePath $bitlockerURI -filter $bitlockerFilter -extraParameters $bitlockerExtraParameters 
        if ($bitlockerKeys.value.count -gt 0)
        {
            Write-Verbose "[$functionName] $($bitlockerKeys.value.count) BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)"
            #get the latest BitLocker recovery key
            $latestBitlockerKey = $bitlockerKeys.value | Sort-Object createdDateTime -Descending | Select-Object -First 1
        }
        else
        {
            Write-Verbose "[$functionName] No BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)" 
            $bitlockerKeys = $returnValues.noBitLockerKeysFoundMessage
            $latestBitlockerKey = $null
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
    if ($hasUserObject)
    {
        Write-Verbose "[$functionName] Device has user object: $hasUserObject"
        Write-Verbose "[$functionName] Device has user: $hasUser"
    }
    else
    {
        Write-Verbose "[$functionName] Device does not have user object: $hasUserObject"
        Write-Verbose "[$functionName] Device does not have user: $hasUser"
    }
    if ($loggedOnUsers)
    {
        Write-Verbose "[$functionName] Logged on users: $($loggedOnUsers.Count)"
        Write-Verbose "[$functionName] Logged on user display name: $($loggedOnUsers.userDisplayName)"
        Write-Verbose "[$functionName] Logged on user principal name: $($loggedOnUsers.userPrincipalName)"
        Write-Verbose "[$functionName] Logged on user email address: $($loggedOnUsers.emailAddress)"
    }
    else
    {
        Write-Verbose "[$functionName] No logged on users found for device in Intune"
    }
    if ($laps)
    {
        Write-Verbose "[$functionName] LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
        Write-Verbose "[$functionName] LAPS credentials count: $($laps.credentials.count)"
    }
    else
    {
        Write-Verbose "[$functionName] No LAPS credentials found for device with ID $($managedDevice.azureADDeviceId)"
    }
    if ($bitlockerKeys -and $bitlockerKeys.value.count -gt 0)
    {
        Write-Verbose "[$functionName] BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)"
        Write-Verbose "[$functionName] BitLocker recovery keys count: $($bitlockerKeys.value.count)"
    }
    else
    {
        Write-Verbose "[$functionName] No BitLocker recovery keys found for device with ID $($managedDevice.azureADDeviceId)"
    }
    if ($hwPassword -and $hwPassword.count -gt 0)
    {
        Write-Verbose "[$functionName] Hardware password found for device with ID $($managedDevice.azureADDeviceId)"
    }
    else
    {
        Write-Verbose "[$functionName] No hardware password found for device with ID $($managedDevice.azureADDeviceId)"
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
        HardwarePassword   = $hwPassword
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

