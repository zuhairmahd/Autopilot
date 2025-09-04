function Get-NormalizedExpiryTime()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function execution"
    if (-not $accessTokenObject.AbsoluteExpiryTime)
    {
        Write-Verbose "[$functionName] No AbsoluteExpiryTime found in token object"
        write-log -logFile $logFile -moduleName $moduleName -logLevel Warning -message "No AbsoluteExpiryTime found in token object"
        return [datetime]::MinValue
    }
    
    try
    {
        if ($accessTokenObject.AbsoluteExpiryTime -is [string])
        {
            Write-Verbose "[$functionName] Converting string expiry time to datetime"
            write-log -logFile $logFile -moduleName $moduleName -logLevel Verbose -message "Converting string expiry time to datetime"
            $parsedTime = [datetime]::Parse($accessTokenObject.AbsoluteExpiryTime).ToLocalTime()
            write-log -logFile $logFile -moduleName $moduleName -logLevel Verbose -message "Parsed expiry time: $parsedTime"
            # Handle timezone differences
            if ($parsedTime -lt $accessTokenObject.AbsoluteExpiryTime)
            {
                Write-Verbose "[$functionName] Using original expiry time to resolve timezone differences"
                return $accessTokenObject.AbsoluteExpiryTime
            }
            return $parsedTime
        }
        elseif ($accessTokenObject.AbsoluteExpiryTime.kind -eq 'Utc')
        {
            Write-Verbose "[$functionName] Converting UTC expiry time to local time"
            return $accessTokenObject.AbsoluteExpiryTime.ToLocalTime()
        }
        else
        {
            Write-Verbose "[$functionName] Using datetime expiry time as-is"
            return $accessTokenObject.AbsoluteExpiryTime
        }
    }
    catch
    {
        Write-Warning "[$functionName] Failed to parse expiry time: $_"
        write-log -logFile $logFile -moduleName $moduleName -logLevel Error -message "Failed to parse expiry time: $_"
        return [datetime]::MinValue
    }
}

