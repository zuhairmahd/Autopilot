function GetGroupDirectAssignments()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $AccessToken,
        [Parameter(Mandatory = $true)]
        [string] $GroupName,
        [Parameter(Mandatory = $false)]
        [switch] $IncludeBeta
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting to get direct assignments for group: $GroupName"
    Write-Log -logFile $LogFile -module $functionName -Message "Starting to get direct assignments for group: $GroupName" -logLevel "Information"
    
    if (-not $AccessToken) {
        Write-Verbose "[$functionName] No AccessToken provided; relying on default authentication in CallGraphAPI."
        Write-Log -logFile $LogFile -module $functionName -Message "No AccessToken provided; relying on default authentication in CallGraphAPI." -logLevel "Warning"
    }
    
    # First, get the group ID from the group name using the existing utility function
    Write-Verbose "[$functionName] Resolving group name '$GroupName' to group ID"
    Write-Log -logFile $LogFile -module $functionName -Message "Resolving group name '$GroupName' to group ID" -logLevel "Information"
    
    try {
        $groupIds = GetGroupIdsByNames -AccessToken $AccessToken -GroupNames @($GroupName)
        
        if (-not $groupIds -or $groupIds.Count -eq 0) {
            Write-Verbose "[$functionName] No group ID found for group name: $GroupName"
            Write-Log -logFile $LogFile -module $functionName -Message "No group ID found for group name: $GroupName" -logLevel "Warning"
            return @()
        }
        
        # Ensure $groupIds is treated as an array and properly extract the first (or only) group ID
        $groupIdArray = @($groupIds)
        $groupId = $groupIdArray[0]
        Write-Verbose "[$functionName] Resolved group '$GroupName' to ID: $groupId (from $($groupIdArray.Count) result(s))"
        Write-Log -logFile $LogFile -module $functionName -Message "Resolved group '$GroupName' to ID: $groupId (from $($groupIdArray.Count) result(s))" -logLevel "Information"
    }
    catch {
        Write-Verbose "[$functionName] Error resolving group name: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error resolving group name: $($_.Exception.Message)" -logLevel "Error"
        return @()
    }
    
    # Initialize result object
    $assignments = [PSCustomObject]@{
        GroupName = $GroupName
        GroupId = $groupId
        AppAssignments = @()
        ConfigurationAssignments = @()
        ComplianceAssignments = @()
        AutopilotAssignments = @()
        AllAssignments = @()
    }
    
    # Determine API version based on IncludeBeta parameter
    $apiVersion = if ($IncludeBeta.IsPresent) { 'beta' } else { 'v1.0' }
    Write-Verbose "[$functionName] Using API version: $apiVersion"
    Write-Log -logFile $LogFile -module $functionName -Message "Using API version: $apiVersion" -logLevel "Information"
    
    try {
        # Get App Assignments - First get all mobile apps, then check individual assignments
        Write-Verbose "[$functionName] Getting mobile apps and their assignments for group ID: $groupId"
        Write-Log -logFile $LogFile -module $functionName -Message "Getting mobile apps and their assignments for group ID: $groupId" -logLevel "Information"
        
        $appUri = "deviceAppManagement/mobileApps"
        $appExtraParameters = "select=id,displayName"
        
        $appResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $appUri -APIVersion $apiVersion -ExtraParameters $appExtraParameters
        
        if ($appResponse -and $appResponse.value) {
            foreach ($app in $appResponse.value) {
                try {
                    # Get assignments for this specific app
                    $assignmentUri = "deviceAppManagement/mobileApps/$($app.id)/assignments"
                    $assignmentResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentUri -APIVersion $apiVersion
                    
                    if ($assignmentResponse -and $assignmentResponse.value) {
                        $relevantAssignments = $assignmentResponse.value | Where-Object { 
                            $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                            $_.target.groupId -eq $groupId 
                        }
                        
                        foreach ($assignment in $relevantAssignments) {
                            $appAssignment = [PSCustomObject]@{
                                Type = "Application"
                                Name = $app.displayName
                                Id = $app.id
                                Intent = $assignment.intent
                                Target = $assignment.target
                                Settings = $assignment.settings
                            }
                            $assignments.AppAssignments += $appAssignment
                            $assignments.AllAssignments += $appAssignment
                        }
                    }
                }
                catch {
                    Write-Verbose "[$functionName] Error getting assignments for app $($app.displayName): $($_.Exception.Message)"
                    Write-Log -logFile $LogFile -module $functionName -Message "Error getting assignments for app $($app.displayName): $($_.Exception.Message)" -logLevel "Warning"
                }
            }
            Write-Verbose "[$functionName] Found $($assignments.AppAssignments.Count) app assignments"
            Write-Log -logFile $LogFile -module $functionName -Message "Found $($assignments.AppAssignments.Count) app assignments" -logLevel "Information"
        }
    }
    catch {
        Write-Verbose "[$functionName] Error getting app assignments: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error getting app assignments: $($_.Exception.Message)" -logLevel "Warning"
    }
    
    try {
        # Get Device Configuration Assignments - First get all configurations, then check individual assignments
        Write-Verbose "[$functionName] Getting device configurations and their assignments for group ID: $groupId"
        Write-Log -logFile $LogFile -module $functionName -Message "Getting device configurations and their assignments for group ID: $groupId" -logLevel "Information"
        
        $configUri = "deviceManagement/deviceConfigurations"
        $configExtraParameters = "select=id,displayName"
        
        $configResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $configUri -APIVersion $apiVersion -ExtraParameters $configExtraParameters
        
        if ($configResponse -and $configResponse.value) {
            foreach ($config in $configResponse.value) {
                try {
                    # Get assignments for this specific configuration
                    $assignmentUri = "deviceManagement/deviceConfigurations/$($config.id)/assignments"
                    $assignmentResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentUri -APIVersion $apiVersion
                    
                    if ($assignmentResponse -and $assignmentResponse.value) {
                        $relevantAssignments = $assignmentResponse.value | Where-Object { 
                            $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                            $_.target.groupId -eq $groupId 
                        }
                        
                        foreach ($assignment in $relevantAssignments) {
                            $configAssignment = [PSCustomObject]@{
                                Type = "Configuration"
                                Name = $config.displayName
                                Id = $config.id
                                Intent = $assignment.intent
                                Target = $assignment.target
                                Settings = $assignment.settings
                            }
                            $assignments.ConfigurationAssignments += $configAssignment
                            $assignments.AllAssignments += $configAssignment
                        }
                    }
                }
                catch {
                    Write-Verbose "[$functionName] Error getting assignments for configuration $($config.displayName): $($_.Exception.Message)"
                    Write-Log -logFile $LogFile -module $functionName -Message "Error getting assignments for configuration $($config.displayName): $($_.Exception.Message)" -logLevel "Warning"
                }
            }
            Write-Verbose "[$functionName] Found $($assignments.ConfigurationAssignments.Count) configuration assignments"
            Write-Log -logFile $LogFile -module $functionName -Message "Found $($assignments.ConfigurationAssignments.Count) configuration assignments" -logLevel "Information"
        }
    }
    catch {
        Write-Verbose "[$functionName] Error getting configuration assignments: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error getting configuration assignments: $($_.Exception.Message)" -logLevel "Warning"
    }
    
    try {
        # Get Compliance Policy Assignments - First get all policies, then check individual assignments
        Write-Verbose "[$functionName] Getting compliance policies and their assignments for group ID: $groupId"
        Write-Log -logFile $LogFile -module $functionName -Message "Getting compliance policies and their assignments for group ID: $groupId" -logLevel "Information"
        
        $complianceUri = "deviceManagement/deviceCompliancePolicies"
        $complianceExtraParameters = "select=id,displayName"
        
        $complianceResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $complianceUri -APIVersion $apiVersion -ExtraParameters $complianceExtraParameters
        
        if ($complianceResponse -and $complianceResponse.value) {
            foreach ($policy in $complianceResponse.value) {
                try {
                    # Get assignments for this specific compliance policy
                    $assignmentUri = "deviceManagement/deviceCompliancePolicies/$($policy.id)/assignments"
                    $assignmentResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentUri -APIVersion $apiVersion
                    
                    if ($assignmentResponse -and $assignmentResponse.value) {
                        $relevantAssignments = $assignmentResponse.value | Where-Object { 
                            $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                            $_.target.groupId -eq $groupId 
                        }
                        
                        foreach ($assignment in $relevantAssignments) {
                            $complianceAssignment = [PSCustomObject]@{
                                Type = "Compliance"
                                Name = $policy.displayName
                                Id = $policy.id
                                Intent = $assignment.intent
                                Target = $assignment.target
                                Settings = $assignment.settings
                            }
                            $assignments.ComplianceAssignments += $complianceAssignment
                            $assignments.AllAssignments += $complianceAssignment
                        }
                    }
                }
                catch {
                    Write-Verbose "[$functionName] Error getting assignments for compliance policy $($policy.displayName): $($_.Exception.Message)"
                    Write-Log -logFile $LogFile -module $functionName -Message "Error getting assignments for compliance policy $($policy.displayName): $($_.Exception.Message)" -logLevel "Warning"
                }
            }
            Write-Verbose "[$functionName] Found $($assignments.ComplianceAssignments.Count) compliance assignments"
            Write-Log -logFile $LogFile -module $functionName -Message "Found $($assignments.ComplianceAssignments.Count) compliance assignments" -logLevel "Information"
        }
    }
    catch {
        Write-Verbose "[$functionName] Error getting compliance assignments: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error getting compliance assignments: $($_.Exception.Message)" -logLevel "Warning"
    }
    
    try {
        # Get Autopilot Deployment Profile Assignments (if IncludeBeta) - First get all profiles, then check individual assignments
        if ($IncludeBeta.IsPresent) {
            Write-Verbose "[$functionName] Getting Autopilot deployment profiles and their assignments for group ID: $groupId"
            Write-Log -logFile $LogFile -module $functionName -Message "Getting Autopilot deployment profiles and their assignments for group ID: $groupId" -logLevel "Information"
            
            $autopilotUri = "deviceManagement/windowsAutopilotDeploymentProfiles"
            $autopilotExtraParameters = "select=id,displayName"
            
            $autopilotResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $autopilotUri -APIVersion $apiVersion -ExtraParameters $autopilotExtraParameters
            
            if ($autopilotResponse -and $autopilotResponse.value) {
                foreach ($profile in $autopilotResponse.value) {
                    try {
                        # Get assignments for this specific Autopilot profile
                        $assignmentUri = "deviceManagement/windowsAutopilotDeploymentProfiles/$($profile.id)/assignments"
                        $assignmentResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentUri -APIVersion $apiVersion
                        
                        if ($assignmentResponse -and $assignmentResponse.value) {
                            $relevantAssignments = $assignmentResponse.value | Where-Object { 
                                $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                                $_.target.groupId -eq $groupId 
                            }
                            
                            foreach ($assignment in $relevantAssignments) {
                                $autopilotAssignment = [PSCustomObject]@{
                                    Type = "AutopilotProfile"
                                    Name = $profile.displayName
                                    Id = $profile.id
                                    Intent = $assignment.intent
                                    Target = $assignment.target
                                    Settings = $assignment.settings
                                }
                                $assignments.AutopilotAssignments += $autopilotAssignment
                                $assignments.AllAssignments += $autopilotAssignment
                            }
                        }
                    }
                    catch {
                        Write-Verbose "[$functionName] Error getting assignments for Autopilot profile $($profile.displayName): $($_.Exception.Message)"
                        Write-Log -logFile $LogFile -module $functionName -Message "Error getting assignments for Autopilot profile $($profile.displayName): $($_.Exception.Message)" -logLevel "Warning"
                    }
                }
                Write-Verbose "[$functionName] Found $($assignments.AutopilotAssignments.Count) Autopilot assignments"
                Write-Log -logFile $LogFile -module $functionName -Message "Found $($assignments.AutopilotAssignments.Count) Autopilot assignments" -logLevel "Information"
            }
        }
    }
    catch {
        Write-Verbose "[$functionName] Error getting Autopilot assignments: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error getting Autopilot assignments: $($_.Exception.Message)" -logLevel "Warning"
    }
    
    # Summary
    $totalAssignments = $assignments.AllAssignments.Count
    Write-Verbose "[$functionName] Total assignments found for group '$GroupName': $totalAssignments"
    Write-Log -logFile $LogFile -module $functionName -Message "Total assignments found for group '$GroupName': $totalAssignments" -logLevel "Information"
    
    Write-Host "Group Direct Assignments Summary for '$GroupName':" -ForegroundColor Green
    Write-Host "  Apps: $($assignments.AppAssignments.Count)" -ForegroundColor Yellow
    Write-Host "  Configurations: $($assignments.ConfigurationAssignments.Count)" -ForegroundColor Yellow
    Write-Host "  Compliance Policies: $($assignments.ComplianceAssignments.Count)" -ForegroundColor Yellow
    if ($IncludeBeta.IsPresent) {
        Write-Host "  Autopilot Profiles: $($assignments.AutopilotAssignments.Count)" -ForegroundColor Yellow
    }
    Write-Host "  Total: $totalAssignments" -ForegroundColor Cyan
    
    return $assignments
}