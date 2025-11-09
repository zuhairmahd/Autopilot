function ShowGroupAssignments()
{
    [CmdletBinding()]
    param (
        $Group,
        [string]$accessToken,
        [string[]]$specialGroups,
        [switch]$exportInstead,
        [switch]$ShowIndirectAssignments,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings
    )

    $functionName = $MyInvocation.MyCommand.Name
    #region process initial setup
    #define the action type
    if ($exportInstead.IsPresent)
    {
        $actionType = "Export"
    }
    else
    {
        $actionType = "Show"
    }           
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
    
    # Log Settings parameter
    Write-Verbose "[$functionName] Settings provided: $($null -ne $Settings)"
    Write-Log -logFile $LogFile -Module $functionName -Message "Settings provided: $($null -ne $Settings)" -logLevel "Information"
    if ($Settings -and $Settings.operatingSystem)
    {
        Write-Verbose "[$functionName] Settings.operatingSystem: $($Settings.operatingSystem)"
        Write-Log -logFile $LogFile -Module $functionName -Message "Settings.operatingSystem: $($Settings.operatingSystem)" -logLevel "Information"
    }
    
    # Handle special case for group assignments when ShowIndirectAssignments is specified                    
    if ($ShowIndirectAssignments.IsPresent -and $groupName -in $specialGroups                                               )
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving all indirect assignments (All Users and All Devices) without group filter" -logLevel "Information"
        Write-Host "Getting all indirect assignments (All Users and All Devices)..."
        Write-Host "This may take a while..."
        
        # Get only indirect assignments
        $assignments = GetGroupIndirectAssignments -AccessToken $accessToken -IncludeBeta -Settings $Settings
        
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
        $assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName $Group -includeBeta -IncludeIndirectAssignments:$ShowIndirectAssignments -Settings $Settings
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
    
    # Consolidate duplicate assignments with multiple scopes
    Write-Verbose "[$functionName] Consolidating duplicate assignments with multiple scopes"
    Write-Log -logFile $LogFile -Module $functionName -Message "Consolidating duplicate assignments (before: $($allAssignments.Count) entries)" -logLevel "Verbose"
    
    # Group assignments by unique identifier (Type + Name + Id)
    $groupedAssignments = $allAssignments | Group-Object -Property { "$($_.Type)|$($_.Name)|$($_.Id)" }
    
    # Consolidate each group
    $consolidatedAssignments = @()
    foreach ($group in $groupedAssignments)
    {
        if ($group.Count -eq 1)
        {
            # Single assignment - create new object with AssignmentScope array
            $assignment = $group.Group[0]
            $scopeArray = if ($assignment.AssignmentScope)
            {
                # Has indirect scope
                @($assignment.AssignmentScope)
            }
            else
            {
                # Direct assignment only
                @("Direct")
            }
            
            # Create new consolidated object
            $consolidatedAssignments += [PSCustomObject]@{
                Type            = $assignment.Type
                Name            = $assignment.Name
                Description     = $assignment.Description
                Id              = $assignment.Id
                Intent          = $assignment.Intent
                Target          = $assignment.Target
                Settings        = $assignment.Settings
                AssignmentScope = $scopeArray
            }
        }
        else
        {
            # Multiple assignments - consolidate into one with combined scopes
            $primaryAssignment = $group.Group[0]
            
            # Collect all unique scopes
            $allScopes = @()
            foreach ($assignment in $group.Group)
            {
                if ($assignment.AssignmentScope)
                {
                    # Indirect assignment
                    $allScopes += $assignment.AssignmentScope
                }
                else
                {
                    # Direct assignment
                    $allScopes += "Direct"
                }
            }
            
            # Remove duplicates and sort for consistency
            $uniqueScopes = @($allScopes | Select-Object -Unique | Sort-Object)
            
            # Create new consolidated object with combined scopes
            $consolidatedAssignments += [PSCustomObject]@{
                Type            = $primaryAssignment.Type
                Name            = $primaryAssignment.Name
                Description     = $primaryAssignment.Description
                Id              = $primaryAssignment.Id
                Intent          = $primaryAssignment.Intent
                Target          = $primaryAssignment.Target
                Settings        = $primaryAssignment.Settings
                AssignmentScope = $uniqueScopes
            }
        }
    }
    
    # Replace allAssignments with consolidated version
    $allAssignments = @($consolidatedAssignments)
    Write-Verbose "[$functionName] Consolidation complete (after: $($allAssignments.Count) entries)"
    Write-Log -logFile $LogFile -Module $functionName -Message "Consolidation complete (after: $($allAssignments.Count) entries)" -logLevel "Information"
    
    # Update the assignments object with consolidated data
    # Re-categorize the consolidated assignments
    $assignments.AllAssignments = $allAssignments
    $assignments.AppAssignments = @($allAssignments | Where-Object { $_.Type -eq 'Application' })
    $assignments.ConfigurationAssignments = @($allAssignments | Where-Object { $_.Type -eq 'Configuration' })
    $assignments.ComplianceAssignments = @($allAssignments | Where-Object { $_.Type -eq 'Compliance' })
    $assignments.ScriptAssignments = @($allAssignments | Where-Object { $_.Type -eq 'Script' })
    $assignments.AppProtectionAssignments = @($allAssignments | Where-Object { $_.Type -eq 'AppProtection' })
    $assignments.IntentAssignments = @($allAssignments | Where-Object { $_.Type -eq 'Intent' })
    $assignments.ResourceAccessAssignments = @($allAssignments | Where-Object { $_.Type -eq 'ResourceAccess' })
    $assignments.AutopilotAssignments = @($allAssignments | Where-Object { $_.Type -eq 'AutopilotProfile' })
    $assignments.HealthScriptAssignments = @($allAssignments | Where-Object { $_.Type -eq 'HealthScript' })
    $assignments.ConfigurationPolicyAssignments = @($allAssignments | Where-Object { $_.Type -eq 'ConfigurationPolicy' })
    $assignments.GroupPolicyAssignments = @($allAssignments | Where-Object { $_.Type -eq 'GroupPolicy' })
    $assignments.WindowsInformationProtectionAssignments = @($allAssignments | Where-Object { $_.Type -eq 'WindowsInformationProtection' })
    $assignments.PolicySetAssignments = @($allAssignments | Where-Object { $_.Type -eq 'PolicySet' })
    #endregion                  
    
    #region Build and show assignment type menu    
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
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Application Assignments ($($assignments.AppAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Application"
        return 'Application'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType           Device Configurations ($($assignments.ConfigurationAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Configuration"
        return 'Configuration'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Device Compliance Policies ($($assignments.ComplianceAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Compliance"
        return 'Compliance'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Device Management Scripts ($($assignments.ScriptAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Script"
        return 'Script'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType App Protection Policies ($($assignments.AppProtectionAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: AppProtection"
        return 'AppProtection'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Security Intents (Baselines) ($($assignments.IntentAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: Intent"
        return 'Intent'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Resource Access Profiles ($($assignments.ResourceAccessAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: ResourceAccess"
        return 'ResourceAccess'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Autopilot Profiles ($($assignments.AutopilotAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: AutopilotProfile"
        return 'AutopilotProfile'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Device Health Scripts ($($assignments.HealthScriptAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: HealthScript"
        return 'HealthScript'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Configuration Policies (Settings Catalog) ($($assignments.ConfigurationPolicyAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: ConfigurationPolicy"
        return 'ConfigurationPolicy'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Group Policy Configurations ($($assignments.GroupPolicyAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: GroupPolicy"
        return 'GroupPolicy'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Windows Information Protection Policies ($($assignments.WindowsInformationProtectionAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: WindowsInformationProtection"
        return 'WindowsInformationProtection'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Policy Sets ($($assignments.PolicySetAssignments.count))" -Action {
        Write-Host "Selected Assignment Type: PolicySet"
        return 'PolicySet'
    } -returnsValue
    $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType  All Assignments ($($assignments.AllAssignments.count))" -Action {
        Write-Host "Displaying all assignments"
        return 'All'
    } -returnsValue
    #endregion

    # Loop: after showing assignments, return to the assignment type menu
    while ($true)
    {
        # Use proper stack operation to maintain menu navigation integrity
        $assignmentType = ShowMenu -Menu $groupAssignmentsMenu -CalledBy 'Custom_GroupAssignmentSubmenu' -StackOperation 'Push'
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
        
        #region Process assignments
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
        # Process assignments based on export or display mode
        if ($selectedAssignments.Count -gt 0)
        {
            if ($exportInstead.IsPresent)
            {
                # Export mode: Generate export filename and export assignments to CSV
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $sanitizedGroupName = $groupName -replace '[\\/:*?"<>|]', '_'
                $exportTypeLabel = if ($assignmentType -eq 'All') { 'AllAssignments' } else { $assignmentType }
                $exportFileName = "GroupAssignments_${sanitizedGroupName}_${exportTypeLabel}_${timestamp}.csv"
                $exportPath = Join-Path -Path $env:TEMP -ChildPath $exportFileName
                
                Write-Host "Exporting $($selectedAssignments.Count) assignments to CSV..." -ForegroundColor Cyan
                Write-Log -logFile $LogFile -Module $functionName -Message "Exporting $($selectedAssignments.Count) assignments to: $exportPath" -LogLevel "Information"
                
                try
                {
                    # Prepare export data with all relevant properties
                    $exportData = $selectedAssignments | ForEach-Object {
                        $assignment = $_
                        
                        # Format AssignmentScope array for CSV export
                        $scopeValue = if ($assignment.AssignmentScope -and $assignment.AssignmentScope.Count -gt 0)
                        {
                            $assignment.AssignmentScope -join ", "
                        }
                        else
                        {
                            "Direct"
                        }
                        
                        # Create export object with all relevant properties
                        [PSCustomObject]@{
                            GroupName       = $groupName
                            Type            = $assignment.Type
                            Name            = $assignment.Name
                            Description     = if ($assignment.Description) { $assignment.Description } else { "" }
                            Id              = $assignment.Id
                            Intent          = if ($null -ne $assignment.Intent) { $assignment.Intent } else { "" }
                            AssignmentScope = $scopeValue
                            Target          = if ($assignment.Target) { ($assignment.Target | ConvertTo-Json -Compress -Depth 10) } else { "" }
                            Settings        = if ($assignment.Settings) { ($assignment.Settings | ConvertTo-Json -Compress -Depth 10) } else { "" }
                        }
                    }
                    
                    # Export to CSV
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
                    
                    Write-Host "Export completed successfully!" -ForegroundColor Green
                    Write-Host "File location: $exportPath" -ForegroundColor White
                    Write-Log -logFile $LogFile -Module $functionName -Message "Export completed: $exportPath" -LogLevel "Information"
                    
                    # Offer to open the file
                    Write-Host ""
                    $openChoice = Read-Host "Would you like to open the exported file? (yes/no)"
                    if ($openChoice -in @('yes', 'y'))
                    {
                        Start-Process $exportPath
                        Write-Log -logFile $LogFile -Module $functionName -Message "User opened exported file: $exportPath" -LogLevel "Verbose"
                    }
                }
                catch
                {
                    Write-Host "Error exporting assignments: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log -logFile $LogFile -Module $functionName -Message "Export failed: $($_.Exception.Message)" -LogLevel "Error"
                }
                
                Write-Host ""
                Write-Host "Press any key to continue..."
                [void][System.Console]::ReadKey($true)
            }
            else
            {
                # Display mode: Show assignments using Show-PagedContent for large datasets
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
                    
                    # Display assignment scope (always an array after consolidation)
                    if ($assignment.AssignmentScope -and $assignment.AssignmentScope.Count -gt 0)
                    {
                        $scopeDisplay = $assignment.AssignmentScope -join ", "
                        
                        # Color coding based on scope types
                        $scopeColor = "Green"  # Default for Direct only
                        if ($assignment.AssignmentScope.Count -gt 1)
                        {
                            # Multiple scopes (e.g., Direct + All Users + All Devices)
                            $scopeColor = "Yellow"
                        }
                        elseif ($assignment.AssignmentScope[0] -ne "Direct")
                        {
                            # Indirect only (All Users or All Devices)
                            $scopeColor = "Cyan"
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
        }
        else
        {
            Write-Host "No assignments found for the selected type." -ForegroundColor Yellow
            Write-Log -logFile $LogFile -Module $functionName -Message "No assignments found for type: $assignmentType" -LogLevel "Information"
            Write-Host ""
            Write-Host "Press any key to continue..."
            [void][System.Console]::ReadKey($true)
        }
        #endregion

        # Loop continues to re-show the assignment type menu
    }
    return $returnValues.backoutText
}
