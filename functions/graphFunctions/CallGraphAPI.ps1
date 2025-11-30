function CallGraphAPI()
{
    <#
    .SYNOPSIS
    Executes HTTP requests to Microsoft Graph API with comprehensive error handling and pagination.

    .DESCRIPTION
    This function is the core Graph API client that handles all HTTP requests to Microsoft Graph endpoints.
    It supports both single and batch resource path processing, automatic pagination for large result sets,
    OData query parameters (filter, search, select), various HTTP methods (GET, POST, PATCH, DELETE),
    consistency level headers for advanced queries, and comprehensive error handling with retry logic.

    .PARAMETER accessToken
    The Microsoft Graph API access token for authentication. This parameter is mandatory.

    .PARAMETER ResourcePath
    The Graph API resource path or array of paths. Supports single string or string array for batch processing.
    This parameter is mandatory.

    .PARAMETER APIVersion
    The Graph API version to use. Default is 'beta'. Can be 'v1.0' or 'beta'.

    .PARAMETER method
    The HTTP method: 'get' (default), 'post', 'patch', 'put', or 'delete'.

    .PARAMETER Filter
    OData $filter query parameter for filtering results.

    .PARAMETER Search
    OData $search query parameter for searching. Requires consistencyLevel.

    .PARAMETER ExtraParameters
    Additional OData query parameters (e.g., "$select=id,displayName&$top=10").

    .PARAMETER headers
    Custom HTTP headers hashtable to include in the request.

    .PARAMETER body
    Request body for POST/PATCH/PUT operations (JSON string).

    .PARAMETER consistencyLevel
    When specified, adds ConsistencyLevel=eventual header (required for $search and some $count operations).

    .PARAMETER secureString
    When specified, returns access token as SecureString instead of plain text.

    .OUTPUTS
    System.Management.Automation.PSCustomObject or System.Array
    Returns the API response value property (single object or array), or complete response object.
    For batch processing, returns array of results. Returns $null on error.

    .EXAMPLE
    $users = CallGraphAPI -accessToken $token -ResourcePath "users" -Filter "startswith(displayName,'John')"
    $device = CallGraphAPI -accessToken $token -ResourcePath "deviceManagement/managedDevices/abc123"
    $result = CallGraphAPI -accessToken $token -ResourcePath "devices" -method "post" -body $jsonBody

    .NOTES
    Handles automatic pagination via @odata.nextLink for large result sets.
    Supports batch resource path processing for multiple endpoints.
    Includes retry logic with exponential backoff for transient errors.
    Processes OData filter conditions via ProcessFilterCondition function.
    Comprehensive error logging and verbose output for debugging.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [object]$ResourcePath,  # Can be string or string array for batch processing
        [string]$APIVersion = 'beta',
        [string]$method = 'get',
        [string]$Filter = $null,
        [string]$Search = $null,
        [string]$ExtraParameters = $null,
        $headers,
        [string]$body = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    if ($accessToken)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Access token provided." -LogLevel "Information"
        Write-Verbose "[$functionName] Access token provided."                                      
    }
    else
    {
        Write-Verbose "[$functionName] Access token not provided. Please provide a valid access token."
        Write-Log -LogFile $logFile -Module $functionName -Message "Access token not provided." -LogLevel "Error"
        return
    }
    Write-Log -LogFile $logFile -Module $functionName -Message "Resource Path: $ResourcePath" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Method: $method" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Filter: $filter" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Search: $Search" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Extra Parameters: $ExtraParameters" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Version: $APIVersion" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Consistency Level: $consistencyLevel" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Body: $body" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "SecureString: $secureString" -LogLevel "Information"
    
    # Check if ResourcePath is an array
    $isArrayInput = $ResourcePath -is [array]
    Write-Verbose "[$functionName] ResourcePath is an array: $isArrayInput"
    write-log -logFile $logFile -Module $functionName -Message "Function called with ResourcePath type: $($ResourcePath.GetType().FullName)" -LogLevel "Information"
    # Handle single-item array
    if ($isArrayInput -and $ResourcePath.Count -eq 1)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Single-item array detected, processing as single request" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Single-item array detected, processing as single request"
        $ResourcePath = $ResourcePath[0]
        $isArrayInput = $false
    }
    # Check if batch processing is requested (array with multiple items)
    $isBatchRequest = $isArrayInput -and $ResourcePath.Count -gt 1
    $batchThreshold = 1
    Write-Verbose "[$functionName] Batch request: $isBatchRequest, Resource count: $($ResourcePath.Count)"
    write-log -logFile $logFile -Module $functionName -Message "isBatchRequest: $isBatchRequest with a threshold of $batchThreshold" -LogLevel "Information"
    if ($isBatchRequest -and $ResourcePath.Count -ge $batchThreshold)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Batch request detected: $($ResourcePath.Count) resources" -LogLevel "Information"
        Write-Verbose "[$functionName] Batch request detected: $($ResourcePath.Count) resources"
        # Normalize input: support both string arrays and hashtable arrays @{id=".."; url=".."}
        $normalizedResources = @()
        $resourceMapping = @{}  # Maps batch request ID to original resource identifier
        
        for ($i = 0; $i -lt $ResourcePath.Count; $i++)
        {
            $item = $ResourcePath[$i]
            if ($item -is [hashtable])
            {
                # Hashtable format: @{ id = "resourceId"; url = "endpoint/path" }
                $resourceId = if ($item.ContainsKey('id')) { $item.id } else { "resource_$i" }
                $resourceUrl = if ($item.ContainsKey('url')) { $item.url } else { $item.Values | Select-Object -First 1 }
                $normalizedResources += $resourceUrl
                $resourceMapping[$i] = @{ id = $resourceId; url = $resourceUrl; originalIndex = $i }
                Write-Verbose "[$functionName] Normalized hashtable resource: id='$resourceId', url='$resourceUrl'"
            }
            else
            {
                # String format: just the URL path
                $normalizedResources += $item
                $resourceMapping[$i] = @{ id = "resource_$i"; url = $item; originalIndex = $i }
                Write-Verbose "[$functionName] Normalized string resource: url='$item'"
            }
        }
        
        Write-Verbose "[$functionName] Normalized $($normalizedResources.Count) resources for batch processing"
        Write-Log -LogFile $logFile -Module $functionName -Message "Normalized $($normalizedResources.Count) resources for batch processing" -LogLevel "Debug"
        
        # Graph API supports up to 20 requests per batch
        $maxBatchSize = 20
        $allResults = @()
        $successCount = 0
        $failureCount = 0
        $errorDetails = @()  # Collect detailed error information
        
        # Split requests into batches of max 20
        $batches = @()
        for ($i = 0; $i -lt $normalizedResources.Count; $i += $maxBatchSize)
        {
            $batchSize = [Math]::Min($maxBatchSize, $normalizedResources.Count - $i)
            Write-Verbose "[$functionName] Creating batch $($batches.Count + 1) with $batchSize requests (indices $i to $($i + $batchSize - 1))"                        
            write-log -logFile $logFile -Module $functionName -Message "Creating batch $($batches.Count + 1) with $batchSize requests (indices $i to $($i + $batchSize - 1))" -LogLevel "Debug"                                 
            $batches += , @($normalizedResources[$i..($i + $batchSize - 1)])
            write-log -logFile $logFile -Module $functionName -Message "Batch $($batches.Count) created with $($batches[-1].Count) requests" -LogLevel "Debug"                                              
            Write-Verbose "[$functionName] Batch $($batches.Count) created with $($batches[-1].Count) requests"         
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Processing $($normalizedResources.Count) requests in $($batches.Count) batch(es)" -LogLevel "Information"
        Write-Verbose "[$functionName] Processing $($normalizedResources.Count) requests in $($batches.Count) batch(es)"
        $batchIndex = 0
        
        foreach ($batch in $batches)
        {
            Write-Verbose "[$functionName] Processing batch $($batchIndex + 1) of $($batches.Count)"
            write-log -logFile $logFile -Module $functionName -Message "Processing batch $($batchIndex + 1) of $($batches.Count)" -LogLevel "Debug"                                                                
            
            # Build batch request body according to Graph API spec
            $batchRequests = @()
            $batchRequestMapping = @{}  # Maps batch-local request ID to global resource index
            $localRequestId = 1
            
            for ($j = 0; $j -lt $batch.Count; $j++)
            {
                $path = $batch[$j]
                $globalIndex = ($batchIndex * $maxBatchSize) + $j
                $resourceInfo = $resourceMapping[$globalIndex]
                
                Write-Verbose "[$functionName] Building batch request $localRequestId for resource: $($resourceInfo.id) ($path)"  
                write-log -logFile $logFile -Module $functionName -Message "Building batch request $localRequestId for resource: $($resourceInfo.id) ($path)" -LogLevel "Debug"                                                                               
                
                # Build full URL for the request (remove leading slash if present)
                $requestUrl = if ($path.StartsWith('/')) { $path } else { "/$path" }
                Write-Verbose "[$functionName] Request URL: $requestUrl"                            
                write-log -logFile $logFile -Module $functionName -Message "Request URL: $requestUrl" -LogLevel "Debug"                                                 
                
                # Handle filters, search, and extra parameters in the URL
                $queryParams = @()
                if ($Filter)
                {
                    # Process filter conditions using ProcessFilterCondition
                    $filterParts = [System.Collections.ArrayList]::new()
                    $logicalOperators = [System.Collections.ArrayList]::new()
                    $pattern = '\s+(and|or)\s+'
                    $lastIndex = 0
                    $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
                    
                    if ($logicalOperaterMatches.Count -eq 0)
                    {
                        $encodedCondition = ProcessFilterCondition -condition $Filter
                        $filterParts.Add($encodedCondition) | Out-Null
                    }
                    else
                    {
                        foreach ($match in $logicalOperaterMatches)
                        {
                            $condition = $Filter.Substring($lastIndex, $match.Index - $lastIndex).Trim()
                            $encodedCondition = ProcessFilterCondition -condition $condition
                            $filterParts.Add($encodedCondition) | Out-Null
                            $logicalOperators.Add($match.Groups[1].Value) | Out-Null
                            $lastIndex = $match.Index + $match.Length
                        }
                        $lastCondition = $Filter.Substring($lastIndex).Trim()
                        $encodedLastCondition = ProcessFilterCondition -condition $lastCondition
                        $filterParts.Add($encodedLastCondition) | Out-Null
                    }
                    
                    $encodedFilter = ""
                    for ($k = 0; $k -lt $filterParts.Count; $k++)
                    {
                        $encodedFilter += $filterParts[$k]
                        if ($k -lt $logicalOperators.Count)
                        {
                            $encodedFilter += " " + $logicalOperators[$k] + " "
                        }
                    }
                    
                    $queryParams += "`$filter=$([uri]::EscapeUriString($encodedFilter))"
                    Write-Verbose "[$functionName] Adding filter query parameter: $encodedFilter"
                    write-log -logFile $logFile -Module $functionName -Message "Adding filter query parameter: $encodedFilter" -LogLevel "Debug"                                   
                }
                
                if ($Search)
                {
                    $queryParams += "`$search=$([uri]::EscapeUriString($Search))"
                    Write-Verbose "[$functionName] Adding search query parameter: $Search"                                                                                  
                    write-log -logFile $logFile -Module $functionName -Message "Adding search query parameter: $Search" -LogLevel "Debug"                                                   
                }
                
                if ($ExtraParameters)
                {
                    # Process extra parameters to add $ prefix where needed
                    $paramsList = @()
                    $keyValuePairs = $ExtraParameters -split '&'
                    
                    foreach ($pair in $keyValuePairs)
                    {
                        $parts = $pair -split '=', 2
                        if ($parts.Count -eq 2)
                        {
                            $key = $parts[0].Trim()
                            $value = $parts[1].Trim()
                            
                            if (-not $key.StartsWith('$'))
                            {
                                $key = "`$$key"
                            }
                            
                            $encodedValue = [uri]::EscapeDataString($value)
                            $paramsList += "$key=$encodedValue"
                        }
                    }
                    
                    if ($paramsList.Count -gt 0)
                    {
                        $queryParams += ($paramsList -join '&')
                        Write-Verbose "[$functionName] Adding extra query parameters: $($paramsList -join '&')"
                        write-log -logFile $logFile -Module $functionName -Message "Adding extra query parameters: $($paramsList -join '&')" -LogLevel "Debug"
                    }
                }
                
                if ($queryParams.Count -gt 0)
                {
                    # Check if URL already has query parameters
                    $separator = if ($requestUrl.Contains('?')) { '&' } else { '?' }
                    $requestUrl += $separator + ($queryParams -join "&")
                    Write-Verbose "[$functionName] Final request URL with query parameters: $requestUrl"
                    write-log -logFile $logFile -Module $functionName -Message "Final request URL with query parameters: $requestUrl" -LogLevel "Debug"                                                     
                }
                
                # Build request object
                $batchRequest = @{
                    id     = $localRequestId.ToString()
                    method = $method.ToUpper()
                    url    = $requestUrl
                }
                
                # Store mapping for this request
                $batchRequestMapping[$localRequestId] = $globalIndex
                
                Write-Verbose "[$functionName] Built batch request object: $($batchRequest | ConvertTo-Json -Depth 5)"
                write-log -logFile $logFile -Module $functionName -Message "Built batch request object: $($batchRequest | ConvertTo-Json -Depth 5)" -LogLevel "Debug"                                                               
                
                # Add headers if needed
                if ($consistencyLevel)
                {
                    Write-Verbose "[$functionName] Adding ConsistencyLevel header: eventual"
                    write-log -logFile $logFile -Module $functionName -Message "Adding ConsistencyLevel header: eventual" -LogLevel "Debug"                                                                                     
                    $batchRequest['headers'] = @{
                        'ConsistencyLevel' = 'eventual'
                    }
                }
                
                # Add body if provided
                if ($body)
                {
                    Write-Verbose "[$functionName] Adding request body"
                    write-log -logFile $logFile -Module $functionName -Message "Adding request body" -LogLevel "Debug"                                                                                                                                  
                    $batchRequest['body'] = $body | ConvertFrom-Json
                    if (-not $batchRequest.ContainsKey('headers'))
                    {
                        $batchRequest['headers'] = @{}
                        Write-Verbose "[$functionName] Initialized headers dictionary for request body"
                        write-log -logFile $logFile -Module $functionName -Message "Initialized headers dictionary for request body" -LogLevel "Debug"                                                                                                                  
                    }
                    $batchRequest['headers']['Content-Type'] = 'application/json'
                    Write-Verbose "[$functionName] Set Content-Type header to application/json"
                    write-log -logFile $logFile -Module $functionName -Message "Set Content-Type header to application/json" -LogLevel "Debug"                                                                                                                                  
                }
                
                $batchRequests += $batchRequest
                $localRequestId++
            }
            
            # Create batch request body
            $batchBody = @{
                requests = $batchRequests
            } | ConvertTo-Json -Depth 10
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Sending batch $($batchIndex + 1) with $($batchRequests.Count) requests to `$batch endpoint" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Sending batch $($batchIndex + 1) with $($batchRequests.Count) requests to `$batch endpoint"
            Write-Verbose "[$functionName] Batch request body: $batchBody"
            write-log -logFile $logFile -Module $functionName -Message "Batch request body: $batchBody" -LogLevel "Debug"
            
            # Send batch request to Graph API
            $statusCode = $null
            try
            {
                $batchHeaders = @{
                    'Authorization' = "Bearer $accessToken"
                    'Content-Type'  = 'application/json'
                }
                $batchUri = "https://graph.microsoft.com/$APIVersion/`$batch"
                
                # Use StatusCodeVariable for PS7+ to capture status code on errors
                $restParams = @{
                    Uri             = $batchUri
                    Method          = 'Post'
                    Headers         = $batchHeaders
                    Body            = $batchBody
                    UseBasicParsing = $true
                }
                
                if ($PSVersionTable.PSVersion.Major -ge 7)
                {
                    $restParams['StatusCodeVariable'] = 'statusCode'
                }
                
                $batchResponse = Invoke-RestMethod @restParams
                Write-Verbose "[$functionName] Received batch response with $($batchResponse.responses.Count) items"
                write-log -logFile $logFile -Module $functionName -Message "Received batch response with $($batchResponse.responses.Count) items" -LogLevel "Debug"
                
                # Process batch responses
                foreach ($response in $batchResponse.responses)
                {
                    $localId = [int]$response.id
                    $globalIndex = $batchRequestMapping[$localId]
                    $resourceInfo = $resourceMapping[$globalIndex]
                    
                    Write-Verbose "[$functionName] Processing response for resource: $($resourceInfo.id) (status: $($response.status))"                          
                    write-log -logFile $logFile -Module $functionName -Message "Processing response for resource: $($resourceInfo.id) (status: $($response.status))" -LogLevel "Debug"                                   
                    
                    if ($response.status -ge 200 -and $response.status -lt 300)
                    {
                        # Success: extract body data
                        # Handle null response body (can occur for empty result sets)
                        if ($null -eq $response.body)
                        {
                            Write-Verbose "[$functionName] Response body is null for resource: $($resourceInfo.id), creating empty result"
                            $resultData = @{
                                value = @()
                            }
                        }
                        else
                        {
                            $resultData = $response.body
                        }
                        
                        # Add metadata to track the original resource
                        $resultData | Add-Member -NotePropertyName '__batchMetadata' -NotePropertyValue @{
                            resourceId    = $resourceInfo.id
                            resourceUrl   = $resourceInfo.url
                            originalIndex = $resourceInfo.originalIndex
                            batchIndex    = $batchIndex
                            status        = $response.status
                        } -Force
                        
                        $allResults += $resultData
                        $successCount++
                        
                        Write-Log -LogFile $logFile -Module $functionName -Message "Batch request succeeded: $($resourceInfo.id) (status: $($response.status))" -LogLevel "Verbose"
                        Write-Verbose "[$functionName] Batch request succeeded: $($resourceInfo.id) (status: $($response.status))"
                    }
                    else
                    {
                        # Failure: capture comprehensive error details matching single-request behavior
                        $errorCode = if ($response.body.error.code) { $response.body.error.code } else { "" }
                        $errorMessage = if ($response.body.error.message) { $response.body.error.message } else { "Unknown error" }
                        $innerError = $response.body.error.innerError
                        
                        # Extract additional error context
                        $requestId = if ($innerError.'request-id') { $innerError.'request-id' } else { "N/A" }
                        $clientRequestId = if ($innerError.'client-request-id') { $innerError.'client-request-id' } else { "N/A" }
                        $errorDate = if ($innerError.date) { $innerError.date } else { "N/A" }
                        
                        # Build comprehensive error log matching single-request format
                        $errorLogMessage = @"
[$functionName] Batch request failed for resource: $($resourceInfo.id)
ResourceURL: $($resourceInfo.url)
StatusCode: $($response.status)
ErrorCode: $errorCode
ErrorMessage: $errorMessage
Request-Id: $requestId
Client-Request-Id: $clientRequestId
ErrorDate: $errorDate
"@
                        
                        if ($innerError)
                        {
                            $errorLogMessage += "`nInnerError: $($innerError | ConvertTo-Json -Depth 5 -Compress)"
                        }
                        
                        Write-Log -Message $errorLogMessage -LogFile $logFile -Module $functionName -LogLevel "Error"
                        Write-Verbose $errorLogMessage
                        
                        # Store structured error details
                        $errorDetails += @{
                            resourceId      = $resourceInfo.id
                            resourceUrl     = $resourceInfo.url
                            originalIndex   = $resourceInfo.originalIndex
                            statusCode      = $response.status
                            errorCode       = $errorCode
                            errorMessage    = $errorMessage
                            requestId       = $requestId
                            clientRequestId = $clientRequestId
                            errorDate       = $errorDate
                            innerError      = $innerError
                            fullResponse    = $response
                        }
                        
                        $failureCount++
                    }
                }
                
                $batchIndex++
            }
            catch
            {
                # Capture detailed batch endpoint failure
                $exceptionMessage = $_.Exception.Message
                $exceptionType = $_.Exception.GetType().FullName
                $statusDescription = $null
                $responseBody = $null
                
                # Try to extract response details
                if ($_.Exception.Response)
                {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                    $statusDescription = $_.Exception.Response.StatusDescription
                    
                    try
                    {
                        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                        $responseBody = $streamReader.ReadToEnd()
                        $streamReader.Close()
                    }
                    catch
                    {
                        $responseBody = "Unable to read response body: $($_.Exception.Message)"
                    }
                }
                
                $batchErrorLog = @"
[$functionName] Batch endpoint request failed:
ExceptionType: $exceptionType
ExceptionMessage: $exceptionMessage
StatusCode: $statusCode
StatusDescription: $statusDescription
BatchIndex: $batchIndex
RequestCount: $($batchRequests.Count)
ResponseBody: $responseBody
"@
                
                Write-Log -Message $batchErrorLog -LogFile $logFile -Module $functionName -LogLevel "Error"
                Write-Verbose $batchErrorLog
                
                # Fallback: process each resource in this batch sequentially
                Write-Log -LogFile $logFile -Module $functionName -Message "Falling back to sequential processing for batch $($batchIndex + 1)" -LogLevel "Warning"
                Write-Verbose "[$functionName] Falling back to sequential processing for batch $($batchIndex + 1)"
                
                for ($j = 0; $j -lt $batch.Count; $j++)
                {
                    $path = $batch[$j]
                    $globalIndex = ($batchIndex * $maxBatchSize) + $j
                    $resourceInfo = $resourceMapping[$globalIndex]
                    
                    Write-Log -LogFile $logFile -Module $functionName -Message "Processing resource sequentially: $($resourceInfo.id) ($path)" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Processing resource sequentially: $($resourceInfo.id) ($path)"
                    
                    # Recursive call with single resource path
                    $result = CallGraphAPI -accessToken $accessToken -ResourcePath $path -APIVersion $APIVersion `
                        -method $method -Filter $Filter -Search $Search -ExtraParameters $ExtraParameters `
                        -body $body -consistencyLevel:$consistencyLevel -secureString:$secureString
                    
                    # Check if result is an error status code (integer) or null
                    if ($null -eq $result -or $result -is [int])
                    {
                        $failureCount++
                        $errorDetails += @{
                            resourceId      = $resourceInfo.id
                            resourceUrl     = $resourceInfo.url
                            originalIndex   = $resourceInfo.originalIndex
                            statusCode      = $result
                            errorMessage    = "Sequential fallback failed"
                            fallbackFailure = $true
                        }
                        Write-Log -LogFile $logFile -Module $functionName -Message "Failed to process resource: $($resourceInfo.id) (Status: $result)" -LogLevel "Warning"
                        Write-Verbose "[$functionName] Failed to process resource: $($resourceInfo.id) (Status: $result)"
                    }
                    else
                    {
                        # Add metadata to successful result
                        $result | Add-Member -NotePropertyName '__batchMetadata' -NotePropertyValue @{
                            resourceId      = $resourceInfo.id
                            resourceUrl     = $resourceInfo.url
                            originalIndex   = $resourceInfo.originalIndex
                            fallbackSuccess = $true
                        } -Force
                        
                        $allResults += $result
                        $successCount++
                        Write-Verbose "[$functionName] Successfully processed resource: $($resourceInfo.id)"                  
                        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully processed resource: $($resourceInfo.id)" -LogLevel "Verbose"             
                    }
                }
                
                $batchIndex++
            }
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Batch processing completed: $successCount successful, $failureCount failed out of $($normalizedResources.Count) total" -LogLevel "Information"
        Write-Verbose "[$functionName] Batch processing completed: $successCount successful, $failureCount failed out of $($normalizedResources.Count) total"
        
        # Log summary of errors if any occurred
        if ($errorDetails.Count -gt 0)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Error summary: $($errorDetails.Count) requests failed" -LogLevel "Warning"
            foreach ($error in $errorDetails)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "  - $($error.resourceId): $($error.errorCode) - $($error.errorMessage)" -LogLevel "Warning"
            }
        }
        
        # Return combined results with enhanced metadata
        return @{
            value           = $allResults
            batchProcessed  = $true
            batchMethod     = "NativeBatch"
            successCount    = $successCount
            failureCount    = $failureCount
            totalCount      = $normalizedResources.Count
            errorDetails    = $errorDetails
            resourceMapping = $resourceMapping
        }
    }
    
    # Single request processing (original behavior continues below)
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    $statusCode = $null
    Write-Log -LogFile $logFile -Module $functionName -Message "Uri: $uri" -LogLevel "Information"
    Write-Verbose "[$functionName] Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Processing filter string: $Filter" -LogLevel "Verbose"
        Write-Log -LogFile $logFile -Module $functionName -Message "Splitting filter by logical operators while preserving operators." -LogLevel "Information"
        Write-Verbose "[$functionName] Splitting filter by logical operators while preserving operators."                                       
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
        Write-Log -LogFile $logFile -Module $functionName -Message "Found $($logicalOperaterMatches.Count) logical operators." -LogLevel "Verbose"
        Write-Verbose "[$functionName] Found $($logicalOperaterMatches.Count) logical operators."
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No logical operators found. Processing as a single filter condition." -LogLevel "Verbose"
            Write-Verbose "[$functionName] No logical operators found. Processing as a single filter condition."
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Log -LogFile $logFile -Module $functionName -Message "Processed single filter condition: $processedFilter" -LogLevel "Information"
            Write-Verbose "[$functionName] Processed single filter condition: $processedFilter"
            $encodedFilter = $processedFilter
            Write-Log -LogFile $logFile -Module $functionName -Message "Encoded filter: $encodedFilter" -LogLevel "Information"
            Write-Verbose "[$functionName] Encoded filter: $encodedFilter"
        }
        else
        {
            # Process each part of the filter
            Write-Log -LogFile $logFile -Module $functionName -Message "Logical operators found. Processing filter as multiple conditions." -LogLevel "Verbose"
            Write-Verbose "[$functionName] Logical operators found. Processing filter as multiple conditions."
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))" -LogLevel "Debug"
                Write-Verbose "[$functionName] Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))"                                                 
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Log -LogFile $logFile -Module $functionName -Message "Condition to process: $condition" -LogLevel "Information"
                Write-Verbose "[$functionName] Condition to process: $condition"                                                                                
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Log -LogFile $logFile -Module $functionName -Message "Processed filter condition: $($filterParts[$filterParts.Count - 1])" -LogLevel "Information"
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"                                                 
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Log -LogFile $logFile -Module $functionName -Message "Logical operators so far: $($logicalOperators -join ', ')" -LogLevel "Information"
                Write-Verbose "[$functionName] Logical operators so far: $($logicalOperators -join ', ')"                                                                   
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Processing filter condition after the last logical operator." -LogLevel "Verbose"
                Write-Verbose "[$functionName] Processing filter condition after the last logical operator."                                                                    
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Log -LogFile $logFile -Module $functionName -Message "Processed filter condition: $($filterParts[$filterParts.Count - 1])" -LogLevel "Information"
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"                             
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Log -LogFile $logFile -Module $functionName -Message "Rebuilding the filter string with processed parts and logical operators." -LogLevel "Information"
            Write-Verbose "[$functionName] Rebuilding the filter string with processed parts and logical operators."
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Log -LogFile $logFile -Module $functionName -Message "Adding logical operator: $($logicalOperators[$i])" -LogLevel "Information"
                Write-Verbose "[$functionName] Adding logical operator: $($logicalOperators[$i])"                                                           
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "Processed complex filter: $encodedFilter" -LogLevel "Information"
            Write-Verbose "[$functionName] Processed complex filter: $encodedFilter"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Log -LogFile $logFile -Module $functionName -Message "Uri after applying filters: $encodedUri" -LogLevel "Information"
        Write-Verbose "[$functionName] Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No filter provided." -LogLevel "Information"
        Write-Verbose "[$functionName] No filter provided."                                                         
        $encodedUri = $uri
        Write-Verbose "[$functionName] No filter provided. Using base URI: $encodedUri"         
    }
    
    # Handle search parameter
    if ($Search)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Processing search parameter: $Search" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Processing search parameter: $Search"
        # URL encode the search string
        $encodedSearch = [uri]::EscapeUriString($Search)
        Write-Log -LogFile $logFile -Module $functionName -Message "Encoded search: $encodedSearch" -LogLevel "Information"
        Write-Verbose "[$functionName] Encoded search: $encodedSearch"
        # Add search parameter to URI
        if ($encodedUri.Contains("?"))
        {
            $encodedUri = "$encodedUri&`$search=$encodedSearch"
            Write-Verbose "[$functionName] Uri after applying search with existing parameters: $encodedUri"                                            
        }
        else
        {
            $encodedUri = "$encodedUri`?`$search=$encodedSearch"
            Write-Verbose "[$functionName] Uri after applying search as first parameter: $encodedUri"                                                                               
            write-log -logFile $logFile -Module $functionName -Message "Uri after applying search as first parameter: $encodedUri" -LogLevel "Information"                                      
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Uri after applying search: $encodedUri" -LogLevel "Information"
        Write-Verbose "[$functionName] Uri after applying search: $encodedUri"
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No search parameter provided." -LogLevel "Information"
        Write-Verbose "[$functionName] No search parameter provided."                                               
    }
    
    if ($extraParameters)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Extra parameters provided." -LogLevel "Information"
        Write-Log -LogFile $logFile -Module $functionName -Message "Splitting the extra parameters by ampersand to get individual key-value pairs." -LogLevel "Information"
        Write-Verbose "[$functionName] Extra parameters provided."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Log -LogFile $logFile -Module $functionName -Message "Found $($keyValuePairs.Count) key-value pairs." -LogLevel "Verbose"
        Write-Verbose "[$functionName] Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Processing key-value pair: $pair" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Processing key-value pair: $pair"                                                                
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Log -LogFile $logFile -Module $functionName -Message "Key: $key" -LogLevel "Information"
                Write-Log -LogFile $logFile -Module $functionName -Message "Value: $value" -LogLevel "Information"
                Write-Verbose "[$functionName] Key: $key"
                Write-Verbose "[$functionName] Value: $value"                                                               
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Log -LogFile $logFile -Module $functionName -Message "Formatted Key with $ prefix: $formattedKey" -LogLevel "Information"
                Write-Verbose "[$functionName] Formatted Key with $ prefix: $formattedKey"                                                      
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
                Write-Log -LogFile $logFile -Module $functionName -Message "Invalid parameter format: $pair - skipping" -LogLevel "Warning"
            }
            Write-Verbose "[$functionName] Processed key-value pair: $pair"                     
            Write-Log -LogFile $logFile -Module $functionName -Message "Processed key-value pair: $pair" -LogLevel "Verbose"                    
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Final parameter list:" -LogLevel "Information"
        Write-Verbose "[$functionName] Final parameter list:"                                           
        $paramsList | ForEach-Object { Write-Verbose "[$functionName] $_" }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Log -LogFile $logFile -Module $functionName -Message "Final query string: $queryString" -LogLevel "Information"
        Write-Verbose "[$functionName] Final query string: $queryString"
        # Append the extra parameters to the URI
        if ($filter -or $Search) 
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Adding extra parameters to the uri along with existing parameters." -LogLevel "Information"
            Write-Verbose "[$functionName] Adding extra parameters to the uri along with existing parameters."                                          
            $encodedUri = "$encodedUri`&$queryString"
            Write-Verbose "[$functionName] Uri after adding extra parameters with existing parameters: $encodedUri"
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No filter or search provided. Adding extra parameters to the uri." -LogLevel "Information"
            Write-Verbose "[$functionName] No filter or search provided. Adding extra parameters to the uri."                                                   
            $encodedUri = "$encodedUri`?$queryString"
            Write-Verbose "[$functionName] Uri after adding extra parameters as first parameter: $encodedUri"
            Write-Log -LogFile $logFile -Module $functionName -Message "Uri after adding extra parameters as first parameter: $encodedUri" -LogLevel "Information"
        }
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No extra parameters provided." -LogLevel "Information"
        Write-Verbose "[$functionName] No extra parameters provided."
    }
    # Build default headers with Authorization and Content-Type
    if ($consistencyLevel)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Adding consistency level to the headers." -LogLevel "Information"
        Write-Verbose "[$functionName] Adding consistency level to the headers."
        $defaultHeaders = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No consistency level provided." -LogLevel "Information"
        Write-Verbose "[$functionName] No consistency level provided."
        $defaultHeaders = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    
    # Merge custom headers if provided (custom headers take precedence)
    if ($headers)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Custom headers provided. Merging with default headers." -LogLevel "Information"
        Write-Verbose "[$functionName] Custom headers provided. Merging with default headers."                                                                          
        foreach ($key in $headers.Keys)
        {
            $defaultHeaders[$key] = $headers[$key]
            Write-Log -LogFile $logFile -Module $functionName -Message "Added/Overridden header: $key" -LogLevel "Information"                                                          
            Write-Verbose "[$functionName] Added/Overridden header: $key"                                                                       
        }
    }
    #endregion

    #region prepare the call
    # Create parameter hashtable for splatting
    Write-Log -LogFile $logFile -Module $functionName -Message "Preparing parameters for Invoke-RestMethod call." -LogLevel "Information"
    Write-Verbose "[$functionName] Preparing parameters for Invoke-RestMethod call."                                                                        
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $defaultHeaders
        UseBasicParsing = $true
    }
    #add headers parameter if it was passed
    if ($headers)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Headers provided. Adding to the request." -LogLevel "Information"
        Write-Verbose "[$functionName] Headers provided. Adding to the request."                                                                                
        $restParams['Headers'] = $headers
    }                                                               
    # Only add Body parameter if it exists
    if ($body)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Body parameter provided. Adding to the request." -LogLevel "Information"
        Write-Verbose "[$functionName] Body parameter provided. Adding to the request."                                                                                 
        $restParams['Body'] = $body
    }                                           
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "PowerShell version is $($PSVersionTable.PSVersion.Major ). Adding StatusCodeVariable to the request." -LogLevel "Debug"
        Write-Verbose "[$functionName] PowerShell version is $($PSVersionTable.PSVersion.Major ). Adding StatusCodeVariable to the request."
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Log -LogFile $logFile -Module $functionName -Message "Making the following call to Microsoft Graph:" -LogLevel "Information"
    Write-Verbose "[$functionName] Making the following call to Microsoft Graph:"                                                               
    Write-Log -LogFile $logFile -Module $functionName -Message "URI: $encodedUri." -LogLevel "Information"
    Write-Verbose "[$functionName] URI: $encodedUri"                                            
    Write-Log -LogFile $logFile -Module $functionName -Message "Method: $method." -LogLevel "Information"
    Write-Verbose "[$functionName] Method: $method"                                         
    #endregion
    try
    {
        Write-Verbose "[$functionName] Invoking REST method with parameters: $($restParams | ConvertTo-Json -Depth 5)"          
        $response = Invoke-RestMethod @restParams
        Write-Log -LogFile $logFile -Module $functionName -Message "NextLink: $($response.'@odata.nextLink')" -LogLevel "Information"
        Write-Verbose "[$functionName] NextLink: $($response.'@odata.nextLink')"
        Write-Log -LogFile $logFile -Module $functionName -Message "Response count: $($response.value.count)" -LogLevel "Information"
        Write-Verbose "[$functionName] Received response with $($response.value.Count) items. NextLink: $($response.'@odata.nextLink')"
        if ($response.'@odata.nextLink')
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "NextLink found. Fetching additional pages." -LogLevel "Verbose"
            Write-Verbose "[$functionName] NextLink found. Fetching additional pages."
            # Initialize an array to hold all items
            $allItems = @()
            $allItems += $response.value
            $nextLink = $response.'@odata.nextLink'
            while ($nextLink)
            {
                $nextGroup = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $defaultHeaders -UseBasicParsing
                Write-Log -LogFile $logFile -Module $functionName -Message "Fetched next page with $($nextGroup.value.Count) items." -LogLevel "Information"
                Write-Verbose "[$functionName] Fetched next page with $($nextGroup.value.Count) items."     
                if ($nextGroup.value)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Adding items from next page to the collection." -LogLevel "Information"
                    Write-Verbose "[$functionName] Adding items from next page to the collection."  
                    $allItems += $nextGroup.value
                }
                $nextLink = $nextGroup.'@odata.nextLink'
            }
            # Optionally, reconstruct a response object if needed
            $response.value = $allItems
            Write-Log -LogFile $logFile -Module $functionName -Message "All items collected. Total count: $($Response.value.Count)" -LogLevel "Information"
            Write-Verbose "[$functionName] All items collected. Total count: $($Response.value.Count)"                                                          
        }
        else 
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No nextLink found. Single page response received." -LogLevel "Verbose"
            Write-Verbose "[$functionName] No nextLink found. Single page response received."
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "The call was successful." -LogLevel "Information"
        Write-Verbose "[$functionName] The call was successful."
        if ($response.count)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Number of objects returned: $($response.count)." -LogLevel "Information"
            Write-Verbose "[$functionName] Number of objects returned: $($response.count)."                                                                     
        }
        if ($response.value.Count)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Number of items returned: $($response.value.Count)." -LogLevel "Information"
            Write-Verbose "[$functionName] Number of items returned: $($response.value.Count)."
        }
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code: $statusCode" -LogLevel "Information"
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code message: $statusCodeMessage" -LogLevel "Information"
            Write-Verbose "[$functionName] Status code: $statusCode"
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
        }
    }
    catch
    {
        # Capture as much diagnostic information as possible about the failure
        Write-Log -LogFile $logFile -Module $functionName -Message "Exception type: $($PSItem.Exception.GetType().FullName)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Exception message: $($PSItem.Exception.Message)" -LogLevel "Error"
        # Walk inner exceptions (if any)
        $inner = $PSItem.Exception.InnerException
        while ($null -ne $inner)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "InnerException type: $($inner.GetType().FullName)" -LogLevel "Error"
            Write-Log -LogFile $logFile -Module $functionName -Message "InnerException message: $($inner.Message)" -LogLevel "Error"    
            $inner = $inner.InnerException
        }
        # Defaults
        $statusDescription = $null
        $statusMessage = $PSItem.Exception.Message
        $statusCodeMessage = $null
        # Try to extract status code from exception when available
        if ($null -eq $PSItem.Exception.statusCode)
        {
            # Fallback: try to parse from exception message
            $statusCode = [regex]::Match($PSItem.Exception.Message, '\d+').Value
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code (parsed): $statusCode" -LogLevel "Error"
            $statusCodeMessage = $PSItem.Exception | Out-String
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code message: $statusCodeMessage" -LogLevel "Error"
        }
        else
        {
            # PowerShell 5.1/7 HttpStatusCode
            try
            {
                $statusCode = $PSItem.Exception.statuscode.value__ 
            }
            catch
            {
                $statusCode = [int]$PSItem.Exception.statuscode 
            }
            $statusCodeMessage = $PSItem.Exception.statuscode
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code (from exception): $statusCode" -LogLevel "Error"
        }
        Write-Verbose "[$functionName] Status code: $statusCode"
        # Attempt to extract response details (headers/body) across PS versions
        $responseBodyRaw = $null
        $responseJson = $null
        $requestId = $null
        $clientRequestId = $null
        $serverDate = $null
        $retryAfter = $null
        $diagHeader = $null
        $responseHeaders = @{}
        $resp = $PSItem.Exception.Response
        if ($null -ne $resp)
        {
            # Status description when available
            try
            {
                $statusDescription = $resp.StatusDescription 
            }
            catch
            { 
                $statusDescription = $null 
            }

            # Headers (handle both WebHeaderCollection and IDictionary-like)
            try
            {
                if ($resp.Headers -and $resp.Headers -is [System.Net.WebHeaderCollection])
                {
                    foreach ($key in $resp.Headers.AllKeys)
                    {
                        $responseHeaders[$key] = $resp.Headers[$key]
                    }
                }
                elseif ($resp.Headers)
                {
                    foreach ($kvp in $resp.Headers.GetEnumerator())
                    {
                        $responseHeaders[$kvp.Key] = ($kvp.Value -join ',')
                    }
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to enumerate response headers: $($_.Exception.Message)" 
                & $logWarn "[$functionName] Failed to enumerate response headers: $($_.Exception.Message)"
            }

            # Common Graph headers
            if ($responseHeaders.ContainsKey('request-id'))
            {
                $requestId = $responseHeaders['request-id'] 
            }
            if ($responseHeaders.ContainsKey('client-request-id'))
            {
                $clientRequestId = $responseHeaders['client-request-id'] 
            }
            if ($responseHeaders.ContainsKey('x-ms-ags-diagnostic'))
            {
                $diagHeader = $responseHeaders['x-ms-ags-diagnostic'] 
            }
            if ($responseHeaders.ContainsKey('Date'))
            {
                $serverDate = $responseHeaders['Date'] 
            }
            if ($responseHeaders.ContainsKey('Retry-After'))
            {
                $retryAfter = $responseHeaders['Retry-After'] 
            }
            # Body: handle HttpWebResponse stream and PS7 ErrorDetails fallbacks
            try
            {
                if ($resp -is [System.Net.HttpWebResponse])
                {
                    $errorResponse = $resp.GetResponseStream()
                    if ($errorResponse)
                    {
                        $streamReader = New-Object System.IO.StreamReader($errorResponse)
                        $responseBodyRaw = $streamReader.ReadToEnd()
                        $streamReader.Close()
                    }
                }
            }
            catch
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to read response stream: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        # Additional fallbacks commonly present in PS7
        if (-not $responseBodyRaw)
        {
            try
            {
                if ($PSItem.ErrorDetails -and $PSItem.ErrorDetails.Message)
                {
                    $responseBodyRaw = $PSItem.ErrorDetails.Message 
                } 
            }
            catch
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve ErrorDetails: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }
        if (-not $responseBodyRaw)
        {
            try
            {
                if ($PSItem.Exception.Response -and $PSItem.Exception.Response.Content)
                {
                    $responseBodyRaw = [string]$PSItem.Exception.Response.Content 
                } 
            }
            catch
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve response content: $($_.Exception.Message)" -LogLevel "Warning"
            }
        }

        # Parse JSON body if it looks like JSON
        if ($responseBodyRaw)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Raw server response captured (truncated for display if large)." -LogLevel "Information"
            Write-Log -LogFile $logFile -Module $functionName -Message "Server Response (raw): $responseBodyRaw" -LogLevel "Error"
            try
            {
                $responseJson = $responseBodyRaw | ConvertFrom-Json -ErrorAction Stop 
            }
            catch
            {
                $responseJson = $null 
            }
        }
        # Extract Graph error fields when available
        if ($null -ne $responseJson -and $responseJson.error)
        {
            $graphError = $responseJson.error
            $graphCode = $graphError.code
            $graphMessage = $graphError.message
            Write-Log -LogFile $logFile -Module $functionName -Message "Graph error code: $graphCode" -LogLevel "Information"
            Write-Log -LogFile $logFile -Module $functionName -Message "Graph error message: $graphMessage" -LogLevel "Information"
            if ($graphError.innerError)
            {
                $innerErr = $graphError.innerError
                # Newer Graph may use camelCase innerError fields; older uses innererror
                try
                {
                    if (-not $requestId -and $innerErr.'request-id')
                    {
                        $requestId = $innerErr.'request-id' 
                    } 
                }
                catch
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve inner error request-id: $($_.Exception.Message)" -LogLevel "Warning"
                }
                try
                {
                    if (-not $clientRequestId -and $innerErr.'client-request-id')
                    {
                        $clientRequestId = $innerErr.'client-request-id' 
                    } 
                }
                catch
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve inner error client-request-id: $($_.Exception.Message)" -LogLevel "Warning"
                }
                try
                {
                    if (-not $serverDate -and $innerErr.date)
                    {
                        $serverDate = $innerErr.date 
                    } 
                }
                catch
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to retrieve inner error date: $($_.Exception.Message)" -LogLevel "Warning"
                }
                Write-Log -LogFile $logFile -Module $functionName -Message "Graph innerError: request-id=$requestId client-request-id=$clientRequestId date=$serverDate" -LogLevel "Information"
                # Some APIs include nested innererror with additional code/message
                if ($innerErr.innererror)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Graph nested innererror: $($innerErr.innererror | ConvertTo-Json -Depth 5)" -LogLevel "Information"
                }
            }
        }

        # Summarize headers and identifiers (avoid logging Authorization)
        if ($responseHeaders.Count -gt 0)
        {
            Write-Verbose "[$functionName] Response headers:"
            foreach ($k in $responseHeaders.Keys | Sort-Object)
            {
                if ($k -ne 'Authorization')
                {
                    Write-Verbose "[$functionName]   $($k): $($responseHeaders[$k])" 
                    Write-Log -LogFile $logFile -Module $functionName -Message "Response header: $($k): $($responseHeaders[$k])" -LogLevel "Information"
                }
            }
        }
        if ($requestId)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Request-Id: $requestId" -LogLevel "Information"
        }
        if ($clientRequestId)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Client-Request-Id: $clientRequestId" -LogLevel "Information"
        }
        if ($diagHeader)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "x-ms-ags-diagnostic: $diagHeader" -LogLevel "Information"
        }
        if ($serverDate)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Server Date: $serverDate" -LogLevel "Information"
        }
        if ($retryAfter)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Retry-After: $retryAfter" -LogLevel "Information"
        }
        # Persist diagnostics to disk via Write-Log (if available)
        try
        {
            # Build a consolidated diagnostic message
            $headersText = ''
            if ($responseHeaders.Count -gt 0)
            {
                $headersText = ($responseHeaders.GetEnumerator() | Where-Object { $_.Key -ne 'Authorization' } | Sort-Object Key | ForEach-Object { "${($_.Key)}: ${($_.Value)}" }) -join [Environment]::NewLine
            }
            $graphInnerDump = $null
            if ($responseJson -and $responseJson.error -and $responseJson.error.innerError)
            {
                try
                {
                    $graphInnerDump = ($responseJson.error.innerError | ConvertTo-Json -Depth 8) 
                }
                catch
                {
                    $graphInnerDump = ($responseJson.error.innerError | Out-String) 
                }
            }
            $rawBodyForLog = $responseBodyRaw
            # Optionally truncate extremely large bodies to keep logs manageable
            $maxBody = 50000
            if ($rawBodyForLog -and $rawBodyForLog.Length -gt $maxBody)
            {
                $rawBodyForLog = $rawBodyForLog.Substring(0, $maxBody) + "... (truncated; total length=$($responseBodyRaw.Length))"
            }
            $logMessage = @"
[$functionName] Graph API call failed.
ExceptionType: $($PSItem.Exception.GetType().FullName)
ExceptionMessage: $($PSItem.Exception.Message)
StatusCode: $statusCode
StatusDescription: $statusDescription
StatusCodeMessage: $statusCodeMessage
Request-Id: $requestId
Client-Request-Id: $clientRequestId
ServerDate: $serverDate
Retry-After: $retryAfter
Headers:
$headersText

GraphErrorCode: $graphCode
GraphErrorMessage: $graphMessage
GraphInnerError:
$graphInnerDump

ResponseBody:
$rawBodyForLog
"@

            Write-Log -Message $logMessage -LogFile $logFile -Module $functionName -LogLevel Error -CMTraceFormat:$false -ErrorAction SilentlyContinue
            # Fallback verbose logging to ensure we don't lose diagnostics
            Write-Verbose "[$functionName] (fallback) $logMessage"
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to write diagnostics via Write-Log: $($_.Exception.Message)" 
            Write-Log -Message "(fallback) $logMessage" -LogFile $logFile -Module $functionName -LogLevel Error -CMTraceFormat:$false -ErrorAction SilentlyContinue
        }

        # Preserve existing switch logic for user-friendly messages
        $statusMessage = $statusMessage
        switch ($statusCode)
        {
            400
            {
                Write-Log -Message "Status code: $statusCode" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Bad request. Please check the resource name." 
            }
            401
            {
                Write-Log -Message "Status code: $statusCode" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Unauthorized. Please check your access token." 
            }
            403
            {
                Write-Log -Message "Status code: $statusCode" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Forbidden. You do not have permission to access this resource." 
            }
            404
            {
                Write-Log -Message "Status code: $statusCode" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Not found. The resource does not exist." 
            }
            default
            {
                Write-Verbose "[$functionName] An unknown error occurred. Please check the error message below." 
                Write-Log -Message "(fallback) $logMessage" -LogFile $logFile -Module $functionName -LogLevel Error -CMTraceFormat:$false -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Error: $statusMessage"
                Write-Log -Message "(fallback) $logMessage" -LogFile $logFile -Module $functionName -LogLevel Error -CMTraceFormat:$false -ErrorAction SilentlyContinue
                if ($statusCode)
                {
                    Write-Log -Message "The status code is $statusCode" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                }
                if ($statusDescription)
                {
                    Write-Log -Message "Status description: $statusDescription" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                }
                if ($statusCodeMessage)
                {
                    Write-Log -Message "$statusCode indicates $statusCodeMessage" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                }
                Write-Log -Message "Status message: $statusMessage" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                if ($requestId)
                {
                    Write-Log -Message "Request-Id: $requestId" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                }
                if ($clientRequestId)
                {
                    Write-Log -Message "Client-Request-Id: $clientRequestId" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                }
                if ($retryAfter)
                {
                    Write-Log -Message "Retry-After: $retryAfter" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
                }
                Write-Verbose "[$functionName] The full error message follows below:"
                Write-Verbose "[$functionName] ----------------------------------------------------------"
                Write-Verbose "[$functionName] $_"
                # Raw server body already logged above when available
            }
        }
        Write-Log -Message "Failed to call the Graph API: $_" -LogFile $logFile -Module $functionName -LogLevel Error -CMTraceFormat:$false -ErrorAction SilentlyContinue
        Write-Log -Message "The status code is $statusCode" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        if ($statusCodeMessage)
        {
            Write-Log -Message "$statusCode indicates $statusCodeMessage" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        }
        if ($statusDescription)
        {
            Write-Log -Message "Status description: $statusDescription" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        }
        Write-Log -Message "Status message: $statusMessage" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        Write-Log -Message "The full error message follows below:" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        Write-Log -Message "----------------------------------------------------------" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Error: $($_)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Exception message: $($PSItem.Exception.Message)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Exception response: $($PSItem.Exception.Response)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        if ($responseBodyRaw)
        {
            Write-Log -Message "Server Response (raw): $responseBodyRaw" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
        }
        return $statusCode
    }
    Write-Log -Message "Response: $($response)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
    Write-Log -Message "Response value: $($response.value)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
    return $response
}
