function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [string]$Command = "clean"
    )
    Write-Verbose "Device ID: $ManagedDeviceId"
    Write-Host "Sending $command command to device with ID $ManagedDeviceId"
    $deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
    $cleanURI = "$deviceManagementUri/cleanWindowsDevice"
    $wipeURI = "$deviceManagementUri/wipe"
    $syncUri = "$deviceManagementUri/syncDevice"
    $success = $false
    if ($command -eq "clean")
    {
        Write-Host 'Cleaning the device...'
        $body = @{
            'keepUserData' = $false
        } | ConvertTo-Json
        $response = callGraphApi -AccessToken $accessToken -Method 'post' -ResourcePath $cleanURI -body $body -apiVersion 'v1.0'
        Write-Verbose "Response: $response"
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
        Write-Verbose "Response: $response"
    }
    else
    {
        Write-Host "Invalid command.  Please use 'clean' or 'wipe'."
        return $success
    }
    if ($response -eq '')
    {
        Write-Host "Success."
        $success = $true
        Write-Verbose "Attempting to get the latest device action results."
        $action = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
        Write-Host "Action: $action"
        Write-Host "Attempting to perform a device sync."
        $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST
        Write-Verbose "Sync Response: $syncResponse"
    }
    return $success
}