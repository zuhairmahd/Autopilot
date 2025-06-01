function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [ValidateSet("clean", "wipe", "sync", "restart")]
        [string]$Command = "clean",
        [int]$MaxRetries = 20,
        [int]$RetryDelaySeconds = 15,
        [switch]$MonitorAction,
        [switch]$NoConfirmation
    )
  
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Device ID:     $ManagedDeviceId"
    Write-Verbose "[$functionName] Command: $Command"
    Write-Verbose "[$functionName] MaxRetries: $MaxRetries"
    Write-Verbose "[$functionName] RetryDelaySeconds: $RetryDelaySeconds"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        return $false
    }
    #endregion

    # Confirmation for destructive operations only
    if (-not $NoConfirmation -and ($Command -eq "clean" -or $Command -eq "wipe" -or $Command -eq "restart"))
    {
        Write-Host "Are you sure you want to $Command the device?" -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'yes' to confirm, or 'no' to cancel"
        if ($confirmation -ne 'yes')
        {
            Write-Host "Operation cancelled." -ForegroundColor Gray
            return $false
        }
    }

    Write-Host "Sending $Command command to device with identifier $ManagedDeviceId" -ForegroundColor Cyan
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $success = $false
    $actionType = ""
    $response = ""
  
    switch ($Command)
    {
        "clean"
        {
            Write-Host 'Cleaning the device...' -ForegroundColor Yellow
            $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
            $body = @{ 'keepUserData' = $false } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0' 
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "cleanWindows"
        }
        "wipe"
        {
            Write-Host 'Wiping the device...' -ForegroundColor Yellow
            $wipeURI = "$deviceManagementUri/wipe"
            $body = @{
                'keepEnrollmentData'   = $false
                'keepUserData'         = $false
                'obliterationBehavior' = "doNotObliterate"
            } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $wipeURI -body $body -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "wipe"
        }
        "sync"
        {
            Write-Host 'Syncing the device...' -ForegroundColor Yellow
            $syncUri = "$deviceManagementUri/syncDevice"
            $response = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "syncDevice"
        }
        "restart"
        {
            Write-Host 'Restarting the device...' -ForegroundColor Yellow
            $restartUri = "$deviceManagementUri/rebootNow"
            $response = callGraphApi -AccessToken $accessToken -Method 'POST' -ResourcePath $restartUri -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $actionType = "rebootNow"
        }
        default
        {
            Write-Host "Invalid command. Please use 'clean', 'wipe', 'sync', or 'restart'." -ForegroundColor Red
            return $false
        }
    }  
    # Monitor action status for all operations
    if ($MonitorAction)
    {
        if ($response -eq '')
        {
            Write-Host "Command sent successfully. Performing automatic device sync..." -ForegroundColor Green
        
            # Only send additional sync for non-sync operations to avoid redundancy
            if ($Command -ne "sync")
            {
                $syncUri = "$deviceManagementUri/syncDevice"
                $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
                Write-Verbose "[$functionName] Sync Response: $syncResponse"
            }

            # Begin monitoring the action status
            Write-Host "Starting to monitor $Command action status..." -ForegroundColor Yellow
            $retryCount = 0
            $actionCompleted = $false
            $actionFailed = $false
            $actionState = "unknown"

            # Loop until action completes, fails, or max retries reached
            while (-not $actionCompleted -and -not $actionFailed -and $retryCount -lt $MaxRetries)
            {
                $retryCount++
                Write-Host "Checking $Command status, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
                Write-Verbose "[$functionName] Checking action results (Attempt $retryCount of $MaxRetries)"
  
                # Wait before checking
                Start-Sleep -Seconds $RetryDelaySeconds
  
                # Check action results
                $deviceDetails = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
                Write-Verbose "[$functionName] Device action results: $($deviceDetails | ConvertTo-Json -Depth 5)"
                Write-Host "Action results: $($deviceDetails.deviceActionResults)"
  
                if ($deviceDetails -and $deviceDetails.deviceActionResults)
                {
                    # Find the relevant action result based on action type
                    $actionResult = $null
                    foreach ($result in $deviceDetails.deviceActionResults)
                    {
                        if ($result.actionName -eq $actionType)
                        {
                            $actionResult = $result
                            break
                        }
                    }
                    if ($actionResult)
                    {
                        $actionState = $actionResult.status
                        Write-Host "Current $Command status: $actionState" -ForegroundColor Cyan
                        Write-Verbose "[$functionName] Action start time: $($actionResult.startDateTime)"
                        Write-Verbose "[$functionName] Action last updated: $($actionResult.lastUpdatedDateTime)"
                        # Check if action completed or failed
                        switch ($actionState)
                        {
                            "succeeded"
                            {
                                Write-Host "$Command action completed successfully!" -ForegroundColor Green
                                $actionCompleted = $true
                                $success = $true
                            }
                            "failed"
                            {
                                Write-Host "$Command action failed with error: $($actionResult.errorCode)" -ForegroundColor Red
                                if ($actionResult.errorDescription)
                                {
                                    Write-Host "Error description: $($actionResult.errorDescription)" -ForegroundColor Red
                                }
                                $actionFailed = $true
                                $success = $false
                            }
                            "timeout"
                            {
                                Write-Host "$Command action timed out." -ForegroundColor Red
                                $actionFailed = $true
                                $success = $false
                            }
                            "canceled"
                            {
                                Write-Host "$Command action was canceled." -ForegroundColor Red
                                $actionFailed = $true
                                $success = $false
                            }
                            "notFound"
                            {
                                Write-Verbose "[$functionName] Action not found yet or device may no longer be available."
                                if ($retryCount -gt 3)
                                {
                                    Write-Verbose "[$functionName] Action not found after multiple attempts, assuming device is no longer available."
                                    $actionFailed = $false
                                    $success = $true
                                }
                            }
                            default
                            {
                                Write-Verbose "[$functionName] Action status is '$actionState', continuing to monitor."
                                # Continue monitoring for non-terminal states
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "[$functionName] No action of type '$actionType' found yet."
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] No device action results available or device might be offline/no longer accessible."
                    # If we can no longer get device details, check if device still exists
                    $deviceCheck = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0'
                    if (-not $deviceCheck)
                    {
                        Write-Host "Device is no longer accessible. This could be expected for wipe operations." -ForegroundColor Yellow
                        # For wipe operations, this might be expected behavior as device is reset
                        if ($Command -eq 'wipe')
                        {
                            Write-Host "Wipe command appears to have succeeded as device is no longer accessible." -ForegroundColor Green
                            $actionCompleted = $true
                            $success = $true
                        }
                    }
                }
            }

            # Final status report
            if ($actionCompleted)
            {
                Write-Host "$Command action has completed successfully." -ForegroundColor Green
            }
            elseif ($actionFailed)
            {
                Write-Host "$Command action has failed with status: $actionState" -ForegroundColor Red
            }
            else
            {
                Write-Host "$Command action monitoring timed out after $MaxRetries attempts." -ForegroundColor Yellow
                Write-Host "Last known status: $actionState" -ForegroundColor Yellow
                Write-Warning "The action may still be in progress. You can check the device status in the Intune portal."
            }
        }
        else
        {
            Write-Host "Failed to send $Command command to device." -ForegroundColor Red
            Write-Verbose "[$functionName] Failed to send command. Response: $response"
        }
    }
    return $success
}

function GetDeviceIdFromSerial()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    #region Variables and verbose logs    
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    $filter = "serialNumber eq '$SerialNumber'"
    $extraParameters = "select=Id"
    $device = $null
    Write-Verbose "[$functionName] Serial Number: $SerialNumber"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] No AccessToken provided."
        return $false
    }
    #endregion    # Query the device enrollment status using Microsoft Graph API
    # Fetch the device details using the serial number
    $response = CallGraphApi -AccessToken $AccessToken -ResourcePath $managedDeviceUri -filter $filter -ExtraParameters $extraParameters -Method GET
    if ($response)
    {
        $device = $response.value.Id
        Write-Verbose "[$functionName] Device found with ID: $($device)"
    }
    else
    {
        Write-Verbose "[$functionName] Device with serial number $SerialNumber not found."
    }
    return $device
}
