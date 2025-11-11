function ShowGroupAssignments()
{
    <#
.SYNOPSIS
    Displays or exports Microsoft Intune policy and profile assignments for a specified group or special assignment scenarios.

.DESCRIPTION
    ShowGroupAssignments retrieves and displays Intune assignments for various resource types including applications, 
    device configurations, compliance policies, scripts, and more. The function supports multiple operational modes:
    
    - Direct group assignments: Show assignments targeted to a specific Azure AD group
    - Indirect assignments: Show assignments targeted to "All Users" and "All Devices"
    - Unassigned resources: Show resources with no assignments at all
    - Export mode: Export assignment data to CSV instead of displaying
    
    The function consolidates duplicate assignments with multiple scopes (Direct, All Users, All Devices) into 
    single entries for cleaner display. It provides an interactive menu to filter assignments by type and supports 
    paginated display for large result sets.

.PARAMETER Group
    The Azure AD group object, hashtable, or group name (string) for which to retrieve assignments.
    Not required when using -ShowOnlyUnassigned with special groups.

.PARAMETER accessToken
    Required. The Microsoft Graph API access token for authentication.

.PARAMETER specialGroups
    Array of special group names (e.g., "All Users", "All Devices") that trigger specific handling 
    when combined with -ShowIndirectAssignments.

.PARAMETER exportInstead
    Switch parameter. When present, exports assignment data to CSV file instead of displaying interactively.

.PARAMETER ExportFilePath
    Directory path where CSV exports should be saved. If not specified, uses current directory.
    Only relevant when -exportInstead is used.

.PARAMETER ShowOnlyUnassigned
    Switch parameter. When present, retrieves and displays only resources that have no assignments 
    (not assigned to any group, user, or device).

.PARAMETER ShowIndirectAssignments
    Switch parameter. When used with a specific group, includes indirect assignments (All Users/All Devices) 
    in addition to direct group assignments. When used with special groups, shows only indirect assignments.

    .PARAMETER HideEmptyMenus
    Switch parameter. When present, assignment type menu will omit options for assignment types with zero entries.                      

.PARAMETER Settings
    Hashtable containing configuration settings, including:
    - operatingSystem: Filter criteria for OS-specific resources
    - knownProblemGraphEndpoints: Array of Graph API endpoints with known issues to suppress warnings

.OUTPUTS
    Returns navigation values for menu system:
    - "Back": User navigated back
    - "Main Menu": User returned to main menu
    - Return value messages for specific scenarios (no assignments found, etc.)

.EXAMPLE
    ShowGroupAssignments -Group "Finance-Users" -accessToken $token
    
    Displays all assignment types for the "Finance-Users" group in an interactive menu.

.EXAMPLE
    ShowGroupAssignments -Group "IT-Admins" -accessToken $token -ShowIndirectAssignments
    
    Displays direct assignments to "IT-Admins" plus all indirect assignments (All Users/All Devices).

.EXAMPLE
    ShowGroupAssignments -Group "All Users" -accessToken $token -ShowIndirectAssignments -specialGroups @("All Users", "All Devices")
    
    Displays only indirect assignments (All Users and All Devices) without filtering to a specific group.

.EXAMPLE
    ShowGroupAssignments -accessToken $token -ShowOnlyUnassigned
    
    Displays all Intune resources that have no assignments.

.EXAMPLE
    ShowGroupAssignments -Group "Marketing" -accessToken $token -exportInstead -ExportFilePath "C:\Reports"
    
    Exports all assignments for the "Marketing" group to a CSV file in C:\Reports directory.

.NOTES
    Author: Function from Autopilot management system
    
    Dependencies:
    - GetGroupDirectAssignments: Retrieves assignments for a specific group
    - GetGroupIndirectAssignments: Retrieves All Users/All Devices assignments
    - Get-UnassignedResources: Retrieves resources with no assignments
    - ShowMenu, AddMenuItem, NewMenu: Menu system functions
    - Show-PagedContent: Paginated display function
    - Write-Log: Logging function
    
    Assignment Types Supported:
    - Application
    - Configuration (Device Configuration)
    - Compliance (Device Compliance Policies)
    - Script (Device Management Scripts)
    - AppProtection (App Protection Policies)
    - Intent (Security Baselines)
    - ResourceAccess (Resource Access Profiles)
    - AutopilotProfile (Windows Autopilot Profiles)
    - HealthScript (Proactive Remediations/Health Scripts)
    - ConfigurationPolicy (Settings Catalog)
    - GroupPolicy (Administrative Templates)
    - WindowsInformationProtection (WIP Policies)
    - PolicySet (Policy Sets/Bundles)
    - WindowsFeatureUpdate (Windows Feature Updates)
    - WindowsQualityUpdate (Windows Quality Updates)
    - WindowsDriverUpdate (Windows Driver Updates)
    
    The function automatically consolidates assignments that appear multiple times due to different 
    assignment scopes (e.g., same policy assigned directly and via All Users) into a single entry 
    with combined scope information.

.LINK
    https://docs.microsoft.com/en-us/graph/api/resources/intune-graph-overview
    #>
    [CmdletBinding()]
    param (
        $Group,
        [string]$accessToken,
        [string[]]$specialGroups,
        [switch]$exportInstead,
        [string]$ExportFilePath,
        [switch]$ShowOnlyUnassigned,
        [switch]$ShowIndirectAssignments,
        [switch]$HideEmptyMenus,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $LogFile -Module $functionName -Message "Function started - Group: '$Group', ShowOnlyUnassigned: $($ShowOnlyUnassigned.IsPresent), ShowIndirectAssignments: $($ShowIndirectAssignments.IsPresent), exportInstead: $($exportInstead.IsPresent), HideEmptyMenus: $($HideEmptyMenus.IsPresent)" -logLevel "Information"
    
    #region process initial setup
    #define the action type
    if ($exportInstead.IsPresent)
    {
        $actionType = "Export"
        Write-Log -logFile $LogFile -Module $functionName -Message "Action type set to: Export" -logLevel "Verbose"
    }
    else
    {
        $actionType = "Show"
        Write-Log -logFile $LogFile -Module $functionName -Message "Action type set to: Show" -logLevel "Verbose"
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
    
    # Log operational mode for debugging
    Write-Log -logFile $LogFile -Module $functionName -Message "Operational mode - ShowOnlyUnassigned: $($ShowOnlyUnassigned.IsPresent), ShowIndirectAssignments: $($ShowIndirectAssignments.IsPresent), exportInstead: $($exportInstead.IsPresent)" -logLevel "Information"
    Write-Verbose "[$functionName] Operational mode - ShowOnlyUnassigned: $($ShowOnlyUnassigned.IsPresent), ShowIndirectAssignments: $($ShowIndirectAssignments.IsPresent), exportInstead: $($exportInstead.IsPresent)"
    
    # Handle special cases for different assignment retrieval modes
    if ($ShowOnlyUnassigned.IsPresent)
    {
        # Special mode: Show only unassigned configuration profiles (no group filtering)
        Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving all resources to identify unassigned configuration profiles" -logLevel "Information"
        Write-Host "Getting all configuration profiles and checking for unassigned ones..."
        Write-Host "This may take a while..."
        
        # Call helper function to get truly unassigned resources
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Calling Get-UnassignedResources with IncludeBeta=$IncludeBeta, Settings.operatingSystem='$($Settings.operatingSystem)'" -logLevel "Debug"
        $unassignedResult = Get-UnassignedResources -AccessToken $accessToken -IncludeBeta:$IncludeBeta -Settings $Settings
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Get-UnassignedResources returned $(if ($unassignedResult.UnassignedResources) { $unassignedResult.UnassignedResources.Count } else { 0 }) unassigned resources, $($unassignedResult.TotalResourcesChecked) total checked" -logLevel "Debug"
        
        if ($null -eq $unassignedResult)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "Failed to retrieve resources for unassigned check." -LogLevel "Error"
            Write-Host "Failed to retrieve resources." -ForegroundColor Red
            return $returnValues.noGroupAssignmentsFoundMessage
        }
        
        $unassignedProfiles = $unassignedResult.UnassignedResources
        Write-Log -logFile $LogFile -Module $functionName -Message "Found $($unassignedProfiles.Count) truly unassigned resources out of $($unassignedResult.TotalResourcesChecked) total resources" -LogLevel "Information"
        
        # Handle failed resource checks for unassigned mode
        if ($unassignedResult.FailedResources -and $unassignedResult.FailedResources.Count -gt 0)
        {
            # Filter out known backend issues
            $knownBackendIssues = if ($null -ne $settings.knownProblemGraphEndpoints)
            {
                $settings.knownProblemGraphEndpoints
            }
            else
            {
                @()
            }
            
            $displayableFailures = $unassignedResult.FailedResources | Where-Object { $_.ResourceType -notin $knownBackendIssues }
            
            if ($displayableFailures -and $displayableFailures.Count -gt 0)
            {
                $failedResourceTypes = ($displayableFailures | Select-Object -ExpandProperty ResourceType -Unique) -join ', '
                Write-Host "Warning: Some resources could not be checked: $failedResourceTypes" -ForegroundColor Yellow
                Write-Log -logFile $LogFile -Module $functionName -Message "Failed to check $($displayableFailures.Count) resource type(s) for assignments" -logLevel "Warning"
                
                foreach ($failedResource in $displayableFailures)
                {
                    Write-Log -logFile $LogFile -Module $functionName -Message "Failed Resource Check - Type: $($failedResource.ResourceType), Status: $($failedResource.StatusCode), API Version: $($failedResource.ApiVersion), Error: $($failedResource.ErrorMessage)" -logLevel "Error"
                }
            }
            
            # Still log known backend issues but don't display warning to user
            $knownIssueFailures = $unassignedResult.FailedResources | Where-Object { $_.ResourceType -in $knownBackendIssues }
            foreach ($failedResource in $knownIssueFailures)
            {
                Write-Log -logFile $LogFile -Module $functionName -Message "Known Backend Issue - Type: $($failedResource.ResourceType), Status: $($failedResource.StatusCode), API Version: $($failedResource.ApiVersion), Error: $($failedResource.ErrorMessage) (suppressed from user display)" -logLevel "Verbose"
            }
        }
        
        if ($unassignedProfiles.Count -eq 0)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "No unassigned configuration profiles found (checked $($unassignedResult.TotalResourcesChecked) resources)." -LogLevel "Information"
            Write-Host "No unassigned configuration profiles found." -ForegroundColor Yellow
            return $returnValues.noGroupAssignmentsFoundMessage
        }
        
        # Create a new assignments object with only unassigned profiles
        $assignments = Initialize-AssignmentResultObject -GroupName "Unassigned Profiles" -GroupId "N/A"
        $assignments.AllAssignments = $unassignedProfiles
        $assignments.AppAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'Application' })
        $assignments.ConfigurationAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'Configuration' })
        $assignments.ComplianceAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'Compliance' })
        $assignments.ScriptAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'Script' })
        $assignments.AppProtectionAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'AppProtection' })
        $assignments.IntentAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'Intent' })
        $assignments.ResourceAccessAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'ResourceAccess' })
        $assignments.AutopilotAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'AutopilotProfile' })
        $assignments.HealthScriptAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'HealthScript' })
        $assignments.ConfigurationPolicyAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'ConfigurationPolicy' })
        $assignments.GroupPolicyAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'GroupPolicy' })
        $assignments.WindowsInformationProtectionAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'WindowsInformationProtection' })
        $assignments.PolicySetAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'PolicySet' })
        $assignments.WindowsFeatureUpdateAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'WindowsFeatureUpdate' }) 
        $assignments.WindowsQualityUpdateAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'WindowsQualityUpdate' })                         
        $assignments.WindowsDriverUpdateAssignments = @($unassignedProfiles | Where-Object { $_.Type -eq 'WindowsDriverUpdate' })
        
        $groupName = "Unassigned Profiles"
        
        Write-Log -logFile $LogFile -Module $functionName -Message "Found $($unassignedProfiles.Count) unassigned configuration profiles." -LogLevel "Information"
        Write-Verbose "[$functionName] Completed ShowOnlyUnassigned branch successfully"
    }
    elseif ($ShowIndirectAssignments.IsPresent -and $groupName -in $specialGroups)
    {
        Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving all indirect assignments (All Users and All Devices) without group filter (groupName: '$groupName', specialGroups: $($specialGroups -join ', '))" -logLevel "Information"
        Write-Verbose "[$functionName] Entering ShowIndirectAssignments with special group branch"
        Write-Host "Getting all indirect assignments (All Users and All Devices)..."
        Write-Host "This may take a while..."
        
        # Get only indirect assignments
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Calling GetGroupIndirectAssignments with Settings.operatingSystem='$($Settings.operatingSystem)'" -logLevel "Debug"
        $assignments = GetGroupIndirectAssignments -AccessToken $accessToken -IncludeBeta -Settings $Settings
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: GetGroupIndirectAssignments returned $(if ($assignments.AllAssignments) { $assignments.AllAssignments.Count } else { 0 }) total assignments" -logLevel "Debug"
        
        if ($null -eq $assignments -or $assignments.AllAssignments.count -eq 0)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "No indirect assignments found." -LogLevel "Verbose"
            Write-Host "No indirect assignments found." -ForegroundColor Yellow
            return $returnValues.noGroupAssignmentsFoundMessage
        }
        
        $groupName = "All Users/All Devices"
        Write-Verbose "[$functionName] Completed ShowIndirectAssignments with special group branch successfully"
    }
    elseif (-not $ShowOnlyUnassigned.IsPresent)
    {
        # Normal flow: get assignments for specific group (only if NOT in ShowOnlyUnassigned mode)
        Write-Log -logFile $LogFile -Module $functionName -Message "Retrieving group assignments for specific group '$groupName'..." -logLevel "Information"
        Write-Verbose "[$functionName] Entering normal group assignment retrieval flow"
        Write-Host "Getting group assignments for '$groupName'..."
        if ($ShowIndirectAssignments.IsPresent)
        {
            Write-Host "Including indirect assignments (All Users and All Devices)..."
        }
        Write-Host "This may take a while..."
        # Get group assignments (fetch once and reuse)
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: Calling GetGroupDirectAssignments for group '$Group', IncludeIndirectAssignments=$($ShowIndirectAssignments.IsPresent), Settings.operatingSystem='$($Settings.operatingSystem)'" -logLevel "Debug"
        $assignments = GetGroupDirectAssignments -accessToken $accessToken -GroupName $Group -includeBeta -IncludeIndirectAssignments:$ShowIndirectAssignments -Settings $Settings
        Write-Log -logFile $LogFile -module $functionName -Message "DEBUG: GetGroupDirectAssignments returned $(if ($assignments -and $assignments -ne 'noGroup' -and $assignments.AllAssignments) { $assignments.AllAssignments.Count } else { 0 }) total assignments" -logLevel "Debug"
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
        Write-Verbose "[$functionName] Completed normal group assignment retrieval successfully"
    }
    else
    {
        # Fallback case - should not be reached under normal operation
        Write-Log -logFile $LogFile -Module $functionName -Message "WARNING: Unexpected code path reached. ShowOnlyUnassigned: $($ShowOnlyUnassigned.IsPresent), ShowIndirectAssignments: $($ShowIndirectAssignments.IsPresent), groupName: '$groupName', specialGroups: $($specialGroups -join ', ')" -LogLevel "Warning"
        Write-Host "Warning: Unexpected operational state detected. Please check logs." -ForegroundColor Yellow
        return $returnValues.noGroupAssignmentsFoundMessage
    }
    # Check for failed resources and notify user
    if ($assignments.FailedResources -and $assignments.FailedResources.Count -gt 0)
    {
        # Filter out known backend service issues that consistently fail with HTTP 400
        # resourceAccessProfiles: Returns 400 from Microsoft's StatelessRAPolicyService backend (not a code issue)
        $knownBackendIssues = if ($null -ne $settings.knownProblemGraphEndpoints)
        {
            $settings.knownProblemGraphEndpoints
        }
        else
        {
            @()
        }                                       
        
        $displayableFailures = $assignments.FailedResources | Where-Object { $_.ResourceType -notin $knownBackendIssues }
        
        if ($displayableFailures -and $displayableFailures.Count -gt 0)
        {
            $failedResourceTypes = ($displayableFailures | Select-Object -ExpandProperty ResourceType -Unique) -join ', '
            Write-Host "Warning: Some resources could not be fetched: $failedResourceTypes" -ForegroundColor Yellow
            Write-Log -logFile $LogFile -Module $functionName -Message "Failed to fetch $($displayableFailures.Count) resource type(s)" -logLevel "Warning"
            
            foreach ($failedResource in $displayableFailures)
            {
                Write-Log -logFile $LogFile -Module $functionName -Message "Failed Resource - Type: $($failedResource.ResourceType), Status: $($failedResource.StatusCode), API Version: $($failedResource.ApiVersion), Error: $($failedResource.ErrorMessage)" -logLevel "Error"
            }
        }
        
        # Still log known backend issues but don't display warning to user
        $knownIssueFailures = $assignments.FailedResources | Where-Object { $_.ResourceType -in $knownBackendIssues }
        foreach ($failedResource in $knownIssueFailures)
        {
            Write-Log -logFile $LogFile -Module $functionName -Message "Known Backend Issue - Type: $($failedResource.ResourceType), Status: $($failedResource.StatusCode), API Version: $($failedResource.ApiVersion), Error: $($failedResource.ErrorMessage) (suppressed from user display)" -logLevel "Verbose"
        }
    }
    
    # Cache all assignments to avoid re-query per selection
    $allAssignments = @($assignments.allAssignments)
    Write-Log -logFile $LogFile -Module $functionName -Message "Cached $($allAssignments.Count) total assignments for processing" -logLevel "Information"
    
    # Skip consolidation for unassigned profiles (they have no assignments to consolidate)
    if ($ShowOnlyUnassigned.IsPresent)
    {
        Write-Verbose "[$functionName] Skipping consolidation for unassigned profiles mode"
        Write-Log -logFile $LogFile -Module $functionName -Message "Skipping consolidation for unassigned profiles (count: $($allAssignments.Count) entries)" -logLevel "Verbose"
    }
    else
    {
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
        $assignments.WindowsFeatureUpdateAssignments = @($allAssignments | Where-Object { $_.Type -eq 'WindowsFeatureUpdate' })
        $assignments.WindowsQualityUpdateAssignments = @($allAssignments | Where-Object { $_.Type -eq 'WindowsQualityUpdate' })
        $assignments.WindowsDriverUpdateAssignments = @($allAssignments | Where-Object { $_.Type -eq 'WindowsDriverUpdate' })
    }  # End of else block for consolidation
    #endregion                  
    
    #region Build and show assignment type menu    
    Write-Log -logFile $LogFile -Module $functionName -Message "Building assignment type menu (Hide EmptyMenus: $($HideEmptyMenus.IsPresent))" -logLevel "Verbose"
    $groupAssignmentsMenu = NewMenu -MenuName "groupAssignmentsMenu"
    if (-not $groupAssignmentsMenu)
    {
        # Fallback to manual creation if config not found
        Write-Log -logFile $LogFile -Module $functionName -Message "Menu config not found, creating menu manually" -logLevel "Debug"
        $groupAssignmentsMenu = NewMenu -Title "Group Assignments for $groupName" -Description "What type of assignments would you like to see?"
    }
    else
    {
        # Update title with actual group name
        $groupAssignmentsMenu.Title = if ($HideEmptyMenus.IsPresent)
        {
            "Assignments for $groupName `n(Only resources with assigned configurations are shown)"
        }
        else
        {
            "Assignments for $groupName"
        }       
        Write-Log -logFile $LogFile -Module $functionName -Message "Menu loaded from config, title updated with group name" -logLevel "Debug"
    }
    
    if (-not $HideEmptyMenus -or $assignments.AppAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Application Assignments ($($assignments.AppAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: Application"
            return 'Application'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.ConfigurationAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType           Device Configurations ($($assignments.ConfigurationAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: Configuration"
            return 'Configuration'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.ComplianceAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Device Compliance Policies ($($assignments.ComplianceAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: Compliance"
            return 'Compliance'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.ScriptAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Device Management Scripts ($($assignments.ScriptAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: Script"
            return 'Script'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.AppProtectionAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType App Protection Policies ($($assignments.AppProtectionAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: AppProtection"
            return 'AppProtection'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.IntentAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Security Intents (Baselines) ($($assignments.IntentAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: Intent"
            return 'Intent'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.ResourceAccessAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Resource Access Profiles ($($assignments.ResourceAccessAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: ResourceAccess"
            return 'ResourceAccess'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.AutopilotAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Autopilot Profiles ($($assignments.AutopilotAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: AutopilotProfile"
            return 'AutopilotProfile'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.HealthScriptAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Device Health Scripts ($($assignments.HealthScriptAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: HealthScript"
            return 'HealthScript'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.ConfigurationPolicyAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Configuration Policies (Settings Catalog) ($($assignments.ConfigurationPolicyAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: ConfigurationPolicy"
            return 'ConfigurationPolicy'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.GroupPolicyAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Group Policy Configurations ($($assignments.GroupPolicyAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: GroupPolicy"
            return 'GroupPolicy'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.WindowsInformationProtectionAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Windows Information Protection Policies ($($assignments.WindowsInformationProtectionAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: WindowsInformationProtection"
            return 'WindowsInformationProtection'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.PolicySetAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Policy Sets ($($assignments.PolicySetAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: PolicySet"
            return 'PolicySet'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.WindowsFeatureUpdateAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Windows Feature Updates ($($assignments.WindowsFeatureUpdateAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: WindowsFeatureUpdate"
            return 'WindowsFeatureUpdate'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.WindowsQualityUpdateAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Windows Quality Updates ($($assignments.WindowsQualityUpdateAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: WindowsQualityUpdate"
            return 'WindowsQualityUpdate'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.WindowsDriverUpdateAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType Windows Driver Updates ($($assignments.WindowsDriverUpdateAssignments.count))" -Action {
            Write-Host "Selected Assignment Type: WindowsDriverUpdate"
            return 'WindowsDriverUpdate'
        } -returnsValue
    }
    if (-not $HideEmptyMenus -or $assignments.AllAssignments.count -gt 0)
    {
        $groupAssignmentsMenu = AddMenuItem -menu $groupAssignmentsMenu -name "$actionType  All Assignments ($($assignments.AllAssignments.count))" -Action {
            Write-Host "Displaying all assignments"
            return 'All'
        } -returnsValue
    }
    
    Write-Log -logFile $LogFile -Module $functionName -Message "Assignment type menu built with $($groupAssignmentsMenu.MenuItems.Count) visible items" -logLevel "Information"
    #endregion

    # Loop: after showing assignments, return to the assignment type menu
    Write-Log -logFile $LogFile -Module $functionName -Message "Entering main assignment type selection loop" -logLevel "Verbose"
    $loopIteration = 0
    while ($true)
    {
        $loopIteration++
        Write-Log -logFile $LogFile -Module $functionName -Message "Assignment type menu loop iteration: $loopIteration" -logLevel "Debug"
        
        # Use proper stack operation to maintain menu navigation integrity
        $assignmentType = ShowMenu -Menu $groupAssignmentsMenu -CalledBy 'Custom_GroupAssignmentSubmenu' -StackOperation 'Push'
        Write-Log -logFile $LogFile -Module $functionName -Message "User selected assignment type: '$assignmentType'" -logLevel "Information"
        
        # Validate that we got a proper assignment, not a navigation option
        if ($assignmentType -eq "Back" -or $assignmentType -eq "Main Menu" -or $assignmentType -eq 0 -or $assignmentType -eq "0")
        {
            Write-Verbose "[$functionName] ShowMenu returned navigation option: '$assignmentType', treating as navigation"
            Write-Log -logFile $LogFile -Module $functionName -Message "Navigation option selected: '$assignmentType', exiting function" -logLevel "Information"
            return $assignmentType
        }
        # If assignmentType is null, user may have navigated away - don't continue processing
        if ($null -eq $assignmentType)
        {
            Write-Verbose "[$functionName] ShowMenu returned null, user may have navigated away"
            Write-Log -logFile $LogFile -Module $functionName -Message "ShowMenu returned null, user navigated away" -logLevel "Information"
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
                'WindowsFeatureUpdate'         = 'WindowsFeatureUpdate'
                'WindowsQualityUpdate'         = 'WindowsQualityUpdate'
                'WindowsDriverUpdate'          = 'WindowsDriverUpdate'
            }
            
            $internalType = $typePropertyMap[$assignmentType]
            if ($internalType)
            {
                $selectedAssignments = @($allAssignments | Where-Object { $_.Type -eq $internalType })
                Write-Log -logFile $LogFile -Module $functionName -Message "Filtered assignments by type '$assignmentType' (internal: '$internalType'): $($selectedAssignments.Count) found" -logLevel "Information"
            }
            else
            {
                $selectedAssignments = @()
                Write-Log -logFile $LogFile -Module $functionName -Message "Unknown assignment type '$assignmentType', returning empty set" -logLevel "Warning"
            }
            Write-Host "Found $($selectedAssignments.Count) assignments of type $assignmentType"
        }
        else
        {
            $selectedAssignments = $allAssignments
            Write-Log -logFile $LogFile -Module $functionName -Message "Showing all assignment types: $($selectedAssignments.Count) total assignments" -logLevel "Information"
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
                $exportPath = if ($ExportFilePath)
                {
                    # Use provided export path
                    Join-Path -Path $ExportFilePath -ChildPath $exportFileName
                }
                else
                {
                    # Use current directory
                    Join-Path -Path (Get-Location).Path -ChildPath $exportFileName
                }                   
                
                Write-Host "Exporting $($selectedAssignments.Count) assignments to CSV..." -ForegroundColor Cyan
                Write-Log -logFile $LogFile -Module $functionName -Message "Starting export - Type: '$assignmentType', Count: $($selectedAssignments.Count), Path: '$exportPath'" -LogLevel "Information"
                
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
                    $exportFileSize = (Get-Item $exportPath).Length
                    
                    Write-Host "Export completed successfully!" -ForegroundColor Green
                    Write-Host "File location: $exportPath" -ForegroundColor White
                    Write-Log -logFile $LogFile -Module $functionName -Message "Export completed successfully - Records: $($exportData.Count), File size: $exportFileSize bytes, Path: '$exportPath'" -LogLevel "Information"
                    
                    # Offer to open the file
                    Write-Host ""
                    $openChoice = Read-Host "Would you like to open the exported file? (yes/no)"
                    Write-Log -logFile $LogFile -Module $functionName -Message "User prompted to open file, response: '$openChoice'" -LogLevel "Debug"
                    if ($openChoice -in @('yes', 'y'))
                    {
                        Start-Process $exportPath
                        Write-Log -logFile $LogFile -Module $functionName -Message "User opened exported file: $exportPath" -LogLevel "Information"
                    }
                    else
                    {
                        Write-Log -logFile $LogFile -Module $functionName -Message "User declined to open exported file" -LogLevel "Verbose"
                    }
                }
                catch
                {
                    Write-Host "Error exporting assignments: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log -logFile $LogFile -Module $functionName -Message "Export failed - Error: $($_.Exception.Message), Stack: $($_.ScriptStackTrace)" -LogLevel "Error"
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
                Write-Log -logFile $LogFile -Module $functionName -Message "Starting paged display - Type: '$assignmentType', Count: $($selectedAssignments.Count), PageSize: 10, Title: '$pageTitle'" -LogLevel "Information"
                
                # Use Show-PagedContent for display
                $pagingResult = Show-PagedContent -Content $selectedAssignments `
                    -DisplayScriptBlock $displayScript `
                    -Title $pageTitle `
                    -PageSize 10 `
                    -ShowPageInfo $true
                    
                Write-Log -logFile $LogFile -Module $functionName -Message "Paged display completed - Result: '$pagingResult'" -LogLevel "Information"
            }
        }
        else
        {
            Write-Host "No assignments found for the selected type." -ForegroundColor Yellow
            Write-Log -logFile $LogFile -Module $functionName -Message "No assignments found for type: '$assignmentType' (filtered from $($allAssignments.Count) total assignments)" -LogLevel "Information"
            Write-Host ""
            Write-Host "Press any key to continue..."
            [void][System.Console]::ReadKey($true)
        }
        #endregion

        # Loop continues to re-show the assignment type menu
    }
    Write-Log -logFile $LogFile -Module $functionName -Message "Function exiting with return value: $($returnValues.backoutText)" -logLevel "Information"
    return $returnValues.backoutText
}
