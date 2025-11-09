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
    
    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.
    
    .PARAMETER IncludeBeta
    Switch to include beta API endpoints for additional resource types.
    
    .PARAMETER BatchSize
    The batch size for API requests (default: 20).
    
    .EXAMPLE
    GetGroupIndirectAssignments -AccessToken $token -IncludeBeta
    
    .NOTES
    This function can be used standalone or integrated with GetGroupDirectAssignments.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBeta,
        [Parameter(Mandatory = $false)]
        [int]$BatchSize = 20,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving indirect assignments (All Users and All Devices)"
    Write-Log -logFile $LogFile -module $functionName -Message "Retrieving indirect assignments (All Users and All Devices)" -logLevel "Information"
    
    # Log Settings parameter
    Write-Verbose "[$functionName] Settings provided: $($null -ne $Settings)"
    Write-Log -logFile $LogFile -module $functionName -Message "Settings provided: $($null -ne $Settings)" -logLevel "Information"
    if ($Settings -and $Settings.operatingSystem) {
        Write-Verbose "[$functionName] Settings.operatingSystem: $($Settings.operatingSystem)"
        Write-Log -logFile $LogFile -module $functionName -Message "Settings.operatingSystem: $($Settings.operatingSystem)" -logLevel "Information"
    }
    
    # Initialize result object
    $indirectAssignments = [PSCustomObject]@{
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
    
    # Determine API version
    $apiVersion = if ($IncludeBeta.IsPresent) { 'beta' } else { 'v1.0' }
    Write-Log -logFile $LogFile -module $functionName -Message "Using API version: $apiVersion" -logLevel "Information"
    
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
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Cache miss - fetching resource lists from Graph API for indirect assignments" -logLevel "Verbose"
            Write-Verbose "[$functionName] No cached indirect resource lists found, fetching from API"
            
            # Create batch request for all resource lists
            $batchRequestBody = @{
                requests = @()
            }
            
            # Define resource endpoints
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
                            "mobileApps" { $mobileApps = $response.body.value }
                            "deviceConfigs" { $deviceConfigs = $response.body.value }
                            "compliancePolicies" { $compliancePolicies = $response.body.value }
                            "deviceScripts" { $deviceScripts = $response.body.value }
                            "appProtectionPolicies" { $appProtectionPolicies = $response.body.value }
                            "intents" { $intents = $response.body.value }
                            "resourceAccessProfiles" { $resourceAccessProfiles = $response.body.value }
                            "autopilotProfiles" { $autopilotProfiles = $response.body.value }
                            "healthScripts" { $healthScripts = $response.body.value }
                            "configurationPolicies"
                            { 
                                $configurationPolicies = $response.body.value | ForEach-Object { 
                                    $_ | Add-Member -NotePropertyName 'displayName' -NotePropertyValue $_.name -Force -PassThru
                                }
                            }
                            "groupPolicyConfigs" { $groupPolicyConfigs = $response.body.value }
                            "policySets" { $policySets = $response.body.value }
                            "wipPolicies" { $wipPolicies = $response.body.value }
                            "mdmWipPolicies" { $mdmWipPolicies = $response.body.value }
                        }
                    }
                    elseif ($response.status -ne 200)
                    {
                        Write-Log -logFile $LogFile -module $functionName -Message "Failed to get resource list for $($response.id). Status: $($response.status)" -logLevel "Warning"
                    }
                }
            }
        
            Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts via batch for indirect assignments" -logLevel "Information"
            
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
            
            $cached = Set-CachedData -CacheType 'Configuration' -Key $resourceListCacheKey -Data $resourceListsToCache -Metadata @{ApiVersion = $apiVersionKey; FetchedAt = Get-Date; Type = 'IndirectResources'}
            if ($cached)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached resource lists for indirect assignments (API: $apiVersionKey)" -logLevel "Verbose"
            }
        }
        
        # Apply platform filtering if Settings.operatingSystem is specified
        if ($Settings -and $Settings.operatingSystem)
        {
            $targetOS = $Settings.operatingSystem
            Write-Log -logFile $LogFile -module $functionName -Message "Filtering indirect assignment resources for operating system: $targetOS" -logLevel "Information"
            
            $mobileApps = @($mobileApps | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $deviceConfigs = @($deviceConfigs | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $compliancePolicies = @($compliancePolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $autopilotProfiles = @($autopilotProfiles | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $deviceScripts = @($deviceScripts | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $healthScripts = @($healthScripts | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $appProtectionPolicies = @($appProtectionPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $intents = @($intents | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $resourceAccessProfiles = @($resourceAccessProfiles | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $configurationPolicies = @($configurationPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $groupPolicyConfigs = @($groupPolicyConfigs | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $policySets = @($policySets | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $wipPolicies = @($wipPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            $mdmWipPolicies = @($mdmWipPolicies | Where-Object { Test-ResourcePlatformMatch -Resource $_ -TargetOS $targetOS })
            
            Write-Log -logFile $LogFile -module $functionName -Message "After filtering for $targetOS - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count)" -logLevel "Information"
        }
        
        # Process indirect assignments for each resource type
        Get-IndirectResourceAssignments -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -AssignmentCategory "Application"
        Get-IndirectResourceAssignments -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -AssignmentCategory "Configuration"
        Get-IndirectResourceAssignments -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -AssignmentCategory "Compliance"
        Get-IndirectResourceAssignments -Resources $deviceScripts -ResourceType "Device Management Scripts" -BaseUri "deviceManagement/deviceManagementScripts" -AssignmentCategory "Script"
        Get-IndirectResourceAssignments -Resources $appProtectionPolicies -ResourceType "App Protection Policies" -BaseUri "deviceAppManagement/managedAppPolicies" -AssignmentCategory "AppProtection"
        Get-IndirectResourceAssignments -Resources $intents -ResourceType "Device Management Intents" -BaseUri "deviceManagement/intents" -AssignmentCategory "Intent"
        Get-IndirectResourceAssignments -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles" -BaseUri "deviceManagement/resourceAccessProfiles" -AssignmentCategory "ResourceAccess"
        Get-IndirectResourceAssignments -Resources $policySets -ResourceType "Policy Sets" -BaseUri "deviceAppManagement/policySets" -AssignmentCategory "PolicySet"
        
        if ($IncludeBeta.IsPresent)
        {
            Get-IndirectResourceAssignments -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -AssignmentCategory "AutopilotProfile"
            Get-IndirectResourceAssignments -Resources $healthScripts -ResourceType "Device Health Scripts" -BaseUri "deviceManagement/deviceHealthScripts" -AssignmentCategory "HealthScript"
            Get-IndirectResourceAssignments -Resources $configurationPolicies -ResourceType "Configuration Policies" -BaseUri "deviceManagement/configurationPolicies" -AssignmentCategory "ConfigurationPolicy"
            Get-IndirectResourceAssignments -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations" -BaseUri "deviceManagement/groupPolicyConfigurations" -AssignmentCategory "GroupPolicy"
            Get-IndirectResourceAssignments -Resources $wipPolicies -ResourceType "Windows Information Protection" -BaseUri "deviceAppManagement/windowsInformationProtectionPolicies" -AssignmentCategory "WindowsInformationProtection"
            Get-IndirectResourceAssignments -Resources $mdmWipPolicies -ResourceType "MDM Windows Information Protection" -BaseUri "deviceAppManagement/mdmWindowsInformationProtectionPolicies" -AssignmentCategory "WindowsInformationProtection"
        }
        
        $totalIndirectAssignments = $indirectAssignments.AllAssignments.Count
        Write-Log -logFile $LogFile -module $functionName -Message "Total indirect assignments found (All Users/All Devices): $totalIndirectAssignments" -LogLevel "Information"
        
        # Cache the indirect assignments results
        if ($totalIndirectAssignments -gt 0)
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
                AllAssignments                          = $indirectAssignments.AllAssignments
            }
            
            $cached = Set-CachedData -CacheType 'Configuration' -Key $indirectAssignmentsCacheKey -Data $indirectAssignmentsData -Metadata @{ApiVersion = $apiVersionKey; FetchedAt = Get-Date; Type = 'IndirectAssignments'; Scope = 'AllUsers_AllDevices'}
            if ($cached)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached indirect assignments (All Users/All Devices)" -logLevel "Verbose"
            }
        }
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error retrieving indirect assignments: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
    }
    
    return $indirectAssignments
}
