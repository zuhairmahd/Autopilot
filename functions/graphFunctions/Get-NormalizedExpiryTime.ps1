function Get-NormalizedExpiryTime()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $accessTokenObject.AbsoluteExpiryTime)
    {
        Write-Verbose "[$functionName] No AbsoluteExpiryTime found in token object"
        return [datetime]::MinValue
    }
    
    try
    {
        if ($accessTokenObject.AbsoluteExpiryTime -is [string])
        {
            Write-Verbose "[$functionName] Converting string expiry time to datetime"
            $parsedTime = [datetime]::Parse($accessTokenObject.AbsoluteExpiryTime).ToLocalTime()
            
            # Handle timezone differences
            if ($parsedTime -lt $accessTokenObject.AbsoluteExpiryTime)
            {
                Write-Verbose "[$functionName] Using original expiry time to resolve timezone differences"
                return $accessTokenObject.AbsoluteExpiryTime
            }
            return $parsedTime
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
        return [datetime]::MinValue
    }
}

