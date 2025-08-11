function ShowGroupAssignments()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        [string]$accessToken
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
    #Create Assignments menu
    
    #region Group Assignments
    $groupAssignmentsMenu = NewMenu -Title "Group Assignments for $GroupName" -Description "What type of assignments would you like to see?"
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Application Assignments" -Action {
        Write-Host "Selected Assignment Type: Application"
        return 'Application'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Configurations" -Action {
        Write-Host "Selected Assignment Type: Configuration"
        return 'Configuration'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Compliance Policies" -Action {
        Write-Host "Selected Assignment Type: Compliance"
        return 'Compliance'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Autopilot Profiles" -Action {
        Write-Host "Selected Assignment Type: Autopilot"
        return 'Autopilot'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Export All Assignments" -Action {
        Write-Host "Displaying all assignments"
        return 'All'
    } -returnsValue
    # Use proper stack operation to maintain menu navigation integrity
    $assignmentType = ShowMenu -Menu $groupAssignmentsMenu -CalledBy 'Custom_GroupAssignmentSubmenu' -StackOperation 'Push'
    #endregion Group Assignments
    
    # Validate that we got a proper assignment, not a navigation option
    if ($assignmentType -eq "Back" -or $assignmentType -eq "Main Menu" -or $assignmentType -eq 0 -or $assignmentType -eq "0")
    {
        Write-Verbose "[$functionName] ShowMenu returned navigation option: '$assignmentType', treating as navigation"
        return $assignmentType
    }
    
    # If assignmentType is null, user may have navigated away - don't continue processing
    if ($null -eq $assignmentType)
    {
        Write-Verbose "[$functionName] ShowMenu returned null, user may have navigated away"
        return $null
    }

    # Filter assignments by type
    if ($assignmentType -ne 'All')
    {
        $assignments = @($assignments.allAssignments | Where-Object { $_.Type -eq $assignmentType })
        Write-Host "Found $($assignments.Count) assignments of type $assignmentType"
    }
    else
    {
        Write-Host "Found $($assignments.Count) assignments"   
        $assignments = $assignments.allAssignments
    }
    
    # Display assignments
    $assignments | ForEach-Object {
        if ($assignmentType -eq 'All')
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
    
    # Add pause after displaying assignments
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    try 
    {
        $null = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
    }
    catch 
    {
        Write-Verbose "[$functionName] Error reading key input: $_"
        # Fallback to Read-Host if RawUI fails
        Read-Host "Press Enter to continue"
    }
    
    # Return a special value to indicate successful completion
    return "AssignmentsDisplayed"
}
