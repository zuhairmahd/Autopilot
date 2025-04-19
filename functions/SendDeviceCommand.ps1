function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [string]$command = "clean"
    )
    Write-Verbose "Device ID: $ManagedDeviceId"
    Write-Host "Sending $command command to device with ID $ManagedDeviceId"
    $cleanURI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($ManagedDeviceId)/cleanWindowsDevice"
    $wipeURI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($ManagedDeviceId)/wipe"
    $syncUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($ManagedDeviceId)/syncDevice"
    if ($command -eq "clean")
    {
        Write-Host 'Cleaning the device...'
        $body = @{
            'keepUserData' = $false
        }
        $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body
        Write-Verbose "Response: $response"
    }
    elsif ($command -eq 'wipe')
    {
        Write-Host 'Wiping the device...'
        $body = @{
            'keepEnrollmentData'   = $false
            'keepUserData'         = $false
            'obliterationBehavior' = "doNotObliterate"
        }
        $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $wipeURI -body $body
        Write-Verbose "Response: $response"
    }
    else
    {
        Write-Host "Invalid command.  Please use 'clean' or 'wipe'."
        return $null
    }
    if ($response -in @(200, 201, 202, 204))
    {
        Write-Host "The command was sent to the device with ID $ManagedDeviceId."
        Write-Host "Attempting a sync..."
        $syncResponse = callGraphApi -AccessToken $accessToken -Uri $syncUri -Method POST
        Write-Verbose "Sync Response: $syncResponse"
        #Check if the sync was successful.
        if ($syncResponse -in @(200, 201, 202, 204))
        {
            Write-Host "The sync command was sent to the device with ID $ManagedDeviceId."
        }
        else
        {
            Write-Host "The sync command failed to send to the device with ID $ManagedDeviceId."
            Write-Host 'Please manually sync the device or give the device enough time to sync and reset.'
            Write-Host "Error: $($syncResponse | Out-String)"
            Write-Host "Status code: $($syncResponse.StatusCode)"
        }
        Write-Host 'The device will be ready for another user after the wipe is complete.'
        Write-Host 'Please contact an Intune admin if you have any problems.'
        return $true
    }
    else
    {
        Write-Host "The command failed to send to the device with ID $ManagedDeviceId."
        Write-Host 'Please contact an Intune admin.'
        Write-Host "Error: $($response | Out-String)"
        Write-Host "Status code: $($response.StatusCode)"
        return $false
    }
}
