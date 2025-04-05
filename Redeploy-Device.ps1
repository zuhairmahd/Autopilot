[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SerialNumber,
    [string]$configFile = "$PSScriptRoot\.secrets.config.json"
)

Write-Host "Checking redeployment status for device with serial number $SerialNumber."
$enrollmentState = VerifyEnrollmentStatus -serialNumber $Serial
#print the enrollment state.
Write-Verbose "The enrollment state is: $($enrollmentState | Out-String)"
if (($enrollmentState.imported -eq $false) -and ($enrollmentState.enrolled -eq $false))
{
    Write-Host "The device with serial number $SerialNumber is not imported or enrolled." -ForegroundColor Yellow
    Write-Host 'Continue to import the device.' -ForegroundColor Yellow
}
elseif (($enrollmentState.imported -eq $true) -and ($enrollmentState.enrolled -eq $false))
{
    Write-Host 'The device is imported in Intune but is not enrolled.' -ForegroundColor Yellow
    Write-Host 'Continue to check assignment.' -ForegroundColor Yellow
}
elseif (($enrollmentState.imported -eq $false) -and ($enrollmentState.enrolled -eq $true) -and ($enrollmentState.userName -ne 'unknown'))
{
    Write-Host "This device is enrolled and is being used by $($enrollmentState.userName) ($($enrollmentState.UserDisplayName))" -ForegroundColor Green
}
elseif (($enrollmentState.imported -eq $true) -and ($enrollmentState.enrolled -eq $true))
{
    Write-Host 'The device is enrolled and is registered to a user.'
    if ($enrollmentState.userName -ne 'unknown')
    {
        Write-Host "The registered user is $($enrollmentState.username)"
        Write-Host 'You must wipe the device to get it ready for another user'
        Write-Host 'Wiping a device is a distructive command.  Make sure you are wiping the correct device.'
        Write-Host "Device id: $($enrollmentState.id)"
        Write-Host "Device serial number: $SerialNumber"
        Write-Host "Registered user: $($enrollmentState.username) `r`n"
        Write-Host 'Would you still like to send a wipe command to the device? (Y/N)'
        $response = Read-Host
        while ($response -notin 'Y', 'N')
        {
            Write-Host 'Please enter Y or N.' -ForegroundColor Yellow
            [console]::beep(500, 300)
            $response = Read-Host
        }
        if ($response -eq 'Y')
        {
            $response = SendDeviceCommand -ManagedDeviceId $enrollmentState.id
            if ($response -eq $true)
            {
                Write-Host "The wipe command has been sent to the device with serial number $SerialNumber."
                Write-Host 'Please manually sync the device or give the device enough time to sync and reset.'
                Write-Host 'The device will be ready for another user after the wipe is complete.'
                Write-Host 'Please contact an Intune admin if you have any problems.'
            }
            else
            {
                Write-Host "The wipe command failed to send to the device with serial number $SerialNumber."
                Write-Host 'Please contact an Intune admin.'
            }
            exit 0
        }
        else
        {
            Write-Host 'Aborting script.'
            exit 0
        }
    }
    else
    {
        Write-Host 'The user is not registered.'
    }
}
else
{
    Write-Host 'Unknown error.' -ForegroundColor Red
    Write-Host 'Please check the Intune portal or contact an Intune administrator.'
    exit 1
}