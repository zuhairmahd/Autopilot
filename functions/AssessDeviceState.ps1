function AssessDeviceState() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState
    )
    #see if the device has a user.
    $deviceState = [ordered] @{}
    $user = @{
        IntunePrimaryUserId   = $enrollmentState.managedDevice.device.userId # Note: Potential inconsistency
        IntunePrimaryUPN      = $enrollmentState.managedDevice.device.userPrincipalName
        IntuneUserDisplayName = $enrollmentState.managedDevice.device.userDisplayName
    }
    #If any of the values in the hashtable above are not null, the device is considered to have a user.
    if ($null -ne $user.IntunePrimaryUserId -and $null -ne $user.IntunePrimaryUPN -and $null -ne $user.IntuneUserDisplayName)
    {
        
        $deviceHasUser = $true
        Write-Verbose "Device has a user: $deviceHasUser" 
    }
    else
    {
        $deviceHasUser = $false
        Write-Verbose "Device has a user: $deviceHasUser"
    }
    $deviceEnrollment = @{
        IntuneAutopilotEnrolled = $enrollmentState.managedDevice.device.autopilotEnrolled
        IntuneRegistrationState = $enrollmentState.managedDevice.device.deviceRegistrationState
        AutopilotState          = $enrollmentState.autopilot.device.enrollmentState
    }
    #If the device is enrolled in autopilot, it is considered to be enrolled.
    if ($deviceEnrollment.IntuneAutopilotEnrolled -eq $true -and $deviceEnrollment.AutopilotState -eq 'Enrolled')
    {
        $deviceIsEnrolled = $true
        Write-Verbose "Device is enrolled: $deviceIsEnrolled"
    }
    else
    {
        $deviceIsEnrolled = $false
        Write-Verbose "Device is enrolled: $deviceIsEnrolled"
    }
    $deviceState.add('DeviceHasUser', $deviceHasUser)
    $deviceState.add('DeviceIsEnrolled', $deviceIsEnrolled)
    Write-Verbose "Device State: $deviceState"
    return $deviceState
}