function GetGroupDirectAssignments()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $AccessToken,
        [Parameter(Mandatory = $true)]
        [string] $GroupName,
        [Parameter(Mandatory = $false)]
        [switch] $IncludeBeta,
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting to get direct assignments for group: $GroupName"
    Write-Log -logFile $LogFile -module $functionName -Message "Starting to get direct assignments for group: $GroupName" -logLevel "Information"
    
    if (-not $AccessToken)
    {
        Write-Verbose "[$functionName] No AccessToken provided; relying on default authentication in CallGraphAPI."
        Write-Log -logFile $LogFile -module $functionName -Message "No AccessToken provided; relying on default authentication in CallGraphAPI." -logLevel "Warning"
    }
    
    # First, get the group ID from the group name using the existing utility function
    Write-Verbose "[$functionName] Resolving group name '$GroupName' to group ID"
    Write-Log -logFile $LogFile -module $functionName -Message "Resolving group name '$GroupName' to group ID" -logLevel "Information"
    
    try
    {
        $groupIds = GetGroupIdsByNames -AccessToken $AccessToken -GroupNames @($GroupName)
        
        if (-not $groupIds -or $groupIds.Count -eq 0)
        {
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
    catch
    {
        Write-Verbose "[$functionName] Error resolving group name: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error resolving group name: $($_.Exception.Message)" -logLevel "Error"
        return @()
    }
    
    # Initialize result object
    $assignments = [PSCustomObject]@{
        GroupName                = $GroupName
        GroupId                  = $groupId
        AppAssignments           = @()
        ConfigurationAssignments = @()
        ComplianceAssignments    = @()
        AutopilotAssignments     = @()
        AllAssignments           = @()
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
    Write-Verbose "[$functionName] Using API version: $apiVersion with batch size: $BatchSize"
    Write-Log -logFile $LogFile -module $functionName -Message "Using API version: $apiVersion with batch size: $BatchSize" -logLevel "Information"
    
    # Helper function to process batch assignments
    function Process-BatchAssignments
    {
        param(
            [array]$Resources,
            [string]$ResourceType,
            [string]$BaseUri,
            [string]$AssignmentCategory
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Processing ${ResourceType} resources"
        Write-Log -logFile $LogFile -module $functionName -Message "Processing ${ResourceType} resources" -logLevel "Information"
        if (-not $Resources -or $Resources.Count -eq 0)
        {
            Write-Verbose "[$functionName] No ${ResourceType} resources to process"
            Write-Log -logFile $LogFile -module $functionName -Message "No ${ResourceType} resources to process" -logLevel "Warning"
            return
        }
        
        Write-Verbose "[$functionName] Processing $($Resources.Count) ${ResourceType} resources using batch API"
        Write-Log -logFile $LogFile -module $functionName -Message "Processing $($Resources.Count) ${ResourceType} resources using batch API" -logLevel "Information"
        
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
            Write-Log -logFile $LogFile -module $functionName -Message "Sending batch request for ${ResourceType} batch $($batchIndex / $BatchSize + 1)" -logLevel "Information"
            
            try
            {
                $batchResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath "`$batch" -APIVersion $apiVersion -Method "POST" -Body ($batchRequestBody | ConvertTo-Json -Depth $maxJSONDepth)
                Write-Verbose "[$functionName] Received batch response for ${ResourceType} batch $($batchIndex / $BatchSize + 1)"
                Write-Log -logFile $LogFile -module $functionName -Message "Received batch response for ${ResourceType} batch $($batchIndex / $BatchSize + 1)" -logLevel "Information"
                if ($batchResponse -and $batchResponse.responses)
                {
                    Write-Verbose "[$functionName] Processing batch response for ${ResourceType} batch $($batchIndex / $BatchSize + 1)"
                    Write-Log -logFile $LogFile -module $functionName -Message "Processing batch response for ${ResourceType} batch $($batchIndex / $BatchSize + 1)" -logLevel "Information"
                    foreach ($response in $batchResponse.responses)
                    {
                        if ($response.status -eq 200 -and $response.body -and $response.body.value)
                        {
                            $resource = $batch | Where-Object { $_.id -eq $response.id } | Select-Object -First 1
                            if ($resource)
                            {
                                $relevantAssignments = $response.body.value | Where-Object { 
                                    $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' -and 
                                    $_.target.groupId -eq $groupId 
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
                                    }
                                    $assignments.AllAssignments += $assignmentObject
                                }
                            }
                        }
                        elseif ($response.status -ne 200)
                        {
                            Write-Verbose "[$functionName] Failed to get assignments for ${ResourceType} resource ID $($response.id). Status: $($response.status)"
                            Write-Log -logFile $LogFile -module $functionName -Message "Failed to get assignments for ${ResourceType} resource ID $($response.id). Status: $($response.status)" -logLevel "Warning"
                        }
                    }
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Error in batch request for ${ResourceType}: $($_.Exception.Message)"
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
        # Get all resource lists first (4 API calls total)
        Write-Verbose "[$functionName] Getting all resource lists for assignments"
        Write-Log -logFile $LogFile -module $functionName -Message "Getting all resource lists for assignments" -logLevel "Information"
        
        # Get Mobile Apps
        $appUri = "deviceAppManagement/mobileApps"
        $appExtraParameters = "select=id,displayName"
        $appResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $appUri -APIVersion $apiVersion -ExtraParameters $appExtraParameters
        $mobileApps = if ($appResponse -and $appResponse.value)
        {
            $appResponse.value 
        }
        else
        {
            @() 
        }
        
        # Get Device Configurations
        $configUri = "deviceManagement/deviceConfigurations"
        $configExtraParameters = "select=id,displayName"
        $configResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $configUri -APIVersion $apiVersion -ExtraParameters $configExtraParameters
        $deviceConfigs = if ($configResponse -and $configResponse.value)
        {
            $configResponse.value 
        }
        else
        {
            @() 
        }
        
        # Get Compliance Policies
        $complianceUri = "deviceManagement/deviceCompliancePolicies"
        $complianceExtraParameters = "select=id,displayName"
        $complianceResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $complianceUri -APIVersion $apiVersion -ExtraParameters $complianceExtraParameters
        $compliancePolicies = if ($complianceResponse -and $complianceResponse.value)
        {
            $complianceResponse.value 
        }
        else
        {
            @() 
        }
        
        # Get Autopilot Profiles (if IncludeBeta)
        $autopilotProfiles = @()
        if ($IncludeBeta.IsPresent)
        {
            $autopilotUri = "deviceManagement/windowsAutopilotDeploymentProfiles"
            $autopilotExtraParameters = "select=id,displayName"
            $autopilotResponse = CallGraphAPI -accessToken $AccessToken -ResourcePath $autopilotUri -APIVersion $apiVersion -ExtraParameters $autopilotExtraParameters
            $autopilotProfiles = if ($autopilotResponse -and $autopilotResponse.value)
            {
                $autopilotResponse.value 
            }
            else
            {
                @() 
            }
        }
        
        Write-Verbose "[$functionName] Retrieved resource counts - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count)"
        Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count)" -logLevel "Information"
        
        # Process assignments using batch API for each resource type
        Process-BatchAssignments -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -AssignmentCategory "Application"
        Process-BatchAssignments -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -AssignmentCategory "Configuration"
        Process-BatchAssignments -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -AssignmentCategory "Compliance"
        
        if ($IncludeBeta.IsPresent)
        {
            Process-BatchAssignments -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -AssignmentCategory "AutopilotProfile"
        }
        
        Write-Verbose "[$functionName] Batch processing complete. Found assignments - Apps: $($assignments.AppAssignments.Count), Configs: $($assignments.ConfigurationAssignments.Count), Compliance: $($assignments.ComplianceAssignments.Count), Autopilot: $($assignments.AutopilotAssignments.Count)"
        Write-Log -logFile $LogFile -module $functionName -Message "Batch processing complete. Found assignments - Apps: $($assignments.AppAssignments.Count), Configs: $($assignments.ConfigurationAssignments.Count), Compliance: $($assignments.ComplianceAssignments.Count), Autopilot: $($assignments.AutopilotAssignments.Count)" -logLevel "Information"
    }
    catch
    {
        Write-Verbose "[$functionName] Error in batch assignment processing: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message "Error in batch assignment processing: $($_.Exception.Message)" -logLevel "Error"
    }
    
    # Summary
    $totalAssignments = $assignments.AllAssignments.Count
    Write-Verbose "[$functionName] Total assignments found for group '$GroupName': $totalAssignments"
    Write-Log -logFile $LogFile -module $functionName -Message "Total assignments found for group '$GroupName': $totalAssignments" -logLevel "Information"
    
    Write-Host "Group Direct Assignments Summary for '$GroupName':" -ForegroundColor Green
    Write-Host "  Apps: $($assignments.AppAssignments.Count)" -ForegroundColor Yellow
    Write-Host "  Configurations: $($assignments.ConfigurationAssignments.Count)" -ForegroundColor Yellow
    Write-Host "  Compliance Policies: $($assignments.ComplianceAssignments.Count)" -ForegroundColor Yellow
    if ($IncludeBeta.IsPresent)
    {
        Write-Host "  Autopilot Profiles: $($assignments.AutopilotAssignments.Count)" -ForegroundColor Yellow
    }
    Write-Host "  Total: $totalAssignments" -ForegroundColor Cyan
    
    return $assignments
}