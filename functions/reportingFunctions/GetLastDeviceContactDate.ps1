function GetLastDeviceContactDate()
{
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

