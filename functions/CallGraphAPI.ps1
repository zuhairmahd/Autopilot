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
    Write-Verbose "SecureString: $secureString"
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    Write-Verbose "Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose "Seperating the filter into key, operator and value."
        #if the filter contains operators such as eq, ne, gt, lt, ge, le, etc. then split the filter into key, operator and value.
        if ($Filter -match 'startswith\(|contains\(|endswith\(')
        {
            Write-Verbose "Processing function-based filter (e.g., startswith, contains, endswith)."
            #get the values between parenthesis and split them into key and value.
            $filterParts = $Filter -replace '.*\((.*)\)', '$1' -split ','
            $FilterKey = $filterParts[0].Trim()
            $FilterValue = $filterParts[1].Trim()
            #the filter operater is what is before the first parenthesis.
            $FilterOperator = $Filter -replace '\s*\(.*', ''
            Write-Verbose "Filter Key: $FilterKey"
            Write-Verbose "Filter Value: $FilterValue"
            Write-Verbose "Filter Operator: $FilterOperator"
            $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
            Write-Verbose "Encoded Filter Value: $encodedFilterValue"
            #build the uri.
            $encodedUri = "$uri`?`$filter=$FilterOperator($FilterKey,$encodedFilterValue)"
        }
        else
        {
            Write-Verbose "Processing standard filter with operators (e.g., eq, ne, gt, lt)."
            $filterParts = $Filter -split '\s+(eq|ne|gt|lt|ge|le)\s+'
            $FilterKey = $filterParts[0].Trim()
            $FilterOperator = $filterParts[1].Trim()
            $FilterValue = $filterParts[2].Trim()
            Write-Verbose "Filter Key: $FilterKey"
            Write-Verbose "Filter Operator: $FilterOperator"
            Write-Verbose "Filter Value: $FilterValue"
            $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
            Write-Verbose "Encoded Filter Value: $encodedFilterValue"
            $encodedUri = "$uri`?`$filter=$FilterKey $FilterOperator $encodedFilterValue"
        }
        Write-Verbose "Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Verbose 'No filter provided.'
        $encodedUri = $uri
    }
    if ($extraParameters)
    {
        Write-Host "Extra parameters provided."
        Write-Host "Splitting the extra parameters by ampersand to get individual key-value pairs."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Host "Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Host "Processing key-value pair: $pair"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Host "Key: $key"
                Write-Host "Value: $value"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Host "Formatted Key with $ prefix: $formattedKey"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
            }
        }
        Write-Host "Final parameter list:"
        $paramsList | ForEach-Object { Write-Host $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Host "Final query string: $queryString"
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
    #endregion
    Write-Verbose "Making the following call to Microsoft Graph:" 
    Write-Verbose "URI: $encodedUri." 
    Write-Verbose "Method: $method."
    try
    {
        $response = Invoke-RestMethod -Method $method -Uri $encodedUri -Headers $headers -UseBasicParsing 
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
            }
        }
        Write-Error "Failed to call the Graph API: $_"
        if ($_.Exception.Response)
        {
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorMessage = $streamReader.ReadToEnd()
            $streamReader.Close()
            Write-Error "Server Response: $errorMessage"
        }   
        return $statusCode
    }
    if ($response.value.Count -eq 0 -and $null -eq $response.count)
    {
        Write-Verbose "Response value: $($response |Out-String)"
    }
    else
    {
        Write-Verbose "Response value: $($response.value)"
    }
    return $response
}



