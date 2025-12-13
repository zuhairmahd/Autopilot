function Export-AgingDeviceReport()
{
    <#
    .SYNOPSIS
        Exports a report of aging devices in the environment.

    .DESCRIPTION
        This function generates a report of devices that have not checked in for a specified number of days and exports the report to a CSV file.

    .PARAMETER DaysThreshold
        The number of days to consider a device as aging. Default is 30 days.

    .PARAMETER OutputPath
        The file path where the report will be saved. Default is "AgingDeviceReport.csv".

    .EXAMPLE
        Export-AgingDeviceReport -DaysThreshold 60 -OutputPath "C:\Reports\AgingDevices.csv"

        Exports a report of devices that have not checked in for 60 days to the specified path.

    .NOTES
    #>
    [CmdletBinding()    ]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$outputPath,
        [ValidateSet('Append', 'Overwrite')]
        [string]$fileMode = 'overwrite',
        [switch]$RefreshCache,
        [int]$CacheExpirationMinutes = 15
    )

    #region Define variables.
    $functionName = $MyInvocation.MyCommand
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = "$outputPath\$reportType-DeviceList-$currentDateTime.csv"
    $CSVObject = [System.Collections.ArrayList]@()
    $returnObject = @{
        OutputFile  = $outputFile
        deviceCount = $null
        success     = $false
        message     = ''
    }
    #endregion

    Write-Verbose "[$functionName] Starting function"
    write-log -logFile $logFile -module $functionName -message "Starting function"
    $managedDevices = Get-DeviceData -AccessToken $accessToken -DeviceType 'managed' -RefreshCache:$RefreshCache -CacheExpirationMinutes $CacheExpirationMinutes
    #region Fetch device data using Get-DeviceData
    $managedDevices = Get-DeviceData -AccessToken $accessToken -DeviceType 'managed' -RefreshCache:$RefreshCache -CacheExpirationMinutes $CacheExpirationMinutes
    # Diagnostic logging - check what we actually received
    if ($null -eq $autopilotDevices -or $null -eq $autopilotDevices.value)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "WARNING: No autopilot devices retrieved from API!" -LogLevel "Warning"
        Write-Verbose "[    $functionName] WARNING: No autopilot devices retrieved!"
    }
    if ($null -eq $managedDevices -or $null -eq $managedDevices.value)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "WARNING: No managed devices retrieved from API!" -LogLevel "Warning"
        Write-Verbose "[    $functionName] WARNING: No managed devices retrieved!"
    }
    #endregion

    #export the csv object.
    try
    {
        # Validate that we have data to export
        if ($null -eq $CSVObject -or $CSVObject.Count -eq 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found matching report type '$reportType'. Generated empty report." -LogLevel "Warning"
            Write-Verbose "[    $functionName] No devices found matching report type '$reportType'."
            $returnObject.message = "No devices found matching report type '$reportType'."

            # Create empty file with headers for consistency
            $emptyObject = [PSCustomObject]@{
                SerialNumber         = ''
                GroupTag             = ''
                DeviceName           = ''
                Manufacturer         = ''
                Model                = ''
                SystemFamily         = ''
                OSVersion            = ''
                EnrollmentState      = ''
                DeviceEnrollmentType = ''
                AzureADRegistered    = ''
                EnrolledDateTime     = ''
                LastSyncDateTime     = ''
                ComplianceState      = ''
                OwnerType            = ''
                UserPrincipalName    = ''
                UserDisplayName      = ''
                UserId               = ''
            }
            $emptyObject | Export-Csv -Path $outputFile -NoTypeInformation
            $returnObject.success = $true
        }

        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting $($CSVObject.Count) devices to report." -LogLevel "Information"
        Write-Verbose "[    $functionName] Exporting $($CSVObject.Count) devices to report."
        if ($fileMode -eq 'Append' -and (Test-Path -Path $outputFile))
        {
            $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append
        }
        else
        {
            $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assignment report exported to $outputFile ($($CSVObject.Count) devices)" -LogLevel "Information"
        Write-Verbose "[    $functionName] Device assignment report exported to $outputFile ($($CSVObject.Count) devices)"
        $returnObject.success = $true
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to export device assignment report to $outputFile. Error: $_" -LogLevel "Error"
        Write-Verbose "[    $functionName] Failed to export device assignment report to $outputFile. Error: $_"
        $returnObject.success = $false
    }

    Write-Verbose "[    $functionName] Export-DeviceAssignmentReport completed successfully. Returning $returnObject."
    return $returnObject
}