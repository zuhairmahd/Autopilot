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
    $loggedOnUsers = [ordered] @{}
    $deviceState = [ordered] @{}
    $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $deviceUri = "devices"
    $deviceManagementUri = "deviceManagement/managedDevices"
    $userUri = "users"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $managedDeviceFilter = "serialNumber eq '$serialNumber'"
    $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
    $importedDeviceFilter = "serialNumber eq '$serialNumber'"
    $deviceFilter = "endswith(displayName,'$serialNumber')"
    #endregion

    #region Get the autopilot device info
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
    $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
    Write-Verbose "Found $($autopilotDevice.count) Autopilot devices."
    Write-Verbose "Autopilot Device serial number: $($autopilotDevice.serialNumber)"
    if ($autopilotDevice)
    {
        Write-Verbose "Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        $expandedDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)`?`$expand=deploymentProfile"
        $autopilotDevice = CallGraphAPI -AccessToken $accessToken -ResourcePath $expandedDeviceURI -APIVersion 'beta'
        $inAutopilot = $true
        $returnedAutopilotDevice = $autopilotDevice
    }
    else
    {
        Write-Verbose 'Device is not an autopilot device.'
    }
    if ($serialNumber -like 'vmware*')
    {
        Write-Verbose 'Device Serial Number begins with vmware. Removing spaces from the serial number.'
        $serialNumber = $serialNumber -replace ' ', ''
        Write-Verbose "New Device Serial Number: $serialNumber"
    }
    #endregion

    #region Get the rest of the device info
    $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -Filter $managedDeviceFilter).value
    Write-Verbose "Device serial number: $($managedDevice.serialNumber)"
    if ($managedDevice)
    {
        Write-Verbose "Device found in Intune with serial number $($managedDevice.serialNumber)"
        $inManagedDevices = $true
        $returnedManagedDevice = $managedDevice
        $users = $device.usersLoggedOn
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
                user              = $user
                lastLogOnDateTime = $device.usersLoggedOn.lastLogonDateTime
            }
            Write-Verbose "LoggedOn Users: $($loggedOnUsers | ConvertTo-Json)"
            $deviceState.Add('loggedOnUsers', $loggedOnUsers)
        }
    }
    else
    {
        Write-Verbose 'Device not found in Intune'
    }
    $device = CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceUri -filter $deviceFilter -consistencyLevel
    if ($device)
    {
        Write-Verbose "Device found in Intune with serial number $($device.serialNumber)"
        $hasDeviceObject = $true
        $returnedDevice = $device
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

    $deviceState.Add('InAutopilot', $inAutopilot)
    $deviceState.add('autoPilotDevice', $returnedAutopilotDevice)
    $deviceState.add('Managed', $inManagedDevices)
    $deviceState.add('managedDevice', $returnedManagedDevice)
    $deviceState.add('imported', $imported)
    $deviceState.add('importedAutopilotDevice', $returnedImportedDevice)
    $deviceState.add('hasDeviceObject', $hasDeviceObject)
    $deviceState.add('device', $returnedDevice)
    Write-Verbose "Device State: $($deviceState | ConvertTo-Json)"
    return $deviceState
}
