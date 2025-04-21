function AssessDeviceState() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$enrollmentState,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Settings
    )
    $success = $false
    Write-Host "Checking if the device is in Autopilot..."
    if ($enrollmentState.InAutopilot)
    {
        Write-Host "Device is in Autopilot."
        Write-Host "--------------------------------"
        Write-Host "Serial Number: $($enrollmentState.autopilot.device.serialNumber)"
        Write-Host "Manufacturer: $($enrollmentState.autopilot.device.manufacturer)"
        Write-Host "Model: $($enrollmentState.autopilot.device.model)"
        Write-Host "--------------------------------"
        Write-Host "Checking Autopilot registration information..."
        Write-Host "--------------------------------"
        Write-Verbose "Deployment Profile Assignment Status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
        if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedUnkownSyncState', 'assignedInSync') )
        {
            Write-Verbose "The device is assigned to a deployment profile."
            if ($enrollmentState.autopilot.device.deploymentProfile.displayName -in $settings.DesiredAutopilotProfiles)
            {
                Write-Host "The device is assigned to the correct deployment profile."
                Write-Host "Deployment profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host ("Deployment Profile Assigned Date And Time: {0}" -f ($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                Write-Host "---------------------------------"
                Write-Host "Checking enrollment state..."
                Write-Host "---------------------------------"
                Write-Verbose "Enrollment State: $($enrollmentState.autopilot.device.enrollmentState)"
                switch ($enrollmentState.autopilot.device.enrollmentState)
                {
                    'enrolled'
                    {
                        Write-Host 'The device appears to have been enrolled.'
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
                            Write-Host "The device is associated with the user $($enrollmentState.managedDevice.device.userPrincipalName) ($($enrollmentState.managedDevice.device.userDisplayName))."
                            #if we can get the last logged on date and time from the managed device, we can display it here
                            if ($null -ne $enrollmentState.managedDevice.device.usersLoggedOn.lastLogOnDateTime)
                            {
                                Write-Host ("$($enrollmentState.managedDevice.users.user.givenName)'s last logon was on {0}" -f ($enrollmentState.managedDevice.device.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                            }
                            else
                            {
                                Write-Host "The last logon date and time is unavailable."
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
                            Write-Host "If you would like to make this device available to another user, you will need to initiate a wipe or a clean action."
                            $choice = DisplayNumericMenu -choices @('Wipe', 'Clean') -Banner "What would you like to do?"
                            switch ($choice)
                            {
                                'wipe'
                                {
                                    Write-Host "Initiating a wipe action on the device..."
                                    $confirmation = DisplayNumericMenu -choices @('Wipe') -Banner "Are you sure?  This cannot be undone!"
                                    if ($confirmation -eq 'Wipe')
                                    {
                                        Write-Host "Wipe action confirmed."
                                        $action = SendDeviceCommand -ManagedDeviceId $enrollmentState.ManagedDevice.device.id -accessToken $AccessToken -Command 'Wipe' -Verbose
                                        Write-Host "Wipe action result: $action"
                                    }
                                    else
                                    {
                                        Write-Host "Wipe action canceled."
                                    }
                                }
                                'clean'
                                {
                                    Write-Host "Initiating a clean action on the device..."
                                    $confirmation = DisplayNumericMenu -choices @('Clean') -Banner "Are you sure?  This cannot be undone!"
                                    if ($confirmation -eq 'Clean')
                                    {
                                        Write-Host "Clean action confirmed."
                                        $action = SendDeviceCommand -ManagedDeviceId $enrollmentState.ManagedDevice.device.id -accessToken $AccessToken -Command 'Clean' -verbose 
                                        Write-Host "Clean action result: $action"
                                    }
                                    else
                                    {
                                        Write-Host "Clean action canceled."
                                    }
                                }
                                'default'
                                {
                                    Write-Host "No action taken."
                                }
                            }
                            Write-Host "Action result: $actionResult"
                        }
                    }
                    'notContacted'
                    { 
                        Write-Host "Device enrollment state: $($enrollmentState.autopilot.device.enrollmentState)."
                        Write-Host "This is normal for a newly imported device."
                        Write-Host "You may proceed with enrollment."
                        if ($enrollmentState.autopilot.device.managedDeviceId -eq $enrollmentState.managedDevice.device.id)
                        {
                            Write-Host "The device is associated with the following managed device:"
                            Write-Host "Device name: $($enrollmentState.managedDevice.device.deviceName)"
                            Write-Host "Serial number: $($enrollmentState.managedDevice.device.serialNumber)"
                            Write-Host "Registration State: $($enrollmentState.managedDevice.device.deviceRegistrationState)"
                            Write-Host "Enrollment type: $($enrollmentState.managedDevice.device.deviceEnrollmentType)"
                            Write-Host ("The device was enrolled on {0}" -f ($enrollmentState.managedDevice.device.enrolledDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                            Write-Host ("It was last synced on {0}" -f ($enrollmentState.managedDevice.device.lastSyncDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                            Write-Host "The device is associated with the user $($enrollmentState.managedDevice.device.userPrincipalName) ($($enrollmentState.managedDevice.device.userDisplayName))."
                            #if we can get the last logged on date and time from the managed device, we can display it here
                            if ($null -ne $enrollmentState.managedDevice.device.usersLoggedOn.lastLogOnDateTime)
                            {
                                Write-Host ("$($enrollmentState.managedDevice.users.user.givenName)'s last logon was on {0}" -f ($enrollmentState.managedDevice.device.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                            }
                            else
                            {
                                Write-Host "The last logon date and time is unavailable."
                            }
                            Write-Host "The device compliance state is  $($enrollmentState.managedDevice.device.complianceState)."
                            $success = $true
                        }
                        else
                        {
                            Write-Host "The device is not associated with a managed device."
                            Write-Host "This is normal for a newly imported device."
                            Write-Host "You may proceed with enrollment."
                            $success = $true
                        }
                    }
                    'pendingReset'
                    {
                        Write-Host 'The device is pending a reset.' -ForegroundColor Yellow
                        Write-Host "The device needs to be allowed to finish the reset." -ForegroundColor Yellow
                        Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Yellow
                    }
                    'failed'
                    {
                        Write-Host 'The device enrollment failed.' -ForegroundColor Red
                        Write-Host 'This may cause issues when the user loggs on for the first time.' -ForegroundColor Red
                        Write-Host "This means someone has already unsuccessfully tried to enroll the device." -ForegroundColor Red
                        Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Red
                        Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
                    }
                    'unknown'
                    {
                        Write-Host "The enrollment state is unknown." -ForegroundColor Yellow 
                    }
                    'default'
                    {
                        Write-Host "The enrollment state is: $($enrollmentState.autopilot.device.enrollmentState)" -ForegroundColor Yellow 
                    }
                }
            }
            else
            {
                Write-Host "The device is assigned to the wrong deployment profile."
                Write-Host "The device is assigned to: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host "The desired deployment profile is: $($settings.DesiredAutopilotProfile)"
            }
        }
        else
        {
            Write-Host "The device is not assigned to a deployment profile."
            Write-Host "Deployment Profile Assignment Status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            Write-Host "Deployment Profile Assigned Date And Time: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime)"
        }
    }
    else
    {
        Write-Host "Device is not in Autopilot."
    }
    return $success
}
