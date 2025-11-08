function ShowGroupAssignments()
{
    [CmdletBinding()]
    param (
        $Group,
        [string]$accessToken,
        [string[]]$specialGroups,
        [switch]$ShowIndirectAssignments
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
    
    # Validate access token
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
    
    # Handle special case for group assignments when ShowIndirectAssignments is specified                    
    if ($ShowIndirectAssignments.IsPresent -and $groupName -in $specialGroups                                               )
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving all indirect assignments (All Users and All Devices) without group filter" -logLevel "Information"
        Write-Host "Getting all indirect assignments (All Users and All Devices)..."
        Write-Host "This may take a while..."
        
        # Get only indirect assignments
        $assignments = GetGroupIndirectAssignments -AccessToken $accessToken -IncludeBeta
        
        if ($null -eq $assignments -or $assignments.AllAssignments.count -eq 0)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "No indirect assignments found." -LogLevel "Verbose"
            Write-Host "No indirect assignments found." -ForegroundColor Yellow
            return $returnValues.noGroupAssignmentsFoundMessage
        }
        
        $groupName = "All Users/All Devices"
    }
    else
    {
        # Normal flow: get assignments for specific group
        Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving group assignments for '$groupName'..." -logLevel "Information"
        Write-Host "Getting group assignments for '$groupName'..."
        if ($ShowIndirectAssignments.IsPresent)
        {
            Write-Host "Including indirect assignments (All Users and All Devices)..."
        }
        Write-Host "This may take a while..."
        
        # Get group assignments (fetch once and reuse)
        $assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName $Group -includeBeta -IncludeIndirectAssignments:$ShowIndirectAssignments
        
        if ($assignments -eq 'noGroup')
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "No group found for name '$groupName'." -LogLevel "Verbose"
            return $returnValues.noGroupFoundMessage
        }   
        if ($null -eq $assignments -or $assignments.AllAssignments.count -eq 0)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "No assignments found for group '$groupName'." -LogLevel "Verbose"
            return $returnValues.noGroupAssignmentsFoundMessage
        }
    }
    # Cache all assignments to avoid re-query per selection
    $allAssignments = @($assignments.allAssignments)

    # Create Assignments menu from configuration
    $groupAssignmentsMenu = NewMenu -MenuName "groupAssignmentsMenu"
    if (-not $groupAssignmentsMenu)
    {
        # Fallback to manual creation if config not found
        $groupAssignmentsMenu = NewMenu -Title "Group Assignments for $groupName" -Description "What type of assignments would you like to see?"
    }
    else
    {
        # Update title with actual group name
        $groupAssignmentsMenu.Title = $groupAssignmentsMenu.Title -replace '\$groupName', $groupName
    }
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Application Assignments ($($assignments.AppAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Application"
        return 'Application'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Configurations ($($assignments.ConfigurationAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Configuration"
        return 'Configuration'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Compliance Policies ($($assignments.ComplianceAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Compliance"
        return 'Compliance'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Management Scripts ($($assignments.ScriptAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Script"
        return 'Script'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show App Protection Policies ($($assignments.AppProtectionAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: AppProtection"
        return 'AppProtection'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Security Intents (Baselines) ($($assignments.IntentAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Intent"
        return 'Intent'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Resource Access Profiles ($($assignments.ResourceAccessAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: ResourceAccess"
        return 'ResourceAccess'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Autopilot Profiles ($($assignments.AutopilotAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: AutopilotProfile"
        return 'AutopilotProfile'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Device Health Scripts ($($assignments.HealthScriptAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: HealthScript"
        return 'HealthScript'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Configuration Policies (Settings Catalog) ($($assignments.ConfigurationPolicyAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: ConfigurationPolicy"
        return 'ConfigurationPolicy'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Group Policy Configurations ($($assignments.GroupPolicyAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: GroupPolicy"
        return 'GroupPolicy'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Windows Information Protection Policies ($($assignments.WindowsInformationProtectionAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: WindowsInformationProtection"
        return 'WindowsInformationProtection'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Show Policy Sets ($($assignments.PolicySetAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: PolicySet"
        return 'PolicySet'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "Export All Assignments ($($assignments.AllAssignments.count))" -Action {
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
                'Application'                  = 'Application'
                'Configuration'                = 'Configuration'
                'Compliance'                   = 'Compliance'
                'Script'                       = 'Script'
                'AppProtection'                = 'AppProtection'
                'Intent'                       = 'Intent'
                'ResourceAccess'               = 'ResourceAccess'
                'AutopilotProfile'             = 'AutopilotProfile'
                'HealthScript'                 = 'HealthScript'
                'ConfigurationPolicy'          = 'ConfigurationPolicy'
                'GroupPolicy'                  = 'GroupPolicy'
                'WindowsInformationProtection' = 'WindowsInformationProtection'
                'PolicySet'                    = 'PolicySet'
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
        # Display assignments using Show-PagedContent for large datasets
        if ($selectedAssignments.Count -gt 0)
        {
            # Create display scriptblock for formatting each assignment
            $displayScript = {
                param($assignment)
                
                # Display assignment type if showing all assignments
                if ($assignmentType -eq 'All')
                {
                    Write-Host "Assignment Type: $($assignment.Type)" -ForegroundColor Magenta
                }
                
                Write-Host "Name: $($assignment.Name)" -ForegroundColor White
                
                if ($assignment.Description)
                {
                    Write-Host "  Description: $($assignment.Description)" -ForegroundColor Gray
                }
                
                if ($null -ne $assignment.Intent)
                {
                    Write-Host "  Intent: $($assignment.Intent)" -ForegroundColor Yellow
                }
                
                # Determine and display assignment scope when ShowIndirectAssignments is used
                if ($ShowIndirectAssignments.IsPresent)
                {
                    $scopeDisplay = "Direct"
                    $scopeColor = "Green"
                    
                    # Check if this is an indirect assignment (has AssignmentScope property)
                    if ($assignment.AssignmentScope)
                    {
                        # This assignment came from All Users or All Devices
                        # Check if there's also a direct assignment by looking for duplicate in allAssignments
                        $directMatch = $allAssignments | Where-Object {
                            $_.Name -eq $assignment.Name -and 
                            $_.Type -eq $assignment.Type -and 
                            -not $_.AssignmentScope
                        }
                        
                        if ($directMatch)
                        {
                            $scopeDisplay = "Both (Direct + $($assignment.AssignmentScope))"
                            $scopeColor = "Yellow"
                        }
                        else
                        {
                            $scopeDisplay = "Indirect ($($assignment.AssignmentScope))"
                            $scopeColor = "Cyan"
                        }
                    }
                    else
                    {
                        # No AssignmentScope means this is a direct assignment
                        # Check if there's also an indirect assignment
                        $indirectMatch = $allAssignments | Where-Object {
                            $_.Name -eq $assignment.Name -and 
                            $_.Type -eq $assignment.Type -and 
                            $_.AssignmentScope
                        }
                        
                        if ($indirectMatch)
                        {
                            $indirectScopes = ($indirectMatch | Select-Object -ExpandProperty AssignmentScope -Unique) -join ", "
                            $scopeDisplay = "Both (Direct + $indirectScopes)"
                            $scopeColor = "Yellow"
                        }
                    }
                    
                    Write-Host "  Assignment Scope: $scopeDisplay" -ForegroundColor $scopeColor
                }
                
                Write-Host ""  # Blank line between assignments
            }
            
            # Determine page title
            $pageTitle = if ($assignmentType -eq 'All')
            {
                "All Assignments for '$groupName' ($($selectedAssignments.Count) total)"
            }
            else
            {
                "$assignmentType Assignments for '$groupName' ($($selectedAssignments.Count) total)"
            }
            
            Write-Log -logFile $LogFile -Module $functionName -Message "Displaying $($selectedAssignments.Count) assignments with paging" -LogLevel "Information"
            
            # Use Show-PagedContent for display
            $pagingResult = Show-PagedContent -Content $selectedAssignments `
                -DisplayScriptBlock $displayScript `
                -Title $pageTitle `
                -PageSize 10 `
                -ShowPageInfo $true
            
            Write-Log -logFile $LogFile -Module $functionName -Message "Paging completed with result: $pagingResult" -LogLevel "Verbose"
        }
        else
        {
            Write-Host "No assignments found for the selected type." -ForegroundColor Yellow
            Write-Log -logFile $LogFile -Module $functionName -Message "No assignments found for type: $assignmentType" -LogLevel "Information"
            Write-Host ""
            Write-Host "Press any key to continue..."
            [void][System.Console]::ReadKey($true)
        }
        
        # Export to CSV if showing all assignments
        if ($assignmentType -eq 'All' -and $selectedAssignments.Count -gt 0)
        {
            Write-Verbose "[$functionName] Exporting assignments to CSV"
            Write-Log -logFile $LogFile -Module $functionName -Message "Exporting assignments to CSV"
            $dateString = (Get-Date -Format "yyyyMMdd")
            $safeGroupName = $groupName -replace '[\\/:*?"<>|]', '_'
            $csvPath = "$pwd\${safeGroupName}-$dateString.csv"
            $selectedAssignments | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host ""
            Write-Host "Exported assignments to $csvPath" -ForegroundColor Green
            Write-Log -logFile $LogFile -Module $functionName -Message "Exported assignments to $csvPath" -logLevel "Information"
            Write-Host ""
            Write-Host "Press any key to continue..."
            [void][System.Console]::ReadKey($true)
        }
        # Loop continues to re-show the assignment type menu
    }
    return $returnValues.backoutText
}
