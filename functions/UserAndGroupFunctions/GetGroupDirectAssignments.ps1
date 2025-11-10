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
        [int] $BatchSize = 20,
        [Parameter(Mandatory = $false)]
        [hashtable] $Settings
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
    Write-Verbose "[$functionName] Settings provided: $($null -ne $Settings)"
    if ($Settings) { Write-Verbose "[$functionName] Settings.operatingSystem: $($Settings.operatingSystem)" }
    #now write-log them.
    Write-Log -logFile $LogFile -module $functionName -Message "Incoming parameters:" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "GroupName: $GroupName" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "IncludeBeta: $IncludeBeta" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "ShowSummary: $ShowSummary" -LogLevel "Verbose"
    Write-Log -logFile $LogFile -module $functionName -Message "IncludeIndirectAssignments: $IncludeIndirectAssignments" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "BatchSize: $BatchSize" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "Settings provided: $($null -ne $Settings)" -logLevel "Information"
    if ($Settings -and $Settings.operatingSystem)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Settings.operatingSystem: $($Settings.operatingSystem)" -logLevel "Information"
    }
    $groupIds = $GroupName
    $groupIdArray = @($groupIds)
    $groupId = $groupIdArray[0]
    Write-Log -logFile $LogFile -module $functionName -Message "Group name: $($groupId.displayName)" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "Group ID: $($groupId.Id)" -logLevel "Information"
    #endregion

    # Initialize result object early (before validation) using common function
    $assignments = Initialize-AssignmentResultObject -GroupName $groupId.displayName -GroupId $groupId.Id
    
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
    
    # Check for cached direct assignments
    $apiVersionKey = $apiVersion
    $directAssignmentsCacheKey = "GroupDirectAssignments_${groupIdValue}_${apiVersionKey}"
    $cachedDirectAssignments = Get-CachedData -Key $directAssignmentsCacheKey -CacheType DirectoryObjects
    
    if ($cachedDirectAssignments)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Using cached direct assignments for group: $($groupId.displayName)" -logLevel "Verbose"
        Write-Verbose "[$functionName] Cache hit for direct assignments"
        
        # Restore assignments from cache
        $assignments.GroupName = $cachedDirectAssignments.GroupName
        $assignments.GroupId = $cachedDirectAssignments.GroupId
        $assignments.AppAssignments = $cachedDirectAssignments.AppAssignments
        $assignments.ConfigurationAssignments = $cachedDirectAssignments.ConfigurationAssignments
        $assignments.ComplianceAssignments = $cachedDirectAssignments.ComplianceAssignments
        $assignments.AutopilotAssignments = $cachedDirectAssignments.AutopilotAssignments
        $assignments.ScriptAssignments = $cachedDirectAssignments.ScriptAssignments
        $assignments.HealthScriptAssignments = $cachedDirectAssignments.HealthScriptAssignments
        $assignments.AppProtectionAssignments = $cachedDirectAssignments.AppProtectionAssignments
        $assignments.IntentAssignments = $cachedDirectAssignments.IntentAssignments
        $assignments.ResourceAccessAssignments = $cachedDirectAssignments.ResourceAccessAssignments
        $assignments.ConfigurationPolicyAssignments = $cachedDirectAssignments.ConfigurationPolicyAssignments
        $assignments.GroupPolicyAssignments = $cachedDirectAssignments.GroupPolicyAssignments
        $assignments.WindowsInformationProtectionAssignments = $cachedDirectAssignments.WindowsInformationProtectionAssignments
        $assignments.PolicySetAssignments = $cachedDirectAssignments.PolicySetAssignments
        $assignments.WindowsFeatureUpdateAssignments = $cachedDirectAssignments.WindowsFeatureUpdateAssignments
        $assignments.WindowsQualityUpdateAssignments = $cachedDirectAssignments.WindowsQualityUpdateAssignments
        $assignments.WindowsDriverUpdateAssignments = $cachedDirectAssignments.WindowsDriverUpdateAssignments
        $assignments.AllAssignments = $cachedDirectAssignments.AllAssignments
        
        Write-Log -logFile $LogFile -module $functionName -Message "Restored $($assignments.AllAssignments.Count) cached direct assignments" -logLevel "Information"
        
        # If indirect assignments requested, fetch and merge them
        if ($IncludeIndirectAssignments.IsPresent)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Retrieving indirect assignments (All Users and All Devices)" -logLevel "Information"
            Write-Verbose "[$functionName] Retrieving indirect assignments"
            
            try
            {
                $indirectAssignments = GetGroupIndirectAssignments -AccessToken $AccessToken -IncludeBeta:$IncludeBeta -BatchSize $BatchSize -Settings $Settings
                
                if ($indirectAssignments -and $indirectAssignments.AllAssignments.Count -gt 0)
                {
                    Write-Log -logFile $LogFile -module $functionName -Message "Found $($indirectAssignments.AllAssignments.Count) indirect assignments" -logLevel "Information"
                    
                    # Merge indirect assignments with cached direct assignments
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
                    $assignments.WindowsFeatureUpdateAssignments += $indirectAssignments.WindowsFeatureUpdateAssignments
                    $assignments.WindowsQualityUpdateAssignments += $indirectAssignments.WindowsQualityUpdateAssignments
                    $assignments.WindowsDriverUpdateAssignments += $indirectAssignments.WindowsDriverUpdateAssignments
                    $assignments.AllAssignments += $indirectAssignments.AllAssignments
                    
                    # Also merge FailedResources from indirect assignments
                    if ($indirectAssignments.FailedResources -and $indirectAssignments.FailedResources.Count -gt 0)
                    {
                        $assignments.FailedResources += $indirectAssignments.FailedResources
                    }
                    
                    Write-Log -logFile $LogFile -module $functionName -Message "After merging: Total assignments = $($assignments.AllAssignments.Count)" -logLevel "Information"
                }
            }
            catch
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Error retrieving indirect assignments: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        
        # Return cached assignments (with or without indirect merge)
        return $assignments
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Cache miss - fetching direct assignments from Graph API" -logLevel "Verbose"
    Write-Verbose "[$functionName] No cached direct assignments found, fetching from API"
    
    try
    {
        # Get all resource lists using unified helper function
        Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for assignments using unified helper" -logLevel "Information"
        
        $resourceLists = Get-IntuneResourceLists -AccessToken $AccessToken -IncludeBeta:$IncludeBeta -Settings $Settings -ResultObject $assignments
        
        # Extract resource lists from helper result
        $mobileApps = $resourceLists.mobileApps
        $deviceConfigs = $resourceLists.deviceConfigs
        $compliancePolicies = $resourceLists.compliancePolicies
        $autopilotProfiles = $resourceLists.autopilotProfiles
        $deviceScripts = $resourceLists.deviceScripts
        $healthScripts = $resourceLists.healthScripts
        $appProtectionPolicies = $resourceLists.appProtectionPolicies
        $intents = $resourceLists.intents
        $resourceAccessProfiles = $resourceLists.resourceAccessProfiles
        $configurationPolicies = $resourceLists.configurationPolicies
        $groupPolicyConfigs = $resourceLists.groupPolicyConfigs
        $policySets = $resourceLists.policySets
        $wipPolicies = $resourceLists.wipPolicies
        $mdmWipPolicies = $resourceLists.mdmWipPolicies
        
        Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts from helper - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count)" -logLevel "Information"
        
        # Process assignments using unified function from Get-GroupAssignments-Common.ps1
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -EndpointId "mobileApps" -AssignmentMode "Direct"
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -EndpointId "deviceConfigs" -AssignmentMode "Direct"
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -EndpointId "compliancePolicies" -AssignmentMode "Direct"
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $deviceScripts -ResourceType "Device Management Scripts" -BaseUri "deviceManagement/deviceManagementScripts" -EndpointId "deviceScripts" -AssignmentMode "Direct"
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $appProtectionPolicies -ResourceType "App Protection Policies" -BaseUri "deviceAppManagement/managedAppPolicies" -EndpointId "appProtectionPolicies" -AssignmentMode "Direct"
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $intents -ResourceType "Device Management Intents" -BaseUri "deviceManagement/intents" -EndpointId "intents" -AssignmentMode "Direct"
        Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $policySets -ResourceType "Policy Sets" -BaseUri "deviceAppManagement/policySets" -EndpointId "policySets" -AssignmentMode "Direct"
        
        if ($IncludeBeta.IsPresent)
        {
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -EndpointId "autopilotProfiles" -AssignmentMode "Direct"
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $healthScripts -ResourceType "Health Scripts" -BaseUri "deviceManagement/deviceHealthScripts" -EndpointId "healthScripts" -AssignmentMode "Direct"
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles" -BaseUri "deviceManagement/resourceAccessProfiles" -EndpointId "resourceAccessProfiles" -AssignmentMode "Direct"
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $configurationPolicies -ResourceType "Configuration Policies" -BaseUri "deviceManagement/configurationPolicies" -EndpointId "configurationPolicies" -AssignmentMode "Direct"
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations" -BaseUri "deviceManagement/groupPolicyConfigurations" -EndpointId "groupPolicyConfigs" -AssignmentMode "Direct"
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $wipPolicies -ResourceType "Windows Information Protection Policies" -BaseUri "deviceAppManagement/windowsInformationProtectionPolicies" -EndpointId "wipPolicies" -AssignmentMode "Direct"
            Get-ResourceAssignments -ResultObject $assignments -AccessToken $AccessToken -ApiVersion $apiVersion -GroupIdValue $groupIdValue -Resources $mdmWipPolicies -ResourceType "MDM Windows Information Protection Policies" -BaseUri "deviceAppManagement/mdmWindowsInformationProtectionPolicies" -EndpointId "mdmWipPolicies" -AssignmentMode "Direct"
        }
        
        Write-Log -logFile $LogFile -module $functionName -Message "Batch processing complete. Found assignments - Apps: $($assignments.AppAssignments.Count), Configs: $($assignments.ConfigurationAssignments.Count), Compliance: $($assignments.ComplianceAssignments.Count), Autopilot: $($assignments.AutopilotAssignments.Count), Scripts: $($assignments.ScriptAssignments.Count), HealthScripts: $($assignments.HealthScriptAssignments.Count), AppProtection: $($assignments.AppProtectionAssignments.Count), Intents: $($assignments.IntentAssignments.Count), ResourceAccess: $($assignments.ResourceAccessAssignments.Count), ConfigPolicies: $($assignments.ConfigurationPolicyAssignments.Count), GroupPolicy: $($assignments.GroupPolicyAssignments.Count), WIP: $($assignments.WindowsInformationProtectionAssignments.Count), PolicySets: $($assignments.PolicySetAssignments.Count)" -LogLevel "Verbose"
        
        # Cache the direct assignments for this group (even if empty, to avoid re-fetching)
        if ($groupIdValue)
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
                WindowsFeatureUpdateAssignments         = $assignments.WindowsFeatureUpdateAssignments
                WindowsQualityUpdateAssignments         = $assignments.WindowsQualityUpdateAssignments
                WindowsDriverUpdateAssignments          = $assignments.WindowsDriverUpdateAssignments
                AllAssignments                          = $assignments.AllAssignments
                FailedResources                         = $assignments.FailedResources
            }
            
            $cached = Set-CachedData -CacheType 'DirectoryObjects' -Key $directAssignmentsCacheKey -Data $directAssignmentsData -Metadata @{GroupId = $groupIdValue; ApiVersion = $apiVersionKey; FetchedAt = Get-Date; Type = 'DirectAssignments'}
            if ($cached)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached direct assignments for group: $($assignments.GroupName) (count: $($assignments.AllAssignments.Count))" -logLevel "Verbose"
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
            $indirectAssignments = GetGroupIndirectAssignments -AccessToken $AccessToken -IncludeBeta:$IncludeBeta -BatchSize $BatchSize -Settings $Settings
            
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
                $assignments.WindowsFeatureUpdateAssignments += $indirectAssignments.WindowsFeatureUpdateAssignments
                $assignments.WindowsQualityUpdateAssignments += $indirectAssignments.WindowsQualityUpdateAssignments
                $assignments.WindowsDriverUpdateAssignments += $indirectAssignments.WindowsDriverUpdateAssignments
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