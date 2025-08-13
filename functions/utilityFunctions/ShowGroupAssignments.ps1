function ShowGroupAssignments()
{
    [CmdletBinding()]
    param (
        $Group,
        [string]$accessToken
    )

    $functionName = $MyInvocation.MyCommand.Name
    
    # Extract group name for logging and display
    $groupName = if ($Group -and $Group.displayName)
    { 
        $Group.displayName 
    }
    elseif ($Group -is [hashtable] -and $Group.ContainsKey('displayName'))
    {
        $Group['displayName']
    }
    elseif ($Group -is [string])
    { 
        $Group 
    }
    else
    { 
        "Unknown" 
    }
    
    Write-Verbose "[$functionName] Retrieving group assignments for '$groupName'..."
    Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving group assignments for '$groupName'..." -logLevel "Information"
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
    Write-Host "Getting group assignments for '$($group.displayName)'..."
    Write-Host "This may take a while..."
    # Get group assignments (fetch once and reuse)
    $global:assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName $Group -includeBeta -verbose 
    if ($assignments -eq 'noGroup')
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "No group found for name '$groupName'." -logLevel "Warning"
        return $returnValues.noGroupFoundMessage
    }   
    if ($null -eq $assignments -or $assignments.AllAssignments.count -eq 0)
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "No assignments found for group '$groupName'." -logLevel "Warning"
        return $returnValues.noGroupAssignmentsFoundMessage
    }
    # Cache all assignments to avoid re-query per selection
    $allAssignments = @($assignments.allAssignments)

    # Create Assignments menu (build once and reuse)
    #region Group Assignments
    $groupAssignmentsMenu = NewMenu -Title "Group Assignments for $groupName" -Description "What type of assignments would you like to see?"
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
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Management Scripts" -Action {
        Write-Host "Selected Assignment Type: Script"
        return 'Script'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show App Protection Policies" -Action {
        Write-Host "Selected Assignment Type: AppProtection"
        return 'AppProtection'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Security Intents (Baselines)" -Action {
        Write-Host "Selected Assignment Type: Intent"
        return 'Intent'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Resource Access Profiles" -Action {
        Write-Host "Selected Assignment Type: ResourceAccess"
        return 'ResourceAccess'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Autopilot Profiles" -Action {
        Write-Host "Selected Assignment Type: AutopilotProfile"
        return 'AutopilotProfile'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Health Scripts" -Action {
        Write-Host "Selected Assignment Type: HealthScript"
        return 'HealthScript'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Configuration Policies (Settings Catalog)" -Action {
        Write-Host "Selected Assignment Type: ConfigurationPolicy"
        return 'ConfigurationPolicy'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Group Policy Configurations" -Action {
        Write-Host "Selected Assignment Type: GroupPolicy"
        return 'GroupPolicy'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Export All Assignments" -Action {
        Write-Host "Displaying all assignments"
        return 'All'
    } -returnsValue
    #endregion Group Assignments

    # Loop: after showing assignments, return to the assignment type menu
    while ($true)
    {
        # Use proper stack operation to maintain menu navigation integrity
        $assignmentType = ShowMenu -Menu $groupAssignmentsMenu -CalledBy 'Custom_GroupAssignmentSubmenu' -StackOperation 'Push'
        # $assignmentType = ShowMenu -Menu $groupAssignmentsMenu -CalledBy 'Action'
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
        # Filter assignments by type for display
        if ($assignmentType -ne 'All')
        {
            # Map display type names to internal property names
            $typePropertyMap = @{
                'Application'         = 'Application'
                'Configuration'       = 'Configuration'
                'Compliance'          = 'Compliance'
                'Script'              = 'Script'
                'AppProtection'       = 'AppProtection'
                'Intent'              = 'Intent'
                'ResourceAccess'      = 'ResourceAccess'
                'AutopilotProfile'    = 'AutopilotProfile'
                'HealthScript'        = 'HealthScript'
                'ConfigurationPolicy' = 'ConfigurationPolicy'
                'GroupPolicy'         = 'GroupPolicy'
            }
            
            $internalType = $typePropertyMap[$assignmentType]
            if ($internalType)
            {
                $selectedAssignments = @($allAssignments | Where-Object { $_.Type -eq $internalType })
            }
            else
            {
                $selectedAssignments = @()
            }
            Write-Host "Found $($selectedAssignments.Count) assignments of type $assignmentType"
        }
        else
        {
            $selectedAssignments = $allAssignments
            Write-Host "Found $($selectedAssignments.Count) assignments"
        }
        # Display assignments
        $selectedAssignments | ForEach-Object {
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
        #export the assignments to a csv file.
        $dateString = (Get-Date -Format "yyyyMMdd")
        $safeGroupName = $groupName -replace '[\\/:*?"<>|]', '_'
        $csvPath = "$pwd\${safeGroupName}-$dateString.csv"
        $selectedAssignments | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Exported assignments to $csvPath"
        Write-Host "Press any key to continue..."
        [void][System.Console]::ReadKey($true)
        # Loop continues to re-show the assignment type menu
    }
    return $returnValues.backoutText
}
