function GetAutopilotDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    $autopilotDeviceProperties = [ordered] @{}
    if ($null -eq $settings.DesiredAutopilotProfiles -or $settings.DesiredAutopilotProfiles.Count -eq 0)
    {
        Write-Verbose "[$functionName] No desired autopilot profiles specified in settings."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No desired autopilot profiles specified in settings." -LogLevel "Information"
        Write-Verbose "[$functionName] Setting default value to 'None'."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Setting default value to 'None'." -LogLevel "Information"
        $desiredAutopilotProfiles = $null
    }
    else
    {
        $desiredAutopilotProfiles = $settings.DesiredAutopilotProfiles
        Write-Verbose "[$functionName] Desired autopilot profiles specified in settings: $desiredAutopilotProfiles"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Desired autopilot profiles specified in settings: $desiredAutopilotProfiles" -LogLevel "Information"
    }
    if ($null -ne $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -and $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedUnkownSyncState', 'assignedInSync'))
    {
        Write-Verbose "[$functionName] The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)." -LogLevel "Information"
        $profileAssigned = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)." -LogLevel "Information"
        $profileAssigned = $false
    }
    if ($null -ne $desiredAutopilotProfiles -and $enrollmentState.autopilot.device.deploymentProfile.displayName -in $desiredAutopilotProfiles -and $profileAssigned -eq $true)
    {
        Write-Host "The device is assigned to the correct autopilot profile."
        $correctProfile = $true
    }
    else
    {
        Write-Verbose "[$functionName] The device is not assigned to the correct autopilot profile."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device is not assigned to the correct autopilot profile." -LogLevel "Information"
        $correctProfile = $false
    }
    Write-Host "Autopilot profile Deployment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
    Write-Host "Assigned profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayname)"
    Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)"
    #Check remediation state.
    $lastRemediationDate = $enrollmentState.autopilot.device.remediationStateLastModifiedDateTime | FormatDateWithTimeZone
    if ($null -ne $enrollmentState.autopilot.device.remediationState -and $enrollmentState.autopilot.device.remediationState -in @('noRemediationRequired', 'unknownFutureValue'))
    {
        Write-Verbose "[$functionName] The device profile remediation state is valid: $($enrollmentState.autopilot.device.remediationState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile remediation state is valid: $($enrollmentState.autopilot.device.remediationState)." -LogLevel "Information"
        $remediationStateGood = $true
        Write-Verbose "[$functionName] Remediation state last modified date: $lastRemediationDate"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Remediation state last modified date: $lastRemediationDate" -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)." -LogLevel "Information"
        $remediationStateGood = $false
    }
    Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
    Write-Host "Remediation state last modified date: $lastRemediationDate"
    #Now check enrollment status.
    if ($null -ne $enrollmentState.autopilot.device.enrollmentState -and $enrollmentState.autopilot.device.enrollmentState -in @('enrolled', 'notContacted'))
    {
        Write-Verbose "[$functionName] The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)." -LogLevel "Information"
        #Check the last enrollment status.
        if ($enrollmentState.autopilot.events.count -gt 0)
        {
            $lastEnrollmentEvent = $enrollmentState.autopilot.events[-1]
            Write-Host "Checking the last autopilot event..."
            if ($lastEnrollmentEvent.deploymentState -ne 'success' -or $lastEnrollmentEvent.deviceSetupStatus -ne 'success')
            {
                Write-Host "There are issues with the device's enrollment:"
                Write-Host "Deployment start date: $($lastEnrollmentEvent.deploymentStartDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment end date: $($lastEnrollmentEvent.deploymentEndDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment state: $($lastEnrollmentEvent.deploymentState)"
                Write-Host "Device setup status: $($lastEnrollmentEvent.deviceSetupStatus)"
                Write-Host "Enrollment failure details: $($lastEnrollmentEvent.enrollmentFailureDetails)"
                $enrollmentStateGood = $false
            }
            else
            {
                Write-Host "The device enrollment state is good."
                Write-Host "Deployment start date: $($lastEnrollmentEvent.deploymentStartDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment end date: $($lastEnrollmentEvent.deploymentEndDateTime | FormatDateWithTimeZone)"
                Write-Host "Deployment state: $($lastEnrollmentEvent.deploymentState)"
                Write-Host "Device setup status: $($lastEnrollmentEvent.deviceSetupStatus)"
                $enrollmentStateGood = $true
            }
        }
        else
        {
            Write-Host "No enrollment events found for this device."
            Write-Host "The device enrollment state is good."
            $enrollmentStateGood = $true
        }
    }
    else
    {
        Write-Verbose "[$functionName] The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)." -LogLevel "Information"
        $enrollmentStateGood = $false
    }
    Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
    if ($CorrectProfile -and $ProfileAssigned -and $RemediationStateGood -and $EnrollmentStateGood)
    {
        Write-Verbose "[$functionName] Autopilot assignment is good..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot assignment is good..." -LogLevel "Information"
        $AutopilotAssignmentGood = $true
    }
    else
    {
        Write-Verbose "[$functionName] There are issues with this device's autopilot assignment."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "There are issues with this device's autopilot assignment." -LogLevel "Information"
        $AutopilotAssignmentGood = $false
        
    }
    Write-Verbose "[$functionName] Autopilot assignment good: $AutopilotAssignmentGood"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Autopilot assignment good: $AutopilotAssignmentGood" -LogLevel "Information"
    #Add what we got the the autopilotDeviceProperties hashtable
    $autopilotDeviceProperties.Add('CorrectProfile', $correctProfile)
    $autopilotDeviceProperties.Add('ProfileAssigned', $profileAssigned)
    $autopilotDeviceProperties.Add('RemediationStateGood', $remediationStateGood)
    $autopilotDeviceProperties.Add('EnrollmentStateGood', $enrollmentStateGood)
    $autopilotDeviceProperties.Add('AutopilotAssignmentGood', $AutopilotAssignmentGood)
    return $autopilotDeviceProperties
}
