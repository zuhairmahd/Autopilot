function HandleDeviceEnrollmentState()
{
    <#
    .SYNOPSIS
    Processes and handles different Autopilot device enrollment states.

    .DESCRIPTION
    This function interprets the enrollment state of an Autopilot device and takes appropriate
    action based on the state (notContacted, enrolled, enrollmentFailed, etc.). It provides
    user-friendly messages, looks up additional device information when needed, and returns
    appropriate status codes for each state.

    .PARAMETER deviceAssignment
    Device assignment object containing enrollmentState property. This parameter is mandatory.

    .PARAMETER serialNumber
    Device serial number for logging and lookups. This parameter is mandatory.

    .PARAMETER accessToken
    Microsoft Graph API access token for additional lookups. This parameter is mandatory.

    .PARAMETER returnValues
    Return values object containing state-specific messages. This parameter is mandatory.

    .PARAMETER domain
    Optional domain for tenant-specific operations.

    .OUTPUTS
    System.String
    Returns state-specific message from returnValues (notContactedMessage, enrollmentFailedMessage, etc.).

    .EXAMPLE
    $result = HandleDeviceEnrollmentState -deviceAssignment $assignment -serialNumber "ABC123" -accessToken $token -returnValues $rv

    .NOTES
    Handles states: notContacted, enrolled, enrollmentFailed, blocked.
    For 'enrolled' state, looks up additional user and device information.
    Provides context-appropriate messages for each state.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $deviceAssignment,
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$domain
    )

    $functionName = $MyInvocation.MyCommand.Name
    $enrollmentState = $deviceAssignment.enrollmentState
    Write-Verbose "[$functionName] Processing enrollment state: $enrollmentState"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Handling enrollment state '$enrollmentState' for serial $serialNumber" -LogLevel "Information"
    
    switch ($enrollmentState)
    {
        'notContacted'
        {
            Write-Host 'The device has not contacted the enrollment service.' -ForegroundColor Green
            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
            Write-Verbose "[$functionName] Returning the message $($returnValues.notContactedMessage)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "State notContacted - returning message" -LogLevel "Verbose"
            return $returnValues.notContactedMessage
        }
        'enrolled'
        {
            Write-Host 'The device appears to have been enrolled.' -ForegroundColor Red
            Write-Host "Looking up user information..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "State enrolled - querying managed device info" -LogLevel "Information"
            $deviceManagementUri = "deviceManagement/managedDevices"
            $managedDeviceFilter = "serialNumber eq '$serialNumber'"
            $managedDevice = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -Filter $managedDeviceFilter).value
            Write-Verbose "[$functionName] Managed device user principal name: $($managedDevice.userPrincipalName)"
            Write-Verbose "[$functionName] Managed device user display name: $($managedDevice.userDisplayName)"
            Write-Verbose "[$functionName] Managed device last logon date: $($managedDevice.usersLoggedOn.lastLogOnDateTime)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "ManagedDevice upn=$($managedDevice.userPrincipalName) lastLogon=$($managedDevice.usersLoggedOn.lastLogOnDateTime)" -LogLevel "Debug"

            $hasUser = $false
            if ($managedDevice.userPrincipalName -match $domain)
            {
                $normalizedUser = NormalizeADUserDisplayName -UserDisplayName $managedDevice.userDisplayName
                Write-Host "The device is registered to the user $($normalizedUser.Fullname) with the email address $($managedDevice.userPrincipalName)." -ForegroundColor Red
                $hasUser = $true
                Write-Log -LogFile $LogFile -Module $functionName -Message "Device enrolled to $($normalizedUser.Fullname) ($($managedDevice.userPrincipalName))" -LogLevel "Information"
            }
            else 
            {
                Write-Host "Cannot determine logged on user."
                Write-Log -LogFile $LogFile -Module $functionName -Message "No matching user principal name for domain filter $domain" -LogLevel "Warning"
            }

            if ($null -ne $managedDevice.usersLoggedOn.lastLogOnDateTime)
            {
                $LastLogonDate = ($managedDevice.usersLoggedOn.lastLogOnDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K") 
                if ($hasUser)
                {
                    Write-Host "The last logon date for $($normalizedUser.FirstName) was $LastLogonDate." -ForegroundColor Red
                }
                else
                {
                    Write-Host "The last logon date was $LastLogonDate." -ForegroundColor Red
                }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Last logon date $LastLogonDate (hasUser=$hasUser)" -LogLevel "Verbose"
            }
            else 
            {
                Write-Host "The last logon date is not available." -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $functionName -Message "Last logon date not available" -LogLevel "Warning"
            }
            
            Write-Host "The device needs to be cleaned before giving to another user." -ForegroundColor Red
            return $returnValues.EnrolledMessage
        }
        'pendingReset'
        {
            Write-Host 'The device is pending a reset.' -ForegroundColor Yellow
            Write-Host "The device needs to be allowed to finish the reset." -ForegroundColor Yellow
            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Yellow
            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "State pendingReset - advising wait" -LogLevel "Information"
            return $returnValues.PendingResetMessage
        }
        'enrollmentFailed'
        {
            Write-Host 'The device enrollment failed.' -ForegroundColor Red
            Write-Host 'This may cause issues when the user logs on for the first time.' -ForegroundColor Red
            Write-Host "This means someone has already unsuccessfully tried to enroll the device." -ForegroundColor Red
            Write-Host "It is likely the next user may experience issues when logging on for the first time." -ForegroundColor Red
            Write-Host "Please check the Intune portal or contact an Intune administrator." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "State enrollmentFailed" -LogLevel "Error"
            return $returnValues.EnrollmentFailedMessage
        }
        default
        {
            Write-Host "The device enrollment state is $enrollmentState." -ForegroundColor Red
            Write-Host 'Please check the Intune portal or contact an Intune administrator before you give the device to a user.' -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Unknown enrollment state $enrollmentState" -LogLevel "Warning"
            return $null
        }
    }
}


