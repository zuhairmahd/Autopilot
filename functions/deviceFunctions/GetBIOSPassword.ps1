function GetBIOSPassword()
{
    [CmdletBinding()]
    param (
        [string]$accessToken,
        [string]$serialNumber
    )
    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @()
    Write-Verbose "[$functionName] Starting BIOS password retrieval. Raw serial input: '$serialNumber'"
    write-log -logFile $LogFile -module $functionName -message "Starting BIOS password retrieval." -logLevel "Information"

    # Normalize and validate input
    $sn = ("$serialNumber").Trim()
    if (-not $sn)
    {
        Write-Verbose "[$functionName] Serial number is null or empty after normalization. Aborting."
        write-log -logFile $LogFile -module $functionName -message "Serial number is null or empty after normalization." -logLevel "Error"
        Write-Error "Serial number is required."
        return $null
    }
    Write-Verbose "[$functionName] Normalized serial number: '$sn'"
    write-log -logFile $LogFile -module $functionName -message "Normalized serial number: '$sn'" -logLevel "Information"

    # Prepare Graph query
    $deviceHardwareDetailsURI = "deviceManagement/hardwarePasswordDetails"
    $filter = "serialNumber eq '$Sn'"
    Write-Verbose "[$functionName] Graph URI: $deviceHardwareDetailsURI | Filter: $filter"
    write-log -logFile $LogFile -module $functionName -message "Querying Graph. URI=$deviceHardwareDetailsURI, Filter=$filter" -logLevel "Information"

    # Call Graph with timing and error handling
    $resp = $null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        $resp = (CallGraphAPI -ResourcePath $deviceHardwareDetailsURI -filter $filter -accessToken $accessToken).value
        $sw.Stop()
        Write-Verbose "[$functionName] Graph call completed in $($sw.ElapsedMilliseconds) ms."
        write-log -logFile $LogFile -module $functionName -message "Graph call completed in $($sw.ElapsedMilliseconds) ms." -logLevel "Information"
        Write-Verbose "[$functionName] Graph returned $($resp.count) records"
        Write-log -logFile $LogFile -module $functionName -message "Graph returned $($resp.count) records." -logLevel "Information"
        if ($resp -and $resp.count -gt 0)
        {
            foreach ($entry in $resp)
            {
                Write-Verbose "[$functionName] Processing entry: $($entry.id)"
                Write-Verbose "[$functionName] Current password: $($entry.currentPassword)"
                # Build previous passwords array (password property only)
                $previousPasswords = @()
                if ($entry.previousPasswords)
                {
                    Write-Verbose "[$functionName] Processing $($entry.previousPasswords.Count) previous passwords."
                    $previousPasswords = @($entry.previousPasswords | ForEach-Object {
                            Write-Verbose "[$functionName] Previous password: $_."
                            $_
                        })
                }
                # Append password object per entry
                $returnObject += @{
                    id                = $entry.id
                    currentPassword   = $entry.currentPassword
                    previousPasswords = $previousPasswords
                }
            }
        }
        else
        {
            Write-Verbose "[$functionName] No hardware password details found for serial '$sn'."
            write-log -logFile $LogFile -module $functionName -message "No hardware password details found for serial '$sn'." -logLevel "Information"
            return $null
        }
        return $returnObject
    }
    catch
    {
        $sw.Stop()
        Write-Verbose "[$functionName] Graph call failed after $($sw.ElapsedMilliseconds) ms: $($_.Exception.Message)"
        write-log -logFile $LogFile -module $functionName -message "Graph call failed: $($_.Exception.Message)" -logLevel "Error"
        Write-Error "Failed retrieving hardware password details for serial '$sn': $($_.Exception.Message)"
        return $null
    }
}

