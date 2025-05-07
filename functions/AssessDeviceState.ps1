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
            Write-Host ":Checking whether the device has enough RAM..."
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
                    Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
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
    $managedDeviceProperties.Add('OrphanDevice', $orphanDevice)
    $managedDeviceProperties.Add('CorrectRam', $correctRam)
    $managedDeviceProperties.Add('HasUser', $hasUser)
    $managedDeviceProperties.Add('ValidUser', $validUser)
    $managedDeviceProperties.Add('LastLogonDate', $lastLogonDate)
    return $managedDeviceProperties
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
                Write-Host "Checking whether the device is assigned to the correct autopilot profile..."
                if ($enrollmentState.autopilot.device.deploymentProfile.displayName -in $settings.DesiredAutopilotProfiles)
                {
                    Write-Host "The device is assigned to the correct autopilot profile."
                    $correctProfile = $true
                }
                else
                {
                    Write-Host "The device is not assigned to the correct autopilot profile."
                    Write-Host "You may want to contact an Intune admin."
                    $correctProfile = $false
                }
                Write-Host "Autopilot profile Deployment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)."
                Write-Host "Assignment date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime |FormatDateWithTimeZone)"
                Write-Host "Assigned profile name: $($enrollmentState.autopilot.device.deploymentProfile.displayname)"
                if ($correctProfile -eq $false)
                {
                    Write-Host "The device is not assigned to the correct autopilot profile."
                    Write-Host "You may want to contact an Intune admin."
                    $readinessState = 'NotReady'
                    $action = 'ContactAdmin'
                    $device = 'None'
                }
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
                                    Write-Verbose "User display name: $($enrollmentState.managedDevice.users.userDisplayName)"
                                    Write-Verbose "User id: $($enrollmentState.managedDevice.device.userId)"
                                    Write-Verbose "User principal name: $($enrollmentState.managedDevice.users.userPrincipalName)"
                                    if ($enrollmentState.managedDevice.users.azureUser)
                                    {
                                        $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.users.userDisplayName
                                        Write-Host "This device is registered to $($normalizedUsername.FullName) ($($enrollmentState.managedDevice.users.userPrincipalName))"
                                        if ($null -ne $enrollmentState.managedDevice.users.lastLogOnDateTime)
                                        {
                                            Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $($enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone)"
                                        }
                                        else
                                        {
                                            Write-Host "Cannot determine the last time $($normalizedUsername.FirstName) logged on..."
                                        }
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
                                    Write-Verbose "Checking whether the user is an Azure user..."
                                    if ($enrollmentState.managedDevice.users.azureUser)
                                    {
                                        $normalizedUsername = ConvertUserDisplayName -UserDisplayName $enrollmentState.managedDevice.users.userDisplayName
                                        Write-Host "This device is registered to $($normalizedUsername.FullName) ($($enrollmentState.managedDevice.users.userPrincipalName))"
                                        if ($null -ne $enrollmentState.managedDevice.users.lastLogOnDateTime)
                                        {
                                            Write-Host "$($enrollmentState.managedDevice.users.user.givenName) last logged on on $($enrollmentState.managedDevice.users.lastLogonDateTime | FormatDateWithTimeZone)"
                                        }
                                        else
                                        {
                                            Write-Host "Cannot determine the last time $($normalizedUsername.FirstName) logged on..."
                                        }
                                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                                        $readinessState = 'NotReady'
                                        $action = 'WipeOrClean'
                                        $device = $enrollmentState.managedDevice.device.id
                                    }
                                }
                                else
                                {
                                    Write-Host "The device is not associated with a user."
                                    Write-Host "You may give this device to the next user."
                                    $readinessState = 'Ready'
                                    $action = 'None'
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
    Write-Verbose "Returning readiness state: $readinessState"
    Write-Verbose "Returning action: $action"
    Write-Verbose "Returning device: $device"
    return $returnValue
}
