function FindAssociatedManagedDevice()
{                        
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    Write-Host "Checking associated managed device..."
    if ($enrollmentState.autopilot.device.managedDeviceId -eq $enrollmentState.managedDevice.device.id)
    #we can also potentially match on
    #($enrollmentState.autopilot.device.azureAdDeviceId -eq $enrollmentState.managedDevice.device.azureADDeviceId)
    #or
    #($enrollmentState.autopilot.device.azureActiveDirectoryDeviceId -eq $enrollmentState.managedDevice.device.azureActiveDirectoryDeviceId
    {
        Write-Host "The device is associated with the following managed device:"
        Write-Host "Device name: $($enrollmentState.managedDevice.device.deviceName)"
        Write-Host "Serial number: $($enrollmentState.managedDevice.device.serialNumber)"
        Write-Host "Registration State: $($enrollmentState.managedDevice.device.deviceRegistrationState)"
        Write-Host "Enrollment type: $($enrollmentState.managedDevice.device.deviceEnrollmentType)"
        Write-Host ("The device was enrolled on {0}" -f ($enrollmentState.managedDevice.device.enrolledDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
        Write-Host ("It was last synced on {0}" -f ($enrollmentState.managedDevice.device.lastSyncDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
        $currentUser = ConvertDisplayName -DisplayName $enrollmentState.managedDevice.device.userDisplayName
        Write-Host "The device is associated with the user $currentUser ($($enrollmentState.managedDevice.device.userDisplayName), $($enrollmentState.managedDevice.device.userPrincipalName)) ."
        #if we can get the last logged on date and time from the managed device, we can display it here
        if ($null -ne $enrollmentState.managedDevice.device.usersLoggedOn.lastLogOnDateTime)
        {
            Write-Host ("$($enrollmentState.managedDevice.users.user.givenName)'s last logon was on {0}" -f ($enrollmentState.managedDevice.device.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
        }
        else
        {
            Write-Host "The last logon date and time is unavailable."
            Write-Host "This could be because the user was unable to complete the enrollment."
        }
        Write-Host "The device compliance state is  $($enrollmentState.managedDevice.device.complianceState)."
        Write-Host "Last action results: $($enrollmentState.managedDevice.device.deviceActionResults)."
        if ($null -ne $enrollmentState.managedDevice.device.deviceActionResults)
        {
            Write-Host "The device has the following actions pending:"
            foreach ($action in $enrollmentState.managedDevice.device.deviceActionResults)
            {
                Write-Host "Action: $($action.action)"
                Write-Host "Action state: $($action.actionState)"
                Write-Host "Action result: $($action.actionResult)"
                Write-Host "Action initiated by: $($action.initiatedBy)"
                Write-Host "Action initiated on: $($action.initiatedDateTime)"
            }
        }
        else
        {
            Write-Host "The device has no actions pending."
        }
    }
}
