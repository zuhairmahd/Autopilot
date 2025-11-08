function GetGroupDirectAssignments()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $AccessToken,
        [Parameter(Mandatory = $true)]
        $GroupName,
        [Parameter(Mandatory = $false)]
        [switch] $IncludeBeta,
        [switch]$ShowSummary,
        [switch]$IncludeIndirectAssignments,
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #region log the incoming parameters 
    Write-Verbose "[$functionName] Incoming parameters:"
    write-log -logFile $logFile -Module $functionName -Message "Incoming parameters for:" -logLevel "Information"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided"
        Write-Log -logFile $LogFile -module $functionName -Message "AccessToken: $AccessToken" -logLevel "Information"
    }
    Write-Verbose "[$functionName] GroupName: $GroupName"
    Write-Verbose "[$functionName] IncludeBeta: $IncludeBeta"
    Write-Verbose "[$functionName] ShowSummary: $ShowSummary"
    Write-Verbose "[$functionName] IncludeIndirectAssignments: $IncludeIndirectAssignments"
    Write-Verbose "[$functionName] BatchSize: $BatchSize"
    #now write-log them.
    Write-Log -logFile $LogFile -module $functionName -Message "Incoming parameters:" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "GroupName: $GroupName" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "IncludeBeta: $IncludeBeta" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "ShowSummary: $ShowSummary" -LogLevel "Verbose"
    Write-Log -logFile $LogFile -module $functionName -Message "IncludeIndirectAssignments: $IncludeIndirectAssignments" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "BatchSize: $BatchSize" -logLevel "Information"
    $groupIds = $GroupName
    $groupIdArray = @($groupIds)
    $groupId = $groupIdArray[0]
    Write-Log -logFile $LogFile -module $functionName -Message "Group name: $($groupId.displayName)" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "Group ID: $($groupId.Id)" -logLevel "Information"
    #endregion

    # Initialize result object early (before validation)
    $assignments = [PSCustomObject]@{
        GroupName                               = $groupId.displayName 
        GroupId                                 = $groupId.Id
        AppAssignments                          = @()
        ConfigurationAssignments                = @()
        ComplianceAssignments                   = @()
        AutopilotAssignments                    = @()
        ScriptAssignments                       = @()
        HealthScriptAssignments                 = @()
        AppProtectionAssignments                = @()
        IntentAssignments                       = @()
        ResourceAccessAssignments               = @()
        ConfigurationPolicyAssignments          = @()
        GroupPolicyAssignments                  = @()
        WindowsInformationProtectionAssignments = @()
        PolicySetAssignments                    = @()
        AllAssignments                          = @()
    }
    
    # Validate that we have a group ID to work with
    if (-not $groupId.Id)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No group ID available, cannot proceed with assignment retrieval" -LogLevel "Warning"
        return $assignments
    }
    
    # Store the group ID value for filtering assignments
    $groupIdValue = $groupId.Id
    
    # Determine API version based on IncludeBeta parameter
    $apiVersion = if ($IncludeBeta.IsPresent)
    {
        'beta' 
    }
    else
    {
        'v1.0' 
    }
    Write-Log -logFile $LogFile -module $functionName -Message "Using API version: $apiVersion with batch size: $BatchSize" -logLevel "Information"
    
    # Helper function to process assignments using CallGraphAPI's built-in batch support
    function Get-ResourceAssignments()
    {
        [CmdletBinding()]
        param(
            [array]$Resources,
            [string]$ResourceType,
            [string]$BaseUri,
            [string]$AssignmentCategory
        )
        
        $functionName = $MyInvocation.MyCommand.Name
        if (-not $Resources -or $Resources.Count -eq 0)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "No ${ResourceType} resources to process" -logLevel "Verbose"
            return
        }
        
        Write-Log -logFile $LogFile -module $functionName -Message "Processing $($Resources.Count) ${ResourceType} resources" -LogLevel "Verbose"
        
        # Build array of assignment endpoint paths for CallGraphAPI batch processing
        $assignmentPaths = @()
        foreach ($resource in $Resources)
        {
            $assignmentPaths += "$BaseUri/$($resource.id)/assignments"
        }
        
        # Use CallGraphAPI's native batch support
        $batchResult = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentPaths -APIVersion $apiVersion -Method "GET"
        
        if ($batchResult -and $batchResult.value)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Processing $($batchResult.value.Count) batch responses for ${ResourceType}" -LogLevel "Verbose"
            for ($i = 0; $i -lt $batchResult.value.Count; $i++)
            {
                $responseData = $batchResult.value[$i]
                $resource = $Resources[$i]
                
                if ($responseData -and $responseData.value)
                {
                    $relevantAssignments = $responseData.value | Where-Object { 
                        $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                        $_.target.groupId -eq $groupIdValue 
                    }
                    
                    foreach ($assignment in $relevantAssignments)
                    {
                        $assignmentObject = [PSCustomObject]@{
                            Type        = $AssignmentCategory
                            Name        = $resource.displayName
                            Description = if ($resource.description) { $resource.description } else { "" }
                            Id          = $resource.id
                            Intent      = $assignment.intent
                            Target      = $assignment.target
                            Settings    = $assignment.settings
                        }
                        
                        switch ($AssignmentCategory)
                        {
                            "Application" { $assignments.AppAssignments += $assignmentObject }
                            "Configuration" { $assignments.ConfigurationAssignments += $assignmentObject }
                            "Compliance" { $assignments.ComplianceAssignments += $assignmentObject }
                            "AutopilotProfile" { $assignments.AutopilotAssignments += $assignmentObject }
                            "Script" { $assignments.ScriptAssignments += $assignmentObject }
                            "HealthScript" { $assignments.HealthScriptAssignments += $assignmentObject }
                            "AppProtection" { $assignments.AppProtectionAssignments += $assignmentObject }
                            "Intent" { $assignments.IntentAssignments += $assignmentObject }
                            "ResourceAccess" { $assignments.ResourceAccessAssignments += $assignmentObject }
                            "ConfigurationPolicy" { $assignments.ConfigurationPolicyAssignments += $assignmentObject }
                            "GroupPolicy" { $assignments.GroupPolicyAssignments += $assignmentObject }
                            "WindowsInformationProtection" { $assignments.WindowsInformationProtectionAssignments += $assignmentObject }
                            "PolicySet" { $assignments.PolicySetAssignments += $assignmentObject }
                        }
                        $assignments.AllAssignments += $assignmentObject
                    }
                }
            }
        }
    }
    
    try
    {
        # Get all resource lists using a single batch API call for better performance
        Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for assignments using batch API" -logLevel "Information"
        
        # Check cache for resource lists first
        $apiVersionKey = if ($IncludeBeta.IsPresent) { "beta" } else { "v1.0" }
        $resourceListCacheKey = "ResourceLists_${apiVersionKey}"
        $cachedResourceLists = Get-CachedData -CacheType 'Configuration' -Key $resourceListCacheKey
        
        if ($cachedResourceLists)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Using cached resource lists (API: $apiVersionKey)" -logLevel "Verbose"
            Write-Verbose "[$functionName] Cache hit for resource lists"
            
            # Extract cached resources
            $mobileApps = $cachedResourceLists.mobileApps
            $deviceConfigs = $cachedResourceLists.deviceConfigs
            $compliancePolicies = $cachedResourceLists.compliancePolicies
            $autopilotProfiles = $cachedResourceLists.autopilotProfiles
            $deviceScripts = $cachedResourceLists.deviceScripts
            $healthScripts = $cachedResourceLists.healthScripts
            $appProtectionPolicies = $cachedResourceLists.appProtectionPolicies
            $intents = $cachedResourceLists.intents
            $resourceAccessProfiles = $cachedResourceLists.resourceAccessProfiles
            $configurationPolicies = $cachedResourceLists.configurationPolicies
            $groupPolicyConfigs = $cachedResourceLists.groupPolicyConfigs
            $policySets = $cachedResourceLists.policySets
            $wipPolicies = $cachedResourceLists.wipPolicies
            $mdmWipPolicies = $cachedResourceLists.mdmWipPolicies
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Cache miss - fetching resource lists from Graph API" -logLevel "Verbose"
            Write-Verbose "[$functionName] No cached resource lists found, fetching from API"
            
            # Create batch request for all resource lists
            $batchRequestBody = @{
                requests = @()
            }
            
            # Define resource endpoints and their IDs (including description field)
            $resourceEndpoints = @(
                @{ id = "mobileApps"; url = "deviceAppManagement/mobileApps"; extraParams = "select=id,displayName,description" }
                @{ id = "deviceConfigs"; url = "deviceManagement/deviceConfigurations"; extraParams = "select=id,displayName,description" }
                @{ id = "compliancePolicies"; url = "deviceManagement/deviceCompliancePolicies"; extraParams = "select=id,displayName,description" }
                @{ id = "deviceScripts"; url = "deviceManagement/deviceManagementScripts"; extraParams = "select=id,displayName,description" }
                @{ id = "appProtectionPolicies"; url = "deviceAppManagement/managedAppPolicies"; extraParams = "select=id,displayName,description" }
                @{ id = "intents"; url = "deviceManagement/intents"; extraParams = "select=id,displayName,description" }
                @{ id = "resourceAccessProfiles"; url = "deviceManagement/resourceAccessProfiles"; extraParams = "select=id,displayName,description" }
                @{ id = "policySets"; url = "deviceAppManagement/policySets"; extraParams = "select=id,displayName,description" }
            )
        
            # Add beta endpoints if IncludeBeta is specified
            if ($IncludeBeta.IsPresent)
            {
                $resourceEndpoints += @(
                    @{ id = "autopilotProfiles"; url = "deviceManagement/windowsAutopilotDeploymentProfiles"; extraParams = "select=id,displayName,description" }
                    @{ id = "healthScripts"; url = "deviceManagement/deviceHealthScripts"; extraParams = "select=id,displayName,description" }
                    @{ id = "configurationPolicies"; url = "deviceManagement/configurationPolicies"; extraParams = "select=id,name,description" }
                    @{ id = "groupPolicyConfigs"; url = "deviceManagement/groupPolicyConfigurations"; extraParams = "select=id,displayName,description" }
                    @{ id = "wipPolicies"; url = "deviceAppManagement/windowsInformationProtectionPolicies"; extraParams = "select=id,displayName,description" }
                    @{ id = "mdmWipPolicies"; url = "deviceAppManagement/mdmWindowsInformationProtectionPolicies"; extraParams = "select=id,displayName,description" }
                )
            }
        
            # Build batch request
            foreach ($endpoint in $resourceEndpoints)
            {
                $requestUrl = "$($endpoint.url)?`$$($endpoint.extraParams)"
                $batchRequestBody.requests += @{
                    id     = $endpoint.id
                    method = "GET"
                    url    = $requestUrl
                }
            }
        
            Write-Log -logFile $LogFile -module $functionName -Message "Sending batch request for $($resourceEndpoints.Count) resource lists" -logLevel "Information"
        
            # Send batch request
            $batchResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath "`$batch" -APIVersion $apiVersion -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth $global:maxJSONDepth)
        
            # Initialize variables for all resource types
            $mobileApps = @()
            $deviceConfigs = @()
            $compliancePolicies = @()
            $autopilotProfiles = @()
            $deviceScripts = @()
            $healthScripts = @()
            $appProtectionPolicies = @()
            $intents = @()
            $resourceAccessProfiles = @()
            $configurationPolicies = @()
            $groupPolicyConfigs = @()
            $policySets = @()
            $wipPolicies = @()
            $mdmWipPolicies = @()
        
            # Process batch response
            if ($batchResponse -and $batchResponse.responses)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Processing batch response for resource lists" -LogLevel "Verbose"
            
                foreach ($response in $batchResponse.responses)
                {
                    if ($response.status -eq 200 -and $response.body -and $response.body.value)
                    {
                        switch ($response.id)
                        {
                            "mobileApps"
                            {
                                $mobileApps = $response.body.value 
                            }
                            "deviceConfigs"
                            {
                                $deviceConfigs = $response.body.value 
                            }
                            "compliancePolicies"
                            {
                                $compliancePolicies = $response.body.value 
                            }
                            "deviceScripts"
                            {
                                $deviceScripts = $response.body.value 
                            }
                            "appProtectionPolicies"
                            {
                                $appProtectionPolicies = $response.body.value 
                            }
                            "intents"
                            {
                                $intents = $response.body.value 
                            }
                            "resourceAccessProfiles"
                            {
                                $resourceAccessProfiles = $response.body.value 
                            }
                            "autopilotProfiles"
                            {
                                $autopilotProfiles = $response.body.value 
                            }
                            "healthScripts"
                            {
                                $healthScripts = $response.body.value 
                            }
                            "configurationPolicies"
                            { 
                                # Configuration policies use 'name' instead of 'displayName', so we normalize it
                                $configurationPolicies = $response.body.value | ForEach-Object { 
                                    $_ | Add-Member -NotePropertyName 'displayName' -NotePropertyValue $_.name -Force -PassThru
                                }
                            }
                            "groupPolicyConfigs"
                            {
                                $groupPolicyConfigs = $response.body.value 
                            }
                            "policySets"
                            {
                                $policySets = $response.body.value
                            }
                            "wipPolicies"
                            {
                                $wipPolicies = $response.body.value
                            }
                            "mdmWipPolicies"
                            {
                                $mdmWipPolicies = $response.body.value
                            }
                        }
                    }
                    elseif ($response.status -ne 200)
                    {
                        Write-Log -logFile $LogFile -module $functionName -Message "Failed to get resource list for $($response.id). Status: $($response.status)" -logLevel "Warning"
                    }
                }
            }
        
            Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts via batch - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count)" -logLevel "Information"
            
            # Cache the resource lists for future use
            $resourceListsToCache = @{
                mobileApps             = $mobileApps
                deviceConfigs          = $deviceConfigs
                compliancePolicies     = $compliancePolicies
                autopilotProfiles      = $autopilotProfiles
                deviceScripts          = $deviceScripts
                healthScripts          = $healthScripts
                appProtectionPolicies  = $appProtectionPolicies
                intents                = $intents
                resourceAccessProfiles = $resourceAccessProfiles
                configurationPolicies  = $configurationPolicies
                groupPolicyConfigs     = $groupPolicyConfigs
                policySets             = $policySets
                wipPolicies            = $wipPolicies
                mdmWipPolicies         = $mdmWipPolicies
            }
            
            $cached = Set-CachedData -CacheType 'Configuration' -Key $resourceListCacheKey -Data $resourceListsToCache -Metadata @{ApiVersion = $apiVersionKey; FetchedAt = Get-Date}
            if ($cached)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached resource lists for API version: $apiVersionKey" -logLevel "Verbose"
            }
        }
        
        # Process assignments using CallGraphAPI's built-in batch support for each resource type
        Get-ResourceAssignments -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -AssignmentCategory "Application"
        Get-ResourceAssignments -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -AssignmentCategory "Configuration"
        Get-ResourceAssignments -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -AssignmentCategory "Compliance"
        Get-ResourceAssignments -Resources $deviceScripts -ResourceType "Device Management Scripts" -BaseUri "deviceManagement/deviceManagementScripts" -AssignmentCategory "Script"
        Get-ResourceAssignments -Resources $appProtectionPolicies -ResourceType "App Protection Policies" -BaseUri "deviceAppManagement/managedAppPolicies" -AssignmentCategory "AppProtection"
        Get-ResourceAssignments -Resources $intents -ResourceType "Device Management Intents" -BaseUri "deviceManagement/intents" -AssignmentCategory "Intent"
        Get-ResourceAssignments -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles" -BaseUri "deviceManagement/resourceAccessProfiles" -AssignmentCategory "ResourceAccess"
        Get-ResourceAssignments -Resources $policySets -ResourceType "Policy Sets" -BaseUri "deviceAppManagement/policySets" -AssignmentCategory "PolicySet"
        
        if ($IncludeBeta.IsPresent)
        {
            Get-ResourceAssignments -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -AssignmentCategory "AutopilotProfile"
            Get-ResourceAssignments -Resources $healthScripts -ResourceType "Device Health Scripts" -BaseUri "deviceManagement/deviceHealthScripts" -AssignmentCategory "HealthScript"
            Get-ResourceAssignments -Resources $configurationPolicies -ResourceType "Configuration Policies" -BaseUri "deviceManagement/configurationPolicies" -AssignmentCategory "ConfigurationPolicy"
            Get-ResourceAssignments -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations" -BaseUri "deviceManagement/groupPolicyConfigurations" -AssignmentCategory "GroupPolicy"
            Get-ResourceAssignments -Resources $wipPolicies -ResourceType "Windows Information Protection" -BaseUri "deviceAppManagement/windowsInformationProtectionPolicies" -AssignmentCategory "WindowsInformationProtection"
            Get-ResourceAssignments -Resources $mdmWipPolicies -ResourceType "MDM Windows Information Protection" -BaseUri "deviceAppManagement/mdmWindowsInformationProtectionPolicies" -AssignmentCategory "WindowsInformationProtection"
        }
        
        Write-Log -logFile $LogFile -module $functionName -Message "Batch processing complete. Found assignments - Apps: $($assignments.AppAssignments.Count), Configs: $($assignments.ConfigurationAssignments.Count), Compliance: $($assignments.ComplianceAssignments.Count), Autopilot: $($assignments.AutopilotAssignments.Count), Scripts: $($assignments.ScriptAssignments.Count), HealthScripts: $($assignments.HealthScriptAssignments.Count), AppProtection: $($assignments.AppProtectionAssignments.Count), Intents: $($assignments.IntentAssignments.Count), ResourceAccess: $($assignments.ResourceAccessAssignments.Count), ConfigPolicies: $($assignments.ConfigurationPolicyAssignments.Count), GroupPolicy: $($assignments.GroupPolicyAssignments.Count), WIP: $($assignments.WindowsInformationProtectionAssignments.Count), PolicySets: $($assignments.PolicySetAssignments.Count)" -LogLevel "Verbose"
        
        # Cache the direct assignments for this group (before merging with indirect)
        if ($groupIdValue -and $assignments.AllAssignments.Count -gt 0)
        {
            $directAssignmentsCacheKey = "GroupDirectAssignments_${groupIdValue}_${apiVersionKey}"
            $directAssignmentsData = @{
                GroupName                               = $assignments.GroupName
                GroupId                                 = $assignments.GroupId
                AppAssignments                          = $assignments.AppAssignments
                ConfigurationAssignments                = $assignments.ConfigurationAssignments
                ComplianceAssignments                   = $assignments.ComplianceAssignments
                AutopilotAssignments                    = $assignments.AutopilotAssignments
                ScriptAssignments                       = $assignments.ScriptAssignments
                HealthScriptAssignments                 = $assignments.HealthScriptAssignments
                AppProtectionAssignments                = $assignments.AppProtectionAssignments
                IntentAssignments                       = $assignments.IntentAssignments
                ResourceAccessAssignments               = $assignments.ResourceAccessAssignments
                ConfigurationPolicyAssignments          = $assignments.ConfigurationPolicyAssignments
                GroupPolicyAssignments                  = $assignments.GroupPolicyAssignments
                WindowsInformationProtectionAssignments = $assignments.WindowsInformationProtectionAssignments
                PolicySetAssignments                    = $assignments.PolicySetAssignments
                AllAssignments                          = $assignments.AllAssignments
            }
            
            $cached = Set-CachedData -CacheType 'DirectoryObjects' -Key $directAssignmentsCacheKey -Data $directAssignmentsData -Metadata @{GroupId = $groupIdValue; ApiVersion = $apiVersionKey; FetchedAt = Get-Date; Type = 'DirectAssignments'}
            if ($cached)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached direct assignments for group: $($assignments.GroupName)" -logLevel "Verbose"
            }
        }
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error in batch assignment processing: $($_.Exception.Message)" -LogLevel "Verbose"
    }
    
    # Get indirect assignments if requested (All Users and All Devices)
    if ($IncludeIndirectAssignments.IsPresent)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Retrieving indirect assignments (All Users and All Devices)" -logLevel "Information"
        Write-Verbose "[$functionName] Retrieving indirect assignments"
        
        try
        {
            $indirectAssignments = GetGroupIndirectAssignments -AccessToken $AccessToken -IncludeBeta:$IncludeBeta -BatchSize $BatchSize
            
            if ($indirectAssignments -and $indirectAssignments.AllAssignments.Count -gt 0)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Found $($indirectAssignments.AllAssignments.Count) indirect assignments" -logLevel "Information"
                
                # Merge indirect assignments with direct assignments
                $assignments.AppAssignments += $indirectAssignments.AppAssignments
                $assignments.ConfigurationAssignments += $indirectAssignments.ConfigurationAssignments
                $assignments.ComplianceAssignments += $indirectAssignments.ComplianceAssignments
                $assignments.AutopilotAssignments += $indirectAssignments.AutopilotAssignments
                $assignments.ScriptAssignments += $indirectAssignments.ScriptAssignments
                $assignments.HealthScriptAssignments += $indirectAssignments.HealthScriptAssignments
                $assignments.AppProtectionAssignments += $indirectAssignments.AppProtectionAssignments
                $assignments.IntentAssignments += $indirectAssignments.IntentAssignments
                $assignments.ResourceAccessAssignments += $indirectAssignments.ResourceAccessAssignments
                $assignments.ConfigurationPolicyAssignments += $indirectAssignments.ConfigurationPolicyAssignments
                $assignments.GroupPolicyAssignments += $indirectAssignments.GroupPolicyAssignments
                $assignments.WindowsInformationProtectionAssignments += $indirectAssignments.WindowsInformationProtectionAssignments
                $assignments.PolicySetAssignments += $indirectAssignments.PolicySetAssignments
                $assignments.AllAssignments += $indirectAssignments.AllAssignments
                
                Write-Log -logFile $LogFile -module $functionName -Message "Merged indirect assignments with direct assignments" -logLevel "Information"
            }
            else
            {
                Write-Log -logFile $LogFile -module $functionName -Message "No indirect assignments found" -logLevel "Information"
            }
        }
        catch
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Error retrieving indirect assignments: $($_.Exception.Message)" -LogLevel "Warning"
            Write-Verbose "[$functionName] Error retrieving indirect assignments: $($_.Exception.Message)"
        }
    }
    
    # Summary
    $totalAssignments = $assignments.AllAssignments.Count
    $summaryTitle = if ($IncludeIndirectAssignments.IsPresent) { "Group Direct and Indirect Assignments Summary" } else { "Group Direct Assignments Summary" }
    Write-Log -logFile $LogFile -module $functionName -Message "Total assignments found for group '$($groupId.displayName)': $totalAssignments" -LogLevel "Verbose"
    if ($ShowSummary)
    {
        Write-Host "$summaryTitle for '$($groupId.displayName)':" -ForegroundColor Green
        Write-Host "  Apps: $($assignments.AppAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Configurations: $($assignments.ConfigurationAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Compliance Policies: $($assignments.ComplianceAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Scripts: $($assignments.ScriptAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  App Protection Policies: $($assignments.AppProtectionAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Security Intents: $($assignments.IntentAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Resource Access Profiles: $($assignments.ResourceAccessAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Policy Sets: $($assignments.PolicySetAssignments.Count)" -ForegroundColor Yellow
        if ($IncludeBeta.IsPresent)
        {
            Write-Host "  Autopilot Profiles: $($assignments.AutopilotAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Health Scripts: $($assignments.HealthScriptAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Configuration Policies: $($assignments.ConfigurationPolicyAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Group Policy Configurations: $($assignments.GroupPolicyAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Windows Information Protection: $($assignments.WindowsInformationProtectionAssignments.Count)" -ForegroundColor Yellow
        }
        Write-Host "  Total: $totalAssignments" -ForegroundColor Cyan
    }
    return $assignments
}