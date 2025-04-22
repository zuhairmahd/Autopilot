function GetDeviceByUser()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserName,
        [parameter(Mandatory = $true)]
        [string]$deviceNamePrefix,
        [parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    #write verbose log of all parameters
    Write-Verbose "UserName: $UserName"
    Write-Verbose "DeviceNamePrefix: $deviceNamePrefix"
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
    $extraparameters = "select=Id,deviceName,serialNumber"
    $filter = "userPrincipalName eq '$username' and startswith(deviceName,'$deviceNamePrefix')"
    $managedDeviceUri = "deviceManagement/managedDevices"
    $deviceInfo = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -Filter $filter -extraParameters $extraparameters
    Write-Verbose "Device value count: $($deviceInfo.value.Count)"
    Write-Verbose "Device Info: $($deviceInfo | Out-String)"
    if ($deviceInfo -notin 400, 401, 403, 404)
    {
        if ($deviceInfo.value.Count -eq 0)
        {
            Write-Host "No devices found for user: $UserName" -ForegroundColor Yellow
            return $null
        }
        elseif ($deviceInfo.value.Count -eq 1)
        {
            # If only one device found, return its serial number directly
            Write-Host "Found one device for user: $UserName" -ForegroundColor Green
            Write-Host "Device Name: $($deviceInfo.value[0].deviceName)" -ForegroundColor Cyan
            Write-Host "Serial Number: $($deviceInfo.value[0].serialNumber)" -ForegroundColor Cyan
            return $deviceInfo.value[0].serialNumber
        }
        else
        {
            # Create device selection menu
            $deviceMenu = NewMenu -Title "Device Selection" -Description "Select a device for user $UserName"
            
            # Store devices in an array to reference later
            $devices = $deviceInfo.value
            
            # Add each device as a menu item
            foreach ($device in $devices)
            {
                # Create a display name for the menu
                $menuItemName = "Device: $($device.deviceName) - SN: $($device.serialNumber)"
                
                # Create a scriptblock action that returns this specific device's serial number when selected
                $serialNumber = $device.serialNumber
                $action = {
                    $serialNumber
                }.GetNewClosure()
                
                # Add the menu item with the action
                $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $menuItemName -Action $action
            }
            
            # Show the menu and return the selected device's serial number
            $selectedSerialNumber = ShowMenu -Menu $deviceMenu
            return $selectedSerialNumber
        }
    }
    else
    {
        Write-Host "No device found for user: $UserName" -ForegroundColor Red
        return $null
    }
}

