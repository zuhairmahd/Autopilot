function ShowGroupAssignments()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        [string]$accessToken,
        [ValidateSet('Application', 'Autopilot', 'Compliance', 'Configuration', 'All')]
        [string]$AssignmentType = 'All'
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving group assignments for '$GroupName'..."
    Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving group assignments for '$GroupName'..."
    if (-not $accessToken)
    {
        Write-Error "Access token is required."
        Write-Log -logFile $LogFile -Module $functionName -Message "Access token is required." -logLevel "Error"
        return
    }
    else
    {
        Write-Verbose "[$functionName] Access token is present."
        Write-Log -logFile $LogFile -Module $functionName -Message "Access token is present."
    }

    # Get group assignments
    $assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName $GroupName -includeBeta
    if ($assignments -eq 'noGroup')
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "No group found for name '$GroupName'." -logLevel "Warning"
        return $returnValues.noGroupFoundMessage
    }   
    if ($null -eq $assignments -or $assignments.AllAssignments.count -eq 0)
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "No assignments found for group '$GroupName'." -logLevel "Warning"
        return $returnValues.noGroupAssignmentsFoundMessage
    }
    # Filter assignments by type
    if ($AssignmentType -ne 'All')
    {
        $assignments = $assignments.allAssignments | Where-Object { $_.Type -eq $AssignmentType }
        Write-Host "Found $($assignments.Count) assignments of type $AssignmentType"
    }
    else
    {
        Write-Host "Found $($assignments.Count) assignments"   
        $assignments = $assignments.allAssignments
    }
    
    # Display assignments
    $assignments | ForEach-Object {
        if ($AssignmentType -eq 'All')
        {
            Write-Verbose "[$functionName] Displaying the Assignment Type since the AssignmentType is 'All'"
            Write-Log -logFile $LogFile -Module $functionName -Message "Displaying the Assignment Type since the AssignmentType is 'All'"
            Write-Host "Assignment Type: $($_.Type)"
        }
        Write-Host "Name: $($_.Name)"
        if ($null -ne $_.Intent)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "Displaying Intent $($_.Intent)"
            Write-Host "Intent: $($_.Intent)"
        }
    }
    return $true
}
