function CallGraphAPI() {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$uri,
        [string]$method = 'get',
        [string]$filter = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    if ($accessToken) {
        Write-Verbose "Access token provided."
    }
    Write-Verbose "Uri: $uri"
    Write-Verbose "Method: $method"
    Write-Verbose "Filter: $filter"
    Write-Verbose "Consistency Level: $consistencyLevel"
    Write-Verbose "SecureString: $secureString"
    #endregion

    #region Encode filter and add headers
    if ($Filter) {
        Write-Verbose 'Encoding the filter value.'
        $encodedFilter = [uri]::EscapeDataString($filter)
        if ($uri -notmatch '\?') {
            $uri += "?`$filter=$encodedFilter"
        }
        else {
            $uri += "&`$filter=$encodedFilter"
        }
        Write-Verbose "Uri: $uri"
    }
    if ($consistencyLevel) {
        Write-Verbose 'Adding consistency level to the headers.'
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else {
        Write-Verbose 'No consistency level provided.'
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion
    Write-Verbose "Making the following call to the Url: $uri with the method: $method."
    try {
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -UseBasicParsing 
        $response | ForEach-Object {
            if ($_.'@odata.nextLink') {
                $nextLink = $_.'@odata.nextLink'
                $nextGroups = CallGraphAPI -accessToken $accessToken -Uri $nextLink -Method GET
                $response.value += $nextGroups.value
            }
        }
        Write-Verbose 'The call was successful.'
        Write-Verbose "Number of objects: $($response.Count)"
        Write-Verbose "Number of items in each object: $($response.value.Count)"
    }
    catch {
        if ($null -eq $_.Exception.statusCode) {
            $statusCode = [regex]::Match($_.Exception.Message, '\d+').Value
            Write-Verbose "Status code: $statusCode"
            $statusCodeMessage = $_.Exception | Out-String
            Write-Verbose "Status code message: $statusCodeMessage"
            $statusMessage = $statusCodeMessage
        }
        else {
            $statusCode = $_.Exception.statuscode.value__
            $statusCodeMessage = $_.Exception.statuscode
            $statusMessage = $_.Exception.Message
        }
        switch ($statusCode) {
            400 {
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401 {
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403 {
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404 {
                Write-Host 'Not found. The resource does not exist.' -ForegroundColor Red 
            }
            default {
                Write-Host 'An unknown error occurred. Please check the error message below.' -ForegroundColor Red 
            }
        }
        Write-Host "Error: $statusMessage" -ForegroundColor Red
        Write-Host "The status code is $statusCode"
        Write-Host "$statusCode indicates $statusCodeMessage"
        Write-Host "Status message: $statusMessage"
        Write-Host 'The full error message follows below:'
        Write-Host '----------------------------------------------------------'
        Write-Host "$_"
        $response = $statusCode
        return $response
    }
    Write-Verbose "Response value: $($response.value)"
    return $response
}



