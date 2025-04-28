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

