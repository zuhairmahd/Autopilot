function DisplayDeviceAssignmentStatus()
{
    <#
        .SYNOPSIS
            Display assignment / enrollment information for an Autopilot device.
        .DESCRIPTION
            Previous implementation returned only a boolean. This refactored version returns a rich object
            containing the raw status values, derived/normalized properties, formatted dates, and messages
            that the caller can use for subsequent logic or UI presentation. All pathways are logged using
            Write-Log for improved diagnostics.
        .OUTPUTS
            PSCustomObject with properties:
              - IsAssigned            [bool]
              - AssignmentStatus      [string]
              - EnrollmentState       [string]
              - DeploymentProfileName [string]
              - DeploymentProfileId   [string]
              - AssignmentDateRaw     [datetime|null]
              - AssignmentDateDisplay [string]
              - StatusCategory        [Assigned|Pending|Unassigned|Problem|Unknown]
              - Messages              [string[]]
              - OriginalObject        [object] (the original assignment object)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $deviceAssignment
    )

    $functionName = $MyInvocation.MyCommand.Name
    # Initialize ordered hashtable for predictable property order
    $returnObject = [ordered]@{
        IsAssigned            = $false
        AssignmentStatus      = $null
        EnrollmentState       = $null
        DeploymentProfileName = $null
        DeploymentProfileId   = $null
        AssignmentDateRaw     = $null
        AssignmentDateDisplay = $null
        StatusCategory        = 'Unknown'
        Messages              = @()
        OriginalObject        = $deviceAssignment
    }

    if (-not $deviceAssignment)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Null deviceAssignment object passed to function" -LogLevel "Error"
        $returnObject.Messages += 'No assignment object provided.'
        return [PSCustomObject]$returnObject
    }

    $status = $deviceAssignment.deploymentProfileAssignmentStatus
    $enrollmentState = $deviceAssignment.enrollmentState
    $profileName = $deviceAssignment.deploymentProfile.displayName
    $profileId = $deviceAssignment.deploymentProfile.id
    $assignedDate = $deviceAssignment.deploymentProfileAssignedDateTime

    $returnObject.AssignmentStatus = $status
    $returnObject.EnrollmentState = $enrollmentState
    $returnObject.DeploymentProfileName = $profileName
    $returnObject.DeploymentProfileId = $profileId
    $returnObject.AssignmentDateRaw = $assignedDate

    Write-Log -LogFile $LogFile -Module $functionName -Message "Evaluating assignment status='$status' enrollmentState='$enrollmentState' profile='$profileName'" -LogLevel "Information"
    Write-Verbose "[$functionName] AssignmentStatus=$status EnrollmentState=$enrollmentState Profile=$profileName"

    switch ($status)
    {
        'assignedInSync'
        {
            $returnObject.StatusCategory = 'Assigned' 
        }
        'assignedUnkownSyncState'
        {
            $returnObject.StatusCategory = 'Assigned' 
        }
        'unassigned'
        {
            $returnObject.StatusCategory = 'Unassigned' 
        }
        'pending'
        {
            $returnObject.StatusCategory = 'Pending' 
        }
        default
        {
            $returnObject.StatusCategory = 'Problem' 
        }
    }

    if ($status -in @('assignedInSync', 'assignedUnkownSyncState'))
    {
        $returnObject.IsAssigned = $true
        if ($assignedDate)
        {
            try
            {
                $returnObject.AssignmentDateDisplay = ($assignedDate | FormatDateWithTimeZone) 
            }
            catch
            {
                $returnObject.AssignmentDateDisplay = ($assignedDate | Get-Date -Format 'G') 
            }
        }
        $msg1 = 'The device is already in Intune and is assigned to a profile.'
        $msg2 = if ($profileName -and $returnObject.AssignmentDateDisplay)
        {
            "Assigned to profile '$profileName' on $($returnObject.AssignmentDateDisplay)." 
        }
        elseif ($profileName)
        {
            "Assigned to profile '$profileName'." 
        }
        else
        {
            'Device assigned to a profile.' 
        }
        $msg3 = "Enrollment state: $enrollmentState"
        $returnObject.Messages += @($msg1, $msg2, $msg3)
        Write-Host $msg1 -ForegroundColor Green
        if ($msg2)
        {
            Write-Host $msg2 -ForegroundColor Green 
        }
        Write-Host $msg3 -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $functionName -Message "Device assigned profile='$profileName' date='$assignedDate' enrollmentState='$enrollmentState'" -LogLevel 'Information'
    }
    elseif ($status -eq 'unassigned')
    {
        $msg1 = 'The device is not assigned to a deployment profile.'
        $msg2 = 'Please check the Intune portal or contact an Intune administrator.'
        $returnObject.Messages += @($msg1, $msg2)
        Write-Host $msg1 -ForegroundColor Red
        Write-Host $msg2 -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message 'Device unassigned' -LogLevel 'Warning'
    }
    elseif ($status -eq 'pending')
    {
        $msg1 = 'The device is pending assignment to a deployment profile.'
        $msg2 = 'Please check again after a little while.'
        $returnObject.Messages += @($msg1, $msg2)
        Write-Host $msg1 -ForegroundColor Yellow
        Write-Host $msg2 -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $functionName -Message 'Device assignment pending' -LogLevel 'Information'
    }
    else
    {
        $msg1 = "The device is in Intune but there is an issue with its profile assignment: $status"
        $msg2 = 'Please check the Intune portal or contact an Intune administrator.'
        $returnObject.Messages += @($msg1, $msg2)
        Write-Host $msg1 -ForegroundColor Red
        Write-Host $msg2 -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Unexpected assignment status '$status'" -LogLevel 'Error'
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message "Returning IsAssigned=$($returnObject.IsAssigned) StatusCategory=$($returnObject.StatusCategory)" -LogLevel 'Verbose'
    return $returnObject
}

