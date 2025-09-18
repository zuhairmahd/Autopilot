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
    
    # Check for new autopilotProfilesToInclude format first, then fall back to legacy DesiredAutopilotProfiles
    $desiredAutopilotProfiles = $null
    $profileNames = @()
    $profileIds = @()
    
    if ($null -ne $settings.autopilotProfilesToInclude -and $settings.autopilotProfilesToInclude.Count -gt 0)
    {
        Write-Verbose "[$functionName] Found autopilotProfilesToInclude in settings (new format)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found autopilotProfilesToInclude in settings with $($settings.autopilotProfilesToInclude.Count) profiles (new format)" -LogLevel "Information"
        
        # Extract names and IDs from the new format
        $profileNames, $profileIds = Convert-AutopilotProfilesToStandardFormat -profiles $settings.autopilotProfilesToInclude
        
        Write-Verbose "[$functionName] Extracted profile names: $($profileNames -join ', ')"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracted profile names: $($profileNames -join ', ')" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Extracted profile IDs: $($profileIds -join ', ')"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracted profile IDs: $($profileIds -join ', ')" -LogLevel "Verbose"
        
        $desiredAutopilotProfiles = $settings.autopilotProfilesToInclude
    }
    elseif ($null -ne $settings.DesiredAutopilotProfiles -and $settings.DesiredAutopilotProfiles.Count -gt 0)
    {
        Write-Verbose "[$functionName] Found DesiredAutopilotProfiles in settings (legacy format)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found DesiredAutopilotProfiles in settings with $($settings.DesiredAutopilotProfiles.Count) profiles (legacy format)" -LogLevel "Information"
        
        # Legacy format - just profile names
        $profileNames = $settings.DesiredAutopilotProfiles
        $profileIds = @()  # No IDs available in legacy format
        $desiredAutopilotProfiles = $settings.DesiredAutopilotProfiles
        
        Write-Verbose "[$functionName] Using legacy format profile names: $($profileNames -join ', ')"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using legacy format profile names: $($profileNames -join ', ')" -LogLevel "Verbose"
    }
    else
    {
        Write-Verbose "[$functionName] No desired autopilot profiles specified in settings."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No desired autopilot profiles specified in settings." -LogLevel "Information"
        Write-Verbose "[$functionName] Setting default value to 'None'."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Setting default value to 'None'." -LogLevel "Information"
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
    
    # Enhanced profile matching logic - prioritize ID matching over display name matching
    $correctProfile = $false
    if ($null -ne $desiredAutopilotProfiles -and $profileAssigned -eq $true)
    {
        $deviceProfileId = $enrollmentState.autopilot.device.deploymentProfile.id
        $deviceProfileDisplayName = $enrollmentState.autopilot.device.deploymentProfile.displayName
        
        Write-Verbose "[$functionName] Device profile ID: $deviceProfileId"
        Write-Verbose "[$functionName] Device profile display name: $deviceProfileDisplayName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device profile ID: $deviceProfileId, Display name: $deviceProfileDisplayName" -LogLevel "Verbose"
        
        # First priority: Check if device profile ID matches any of the desired profile IDs
        if ($profileIds.Count -gt 0 -and $deviceProfileId -and $deviceProfileId -in $profileIds)
        {
            Write-Host "The device is assigned to the correct autopilot profile (matched by ID)."
            Write-Verbose "[$functionName] Device autopilot profile matched by ID: $deviceProfileId"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device autopilot profile matched by ID: $deviceProfileId" -LogLevel "Information"
            $correctProfile = $true
        }
        # Second priority: Check if device profile display name matches any of the desired profile names
        elseif ($profileNames.Count -gt 0 -and $deviceProfileDisplayName -and $deviceProfileDisplayName -in $profileNames)
        {
            Write-Host "The device is assigned to the correct autopilot profile (matched by display name)."
            Write-Verbose "[$functionName] Device autopilot profile matched by display name: $deviceProfileDisplayName"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device autopilot profile matched by display name: $deviceProfileDisplayName" -LogLevel "Information"
            $correctProfile = $true
            
            # Log a note if we have IDs available but had to fall back to name matching
            if ($profileIds.Count -gt 0)
            {
                Write-Verbose "[$functionName] Note: Profile matched by name but ID-based matching was available. Consider using ID-based matching for better accuracy."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Note: Profile matched by name but ID-based matching was available. Consider updating profile configuration." -LogLevel "Warning"
            }
        }
        else
        {
            Write-Verbose "[$functionName] The device is not assigned to the correct autopilot profile."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device autopilot profile does not match any desired profiles. Device profile: '$deviceProfileDisplayName' (ID: $deviceProfileId)" -LogLevel "Information"
            $correctProfile = $false
        }
    }
    else
    {
        if ($null -eq $desiredAutopilotProfiles)
        {
            Write-Verbose "[$functionName] No desired autopilot profiles configured - skipping profile validation."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No desired autopilot profiles configured - skipping profile validation." -LogLevel "Information"
        }
        if ($profileAssigned -eq $false)
        {
            Write-Verbose "[$functionName] No autopilot profile assigned to device - cannot validate profile."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No autopilot profile assigned to device - cannot validate profile." -LogLevel "Information"
        }
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
        if ($enrollmentState.autopilot.events.count -gt 0 -and $enrollmentState.autopilot.device.enrollmentState -ne 'notContacted')
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
