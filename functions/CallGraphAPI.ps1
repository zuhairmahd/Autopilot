# Helper function to process a single filter condition
function ProcessFilterCondition
{
    [CmdletBinding()]
    param(
        [string]$condition
    )

    Write-Verbose "Processing filter condition: $condition"
    # Check if this is a function-based filter (contains, startswith, endswith)
    Write-Verbose "Checking for function-based filter..."
    if ($condition -match '(startswith|contains|endswith)\s*\(([^,]+),\s*([^)]+)\)')
    {
        Write-Verbose "Found function-based filter: $($Matches[1])"
        $filterOperator = $Matches[1]
        Write-Verbose "Filter Operator: $filterOperator"
        $filterKey = $Matches[2].Trim()
        Write-Verbose "Filter Key: $filterKey"
        $filterValue = $Matches[3].Trim()
        Write-Verbose "Filter Value: $filterValue"
        # Remove quotes if present in the value
        Write-Verbose "Removing quotes from filter value..."
        $filterValue = $filterValue -replace "^'|'$", ""
        Write-Verbose "Filter Value after removing double quotes: $filterValue"
        $filterValue = $filterValue -replace '^"|"$', ""
        Write-Verbose "Filter Value after removing single quotes: $filterValue"
        Write-Verbose "Filter Key after removing quotes: $FilterKey"
        Write-Verbose "Filter Value: $FilterValue"
        Write-Verbose "Filter Operator: $FilterOperator"
        $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
        Write-Verbose "Encoded Filter Value: $encodedFilterValue"
        # Rebuild the function call with encoded value
        $returnFilter = "$filterOperator($filterKey,'$encodedFilterValue')"
        Write-Verbose "Returning filter: $returnFilter"
        return $returnFilter
    }
    # Check for standard comparison operators
    elseif ($condition -match '([^\s]+)\s+(eq|ne|gt|lt|ge|le)\s+(.+)')
    {
        Write-Verbose "Not a function based filter. Checking for standard comparison operators..."
        $filterKey = $Matches[1].Trim()
        $filterOperator = $Matches[2].Trim()
        $filterValue = $Matches[3].Trim()
        Write-Verbose "Filter Key: $FilterKey"
        Write-Verbose "Filter Operator: $FilterOperator"
        Write-Verbose "Filter Value: $FilterValue"
        # Special handling for null and empty string
        Write-Verbose "Checking for null or empty string..."
        if ($filterValue -eq "null" -or $filterValue -eq "''" -or $filterValue -eq '""')
        {
            Write-Verbose "Filter value is null or empty string."
            Write-Verbose "Returning filter without encoding: $filterKey $filterOperator $filterValue"
            # Don't encode null or empty string values
            return "$filterKey $filterOperator $filterValue"
        }
        else
        {
            # Remove quotes if present
            Write-Verbose "Checking for quotes and removing from value if present..."
            Write-Verbose "Value before processing: $filterValue"
            $filterValue = $filterValue -replace "^'|'$", ""
            Write-Verbose "Value after removing double quotes: $filterValue"
            $filterValue = $filterValue -replace '^"|"$', ""
            Write-Verbose "Value after removing single quotes: $filterValue"
            Write-Verbose "Filter Key: $FilterKey"
            Write-Verbose "Filter Value: $FilterValue"
            $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
            Write-Verbose "Encoded Filter Value: $encodedFilterValue"
            # Add quotes back for the encoded value
            $returnFilter = "$filterKey $filterOperator '$encodedFilterValue'"
            Write-Verbose "Returning filter: $returnFilter"
            return $returnFilter
        }
    }
    else
    {
        Write-Verbose "Unrecognized filter condition format: $condition"
        return $condition
    }
}

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
    if ($accessToken)
    {
        Write-Verbose "Access token provided."
    }
    else
    {
        Write-Host 'Access token not provided. Please provide a valid access token.' -ForegroundColor Red
        return
    }
    Write-Verbose "Resource Path: $ResourcePath"
    Write-Verbose "Method: $method"
    Write-Verbose "Filter: $filter"
    Write-Verbose "Extra Parameters: $ExtraParameters"
    Write-Verbose "Version: $APIVersion"
    Write-Verbose "Consistency Level: $consistencyLevel"
    Write-Verbose "Body: $body"
    Write-Verbose "SecureString: $secureString"
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    Write-Verbose "Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose "Processing filter string: $Filter"
        Write-Verbose "Splitting filter by logical operators while preserving operators."
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
        Write-Verbose "Found $($logicalOperaterMatches.Count) logical operators."
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
            Write-Verbose "No logical operators found. Processing as a single filter condition."
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Verbose "Processed single filter condition: $processedFilter"
            $encodedFilter = $processedFilter
            Write-Verbose "Encoded filter: $encodedFilter"
        }
        else
        {
            # Process each part of the filter
            Write-Verbose "Logical operators found. Processing filter as multiple conditions."
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
                Write-Verbose "Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))"
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Verbose "Condition to process: $condition"
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "Processed filter condition: $($filterParts[$filterParts.Count - 1])"
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Verbose "Logical operators so far: $($logicalOperators -join ', ')"
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
                Write-Verbose "Processing filter condition after the last logical operator."
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "Processed filter condition: $($filterParts[$filterParts.Count - 1])"
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Verbose "Rebuilding the filter string with processed parts and logical operators."
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Verbose "Adding logical operator: $($logicalOperators[$i])"
            }
            Write-Verbose "Processed complex filter: $encodedFilter"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Verbose "Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Verbose 'No filter provided.'
        $encodedUri = $uri
    }
    
    if ($extraParameters)
    {
        Write-Verbose "Extra parameters provided."
        Write-Verbose "Splitting the extra parameters by ampersand to get individual key-value pairs."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Verbose "Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Verbose "Processing key-value pair: $pair"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Verbose "Key: $key"
                Write-Verbose "Value: $value"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Verbose "Formatted Key with $ prefix: $formattedKey"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
            }
        }
        Write-Verbose "Final parameter list:"
        $paramsList | ForEach-Object { Write-Verbose $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Verbose "Final query string: $queryString"
        if ($filter) 
        {
            Write-Verbose "Adding extra parameters to the uri along with the filter."
            $encodedUri = "$encodedUri`&$queryString"
        }
        else
        {
            Write-Verbose "No filter provided. Adding extra parameters to the uri."
            $encodedUri = "$encodedUri`?$queryString"
        }
    }
    else
    {
        Write-Verbose 'No extra parameters provided.'
    }
    if ($consistencyLevel)
    {
        Write-Verbose 'Adding consistency level to the headers.'
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Verbose 'No consistency level provided.'
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    # Create parameter hashtable for splatting
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        $restParams['Body'] = $body
    }
    #endregion
    Write-Verbose "Making the following call to Microsoft Graph:" 
    Write-Verbose "URI: $encodedUri." 
    Write-Verbose "Method: $method."
    try
    {
        $response = Invoke-RestMethod @restParams
        $response | ForEach-Object {
            if ($_.'@odata.nextLink')
            {
                $nextLink = $_.'@odata.nextLink'
                # $nextGroups = CallGraphAPI -accessToken $accessToken -ResourcePath $nextLink -Method GET
                $nextGroups = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing 
                $response.value += $nextGroups.value
            }
        }
        Write-Verbose 'The call was successful.'
        if ($response.count)
        {
            Write-Verbose "Number of objects returned: $($response.count)."
        }
        if ($response.value.Count)
        {
            Write-Verbose "Number of items returned: $($response.value.Count)."
        }
    }
    catch
    {
        if ($null -eq $_.Exception.statusCode)
        {
            $statusCode = [regex]::Match($_.Exception.Message, '\d+').Value
            Write-Verbose "Status code: $statusCode"
            $statusCodeMessage = $_.Exception | Out-String
            Write-Verbose "Status code message: $statusCodeMessage"
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
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401
            {
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Verbose "Status code: $statusCode"
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Verbose "Status code: $statusCode"
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
        Write-Verbose "Failed to call the Graph API: $_"
        Write-Verbose "Error: $statusMessage"
        Write-Verbose "The status code is $statusCode"
        Write-Verbose "$statusCode indicates $statusCodeMessage"
        Write-Verbose "Status message: $statusMessage"
        Write-Verbose 'The full error message follows below:'
        Write-Verbose '----------------------------------------------------------'
        Write-Verbose "$_"
        if ($_.Exception.Response)
        {
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorMessage = $streamReader.ReadToEnd()
            $streamReader.Close()
            Write-Verbose "Server Response: $errorMessage"
        }   
        return $statusCode
    }
    Write-Verbose "Response: $($response)"
    Write-Verbose "Response value: $($response.value)"
    return $response
}



