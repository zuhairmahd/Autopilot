function Export-AutopilotCsv()
{
    <#
    .SYNOPSIS
        High-performance CSV export with automatic C#/PowerShell fallback.
    
    .DESCRIPTION
        Exports hashtable collections to CSV using Autopilot.CsvCore.dll when available (5-10x faster).
        Automatically falls back to PowerShell Export-Csv if DLL unavailable.
    
    .PARAMETER Data
        Collection of hashtables or PSCustomObjects to export.
    
    .PARAMETER Path
        Target CSV file path.
    
    .PARAMETER Append
        If true, appends to existing file.
    
    .PARAMETER NoTypeInformation
        If true, omits #TYPE header line (PowerShell compatibility).
    
    .OUTPUTS
        System.Boolean
        Returns $true if export succeeded, $false otherwise.
    
    .EXAMPLE
        Export-AutopilotCsv -Data $devices -Path "devices.csv"
        
    .EXAMPLE
        Export-AutopilotCsv -Data $apps -Path "apps.csv" -Append
    
    .NOTES
        Uses CsvCore.dll for 5-10x speedup when available.
        Falls back to Export-Csv automatically.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Data,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$Append,
        [switch]$NoTypeInformation
    )
    
    begin
    {
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Starting CSV export to: $Path"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Starting CSV export to: $Path (Append: $Append)" -LogLevel "Verbose"
        
        $collectedData = [System.Collections.ArrayList]@()
    }
    
    process
    {
        # Collect pipeline input
        foreach ($item in $Data)
        {
            $null = $collectedData.Add($item)
        }
    }
    
    end
    {
        if ($collectedData.Count -eq 0)
        {
            Write-Warning "[$functionName] No data to export"
            Write-Log -LogFile $LogFile -Module $functionName -Message "No data to export" -LogLevel "Warning"
            return $false
        }
        
        Write-Verbose "[$functionName] Exporting $($collectedData.Count) rows"
        
        # Try CsvCore for 5-10x faster export
        $useCsvCore = $global:AutopilotDllStatus -and $global:AutopilotDllStatus.CsvCoreLoaded
        
        if ($useCsvCore)
        {
            try
            {
                Write-Verbose "[$functionName] Using CsvCore for high-performance export (5-10x faster)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using CsvCore for optimized CSV export" -LogLevel "Verbose"
                
                $includeTypeInfo = -not $NoTypeInformation.IsPresent
                $rowsWritten = [Autopilot.CsvCore.CsvWriter]::ExportToCsv($collectedData, $Path, $Append.IsPresent, $includeTypeInfo)
                
                Write-Verbose "[$functionName] CsvCore exported $rowsWritten rows successfully"
                Write-Log -LogFile $LogFile -Module $functionName -Message "CsvCore exported $rowsWritten rows to $Path" -LogLevel "Information"
                return $true
            }
            catch
            {
                Write-Warning "[$functionName] CsvCore export failed, falling back to PowerShell: $_"
                Write-Log -LogFile $LogFile -Module $functionName -Message "CsvCore failed, using PowerShell fallback: $($_.Exception.Message)" -LogLevel "Warning"
                $useCsvCore = $false
            }
        }
        
        # PowerShell fallback
        if (-not $useCsvCore)
        {
            try
            {
                Write-Verbose "[$functionName] Using PowerShell Export-Csv"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using PowerShell Export-Csv fallback" -LogLevel "Verbose"
                
                if ($Append.IsPresent)
                {
                    $collectedData | Export-Csv -Path $Path -NoTypeInformation:$NoTypeInformation.IsPresent -Append -Force
                }
                else
                {
                    $collectedData | Export-Csv -Path $Path -NoTypeInformation:$NoTypeInformation.IsPresent -Force
                }
                
                Write-Verbose "[$functionName] PowerShell exported $($collectedData.Count) rows successfully"
                Write-Log -LogFile $LogFile -Module $functionName -Message "PowerShell exported $($collectedData.Count) rows to $Path" -LogLevel "Information"
                return $true
            }
            catch
            {
                Write-Error "[$functionName] CSV export failed: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "CSV export failed: $($_.Exception.Message)" -LogLevel "Error"
                return $false
            }
        }
    }
}
