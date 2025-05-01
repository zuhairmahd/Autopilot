function DeleteAutopilotDevice()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$DeviceIdentifyer,
        [ValidateSet('SerialNumber', 'DeviceId')]
        [string]$IdentifyerType = 'SerialNumber',
        [string]$accessToken = $accessToken
    )

    #region variables and logs.
    Write-Verbose "Received parameters:" 
    if ($accessToken)
    {
        Write-Verbose "    AccessToken provided."
    }
    else
    {
        Write-Verbose "    No AccessToken provided."
        return $null
    }
    Write-Verbose "Device identifier: $DeviceIdentifyer."
    Write-Verbose "Identifyer type: $IdentifyerType."
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "Identifyer Type is $IdentifyerType."
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "VMware device detected."
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Verbose "Returning device id: $autoPilotDeviceId"
                }
                else
                {
                    Write-Verbose "No match for device with serial number $serialNumber found in Autopilot."
                }
            }
            else
            {
                Write-Verbose "Not a VMWare device. Continuing"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "Found $($autopilotDevice.count) Autopilot devices."
                Write-Verbose "Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "Autopilot Device Id: $($autoPilotDeviceId)"
            }
        }
        'DeviceId'
        {
            Write-Verbose "Parameter type is DeviceId."
            Write-Verbose "$IdentifyerType is $deviceIdentifyer."
            $autoPilotDeviceId = $deviceIdentifyer
        }
    }
    if ($autoPilotDeviceId)
    {
        Write-Verbose "Found device with id $autoPilotDeviceId in Autopilot."
        Write-Verbose "Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
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
        Write-Host "No autopilot device found with $IdentifyerType $DeviceIdentifyer."
    }
    return $success
}