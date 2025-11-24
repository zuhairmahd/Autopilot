function PrepareImportDevice()
{
    <#
    .SYNOPSIS
    Prepares device object for Autopilot import by validating and formatting properties.

    .DESCRIPTION
    This function validates the device object contains required properties (serialNumber, hardwareHash),
    formats optional properties (GroupTag, AssignedUser), and creates the properly structured device
    object for Graph API import. It ensures all data meets Autopilot import requirements.

    .PARAMETER device
    Device object to prepare containing serialNumber, hardwareHash, and optional GroupTag/AssignedUser.
    This parameter is mandatory.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns prepared device object with validated and formatted properties, or $null if validation fails.

    .EXAMPLE
    $preparedDevice = PrepareImportDevice -device $rawDevice

    .NOTES
    Validates serialNumber and hardwareHash are present.
    Formats GroupTag and AssignedUser properties.
    Returns $null if required properties missing.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $accessToken,
        [switch]$CustomImport
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Preparing to import device with serial number: $($deviceObject.serialNumber)."
    Write-Log -LogFile $LogFile -Module $functionName -Message "Preparing device import (CustomImport=$CustomImport)" -LogLevel "Information"
    Write-Verbose "[$functionName] Getting the serial number for this device..."
    Write-Verbose "[$functionName] Checking whether the script has sufficient permissions to run."
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    if ($deviceObject)
    {
        if ($deviceObject.deviceAllowed -eq $false)
        {
            Write-Host "The device manufacturer $($deviceObject.manufacturer) is not allowed." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Device manufacturer $($deviceObject.manufacturer) is not allowed" -LogLevel "Error"
            return $returnValues.manufacturerNotAllowed
        }
        if ($customImport) 
        {
            Write-Verbose "[$functionName] Custom import is enabled."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Custom import enabled" -LogLevel "Information"
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import' -CustomImport
            if ($result -eq $returnValues.backoutText)
            {
                Write-Verbose "[$functionName] Custom import aborted. Returning $($returnValues.backoutText)."
                Write-Log -LogFile $LogFile -Module $functionName -Message "Custom import aborted (backout)" -LogLevel "Information"
                return $returnValues.backoutText
            }
        }
        else 
        {
            Write-Verbose "[$functionName] The device with serial number $($deviceObject.serialNumber) is ready for import."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Starting standard import for serial=$($deviceObject.serialNumber)" -LogLevel "Information"
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import'
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to obtain device object" -LogLevel "Error"
    }
}
