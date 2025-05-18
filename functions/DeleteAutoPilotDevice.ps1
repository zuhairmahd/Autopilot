function DeleteAutopilotDevice()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$DeviceIdentifyer,
        [ValidateSet('SerialNumber', 'DeviceId')]
        [string]$IdentifyerType = 'SerialNumber',
        [string]$accessToken = $accessToken,
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 20
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region variables and logs.
    Write-Verbose "[$functionName] Received parameters:" 
    if ($accessToken)
    {
        Write-Verbose "[$functionName]     AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName]     No AccessToken provided."
        return $null
    }
    Write-Verbose "[$functionName] Device identifier: $DeviceIdentifyer."
    Write-Verbose "[$functionName] Identifyer type: $IdentifyerType."
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "[$functionName] Identifyer Type is $IdentifyerType."
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "[$functionName] VMware device detected."
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "[$functionName] Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "[$functionName] Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Verbose "[$functionName] Returning device id: $autoPilotDeviceId"
                }
                else
                {
                    Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
                }
            }
            else
            {
                Write-Verbose "[$functionName] Not a VMWare device. Continuing"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "[$functionName] Found $($autopilotDevice.count) Autopilot devices."
                Write-Verbose "[$functionName] Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "[$functionName] Autopilot Device Id: $($autoPilotDeviceId)"
            }
        }
        'DeviceId'
        {
            Write-Verbose "[$functionName] Parameter type is DeviceId."
            Write-Verbose "[$functionName] $IdentifyerType is $deviceIdentifyer."
            $autoPilotDeviceId = $deviceIdentifyer
        }
    }
    if ($autoPilotDeviceId)
    {
        Write-Verbose "[$functionName] Found device with id $autoPilotDeviceId in Autopilot."
        Write-Verbose "[$functionName] Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
        Write-Verbose "[$functionName] Delete URI: $deleteUri"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "[$functionName] Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Passing the uri $deleteUri"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "[$functionName] Delete request initiated successfully. Beginning monitoring of device deletion..."
            
            #region Monitor the deletion process
            $retryCount = 0
            $isDeleted = $false
            $deviceInfo = $null
            
            while (-not $isDeleted -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Verifying device deletion, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)"
                
                # Sleep before checking
                Start-Sleep -Seconds $RetryDelaySeconds
                
                # Check if the device still exists
                if ($IdentifyerType -eq 'SerialNumber')
                {
                    $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
                    $deviceInfo = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                }
                else # DeviceId
                {
                    $checkUri = "$autoPilotDeviceURI/$autoPilotDeviceId"
                    try
                    {
                        $deviceInfo = CallGraphAPI -AccessToken $accessToken -ResourcePath $checkUri -Method GET
                        Write-Verbose "[$functionName] Device check response: $($deviceInfo | Out-String)"
                    } 
                    catch
                    {
                        # If the call fails with 404 (not found), the device is deleted
                        Write-Verbose "[$functionName] Error checking device: $_"
                        if ($_.Exception.Response.StatusCode -eq 404)
                        {
                            $deviceInfo = $null
                        }
                    }
                }
                
                if ($null -eq $deviceInfo -or ($deviceInfo.Count -eq 0) -or ($deviceInfo -eq ''))
                {
                    $isDeleted = $true
                    Write-Host "Device deletion confirmed!" -ForegroundColor Green
                    Write-Verbose "[$functionName] Device deletion confirmed at attempt $retryCount."
                }
                else
                {
                    Write-Verbose "[$functionName] Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check."
                }
            }
            
            if ($isDeleted)
            {
                Write-Verbose "[$functionName] Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
                $success = $true
            }
            else
            {
                Write-Host "Device deletion verification timed out after $MaxRetries attempts." -ForegroundColor Red
                Write-Verbose "[$functionName] Delete operation may have been queued but not completed within the monitoring period."
                Write-Warning "Device may still be in the process of being deleted. Please check again later."
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
        }
    }
    else
    {
        Write-Host "No autopilot device found with $IdentifyerType $DeviceIdentifyer."
    }
    return $success
}

function DeleteAutopilotDevice()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$DeviceIdentifyer,
        [ValidateSet('SerialNumber', 'DeviceId')]
        [string]$IdentifyerType = 'SerialNumber',
        [string]$accessToken = $accessToken,
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 20
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region variables and logs.
    Write-Verbose "[$functionName] Received parameters:" 
    if ($accessToken)
    {
        Write-Verbose "[$functionName]     AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName]     No AccessToken provided."
        return $null
    }
    Write-Verbose "[$functionName] Device identifier: $DeviceIdentifyer."
    Write-Verbose "[$functionName] Identifyer type: $IdentifyerType."
    $success = $false
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    #endregion

    switch ($IdentifyerType)
    {
        'SerialNumber'
        {
            $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
            Write-Verbose "[$functionName] Identifyer Type is $IdentifyerType."
            if ($DeviceIdentifyer -match 'vmware')
            {
                Write-Verbose "[$functionName] VMware device detected."
                $autoPilotDeviceId = GetVMAutopilotDeviceIdBySerialNumber -AccessToken $AccessToken -serialNumber $DeviceIdentifyer
                Write-Verbose "[$functionName] Autopilot device Id for serial number $deviceIdentifyer is $autoPilotDeviceId"
                if ($autoPilotDeviceId)
                {
                    Write-Verbose "[$functionName] Device with Id $autoPilotDeviceId found in Autopilot."
                    Write-Verbose "[$functionName] Returning device id: $autoPilotDeviceId"
                }
                else
                {
                    Write-Verbose "[$functionName] No match for device with serial number $serialNumber found in Autopilot."
                }
            }
            else
            {
                Write-Verbose "[$functionName] Not a VMWare device. Continuing"
                $autopilotDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                Write-Verbose "[$functionName] Found $($autopilotDevice.count) Autopilot devices."
                Write-Verbose "[$functionName] Autopilot Device serial number: $($autopilotDevice.serialNumber)"
                $autoPilotDeviceId = $autopilotDevice.id
                Write-Verbose "[$functionName] Autopilot Device Id: $($autoPilotDeviceId)"
            }
        }
        'DeviceId'
        {
            Write-Verbose "[$functionName] Parameter type is DeviceId."
            Write-Verbose "[$functionName] $IdentifyerType is $deviceIdentifyer."
            $autoPilotDeviceId = $deviceIdentifyer
        }
    }
    if ($autoPilotDeviceId)
    {
        Write-Verbose "[$functionName] Found device with id $autoPilotDeviceId in Autopilot."
        Write-Verbose "[$functionName] Defining variables:"
        $deleteUri = "$autopilotDeviceURI/$autoPilotDeviceId"
        Write-Verbose "[$functionName] Delete URI: $deleteUri"
        Write-Host "Deleting autopilot device..."
        Write-Verbose "[$functionName] Calling Graph API to delete autopilot device with serial number $($autopilotDevice.serialNumber)"
        Write-Verbose "[$functionName] Passing the uri $deleteUri"
        $deleteResponse = CallGraphAPI -AccessToken $accessToken -ResourcePath $deleteUri -Method DELETE
        Write-Verbose "[$functionName] Delete response: $($deleteResponse | Out-String)"
        if ($null -eq $deleteResponse -or $deleteResponse -eq '')
        {
            Write-Verbose "[$functionName] Delete request initiated successfully. Beginning monitoring of device deletion..."
            
            #region Monitor the deletion process
            $retryCount = 0
            $isDeleted = $false
            $deviceInfo = $null
            
            while (-not $isDeleted -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Verifying device deletion, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking if device is still present after delete request (Attempt $retryCount of $MaxRetries)"
                
                # Sleep before checking
                Start-Sleep -Seconds $RetryDelaySeconds
                
                # Check if the device still exists
                if ($IdentifyerType -eq 'SerialNumber')
                {
                    $autopilotDeviceFilter = "contains(serialNumber,'$DeviceIdentifyer')"
                    $deviceInfo = (CallGraphAPI -AccessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter).value
                }
                else # DeviceId
                {
                    $checkUri = "$autoPilotDeviceURI/$autoPilotDeviceId"
                    try
                    {
                        $deviceInfo = CallGraphAPI -AccessToken $accessToken -ResourcePath $checkUri -Method GET
                        Write-Verbose "[$functionName] Device check response: $($deviceInfo | Out-String)"
                    } 
                    catch
                    {
                        # If the call fails with 404 (not found), the device is deleted
                        Write-Verbose "[$functionName] Error checking device: $_"
                        if ($_.Exception.Response.StatusCode -eq 404)
                        {
                            $deviceInfo = $null
                        }
                    }
                }
                
                if ($null -eq $deviceInfo -or ($deviceInfo.Count -eq 0) -or ($deviceInfo -eq ''))
                {
                    $isDeleted = $true
                    Write-Host "Device deletion confirmed!" -ForegroundColor Green
                    Write-Verbose "[$functionName] Device deletion confirmed at attempt $retryCount."
                }
                else
                {
                    Write-Verbose "[$functionName] Device still exists after attempt $retryCount. Waiting for $RetryDelaySeconds seconds before next check."
                }
            }
            
            if ($isDeleted)
            {
                Write-Verbose "[$functionName] Autopilot device with serial number $($autopilotDevice.serialNumber) deleted successfully."
                $success = $true
            }
            else
            {
                Write-Host "Device deletion verification timed out after $MaxRetries attempts." -ForegroundColor Red
                Write-Verbose "[$functionName] Delete operation may have been queued but not completed within the monitoring period."
                Write-Warning "Device may still be in the process of being deleted. Please check again later."
                $success = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] Failed to delete autopilot device with serial number $($autopilotDevice.serialNumber)."
        }
    }
    else
    {
        Write-Host "No autopilot device found with $IdentifyerType $DeviceIdentifyer."
    }
    return $success
}
