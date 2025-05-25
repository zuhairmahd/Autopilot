function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [string]$Command = "clean",
        [int]$MaxRetries = 20,
        [int]$RetryDelaySeconds = 15,
        [switch]$NoConfirmation
    )
  
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] [$functionName] Device ID:     $ManagedDeviceId"
    Write-Verbose "[$functionName] [$functionName] Command: $Command"
    Write-Verbose "[$functionName] [$functionName] MaxRetries: $MaxRetries"
    Write-Verbose "[$functionName] [$functionName] RetryDelaySeconds: $RetryDelaySeconds"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] [$functionName] AccessToken provided."
    }
    else
    {
        Write-Verbose "[$functionName] [$functionName] No AccessToken provided."
        return $false
    }
    #endregion

    if ($NoConfirmation)
    {
        Write-Host "Are you sure you want to $command the device?"
        $confirmation = Read-Host "Type 'yes' to confirm, or 'no' to cancel"
        if ($confirmation -ne 'yes')
        {
            Write-Host "Operation cancelled."
            return $false
        }
    }

    Write-Host "Sending $command command to device with identifyer $ManagedDeviceId"
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
    $wipeURI = "$deviceManagementUri/wipe"
    $syncUri = "$deviceManagementUri/syncDevice"
    $success = $false
    $actionType = ""
  
    if ($command -eq "clean")
    {
        Write-Host 'Cleaning the device...'
        $body = @{
            'keepUserData' = $false
        } | ConvertTo-Json
        $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0' 
        Write-Verbose "[$functionName] [$functionName] Response: $response"
        $actionType = "cleanWindows"
    }
    elseif ($command -eq 'wipe')
    {
        Write-Host 'Wiping the device...'
        $body = @{
            'keepEnrollmentData'   = $false
            'keepUserData'         = $false
            'obliterationBehavior' = "doNotObliterate"
        } | ConvertTo-Json
        $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $wipeURI -body $body -apiVersion 'v1.0' 
        Write-Verbose "[$functionName] [$functionName] Response: $response"
        $actionType = "wipe"
    }
    else
    {
        Write-Host "Invalid command. Please use 'clean' or 'wipe'." -ForegroundColor Red
        return $success
    }
  
    if ($response -eq '')
    {
        Write-Host "Command sent successfully. Attempting to perform a device sync..." -ForegroundColor Green
        $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST
        Write-Verbose "[$functionName] [$functionName] Sync Response: $syncResponse"
    
        # Begin monitoring the action status
        Write-Host "Starting to monitor $command action status..." -ForegroundColor Yellow
        $retryCount = 0
        $actionCompleted = $false
        $actionFailed = $false
        $actionState = "unknown"
    
        # Loop until action completes, fails, or max retries reached
        while (-not $actionCompleted -and -not $actionFailed -and $retryCount -lt $MaxRetries)
        {
            $retryCount++
            Write-Host "Checking $command status, attempt $retryCount of $MaxRetries..." -ForegroundColor Yellow
            Write-Verbose "[$functionName] [$functionName] Checking action results (Attempt $retryCount of $MaxRetries)"
      
            # Wait before checking
            Start-Sleep -Seconds $RetryDelaySeconds
      
            # Check action results
            $deviceDetails = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
            Write-Verbose "[$functionName] [$functionName] Device action results: $($deviceDetails | ConvertTo-Json -Depth 5)"
      
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
                    Write-Host "Current $command status: $actionState" -ForegroundColor Cyan
                    Write-Verbose "[$functionName] [$functionName] Action start time: $($actionResult.startDateTime)"
                    Write-Verbose "[$functionName] [$functionName] Action last updated: $($actionResult.lastUpdatedDateTime)"
          
                    # Check if action completed or failed
                    switch ($actionState)
                    {
                        "succeeded"
                        {
                            Write-Host "$command action completed successfully!" -ForegroundColor Green
                            $actionCompleted = $true
                            $success = $true
                        }
                        "failed"
                        {
                            Write-Host "$command action failed with error: $($actionResult.errorCode)" -ForegroundColor Red
                            if ($actionResult.errorDescription)
                            {
                                Write-Host "Error description: $($actionResult.errorDescription)" -ForegroundColor Red
                            }
                            $actionFailed = $true
                            $success = $false
                        }
                        "timeout"
                        {
                            Write-Host "$command action timed out." -ForegroundColor Red
                            $actionFailed = $true
                            $success = $false
                        }
                        "canceled"
                        {
                            Write-Host "$command action was canceled." -ForegroundColor Red
                            $actionFailed = $true
                            $success = $false
                        }
                        "notFound"
                        {
                            Write-Verbose "[$functionName] [$functionName] Action not found yet or device may no longer be available."
                            # Continue monitoring, this could mean the action hasn't been registered yet
                        }
                        default
                        {
                            Write-Verbose "[$functionName] [$functionName] Action status is '$actionState', continuing to monitor."
                            # Continue monitoring for non-terminal states
                        }
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] [$functionName] No action of type '$actionType' found yet."
                }
            }
            else
            {
                Write-Verbose "[$functionName] [$functionName] No device action results available or device might be offline/no longer accessible."
        
                # If we can no longer get device details, check if device still exists
                $deviceCheck = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0'
                if (-not $deviceCheck)
                {
                    Write-Host "Device is no longer accessible. This could be expected for wipe operations." -ForegroundColor Yellow
                    # For wipe operations, this might be expected behavior as device is reset
                    if ($command -eq 'wipe')
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
            Write-Host "$command action has completed successfully." -ForegroundColor Green
        }
        elseif ($actionFailed)
        {
            Write-Host "$command action has failed with status: $actionState" -ForegroundColor Red
        }
        else
        {
            Write-Host "$command action monitoring timed out after $MaxRetries attempts." -ForegroundColor Yellow
            Write-Host "Last known status: $actionState" -ForegroundColor Yellow
            Write-Warning "The action may still be in progress. You can check the device status in the Intune portal."
        }
    }
    else
    {
        Write-Host "Failed to send $command command to device." -ForegroundColor Red
        Write-Verbose "[$functionName] [$functionName] Failed to send command. Response: $response"
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
    #endregion

    # Query the device enrollment status using Microsoft Graph API
    # Fetch the device details using the serial number
    $response = CallGraphApi -AccessToken $AccessToken -ResourcePath $managedDeviceUri -filter $filter -Method GET
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
