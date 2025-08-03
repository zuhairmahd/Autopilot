function GetTotalRegisteredDevicesByUser()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserName,
        [parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $Uri = "users/$userName/registeredDevices"
    Write-Verbose "[$functionName] Getting total registered devices for user: $UserName"
    if ($null -eq $AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken is null or empty. Cannot proceed."
        return 0
    }
    Write-Verbose "[$functionName] AccessToken provided."
    $registeredDevices = (CallGraphAPI -AccessToken $AccessToken -ResourcePath $Uri).value
    Write-Verbose "[$functionName] Registered devices count: $($registeredDevices.Count)"
    if ($registeredDevices -and $registeredDevices.Count -gt 0)
    {
        Write-Verbose "[$functionName] Returning count of registered devices: $($registeredDevices.Count)"
        return $registeredDevices.Count
    }
    else
    {
        Write-Verbose "[$functionName] No registered devices found for user: $UserName"
        return 0
    }
}

