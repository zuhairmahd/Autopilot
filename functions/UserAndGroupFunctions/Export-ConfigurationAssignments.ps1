function Export-ConfigurationAssignments()
{
    <#
    .SYNOPSIS
    Exports all Intune configurations and their assignments to a CSV file.
    
    .DESCRIPTION
    This function retrieves all Intune resources (apps, configurations, policies, etc.)
    and exports them to a CSV file with detailed assignment information including:
    - Resource properties (name, description, type, category)
    - Assignment classifications (Direct, Indirect, Unassigned)
    - Raw assignment targets for debugging
    - Platform-specific filtering option
    
    .PARAMETER AccessToken
    The access token for Microsoft Graph API authentication.
    
    .PARAMETER OutputPath
    The directory path where the CSV file will be saved.
    
    .PARAMETER IncludeBeta
    Switch to include beta API endpoints for additional resource types.
    
    .PARAMETER Settings
    Optional settings hashtable for platform filtering.
    
    .PARAMETER RespectOperatingSystem
    Boolean to control whether platform filtering should be applied.
    Default is $true to match current diagnostic behavior.
    
    .PARAMETER CreateErrorExportFile
    Switch to enable export of a separate error CSV file containing detailed error information.
    When present, errors will be exported to a file with the same base name plus -error suffix.
    
    .EXAMPLE
    Export-ConfigurationAssignments -AccessToken $token -OutputPath "C:\Reports" -IncludeBeta
    
    .EXAMPLE
    Export-ConfigurationAssignments -AccessToken $token -OutputPath "C:\Reports" -RespectOperatingSystem $false
    
    .EXAMPLE
    Export-ConfigurationAssignments -AccessToken $token -OutputPath "C:\Reports" -IncludeBeta -CreateErrorExportFile
    
    .OUTPUTS
    PSCustomObject with properties:
    - Success: Boolean indicating if export succeeded
    - OutputFile: Full path to the exported CSV file
    - ResourceCount: Number of resources exported
    - Message: Status or error message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeBeta,
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings,
        [Parameter(Mandatory = $false)]
        [switch]$RespectOperatingSystem,
        [switch]$CreateErrorExportFile
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = Join-Path $OutputPath "ConfigurationAssignments-$currentDateTime.csv"
    $errorFile = Join-Path $OutputPath "ConfigurationAssignments-$currentDateTime-error.csv"
    
    # Initialize error log for separate error export
    $errorLog = @()
    
    Write-Log -logFile $LogFile -module $functionName -Message "Starting configuration assignments export" -logLevel "Information"
    Write-Host "Exporting all configurations and their assignments..." -ForegroundColor Cyan
    
    # Determine API version
    $apiVersion = if ($IncludeBeta.IsPresent) { 'beta' } else { 'v1.0' }
    
    # Get all resource endpoints
    $resourceEndpoints = Get-ResourceListEndpoints -IncludeBeta:$IncludeBeta
    
    Write-Log -logFile $LogFile -module $functionName -Message "Fetching all resources from $($resourceEndpoints.Count) endpoint types" -logLevel "Information"
    Write-Host "  Fetching resources from $($resourceEndpoints.Count) endpoint types..." -ForegroundColor Gray
    
    # Fetch all resources using batch API
    $allResourcePaths = $resourceEndpoints | ForEach-Object { $_.url }
    
    try
    {
        $resourceResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $allResourcePaths -APIVersion $apiVersion -Method "GET"
    }
    catch
    {
        $errorMsg = "Error fetching resources: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message $errorMsg -logLevel "Error"
        Write-Host "  $errorMsg" -ForegroundColor Red
        
        # Log critical error
        $errorLog += [PSCustomObject]@{
            Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ErrorType      = "CRITICAL"
            Operation      = "Fetch All Resources"
            ResourceName   = "N/A"
            ResourceId     = "N/A"
            Endpoint       = "Batch: $($allResourcePaths -join ', ')"
            APIVersion     = $apiVersion
            Method         = "GET"
            StatusCode     = "EXCEPTION"
            ErrorCode      = $_.Exception.GetType().Name
            ErrorMessage   = $_.Exception.Message
            InnerException = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { "" }
            Parameters     = "ResourcePaths: $($allResourcePaths.Count) endpoints"
        }
        
        return [PSCustomObject]@{
            Success       = $false
            OutputFile    = $null
            ErrorFile     = $null
            ResourceCount = 0
            ErrorCount    = 1
            Message       = $errorMsg
        }
    }
    
    # Collect all resources
    $allResources = @()
    $resourceTypeMap = @{}
    
    # CRITICAL FIX: Graph API batch responses include an 'id' field that maps to the request 'id',
    # but response order does NOT guarantee matching request order. We must match by response.id,
    # not by array index, to ensure resources are paired with the correct endpoints.
    foreach ($result in $resourceResults.value)
    {
        # Match response to original request by ID (batch request IDs are sequential: 1, 2, 3...)
        # CallGraphAPI builds requests with $requestId starting at 1, so array index = id - 1
        $responseId = [int]$result.id
        $endpointIndex = $responseId - 1
        
        if ($endpointIndex -ge 0 -and $endpointIndex -lt $resourceEndpoints.Count)
        {
            $endpointInfo = $resourceEndpoints[$endpointIndex]
            # Access response.body.value since CallGraphAPI now preserves full response structure
            $resources = $result.body.value
            
            if ($resources -and $resources.Count -gt 0)
            {
                foreach ($resource in $resources)
                {
                    # Validate if resource supports assignments using metadata
                    $supportsAssignments = Test-ResourceSupportsAssignments -Resource $resource -AccessToken $AccessToken
                    
                    if (-not $supportsAssignments)
                    {
                        Write-Log -logFile $LogFile -module $functionName -Message "Skipping '$($resource.displayName)' (ID: $($resource.id), Type: $($resource.'@odata.type')) - does not support assignments per metadata" -logLevel "Information"
                        continue
                    }
                    
                    # Determine resource type and category using unified function
                    $resourceType = $endpointInfo.id
                    $category = Get-ResourceCategory -Resource $resource -EndpointId $resourceType
                    
                    # Validate and correct BaseUri based on @odata.type
                    $expectedBaseUri = Get-CorrectBaseUriForResource -Resource $resource
                    $actualBaseUri = $endpointInfo.url
                    
                    # If we determined a correct BaseUri and it differs from endpoint, log warning and use correct one
                    if ($expectedBaseUri -and $expectedBaseUri -ne $endpointInfo.url)
                    {
                        Write-Log -logFile $LogFile -module $functionName -Message "BaseUri mismatch for '$($resource.displayName)' (ID: $($resource.id)). ODataType: $($resource.'@odata.type'), Expected: $expectedBaseUri, Endpoint: $($endpointInfo.url)" -logLevel "Warning"
                        $actualBaseUri = $expectedBaseUri
                    }
                    
                    $allResources += [PSCustomObject]@{
                        Id            = $resource.id
                        Name          = if ($resource.displayName) { $resource.displayName } elseif ($resource.name) { $resource.name } else { "Unknown" }
                        Description   = if ($resource.description) { $resource.description } else { "" }
                        ResourceType  = $resourceType
                        Category      = $category
                        BaseUri       = $actualBaseUri  # Use corrected BaseUri
                        '@odata.type' = $resource.'@odata.type'
                        Resource      = $resource
                    }
                    
                    $resourceTypeMap[$resource.id] = $category
                }
            }
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Batch response ID $responseId (endpoint: $($endpointInfo.id)) returned no resources or failed" -logLevel "Verbose"
        }
    }    Write-Log -logFile $LogFile -module $functionName -Message "Retrieved $($allResources.Count) total resources across all types" -logLevel "Information"
    Write-Host "  Retrieved $($allResources.Count) total resources" -ForegroundColor Gray
    
    # Apply platform filtering if specified and RespectOperatingSystem is true
    if ($RespectOperatingSystem -and $Settings -and $Settings.operatingSystem)
    {
        $targetOS = $Settings.operatingSystem
        Write-Log -logFile $LogFile -module $functionName -Message "Applying platform filter for OS: $targetOS (RespectOperatingSystem=$RespectOperatingSystem)" -logLevel "Information"
        Write-Host "  Applying platform filter for OS: $targetOS" -ForegroundColor Gray
        
        $originalCount = $allResources.Count
        $allResources = @($allResources | Where-Object { Test-ResourcePlatformMatch -Resource $_.Resource -TargetOS $targetOS })
        $filteredCount = $allResources.Count
        
        Write-Log -logFile $LogFile -module $functionName -Message "Platform filter applied: reduced from $originalCount to $filteredCount resources for OS: $targetOS" -logLevel "Information"
        Write-Host "  Platform filter applied: $originalCount -> $filteredCount resources" -ForegroundColor Gray
    }
    elseif ($RespectOperatingSystem)
    {
        Write-Log -logFile $LogFile -module $functionName -Message "No platform filter specified (RespectOperatingSystem=$RespectOperatingSystem), exporting all $($allResources.Count) resources" -logLevel "Information"
        Write-Host "  No platform filter specified, exporting all resources" -ForegroundColor Gray
    }
    else
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Platform filtering disabled (RespectOperatingSystem=$RespectOperatingSystem), exporting all $($allResources.Count) resources" -logLevel "Information"
        Write-Host "  Platform filtering disabled, exporting all resources" -ForegroundColor Gray
    }
    
    # Now check each resource for assignments
    # Separate resources into standard and app protection policies (which need alternative endpoints)
    $standardResources = @()
    $appProtectionResources = @()
    
    foreach ($resource in $allResources)
    {
        $odataType = $resource.'@odata.type'
        
        # App Protection Policies need resource-type-specific endpoints
        if ($odataType -match 'androidManagedAppProtection|iosManagedAppProtection|targetedManagedAppConfiguration')
        {
            $appProtectionResources += $resource
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)' ($odataType) flagged for alternative endpoint handling" -logLevel "Verbose"
        }
        # PolicySets have known limitation, skip assignment retrieval
        elseif ($resource.ResourceType -eq 'policySets' -or $odataType -match 'policySet')
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)' is PolicySet, skipping assignment retrieval (known API limitation)" -logLevel "Verbose"
            # Will be handled in processing loop with known limitation message
        }
        else
        {
            $standardResources += $resource
        }
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Resource categorization: Standard=$($standardResources.Count), AppProtection=$($appProtectionResources.Count), PolicySets=$(($allResources | Where-Object { $_.ResourceType -eq 'policySets' }).Count)" -logLevel "Information"
    
    # Build assignment paths for standard resources only
    $assignmentPaths = $standardResources | ForEach-Object { "$($_.BaseUri)/$($_.Id)/assignments" }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Checking assignments for $($allResources.Count) resources ($($standardResources.Count) standard, $($appProtectionResources.Count) app protection)" -logLevel "Information"
    Write-Log -logFile $LogFile -module $functionName -Message "Built $($assignmentPaths.Count) standard assignment paths" -logLevel "Debug"
    Write-Host "  Checking assignments for $($allResources.Count) resources..." -ForegroundColor Gray
    
    try
    {
        Write-Log -logFile $LogFile -module $functionName -Message "Calling Graph API for batch assignment retrieval (API: $apiVersion)" -logLevel "Debug"
        $assignmentResults = CallGraphAPI -accessToken $AccessToken -ResourcePath $assignmentPaths -APIVersion $apiVersion -Method "GET"
        Write-Log -logFile $LogFile -module $functionName -Message "Graph API returned $($assignmentResults.value.Count) results for standard resources (Success: $($assignmentResults.successCount), Failed: $($assignmentResults.failureCount))" -logLevel "Information"
        
        # Now fetch app protection policy assignments using alternative endpoints
        if ($appProtectionResources.Count -gt 0)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "Fetching assignments for $($appProtectionResources.Count) app protection policies using alternative endpoints" -logLevel "Information"
            Write-Host "  Fetching app protection policy assignments using alternative endpoints..." -ForegroundColor Gray
            
            $appProtectionSuccessCount = 0
            $appProtectionFailureCount = 0
            
            foreach ($appResource in $appProtectionResources)
            {
                $appAssignments = Get-AppProtectionPolicyAssignments -ResourceId $appResource.Id -ODataType $appResource.'@odata.type' -AccessToken $AccessToken -APIVersion $apiVersion
                
                if ($appAssignments -and $appAssignments.value)
                {
                    # Add to assignment results with synthetic ID for consistent processing
                    # Use index offset: standard resources + app protection index
                    $syntheticId = $standardResources.Count + ($appProtectionResources.IndexOf($appResource) + 1)
                    
                    $syntheticResponse = [PSCustomObject]@{
                        id     = $syntheticId
                        status = 200
                        body   = $appAssignments
                    }
                    
                    # Add to results
                    $assignmentResults.value += $syntheticResponse
                    $appProtectionSuccessCount++
                    
                    Write-Log -logFile $LogFile -module $functionName -Message "Successfully retrieved assignments for app protection policy '$($appResource.Name)' (SyntheticID: $syntheticId, Assignments: $($appAssignments.value.Count))" -logLevel "Verbose"
                }
                else
                {
                    $appProtectionFailureCount++
                    Write-Log -logFile $LogFile -module $functionName -Message "Failed to retrieve assignments for app protection policy '$($appResource.Name)'" -logLevel "Warning"
                }
            }
            
            Write-Log -logFile $LogFile -module $functionName -Message "App protection policy assignment retrieval complete: Success=$appProtectionSuccessCount, Failed=$appProtectionFailureCount" -logLevel "Information"
            Write-Host "  Retrieved assignments for $appProtectionSuccessCount of $($appProtectionResources.Count) app protection policies" -ForegroundColor $(if ($appProtectionSuccessCount -eq $appProtectionResources.Count) { 'Green' } else { 'Yellow' })
        }
    }
    catch
    {
        $errorMsg = "Error fetching assignments: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message $errorMsg -logLevel "Error"
        Write-Log -logFile $LogFile -module $functionName -Message "Exception details: $($_.Exception | ConvertTo-Json -Depth $maxJSONDepth)" -logLevel "Debug"
        Write-Host "  $errorMsg" -ForegroundColor Red
        
        # Log critical error
        $errorLog += [PSCustomObject]@{
            Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ErrorType      = "CRITICAL"
            Operation      = "Fetch All Assignments"
            ResourceName   = "N/A"
            ResourceId     = "N/A"
            Endpoint       = "Batch: $($assignmentPaths.Count) assignment paths"
            APIVersion     = $apiVersion
            Method         = "GET"
            StatusCode     = "EXCEPTION"
            ErrorCode      = $_.Exception.GetType().Name
            ErrorMessage   = $_.Exception.Message
            InnerException = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { "" }
            Parameters     = "AssignmentPaths: $($assignmentPaths.Count) resources"
        }
        
        return [PSCustomObject]@{
            Success       = $false
            OutputFile    = $null
            ErrorFile     = $null
            ResourceCount = 0
            ErrorCount    = 1
            Message       = $errorMsg
        }
    }
    
    # Build export data with detailed assignment information
    $exportData = @()
    $errorCount = 0
    $successCount = 0
    
    Write-Log -logFile $LogFile -module $functionName -Message "Processing assignment results for $($allResources.Count) resources" -logLevel "Information"
    
    # Create a lookup dictionary for batch responses by ID for efficient matching using common helper
    $responseLookup = Build-BatchResponseLookup -BatchResponses $assignmentResults.value
    
    for ($i = 0; $i -lt $allResources.Count; $i++)
    {
        $resource = $allResources[$i]
        
        # Determine the request ID based on resource type
        # Standard resources: IDs 1 to standardResources.Count
        # App protection resources: IDs (standardResources.Count + 1) to (standardResources.Count + appProtectionResources.Count)
        # PolicySets: Skip lookup (known limitation)
        
        $requestId = $null
        $batchResponse = $null
        
        # Check if this is a PolicySet (known limitation - skip assignment retrieval)
        $isPolicySet = $resource.ResourceType -eq 'policySets' -or $resource.'@odata.type' -match 'policySet'
        
        if ($isPolicySet)
        {
            # PolicySet - known API limitation, no response to look up
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)' is PolicySet (known API limitation), skipping response lookup" -logLevel "Verbose"
            $requestId = "N/A-PolicySet"
        }
        else
        {
            # Find resource index in either standard or app protection list
            $standardIndex = $standardResources.IndexOf($resource)
            $appProtectionIndex = $appProtectionResources.IndexOf($resource)
            
            if ($standardIndex -ge 0)
            {
                # Standard resource - ID is 1-based index in standard list
                $requestId = ($standardIndex + 1).ToString()
            }
            elseif ($appProtectionIndex -ge 0)
            {
                # App protection resource - ID is offset by standard resource count
                $requestId = ($standardResources.Count + $appProtectionIndex + 1).ToString()
            }
            else
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)' not found in standard or app protection lists" -logLevel "Warning"
                $requestId = "N/A-Unknown"
            }
            
            # Look up batch response
            $batchResponse = $responseLookup[$requestId]
        }
        
        # Check if batch request failed (non-2xx status code)
        $batchRequestFailed = $batchResponse -and $batchResponse.status -and ($batchResponse.status -lt 200 -or $batchResponse.status -ge 300)
        
        # Access response.body since CallGraphAPI preserves full batch response structure
        $assignmentData = if ($batchResponse -and $batchResponse.body -and -not $batchRequestFailed) { $batchResponse.body } else { $null }
        
        Write-Log -logFile $LogFile -module $functionName -Message "Processing resource [$($i+1)/$($allResources.Count)]: '$($resource.Name)' (ID: $($resource.Id))" -logLevel "Debug"
        
        if ($batchResponse)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "BatchResponse ID: $($batchResponse.id), Status: $($batchResponse.status), Has body: $($null -ne $batchResponse.body), Failed: $batchRequestFailed" -logLevel "Verbose"
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "No batch response found for request ID $requestId (resource: $($resource.Name))" -logLevel "Warning"
        }
        
        if ($assignmentData)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "AssignmentData has value property: $($null -ne $assignmentData.PSObject.Properties['value'])" -logLevel "Verbose"
        }
        
        # Determine if this is an error response or successful response
        $isError = $false
        $errorStatusCode = $null
        $errorMessage = $null
        $errorCategory = $null
        $remediationGuidance = $null
        
        # Check for error response patterns from CallGraphAPI batch processing
        if ($null -eq $assignmentData)
        {
            # Special handling for PolicySets (known API limitation)
            if ($isPolicySet)
            {
                $isError = $true
                $errorStatusCode = "API_DESIGN_LIMITATION"
                $errorMessage = "PolicySets use non-standard OData routing for assignments"
                $errorCategory = "API_DESIGN_LIMITATION"
                $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorStatusCode `
                    -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
                
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': PolicySet with known API limitation" -logLevel "Information"
            }
            else
            {
                $isError = $true
                
                # Check if we have batch response with error details
                if ($batchRequestFailed -and $batchResponse.body -and $batchResponse.body.error)
                {
                    $errorStatusCode = if ($batchResponse.body.error.code) { $batchResponse.body.error.code } else { $batchResponse.status.ToString() }
                    $errorMessage = if ($batchResponse.body.error.message) { $batchResponse.body.error.message } else { "HTTP $($batchResponse.status)" }
                    
                    # Categorize error
                    $errorCategory = Get-ErrorCategory -ErrorCode $errorStatusCode -ErrorMessage $errorMessage `
                        -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
                    $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorStatusCode `
                        -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
                    
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Batch request failed - Status=$($batchResponse.status), Code=$errorStatusCode, Message=$errorMessage, Category=$errorCategory" -logLevel "Warning"
                }
                elseif ($batchRequestFailed)
                {
                    $errorStatusCode = $batchResponse.status.ToString()
                    $errorMessage = "HTTP $($batchResponse.status) - Batch request failed"
                    
                    # Categorize error
                    $errorCategory = Get-ErrorCategory -ErrorCode $errorStatusCode -ErrorMessage $errorMessage `
                        -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
                    $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorStatusCode `
                        -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
                    
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Batch request failed - Status=$errorStatusCode, Category=$errorCategory" -logLevel "Warning"
                }
                else
                {
                    $errorStatusCode = "NULL"
                    $errorMessage = "No response returned from API"
                    $errorCategory = "NO_RESPONSE"
                    $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorStatusCode `
                        -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
                    
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': NULL response, Category=$errorCategory" -logLevel "Warning"
                }
            }
        }
        elseif ($assignmentData.PSObject.Properties['error'])
        {
            # Graph API error object present
            $isError = $true
            $errorStatusCode = if ($assignmentData.error.code) { $assignmentData.error.code } else { "UNKNOWN" }
            $errorMessage = if ($assignmentData.error.message) { $assignmentData.error.message } else { "Unknown error" }
            
            # Categorize error
            $errorCategory = Get-ErrorCategory -ErrorCode $errorStatusCode -ErrorMessage $errorMessage `
                -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
            $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorStatusCode `
                -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
            
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Error - Status=$errorStatusCode, Message=$errorMessage, Category=$errorCategory" -logLevel "Warning"
        }
        elseif (-not $assignmentData.PSObject.Properties['value'])
        {
            # Response doesn't have 'value' property - unexpected structure
            $isError = $true
            $errorStatusCode = "MALFORMED"
            $errorMessage = "Response missing 'value' property"
            $errorCategory = "MALFORMED_RESPONSE"
            $remediationGuidance = Get-RemediationGuidance -ErrorCategory $errorCategory -ErrorCode $errorStatusCode `
                -ResourceType $resource.ResourceType -ODataType $resource.'@odata.type'
            
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Malformed response (missing 'value' property), Category=$errorCategory" -logLevel "Warning"
            Write-Log -logFile $LogFile -module $functionName -Message "Response object: $($assignmentData | ConvertTo-Json -Depth 2 -Compress)" -logLevel "Debug"
        }
        
        if ($isError)
        {
            # Failed to get assignments - include error details
            $errorCount++
            
            # Add to error log with comprehensive details including categorization
            $assignmentEndpoint = "$($resource.BaseUri)/$($resource.Id)/assignments"
            $errorLog += [PSCustomObject]@{
                Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ErrorType           = "ASSIGNMENT_CHECK_FAILED"
                ErrorCategory       = $errorCategory
                KnownLimitation     = ($errorCategory -in @('API_DESIGN_LIMITATION', 'UNSUPPORTED_ENDPOINT'))
                Operation           = "Get Resource Assignments"
                ResourceName        = $resource.Name
                ResourceId          = $resource.Id
                Endpoint            = $assignmentEndpoint
                APIVersion          = $apiVersion
                Method              = "GET"
                StatusCode          = $errorStatusCode
                ErrorCode           = $errorStatusCode
                ErrorMessage        = $errorMessage
                RemediationGuidance = $remediationGuidance
                InnerException      = ""
                Parameters          = "Category: $($resource.Category), ResourceType: $($resource.ResourceType), ODataType: $($resource.'@odata.type')"
                ResponseDetails     = if ($batchResponse) { $batchResponse | ConvertTo-Json -Depth 3 -Compress } else { "NULL" }
            }
            
            $exportData += [PSCustomObject]@{
                ResourceName        = $resource.Name
                Description         = $resource.Description
                Category            = $resource.Category
                ResourceType        = $resource.ResourceType
                ODataType           = $resource.'@odata.type'
                ResourceId          = $resource.Id
                AssignmentCount     = -1
                Classification      = "ERROR: Failed to Check"
                HasDirectAssignment = $false
                HasAllUsers         = $false
                HasAllDevices       = $false
                DirectGroupCount    = 0
                RawTargets          = "ERROR [$errorCategory - $errorStatusCode]: $errorMessage"
                ErrorStatusCode     = $errorStatusCode
                ErrorMessage        = $errorMessage
                ErrorCategory       = $errorCategory
                KnownLimitation     = ($errorCategory -in @('API_DESIGN_LIMITATION', 'UNSUPPORTED_ENDPOINT'))
            }
            continue
        }
        
        # Successful response - process assignments
        $assignments = $assignmentData.value
        $assignmentCount = if ($assignments) { $assignments.Count } else { 0 }
        $successCount++
        
        Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': $assignmentCount assignment(s) found" -logLevel "Debug"
        
        if ($assignmentCount -eq 0)
        {
            # No assignments at all
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': No assignments (truly unassigned)" -logLevel "Verbose"
            $exportData += [PSCustomObject]@{
                ResourceName        = $resource.Name
                Description         = $resource.Description
                Category            = $resource.Category
                ResourceType        = $resource.ResourceType
                ODataType           = $resource.'@odata.type'
                ResourceId          = $resource.Id
                AssignmentCount     = 0
                Classification      = "Unassigned"
                HasDirectAssignment = $false
                HasAllUsers         = $false
                HasAllDevices       = $false
                DirectGroupCount    = 0
                RawTargets          = ""
                ErrorStatusCode     = ""
                ErrorMessage        = ""
            }
        }
        else
        {
            # Analyze assignments
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Analyzing $assignmentCount assignment(s)" -logLevel "Debug"
            $hasRealAssignment = Test-HasRealAssignment -Assignments $assignments -ResourceName $resource.Name -ResourceCategory $resource.Category
            $hasAllUsers = $false
            $hasAllDevices = $false
            $directGroupIds = @()
            $rawTargets = @()
            
            for ($j = 0; $j -lt $assignments.Count; $j++)
            {
                $assignment = $assignments[$j]
                $targetType = $assignment.target.'@odata.type'
                $intent = $assignment.intent
                
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Assignment #$($j+1) - TargetType=$targetType, Intent=$intent" -logLevel "Debug"
                
                # Build raw target string for visibility - include ALL properties
                $targetInfo = "TargetType=$targetType"
                
                if ($targetType -eq '#microsoft.graph.groupAssignmentTarget')
                {
                    $groupId = $assignment.target.groupId
                    $targetInfo += ";GroupId=$groupId"
                    $directGroupIds += $groupId
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Assignment #$($j+1) is group assignment (GroupId: $groupId)" -logLevel "Debug"
                }
                elseif ($targetType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')
                {
                    $hasAllUsers = $true
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Assignment #$($j+1) is All Users" -logLevel "Debug"
                }
                elseif ($targetType -eq '#microsoft.graph.allDevicesAssignmentTarget')
                {
                    $hasAllDevices = $true
                    Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Assignment #$($j+1) is All Devices" -logLevel "Debug"
                }
                
                # Add intent if present
                if ($intent)
                {
                    $targetInfo += ";Intent=$intent"
                }
                
                # Add assignment ID for traceability
                if ($assignment.id)
                {
                    $targetInfo += ";AssignmentId=$($assignment.id)"
                }
                
                $rawTargets += $targetInfo
            }
            
            # Determine classification
            $classification = "Unknown"
            $hasDirectAssignment = $directGroupIds.Count -gt 0
            
            if (-not $hasRealAssignment)
            {
                # Has assignments but none are "real" (no group, All Users, or All Devices)
                $classification = "Unassigned (Has Other Assignments)"
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Classification=Unassigned (has $assignmentCount non-real assignments)" -logLevel "Verbose"
            }
            elseif ($hasDirectAssignment -and ($hasAllUsers -or $hasAllDevices))
            {
                # Has both direct group assignments AND All Users/All Devices
                $classification = "Direct + Indirect"
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Classification=Direct+Indirect (Groups: $($directGroupIds.Count), AllUsers: $hasAllUsers, AllDevices: $hasAllDevices)" -logLevel "Verbose"
            }
            elseif ($hasDirectAssignment)
            {
                # Has only direct group assignments
                $classification = "Direct"
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Classification=Direct (Groups: $($directGroupIds.Count))" -logLevel "Verbose"
            }
            elseif ($hasAllUsers -or $hasAllDevices)
            {
                # Has only All Users or All Devices
                $classification = "Indirect"
                Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': Classification=Indirect (AllUsers: $hasAllUsers, AllDevices: $hasAllDevices)" -logLevel "Verbose"
            }
            
            $rawTargetString = ($rawTargets -join " | ")
            Write-Log -logFile $LogFile -module $functionName -Message "Resource '$($resource.Name)': RawTargets=$rawTargetString" -logLevel "Debug"
            
            $exportData += [PSCustomObject]@{
                ResourceName        = $resource.Name
                Description         = $resource.Description
                Category            = $resource.Category
                ResourceType        = $resource.ResourceType
                ODataType           = $resource.'@odata.type'
                ResourceId          = $resource.Id
                AssignmentCount     = $assignmentCount
                Classification      = $classification
                HasDirectAssignment = $hasDirectAssignment
                HasAllUsers         = $hasAllUsers
                HasAllDevices       = $hasAllDevices
                DirectGroupCount    = $directGroupIds.Count
                RawTargets          = $rawTargetString
                ErrorStatusCode     = ""
                ErrorMessage        = ""
            }
        }
    }
    
    Write-Log -logFile $LogFile -module $functionName -Message "Assignment processing complete: $successCount successful, $errorCount errors" -logLevel "Information"
    
    # Export to CSV
    Write-Log -logFile $LogFile -module $functionName -Message "Exporting $($exportData.Count) resources to CSV: $outputFile" -logLevel "Information"
    Write-Host "  Exporting $($exportData.Count) resources to CSV..." -ForegroundColor Gray
    
    try
    {
        $exportData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        
        Write-Log -logFile $LogFile -module $functionName -Message "Successfully exported $($exportData.Count) resources to $outputFile" -logLevel "Information"
        Write-Host "Successfully exported to: $outputFile" -ForegroundColor Green
        Write-Host "  Total resources: $($exportData.Count)" -ForegroundColor Green
        
        # Export error log if there were any errors AND CreateErrorExportFile switch is present
        if ($CreateErrorExportFile.IsPresent -and $errorLog.Count -gt 0)
        {
            try
            {
                $errorLog | Export-Csv -Path $errorFile -NoTypeInformation -Encoding UTF8
                Write-Log -logFile $LogFile -module $functionName -Message "Exported $($errorLog.Count) errors to $errorFile" -logLevel "Information"
                Write-Host "  Error log exported to: $errorFile" -ForegroundColor Yellow
                Write-Host "  Total errors: $($errorLog.Count)" -ForegroundColor Yellow
            }
            catch
            {
                Write-Log -logFile $LogFile -module $functionName -Message "Failed to export error log: $($_.Exception.Message)" -logLevel "Warning"
                Write-Host "  Warning: Failed to export error log: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        elseif ($errorLog.Count -gt 0)
        {
            Write-Log -logFile $LogFile -module $functionName -Message "$($errorLog.Count) errors encountered but CreateErrorExportFile switch not set - error file not created" -logLevel "Information"
            Write-Host "  Note: $($errorLog.Count) errors encountered (use -CreateErrorExportFile to export error details)" -ForegroundColor Gray
        }
        else
        {
            Write-Log -logFile $LogFile -module $functionName -Message "No errors encountered - error file not created" -logLevel "Information"
        }
        
        # Show summary statistics
        $stats = $exportData | Group-Object Classification | Select-Object Name, Count | Sort-Object Count -Descending
        Write-Host "`nAssignment Summary:" -ForegroundColor Cyan
        foreach ($stat in $stats)
        {
            Write-Host "  $($stat.Name): $($stat.Count)" -ForegroundColor Gray
        }
        
        # Show error categorization if errors occurred
        if ($errorLog.Count -gt 0)
        {
            Write-Host "`nError Category Breakdown:" -ForegroundColor Yellow
            $errorStats = $errorLog | Group-Object ErrorCategory | Select-Object Name, Count | Sort-Object Count -Descending
            foreach ($errStat in $errorStats)
            {
                $isKnownLimitation = $errStat.Name -in @('API_DESIGN_LIMITATION', 'UNSUPPORTED_ENDPOINT')
                $prefix = if ($isKnownLimitation) { "  [Known Limitation]" } else { "  [Error]" }
                Write-Host "$prefix $($errStat.Name): $($errStat.Count)" -ForegroundColor $(if ($isKnownLimitation) { 'Cyan' } else { 'Yellow' })
            }
            
            # Count known limitations vs real errors
            $knownLimitationCount = ($errorLog | Where-Object { $_.KnownLimitation -eq $true }).Count
            $realErrorCount = $errorLog.Count - $knownLimitationCount
            
            if ($knownLimitationCount -gt 0)
            {
                Write-Host "`n  Known API Limitations: $knownLimitationCount" -ForegroundColor Cyan
                Write-Host "  Real Errors: $realErrorCount" -ForegroundColor $(if ($realErrorCount -gt 0) { 'Yellow' } else { 'Green' })
                Write-Host "`n  Note: Known limitations are documented API design patterns requiring alternative approaches." -ForegroundColor Gray
            }
        }
        
        return [PSCustomObject]@{
            Success       = $true
            OutputFile    = $outputFile
            ErrorFile     = if ($CreateErrorExportFile.IsPresent -and $errorLog.Count -gt 0) { $errorFile } else { $null }
            ResourceCount = $exportData.Count
            ErrorCount    = $errorLog.Count
            Message       = "Successfully exported $($exportData.Count) resources" + $(if ($errorLog.Count -gt 0) { " with $($errorLog.Count) errors" } else { "" })
        }
    }
    catch
    {
        $errorMsg = "Error exporting to CSV: $($_.Exception.Message)"
        Write-Log -logFile $LogFile -module $functionName -Message $errorMsg -logLevel "Error"
        Write-Host "  $errorMsg" -ForegroundColor Red
        
        return [PSCustomObject]@{
            Success       = $false
            OutputFile    = $null
            ErrorFile     = $null
            ResourceCount = 0
            ErrorCount    = 0
            Message       = $errorMsg
        }
    }
}
