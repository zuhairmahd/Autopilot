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
    
    # Initialize device cache if it doesn't exist
    if (-not $global:DeviceIdCache)
    {
        $global:DeviceIdCache = @{}
        Write-Verbose "[$functionName] Initialized device ID cache"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initialized device ID cache" -LogLevel "Verbose"
    }
    
    # Check cache first
    if ($global:DeviceIdCache.ContainsKey($SerialNumber))
    {
        Write-Verbose "[$functionName] Found cached device ID for serial: $SerialNumber"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found cached device ID for serial: $SerialNumber" -LogLevel "Verbose"
        return $global:DeviceIdCache[$SerialNumber]
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
        
        # Cache the result
        $global:DeviceIdCache[$SerialNumber] = $device
        Write-Verbose "[$functionName] Cached device ID for serial: $SerialNumber"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cached device ID for serial: $SerialNumber" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] Device with serial number $SerialNumber not found."
        # Cache null result to avoid repeated API calls for non-existent devices
        $global:DeviceIdCache[$SerialNumber] = $null
    }
    return $device
}

