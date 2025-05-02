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
                Write-Host "The device is registered in Autopilot."
                Write-Host "Autopilot profile Deployment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
                Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)"
                Write-Host "Assigned profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayname)"
                Write-Host "Checking enrollment state..."
                Write-Verbose "Enrollment state: $($enrollmentState.autopilot.device.enrollmentState)"
                switch ($enrollmentState.autopilot.device.enrollmentState) 
                {
                    notContacted 
                    {
                        Write-Host "The device has not contacted the Autopilot service."
                        Write-Host "Checking for an associated managed device..."
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
                                Write-Host "Checking for a user association on the manage device..."
                                if ($enrollmentState.managedDevice.device.userId -ne '' -and $null -ne $enrollmentState.managedDevice.device.userId)
                                {
                                    Write-Verbose "Found a user..."
                                    Write-Verbose "User display name: $($enrollmentState.managedDevice.device.userDisplayName)"
                                    Write-Verbose "User id: $($enrollmentState.managedDevice.device.userId)"
                                    Write-Verbose "User principal name: $($enrollmentState.managedDevice.device.userPrincipalName)"
                                    if ($enrollmentState.managedDevice.users.azureUser)
                                    {
                                        $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.device.userDisplayName
                                        Write-Host "This device is registered to $normalizedUsername ($($enrollmentState.managedDevice.users.user.userPrincipalName))"
                                        Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $($enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone))"
                                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                        $readinessState = 'NotReady'
                                        $action = 'WipeOrClean'
                                        $device = $enrollmentState.managedDevice.device.id
                                    }
                                    else 
                                    {
                                        Write-Host "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                        $readinessState = 'NotReady'
                                        $action = 'WipeOrClean'
                                        $device = $enrollmentState.managedDevice.device.id
                                    }
                                }
                                else
                                {
                                    Write-Verbose "The managed device is not associated with a user."
                                    Write-Host "This is probably ok."
                                    $readinessState = 'Ready'
                                    $action = 'None'
                                    $device = 'None'
                                }
                            }
                            else
                            {
                                Write-Verbose "Device Id's do not match."
                                Write-Verbose "The device is an orphan device."
                                Write-Host "The device was once associated with a managed device, but the association is no longer valid."
                                Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                $readinessState = 'NotReady'
                                $action = 'WipeOrClean'
                                $device = $enrollmentState.managedDevice.device.id
                            }
                        }
                        else 
                        {
                            Write-Host "No managed device is associated with this autopilot device."
                            Write-Host "the device is ready for the next user."
                            $readinessState = 'Ready'
                            $action = 'None'
                            $device = 'None'
                        }
                    }
                    enrolled 
                    {
                        Write-Host "The device is enrolled in Autopilot."
                        Write-Host "Checking for an associated managed device..."
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
                                Write-Host "Found a managed device..."
                                Write-Host "Checking for a user association on the manage device..."
                                if ($enrollmentState.managedDevice.device.userId -ne '' -and $null -ne $enrollmentState.managedDevice.device.userId)
                                {
                                    Write-Verbose "Found a user..."
                                    Write-Verbose "User display name: $($enrollmentState.managedDevice.device.userDisplayName)"
                                    Write-Verbose "User id: $($enrollmentState.managedDevice.device.userId)"
                                    Write-Verbose "User principal name: $($enrollmentState.managedDevice.device.userPrincipalName)"
                                    if ($enrollmentState.managedDevice.users.azureUser)
                                    {
                                        $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.device.userDisplayName
                                        Write-Host "This device is registered to $normalizedUsername ($($enrollmentState.managedDevice.users.user.userPrincipalName))"
                                        Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $($enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone)"
                                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                        $readinessState = 'NotReady'
                                        $action = 'WipeOrClean'
                                        $device = $enrollmentState.managedDevice.device.id
                                    }
                                }
                                else
                                {
                                    Write-Verbose "Device Id's do not match."
                                    Write-Host "The device is an orphan device."
                                    Write-Host "The device was once associated with a managed device, but the association is no longer valid."
                                    Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                    $readinessState = 'NotReady'
                                    $action = 'WipeOrClean'
                                    $device = $enrollmentState.managedDevice.device.id
                                }
                            }
                            else
                            {
                                Write-Verbose "Device Id's do not match."
                                Write-Host "The device is an orphan device."
                                Write-Host "The device was once associated with a managed device, but the association is no longer valid."
                                Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                $readinessState = 'NotReady'
                                $action = 'WipeOrClean'
                                $device = $enrollmentState.managedDevice.device.id
                            }
                        }
                        else 
                        {
                            Write-Host "No managed device is associated with this autopilot device even though it shows as being enrolled."
                            Write-Host "you may want to contact an Intune admin."
                            $readinessState = 'NotReady'
                            $action = 'ContactAdmin'
                            $device = $enrollmentState.managedDevice.device.id
                        }
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
    Write-Host "Returning readiness state: $readinessState"
    return $returnValue
}

# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAQ4vm10vSjuoSG
# 624CisMHgE+zNfgTj7D9wu97eV+lQqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN0uwl7
# vtDCSQaiAAAAA3S7MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDIzMDQ0NDU1WhcNMjUwNDI2
# MDQ0NDU1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h/5tCSWKbPKt8F93wvLZlP5AAfdF3mukm8z0mBQtyMLGXK+NWnLO8fvV0ge5eUjI
# A9wcMLEcX2TvQCW7IyvihQMgHy1L6uzT9xKUmyQI9kJGEXpw64rtKAgDlJqD6GgA
# WnyhOzNcHRfgN0HNTai/MezVyct6AF9SxZn1XinCOhUbBx1wTZTvScxwTEqe43HU
# ZIVJ40G32BYnBeOoSXYAO0ZK4b+mxStrfB9II8lQ3tdTxu524cM+qaIF23QUnhBa
# asuCBhne2rFQuaQnY++/GvWc+ZdkR1d4eoV4zyt9d+mzYHNZ9JNOI4XWn78S2rKd
# gsL9xWj1YKAD1mhVFuuBKMIXktSaSDXiPdhGWSQcaTYbchw2OI0Peb3Xf50WD9qD
# GAPcYdjtB0vugl/dx5YJOLBfqiIxXeVg6TEsgSQTRDQdBaKDjHma/gXRJIsQw5KP
# mJMHaAZ5dEDoVuXbDev27Yvv4VV95giO3wLUx2iOsC1qDenBWiFyWPe4WovyDvxF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCmIHt4RADaTywJxAromEjAGzJZjMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFXeJOg62AhYTxzF
# Yip4wYPtqc/tDdCid07e6FTg2jM84hJXep5mqbcU8VtqDNTqVODwDy1dFGRmHAdu
# 3F4o2Hkb0W4QVFAZsHR9yd+BQTJGDBFv+i23cHJ+qODBTZ6rh1NOMRGSuH6k3lX7
# nsI0/WQXbff/5XsSqpO9/d0+2VwWmeujUSCQf48tY7PsXBH+4rPOe3U9NW0/HXiI
# adefC8/N9UltDmQ4by+CtRmra3nBkIEAPRmFC1ERfq3JMPAJ4yJ3ddzakrjO0w56
# JyW7yeawoSB3iX8due4vRy2rDIfFWsKrcIKEqBZItd3ZTDIuLXbpQD/tZxocQPIx
# Eg6Wy5XRMlKxgQmxVP8IIsmz9InLM1qjhAtGgIv+kx+iisyg1qvojhnGnJohaZbq
# 2XH5Nx84JnfOfTAZ0mfEuSnuZA7IvCtaL66lP6Q1TikBAIGUa5wwk6cL0GGFGcI4
# p/Lr9n34HsCuJp4Qu/d6IaHMwA0s4YJnwH/bJctKJYO5VhV5MEVDU2QgeVkAkQ5G
# EIKOIBA1SR+fC87xg9dmbFjmAHqA3wkNgL1DVijsPpMXByQnkP3IqFFlDrP+rlBz
# WBv7814VxOszcciIgYPGI24asSBGXE6oQyAKkmTfTthhzNdgT5JxpNrgBwFEuUle
# mnqxm4/T9GIubTff34taJzANNNJVMIIG5zCCBM+gAwIBAgITMwADdLsJe77QwkkG
# ogAAAAN0uzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyMzA0NDQ1NVoXDTI1MDQyNjA0NDQ1
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIf+bQkl
# imzyrfBfd8Ly2ZT+QAH3Rd5rpJvM9JgULcjCxlyvjVpyzvH71dIHuXlIyAPcHDCx
# HF9k70AluyMr4oUDIB8tS+rs0/cSlJskCPZCRhF6cOuK7SgIA5Sag+hoAFp8oTsz
# XB0X4DdBzU2ovzHs1cnLegBfUsWZ9V4pwjoVGwcdcE2U70nMcExKnuNx1GSFSeNB
# t9gWJwXjqEl2ADtGSuG/psUra3wfSCPJUN7XU8buduHDPqmiBdt0FJ4QWmrLggYZ
# 3tqxULmkJ2Pvvxr1nPmXZEdXeHqFeM8rfXfps2BzWfSTTiOF1p+/EtqynYLC/cVo
# 9WCgA9ZoVRbrgSjCF5LUmkg14j3YRlkkHGk2G3IcNjiND3m913+dFg/agxgD3GHY
# 7QdL7oJf3ceWCTiwX6oiMV3lYOkxLIEkE0Q0HQWig4x5mv4F0SSLEMOSj5iTB2gG
# eXRA6Fbl2w3r9u2L7+FVfeYIjt8C1MdojrAtag3pwVohclj3uFqL8g78RQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQpiB7eEQA2k8sCcQK6JhIwBsyWYzAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBV3iToOtgIWE8cxWIqeMGD
# 7anP7Q3QondO3uhU4NozPOISV3qeZqm3FPFbagzU6lTg8A8tXRRkZhwHbtxeKNh5
# G9FuEFRQGbB0fcnfgUEyRgwRb/ott3ByfqjgwU2eq4dTTjERkrh+pN5V+57CNP1k
# F233/+V7EqqTvf3dPtlcFpnro1EgkH+PLWOz7FwR/uKzznt1PTVtPx14iGnXnwvP
# zfVJbQ5kOG8vgrUZq2t5wZCBAD0ZhQtREX6tyTDwCeMid3Xc2pK4ztMOeiclu8nm
# sKEgd4l/HbnuL0ctqwyHxVrCq3CChKgWSLXd2UwyLi126UA/7WcaHEDyMRIOlsuV
# 0TJSsYEJsVT/CCLJs/SJyzNao4QLRoCL/pMfoorMoNar6I4ZxpyaIWmW6tlx+Tcf
# OCZ3zn0wGdJnxLkp7mQOyLwrWi+upT+kNU4pAQCBlGucMJOnC9BhhRnCOKfy6/Z9
# +B7AriaeELv3eiGhzMANLOGCZ8B/2yXLSiWDuVYVeTBFQ1NkIHlZAJEORhCCjiAQ
# NUkfnwvO8YPXZmxY5gB6gN8JDYC9Q1Yo7D6TFwckJ5D9yKhRZQ6z/q5Qc1gb+/Ne
# FcTrM3HIiIGDxiNuGrEgRlxOqEMgCpJk307YYczXYE+ScaTa4AcBRLlJXpp6sZuP
# 0/RiLm0339+LWicwDTTSVTCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
# AAQwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTJaFw0yNjA0MTMx
# NzMxNTJaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDhzqDoM6JjpsA7AI9s
# GVAXa2OjdyRRm5pvlmisydGnis6bBkOJNsinMWRn+TyTiK8ElXXDn9v+jKQj55cC
# pprEx3IA7Qyh2cRbsid9D6tOTKQTMfFFsI2DooOxOdhz9h0vsgiImWLyTnW6locs
# vsJib1g1zRIVi+VoWPY7QeM73L81GZxY2NqZk6VGPFbZxaBSxR1rNIeBEJ6TztXZ
# sz/Xtv6jxZdRb3UimCBFqyaJnrlYQUdcpvKGbYtuEErplaZCgV4T4ZaspYIYr+r/
# hGJNow2Edda9a/7/8jnxS07FWLcNorV9DpgvIggYfMPgKa1ysaK/G6mr9yuse6cY
# 0Hv/9Ca6XZk/0dw6Zj9qm2BSfBP7bSD8DfuIN+65XDrJLYujT+Sn+Nv4ny8TgUyo
# iLDEYHIvjzY8xUELep381sVBrwyaPp6exT4cSq/1qv4BtwrC6ZtmokkqZCsZpI11
# Z+TY2h2BxY6aruPKFvHBk6OcuPT9vCexQ1w0B7T2/6qKjPJBB6zwDdRc9xFBvwb5
# zTJo7YgKJ9ZMrvJK7JQnzyTWa03bYI1+1uOK2IB5p+hn1WaGflF9v5L8rlqtW9Nw
# u6S3k91MNDGXnnsQgToD7pcUGl2yM7OQvN0SHsQuTw9U8yNB88KAq0nzhzXt93YL
# 36nEXWURBQVdj9i0Iv42az1xZQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQkRZmhd5AqfMPKg7BuZBaEKvgs
# ZzBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGct
# OF2Vsw0iiR0q3NJryKj6kQ73kJzdU7Jj+FCwghx0zKTaEk7Mu38zVZd9DISUOT9C
# 3IvNfrdN05vkn6c7y3SnPPCLtli8yI2oq8BA7nSww4mfdPeEI+mnE02GgYVXHPZT
# KJDhva86tywsr1M4QVdZtQwk5tH08zTBmwAEiG7iTpVUvEQN7QZJ5Bf9kTs8d9OD
# jgu5+3ggqpiae/UK6iyneCUVixV6AucxZlRnxS070XxAKICi4liEvk6UKSyANv29
# 78dCEsWd6V+Dp1C5sgWyoH0iUKidgoln8doxm9i0DvL0Q5ErhzGW9N60JcAdrKJJ
# cfS54T9P3bBUbRyy/lV1TKPrJWubba+UpgCRcg0q8M4Hz6ziH5OBKGVRrYAK7YVa
# fsnOVNJumTQgTxES5iaS7IT8FOST3dYMzHs/Auefgn7l+S9uONDTw57B+kyGHxK4
# 91AqqZnjQjhbZTIkowxNt63XokWKZKoMKGCcIHqXCWl7SB9uj3tTumult8EqnoHa
# TZ/tj5ONatBg3451w87JAB3EYY8HAlJokbeiF2SULGAAnlqcLF5iXtKNDkS5rpq2
# Mh5WE3Qp88sU+ljPkJBT4kLYfv3Hh387pg4VH1ph7nj8Ia6nt1FQh8tK/X+PQM9z
# oSV/djJbGWhaPzJ5jeQetkVoCVEzCEBfI9DesRf3MIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADdLsJe77QwkkGogAAAAN0uzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDj2ODusMe5KPch1baUwJRlF08R
# O9D474YweDv6+qCWzjANBgkqhkiG9w0BAQEFAASCAYBx4udWI/19EEHJHZPAr5+/
# giE5T9MwsW/lcmm+kgcLqcpv+30+NxWi3gzN2UCP2B2fkhaWmPv8GX+MDhmazvAD
# dEOeSB36ohRj5Fu3wspzMhR23ZhytvKZMfG+9ZjEgO6nsODGo0EG/q6gWMQvtNWr
# Ofz+dzoH0kYK+rrN3l9IZVtrBxxqJUvzfYcqw5Pn1V3B4UoeYJ3/CJm1Z6kL8eJ9
# BfX68tTmAPU2yn4keJI0LFTC5sjt3WdrjByUxeYyGAi7wHpfaM5YarcuS1FdqQEt
# GvGpYoGm1f8tWWhKHhKsLx4TlPbvp6ytOYeJvb8+y8/TFp7zav4RwniOkFmuckdP
# Qj/ONM26yTInDXxR9xbUio7onda2KGzUlFX6Ss7EZvu0va5G/2ADHOQWiC9yEYKC
# 7Zut3JKE0V4IkjtEDxdYjICm7Rw0SJyX2iZf683LyIBhRl8aRXRgv9Avf5aqRPeg
# luQa4T4kgG1BHEHp8E/sFBl8U9SkqC/K6yIz5SEkAPOhghgRMIIYDQYKKwYBBAGC
# NwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgZvG9sVUl+59LWQ95y0V1MuDue+taO0l18cQXpsmB
# jDwCBmfnvmk2MhgTMjAyNTA0MjMyMDUyMjcuNjY1WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAAR+OVCzehYN3HAAAAAABHMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MFoXDTI1MTExOTE4NDg1MFowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDocLpu99z/+NeI
# ZmR32GJg2VT/jd96pYLsvNngeH4qXwK1qVmFaXXkkVbxb1fOQJMukYkba3WEc69W
# /Z4BszAuxguThDVlY9sk4ZYkGMgxoq1Z5inUPvj4Qh8xVvlhiAS6Of/uLwDsbsKl
# g2fGpmvztiPSOL9P15k00I4bsl1vlmRSut2tNwJQ5sXpoT7GI/2T2A0GnWbFECKR
# CyGW9rsny9o0LNIUl4NYAd4awGSs6OIzKPpIK1JfK90wXHvaXwGJcN9P8QPRJIHK
# uFoVGzIUG/C0jQC4rQ62yTGvc2sZ4AxTQwflfVBBaiHq8gn/YDHpZileGkB2IQaz
# ZEiEc5Or5Xer9mUDU+2FEe66w8e2WkLXanqxaD5+Zco+E+QdwcTYGo78jFxPDvNr
# aTr5QAgITc4dY/PBC3cYFzcgDyUx2xOVCBvgabqJxj7rXrj4Bhd2S/ZTYOVHhi8c
# DWBaefM8JgiO8GCIIRvlNWng8FKFt09ZfNxmsSdCJlWw3rNAwsBY1xp8pmmv9r2M
# 9rNIRkZ+sh0xd3GuASWs2bOrqBi0aTzgY9b3CxY+/m+RU+UTim5JkmpJM/AIP68/
# S+1NwFqXK5yxTJBIInhoEgdEHi+a2JR2SlV3AkpJa0/B6sZaoEa+zgshIfFa66XB
# mnnsydV4uG7W1INoaNVwxBKDdmqNRwIDAQABo4IByzCCAccwHQYDVR0OBBYEFORU
# dlggOj7vT7m2XvFhSEW8ht1oMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEADSJUQ9XamDh0gkC1XvrhVz6A
# MwGVKuKJA+tklJzBa4UVYP3Y9r1RLU08RYJIjPEkpwiwDWitK58gsZxwNh4Nc4fF
# iQrZUJZ9BInfnodv8WOO83zY8YQdJMcpgBzeYVXiNCedumqFKXj0mMMuWaBynv7w
# wn7FnHJwzLru4jt4VLeef+BycnYwPoMa75LF/9xZo/0TJ371qtBYdbsceKmNhQUT
# D2vIvvPkHTPH/NA2IkLsQ1Am51nzh52WEDzRCoXeld6+/KClnfsEB1/vfR6pYPxw
# ZTvTZ7uh7y8D6g4hDpEcjIses754W2aRpxTPru6n+z2EzkvHF70B/g5oAodmVTUB
# b+pxpu77UHm0TraVodjfXJJNs+h1RjnCu9Miku2KhPmpBrsSne31y3gXstm5vctp
# 1tFox9amTWvhIV88l1EIC3yX+BN9cGKtL65REl/y8yqa2PIW2i18JMRIr4T7liHf
# X0A6sdPsl7GudLyEVHAWsW8NFVzt/vdyRhzMUpsxhPL1qGQgD45Q+3bgTlel5MWl
# WgYG+b+LLUXR5uiybbIswnORTU/jDycNAx8u4c5+14sen5/fmqcrQa316l7WqcQ6
# rOcoxDFym7k2RVuEhZNQ4XNXCKI7kb8PMrRtMbobV0mryd0UlbQUbPsJuN9nUE2A
# DmgnO3bQGyERvppedCExggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAA
# AABHMA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjMyMDUy
# MjdaMC8GCSqGSIb3DQEJBDEiBCCqSOLwHBltuhHYgr6zmp/iApfCsUucmfIn2vOT
# DXqbszCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIJNm85ZyhQAGGe9QPhd3
# +xvmMKCvfjHhf8tl6mRICsynMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAAAABH
# MIIDXgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# ACAF09m+ILyMNydZT7P3lOLNVFzdoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67Mx8TAiGA8yMDI1MDQyMzA5MzEyOVoYDzIwMjUwNDI0MDkzMTI5WjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDrszHxAgEAMAcCAQACAhOQMAcCAQACAhKOMAoCBQDr
# tINxAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAJ8DgEs80PLww0B6n9aq
# +wJBk3dYQx46tOpe50BYQvHN0iqVvxBv4j2aKE/uCp8uNNsm/P9LDWPp7Z00MdcW
# Nq+AcPWEsVVlFAhdKz47/dDOY4tVX2Or/pZpwTYGewmgykv00fgrHiABWoqR4ACC
# U4Z1LiBjl2ugUuImw1Js6aLPsug1tLSUtNF+vlOuibyyuW6WlBSFuOwdt/sMcVfw
# 5eLzJQOJ1skb1aa2f3k+uMAmklBDnelMYZ+5TH+VJa1/4AFGJSYnRJXDdTZBnCw6
# AOuzuZEmwiGVrwmRZpAkoTtTYjOeK8c6XwqCEN2eK0vPW1UUZDWTwxciVGVmhbSc
# SQkwDQYJKoZIhvcNAQEBBQAEggIAZQAHmZZkxmkQGxyHNCGjKZRVh2Cql1KMqd0t
# gjWaqkQkKDGDDvC+PXMzTKPBARaaV8byXSupehacoSMBXnm/WH7sKQ8pXKwxmSzR
# N6tCgoiyG62qkhJF6n8giuA5Ms+jUAMTRLltaryhCBmubKaeU8l0+A5HptcVPWji
# wZC3FcylLgvR9ftYHLxS1/65h4qk8G0vvt2GQaZyyDTYV29vbInaTMTYLNVjQP+8
# d72vE0aewzP+6RIX73X7X62JIo5iqoKrgG4CiTrmuz2qOpOoIqRrbwPbD+F6lKVQ
# zk6WpUj5tbpkvc5t/ddImjiu9rZMzLD7HZsXejNCsGFyA5BC54siZyFU4BMvZbg9
# biNeR70wp5OF5grkzuN2NqOmOCaIOAVnosB+MFvZQv/E95sMTHnkSApALdi48PoF
# 50EaCnWt9MQU+UFPessFynE47NmpyszQuFzntZtmBg8lyJlHYNaDcTF9jqXzYO5N
# 30xNwBaC4H8bQOf1OgjU6RM3Kb/aLCX12cN3+X1LlgosFre+ixodgXw1g3+xbnJB
# G+Qi02krUZYetUwJJ2izLbzbyYkeAGREahPZsYRRVto3+HntgmmIvbMxowjs+1pb
# zSf3RSod9LUhWmRDbNx/U2wnP54D8E7cvRYWXGBfJJh+QUPZQPgXd7BgY7rWzrm9
# R4Sk0IA=
# SIG # End signature block
