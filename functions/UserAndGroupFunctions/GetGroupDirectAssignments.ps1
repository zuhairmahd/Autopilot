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
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #log the incoming parameters 
    Write-Verbose "[$functionName] Incoming parameters:"
    if ($AccessToken)
    {
        Write-Verbose "[$functionName] AccessToken provided"
        Write-Log -logFile $LogFile -module $functionName -Message "AccessToken: $AccessToken" -logLevel "Information"
    }
    Write-Verbose "[$functionName] GroupName: $GroupName"
    Write-Verbose "[$functionName] IncludeBeta: $IncludeBeta"
    Write-Verbose "[$functionName] ShowSummary: $ShowSummary"
    Write-Verbose "[$functionName] BatchSize: $BatchSize"
    #now write-log them.
    Write-Log -logFile $LogFile -module $functionName -Message "Incoming parameters:" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "GroupName: $GroupName" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "IncludeBeta: $IncludeBeta" -logLevel "Information"
Write-Log -logFile $LogFile -module $functionName -Message "ShowSummary: $ShowSummary" -LogLevel "Verbose"
    Write-Log -logFile $LogFile -module $functionName -Message "BatchSize: $BatchSize" -logLevel "Information"
    # PowerShell 5.1 compatible array handling and safe indexing
    $groupIds = $GroupName
    $groupIdArray = @($groupIds)
    $groupId = $groupIdArray[0]
    
    Write-Log -logFile $LogFile -module $functionName -Message "Group name: $($groupId.displayName)" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "Group ID: $($groupId.Id)" -logLevel "Information"
    
    # Validate that we have a group ID to work with
    if (-not $groupId.Id)
    {
Write-Log -logFile $LogFile -module $functionName -Message "No group ID available, cannot proceed with assignment retrieval" -LogLevel "Warning"
        return $assignments
    }
    
    # Store the group ID value for filtering assignments
    $groupIdValue = $groupId.Id
    
    # Initialize result object
    $assignments = [PSCustomObject]@{
        GroupName                      = $groupId.displayName 
        GroupId                        = $groupId.Id
        AppAssignments                 = @()
        ConfigurationAssignments       = @()
        ComplianceAssignments          = @()
        AutopilotAssignments           = @()
        ScriptAssignments              = @()
        HealthScriptAssignments        = @()
        AppProtectionAssignments       = @()
        IntentAssignments              = @()
        ResourceAccessAssignments      = @()
        ConfigurationPolicyAssignments = @()
        GroupPolicyAssignments         = @()
        AllAssignments                 = @()
    }
    
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
    
    # Helper function to process batch assignments
    function Invoke-BatchAssignments
    {
        [CmdletBinding()]
        param(
            [array]$Resources,
            [string]$ResourceType,
            [string]$BaseUri,
            [string]$AssignmentCategory
        )
        $functionName = $MyInvocation.MyCommand.Name
Write-Log -logFile $LogFile -module $functionName -Message "Processing ${ResourceType} resources" -LogLevel "Verbose"
        if (-not $Resources -or $Resources.Count -eq 0)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "No ${ResourceType} resources to process" -logLevel "Warning"
            return
        }
        
Write-Log -logFile $LogFile -module $functionName -Message "Processing $($Resources.Count) ${ResourceType} resources using batch API" -LogLevel "Verbose"
        
        # Process resources in batches to reduce API calls
        for ($batchIndex = 0; $batchIndex -lt $Resources.Count; $batchIndex += $BatchSize)
        {
            $batch = $Resources | Select-Object -Skip $batchIndex -First $BatchSize
            
            # Create batch request
            $batchRequestBody = @{
                requests = @()
            }
            
            foreach ($resource in $batch)
            {
                $batchRequestBody.requests += @{
                    id     = $resource.id
                    method = "GET"
                    url    = "/$BaseUri/$($resource.id)/assignments"
                }
            }
            
            Write-Verbose "[$functionName] Sending batch request for ${ResourceType} batch $($batchIndex / $BatchSize + 1) (items $batchIndex to $($batchIndex + $batch.Count - 1))"
Write-Log -logFile $LogFile -module $functionName -Message "Sending batch request for ${ResourceType} batch $($batchIndex / $BatchSize + 1)" -LogLevel "Debug"
            
            try
            {
                $batchResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath "`$batch" -APIVersion $apiVersion -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth $global:maxJSONDepth)
Write-Log -logFile $LogFile -module $functionName -Message "Received batch response for ${ResourceType} batch $($batchIndex / $BatchSize + 1)" -LogLevel "Debug"
                if ($batchResponse -and $batchResponse.responses)
                {
Write-Log -logFile $LogFile -module $functionName -Message "Processing batch response for ${ResourceType} batch $($batchIndex / $BatchSize + 1)" -LogLevel "Debug"
                    foreach ($response in $batchResponse.responses)
                    {
                        if ($response.status -eq 200 -and $response.body -and $response.body.value)
                        {
                            $resource = $batch | Where-Object { $_.id -eq $response.id } | Select-Object -First 1
                            if ($resource)
                            {
                                $relevantAssignments = $response.body.value | Where-Object { 
                                    $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                                    $_.target.groupId -eq $groupIdValue 
                                }
                                
                                foreach ($assignment in $relevantAssignments)
                                {
                                    $assignmentObject = [PSCustomObject]@{
                                        Type     = $AssignmentCategory
                                        Name     = $resource.displayName
                                        Id       = $resource.id
                                        Intent   = $assignment.intent
                                        Target   = $assignment.target
                                        Settings = $assignment.settings
                                    }
                                    
                                    switch ($AssignmentCategory)
                                    {
                                        "Application"
                                        {
                                            $assignments.AppAssignments += $assignmentObject 
                                        }
                                        "Configuration"
                                        {
                                            $assignments.ConfigurationAssignments += $assignmentObject 
                                        }
                                        "Compliance"
                                        {
                                            $assignments.ComplianceAssignments += $assignmentObject 
                                        }
                                        "AutopilotProfile"
                                        {
                                            $assignments.AutopilotAssignments += $assignmentObject 
                                        }
                                        "Script"
                                        {
                                            $assignments.ScriptAssignments += $assignmentObject 
                                        }
                                        "HealthScript"
                                        {
                                            $assignments.HealthScriptAssignments += $assignmentObject 
                                        }
                                        "AppProtection"
                                        {
                                            $assignments.AppProtectionAssignments += $assignmentObject 
                                        }
                                        "Intent"
                                        {
                                            $assignments.IntentAssignments += $assignmentObject 
                                        }
                                        "ResourceAccess"
                                        {
                                            $assignments.ResourceAccessAssignments += $assignmentObject 
                                        }
                                        "ConfigurationPolicy"
                                        {
                                            $assignments.ConfigurationPolicyAssignments += $assignmentObject 
                                        }
                                        "GroupPolicy"
                                        {
                                            $assignments.GroupPolicyAssignments += $assignmentObject 
                                        }
                                    }
                                    $assignments.AllAssignments += $assignmentObject
                                }
                            }
                        }
                        elseif ($response.status -ne 200)
                        {
                            Write-Log -logFile $LogFile -module $functionName -Message "Failed to get assignments for ${ResourceType} resource ID $($response.id). Status: $($response.status)" -logLevel "Warning"
                        }
                    }
                }
            }
            catch
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Error in batch request for ${ResourceType}: $($_.Exception.Message)" -logLevel "Warning"
            }
            
            # Add delay to prevent throttling
            if ($batchIndex + $BatchSize -lt $Resources.Count)
            {
                Start-Sleep -Milliseconds 500
            }
        }
    }
    
    try
    {
        # Get all resource lists using a single batch API call for better performance
        Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for assignments using batch API" -logLevel "Information"
        
        # Create batch request for all resource lists
        $batchRequestBody = @{
            requests = @()
        }
        
        # Define resource endpoints and their IDs
        $resourceEndpoints = @(
            @{ id = "mobileApps"; url = "deviceAppManagement/mobileApps"; extraParams = "select=id,displayName" }
            @{ id = "deviceConfigs"; url = "deviceManagement/deviceConfigurations"; extraParams = "select=id,displayName" }
            @{ id = "compliancePolicies"; url = "deviceManagement/deviceCompliancePolicies"; extraParams = "select=id,displayName" }
            @{ id = "deviceScripts"; url = "deviceManagement/deviceManagementScripts"; extraParams = "select=id,displayName" }
            @{ id = "appProtectionPolicies"; url = "deviceAppManagement/managedAppPolicies"; extraParams = "select=id,displayName" }
            @{ id = "intents"; url = "deviceManagement/intents"; extraParams = "select=id,displayName" }
            @{ id = "resourceAccessProfiles"; url = "deviceManagement/resourceAccessProfiles"; extraParams = "select=id,displayName" }
        )
        
        # Add beta endpoints if IncludeBeta is specified
        if ($IncludeBeta.IsPresent)
        {
            $resourceEndpoints += @(
                @{ id = "autopilotProfiles"; url = "deviceManagement/windowsAutopilotDeploymentProfiles"; extraParams = "select=id,displayName" }
                @{ id = "healthScripts"; url = "deviceManagement/deviceHealthScripts"; extraParams = "select=id,displayName" }
                @{ id = "configurationPolicies"; url = "deviceManagement/configurationPolicies"; extraParams = "select=id,name" }
                @{ id = "groupPolicyConfigs"; url = "deviceManagement/groupPolicyConfigurations"; extraParams = "select=id,displayName" }
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
                    }
                }
                elseif ($response.status -ne 200)
                {
                    Write-Log -logFile $LogFile -module $functionName -Message "Failed to get resource list for $($response.id). Status: $($response.status)" -logLevel "Warning"
                }
            }
        }
        
        Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts via batch - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count)" -logLevel "Information"
        
        # Process assignments using batch API for each resource type
        Invoke-BatchAssignments -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -AssignmentCategory "Application"
        Invoke-BatchAssignments -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -AssignmentCategory "Configuration"
        Invoke-BatchAssignments -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -AssignmentCategory "Compliance"
        Invoke-BatchAssignments -Resources $deviceScripts -ResourceType "Device Management Scripts" -BaseUri "deviceManagement/deviceManagementScripts" -AssignmentCategory "Script"
        Invoke-BatchAssignments -Resources $appProtectionPolicies -ResourceType "App Protection Policies" -BaseUri "deviceAppManagement/managedAppPolicies" -AssignmentCategory "AppProtection"
        Invoke-BatchAssignments -Resources $intents -ResourceType "Device Management Intents" -BaseUri "deviceManagement/intents" -AssignmentCategory "Intent"
        Invoke-BatchAssignments -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles" -BaseUri "deviceManagement/resourceAccessProfiles" -AssignmentCategory "ResourceAccess"
        
        if ($IncludeBeta.IsPresent)
        {
            Invoke-BatchAssignments -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -AssignmentCategory "AutopilotProfile"
            Invoke-BatchAssignments -Resources $healthScripts -ResourceType "Device Health Scripts" -BaseUri "deviceManagement/deviceHealthScripts" -AssignmentCategory "HealthScript"
            Invoke-BatchAssignments -Resources $configurationPolicies -ResourceType "Configuration Policies" -BaseUri "deviceManagement/configurationPolicies" -AssignmentCategory "ConfigurationPolicy"
            Invoke-BatchAssignments -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations" -BaseUri "deviceManagement/groupPolicyConfigurations" -AssignmentCategory "GroupPolicy"
        }
        
Write-Log -logFile $LogFile -module $functionName -Message "Batch processing complete. Found assignments - Apps: $($assignments.AppAssignments.Count), Configs: $($assignments.ConfigurationAssignments.Count), Compliance: $($assignments.ComplianceAssignments.Count), Autopilot: $($assignments.AutopilotAssignments.Count), Scripts: $($assignments.ScriptAssignments.Count), HealthScripts: $($assignments.HealthScriptAssignments.Count), AppProtection: $($assignments.AppProtectionAssignments.Count), Intents: $($assignments.IntentAssignments.Count), ResourceAccess: $($assignments.ResourceAccessAssignments.Count), ConfigPolicies: $($assignments.ConfigurationPolicyAssignments.Count), GroupPolicy: $($assignments.GroupPolicyAssignments.Count)" -LogLevel "Verbose"
    }
    catch
    {
Write-Log -logFile $LogFile -module $functionName -Message "Error in batch assignment processing: $($_.Exception.Message)" -LogLevel "Verbose"
    }
    
    # Summary
    $totalAssignments = $assignments.AllAssignments.Count
Write-Log -logFile $LogFile -module $functionName -Message "Total assignments found for group '$($groupId.displayName)': $totalAssignments" -LogLevel "Verbose"
    if ($ShowSummary)
    {
        Write-Host "Group Direct Assignments Summary for '$($groupId.displayName)':" -ForegroundColor Green
        Write-Host "  Apps: $($assignments.AppAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Configurations: $($assignments.ConfigurationAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Compliance Policies: $($assignments.ComplianceAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Scripts: $($assignments.ScriptAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  App Protection Policies: $($assignments.AppProtectionAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Security Intents: $($assignments.IntentAssignments.Count)" -ForegroundColor Yellow
        Write-Host "  Resource Access Profiles: $($assignments.ResourceAccessAssignments.Count)" -ForegroundColor Yellow
        if ($IncludeBeta.IsPresent)
        {
            Write-Host "  Autopilot Profiles: $($assignments.AutopilotAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Health Scripts: $($assignments.HealthScriptAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Configuration Policies: $($assignments.ConfigurationPolicyAssignments.Count)" -ForegroundColor Yellow
            Write-Host "  Group Policy Configurations: $($assignments.GroupPolicyAssignments.Count)" -ForegroundColor Yellow
        }
        Write-Host "  Total: $totalAssignments" -ForegroundColor Cyan
    }
    return $assignments
}