function GetBitLockerRecoveryKey()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        $key,
        [parameter(Mandatory = $true)]
        [string]$accessToken
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving BitLocker recovery key for key ID: $($key.id)"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access Token provided."
    }
    $volumeTypes = @{
        "0" = "Unknown"
        "1" = "OperatingSystem"
        "2" = "FixedData"
        "3" = "RemovableData"
    }
    # Define the resource path for BitLocker recovery keys
    $bitLockerUri = "informationProtection/bitlocker/recoveryKeys/$($key.id)"
    $bitlockerExtraParameters = "select=key"
    Write-Verbose "[$functionName] Retrieving actual BitLocker recovery key..."
    Write-Verbose "[$functionName] BitLocker URI: $bitLockerUri"
    Write-Verbose "[$functionName] Extra parameters for BitLocker API call: $bitlockerExtraParameters"
    # Call the Graph API to get BitLocker recovery keys
    try
    {
        $recoveryKeyDetails = CallGraphApi -accessToken $accessToken -ResourcePath $bitLockerUri -extraParameters $bitlockerExtraParameters
        # Display the recovery key information
        Write-Host "Latest BitLocker recovery key:" -ForegroundColor Cyan
        Write-Host "Key: $($recoveryKeyDetails.key)" -ForegroundColor Yellow
        Write-Host "Created: $($key.createdDateTime |FormatDateWithTimeZone)" -ForegroundColor Yellow
        Write-Host "Volume Type: $($volumeTypes[$key.volumeType])" -ForegroundColor Yellow
        return $recoveryKeyDetails.key
    }
    catch
    {
        Write-Error "[$scriptName] Failed to retrieve BitLocker recovery key: $($_.Exception.Message)"
        Write-Host "Key metadata available:" -ForegroundColor Yellow
        Write-Host "Created: $($latestKeyInfo.createdDateTime |FormatDateWithTimeZone)" 
        Write-Host "Volume Type: $($volumeTypes[$latestKeyInfo.volumeType])" 
        Write-Host "Device ID: $($latestKeyInfo.deviceId)" 
        Write-Host "Key ID: $($latestKeyInfo.id)" -ForegroundColor Yellow
    }
    return "`n"
}


