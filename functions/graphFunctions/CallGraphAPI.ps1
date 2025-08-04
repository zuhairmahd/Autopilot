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
        [string]$ExtraParameters = $null,
        [string]$body = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    else
    {
        Write-Host 'Access token not provided. Please provide a valid access token.' -ForegroundColor Red
        return
    }
    Write-Verbose "[$functionName] Resource Path: $ResourcePath"
    Write-Verbose "[$functionName] Method: $method"
    Write-Verbose "[$functionName] Filter: $filter"
    Write-Verbose "[$functionName] Extra Parameters: $ExtraParameters"
    Write-Verbose "[$functionName] Version: $APIVersion"
    Write-Verbose "[$functionName] Consistency Level: $consistencyLevel"
    Write-Verbose "[$functionName] Body: $body"
    Write-Verbose "[$functionName] SecureString: $secureString"
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    $statusCode = $null
    Write-Verbose "[$functionName] Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose "[$functionName] Processing filter string: $Filter"
        Write-Verbose "[$functionName] Splitting filter by logical operators while preserving operators."
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
        Write-Verbose "[$functionName] Found $($logicalOperaterMatches.Count) logical operators."
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
            Write-Verbose "[$functionName] No logical operators found. Processing as a single filter condition."
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Verbose "[$functionName] Processed single filter condition: $processedFilter"
            $encodedFilter = $processedFilter
            Write-Verbose "[$functionName] Encoded filter: $encodedFilter"
        }
        else
        {
            # Process each part of the filter
            Write-Verbose "[$functionName] Logical operators found. Processing filter as multiple conditions."
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
                Write-Verbose "[$functionName] Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))"
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Verbose "[$functionName] Condition to process: $condition"
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Verbose "[$functionName] Logical operators so far: $($logicalOperators -join ', ')"
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
                Write-Verbose "[$functionName] Processing filter condition after the last logical operator."
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Verbose "[$functionName] Rebuilding the filter string with processed parts and logical operators."
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Verbose "[$functionName] Adding logical operator: $($logicalOperators[$i])"
            }
            Write-Verbose "[$functionName] Processed complex filter: $encodedFilter"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Verbose "[$functionName] Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Verbose "[$functionName] No filter provided."
        $encodedUri = $uri
    }
    
    if ($extraParameters)
    {
        Write-Verbose "[$functionName] Extra parameters provided."
        Write-Verbose "[$functionName] Splitting the extra parameters by ampersand to get individual key-value pairs."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Verbose "[$functionName] Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Verbose "[$functionName] Processing key-value pair: $pair"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Verbose "[$functionName] Key: $key"
                Write-Verbose "[$functionName] Value: $value"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Verbose "[$functionName] Formatted Key with $ prefix: $formattedKey"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
            }
        }
        Write-Verbose "[$functionName] Final parameter list:"
        $paramsList | ForEach-Object { Write-Verbose $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Verbose "[$functionName] Final query string: $queryString"
        if ($filter) 
        {
            Write-Verbose "[$functionName] Adding extra parameters to the uri along with the filter."
            $encodedUri = "$encodedUri`&$queryString"
        }
        else
        {
            Write-Verbose "[$functionName] No filter provided. Adding extra parameters to the uri."
            $encodedUri = "$encodedUri`?$queryString"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No extra parameters provided."
    }
    if ($consistencyLevel)
    {
        Write-Verbose "[$functionName] Adding consistency level to the headers."
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Verbose "[$functionName] No consistency level provided."
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion

    #region prepare the call
    # Create parameter hashtable for splatting
    Write-Verbose "[$functionName] Preparing parameters for Invoke-RestMethod call."
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        Write-Verbose "[$functionName] Body parameter provided. Adding to the request."
        $restParams['Body'] = $body
    }
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        Write-Verbose "[$functionName] PowerShell version is $($PSVersionTable.PSVersion.Major ). Adding StatusCodeVariable to the request."
        Write-Verbose "[$functionName] Added StatusCodeVariable."
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Verbose "[$functionName] Making the following call to Microsoft Graph:" 
    Write-Verbose "[$functionName] URI: $encodedUri." 
    Write-Verbose "[$functionName] Method: $method."
    #endregion
    try
    {
        $response = Invoke-RestMethod @restParams
        Write-Verbose "[$functionName] NextLink: $($response.'@odata.nextLink')"
        Write-Verbose "[$functionName] Response count: $($response.value.count)"
        if ($response.'@odata.nextLink')
        {
            Write-Verbose "[$functionName] NextLink found. Fetching additional pages."
            # Initialize an array to hold all items
            $allItems = @()
            $allItems += $response.value
            $nextLink = $response.'@odata.nextLink'
            while ($nextLink)
            {
                $nextGroup = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing
                Write-Verbose "[$functionName] Fetched next page with $($nextGroup.value.Count) items."
                if ($nextGroup.value)
                {
                    Write-Verbose "[$functionName] Adding items from next page to the collection."
                    $allItems += $nextGroup.value
                }
                $nextLink = $nextGroup.'@odata.nextLink'
            }
            # Optionally, reconstruct a response object if needed
            $response.value = $allItems
            Write-Verbose "[$functionName] All items collected. Total count: $($Response.value.Count)"
        }
        else 
        {
            Write-Verbose "[$functionName] No nextLink found. Single page response received."
        }
        Write-Verbose "[$functionName] The call was successful."
        if ($response.count)
        {
            Write-Verbose "[$functionName] Number of objects returned: $($response.count)."
        }
        if ($response.value.Count)
        {
            Write-Verbose "[$functionName] Number of items returned: $($response.value.Count)."
        }
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            Write-Verbose "[$functionName] Status code: $statusCode"
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
        }
    }
    catch
    {
        if ($null -eq $_.Exception.statusCode)
        {
            $statusCode = [regex]::Match($_.Exception.Message, '\d+').Value
            Write-Verbose "[$functionName] Status code: $statusCode"
            $statusCodeMessage = $_.Exception | Out-String
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
            $statusMessage = $statusCodeMessage
        }
        else
        {
            $statusCode = $_.Exception.statuscode.value__
            $statusCodeMessage = $_.Exception.statuscode
            $statusMessage = $_.Exception.Message
        }
        switch ($statusCode)
        {
            400
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Not found. The resource does not exist.' -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message below.' -ForegroundColor Red 
                Write-Host "Error: $statusMessage" -ForegroundColor Red
                Write-Host "The status code is $statusCode"
                Write-Host "$statusCode indicates $statusCodeMessage"
                Write-Host "Status message: $statusMessage"
                Write-Host 'The full error message follows below:'
                Write-Host '----------------------------------------------------------'
                Write-Host "$_"
                if ($_.Exception.Response)
                {
                    $errorResponse = $_.Exception.Response.GetResponseStream()
                    $streamReader = New-Object System.IO.StreamReader($errorResponse)
                    $errorMessage = $streamReader.ReadToEnd()
                    $streamReader.Close()
                    Write-Error "Server Response: $errorMessage"
                }   
            }
        }
        Write-Verbose "[$functionName] Failed to call the Graph API: $_"
        Write-Verbose "[$functionName] The status code is $statusCode"
        Write-Verbose "[$functionName] $statusCode indicates $statusCodeMessage"
        Write-Verbose "[$functionName] Status message: $statusMessage"
        Write-Verbose "[$functionName] The full error message follows below:"
        Write-Verbose "[$functionName] ----------------------------------------------------------"
        Write-Verbose "[$functionName] Error: $($_)"
        Write-Verbose "[$functionName] Exception message: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Exception response: $($_.Exception.Response)"
        if ($_.Exception.Response -and $psversionTable.PSVersion.Major -ge 7)
        {
            {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Verbose "[$functionName] Server Response: $errorMessage"
            }   
        }
        return $statusCode
        # return $null
    }
    Write-Verbose "[$functionName] Response: $($response)"
    Write-Verbose "[$functionName] Response value: $($response.value)"
    return $response
}

