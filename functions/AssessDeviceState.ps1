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
            if ($enrollmentState.autopilot.device.deploymentProfile.displayName -eq $settings.DesiredAutopilotProfile)
            {
                Write-Host "The device is assigned to the correct deployment profile."
                Write-Host "Deployment profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host ("Deployment Profile Assigned Date And Time: {0}" -f ($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                Write-Host "---------------------------------"
                Write-Host "Checking enrollment state..."
                Write-Host "---------------------------------"
                switch ($enrollmentState.autopilot.device.enrollmentState)
                {
                    'enrolled'
                    {
                        Write-Host 'The device appears to have been enrolled.' -ForegroundColor Red
                        Write-Host "This may cause issues when the user loggs on for the first timme." -ForegroundColor Red
                        Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
                    }
                    'notContacted'
                    { 
                        Write-Host "Device enrollment state: $($enrollmentState.autopilot.device.enrollmentState)."
                        Write-Host "This is normal for a newly imported device."
                        Write-Host "You may proceed with enrollment."
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
                        Write-Host "The enrollment state is unknown." -ForegroundColor Yellow; $success = $false 
                    }
                    default
                    {
                        Write-Host "The enrollment state is: $($enrollmentState.autopilot.device.enrollmentState)" -ForegroundColor Yellow; $success = $false 
                    }
                }
            }
            else
            {
                Write-Host "The device is assigned to the wrong deployment profile."
                Write-Host "The device is assigned to: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host "The desired deployment profile is: $($settings.desiredDeploymentProfileName)"
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
