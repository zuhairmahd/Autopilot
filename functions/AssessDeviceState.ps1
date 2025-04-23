#region Helper functions
function TakeAction()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )
    
    Write-Host "You will need to initiate a wipe or a clean action."
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

function CheckAutopilotState()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings
    )

    # Check if the device is enrolled in Autopilot and display the enrollment state
    if ($enrollmentState.inAutopilot)
    {
        Write-Host "The device is enrolled in Autopilot."
        Write-Host "--------------------------------"
        Write-Host "Checking whether the device is assigned to an autopilot profile..."
        if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
        {
            Write-Host "The device is assigned to an autopilot profile."
            Write-Host "Autopilot profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            Write-Host "Autopilot profile display name: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
            Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone)"
        }
        else
        {
            Write-Host "There is an issue with the device's autopilot profile assignment."
            Write-Host "Autopilot profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            return $false
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

function ConvertUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )
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
    return $currentUser
}
#endregion

function AssessDeviceState() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$enrollmentState,
        $settings = $settings,
        [Parameter(Mandatory = $true)]
        [ValidateSet('PropperEnrollmentVerification', 'NextUserReadiness', 'TroubleShooting')]
        [string]$AssessmentType
    )
    
    Write-Verbose "Type of assessment: $AssessmentType"
    switch ($AssessmentType)
    {
        'PropperEnrollmentVerification'
        {
            Write-Host "Place holder text..."
            Write-Host "Checking if the device is properly enrolled..."
            return $true
        }
        'NextUserReadiness'
        {
            Write-Host "Checking if the device is ready for the next user..."
            if (CheckAutopilotState -enrollmentState $enrollmentState -settings $settings)
            {
                Write-Host "Device passed."
                Write-Host "The device is ready to assign to the user"
                return $true
            }
            else 
            {
                Write-Host "Device failed."
                Write-Host "The device is not ready to be assigned to the user."
                return $false
            }
        }
        'TroubleShooting'
        {
            Write-Host "Place holder text..."
            Write-Host "Troubleshooting the device..."
            return $true
        }
    }
}
