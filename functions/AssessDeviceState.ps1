#region Helper functions
function ConvertUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
    $processedUser = [ordered] @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "No nickname found."
            $currentUser = $fullName
            Write-Verbose "Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "No match found for user display name format."
        Write-Verbose "Returning original display name."
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

function GetManagedDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )
    $managedDeviceProperties = [ordered] @{}
    if ($null -eq $settings.MinimumDevicePhysicalMemoryInGB -or $settings.MinimumDevicePhysicalMemoryInGB -eq 0)
    {
        Write-Verbose "No minimum device physical memory specified in settings."
        Write-Verbose "Setting default value to 16GB."
        $MinimumDevicePhysicalMemoryInGB = 16
    }
    else
    {
        $MinimumDevicePhysicalMemoryInGB = $settings.MinimumDevicePhysicalMemoryInGB
        Write-Verbose "Minimum device physical memory specified in settings: $MinimumDevicePhysicalMemoryInGB"
    }
    Write-Host "Checking managed device..."
    Write-Verbose "Managed device: $($enrollmentState.managed)"
    if ($enrollmentState.managed)
    {
        Write-Verbose "Found a managed device."
        Write-Verbose "Checking whether this is an orphan device..."
        Write-Verbose "Autopilot managed device id: $($enrollmentState.autopilot.device.managedDeviceId)"
        Write-Verbose "Managed device id: $($enrollmentState.managedDevice.device.id)"
        Write-Verbose "Checking if they are the same..."
        if ($enrollmentState.managedDevice.device.id -eq $enrollmentState.autopilot.device.managedDeviceId)
        {
            Write-Verbose "Device Id's match."
            Write-Host "The device is not an orphan device."
            $orphanDevice = $false
            Write-Host "Checking whether the device has enough RAM..."
            if ($enrollmentState.managedDevice.memory -ge $MinimumDevicePhysicalMemoryInGB)
            {
                Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of ram, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                $correctRam = $true
            }
            else
            {
                Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                Write-Host "Contact Hardware and Logistics."
                $correctRam = $false
            }   
            Write-Host "Checking for a user association on the manage device..."
            if ($enrollmentState.managedDevice.device.userId -ne '' -and $null -ne $enrollmentState.managedDevice.device.userId)
            {
                Write-Verbose "Found a user..."
                Write-Verbose "User display name: $($enrollmentState.managedDevice.users.userDisplayName)"
                Write-Verbose "User id: $($enrollmentState.managedDevice.device.userId)"
                Write-Verbose "User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)"
                $hasUser = $true
                if ($enrollmentState.managedDevice.users.azureUser)
                {
                    $validUser = $true
                    $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.users.userDisplayName
                    Write-Host "This device is registered to $($normalizedUsername.FullName) ($($enrollmentState.managedDevice.users.userPrincipalName))"
                    if ($null -ne $enrollmentState.managedDevice.users.lastLogOnDateTime)
                    {
                        $lastLogonDate = $enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone
                        Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $lastLogonDate."
                    }
                    else
                    {
                        $lastLogonDate = $null
                        Write-Host "Cannot determine the last time $($normalizedUsername.FirstName) logged on..."
                    }
                }
                else 
                {
                    Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                    Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                    $validUser = $false
                }
            }
            else
            {
                Write-Verbose "The managed device is not associated with a user."
                $hasUser = $false
            }
        }
        else
        {
            $orphanDevice = $true
            Write-Verbose "Device Id's do not match."
            Write-Verbose "The device is an orphan device."
        }
    }

    if ($OrphanDevice -eq $false -and $CorrectRam -and -not ($HasUser -and $ValidUser))
    {
        $readyForNextUser = $true
        Write-Verbose "Device is ready for the next user"
    }
    else
    {
        $readyForNextUser = $false
        Write-Verbose "Device is not ready for the next user"
    }
    $managedDeviceProperties.Add('OrphanDevice', $orphanDevice)
    $managedDeviceProperties.Add('CorrectRam', $correctRam)
    $managedDeviceProperties.Add('HasUser', $hasUser)
    $managedDeviceProperties.Add('ValidUser', $validUser)
    $managedDeviceProperties.Add('LastLogonDate', $lastLogonDate)
    $managedDeviceProperties.Add('ReadyForNextUser', $readyForNextUser)
    return $managedDeviceProperties
}

function GetAutopilotDeviceRelevantProperties()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )

    $autopilotDeviceProperties = [ordered] @{}
    if ($null -eq $settings.DesiredAutopilotProfiles -or $settings.DesiredAutopilotProfiles.Count -eq 0)
    {
        Write-Verbose "No desired autopilot profiles specified in settings."
        Write-Verbose "Setting default value to 'None'."
        $desiredAutopilotProfiles = $null
    }
    else
    {
        $desiredAutopilotProfiles = $settings.DesiredAutopilotProfiles
        Write-Verbose "Desired autopilot profiles specified in settings: $desiredAutopilotProfiles"
    }
    if ($null -ne $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -and $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedUnkownSyncState', 'assignedInSync'))
    {
        Write-Verbose "The device profile assignment state is valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        $profileAssigned = $true
    }
    else
    {
        Write-Verbose "The device profile assignment state is not valid: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
        $profileAssigned = $false
    }
    if ($null -ne $desiredAutopilotProfiles -and $enrollmentState.autopilot.device.deploymentProfile.displayName -in $desiredAutopilotProfiles -and $profileAssigned -eq $true)
    {
        Write-Host "The device is assigned to the correct autopilot profile."
        $correctProfile = $true
    }
    else
    {
        Write-Verbose "The device is not assigned to the correct autopilot profile."
        $correctProfile = $false
    }
    Write-Host "Autopilot profile Deployment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
    Write-Host "Assigned profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayname)"
    Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)"
    #Check remediation state.
    $lastRemediationDate = $enrollmentState.autopilot.device.remediationStateLastModifiedDateTime | FormatDateWithTimeZone
    if ($null -ne $enrollmentState.autopilot.device.remediationState -and $enrollmentState.autopilot.device.remediationState -in @('noRemediationRequired', 'unknownFutureValue'))
    {
        Write-Verbose "The device profile remediation state is valid: $($enrollmentState.autopilot.device.remediationState)."
        $remediationStateGood = $true
        Write-Verbose "Remediation state last modified date: $lastRemediationDate"
    }
    else
    {
        Write-Verbose "The device profile remediation state is not valid: $($enrollmentState.autopilot.device.remediationState)."
        $remediationStateGood = $false
    }
    Write-Host "Remediation state: $($enrollmentState.autopilot.device.remediationState)"
    Write-Host "Remediation state last modified date: $lastRemediationDate"
    #Now check enrollment status.
    if ($null -ne $enrollmentState.autopilot.device.enrollmentState -and $enrollmentState.autopilot.device.enrollmentState -in @('enrolled', 'notContacted'))
    {
        Write-Verbose "The device enrollment state is valid: $($enrollmentState.autopilot.device.enrollmentState)."
        $enrollmentStateGood = $true
    }
    else
    {
        Write-Verbose "The device enrollment state is not valid: $($enrollmentState.autopilot.device.enrollmentState)."
        $enrollmentStateGood = $false
    }
    Write-Host "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
    if ($CorrectProfile -and $ProfileAssigned -and $RemediationStateGood -and $EnrollmentStateGood)
    {
        Write-Verbose "Autopilot assignment is good..."
        $AutopilotAssignmentGood = $true
    }
    else
    {
        Write-Verbose "There are issues with this device's autopilot assignment."
        $AutopilotAssignmentGood = $false
        
    }
    Write-Verbose "Autopilot assignment good: $AutopilotAssignmentGood"
    #Add what we got the the autopilotDeviceProperties hashtable
    $autopilotDeviceProperties.Add('CorrectProfile', $correctProfile)
    $autopilotDeviceProperties.Add('ProfileAssigned', $profileAssigned)
    $autopilotDeviceProperties.Add('RemediationStateGood', $remediationStateGood)
    $autopilotDeviceProperties.Add('EnrollmentStateGood', $enrollmentStateGood)
    $autopilotDeviceProperties.Add('AutopilotAssignmentGood', $AutopilotAssignmentGood)
    return $autopilotDeviceProperties
}

#endregion

function AssessDeviceState() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings,
        [Parameter(Mandatory = $true)]
        [ValidateSet('PropperEnrollmentVerification', 'NextUserReadiness', 'TroubleShooting')]
        [string]$AssessmentType
    )

    #region Write verbose log of received parameters.
    Write-Verbose "Received parameters:"
    Write-Verbose "Enrollment state: $($enrollmentState | ConvertTo-Json -Depth 10)"
    Write-Verbose "Assessment type: $AssessmentType"
    Write-Verbose "Settings: $($settings | ConvertTo-Json -Depth 10)"
    $returnValue = [ordered] @{}
    $readinessState = $null
    $action = $null
    $device = $null
    #endregion

    Write-Verbose "Type of assessment: $AssessmentType"
    switch ($AssessmentType)
    {
        'PropperEnrollmentVerification'
        {
            Write-Host "Place holder text..."
            Write-Host "Checking if the device is properly enrolled..."
        }
        'NextUserReadiness'
        {
            Write-Host "Checking if the device is ready for the next user..."
            Write-Verbose "Checking if the device is registered in Autopilot..."
            Write-Verbose "In Autopilot: $($enrollmentState.inAutopilot)"
            if ($enrollmentState.inAutopilot)
            {
                $autopilotReadiness = GetAutopilotDeviceRelevantProperties -enrollmentState $enrollmentState
                $managedDeviceReadiness = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState
                Write-Host "Autopilot assignment good: $($autopilotReadiness.AutopilotAssignmentGood)"
                Write-Host "Managed device readiness good: $($managedDeviceReadiness.ReadyForNextUser)"
                if ($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser)
                {
                    Write-Host "The device has $($enrollmentState.managedDevice.memory)GB of RAM, which meets the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                    $readinessState = 'Ready'
                    $action = 'None'
                    $device = $enrollmentState.managedDevice.device.id
                }
                else
                {
                    Write-Host "The device is not ready for the next user."
                    Write-Host "See below for more information."
                    #let us explain to the user what the problem is.
                    if ($autopilotReadiness.CorrectProfile -eq $false)
                    {
                        Write-Host "The device is not assigned to the correct autopilot profile."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.ProfileAssigned -eq $false)
                    {
                        Write-Host "The device is not assigned to an autopilot profile."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.RemediationStateGood -eq $false)
                    {
                        Write-Host "The device has a remediation state that is not valid."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($autopilotReadiness.EnrollmentStateGood -eq $false)
                    {
                        Write-Host "The device has an enrollment state that is not valid."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.OrphanDevice -eq $true)
                    {
                        Write-Host "The device is an orphan device."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.CorrectRam -eq $false)
                    {
                        Write-Host "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                        Write-Host "Contact Hardware and Logistics."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.HasUser)
                    {
                        Write-Host "The managed device is associated with a user."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = 'NotReady'
                        $action = 'WipeOrClean'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    elseif ($managedDeviceReadiness.ValidUser -eq $false)
                    {
                        Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $readinessState = 'NotReady'
                        $action = 'WipeOrClean'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                    else
                    {
                        Write-Host "The device is not ready for the next user."
                        $readinessState = 'NotReady'
                        $action = 'ContactAdmin'
                        $device = $enrollmentState.managedDevice.device.id
                    }
                }
            }
            else
            {
                Write-Host "The device is not registered in Autopilot."
                Write-Host "You may want to contact an Intune admin."
                $readinessState = 'NotReady'
                $action = 'ContactAdmin'
                $device = $enrollmentState.managedDevice.device.id
            }
        }
        'TroubleShooting'
        {
            Write-Host "Place holder text..."
            Write-Host "Troubleshooting the device..."
        }
    }        
    $returnValue.Add('ReadinessState', $readinessState)
    $returnValue.Add('Action', $action)
    $returnValue.Add('Device', $device)
    Write-Verbose "Returning readiness state: $readinessState"
    Write-Verbose "Returning action: $action"
    Write-Verbose "Returning device: $device"
    return $returnValue
}
