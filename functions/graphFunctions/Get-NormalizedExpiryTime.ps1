function Get-NormalizedExpiryTime()
{
    <#
    .SYNOPSIS
    Normalizes and converts token expiry time to a consistent datetime format.

    .DESCRIPTION
    This function processes the AbsoluteExpiryTime property from an access token object and
    converts it to a normalized datetime format in local time. It handles various input formats
    including string representations, UTC timestamps, and local time values. If parsing fails
    or no expiry time is present, it returns DateTime.MinValue.

    .PARAMETER accessTokenObject
    The access token object containing an AbsoluteExpiryTime property.

    .OUTPUTS
    System.DateTime
    Returns the normalized expiry time in local time zone, or DateTime.MinValue if not available.

    .EXAMPLE
    $expiryTime = Get-NormalizedExpiryTime -accessTokenObject $tokenObj

    .NOTES
    Handles timezone conversions and string parsing automatically.
    Returns DateTime.MinValue for invalid or missing expiry times.
    Compatible with PowerShell 5.1.
    #>
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

