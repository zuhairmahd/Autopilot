function Get-DeviceHash()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$device
    )
    $success = $false
    #Ask the user if they would like to create a device hash.
    $ask = Read-Host 'Would you like to create a device hash? (Y/N)'
    if ($ask -eq 'Y')
    {
        Write-Verbose 'Creating DeviceHash with the following parameters:'
        Write-Verbose "OutputFile=$outputFile"
        Write-Verbose "SerialNumber=$device.SerialNumber"
        Write-Verbose "OutputFile=$outputFile"
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
    }
    else
    {
        Write-Host 'Failed to save the device hash' -ForegroundColor Red
    }
    return $success 
}

