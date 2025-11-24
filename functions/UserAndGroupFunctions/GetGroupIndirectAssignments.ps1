function GetGroupIndirectAssignments()
{
    <#
    .SYNOPSIS
    Retrieves indirect assignments for All Users and All Devices virtual groups.
    
    .DESCRIPTION
    This function retrieves assignments that are indirectly assigned via the special
    Intune virtual groups "All Users" and "All Devices". These assignments use special
    OData types in Microsoft Graph API:
    - All Users: #microsoft.graph.allLicensedUsersAssignmentTarget
    - All Devices: #microsoft.graph.allDevicesAssignmentTarget
    
    When GroupId is specified, only resources that have BOTH the group assignment AND
    All Users/All Devices assignments are returned.
    
    When GroupId is not specified, ALL resources with All Users/All Devices assignments
    are returned (regardless of other group assignments).
    
    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.
    
    .PARAMETER GroupId
    Optional. When specified, filters to show only resources that have assignments to
    BOTH this group AND All Users/All Devices.
    
    .PARAMETER IncludeBeta
    Switch to include beta API endpoints for additional resource types.
    
    .PARAMETER BatchSize
    The batch size for API requests (default: 20).
    
    .PARAMETER Settings
    Optional settings hashtable for platform filtering and other options.
    
    .EXAMPLE
    GetGroupIndirectAssignments -AccessToken $token -IncludeBeta
    Returns all resources assigned to All Users or All Devices.
    
    .EXAMPLE
    GetGroupIndirectAssignments -AccessToken $token -GroupId "abc-123" -IncludeBeta
    Returns only resources assigned to BOTH the specified group AND All Users/All Devices.
    
    .NOTES
    This function can be used standalone or integrated with GetGroupDirectAssignments.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [string]$GroupId,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBeta,
        [Parameter(Mandatory = $false)]
        [int]$BatchSize = 20,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Log parameters
    $modeDesc = if ($GroupId) { "with GroupId filter (show resources with BOTH group and All Users/All Devices)" } else { "without GroupId filter (show ALL All Users/All Devices)" }
    Write-Verbose "[$functionName] Retrieving indirect assignments (All Users and All Devices) $modeDesc"
    Write-Log -logFile $LogFile -module $functionName -Message "Retrieving indirect assignments (All Users and All Devices) $modeDesc" -logLevel "Information"
    
    # Log Settings parameter
    Write-Verbose "[$functionName] Settings provided: $($null -ne $Settings)"
    Write-Log -logFile $LogFile -module $functionName -Message "Settings provided: $($null -ne $Settings)" -logLevel "Information"
    if ($Settings -and $Settings.operatingSystem)
    {
        Write-Verbose "[$functionName] Settings.operatingSystem: $($Settings.operatingSystem)"
        Write-Log -logFile $LogFile -module $functionName -Message "Settings.operatingSystem: $($Settings.operatingSystem)" -logLevel "Information"
    }
    
    # Initialize result object using common function
    $indirectAssignments = Initialize-AssignmentResultObject
    
    # Determine API version
    $apiVersion = if ($IncludeBeta.IsPresent) { 'beta' } else { 'v1.0' }
    Write-Log -logFile $LogFile -module $functionName -Message "Using API version: $apiVersion" -logLevel "Information"
    
    # Check for cached indirect assignments
    # NOTE: Cache is only used when NO GroupId filter is specified (showing ALL indirect assignments)
    # When GroupId is specified, we always fetch fresh to ensure accuracy
    $apiVersionKey = $apiVersion
    $indirectAssignmentsCacheKey = "AllIndirectAssignments_${apiVersionKey}"
    $cachedIndirectAssignments = $null
    
    if (-not $GroupId)
    {
        $cachedIndirectAssignments = Get-CachedData -Key $indirectAssignmentsCacheKey -CacheType Configuration
    }
    
    if ($cachedIndirectAssignments)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Using cached indirect assignments" -logLevel "Verbose"
        Write-Verbose "[$functionName] Cache hit for indirect assignments"
        
        # Restore assignments from cache
        $indirectAssignments.AppAssignments = $cachedIndirectAssignments.AppAssignments
        $indirectAssignments.ConfigurationAssignments = $cachedIndirectAssignments.ConfigurationAssignments
        $indirectAssignments.ComplianceAssignments = $cachedIndirectAssignments.ComplianceAssignments
        $indirectAssignments.AutopilotAssignments = $cachedIndirectAssignments.AutopilotAssignments
        $indirectAssignments.ScriptAssignments = $cachedIndirectAssignments.ScriptAssignments
        $indirectAssignments.HealthScriptAssignments = $cachedIndirectAssignments.HealthScriptAssignments
        $indirectAssignments.AppProtectionAssignments = $cachedIndirectAssignments.AppProtectionAssignments
        $indirectAssignments.IntentAssignments = $cachedIndirectAssignments.IntentAssignments
        $indirectAssignments.ResourceAccessAssignments = $cachedIndirectAssignments.ResourceAccessAssignments
        $indirectAssignments.ConfigurationPolicyAssignments = $cachedIndirectAssignments.ConfigurationPolicyAssignments
        $indirectAssignments.GroupPolicyAssignments = $cachedIndirectAssignments.GroupPolicyAssignments
        $indirectAssignments.WindowsInformationProtectionAssignments = $cachedIndirectAssignments.WindowsInformationProtectionAssignments
        $indirectAssignments.PolicySetAssignments = $cachedIndirectAssignments.PolicySetAssignments
        if ($cachedIndirectAssignments.PSObject.Properties['WindowsFeatureUpdateAssignments'])
        {
            $indirectAssignments.WindowsFeatureUpdateAssignments = $cachedIndirectAssignments.WindowsFeatureUpdateAssignments
        }
        if ($cachedIndirectAssignments.PSObject.Properties['WindowsQualityUpdateAssignments'])
        {
            $indirectAssignments.WindowsQualityUpdateAssignments = $cachedIndirectAssignments.WindowsQualityUpdateAssignments
        }
        if ($cachedIndirectAssignments.PSObject.Properties['WindowsDriverUpdateAssignments'])
        {
            $indirectAssignments.WindowsDriverUpdateAssignments = $cachedIndirectAssignments.WindowsDriverUpdateAssignments
        }
        $indirectAssignments.AllAssignments = $cachedIndirectAssignments.AllAssignments
        
        # Restore FailedResources if present
        if ($cachedIndirectAssignments.FailedResources -and $cachedIndirectAssignments.FailedResources.Count -gt 0)
        {
            $indirectAssignments.FailedResources = $cachedIndirectAssignments.FailedResources
        }
        
        Write-Log -logFile $LogFile -module $functionName -Message "Restored $($indirectAssignments.AllAssignments.Count) cached indirect assignments" -logLevel "Information"
        
        return $indirectAssignments
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Cache miss - fetching indirect assignments from Graph API" -logLevel "Verbose"
    Write-Verbose "[$functionName] No cached indirect assignments found, fetching from API"
    
    try
    {
        # Get all resource lists using batch API
        Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for indirect assignments using batch API" -logLevel "Information"
        
        # Check cache for resource lists first
        $apiVersionKey = if ($IncludeBeta.IsPresent) { "beta" } else { "v1.0" }
        $resourceListCacheKey = "IndirectResourceLists_${apiVersionKey}"
        $cachedResourceLists = Get-CachedData -CacheType 'Configuration' -Key $resourceListCacheKey
        
        if ($cachedResourceLists)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Using cached resource lists for indirect assignments (API: $apiVersionKey)" -logLevel "Verbose"
            Write-Verbose "[$functionName] Cache hit for indirect resource lists"
            
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
            
            # Identify resources that failed previously (marked as $null in cache) and retry them
            $resourcesToRetry = @()
            $allResourceIds = @('mobileApps', 'deviceConfigs', 'compliancePolicies', 'deviceScripts', 'appProtectionPolicies', 'intents', 'policySets')
            if ($IncludeBeta.IsPresent)
            {
                $allResourceIds += @('autopilotProfiles', 'healthScripts', 'configurationPolicies', 'groupPolicyConfigs', 'wipPolicies', 'resourceAccessProfiles', 'mdmWipPolicies')
            }
            
            foreach ($resourceId in $allResourceIds)
            {
                if ($null -eq $cachedResourceLists[$resourceId])
                {
                    $resourcesToRetry += $resourceId
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$resourceId' was $null in cache (failed previously), will retry" -logLevel "Verbose"
                }
            }
            
            # Retry failed resources if any
            if ($resourcesToRetry.Count -gt 0)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Retrying $($resourcesToRetry.Count) previously failed resources" -logLevel "Information"
                
                # Build retry batch request
                $retryBatchBody = @{ requests = @() }
                
                foreach ($resourceId in $resourcesToRetry)
                {
                    # Map resource ID to endpoint
                    $endpoint = switch ($resourceId)
                    {
                        'mobileApps' { @{ url = "deviceAppManagement/mobileApps"; extraParams = "select=id,displayName,description" } }
                        'deviceConfigs' { @{ url = "deviceManagement/deviceConfigurations"; extraParams = "select=id,displayName,description" } }
                        'compliancePolicies' { @{ url = "deviceManagement/deviceCompliancePolicies"; extraParams = "select=id,displayName,description" } }
                        'deviceScripts' { @{ url = "deviceManagement/deviceManagementScripts"; extraParams = "select=id,displayName,description" } }
                        'appProtectionPolicies' { @{ url = "deviceAppManagement/managedAppPolicies"; extraParams = "select=id,displayName,description" } }
                        'intents' { @{ url = "deviceManagement/intents"; extraParams = "select=id,displayName,description" } }
                        'resourceAccessProfiles' { @{ url = "deviceManagement/resourceAccessProfiles"; extraParams = "select=id,displayName,description" } }
                        'policySets' { @{ url = "deviceAppManagement/policySets"; extraParams = "select=id,displayName,description" } }
                        'autopilotProfiles' { @{ url = "deviceManagement/windowsAutopilotDeploymentProfiles"; extraParams = "select=id,displayName,description" } }
                        'healthScripts' { @{ url = "deviceManagement/deviceHealthScripts"; extraParams = "select=id,displayName,description" } }
                        'configurationPolicies' { @{ url = "deviceManagement/configurationPolicies"; extraParams = "select=id,name,description" } }
                        'groupPolicyConfigs' { @{ url = "deviceManagement/groupPolicyConfigurations"; extraParams = "select=id,displayName,description" } }
                        'wipPolicies' { @{ url = "deviceAppManagement/windowsInformationProtectionPolicies"; extraParams = "select=id,displayName,description" } }
                        'mdmWipPolicies' { @{ url = "deviceAppManagement/mdmWindowsInformationProtectionPolicies"; extraParams = "select=id,displayName,description" } }
                    }
                    
                    if ($endpoint)
                    {
                        $requestUrl = "$($endpoint.url)?`$$($endpoint.extraParams)"
                        $retryBatchBody.requests += @{
                            id     = $resourceId
                            method = "GET"
                            url    = $requestUrl
                        }
                    }
                }
                
                # Send retry batch request
                try
                {
                    $retryResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath "`$batch" -APIVersion $apiVersion -Method "POST" -Body ($retryBatchBody | ConvertTo-Json -Depth $global:maxJSONDepth)
                    
                    if ($retryResponse -and $retryResponse.responses)
                    {
                        foreach ($response in $retryResponse.responses)
                        {
                            if ($response.status -eq 200 -and $response.body -and $response.body.value)
                            {
                                # Success! Update the variable
                                switch ($response.id)
                                {
                                    "mobileApps" { $mobileApps = $response.body.value }
                                    "deviceConfigs" { $deviceConfigs = $response.body.value }
                                    "compliancePolicies" { $compliancePolicies = $response.body.value }
                                    "deviceScripts" { $deviceScripts = $response.body.value }
                                    "appProtectionPolicies" { $appProtectionPolicies = $response.body.value }
                                    "intents" { $intents = $response.body.value }
                                    "resourceAccessProfiles" { $resourceAccessProfiles = $response.body.value }
                                    "policySets" { $policySets = $response.body.value }
                                    "autopilotProfiles" { $autopilotProfiles = $response.body.value }
                                    "healthScripts" { $healthScripts = $response.body.value }
                                    "configurationPolicies"
                                    {
                                        $configurationPolicies = $response.body.value | ForEach-Object {
                                            $_ | Add-Member -NotePropertyName 'displayName' -NotePropertyValue $_.name -Force -PassThru
                                        }
                                    }
                                    "groupPolicyConfigs" { $groupPolicyConfigs = $response.body.value }
                                    "wipPolicies" { $wipPolicies = $response.body.value }
                                    "mdmWipPolicies" { $mdmWipPolicies = $response.body.value }
                                }
                                Write-Log -logFile $LogFile -module $functionName -Message "Retry successful for '$($response.id)' - fetched $($response.body.value.Count) items" -logLevel "Information"
                            }
                            elseif ($response.status -ne 200)
                            {
                                # Still failing - track the error with categorization
                                $errorMessage = "API returned status $($response.status)"
                                $errorCode = $response.status.ToString()
                                
                                if ($response.body -and $response.body.error)
                                {
                                    $errorMessage += ": $($response.body.error.message)"
                                    if ($response.body.error.code)
                                    {
                                        $errorCode = $response.body.error.code
                                    }
                                }
                                
                                # Categorize error using common helper
                                $errorCategory = Get-ErrorCategory -ErrorCode $errorCode -ErrorMessage $errorMessage -ResourceType $response.id -ODataType ""
                                $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorCode -ResourceType $response.id -ODataType ""
                                
                                Write-Log -logFile $LogFile -module $functionName -Message "Retry failed for '$($response.id)'. Category: $errorCategory, Error: $errorMessage" -logLevel "Warning"
                                Write-Log -logFile $LogFile -module $functionName -Message "Remediation guidance: $remediationGuidance" -logLevel "Information"
                                
                                Add-FailedResourceError -ResultObject $indirectAssignments -ResourceType $response.id -ErrorMessage $errorMessage -StatusCode $response.status -ApiVersion $apiVersion
                            }
                        }
                    }
                }
                catch
                {
                    Write-Log -logFile $LogFile -module $functionName -Message "Error during retry batch request: $($_.Exception.Message)" -LogLevel "Error"
                }
            }
        }
        else
        {
            # Get all resource lists using unified helper function
            Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for indirect assignments using unified helper" -logLevel "Information"
            
            $resourceLists = Get-IntuneResourceLists -AccessToken $AccessToken -IncludeBeta:$IncludeBeta -Settings $Settings -CacheKey "IndirectResourceLists" -ResultObject $indirectAssignments
            
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
            $windowsFeatureUpdates = $resourceLists.windowsFeatureUpdates
            $windowsQualityUpdates = $resourceLists.windowsQualityUpdates
            $windowsDriverUpdates = $resourceLists.windowsDriverUpdates
            
            Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts from helper - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count)" -logLevel "Information"
        }
        
        # Process indirect assignments for each resource type using unified function
        # Determine assignment mode based on whether GroupId filter is specified
        $assignmentMode = if ($GroupId) { 'IndirectFiltered' } else { 'Indirect' }
        
        # Build parameters for unified Get-ResourceAssignments function
        $splatParams = @{
            ResultObject   = $indirectAssignments
            AccessToken    = $AccessToken
            ApiVersion     = $apiVersion
            AssignmentMode = $assignmentMode
        }
        if ($GroupId) { $splatParams['GroupIdValue'] = $GroupId }
        
        # Process all resource types with unified function
        Get-ResourceAssignments @splatParams -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -EndpointId "mobileApps"
        Get-ResourceAssignments @splatParams -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -EndpointId "deviceConfigs"
        Get-ResourceAssignments @splatParams -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -EndpointId "compliancePolicies"
        Get-ResourceAssignments @splatParams -Resources $deviceScripts -ResourceType "Device Management Scripts" -BaseUri "deviceManagement/deviceManagementScripts" -EndpointId "deviceScripts"
        Get-ResourceAssignments @splatParams -Resources $appProtectionPolicies -ResourceType "App Protection Policies" -BaseUri "deviceAppManagement/managedAppPolicies" -EndpointId "appProtectionPolicies"
        Get-ResourceAssignments @splatParams -Resources $intents -ResourceType "Device Management Intents" -BaseUri "deviceManagement/intents" -EndpointId "intents"
        Get-ResourceAssignments @splatParams -Resources $policySets -ResourceType "Policy Sets" -BaseUri "deviceAppManagement/policySets" -EndpointId "policySets"
        
        if ($IncludeBeta.IsPresent)
        {
            Get-ResourceAssignments @splatParams -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -EndpointId "autopilotProfiles"
            Get-ResourceAssignments @splatParams -Resources $healthScripts -ResourceType "Device Health Scripts" -BaseUri "deviceManagement/deviceHealthScripts" -EndpointId "healthScripts"
            Get-ResourceAssignments @splatParams -Resources $configurationPolicies -ResourceType "Configuration Policies" -BaseUri "deviceManagement/configurationPolicies" -EndpointId "configurationPolicies"
            Get-ResourceAssignments @splatParams -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations" -BaseUri "deviceManagement/groupPolicyConfigurations" -EndpointId "groupPolicyConfigs"
            Get-ResourceAssignments @splatParams -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles" -BaseUri "deviceManagement/resourceAccessProfiles" -EndpointId "resourceAccessProfiles"
            Get-ResourceAssignments @splatParams -Resources $wipPolicies -ResourceType "Windows Information Protection" -BaseUri "deviceAppManagement/windowsInformationProtectionPolicies" -EndpointId "wipPolicies"
            Get-ResourceAssignments @splatParams -Resources $mdmWipPolicies -ResourceType "MDM Windows Information Protection" -BaseUri "deviceAppManagement/mdmWindowsInformationProtectionPolicies" -EndpointId "mdmWipPolicies"
            Get-ResourceAssignments @splatParams -Resources $windowsFeatureUpdates -ResourceType "Windows Feature Update Profiles" -BaseUri "deviceManagement/windowsFeatureUpdateProfiles" -EndpointId "windowsFeatureUpdates"
            Get-ResourceAssignments @splatParams -Resources $windowsQualityUpdates -ResourceType "Windows Quality Update Profiles" -BaseUri "deviceManagement/windowsQualityUpdateProfiles" -EndpointId "windowsQualityUpdates"
            Get-ResourceAssignments @splatParams -Resources $windowsDriverUpdates -ResourceType "Windows Driver Update Profiles" -BaseUri "deviceManagement/windowsDriverUpdateProfiles" -EndpointId "windowsDriverUpdates"
        }
        
        $totalIndirectAssignments = $indirectAssignments.AllAssignments.Count
        Write-Log -logFile $LogFile -module $functionName -Message "Total indirect assignments found (All Users/All Devices): $totalIndirectAssignments" -LogLevel "Information"
        
        # Cache the indirect assignments results (only when NO GroupId filter is used)
        # When GroupId is specified, results are filtered and shouldn't be cached globally
        if (-not $GroupId)
        {
            $indirectAssignmentsCacheKey = "AllIndirectAssignments_${apiVersionKey}"
            $indirectAssignmentsData = @{
                AppAssignments                          = $indirectAssignments.AppAssignments
                ConfigurationAssignments                = $indirectAssignments.ConfigurationAssignments
                ComplianceAssignments                   = $indirectAssignments.ComplianceAssignments
                AutopilotAssignments                    = $indirectAssignments.AutopilotAssignments
                ScriptAssignments                       = $indirectAssignments.ScriptAssignments
                HealthScriptAssignments                 = $indirectAssignments.HealthScriptAssignments
                AppProtectionAssignments                = $indirectAssignments.AppProtectionAssignments
                IntentAssignments                       = $indirectAssignments.IntentAssignments
                ResourceAccessAssignments               = $indirectAssignments.ResourceAccessAssignments
                ConfigurationPolicyAssignments          = $indirectAssignments.ConfigurationPolicyAssignments
                GroupPolicyAssignments                  = $indirectAssignments.GroupPolicyAssignments
                WindowsInformationProtectionAssignments = $indirectAssignments.WindowsInformationProtectionAssignments
                PolicySetAssignments                    = $indirectAssignments.PolicySetAssignments
                WindowsFeatureUpdateAssignments         = $indirectAssignments.WindowsFeatureUpdateAssignments
                WindowsQualityUpdateAssignments         = $indirectAssignments.WindowsQualityUpdateAssignments
                WindowsDriverUpdateAssignments          = $indirectAssignments.WindowsDriverUpdateAssignments
                AllAssignments                          = $indirectAssignments.AllAssignments
                FailedResources                         = $indirectAssignments.FailedResources
            }
        
            $cached = Set-CachedData -CacheType 'Configuration' -Key $indirectAssignmentsCacheKey -Data $indirectAssignmentsData -Metadata @{ApiVersion = $apiVersionKey; FetchedAt = Get-Date; Type = 'IndirectAssignments'; Scope = 'AllUsers_AllDevices'}
            if ($cached)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached indirect assignments (All Users/All Devices, count: $totalIndirectAssignments)" -logLevel "Verbose"
            }
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Skipping cache (GroupId filter specified, results are filtered)" -logLevel "Verbose"
        }
    }
    catch
    {
        $errorMessage = "Error retrieving indirect assignments: $($_.Exception.Message)"
        $errorCode = $_.Exception.GetType().Name
        
        # Categorize error using common helper
        $errorCategory = Get-ErrorCategory -ErrorCode $errorCode -ErrorMessage $errorMessage -ResourceType "IndirectAssignments" -ODataType ""
        $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorCode -ResourceType "IndirectAssignments" -ODataType ""
        
        Write-Log -logFile $LogFile -module $functionName -Message "$errorMessage (Category: $errorCategory)" -LogLevel "Error"
        Write-Log -logFile $LogFile -module $functionName -Message "Remediation guidance: $remediationGuidance" -logLevel "Information"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
    }
    
    return $indirectAssignments
}
