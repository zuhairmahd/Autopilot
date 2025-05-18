function GetDeviceHash()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $true)]
        $device
    )
    $success = $false

    Write-Verbose 'Creating DeviceHash with the following parameters:'
    Write-Verbose "OutputFile=$outputFile"
    Write-Verbose "SerialNumber=$($device.SerialNumber)"
    $csvObject = [PSCustomObject]@{
        'Device Serial Number' = $device.serialNumber
        'Windows Product ID'   = $device.product
        'Hardware Hash'        = $device.hardwareHash
        'Group Tag'            = $device.GroupTag
        'Assigned User'        = $device.AssignedUser
    }
    $csvObject | Select-Object 'Device Serial Number', 'Windows Product ID', 'Hardware Hash', 'Group Tag' | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | Out-File $OutputFile
    if ($outputFile)
    {
        Write-Host "Device hash saved to $outputFile" -ForegroundColor Green
        Write-Host 'In case of problems, you can manually upload the file to Intune or contact an Intune admin.'
        $success = $true
    }
    else
    {
        Write-Host 'Failed to save the device hash' -ForegroundColor Red
    }
    return $success 
}
