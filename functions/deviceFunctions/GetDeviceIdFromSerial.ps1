function GetDeviceIdFromSerial()
{
    <#
    .SYNOPSIS
    Retrieves the device ID for a managed device by its serial number.

    .DESCRIPTION
    This function queries Microsoft Graph to get the device ID for a managed device
    identified by its serial number. It implements caching to improve performance by
    storing both successful lookups and "not found" results to avoid redundant API calls.

    .PARAMETER SerialNumber
    The serial number of the device to look up.

    .PARAMETER AccessToken
    The Microsoft Graph API access token for authentication.

    .OUTPUTS
    System.String
    Returns the device ID if found, or $null if the device is not found or an error occurs.

    .EXAMPLE
    $deviceId = GetDeviceIdFromSerial -SerialNumber "ABC123456" -AccessToken $token

    .NOTES
    Uses unified device cache for performance optimization.
    Requires appropriate Microsoft Graph permissions to query managed devices.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    #region Variables and verbose logs    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Check unified cache first
    $cacheKey = "deviceid:$($SerialNumber.ToLower())"
    $cachedDeviceId = Get-CachedData -CacheType 'Devices' -Key $cacheKey -CacheSettings $global:cacheSettings
    
    if ($null -ne $cachedDeviceId)
    {
        # Check if this is a cached "not found" result (empty string sentinel)
        if ($cachedDeviceId -eq "")
        {
            Write-Verbose "[$functionName] Cached not-found result for serial: $SerialNumber"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached not-found result for serial: $SerialNumber" -LogLevel "Verbose"
            return $null
        }
        
        Write-Verbose "[$functionName] Found cached device ID for serial: $SerialNumber"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found cached device ID for serial: $SerialNumber" -LogLevel "Verbose"
        return $cachedDeviceId
    }
    
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
        
        # Cache the result using unified cache
        $cacheKey = "deviceid:$($SerialNumber.ToLower())"
        $metadata = @{
            SerialNumber = $SerialNumber
            DeviceType   = 'ManagedDevice'
            CachedAt     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        [void](Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data $device -Metadata $metadata -CacheSettings $global:cacheSettings)
        Write-Verbose "[$functionName] Cached device ID for serial: $SerialNumber using unified cache"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached device ID for serial: $SerialNumber using unified cache" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] Device with serial number $SerialNumber not found."
        # Cache empty string as sentinel for not-found devices to avoid repeated API calls
        $cacheKey = "deviceid:$($SerialNumber.ToLower())"
        [void](Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data "" -Metadata @{ SerialNumber = $SerialNumber; NotFound = $true } -CacheSettings $global:cacheSettings)
    }
    return $device
}

