function CheckAutopilotState()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )

    $success = $false
    if (-not ($enrollmentState.InAutopilot -and $enrollmentState.managed))
    {
        Write-Host "The device is not registered in Autopilot."
        Write-Host "The device must be registered before it is assigned to another user."
        return $success
    }
    # Check if the device is enrolled in Autopilot and display the enrollment state
    if ($enrollmentState.inAutopilot)
    {
        Write-Host "The device is registered in Autopilot."
        Write-Host "--------------------------------"
        Write-Host "Checking whether the device is assigned to an autopilot profile..."
        if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
        {
            Write-Host "The device is assigned to an autopilot profile."
            Write-Host "Autopilot profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            Write-Host "Autopilot profile display name: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
            Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone)"
            $success = $true
        }
        else
        {
            Write-Host "There is an issue with the device's autopilot profile assignment."
            Write-Host "Autopilot profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            return $success
        }
        Write-Host "---------------------------------"
        Write-Host "Checking the device enrollment status..."
        if ($enrollmentState.autopilot.device.enrollmentState -eq 'Enrolled')
        {
            Write-Host "The device is enrolled in Autopilot."
            Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
            Write-Host "Last contacted date: $($enrollmentState.autopilot.device.lastContactedDateTime |FormatDateWithTimeZone)"
        }
        else 
        {
            Write-Host "The device is not enrolled in Autopilot."
            Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
            return $false
        }
        Write-Host "--------------------------------"
        Write-Host "Checking whether device is managed..."
        if ($null -ne $enrollmentState.autopilot.device.managedDeviceId -and $enrollmentState.autopilot.device.managedDeviceId -ne '' -and -not ($enrollmentState.autopilot.device.managedDeviceId -replace '[-]' -match '^[0]*$'))
        {
            Write-Host "The device is managed."
            Write-Host "Managed device ID: $($enrollmentState.autopilot.device.managedDeviceId)"
        }
        else
        {
            Write-Host "The device is not managed."
            return $false
        }
        Write-Host "--------------------------------"
        Write-Host "Checking whether the device is Azure registered..."
        if (($null -ne $enrollmentState.autopilot.device.azureActiveDirectoryDeviceId -and $enrollmentState.autopilot.device.azureActiveDirectoryDeviceId -ne '') -and ($null -ne $enrollmentState.autopilot.device.azureAdDeviceId -and $enrollmentState.autopilot.device.azureAdDeviceId -ne ''))
        {
            Write-Host "The device is registered in Azure."
            Write-Host "Azure Active Directory device ID: $($enrollmentState.autopilot.device.azureActiveDirectoryDeviceId)"
            Write-Host "Azure AD device ID: $($enrollmentState.autopilot.device.azureAdDeviceId)"
        }
        else
        {
            Write-Host "The device is not registered in Azure."
            return $false
        }
        Write-Host "--------------------------------"
        Write-Host "Checking remediation state..."
        if ($enrollmentState.autopilot.device.remediationState -eq 'noRemediationRequired')
        {
            Write-Host "The device is in a good state."
            Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
            Write-Host "Last checked date: $($enrollmentState.autopilot.device.remediationStateLastModifiedDateTime | FormatDateWithTimeZone)"
        }
        else
        {
            Write-Host "There may be an issue with the device, but it should not prevent registration."
            Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
            Write-Host "Last checked date: $($enrollmentState.autopilot.device.remediationStateLastModifiedDateTime) | FormatDateWithTimeZone"
        }
        Write-Host "--------------------------------"
        Write-Host "Checking the latest Autopilot event state..."
        Write-Host "The device has $($enrollmentState.autopilot.events.count) autopilot events."
        if ($enrollmentState.autopilot.events.count -gt 0 -and $enrollmentState.autopilot.events[0] -ne '') 
        {
            $latestEvent = $enrollmentState.autopilot.events[0]
            if ($latestEvent.deploymentState -eq 'failure' -or $latestEvent.deviceSetupStatus -eq 'failure' -or $latestEvent.accountSetupStatus -eq 'failure') 
            {
                Write-Host "The last Autopilot enrollment resulted in a failure."
                Write-Host "Here are the details:"
                Write-Host ("Event date: {0}" -f ($($latestEvent.eventDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")))
                Write-Host ("Enrollment start date: {0}" -f ($latestEvent.enrollmentStartDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                Write-Host "Enrollment type: $($latestEvent.enrollmentType)."
                Write-Host "Device name: $($latestEvent.managedDeviceName)."
                Write-Host "User name: $($latestEvent.userPrincipalName)."
                Write-Host "Autopilot profile display name: $($latestEvent.windowsAutopilotDeploymentProfileDisplayName)."
                Write-Host "Enrollment Status Page (ESP) name: $($latestEvent.windows10EnrollmentCompletionPageConfigurationDisplayName)."
                Write-Host "Deployment state: $($latestEvent.deploymentState)."
                Write-Host "Device setup status: $($latestEvent.deviceSetupStatus)."
                Write-Host "Account setup status: $($latestEvent.accountSetupStatus)."
                Write-Host ("Deployment started on {0} and ended on {1}, lasting {2}" -f ($latestEvent.deploymentStartDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"), ($latestEvent.deploymentEndDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"), $latestEvent.deploymentDuration)
                Write-Host "Deployment total duration: $($latestEvent.deploymentTotalDuration)."
                Write-Host "Device setup duration: $($latestEvent.deviceSetupDuration)."
                Write-Host "Account setup duration: $($latestEvent.accountSetupDuration)."
                Write-Host "Enrollment failure details: $($latestEvent.enrollmentFailureDetails)."
                Write-Host "--------------------------------"
                return $false
            }
            else
            {
                Write-Host "The last autopilot enrollment was successful."
            }
            if ($enrollmentState.autopilot.events.count -gt 1) 
            {
                Write-Host "Would you like to see the remaining autopilot events?"
                $choice = DisplayNumericMenu -choices @('Yes', 'No') -Banner "Please choose an option."
                if ($choice -eq 'Yes') 
                {
                    Write-Host "Here are the remaining autopilot events:"
                    foreach ($event in $enrollmentState.autopilot.events[1..$enrollmentState.autopilot.events.count])
                    {
                        Write-Host ("Event date: {0}" -f ($($event.eventDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K")))
                        Write-Host ("Enrollment start date: {0}" -f ($event.enrollmentStartDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"))
                        Write-Host "Enrollment type: $($event.enrollmentType)."
                        Write-Host "Device name: $($event.managedDeviceName)."
                        Write-Host "User name: $($event.userPrincipalName)."
                        Write-Host "Autopilot profile display name: $($event.windowsAutopilotDeploymentProfileDisplayName)."
                        Write-Host "Enrollment Status Page (ESP) name: $($event.windows10EnrollmentCompletionPageConfigurationDisplayName)."
                        Write-Host "Deployment state: $($event.deploymentState)."
                        Write-Host "Device setup status: $($event.deviceSetupStatus)."
                        Write-Host "Account setup status: $($event.accountSetupStatus)."
                        Write-Host ("Deployment started on {0} and ended on {1}, lasting {2}" -f ($event.deploymentStartDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"), ($event.deploymentEndDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"), $event.deploymentDuration)
                        Write-Host "Deployment total duration: $($event.deploymentTotalDuration)."
                        Write-Host "Device setup duration: $($event.deviceSetupDuration)."
                        Write-Host "Account setup duration: $($event.accountSetupDuration)."
                        Write-Host "Enrollment failure details: $($event.enrollmentFailureDetails)."
                    }
                }
                else
                {
                    Write-Host "Ok.."
                }
            }
        }
        else
        {
            Write-Host "No autopilot events found."
        }
    }
    else
    {
        Write-Host "The device is not enrolled in Autopilot."
        return $false
    }
    return $true
}
