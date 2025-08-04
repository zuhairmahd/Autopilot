function Test-CachedTokenValidity()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject,
        [datetime]$timeBuffer,
        [string]$domain,
        [string]$cacheType
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $accessTokenObject.access_token)
    {
        Write-Verbose "[$functionName] No access token in cached object"
        return $null
    }
    
    # Handle different time formats for expiry time
    $absoluteExpiryTime = Get-NormalizedExpiryTime -accessTokenObject $accessTokenObject
    
    if ($absoluteExpiryTime -gt $timeBuffer)
    {
        Write-Verbose "[$functionName] Access token for $domain is valid until $absoluteExpiryTime"
        Write-Verbose "[$functionName] Using cached access token from $cacheType cache"
        [console]::beep(200, 200)
        return $accessTokenObject.access_token
    }
    else
    {
        Write-Verbose "[$functionName] Access token for $domain is expired or invalid"
        Write-Verbose "[$functionName] Absolute expiry time: $absoluteExpiryTime, Time buffer: $timeBuffer"
        Write-Verbose "[$functionName] Will attempt to refresh token"
        Write-Log -LogFile $logFile -Module "$functionName" -Message "Access token in $cacheType cache is expired or invalid (expires: $absoluteExpiryTime, buffer: $timeBuffer)" -LogLevel "Warning"
        return $null
    }
}

