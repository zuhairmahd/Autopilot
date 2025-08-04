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
    $functionName = $MyInvocation.MyCommand.Name    
    Write-Verbose "[$functionName] UserName: $UserName"
    Write-Verbose "[$functionName] Operating system: $OperatingSystem"
    if ($null -ne $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] AccessToken not provided."
        return $null
    }
    $UserName = $UserName.Trim()
    Write-Verbose "[$functionName] Trimmed user name: $UserName"
    $extraparameters = "select=deviceName,serialNumber,userDisplayName,model,manufacturer,complianceState"
    Write-Verbose "[$functionName] Extra parameters for API call: $extraparameters"
    $filter = "startswith(userPrincipalName,'$UserName') and operatingSystem eq '$OperatingSystem'"
    Write-Verbose "[$functionName] Filter for API call: $filter"
    $managedDeviceUri = "deviceManagement/managedDevices"
    Write-Verbose "[$functionName] Managed device URI: $managedDeviceUri"
    #endregion

    $deviceInfo = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -Filter $filter -extraParameters $extraparameters
    Write-Verbose "[$functionName] Device value count: $($deviceInfo.value.Count)"
    Write-Verbose "[$functionName] Device Info: $($deviceInfo | Out-String)"
    if ($deviceInfo -notin 400, 401, 403, 404)
    {
        if ($deviceInfo.value.Count -eq 0)
        {
            Write-Verbose "[$functionName] No devices found for user: $UserName"
            return $returnValues.noDeviceFound
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
            $deviceMenu = NewMenu -Title "Device Selection" -Description "Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))"
            Write-Verbose "[$functionName] Creating device menu with $($devices.Count) devices"
            # Add each device as a menu item
            foreach ($device in $devices)
            {
                
                # Create a display name for the menu
                $menuItemName = "Device: $($device.deviceName) ($($device.manufacturer) $($device.model) SN: $($device.serialNumber)) ($($device.complianceState))"
                Write-Verbose "[$functionName] Adding menu item: $menuItemName"
                # Create a scriptblock action that returns this specific device's serial number when selected
                $serialNumber = $device.serialNumber
                Write-Verbose "[$functionName] Creating action for serial number: $serialNumber"
                $action = {
                    Write-Verbose "[$functionName] Returning Serial Number: $serialNumber"
                    return $serialNumber
                }.GetNewClosure()
                # Add the menu item with the action
                $deviceMenu = AddMenuItem -Menu $deviceMenu -Name $menuItemName -Action $action -ReturnsValue
            }
            Write-Verbose "[$functionName] Showing device selection menu with $($deviceMenu.Items.Count) items"
            Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
            Write-Verbose "[$functionName] Current menu title: $($deviceMenu.Title)"
            $selectedSerialNumber = ShowMenu -Menu $deviceMenu -CalledBy 'Action'
            if ($null -ne $selectedSerialNumber -and $selectedSerialNumber -is [string])
            {
                Write-Verbose "[$functionName] Selected serial number: $selectedSerialNumber"
            }
            else
            {
                Write-Verbose "[$functionName] Selected serial number is null or not a string"
            }
            
            # Validate that we got a proper serial number, not a navigation option
            if ($selectedSerialNumber -eq "Back" -or $selectedSerialNumber -eq "Main Menu" -or $selectedSerialNumber -eq 0 -or $selectedSerialNumber -eq "0")
            {
                Write-Verbose "[$functionName] ShowMenu returned navigation option: '$selectedSerialNumber', treating as navigation"
                return $selectedSerialNumber
            }
            
            Write-Verbose "[$functionName] Returning valid selected serial number: $selectedSerialNumber"
            return $selectedSerialNumber
            # #region Additional validation: check if the returned value is actually a serial number from one of our devices
            ##This section may be removed in the future if we are confident that ShowMenu always returns a valid serial number
            # $isValidSerialNumber = $false
            # foreach ($device in $devices)
            # {
            #     if ($selectedSerialNumber -match $device.serialNumber)
            #     {
            #         $selectedSerialNumber = $device.serialNumber
            #         Write-Verbose "[$functionName] Valid serial number found: $selectedSerialNumber"
            #         $isValidSerialNumber = $true
            #         break
            #     }
            # }
            # if (-not $isValidSerialNumber)
            # {
            #     Write-Verbose "[$functionName] ShowMenu returned invalid serial number: '$selectedSerialNumber', this might be a navigation option or error"
            #     Write-Warning "Unexpected return value from device selection: '$selectedSerialNumber'. Please try again."
            #     return $null
            # }            
            # Write-Verbose "[$functionName] Returning valid selected serial number: $selectedSerialNumber"
            # return $selectedSerialNumber
            # #endregion
        }
    }
    else
    {
        Write-Host "An error occured looking up device for user: $UserName" -ForegroundColor Red
        return $returnValues.noDeviceFound
    }
}

