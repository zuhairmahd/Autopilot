function DisplayReport()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$report,
        [string[]]$PrefixList,
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
    Write-Verbose "Export: $Export"
    Write-Verbose "ExportFormat: $ExportFormat"
    Write-Verbose "OutputFile: $OutputFile"
    Write-Verbose "Prefix list: $PrefixList"
    #endregion write verbose log of received parameters
    
    #region Format property names and display report
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($key in $output.Keys)
    {
        # Format the property name to be more readable
        $readableKey = $key
        # Handle common prefixes separately
        $matchedPrefix = $null
        foreach ($prefix in $PrefixList)
        {
            if ($key -match "^($prefix)(.+)$")
            {
                $matchedPrefix = $prefix
                break
            }
        }
        if ($matchedPrefix) 
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
        #if the value is a date, pipe it to the FormatDateWithTimeZone function.
        if ($output[$key] -is [DateTime])
        {
            $formattedOutput[$readableKey] = FormatDateWithTimeZone -DateTime $output[$key]
        }
        else
        {
            $formattedOutput[$readableKey] = $output[$key]
        }
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
