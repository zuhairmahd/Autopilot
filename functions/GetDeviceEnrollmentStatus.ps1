#region help
<#PSScriptInfo
.VERSION 2.2.0
.GUID c5b2b9ce-7269-4fe5-a126-3c84a5053d37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Verifies the enrollment status of a device in Intune and Autopilot.
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement, WindowsAutoPilotIntune
.SYNOPSIS
Checks if a device is enrolled in Intune and imported into Autopilot.
.DESCRIPTION
    This function verifies the enrollment status of a device in Intune and Autopilot. It checks if the device is imported into Autopilot and if it is enrolled in Intune. The function retrieves the device's details, including its serial number, user information, and enrollment status. If the device is not found in Intune, it returns a null state for the user and device ID.
.PARAMETER serialNumber
    The serial number of the device to verify. This parameter is required.
.EXAMPLE
    VerifyEnrollmentStatus -serialNumber "12345"
    Verifies the enrollment status of the device with serial number "12345".
.NOTES
  1. Retrieves device information from Autopilot and Intune.
  2. Checks if the device is imported into Autopilot.
  3. Checks if the device is enrolled in Intune and retrieves user information if available.
  4. Returns the device state, including enrollment and import status.
#>
#endregion help

function GetDeviceEnrollmentStatus()
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken,
        $settings = $settings
    )

    #region Define variables
    Write-Verbose "Serial Number: $serialNumber"
    if ($accessToken)
    {
        Write-Verbose 'Received Access Token'
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
    #endregion

    #region Get the autopilot device info
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "VMware device detected."
        # $autopilotDeviceFilter = "AzureActiveDirectoryDeviceId eq '$($managedDevice.AzureAdDeviceId)'"
        # Alternative approach if the above doesn't work
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)'"
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)' or AzureActiveDirectoryDeviceId eq '$AzureActiveDirectoryDeviceId'"
        $autoPilotVMDevice = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "Received $($autoPilotVMDevice.count) devices from Autopilot."
        if ($autoPilotVMDevice -and $autoPilotVMDevice.count -gt 0)
        {
            Write-Verbose "Got an Autopilot Device with device id $($autoPilotVMDevice)"
            $autopilotDeviceUriWithId = "$autopilotDeviceUri/$autoPilotVMDevice"
            $params = @{
                AccessToken  = $accessToken
                ResourcePath = $autopilotDeviceUriWithId
            }
        }
        else
        {
            Write-Verbose "No match for device with serial number $serialNumber found in Autopilot."
        }
    }
    else
    {
        Write-Verbose "Not a VMWare device. Continuing"
        $params = @{
            AccessToken  = $accessToken
            ResourcePath = $autoPilotDeviceURI
            Filter       = $autopilotDeviceFilter
        }
    }
    $autopilotDeviceResponse = CallGraphAPI @params
    if ($null -ne $autopilotDeviceResponse -and $autopilotDeviceResponse.'@odata.count' -gt 0)
    {
        Write-Verbose "Got a device count of $($autopilotDeviceResponse.'@odata.count') from Autopilot."
        $autopilotDevice = $autopilotDeviceResponse.value
    }
    elseif ($null -ne $autopilotDeviceResponse -and ($null -ne $autopilotDeviceResponse.id -or $autopilotDeviceResponse.id -ne '') )
    {
        Write-Verbose "Got a single autopilot device with id $($autopilotDeviceResponse.id)"
        $autopilotDevice = $autopilotDeviceResponse
    }
    else
    {
        Write-Verbose "Did not get a good response for device with serial number $serialNumber"
        $inAutopilot = $false
    }
    if ($autopilotDevice)
    {
        $inAutopilot = $true
        Write-Verbose "Getting deployment profile information for device with serial number $($autopilotDevice.serialNumber)"
        # $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)?`$expand=deploymentProfile(`$select=displayName)"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)?`$expand=deploymentProfile"
        $autopilotDevice = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -APIVersion 'beta' 
        Write-Verbose "Got $($autopilotDevice.count) devices from Autopilot."
        Write-Verbose "Enrollment Profile name: $($autopilotDevice.deploymentProfile.displayname)"
        Write-Verbose "Device is in Autopilot: $inAutopilot to true."
        $returnedAutopilotDevice = $autopilotDevice 
        Write-Verbose "Getting latest events for device with serial number $($autopilotDevice.serialNumber)"
        $autopilotDeviceEventsFilter = "deviceSerialNumber eq '$($autopilotDevice.serialNumber)'"
        $autopilotEvents = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotEventsURI -filter $autopilotDeviceEventsFilter
        Write-Verbose "Found $($autopilotEvents.value.count) Autopilot events."
        if ($autopilotEvents)
        {
            Write-Verbose "Returning $($autopilotEvents.value.count) Events found for device with serial number $($autopilot.serialNumber)"
            $returnedAutopilotEvents = ($autopilotEvents | Sort-Object createdDateTime -Descending).value 
            Write-Verbose "Autopilot Events: $($returnedAutopilotEvents.count)"
        }
        else
        {
            Write-Verbose 'No events found for device in Autopilot'
        }
    }
    else
    {
        Write-Verbose 'Device is not an autopilot device.'
        $inAutopilot = $false
    }
    if ($autopilotDevice)
    {
        Write-Verbose "Getting imported Autopilot device info for serial number $($autopilotDevice.serialNumber) from autopilot object."
        $importedDeviceFilter = "serialNumber eq '$($autopilotDevice.serialNumber)'"
    }
    else
    {
        Write-Verbose "Getting imported Autopilot device info for serial number $serialNumber from serial number."
        $importedDeviceFilter = "serialNumber eq '$serialNumber'"
        $importedAutopilotDeviceResult = CallGraphAPI -AccessToken $accessToken -ResourcePath $importedAutopilotDeviceURI -Filter $importedDeviceFilter
        $importedAutopilotDevice = $importedAutopilotDeviceResult.value
        Write-Verbose "Returned Imported Autopilot Device serial number: $($autopilotDevice.serialNumber)"
        if ($importedAutopilotDevice)
        {
            Write-Verbose "Device found in Imported Autopilot device list with serial number $($importedAutopilotDevice.serialNumber)"
            $imported = $true
            $returnedImportedDevice = $importedAutopilotDevice
        }
        else
        {
            Write-Verbose 'Device not found in the list of imported Autopilot devices'
            Write-Verbose "This means the device may have already been registered."
        }
    }
    #endregion

    #region Get the managed device info
    #If the serial number contains spaces, remove them.
    if ($serialNumber -match '\s')
    {
        Write-Verbose "Serial number contains spaces. Removing them."
        $serialNumber = $serialNumber -replace '\s', ''
    }
    $managedDeviceFilter = "serialNumber eq '$serialNumber'"
    $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -Filter $managedDeviceFilter).value
    Write-Verbose "Device serial number: $($managedDevice.serialNumber)"
    if ($managedDevice)
    {
        Write-Verbose "Device found in Intune with serial number $($managedDevice.serialNumber)"
        $inManagedDevices = $true
        $returnedManagedDevice = $managedDevice
        Write-Verbose "Checking device memory information."
        $hardwareResourcePath = "$deviceManagementUri/$($autopilotDevice.managedDeviceId)" 
        Write-Verbose "Calling graph using the path $hardwareResourcePath with the extra parameters         $deviceHardwareExtraparameters"
        $deviceMemory = (CallGraphAPI -AccessToken $accessToken -ResourcePath $hardwareResourcePath -APIVersion 'beta' -ExtraParameters $deviceHardwareExtraparameters).physicalMemoryInBytes
        Write-Verbose "Device memory in bytes: $deviceMemory"
        if ($deviceMemory -gt 0) 
        {   
            Write-Verbose "Converting memory to gigabytes."
            $deviceMemory = [math]::round($deviceMemory / 1GB, 2)
            Write-Verbose "Device memory: $deviceMemory GB"
        }
        else
        {
            Write-Verbose 'Device memory not found.'
            $deviceMemory = $null
        }
        Write-Verbose "Got device memory: $deviceMemory"
        Write-Verbose "Checking for logged on users for device with serial number $($managedDevice.serialNumber)"
        Write-Verbose "managedDevice.usersLoggedOn: $($managedDevice.usersLoggedOn)"
        Write-Verbose "managedDevice.userPrincipalName: $($managedDevice.userPrincipalName)"
        Write-Verbose "managedDevice.emailAddress: $($managedDevice.emailAddress)"
        Write-Verbose "ManagedDevice.userDisplayName: $($managedDevice.userDisplayName)"
        if ($nnull -ne $managedDevice.usersLoggedOn )
        {
            Write-Verbose "Device has logged on users."
            $hasUserObject = $true
            $hasUser = $true
            $lastLogonDateTime = $managedDevice.usersLoggedOn.lastLogonDateTime
            Write-Verbose "Last logon date: $lastLogonDateTime"
        }
        elseif ($null -ne $managedDevice.userPrincipalName -and $managedDevice.userPrincipalName -match $settings.domain)
        {
            Write-Verbose "Device has a userPrincipalName."
            $azureUser = $true
            $hasUser = $true
            Write-Verbose "The last logon date is unavailable."
        }
        elseif ($null -ne $managedDevice.emailAddress -and $managedDevice.userPrincipalName -match $settings.domain) 
        {
            Write-Verbose "Device has an email address."
            $azureUser = $true
            $hasUser = $true
            Write-Verbose "The last logon date is unavailable."
        }
        else
        {
            Write-Verbose 'No associated users found for device in Intune'
        }
        if ($hasUser -and $hasUserObject -eq $false)
        {
            Write-Verbose "No user object detected.  Returning device values."
            if ($managedDevice.userPrincipalName -match $settings.domain)
            {
                Write-Verbose 'User is an Azure AD user'
                $azureUser = $true
            }
            else
            {
                Write-Verbose 'User is not an Azure AD user'
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
            Write-Verbose "Retrieving the logged on user for device with serial number $($managedDevice.serialNumber) and ID $($managedDevice.Id)"
            Write-Verbose "Passing $deviceManagementUri/$($managedDevice.Id)/$userUri to graph."
            $user = (CallGraphAPI -AccessToken $accessToken -ResourcePath "$deviceManagementUri/$($managedDevice.Id)/$userUri" -APIVersion 'beta').value
            Write-Verbose "User Display Name: $($user.displayName)"
            Write-Verbose "userPrincipalName: $($user.userPrincipalName)"
            if ($user.userPrincipalName -match $settings.domain)
            {
                Write-Verbose 'User is an Azure AD user'
                $azureUser = $true
            }
            else
            {
                Write-Verbose 'User is not an Azure AD user'
            }
            $loggedOnUsers = @{
                AzureUser         = $azureUser
                lastLogOnDateTime = $lastLogonDateTime
                userDisplayName   = $user.displayName
                userPrincipalName = $user.userPrincipalName
                emailAddress      = $user.emailAddress
                user              = $user
            }
            Write-Verbose "LoggedOn Users: $($loggedOnUsers.Count)"
        }
        else
        {
            Write-Verbose 'No logged on users found for device in Intune'
        }
    }
    else
    {
        Write-Verbose 'Device not found in Intune'
    }
    #Getting the unmanaged device object from Intune
    if ($managedDevice )
    {
        Write-Verbose "Looking up device with Azure Active Directory id $($managedDevice.azureActiveDirectoryDeviceId)"
        $deviceId = $managedDevice.azureActiveDirectoryDeviceId
        $deviceFilter = "deviceId eq '$deviceId'"
    }
    else
    {
        Write-Verbose "Attempting to find device with serial number."
        $deviceFilter = "endswith(displayName, '$serialNumber')"
    }
    $device = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceUri -filter $deviceFilter -consistencyLevel).value
    if ($device -and $device.count -gt 0)
    {
        Write-Verbose "Device found in Intune with serial number $($device.serialNumber)"
        $hasDeviceObject = $true
        $returnedDevice = $device.value
    }
    else
    {
        Write-Verbose 'Device not found in Intune'
    }
    #endregion
    
    #region Verbose logging
    if ($inAutopilot)
    {
        Write-Verbose "Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "Autopilot Registered: $inAutopilot"
        if ($returnedAutopilotEvents)
        {
            Write-Verbose "The device has had $($returnedAutopilotEvents.count) events."
        }
        else
        {
            Write-Verbose 'No Autopilot events found'
        }
    }
    else
    {
        Write-Verbose 'Device not found in Autopilot'
    }
    if ($inManagedDevices)
    {
        Write-Verbose "Device is managed in Intune with serial number $($device.serialNumber)"
        Write-Verbose "Device managed: $inManagedDevices"
    }
    else
    {
        Write-Verbose 'Device not managed in Intune'
    }
    if ($imported)
    {
        Write-Verbose "Device is imported into Autopilot with serial number $($importedAutopilotDevice.serialNumber)"
        Write-Verbose "Device Imported: $imported"
    }
    else
    {
        Write-Verbose 'Device not imported into Autopilot'
    }
    if ($hasDeviceObject)
    {
        Write-Verbose "Device found in Intune with display name: $($device.displayName)"
        Write-Verbose "Device has device object: $hasDeviceObject"
    }
    else
    {
        Write-Verbose 'Device not found in Intune'
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
