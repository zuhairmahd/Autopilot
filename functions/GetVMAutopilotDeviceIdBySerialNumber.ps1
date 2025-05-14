function GetVMAutopilotDeviceIdBySerialNumber() 
{
    [CmdletBinding()]
    param (
        [string]$serialNumber,
        [string]$accessToken
    )

    #write a verbose log  of receved parameters
    Write-Verbose "Received serial number: $serialNumber"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    $autopilotDevices = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI).value
    Write-Verbose "Received $($autopilotDevices.Count) devices from Autopilot."
    for ($i = 0; $i -lt $autopilotDevices.Count; $i++)
    {
        $device = $autopilotDevices[$i]
        Write-Verbose "Processing device with serial number $($device.serialNumber)"
        $filteredDeviceSerialNumber = $device.serialNumber -replace '\s', ''
        Write-Verbose "Filtered device serial number: $filteredDeviceSerialNumber"
        if ($serialNumber -match '\s')
        {
            Write-Verbose "Also filtering input serial number $serialNumber since it contains spaces."
            $serialNumber = $serialNumber -replace '\s', ''
            Write-Verbose "Filtered input serial number: $serialNumber"
        }
        if ($filteredDeviceSerialNumber -eq $serialNumber)
        {
            Write-Verbose "Found a match for serial number $serialNumber in Autopilot."
            return $device.id
        }
        else
        {
            Write-Verbose "No match for serial number $serialNumber in Autopilot."
        }
    }
    Write-Verbose "Filtered device serial number: $filteredDeviceSerialNumber"
    return $null
}

