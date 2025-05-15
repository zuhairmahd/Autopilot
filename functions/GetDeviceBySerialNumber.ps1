function GetDeviceBySerialNumber ()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $serialNumber
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Searching for device with serial number $serialNumber"
    $managedDevice = Get-MgBetaDeviceManagementManagedDevice -Filter "contains(serialNumber,'$serialNumber')" -All
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    $devices = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
    $devices = $devices.value
    foreach ($device in $devices)
    {
        Write-Verbose "[$functionName] Checking device with serial number $($device.serialNumber)"
        if ($device.serialNumber -eq $serialNumber)
        {
            Write-Verbose "[$functionName] Device found with serial number $serialNumber"
            $deviceToReturn = $device
            break
        }
        else
        {
            Write-Verbose "[$functionName] Device not found with serial number $serialNumber"
        }
    }
    if ($deviceToReturn)
    {
        Write-Verbose "[$functionName] Device found with serial number $serialNumber"
        return $deviceToReturn
    }
    else
    {
        Write-Verbose "[$functionName] Device not found with serial number $serialNumber"
        return $null    
    }
}
