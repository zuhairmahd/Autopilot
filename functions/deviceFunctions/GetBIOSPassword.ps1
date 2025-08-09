function GetBIOSPassword
{
    [CmdletBinding()]
    param (
        [string]$serialNumber
    )
    $functionName = $MyInvocation.MyCommand.Name
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
    $escapedSn = $sn.Replace("'", "''")
    $filter = "serialNumber eq '$escapedSn'"
    Write-Verbose "[$functionName] Graph URI: $deviceHardwareDetailsURI | Filter: $filter"
    write-log -logFile $LogFile -module $functionName -message "Querying Graph. URI=$deviceHardwareDetailsURI, Filter=$filter" -logLevel "Information"

    # Call Graph with timing and error handling
    $resp = $null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        $resp = Get-GraphData -uri $deviceHardwareDetailsURI -filter $filter -ErrorAction Stop
        $sw.Stop()
        Write-Verbose "[$functionName] Graph call completed in $($sw.ElapsedMilliseconds) ms."
        write-log -logFile $LogFile -module $functionName -message "Graph call completed in $($sw.ElapsedMilliseconds) ms." -logLevel "Information"
    }
    catch
    {
        $sw.Stop()
        Write-Verbose "[$functionName] Graph call failed after $($sw.ElapsedMilliseconds) ms: $($_.Exception.Message)"
        write-log -logFile $LogFile -module $functionName -message "Graph call failed: $($_.Exception.Message)" -logLevel "Error"
        Write-Error "Failed retrieving hardware password details for serial '$sn': $($_.Exception.Message)"
        return $null
    }

    # Maintain global for backward compatibility while using local variable for logic
    $global:hardwarePasswordDetails = $resp

    # Extract items from response
    $items = if ($resp -and $resp.PSObject.Properties.Match('value').Count -gt 0)
    {
        $resp.value 
    }
    else
    {
        $resp 
    }
    $totalItems = @($items).Count
    Write-Verbose "[$functionName] Retrieved $totalItems hardware password detail record(s)."
    write-log -logFile $LogFile -module $functionName -message "Retrieved $totalItems hardware password detail record(s)." -logLevel "Information"

    if (-not $items -or $totalItems -eq 0)
    {
        Write-Verbose "[$functionName] No hardware password details returned for serial '$sn'."
        write-log -logFile $LogFile -module $functionName -message "No hardware password details found for serial '$sn'." -logLevel "Warning"
        Write-Error "No hardware password details found for serial number: $sn"
        return $null
    }

    # Filter for BIOS password
    $biosEntries = @($items | Where-Object { $_.passwordType -eq 'BIOS' })
    $biosCount = $biosEntries.Count
    Write-Verbose "[$functionName] BIOS entry count: $biosCount"
    write-log -logFile $LogFile -module $functionName -message "BIOS entry count: $biosCount" -logLevel "Information"

    if ($biosCount -gt 1)
    {
        Write-Verbose "[$functionName] Multiple BIOS password entries found; using the first entry."
        write-log -logFile $LogFile -module $functionName -message "Multiple BIOS password entries found; using the first entry." -logLevel "Warning"
    }

    if ($biosCount -ge 1)
    {
        $pw = $biosEntries[0].password
        if ($pw)
        {
            $masked = ('*' * [Math]::Min($pw.Length, 8))
            Write-Verbose "[$functionName] BIOS password located; masked preview: $masked (length: $($pw.Length))"
            write-log -logFile $LogFile -module $functionName -message "BIOS password located; returning value (not logged)." -logLevel "Information"
            return $pw
        }
        else
        {
            Write-Verbose "[$functionName] BIOS entry found but 'password' property is empty."
            write-log -logFile $LogFile -module $functionName -message "BIOS entry found but 'password' is empty." -logLevel "Warning"
            Write-Error "BIOS password is empty for serial number: $sn"
            return $null
        }
    }
    else
    {
        Write-Verbose "[$functionName] No BIOS password entry found in returned records."
        write-log -logFile $LogFile -module $functionName -message "No BIOS password entry found for serial '$sn'." -logLevel "Warning"
        Write-Error "No BIOS password found for serial number: $sn"
        return $null
    }
}