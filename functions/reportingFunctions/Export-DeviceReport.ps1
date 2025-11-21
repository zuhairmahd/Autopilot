function Export-DeviceReport()
{
    <#
    .SYNOPSIS
    Exports comprehensive device report with detailed properties and state information.

    .DESCRIPTION
    This function generates a detailed report for devices including hardware information,
    compliance state, enrollment status, and management properties. Exports to CSV with
    configurable property selection.

    .PARAMETER accessToken
    Microsoft Graph API access token. This parameter is mandatory.

    .PARAMETER outputPath
    Directory path for report export. This parameter is mandatory.

    .PARAMETER deviceList
    Optional pre-filtered device list to export.

    .OUTPUTS
    System.String
    Returns path to exported report file.

    .EXAMPLE
    Export-DeviceReport -accessToken $token -outputPath "C:\Reports"

    .NOTES
    Comprehensive device report with extended properties.
    Includes compliance, enrollment, and hardware details.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$formattedOutput,
        [Parameter(Mandatory = $false)]
        [string]$outputFile,
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV")]
        [string]$ExportFormat = "HTML"
    )

    $functionName = "Export-DeviceReport"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting export with parameters: output file='$outputFile', ExportFormat='$ExportFormat'" -LogLevel "Verbose"
    $returnObject = @{
        success      = $false
        ExportFormat = $ExportFormat
        FileName     = $outputFile
        message      = ""
    }
    
    # Validate ExportFormat
    if ($ExportFormat -notin @("HTML", "CSV"))
    {
        $returnObject.message = "Invalid ExportFormat specified: $ExportFormat. Valid options are 'HTML' or 'CSV'."
        write-log -logFile $LogFile -Module "$functionName" -Message $returnObject.message -LogLevel "Error"
        return $returnObject
    }
    
    # Determine device name for file naming
    if (-not $outputFile -or $null -eq $outputFile)
    {
        write-log -logFile $LogFile -Module "$functionName" -Message "No output file specified, generating filename based on device name." -LogLevel "Information"
        if (-not $DeviceName)
        {
            $DeviceName = "Device"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using default device name ($DeviceName) for export" -LogLevel "Information"
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$DeviceName`_Report_$timestamp"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Generated filename: $fileName" -LogLevel "Information"
    }
    else
    {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($outputFile)
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using provided output file name: $fileName" -LogLevel "Information"
    }
    $returnObject.FileName = $fileName
    
    # Determine final export format
    $finalExportFormat = $ExportFormat.ToUpper()
    if ($finalExportFormat -eq "HTML")
    {
        $returnObject.ExportFormat = "HTML"
        write-log -logFile $LogFile -Module "$functionName" -Message "Preparing to export report in HTML format." -LogLevel "Information"
        if ($outputFile)
        {
            $htmlPath = $outputFile
            write-log -logFile $LogFile -Module "$functionName" -Message "Using specified output file path for HTML: $htmlPath" -LogLevel "Information"
        }
        else
        {
            $htmlPath = "$pwd\$fileName.html"
            write-log -logFile $LogFile -Module "$functionName" -Message "No output file specified, using default path for HTML: $htmlPath" -LogLevel "Information" 
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting to HTML: $htmlPath" -LogLevel "Information"
        $returnObject.outputFile = $htmlPath    
        $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Device Report: $DeviceName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        h1 { color: #333; }
        .meta { color: #666; font-style: italic; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Device Report: $DeviceName</h1>
    <div class="meta">Generated on $(Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")</div>
    <table>
        <thead>
            <tr>
                <th>Property</th>
                <th>Value</th>
            </tr>
        </thead>
        <tbody>
"@
        $htmlRows = ""
        foreach ($key in $formattedOutput.Keys)
        {
            write-log -logFile $LogFile -Module "$functionName" -Message "Adding HTML row for property: $key" -LogLevel "Verbose"
            $value = [System.Web.HttpUtility]::HtmlEncode($formattedOutput[$key])
            write-log -logFile $LogFile -Module "$functionName" -Message "Encoded value for property '$key': $value" -LogLevel "Verbose"
            $htmlRows += "            <tr><td>$([System.Web.HttpUtility]::HtmlEncode($key))</td><td>$value</td></tr>`n"
        }
        $htmlFooter = @"
        </tbody>
    </table>
</body>
</html>
"@
        try
        {
            $htmlContent = $htmlHeader + $htmlRows + $htmlFooter
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully exported HTML report to $htmlPath" -LogLevel "Information"
            $returnObject.message = "HTML report exported to: $htmlPath"        
            $returnObject.success = $true
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to export HTML report: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "HTML export error details: $($_.Exception)" -LogLevel "Error"
            $returnObject.message = "Failed to export HTML report: $($_.Exception.Message)"     
        }
    }
    elseif ($finalExportFormat -eq "CSV")
    {
        $returnObject.ExportFormat = "CSV"
        write-log -logFile $LogFile -Module "$functionName" -Message "Preparing to export report in CSV format." -LogLevel "Information"
        if ($outputFile)
        {
            write-log -logFile $LogFile -Module "$functionName" -Message "Using specified output file path for CSV: $csvPath" -LogLevel "Information"       
            $csvPath = $outputFile
        }
        else
        {
            write-log -logFile $LogFile -Module "$functionName" -Message "No output file specified, using default path for CSV." -LogLevel "Information"    
            $csvPath = "$pwd\$fileName.csv"
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting to CSV: $csvPath" -LogLevel "Information"
        $returnObject.outputFile = $csvPath
        try
        {
            $csvData = foreach ($key in $formattedOutput.Keys)
            {
                [PSCustomObject]@{
                    Property = $key
                    Value    = $formattedOutput[$key]
                }
            }
            $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Verbose "[$functionName] CSV report exported to: $csvPath"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully exported CSV report to $csvPath" -LogLevel "Information"
            $returnObject.success = $true
            $returnObject.message = "CSV report exported to: $csvPath"      
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to export CSV report: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "CSV export error details: $($_.Exception)" -LogLevel "Error"
            $returnObject.message = "Failed to export CSV report: $($_.Exception.Message)"          
        }
    }
    else
    {
        Write-Verbose "[$functionName] Unsupported export format: $finalExportFormat"
        Write-Log -logFile $LogFile -Module "$functionName" -Message "Unsupported export format specified: $finalExportFormat" -LogLevel "Error"                        
        $returnObject.message = "Unsupported export format specified: $finalExportFormat"       
    }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Export completed successfully." -LogLevel "Information"
    return $returnObject
}


