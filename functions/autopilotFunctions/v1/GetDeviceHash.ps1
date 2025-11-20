function GetDeviceHash()
{
    <#
    .SYNOPSIS
    Creates a hardware hash CSV file for Autopilot device import.

    .DESCRIPTION
    This function generates a CSV file containing the device hardware hash and metadata required
    for manual Autopilot device import. The CSV includes serial number, Windows Product ID,
    hardware hash, group tag, and assigned user in the format required by Microsoft Intune.

    .PARAMETER OutputFile
    Path where the CSV file should be created. This parameter is mandatory.

    .PARAMETER device
    Device object containing serialNumber, product, hardwareHash, GroupTag, and AssignedUser properties.
    This parameter is mandatory.

    .OUTPUTS
    System.Boolean
    Returns $true if CSV file created successfully, $false otherwise.

    .EXAMPLE
    GetDeviceHash -OutputFile "C:\Temp\device.csv" -device $deviceObj

    .NOTES
    Creates CSV with columns: Device Serial Number, Windows Product ID, Hardware Hash, Group Tag.
    Removes quotes from CSV for proper Intune import format.
    CSV can be manually uploaded to Intune portal for device import.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $true)]
        $device
    )
    $success = $false

    Write-Log -LogFile $LogFile -Module $MyInvocation.MyCommand.Name -Message "Creating device hash file OutputFile=$outputFile Serial=$($device.SerialNumber)" -LogLevel "Information"
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
        Write-Log -LogFile $LogFile -Module $MyInvocation.MyCommand.Name -Message "Device hash saved to $outputFile" -LogLevel "Information"
    }
    else
    {
        Write-Host 'Failed to save the device hash' -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $MyInvocation.MyCommand.Name -Message "Failed to save device hash to $outputFile" -LogLevel "Error"
    }
    Write-Log -LogFile $LogFile -Module $MyInvocation.MyCommand.Name -Message "Returning success=$success" -LogLevel "Verbose"
    return $success 
}

