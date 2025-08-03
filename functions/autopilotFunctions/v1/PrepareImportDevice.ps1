function PrepareImportDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $accessToken,
        [switch]$CustomImport
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Preparing to import device with serial number: $($deviceObject.serialNumber)."
    Write-Verbose "[$functionName] Getting the serial number for this device..."
    Write-Verbose "[$functionName] Checking whether the script has sufficient permissions to run."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$functionName] The script is running with sufficient permissions."
        Write-Verbose "[$functionName] Getting device object."
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please run the script as an administrator.' -ForegroundColor Red
        return $null
    }
    if ($deviceObject)
    {
        if ($customImport) 
        {
            Write-Verbose "[$functionName] Custom import is enabled."
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import' -CustomImport
            if ($result -eq $returnValues.backoutText)
            {
                Write-Verbose "[$functionName] Custom import aborted. Returning $($returnValues.backoutText)."
                return $returnValues.backoutText
            }
        }
        else 
        {
            Write-Verbose "[$functionName] The device with serial number $($deviceObject.serialNumber) is ready for import."
            $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'import'
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
}
