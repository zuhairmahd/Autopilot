function SendDeviceCommand ()
{
    [CmdletBinding()]
    param (
        [string]$ManagedDeviceId,
        [string]$accessToken,
        [string]$Command = "clean"
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Host "Are you sure you want to $command the device?"
    $confirmation = Read-Host "Type 'yes' to confirm, or 'no' to cancel"
    if ($confirmation -ne 'yes')
    {
        Write-Host "Operation cancelled."
        return $false
    }
    Write-Verbose "[$functionName] Device ID: $ManagedDeviceId"
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
        Write-Verbose "[$functionName] Response: $response"
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
        Write-Verbose "[$functionName] Response: $response"
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
        Write-Verbose "[$functionName] Attempting to get the latest device action results."
        $action = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
        Write-Verbose "[$functionName] Action: $action"
        Write-Host "Attempting to perform a device sync."
        $syncResponse = callGraphApi -AccessToken $accessToken -ResourcePath $syncUri -Method POST
        Write-Verbose "[$functionName] Sync Response: $syncResponse"
    }
    return $success
}
