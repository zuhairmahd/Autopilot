function ExportDeviceReport()
{
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

    $functionName = "ExportDeviceReport"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting export with parameters: output file='$outputFile', ExportFormat='$ExportFormat'" -LogLevel "Verbose"
    # Validate ExportFormat
    if ($ExportFormat -notin @("HTML", "CSV"))
    {
        Write-Error "[$functionName] Invalid ExportFormat specified: $ExportFormat. Valid options are 'HTML' or 'CSV'."
        return $false
    }
    
    # Determine device name for file naming
    if (-not $outputFile -or $null -eq $outputFile)
    {
        if (-not $DeviceName)
        {
            $DeviceName = "Device"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using default device name for export" -LogLevel "Information"
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
    
    # Determine final export format
    $finalExportFormat = $ExportFormat.ToUpper()
    if ($finalExportFormat -eq "HTML")
    {
        if ($outputFile)
        {
            $htmlPath = $outputFile
        }
        else
        {
            $htmlPath = "$pwd\$fileName.html"
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting to HTML: $htmlPath" -LogLevel "Information"
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
            $value = [System.Web.HttpUtility]::HtmlEncode($formattedOutput[$key])
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
            Write-Host "HTML report exported to: $htmlPath" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully exported HTML report to $htmlPath" -LogLevel "Information"
        }
        catch
        {
            Write-Error "[$functionName] Failed to export HTML report: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "HTML export error details: $($_.Exception)" -LogLevel "Error"
            return $false
        }
    }
    elseif ($finalExportFormat -eq "CSV")
    {
        if ($outputFile)
        {
            $csvPath = $outputFile
        }
        else
        {
            $csvPath = "$pwd\$fileName.csv"
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting to CSV: $csvPath" -LogLevel "Information"
        try
        {
            $csvData = foreach ($key in $formattedOutput.Keys)
            {
                [PSCustomObject]@{
                    Property = $key
                    Value    = $formattedOutput[$key]
                }
            }
            $null = $csvData | Export-AutopilotCsv -Path $csvPath -NoTypeInformation
            Write-Host "CSV report exported to: $csvPath" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Successfully exported CSV report to $csvPath" -LogLevel "Information"
        }
        catch
        {
            Write-Error "[$functionName] Failed to export CSV report: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "CSV export error details: $($_.Exception)" -LogLevel "Error"
            return $false
        }
    }
    else
    {
        Write-Error "[$functionName] Unsupported export format: $finalExportFormat"
        return $false
    }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Export completed successfully." -LogLevel "Information"
    return $true
}


