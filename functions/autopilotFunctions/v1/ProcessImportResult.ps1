function ProcessImportResult()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $device,
        [Parameter(Mandatory = $true)]
        $returnValues
    )
    
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing import result with status: $($device.state.deviceImportStatus)"
    if ($device.state.deviceImportStatus -eq 'complete')
    {
        $serialNumber = $device.SerialNumber
        Write-Host "The import of device with serial number $serialNumber completed successfully." -ForegroundColor Green
        return $returnValues.deviceImportSuccessMessage
    }
    elseif ($device.state.deviceImportStatus -eq 'error')
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
        return $returnValues.deviceImportFailedMessage
    }
    else
    {
        Write-Host 'The device import failed with the following error:' -ForegroundColor Red
        Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
        return $returnValues.deviceImportFailedMessage
    }
}

