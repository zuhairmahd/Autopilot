function ShowDeviceReport()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        [parameter(ParameterSetName = 'export')]
        [switch]$Export,
        [parameter(ParameterSetName = 'export')]
        [string]$OutputFile = "$pwd\DeviceReport.csv",
        [parameter(ParameterSetName = 'export')]
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV")]
        [string]$ExportFormat = "HTML"
    )
    #region write verbose log of received parameters
    Write-Verbose "Received parameters: $($enrollmentState | Out-String)"
    Write-Verbose "Export: $Export"
    Write-Verbose "ExportFormat: $ExportFormat"
    #endregion write verbose log of received parameters
    
    #region report content
    if ($enrollmentState.autopilot.events -and $enrollmentState.autopilot.events.Count -gt 0)
    {
        $latestAutopilotEvent = $enrollmentState.autopilot.events | Select-Object -First 1
    }
    else
    {
        $latestAutopilotEvent = $null
    }
    $output = [ordered] @{
        InputIdentifier          = $serialNumber
        FoundDeviceName          = $enrollmentState.managedDevice.device.deviceName
        FoundSerialNumber        = $enrollmentState.managedDevice.device.serialNumber
        IntuneManagedDeviceId    = $enrollmentState.managedDevice.device.Id
        IntuneEnrollmentDate     = $enrollmentState.managedDevice.device.enrolledDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
        IntuneLastSync           = $enrollmentState.managedDevice.device.lastSyncDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
        IntuneEnrollmentProfile  = $enrollmentState.managedDevice.device.enrollmentProfileName
        IntunePrimaryUserId      = $enrollmentState.managedDevice.device.userId # Note: Potential inconsistency
        IntunePrimaryUPN         = $enrollmentState.managedDevice.device.userPrincipalName # Note: Potential inconsistency
        IntuneActionResults      = $enrollmentState.managedDevice.device.deviceActionResults
        IntuneCertExpiration     = $enrollmentState.managedDevice.device.managementCertificateExpirationDate
        IntuneAutopilotEnrolled  = $enrollmentState.managedDevice.device.autopilotEnrolled
        IntuneUserDisplayName    = $enrollmentState.managedDevice.device.userDisplayName
        IntuneRegistrationState  = $enrollmentState.managedDevice.device.deviceRegistrationState
        IntuneComplianceExpiry   = $enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime
        IntuneIsEncrypted        = $enrollmentState.managedDevice.device.isEncrypted
        IntuneEnrollmentType     = $enrollmentState.managedDevice.device.deviceEnrollmentType
        IntuneSVersion           = $enrollmentState.managedDevice.device.sVersion
        IntuneComplianceState    = $enrollmentState.managedDevice.device.complianceState
        IntuneManagementState    = $enrollmentState.managedDevice.device.managementState
        IntuneOwnerType          = $enrollmentState.managedDevice.device.managedDeviceOwnerType
        AutopilotDeviceId        = $enrollmentState.autopilot.device.id
        AutopilotState           = $enrollmentState.autopilot.device.enrollmentState
        AutopilotAssignedUser    = $enrollmentState.autopilot.device.userPrincipalName
        AutopilotLastContacted   = $enrollmentState.autopilot.device.lastContactedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
        LatestAutopilotEventTime = $latestAutopilotEvent.eventDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
        LatestAutopilotProfile   = $latestAutopilotEvent.windowsAutopilotDeploymentProfileDisplayName
        LatestAutopilotStatus    = $latestAutopilotEvent.deploymentState
        LatestAutopilotError     = $latestAutopilotEvent.enrollmentFailureDetails
    }
    #endregion report content
    
    #region Format property names and display report
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($key in $output.Keys)
    {
        # Format the property name to be more readable
        $readableKey = $key
        
        # Handle common prefixes separately
        if ($key -match '^(Intune|Autopilot)(.+)$')
        {
            $prefix = $matches[1]
            $remainder = $matches[2]
            
            # Insert spaces before capital letters in the remainder
            $formattedRemainder = [regex]::Replace($remainder, '(?<=[a-z])(?=[A-Z])', ' ')
            $readableKey = "$prefix $formattedRemainder"
        }
        else
        {
            # Insert spaces before capital letters
            $readableKey = [regex]::Replace($key, '(?<=[a-z])(?=[A-Z])', ' ')
        }
        
        $formattedOutput[$readableKey] = $output[$key]
        
        # Print each property and value
        Write-Host "$readableKey`: $($output[$key])"
    }
    #endregion Format property names and display report

    #region export
    if (-not $Export)    
    {
        $choice = DisplayNumericMenu -Choices ('Export to HTML', 'Export to CSV') -Banner "Would you like to export the report?" -Prompt "Please select an option" -ErrorMessage "Invalid selection. Please try again."
        if ($choice -eq 'Export to HTML')
        {
            $Export = $true
            $ExportFormat = "HTML"
        }
        elseif ($choice -eq 'Export to CSV')
        {
            $Export = $true
            $ExportFormat = "CSV"
        }
        else
        {
            Write-Host "No export selected."
            return $null
        }
    }
    # Export the report if requested
    if ($Export)
    {
        $deviceName = $enrollmentState.managedDevice.device.deviceName
        if (-not $deviceName)
        {
            $deviceName = "Device"
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$deviceName`_Report_$timestamp"
        if ($ExportFormat -eq "HTML")
        {
            $htmlPath = "$pwd\$fileName.html"
            $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Device Report: $deviceName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Device Report: $deviceName</h1>
    <p>Generated on $(Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")</p>
    <table>
        <tr>
            <th>Property</th>
            <th>Value</th>
        </tr>
"@

            $htmlRows = ""
            foreach ($key in $formattedOutput.Keys)
            {
                $value = $formattedOutput[$key]
                $htmlRows += "<tr><td>$key</td><td>$value</td></tr>`n"
            }

            $htmlFooter = @"
    </table>
</body>
</html>
"@

            $htmlHeader + $htmlRows + $htmlFooter | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Host "HTML report exported to: $htmlPath"
        }
        elseif ($ExportFormat -eq "CSV")
        {
            $csvPath = "$pwd\$fileName.csv"
            
            $csvData = foreach ($key in $formattedOutput.Keys)
            {
                [PSCustomObject]@{
                    Property = $key
                    Value    = $formattedOutput[$key]
                }
            }
            
            $csvData | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "CSV report exported to: $csvPath"
        }
    }
    #endregion export
}
