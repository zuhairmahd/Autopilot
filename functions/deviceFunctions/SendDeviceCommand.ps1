function SendDeviceCommand()
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
    $returnSuccessMessage = $null
    $returnFailureMessage = $null
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $response = ""
    #endregion

    if (-not $NoConfirmation)
    {
        Write-Host "Are you sure you want to $Command the device?" -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'yes' to confirm, or 'no' to cancel"
        if ($confirmation -ne 'yes')
        {
            Write-Host "Operation cancelled." -ForegroundColor Gray
            return $returnedValues.userCanceledMessage
        }
    }
    Write-Host "Sending $Command command to device with identifier $ManagedDeviceId" -ForegroundColor Cyan
    
    switch ($Command)
    {
        "clean"
        {
            Write-Host 'Cleaning the device...' -ForegroundColor Yellow
            $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
            $body = @{ 'keepUserData' = $false } | ConvertTo-Json
            $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0' 
            Write-Verbose "[$functionName] Response: $response"
            $returnSuccessMessage = $returnValues.deviceCleanSuccessMessage
            $returnFailureMessage = $returnValues.deviceCleanFailedMessage
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
            $returnSuccessMessage = $returnValues.deviceWipeSuccessMessage
            $returnFailureMessage = $returnValues.deviceWipeFailedMessage
        }
        "sync"
        {
            Write-Host 'Syncing the device...' -ForegroundColor Yellow
            $syncUri = "$deviceManagementUri/syncDevice"
            $response = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $returnSuccessMessage = $returnValues.deviceSyncSuccessMessage
            $returnFailureMessage = $returnValues.deviceSyncFailedMessage
        }
        "restart"
        {
            Write-Host 'Restarting the device...' -ForegroundColor Yellow
            $restartUri = "$deviceManagementUri/rebootNow"
            $response = callGraphApi -AccessToken $accessToken -Method 'POST' -ResourcePath $restartUri -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Response: $response"
            $returnSuccessMessage = $returnValues.deviceRestartSuccessMessage
            $returnFailureMessage = $returnValues.deviceRestartFailedMessage
        }
        default
        {
            Write-Host "Invalid command. Please use 'clean', 'wipe', 'sync', or 'restart'." -ForegroundColor Red
            return $returnValues.unknownErrorMessage
        }
    }  

    # Report on action status for all operations
    if ($response -eq '')
    {
        Write-Host "Command sent successfully." -ForegroundColor Green
        # Only send additional sync for non-sync operations to avoid redundancy
        if ($Command -ne "sync")
        {
            Write-Host "Performing automatic device sync after $Command operation."
            $syncUri = "$deviceManagementUri/syncDevice"
            $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST -apiVersion 'v1.0'
            Write-Verbose "[$functionName] Sync Response: $syncResponse"
        }
        return $returnSuccessMessage
    }
    else
    {
        Write-Host "Failed to send $Command command to device." -ForegroundColor Red
        Write-Verbose "[$functionName] Failed to send command. Response: $response"
        return $returnFailureMessage
    }
}

