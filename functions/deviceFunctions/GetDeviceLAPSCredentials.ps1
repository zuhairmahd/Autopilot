function GetDeviceLAPSCredentials()
{
    <#
    .SYNOPSIS
    Retrieves and displays Local Administrator Password Solution (LAPS) credentials for a device.

    .DESCRIPTION
    This function extracts LAPS credentials from the enrollment state object for a managed device.
    When multiple credentials exist, it returns the most recent one based on backup date time.
    The function decodes the Base64-encoded password and displays all credential details.

    .PARAMETER enrollmentState
    The enrollment state object containing device information and LAPS credentials.

    .OUTPUTS
    System.String
    Returns a newline character on success, or a predefined return value if no LAPS credentials are found.

    .EXAMPLE
    GetDeviceLAPSCredentials -enrollmentState $deviceEnrollmentState

    .NOTES
    Displays account name, backup date/time, clear text password, and next password change date.
    Requires appropriate Microsoft Graph permissions to access LAPS credentials.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        $enrollmentState
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting LAPS credentials for device with Azure ID: $($enrollmentState.managedDevice.Device.azureADDeviceId)."

    if ($enrollmentState.managedDevice.laps -notin $returnValues.values)
    {
        Write-Host "LAPS credentials found for device with serial number $($enrollmentState.managedDevice.Device.serialNumber)" -ForegroundColor Green
        Write-Verbose "Found $($enrollmentState.managedDevice.laps.credentials.count ) LAPS credentials for device with Azure ID: $DeviceId"
        #If there is more than $lapsCredentials.credentials.count, return the latest (by date) $lapsCredential.accountName, backupDateTime and a clear text password derived from passwordBase64
        if ($enrollmentState.managedDevice.laps.credentials.count -gt 1)
        {
            Write-Verbose "[$functionName] More than one LAPS credential found. Sorting by backupDateTime and getting the latest credential."
            $latestCredential = $enrollmentState.managedDevice.laps.credentials | Sort-Object backupDateTime -Descending | Select-Object -First 1
        }
        else
        {
            Write-Verbose "[$functionName] Only one LAPS credential found. Using that credential."
            $latestCredential = $enrollmentState.managedDevice.laps.credentials
        }
        $clearTextPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($latestCredential.passwordBase64))
        $returnObject = @{
            AccountName        = $latestCredential.accountName
            BackupDateTime     = $latestCredential.backupDateTime
            ClearTextPassword  = $clearTextPassword
            NextPasswordChange = $enrollmentState.managedDevice.laps.refreshDateTime
        }
        #display the LAPS credentials
        Write-Host "LAPS Credentials for device: $DeviceId" -ForegroundColor Cyan
        Write-Host "Account Name: $($returnObject.AccountName)" -ForegroundColor Cyan
        Write-Host "Backup DateTime: $($returnObject.BackupDateTime | FormatDateWithTimeZone)" -ForegroundColor Cyan
        Write-Host "Clear Text Password: $($returnObject.ClearTextPassword)" -ForegroundColor Cyan
        Write-Host "Next Password Change: $($returnObject.NextPasswordChange | FormatDateWithTimeZone)" -ForegroundColor Cyan
        # return $lapsCredentials 
        return "`n"
    }
    else
    {
        Write-Verbose "[$functionName] No LAPS credentials found for device: $DeviceId"
        Write-Host "No LAPS credentials found for device: $DeviceId" -ForegroundColor Red
        return $returnValues.noLAPSFoundMessage
    }
}

