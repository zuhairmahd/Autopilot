function GetDeviceByUser()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserName,
        [parameter(Mandatory = $true)]
        [string]$OperatingSystem,
        [parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    #region write verbose log of all parameters
    Write-Verbose "UserName: $UserName"
    Write-Verbose "Operating system: $OperatingSystem"
    if ($null -ne $AccessToken)
    {
        Write-Verbose "AccessToken provided."
    }
    else
    {
        Write-Verbose "AccessToken not provided."
        return $null
    }
    $UserName = $UserName.Trim()
    Write-Verbose "Trimmed user name: $UserName"
    $extraparameters = "select=deviceName,serialNumber,userDisplayName,model,manufacturer,complianceState"
    $filter = "userPrincipalName ne null and userPrincipalName ne '' and contains(userPrincipalName, '$username') and operatingSystem eq '$OperatingSystem'"
    $managedDeviceUri = "deviceManagement/managedDevices"
    #endregion

    $deviceInfo = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -Filter $filter -extraParameters $extraparameters
    Write-Verbose "Device value count: $($deviceInfo.value.Count)"
    Write-Verbose "Device Info: $($deviceInfo | Out-String)"
    if ($deviceInfo -notin 400, 401, 403, 404)
    {
        if ($deviceInfo.value.Count -eq 0)
        {
            Write-Verbose "No devices found for user: $UserName"
            return $null
        }
        elseif ($deviceInfo.value.Count -eq 1)
        {
            # If only one device found, return its serial number directly
            Write-Host "Found one device for user: $UserName ($($deviceInfo.value[0].userDisplayName))." -ForegroundColor Green
            Write-Host "Device Name: $($deviceInfo.value[0].deviceName)" -ForegroundColor Cyan
            Write-Host "Serial Number: $($deviceInfo.value[0].serialNumber)."
            Write-Host "Device make and model: $($deviceInfo.value[0].manufacturer) $($deviceInfo.value[0].model)."
            Write-Host "Compliance state: $($deviceInfo.value[0].complianceState)."
            return $deviceInfo.value[0].serialNumber
        }
        else
        {
            # Create device selection menu
            $deviceMenu = NewMenu -Title "Device Selection" -Description "Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))"
            # Store devices in an array to reference later
            $devices = $deviceInfo.value
            # Add each device as a menu item
            foreach ($device in $devices)
            {
                # Create a display name for the menu
                # $menuItemName = "Device: $($device.deviceName)  (Serial number: $($device.serialNumber))"
                $menuItemName = "Device: $($device.deviceName) ($($device.manufacturer) $($device.model) SN: $($device.serialNumber)) ($($device.complianceState))"
                # Create a scriptblock action that returns this specific device's serial number when selected
                $serialNumber = $device.serialNumber
                $action = {
                    Write-Verbose "Returning Serial Number: $serialNumber"
                    return $serialNumber
                }.GetNewClosure()
                # Add the menu item with the action
                $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $menuItemName -Action $action -ReturnsValue
            }
            # Show the menu and return the selected device's serial number
            $selectedSerialNumber = ShowMenu -Menu $deviceMenu
            Write-Verbose "Returning selected serial number: $selectedSerialNumber"
            return $selectedSerialNumber
        }
    }
    else
    {
        Write-Host "No device found for user: $UserName" -ForegroundColor Red
        return $null
    }
}

