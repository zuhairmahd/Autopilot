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
    
    # Helper function to process assignments using CallGraphAPI's built-in batch support
    function Get-ResourceAssignments()
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$ResultObject,
            [Parameter(Mandatory = $true)]
            [string]$GroupIdValue,
            [array]$Resources,
            [string]$ResourceType,
            [string]$BaseUri,
            [string]$EndpointId
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
        try
        {
            $batchResult = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentPaths -APIVersion $apiVersion -Method "GET"
        }
        catch
        {
            $errorMessage = "Failed to fetch assignments for ${ResourceType}: $($_.Exception.Message)"
            $errorCode = $_.Exception.GetType().Name
            
            # Categorize error using common helper
            $errorCategory = Get-ErrorCategory -ErrorCode $errorCode -ErrorMessage $errorMessage -ResourceType $ResourceType -ODataType ""
            $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorCode -ResourceType $ResourceType -ODataType ""
            
            Write-Log -logFile $LogFile -module $functionName -Message "$errorMessage (Category: $errorCategory)" -LogLevel "Error"
            Write-Log -logFile $LogFile -module $functionName -Message "Remediation guidance: $remediationGuidance" -logLevel "Information"
            
            Add-FailedResourceError -ResultObject $ResultObject -ResourceType $ResourceType -ErrorMessage $errorMessage -StatusCode "N/A" -ApiVersion $apiVersion
            return
        }
        
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
                        $_.target.groupId -eq $GroupIdValue 
                    }
                    
                    foreach ($assignment in $relevantAssignments)
                    {
                        # Use Get-ResourceCategory to determine the correct category based on @odata.type
                        $category = Get-ResourceCategory -Resource $resource -EndpointId $EndpointId
                        
                        $assignmentObject = New-AssignmentObject -Type $category `
                            -Name $resource.displayName `
                            -Description $(if ($resource.description) { $resource.description } else { "" }) `
                            -Id $resource.id `
                            -Intent $assignment.intent `
                            -Target $assignment.target `
                            -Settings $assignment.settings `
                            -AssignmentScope "Direct"
                        
                        Add-AssignmentToCategory -ResultObject $ResultObject -Assignment $assignmentObject -AssignmentCategory $category
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

            # Check for resources marked as $null (previously failed) and retry them
            $resourcesToRetry = @()
            $resourceRetryMap = @{
                'mobileApps'             = @{ endpoint = "deviceAppManagement/mobileApps?`$filter=isAssigned eq true&`$select=id,displayName,description"; variable = 'mobileApps' }
                'deviceConfigs'          = @{ endpoint = "deviceManagement/deviceConfigurations?`$filter=isAssigned eq true&`$select=id,displayName,description"; variable = 'deviceConfigs' }
                'compliancePolicies'     = @{ endpoint = "deviceManagement/deviceCompliancePolicies?`$filter=isAssigned eq true&`$select=id,displayName,description"; variable = 'compliancePolicies' }
                'autopilotProfiles'      = @{ endpoint = "deviceManagement/windowsAutopilotDeploymentProfiles?`$select=id,displayName,description"; variable = 'autopilotProfiles' }
                'deviceScripts'          = @{ endpoint = "deviceManagement/deviceManagementScripts?`$select=id,displayName,description"; variable = 'deviceScripts' }
                'healthScripts'          = @{ endpoint = "deviceManagement/deviceHealthScripts?`$select=id,displayName,description"; variable = 'healthScripts' }
                'appProtectionPolicies'  = @{ endpoint = "deviceAppManagement/managedAppPolicies?`$select=id,displayName,description"; variable = 'appProtectionPolicies' }
                'intents'                = @{ endpoint = "deviceManagement/intents?`$select=id,displayName,description"; variable = 'intents' }
                'resourceAccessProfiles' = @{ endpoint = "deviceManagement/resourceAccessProfiles?`$select=id,displayName,description"; variable = 'resourceAccessProfiles' }
                'configurationPolicies'  = @{ endpoint = "deviceManagement/configurationPolicies?`$select=id,name,description"; variable = 'configurationPolicies' }
                'groupPolicyConfigs'     = @{ endpoint = "deviceManagement/groupPolicyConfigurations?`$select=id,displayName,description"; variable = 'groupPolicyConfigs' }
                'policySets'             = @{ endpoint = "deviceAppManagement/policySets?`$select=id,displayName,description"; variable = 'policySets' }
                'wipPolicies'            = @{ endpoint = "deviceAppManagement/windowsInformationProtectionPolicies?`$select=id,displayName,description"; variable = 'wipPolicies' }
                'mdmWipPolicies'         = @{ endpoint = "deviceAppManagement/mdmWindowsInformationProtectionPolicies?`$select=id,displayName,description"; variable = 'mdmWipPolicies' }
            }

            foreach ($resourceId in $resourceRetryMap.Keys)
            {
                if ($null -eq $cachedResourceLists[$resourceId])
                {
                    $resourcesToRetry += $resourceId
                }
            }

            if ($resourcesToRetry.Count -gt 0)
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Retrying $($resourcesToRetry.Count) previously failed resources" -logLevel "Info"
                Write-Verbose "[$functionName] Retrying failed resources: $($resourcesToRetry -join ', ')"

                # Build batch request for retry
                $retryBatchBody = @{
                    requests = @()
                }

                foreach ($resourceId in $resourcesToRetry)
                {
                    $retryBatchBody.requests += @{
                        id     = $resourceId
                        method = "GET"
                        url    = $resourceRetryMap[$resourceId].endpoint
                    }
                }

                # Send retry batch request
                $retryBatchResponse = CallGraphAPI -AccessToken $AccessToken -Uri 'https://graph.microsoft.com/beta/$batch' -Method "POST" -Body $retryBatchBody -LogFile $LogFile

                if ($retryBatchResponse -and $retryBatchResponse.responses)
                {
                    foreach ($response in $retryBatchResponse.responses)
                    {
                        if ($response.status -eq 200 -and $response.body.value)
                        {
                            # Retry successful - update the variable
                            $varName = $resourceRetryMap[$response.id].variable
                            Set-Variable -Name $varName -Value $response.body.value -Scope Local
                            Write-Log -logFile $LogFile -module $functionName -Message "Retry successful for '$($response.id)' - retrieved $($response.body.value.Count) items" -logLevel "Verbose"
                        }
                        else
                        {
                            # Retry failed - track error again
                            $failedResourceIds += $response.id
                            $errorMsg = if ($response.body.error.message) { $response.body.error.message } else { "Unknown error (Status: $($response.status))" }
                            Add-FailedResourceError -FailedResources $FailedResources -ResourceType $response.id -ErrorMessage $errorMsg -StatusCode $response.status -ApiVersion $apiVersionKey
                            Write-Log -logFile $LogFile -module $functionName -Message "Retry failed for '$($response.id)': $errorMsg" -logLevel "Warning"
                        }
                    }
                }
            }
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
                    @{ id = "resourceAccessProfiles"; url = "deviceManagement/resourceAccessProfiles"; extraParams = "select=id,displayName,description" }
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
            
            # Track failed resource IDs (will not be cached)
            $failedResourceIds = @()
        
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
                        
                        Write-Log -logFile $LogFile -module $functionName -Message "Failed to get resource list for $($response.id). Category: $errorCategory, Error: $errorMessage" -logLevel "Warning"
                        Write-Log -logFile $LogFile -module $functionName -Message "Remediation guidance: $remediationGuidance" -logLevel "Information"
                        
                        Add-FailedResourceError -ResultObject $assignments -ResourceType $response.id -ErrorMessage $errorMessage -StatusCode $response.status -ApiVersion $apiVersion
                        
                        # Track this resource ID so it's NOT cached and will be retried next time
                        $failedResourceIds += $response.id
                    }
                }
            }
        
            Write-Log -logFile $LogFile -module $functionName -Message "Retrieved resource counts via batch - Apps: $($mobileApps.Count), Configs: $($deviceConfigs.Count), Compliance: $($compliancePolicies.Count), Autopilot: $($autopilotProfiles.Count), Scripts: $($deviceScripts.Count), HealthScripts: $($healthScripts.Count), AppProtection: $($appProtectionPolicies.Count), Intents: $($intents.Count), ResourceAccess: $($resourceAccessProfiles.Count), ConfigPolicies: $($configurationPolicies.Count), GroupPolicy: $($groupPolicyConfigs.Count), PolicySets: $($policySets.Count), WIP: $($wipPolicies.Count), MDMWIP: $($mdmWipPolicies.Count)" -logLevel "Information"
            
            # Apply platform filtering if Settings.operatingSystem is specified
            if ($Settings -and $Settings.operatingSystem)
            {
                $targetOS = $Settings.operatingSystem
                Write-Log -logFile $LogFile -module $functionName -Message "Filtering resources for operating system: $targetOS" -logLevel "Information"
                
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
            
            # Cache only successfully fetched resources (exclude failed ones)
            # Failed resources will be retried on next run
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
            
            # Remove failed resources from cache object (set to $null so cache knows they weren't fetched)
            foreach ($failedId in $failedResourceIds)
            {
                if ($resourceListsToCache.ContainsKey($failedId))
                {
                    $resourceListsToCache[$failedId] = $null
                    Write-Log -logFile $LogFile -module $functionName -Message "Excluding failed resource '$failedId' from cache (will retry next time)" -logLevel "Verbose"
                }
            }
            
            $cached = Set-CachedData -CacheType 'Configuration' -Key $resourceListCacheKey -Data $resourceListsToCache -Metadata @{ApiVersion = $apiVersionKey; FetchedAt = Get-Date; FailedResources = $failedResourceIds}
            if ($cached)
            {
                $successCount = ($resourceListsToCache.Keys | Where-Object { $resourceListsToCache[$_] -ne $null }).Count
                Write-Log -logFile $LogFile -module $functionName -Message "Successfully cached $successCount resource lists for API version: $apiVersionKey (excluded $($failedResourceIds.Count) failed)" -logLevel "Verbose"
            }
        }
        
        # Process assignments using CallGraphAPI's built-in batch support for each resource type
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $mobileApps -ResourceType "Mobile Apps" -BaseUri "deviceAppManagement/mobileApps" -EndpointId "mobileApps"
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $deviceConfigs -ResourceType "Device Configurations" -BaseUri "deviceManagement/deviceConfigurations" -EndpointId "deviceConfigs"
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $compliancePolicies -ResourceType "Compliance Policies" -BaseUri "deviceManagement/deviceCompliancePolicies" -EndpointId "compliancePolicies"
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $deviceScripts -ResourceType "Device Management Scripts" -BaseUri "deviceManagement/deviceManagementScripts" -EndpointId "deviceScripts"
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $appProtectionPolicies -ResourceType "App Protection Policies" -BaseUri "deviceAppManagement/managedAppPolicies" -EndpointId "appProtectionPolicies"
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $intents -ResourceType "Device Management Intents" -BaseUri "deviceManagement/intents" -EndpointId "intents"
        Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $policySets -ResourceType "Policy Sets" -BaseUri "deviceAppManagement/policySets" -EndpointId "policySets"
        
        if ($IncludeBeta.IsPresent)
        {
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $autopilotProfiles -ResourceType "Autopilot Profiles" -BaseUri "deviceManagement/windowsAutopilotDeploymentProfiles" -EndpointId "autopilotProfiles"
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $healthScripts -ResourceType "Device Health Scripts" -BaseUri "deviceManagement/deviceHealthScripts" -EndpointId "healthScripts"
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $configurationPolicies -ResourceType "Configuration Policies" -BaseUri "deviceManagement/configurationPolicies" -EndpointId "configurationPolicies"
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $groupPolicyConfigs -ResourceType "Group Policy Configurations" -BaseUri "deviceManagement/groupPolicyConfigurations" -EndpointId "groupPolicyConfigs"
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $resourceAccessProfiles -ResourceType "Resource Access Profiles" -BaseUri "deviceManagement/resourceAccessProfiles" -EndpointId "resourceAccessProfiles"
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $wipPolicies -ResourceType "Windows Information Protection" -BaseUri "deviceAppManagement/windowsInformationProtectionPolicies" -EndpointId "wipPolicies"
            Get-ResourceAssignments -ResultObject $assignments -GroupIdValue $groupIdValue -Resources $mdmWipPolicies -ResourceType "MDM Windows Information Protection" -BaseUri "deviceAppManagement/mdmWindowsInformationProtectionPolicies" -EndpointId "mdmWipPolicies"
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