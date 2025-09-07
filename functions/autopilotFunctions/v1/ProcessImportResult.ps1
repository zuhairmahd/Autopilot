function ProcessImportResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $device,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name    
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing import result status=$($device.state.deviceImportStatus) errName=$($device.state.deviceErrorName)" -LogLevel "Information"
    if ($device.state.deviceImportStatus -eq 'complete')
    {
        $serialNumber = $device.SerialNumber
        Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $functionName -Message "Import complete for serial $serialNumber" -LogLevel "Information"
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($device.state.deviceImportStatus -eq 'error')
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Import error status=error name=$($device.state.deviceErrorName)" -LogLevel "Error"
        return $returnValues.deviceImportFailedMessage
    }
    else
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Import failure other status=$($device.state.deviceImportStatus)" -LogLevel "Error"
        return $returnValues.deviceImportFailedMessage
    }
}
