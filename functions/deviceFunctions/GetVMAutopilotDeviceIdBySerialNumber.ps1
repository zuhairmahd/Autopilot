function GetVMAutopilotDeviceIdBySerialNumber() 
{
    <#
    .SYNOPSIS
    Retrieves the Autopilot device ID for a virtual machine by its serial number.

    .DESCRIPTION
    This function queries Microsoft Graph to retrieve all Windows Autopilot device identities
    and searches for a matching serial number. It handles whitespace normalization in serial
    numbers to ensure accurate matching for virtual machines.

    .PARAMETER serialNumber
    The serial number of the virtual machine to search for in Autopilot.

    .PARAMETER accessToken
    The Microsoft Graph API access token for authentication.

    .OUTPUTS
    System.String
    Returns the Autopilot device ID if found, or $null if no matching device is found.

    .EXAMPLE
    $autopilotId = GetVMAutopilotDeviceIdBySerialNumber -serialNumber "VMSerial123" -accessToken $token

    .NOTES
    Strips whitespace from both input and device serial numbers for comparison.
    Requires appropriate Microsoft Graph permissions to query Autopilot device identities.
    Compatible with PowerShell 5.1.
    #>
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

