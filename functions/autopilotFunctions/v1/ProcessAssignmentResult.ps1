function ProcessAssignmentResult()
{
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
    
    if (-not $assignment)
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
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
        
        if ($assignment.enrollmentState -eq 'notContacted')
        {
            Write-Host 'This is normal for a recently imported device.' -ForegroundColor Green
        }
        
        $importDuration = (Get-Date) - $importStart
        $importMinutes = [int]$importDuration.TotalMinutes
        $importSeconds = $importDuration.Seconds
        Write-Host "Elapsed time to complete: $importMinutes minutes, $importSeconds seconds"
        
        if (-not (RestartDevice))
        {
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
        return $returnValues.deviceImportFailedMessage
    }
}

