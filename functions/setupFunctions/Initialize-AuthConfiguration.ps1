function Initialize-AuthConfiguration()
{
    <#
    .SYNOPSIS
        Processes auth configuration from settings file.
    #>
    [CmdletBinding()]
    param(
        $AuthConfiguration,
        [hashtable]$BoundParameters
    )
    $functionName = $MyInvocation.MyCommand.Name
    $auth = @{}
    Write-Verbose "[$functionName] Received auth configuration object of type: $($AuthConfiguration.GetType().Name)"
    if ($null -eq $AuthConfiguration)
    {
        Write-Verbose "[$functionName] No auth configuration found, using defaults"
        return @{ Auth = $auth }
    }
    
    Write-Verbose "[$functionName] Processing auth configuration"
    
    # Batch processing counters for performance optimization
    $authProcessedCount = 0
    $authBooleanCount = 0
    $authOverrideCount = 0
    
    foreach ($key in $AuthConfiguration.keys)
    {
        # Conditional verbose logging - only log individual settings when explicit verbose is used
        if ($VerbosePreference -eq 'Continue')
        {
            Write-Verbose "[$functionName] Processing auth key: $key"
        }
        
        if ($BoundParameters.ContainsKey($key) -eq $false -and $null -ne $AuthConfiguration.$key)
        {
            if ($AuthConfiguration.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($AuthConfiguration.$key)
                $auth.add($key, $keyBooleanValue)
                if ($VerbosePreference -eq 'Continue')
                {
                    Write-Verbose "[$functionName] Set $key to boolean value: $keyBooleanValue"
                }
                $authBooleanCount++
            }
            else
            {
                $auth.add($key, $AuthConfiguration.$key)
                if ($VerbosePreference -eq 'Continue')
                {
                    Write-Verbose "[$functionName] Set $key to string value: $($AuthConfiguration.$key)"
                }
            }
            $authProcessedCount++
        }
        elseif ($BoundParameters.ContainsKey($key))
        {
            $auth.add($key, $BoundParameters[$key])
            if ($VerbosePreference -eq 'Continue')
            {
                Write-Verbose "[$functionName] Used command-line parameter for $key`: $($BoundParameters[$key])"
            }
            $authOverrideCount++
        }
    }
    
    # Batch summary logging for performance optimization
    Write-Verbose "[$functionName] Completed processing $authProcessedCount auth settings ($authBooleanCount boolean, $authOverrideCount overrides)"
    
    return @{ Auth = $auth }
}
