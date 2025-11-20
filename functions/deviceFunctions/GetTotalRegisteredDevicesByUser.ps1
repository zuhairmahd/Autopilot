function GetTotalRegisteredDevicesByUser()
{
    <#
    .SYNOPSIS
    Retrieves the total count of devices registered to a user.

    .DESCRIPTION
    This function queries Microsoft Graph to get the count of all devices registered
    to a specific user account. It returns 0 if no devices are found or if the access
    token is invalid.

    .PARAMETER UserName
    The user principal name of the user whose registered devices should be counted.

    .PARAMETER AccessToken
    The Microsoft Graph API access token for authentication.

    .OUTPUTS
    System.Int32
    Returns the count of registered devices, or 0 if none are found or an error occurs.

    .EXAMPLE
    $deviceCount = GetTotalRegisteredDevicesByUser -UserName "john.doe@contoso.com" -AccessToken $token

    .NOTES
    Requires appropriate Microsoft Graph permissions to query user registered devices.
    Compatible with PowerShell 5.1.
    #>
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

