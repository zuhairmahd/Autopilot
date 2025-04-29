function DeleteAutopilotDevice()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$serialNumber,
        [string]$accessToken = $accessToken
    )

    #region Define variables
    Write-Verbose "Serial Number: $serialNumber"
    if ($accessToken)
    {
        Write-Verbose 'Received Access Token'
    }
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
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
    #endregion
    
    $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
    Write-Verbose "Found $($autopilotDevice.count) Autopilot devices."
    Write-Verbose "Autopilot Device serial number: $($autopilotDevice.serialNumber)"
    if ($autopilotDevice)
    {
        Write-Verbose "Device found in Autopilot with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$($autopilotDevice.id)"
        Write-Verbose "Delete URI: $deleteUri"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "Passing the uri $deleteUri"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "Delete response: $($deleteResponse | Out-String)"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
            $success = $true
        }
        else
        {
            Write-Verbose "Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
        }
    }
    else
    {
        Write-Host "No autopilot device found with serial number $serialNumber."
        Write-Verbose "No autopilot device found with serial number $serialNumber."
    }
    return $success
}