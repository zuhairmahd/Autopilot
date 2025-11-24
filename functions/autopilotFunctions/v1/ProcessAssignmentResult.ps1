function ProcessAssignmentResult()
{
    <#
    .SYNOPSIS
    Processes the result of profile assignment check for an imported Autopilot device.

    .DESCRIPTION
    This function interprets the profile assignment status returned from CheckDeviceAssignment
    and determines next steps. It handles success (profile assigned), timeout scenarios, and
    delegation to HandleDeviceEnrollmentState for enrollment-specific processing.

    .PARAMETER assignmentResult
    Result object from CheckDeviceAssignment containing device assignment status. This parameter is mandatory.

    .PARAMETER serialNumber
    Device serial number for logging and further lookups. This parameter is mandatory.

    .PARAMETER accessToken
    Microsoft Graph API access token for additional operations. This parameter is mandatory.

    .PARAMETER returnValues
    Return values object containing status messages. This parameter is mandatory.

    .PARAMETER domain
    Optional domain for tenant-specific operations.

    .OUTPUTS
    System.String
    Returns status message from returnValues based on assignment result.

    .EXAMPLE
    $result = ProcessAssignmentResult -assignmentResult $assignment -serialNumber "ABC123" -accessToken $token -returnValues $rv

    .NOTES
    Handles successful assignment (profile assigned).
    Handles timeout scenarios (no assignment after retries).
    Delegates enrollment state handling to HandleDeviceEnrollmentState.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $assignment,
        [Parameter(Mandatory = $true)]
        [datetime]$importStart,
        [Parameter(Mandatory = $true)]
        $returnValues
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing assignment result"
    Write-Verbose "[$functionName] The assignment details are: $($assignment | ConvertTo-Json)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing assignment result status=$($assignment.deploymentProfileAssignmentStatus) enrollmentState=$($assignment.enrollmentState)" -LogLevel "Information"
    
    if (-not $assignment)
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        Write-Log -LogFile $LogFile -Module $functionName -Message "Assignment object is null - returning notInIntuneMessage" -LogLevel "Warning"
        return $returnValues.notInIntuneMessage
    }
    
    Write-Verbose "[$functionName] The assignment status is $($assignment.deploymentProfileAssignmentStatus)"    
    if (($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState' -or 
            $assignment.deploymentProfileAssignmentStatus -eq 'assignedInSync') -and 
        $null -ne $assignment.deploymentProfile.displayName)
    {
        $profileAssignmentDate = if ($assignment.deploymentProfileAssignedDateTime)
        {
            $assignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K" 
        }
        
        Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
        Write-Host "The device is successfully assigned to the deployment profile $($assignment.deploymentProfile.displayName) on $profileAssignmentDate." -ForegroundColor Green
        Write-Host "The device enrollment state is $($assignment.enrollmentState). " -ForegroundColor Green -NoNewline
        Write-Log -LogFile $LogFile -Module $functionName -Message "Device assigned to profile $($assignment.deploymentProfile.displayName) on $profileAssignmentDate enrollmentState=$($assignment.enrollmentState)" -LogLevel "Information"
        
        if ($assignment.enrollmentState -eq 'enrolled')
        {
            Write-Host 'The device is enrolled and should be ready for use.' -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Enrollment state enrolled" -LogLevel "Information"
        }        
        if ($assignment.enrollmentState -eq 'notContacted')
        {
            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Enrollment state notContacted" -LogLevel "Verbose"
        }
        
        $importDuration = (Get-Date) - $importStart
        $importMinutes = [int]$importDuration.TotalMinutes
        $importSeconds = $importDuration.Seconds
        Write-Host "Elapsed time to complete: $importMinutes minutes, $importSeconds seconds"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Import and assignment completed in $importMinutes minutes, $importSeconds seconds" -LogLevel "Information"
        if (-not (RestartDevice))
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Device import successful. User chose not to restart." -LogLevel "Information"
            return $returnValues.deviceImportSuccessMessage
        }
    }
    else
    {
        Write-Host 'The device could not be assigned to a deployment profile.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
        Write-Host "The device current assignment status is $($assignment.deploymentProfileAssignmentStatus)."
        Write-Host "The device assignment profile name is $($assignment.deploymentProfile.displayName)."
        Write-Host "The device profile assignment date is $($assignment.deploymentProfileAssignmentDateTime)."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Assignment failure status=$($assignment.deploymentProfileAssignmentStatus) profile=$($assignment.deploymentProfile.displayName)" -LogLevel "Error"
        return $returnValues.deviceImportFailedMessage
    }
}

