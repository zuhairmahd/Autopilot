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


function GetAutoPilotDeviceSerialNumber() 
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken
    )

    #write a verbose log  of receved parameters
    Write-Verbose "Received serial number: $serialNumber"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $autopilotDevices = CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI
    Write-Verbose "Received $($autopilotDevices.value.Count) devices from Autopilot."
    $serialNumbers = $autopilotDevices.value | Select-Object -ExpandProperty serialNumber
    Write-Verbose "Received $($serialNumbers.Count) serial numbers from Autopilot."
    Write-Verbose "Serial numbers received from Autopilot: $($serialNumbers -join ', ')"
    foreach ($device in $serialNumbers)
    {
        Write-Verbose "Processing device with serial number $device"
        $filteredDevice = $device -replace '\s', ''
        Write-Verbose "Filtered device serial number: $filteredDevice"
        if ($filteredDevice -eq $serialNumber)
        {
            Write-Verbose "Device with serial number $serialNumber found in Autopilot."
            return $device
        }
        else
        {
            Write-Verbose "Device with serial number $serialNumber not found in Autopilot."
        }
    }
    return $valueToReturn
}

function GetDeviceEnrollmentStatus()
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken
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
    $managedDeviceFilter = "serialNumber eq '$serialNumber'"
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    #endregion

    #region Get the autopilot device info
    if ($serialNumber -match 'vmware')
    {
        Write-Verbose "VMware device detected."
        # $autopilotDeviceFilter = "AzureActiveDirectoryDeviceId eq '$($managedDevice.AzureAdDeviceId)'"
        # Alternative approach if the above doesn't work
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)'"
        # $autopilotDeviceFilter = "managedDeviceId eq '$($managedDevice.id)' or AzureActiveDirectoryDeviceId eq '$AzureActiveDirectoryDeviceId'"
        $autoPilotDeviceSerialNumber = GetAutopilotDeviceSerialNumber -AccessToken $AccessToken -serialNumber $serialNumber
        Write-Verbose "Autopilot device serial number: $autoPilotDeviceSerialNumber"
        if ($autoPilotDeviceSerialNumber)
        {
            Write-Verbose "Device with serial number $autoPilotDeviceSerialNumber found in Autopilot."
            $autopilotDeviceFilter = "contains(serialNumber,'$autoPilotDeviceSerialNumber')"
        }
        else
        {
            Write-Verbose "No match for device with serial number $serialNumber found in Autopilot."
        }
    }
    else
    {
        Write-Verbose "Not a VMWare device. Continuing"
    }
    $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
    Write-Verbose "Found $($autopilotDevice.count) Autopilot devices."
    Write-Verbose "Autopilot Device serial number: $($autopilotDevice.serialNumber)"
    if ($autopilotDevice)
    {
        Write-Verbose "Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "Getting deployment profile information for device with serial number $($autopilotDevice.serialNumber)"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)`?`$expand=deploymentProfile"
        $autopilotDevice = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -APIVersion 'beta' 
        $inAutopilot = $true
        $returnedAutopilotDevice = $autopilotDevice
        Write-Verbose "Getting latest events for device with serial number $($autopilotDevice.serialNumber)"
        $autopilotDeviceEventsFilter = "deviceSerialNumber eq '$($autopilotDevice.serialNumber)'"
        $autopilotEvents = CallGraphAPI -AccessToken $accessToken -ResourcePath $autopilotEventsURI -filter $autopilotDeviceEventsFilter
        Write-Verbose "Found $($autopilotEvents.value.count) Autopilot events."
        if ($autopilotEvents)
        {
            Write-Verbose "Returning $($autopilotEvents.value.count) Events found for device with serial number $($autopilotEvents.serialNumber)"
            $returnedAutopilotEvents = ($autopilotEvents | Sort-Object createdDateTime -Descending).value 
            Write-Verbose "Autopilot Events: $($returnedAutopilotEvents | ConvertTo-Json)"
        }
        else
        {
            Write-Verbose 'No events found for device in Autopilot'
        }
    }
    else
    {
        Write-Verbose 'Device is not an autopilot device.'
    }
    
    Write-Verbose "Getting imported Autopilot device info for serial number $($autopilotDevice.serialNumber)"
    $importedDeviceFilter = "serialNumber eq '$($autopilotDevice.serialNumber)'"
    $importedAutopilotDevices = CallGraphAPI -AccessToken $accessToken -ResourcePath $importedAutopilotDeviceURI -filter $importedDeviceFilter
    Write-Verbose "Found $($importedAutopilotDevices.value.count) Imported Autopilot devices."
    $importedAutopilotDevice = $importedAutopilotDevices.value | Where-Object { $_.serialNumber -match $serialNumber }
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
    #endregion

    #region Get device info
    Write-Verbose "Getting device info for serial number $serialNumber"
    $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -Filter $managedDeviceFilter).value
    Write-Verbose "Device serial number: $($managedDevice.serialNumber)"
    if ($managedDevice)
    {
        Write-Verbose "Device found in Intune with serial number $($managedDevice.serialNumber)"
        $inManagedDevices = $true
        $returnedManagedDevice = $managedDevice
        Write-Verbose "Checking for logged on users for device with serial number $($managedDevice.serialNumber)"
        $users = $managedDevice.usersLoggedOn
        Write-Verbose "Users logged on: $($users)"
        if ($users)
        {
            Write-Verbose "Retrieving the logged on user for device with serial number $($managedDevice.serialNumber) and ID $($managedDevice.Id)"
            Write-Verbose "Passing $deviceManagementUri/$($managedDevice.Id)/$userUri to graph."
            $user = CallGraphAPI -AccessToken $accessToken -ResourcePath "$deviceManagementUri/$($managedDevice.Id)/$userUri" -APIVersion 'beta'
            if ($user.userPrincipalName -like '*@*' -or $user.userName -like '*@*')
            {
                Write-Verbose 'User is an Azure AD user'
                $azureUser = $true
            }
            else
            {
                Write-Verbose 'User is not an Azure AD user'
            }
            Write-Verbose "User Display Name: $($user.displayName)"
            Write-Verbose "userPrincipalName: $($user.userPrincipalName)"
            $loggedOnUsers = @{
                AzureUser         = $azureUser
                user              = $user.value
                lastLogOnDateTime = $device.usersLoggedOn.lastLogonDateTime
            }
            Write-Verbose "LoggedOn Users: $($loggedOnUsers | ConvertTo-Json)"
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
    $deviceId = $autopilotDevice.azureActiveDirectoryDeviceId
    $deviceFilter = "deviceId eq '$deviceId'"
    $device = CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceUri -filter $deviceFilter -consistencyLevel
    if ($device -and $device.value.count -gt 0)
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
        Users  = $loggedOnUsers
    }
    $deviceState.add('managedDevice', $managedDeviceData)
    $deviceState.add('imported', $imported)
    $deviceState.add('importedAutopilotDevice', $returnedImportedDevice)
    $deviceState.add('hasDeviceObject', $hasDeviceObject)
    $deviceState.add('device', $returnedDevice)
    Write-Verbose "Device State: $($deviceState | ConvertTo-Json)"
    #endregion
    return $deviceState
}
