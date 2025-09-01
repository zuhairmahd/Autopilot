function CallGraphAPI()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$ResourcePath,
        [string]$APIVersion = 'beta',
        [string]$method = 'get',
        [string]$Filter = $null,
        [string]$Search = $null,
        [string]$ExtraParameters = $null,
        [string]$body = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    if ($accessToken)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Access token provided." -LogLevel "Information"
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
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    $statusCode = $null
    Write-Log -LogFile $logFile -Module $functionName -Message "Uri: $uri" -LogLevel "Information"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
Write-Log -LogFile $logFile -Module $functionName -Message "Processing filter string: $Filter" -LogLevel "Verbose"
        Write-Log -LogFile $logFile -Module $functionName -Message "Splitting filter by logical operators while preserving operators." -LogLevel "Information"
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
Write-Log -LogFile $logFile -Module $functionName -Message "Found $($logicalOperaterMatches.Count) logical operators." -LogLevel "Verbose"
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
Write-Log -LogFile $logFile -Module $functionName -Message "No logical operators found. Processing as a single filter condition." -LogLevel "Verbose"
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Log -LogFile $logFile -Module $functionName -Message "Processed single filter condition: $processedFilter" -LogLevel "Information"
            $encodedFilter = $processedFilter
            Write-Log -LogFile $logFile -Module $functionName -Message "Encoded filter: $encodedFilter" -LogLevel "Information"
        }
        else
        {
            # Process each part of the filter
Write-Log -LogFile $logFile -Module $functionName -Message "Logical operators found. Processing filter as multiple conditions." -LogLevel "Verbose"
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
Write-Log -LogFile $logFile -Module $functionName -Message "Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))" -LogLevel "Debug"
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Log -LogFile $logFile -Module $functionName -Message "Condition to process: $condition" -LogLevel "Information"
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Log -LogFile $logFile -Module $functionName -Message "Processed filter condition: $($filterParts[$filterParts.Count - 1])" -LogLevel "Information"
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Log -LogFile $logFile -Module $functionName -Message "Logical operators so far: $($logicalOperators -join ', ')" -LogLevel "Information"
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
Write-Log -LogFile $logFile -Module $functionName -Message "Processing filter condition after the last logical operator." -LogLevel "Verbose"
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Log -LogFile $logFile -Module $functionName -Message "Processed filter condition: $($filterParts[$filterParts.Count - 1])" -LogLevel "Information"
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Log -LogFile $logFile -Module $functionName -Message "Rebuilding the filter string with processed parts and logical operators." -LogLevel "Information"
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Log -LogFile $logFile -Module $functionName -Message "Adding logical operator: $($logicalOperators[$i])" -LogLevel "Information"
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "Processed complex filter: $encodedFilter" -LogLevel "Information"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Log -LogFile $logFile -Module $functionName -Message "Uri after applying filters: $encodedUri" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No filter provided." -LogLevel "Information"
        $encodedUri = $uri
    }
    
    # Handle search parameter
    if ($Search)
    {
Write-Log -LogFile $logFile -Module $functionName -Message "Processing search parameter: $Search" -LogLevel "Verbose"
        
        # URL encode the search string
        $encodedSearch = [uri]::EscapeUriString($Search)
        Write-Log -LogFile $logFile -Module $functionName -Message "Encoded search: $encodedSearch" -LogLevel "Information"
        
        # Add search parameter to URI
        if ($encodedUri.Contains("?"))
        {
            $encodedUri = "$encodedUri&`$search=$encodedSearch"
        }
        else
        {
            $encodedUri = "$encodedUri`?`$search=$encodedSearch"
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Uri after applying search: $encodedUri" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No search parameter provided." -LogLevel "Information"
    }
    
    if ($extraParameters)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Extra parameters provided." -LogLevel "Information"
        Write-Log -LogFile $logFile -Module $functionName -Message "Splitting the extra parameters by ampersand to get individual key-value pairs." -LogLevel "Information"
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
Write-Log -LogFile $logFile -Module $functionName -Message "Found $($keyValuePairs.Count) key-value pairs." -LogLevel "Verbose"
        foreach ($pair in $keyValuePairs)
        {
Write-Log -LogFile $logFile -Module $functionName -Message "Processing key-value pair: $pair" -LogLevel "Verbose"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Log -LogFile $logFile -Module $functionName -Message "Key: $key" -LogLevel "Information"
                Write-Log -LogFile $logFile -Module $functionName -Message "Value: $value" -LogLevel "Information"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Log -LogFile $logFile -Module $functionName -Message "Formatted Key with $ prefix: $formattedKey" -LogLevel "Information"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
                Write-Log -LogFile $logFile -Module $functionName -Message "Invalid parameter format: $pair - skipping" -LogLevel "Warning"
            }
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Final parameter list:" -LogLevel "Information"
        $paramsList | ForEach-Object { Write-Verbose $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Log -LogFile $logFile -Module $functionName -Message "Final query string: $queryString" -LogLevel "Information"
        if ($filter -or $Search) 
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Adding extra parameters to the uri along with existing parameters." -LogLevel "Information"
            $encodedUri = "$encodedUri`&$queryString"
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No filter or search provided. Adding extra parameters to the uri." -LogLevel "Information"
            $encodedUri = "$encodedUri`?$queryString"
        }
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No extra parameters provided." -LogLevel "Information"
    }
    if ($consistencyLevel)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Adding consistency level to the headers." -LogLevel "Information"
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "No consistency level provided." -LogLevel "Information"
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion

    #region prepare the call
    # Create parameter hashtable for splatting
    Write-Log -LogFile $logFile -Module $functionName -Message "Preparing parameters for Invoke-RestMethod call." -LogLevel "Information"
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Body parameter provided. Adding to the request." -LogLevel "Information"
        $restParams['Body'] = $body
    }
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
Write-Log -LogFile $logFile -Module $functionName -Message "PowerShell version is $($PSVersionTable.PSVersion.Major ). Adding StatusCodeVariable to the request." -LogLevel "Debug"
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Log -LogFile $logFile -Module $functionName -Message "Making the following call to Microsoft Graph:" -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "URI: $encodedUri." -LogLevel "Information"
    Write-Log -LogFile $logFile -Module $functionName -Message "Method: $method." -LogLevel "Information"
    #endregion
    try
    {
        $response = Invoke-RestMethod @restParams
        Write-Log -LogFile $logFile -Module $functionName -Message "NextLink: $($response.'@odata.nextLink')" -LogLevel "Information"
        Write-Log -LogFile $logFile -Module $functionName -Message "Response count: $($response.value.count)" -LogLevel "Information"
        if ($response.'@odata.nextLink')
        {
Write-Log -LogFile $logFile -Module $functionName -Message "NextLink found. Fetching additional pages." -LogLevel "Verbose"
            # Initialize an array to hold all items
            $allItems = @()
            $allItems += $response.value
            $nextLink = $response.'@odata.nextLink'
            while ($nextLink)
            {
                $nextGroup = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing
                Write-Log -LogFile $logFile -Module $functionName -Message "Fetched next page with $($nextGroup.value.Count) items." -LogLevel "Information"
                if ($nextGroup.value)
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Adding items from next page to the collection." -LogLevel "Information"
                    $allItems += $nextGroup.value
                }
                $nextLink = $nextGroup.'@odata.nextLink'
            }
            # Optionally, reconstruct a response object if needed
            $response.value = $allItems
            Write-Log -LogFile $logFile -Module $functionName -Message "All items collected. Total count: $($Response.value.Count)" -LogLevel "Information"
        }
        else 
        {
Write-Log -LogFile $logFile -Module $functionName -Message "No nextLink found. Single page response received." -LogLevel "Verbose"
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "The call was successful." -LogLevel "Information"
        if ($response.count)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Number of objects returned: $($response.count)." -LogLevel "Information"
        }
        if ($response.value.Count)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Number of items returned: $($response.value.Count)." -LogLevel "Information"
        }
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code: $statusCode" -LogLevel "Information"
            Write-Log -LogFile $logFile -Module $functionName -Message "Status code message: $statusCodeMessage" -LogLevel "Information"
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
        # return $null
    }
    Write-Log -Message "Response: $($response)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
    Write-Log -Message "Response value: $($response.value)" -LogFile $logFile -Module $functionName -LogLevel Information -CMTraceFormat:$false -ErrorAction SilentlyContinue
    return $response
}

