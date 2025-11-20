function GetLastDeviceContactDate()
{
    <#
    .SYNOPSIS
    Determines the most recent contact date for a device across multiple sources.

    .DESCRIPTION
    This function aggregates contact dates from managed device sync, Autopilot device contacts,
    Azure AD sign-ins, and user logons to find the latest contact date. Calculates days since
    last contact and compares against threshold for staleness assessment.

    .PARAMETER accessToken
    Microsoft Graph API access token. This parameter is mandatory.

    .PARAMETER enrollmentState
    Enrollment state object with device contact information. This parameter is mandatory.

    .OUTPUTS
    System.Collections.Hashtable
    Returns hashtable with latestContactDate, numberOfDaysSinceLastContact, withinThreshold, and source dates.

    .EXAMPLE
    $contactInfo = GetLastDeviceContactDate -accessToken $token -enrollmentState $state

    .NOTES
    Aggregates from: managedDevice sync, autopilot contacts, Azure AD sign-ins.
    Compares against deviceContactThresholdInDays setting.
    Returns $null values if no contact dates found.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $goodContactThreshold = $settings.deviceContactThresholdInDays
    $withinThreshold = $false
    Write-Verbose "[$functionName] Getting last device contact date."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting last device contact date." -LogLevel "Verbose"
    $contactDates = @{}
    if ($enrollmentState.managed)
    {
        Write-Verbose "[$functionName] Device is managed, retrieving contact dates."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is managed, retrieving contact dates." -LogLevel "Information"
        $contactDates.add('managedDeviceLastSyncDateTime', $enrollmentState.managedDevice.lastSyncDateTime)
        $contactDates.add('managedDeviceUsersLastLogOnDateTime', $enrollmentState.managedDevice.Users.lastLogOnDateTime)
    }
    if ($enrollmentState.inAutopilot)
    {
        Write-Verbose "[$functionName] Device is in Autopilot, retrieving contact dates."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is in Autopilot, retrieving contact dates." -LogLevel "Information"
        $contactDates.add('autopilotDeviceDeploymentProfileAssignedDateTime', $enrollmentState.autopilot.device.deploymentProfileAssignedDateTime)
        $contactDates.add('autopilotDeviceLastContactedDateTime', $enrollmentState.autopilot.device.lastContactedDateTime)
        $contactDates.add('autopilotDeviceRemediationStateLastModifiedDateTime', $enrollmentState.autopilot.device.remediationStateLastModifiedDateTime)
    }
    if ($enrollmentState.hasDeviceObject)
    {
        Write-Verbose "[$functionName] Device has device object, retrieving additional contact dates."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device has device object, retrieving additional contact dates." -LogLevel "Information"
        $contactDates.add('deviceApproximateLastSignInDateTime', $enrollmentState.device.approximateLastSignInDateTime)
        $contactDates.add('deviceCreatedDateTime', $enrollmentState.device.createdDateTime)
        $contactDates.add('deviceRegistrationDateTime', $enrollmentState.device.registrationDateTime)
    }
    #Figure out the latest contact date
    if ($null -eq $contactDates.Values)
    {
        Write-Verbose "[$functionName] No contact dates found."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No contact dates found." -LogLevel "Warning"
        $contactDates.add('latestContactDate', $null)
        $contactDates.add('numberOfDaysSinceLastContact', $null)
        $contactDates.add('withinThreshold', $withinThreshold)
        return $contactDates
    }
    $latestContactDate = $contactDates.Values | Sort-Object -Descending | Select-Object -First 1
    Write-Verbose "[$functionName] Latest contact date: $latestContactDate"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Latest contact date: $latestContactDate" -LogLevel "Information"
    $contactDates.add('latestContactDate', $latestContactDate)
    $numberOfDaysSinceLastContact = (New-TimeSpan -Start $latestContactDate -End (Get-Date)).Days
    Write-Verbose "[$functionName] Number of days since last contact: $numberOfDaysSinceLastContact"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Number of days since last contact: $numberOfDaysSinceLastContact" -LogLevel "Information"
    $contactDates.add('numberOfDaysSinceLastContact', $numberOfDaysSinceLastContact)
    if ($numberOfDaysSinceLastContact -lt $goodContactThreshold)
    {
        Write-Verbose "[$functionName] Device contact date is within the threshold of $goodContactThreshold days."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device contact date is within the threshold of $goodContactThreshold days." -LogLevel "Information"
        $withinThreshold = $true
    }
    else
    {
        Write-Verbose "[$functionName] Device contact date is outside the threshold of $goodContactThreshold days."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device contact date is outside the threshold of $goodContactThreshold days." -LogLevel "Information"
    }
    $contactDates.add('withinThreshold', $withinThreshold)
    Write-Verbose "[$functionName] Contact dates retrieved successfully."
    return $contactDates
}

