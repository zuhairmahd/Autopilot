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
        [int]$BatchSize = 20
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    Write-Verbose "[$functionName] Retrieving indirect assignments (All Users and All Devices)"
    Write-Log -logFile $LogFile -module $functionName -Message "Retrieving indirect assignments (All Users and All Devices)" -logLevel "Information"
    
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
    
    # Helper function to process indirect assignments
    <#
    .SYNOPSIS
    Processes a set of resources to retrieve their indirect assignments via virtual groups.
    
    .DESCRIPTION
    This nested helper function iterates over a collection of resources (such as apps, configurations, etc.)
    and retrieves assignments that are indirectly assigned through the "All Users" or "All Devices" virtual groups.
    It is called by the parent function for each resource type and assignment category.
    
    Unlike the parent function, which orchestrates the overall retrieval and aggregation of indirect assignments,
    this helper focuses on processing a specific resource type and category, making API calls and updating the result object.
    
    .PARAMETER Resources
    The array of resources to process for indirect assignments.
    
    .PARAMETER ResourceType
    The type of resource being processed (e.g., App, Configuration).
    
    .PARAMETER BaseUri
    The base URI for the Microsoft Graph API endpoint for the resource type.
    
    .PARAMETER AssignmentCategory
    The category under which assignments will be stored in the result object.
    #>
    function Get-IndirectResourceAssignments()
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
        
        Write-Log -logFile $LogFile -module $functionName -Message "Processing $($Resources.Count) ${ResourceType} resources for indirect assignments" -LogLevel "Verbose"
        
        # Build array of assignment endpoint paths
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
                    # Filter for All Users and All Devices assignments
                    $indirectAssignmentTargets = $responseData.value | Where-Object { 
                        $_.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget' -or 
                        $_.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'
                    }
                    
                    foreach ($assignment in $indirectAssignmentTargets)
                    {
                        # Determine assignment scope
                        $assignmentScope = switch ($assignment.target.'@odata.type')
                        {
                            '#microsoft.graph.allLicensedUsersAssignmentTarget' { 'All Users' }
                            '#microsoft.graph.allDevicesAssignmentTarget' { 'All Devices' }
                            default { 'Unknown' }
                        }
                        
                        $assignmentObject = [PSCustomObject]@{
                            Type            = $AssignmentCategory
                            Name            = $resource.displayName
                            Description     = if ($resource.description) { $resource.description } else { "" }
                            Id              = $resource.id
                            Intent          = $assignment.intent
                            Target          = $assignment.target
                            Settings        = $assignment.settings
                            AssignmentScope = $assignmentScope
                        }
                        
                        switch ($AssignmentCategory)
                        {
                            "Application" { $indirectAssignments.AppAssignments += $assignmentObject }
                            "Configuration" { $indirectAssignments.ConfigurationAssignments += $assignmentObject }
                            "Compliance" { $indirectAssignments.ComplianceAssignments += $assignmentObject }
                            "AutopilotProfile" { $indirectAssignments.AutopilotAssignments += $assignmentObject }
                            "Script" { $indirectAssignments.ScriptAssignments += $assignmentObject }
                            "HealthScript" { $indirectAssignments.HealthScriptAssignments += $assignmentObject }
                            "AppProtection" { $indirectAssignments.AppProtectionAssignments += $assignmentObject }
                            "Intent" { $indirectAssignments.IntentAssignments += $assignmentObject }
                            "ResourceAccess" { $indirectAssignments.ResourceAccessAssignments += $assignmentObject }
                            "ConfigurationPolicy" { $indirectAssignments.ConfigurationPolicyAssignments += $assignmentObject }
                            "GroupPolicy" { $indirectAssignments.GroupPolicyAssignments += $assignmentObject }
                            "WindowsInformationProtection" { $indirectAssignments.WindowsInformationProtectionAssignments += $assignmentObject }
                            "PolicySet" { $indirectAssignments.PolicySetAssignments += $assignmentObject }
                        }
                        $indirectAssignments.AllAssignments += $assignmentObject
                    }
                }
            }
        }
    }
    
    try
    {
        # Get all resource lists using batch API
        Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for indirect assignments using batch API" -logLevel "Information"
        
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
        "healthScripts" { $healthScripts = $response.body.value }
        # The 'configurationPolicies' resource does not include a 'displayName' property in its API response,
        # but other resources do. To ensure consistent downstream processing, we copy the 'name' property
        # to a new 'displayName' property for each configuration policy object.
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
    }
    catch
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Error retrieving indirect assignments: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
    }
    
    return $indirectAssignments
}
