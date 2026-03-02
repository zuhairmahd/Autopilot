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

    if ($null -eq $AuthConfiguration)
    {
        Write-Verbose "[$functionName] No auth configuration found, using defaults"
        Write-Log -logFile $logFile -Module $functionName -Message "No auth configuration found, using defaults"
        return @{ Auth = $auth }
    }

    Write-Verbose "[$functionName] Received auth configuration object of type: $($AuthConfiguration.GetType().Name)"
    Write-Log -logFile $logFile -Module $functionName -Message "Received auth configuration object of type: $($AuthConfiguration.GetType().Name)"

    Write-Verbose "[$functionName] Processing auth configuration"
    Write-Log -logFile $logFile -Module $functionName -Message "Processing auth configuration"

    # Batch processing counters for performance optimization
    $authProcessedCount = 0
    $authBooleanCount = 0
    $authOverrideCount = 0

    foreach ($key in $AuthConfiguration.keys)
    {
        Write-Verbose "[$functionName] Processing auth key: $key"
        Write-Log -logFile $logFile -Module $functionName -Message "Processing auth key: $key"
        if ($BoundParameters.ContainsKey($key) -eq $false -and $null -ne $AuthConfiguration.$key)
        {
            if ($AuthConfiguration.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($AuthConfiguration.$key)
                $auth.add($key, $keyBooleanValue)
                Write-Verbose "[$functionName] Set $key to boolean value: $keyBooleanValue"
                Write-Log -logFile $logFile -Module $functionName -Message "Set $key to boolean value: $keyBooleanValue"
                $authBooleanCount++
            }
            else
            {
                $auth.add($key, $AuthConfiguration.$key)
                Write-Verbose "[$functionName] Set $key to string value: $($AuthConfiguration.$key)"
                Write-Log -logFile $logFile -Module $functionName -Message "Set $key to string value: $($AuthConfiguration.$key)"
            }
            $authProcessedCount++
        }
        elseif ($BoundParameters.ContainsKey($key))
        {
            $auth.add($key, $BoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line parameter for $key`: $($BoundParameters[$key])"
            Write-Log -logFile $logFile -Module $functionName -Message "Used command-line parameter for $key`: $($BoundParameters[$key])"
            $authOverrideCount++
        }
    }

    # Process BoundParameters that aren't in the config file
    foreach ($key in $BoundParameters.Keys)
    {
        if (-not $auth.ContainsKey($key))
        {
            $auth.add($key, $BoundParameters[$key])
            Write-Verbose "[$functionName] Added command-line parameter for $key (not in config file): $($BoundParameters[$key])"
            Write-Log -logFile $logFile -Module $functionName -Message "Added command-line parameter for $key (not in config file): $($BoundParameters[$key])"
            $authOverrideCount++
        }
    }

    # Batch summary logging for performance optimization
    Write-Verbose "[$functionName] Completed processing $authProcessedCount auth settings ($authBooleanCount boolean, $authOverrideCount overrides)"
    Write-Log -logFile $logFile -Module $functionName -Message "Completed processing $authProcessedCount auth settings ($authBooleanCount boolean, $authOverrideCount overrides)"

    # Check against defaults and merge missing keys after filtering psbound parameters.
    $changesMade = $false
    try
    {
        #get auth defaults.
        $defaultAuthSettings = Get-ApplicationDefaults -DefaultType "Auth"
        if ($defaultAuthSettings)
        {
            # Filter out keys that are already set via command-line parameters
            $filteredAuth = @{}
            foreach ($key in $auth.Keys)
            {
                if ($BoundParameters.ContainsKey($key) -eq $false)
                {
                    $filteredAuth[$key] = $auth[$key]
                }
            }
            Write-Verbose "[$functionName] Checking $($filteredAuth.Count) filtered auth settings against defaults"
            Write-Log -logFile $logFile -Module $functionName -Message "Checking $($filteredAuth.Count) filtered auth settings against defaults"
            if ($filteredAuth.Count -gt 0)
            {
                $mergedAuthSettings = Merge-ConfigurationDefaults -ExistingConfig $filteredAuth -DefaultConfig $defaultAuthSettings -PreserveExisting $true
                if ($mergedAuthSettings)
                {
                    Write-Log -logFile $logFile -Module $functionName -Message "Merged missing keys into auth settings"
                    Write-Verbose "[$functionName] Merged missing keys into auth settings"

                    # Re-add command-line parameters to merged config
                    foreach ($key in $BoundParameters.Keys)
                    {
                        $mergedAuthSettings[$key] = $BoundParameters[$key]
                    }
                    $auth = $mergedAuthSettings
                    $changesMade = $true
                }
                else
                {
                    Write-Verbose "[$functionName] No missing keys to merge into auth settings"
                    Write-Log -logFile $logFile -Module $functionName -Message "No missing keys to merge into auth settings"
                }
            }
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error during auth settings merge: $($_.Exception.Message)"
        Write-Log -logFile $logFile -Module $functionName -Message "Error during auth settings merge: $($_.Exception.Message)"
    }
    return @{ Auth = $auth; Changed = $changesMade }
}