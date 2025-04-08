function CallGraphAPI()
{
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
    Write-Verbose "AccessToken: $accessToken"
    Write-Verbose "Uri: $uri"
    Write-Verbose "Method: $method"
    Write-Verbose "Filter: $filter"
    Write-Verbose "Consistency Level: $cl"
    Write-Verbose "SecureString: $secureString"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose 'Encoding the filter value.'
        $Filter = [System.Web.HttpUtility]::UrlEncode($filter)
        $uri += "?`$filter=$Filter"
        Write-Verbose "Uri: $uri"
    }
    if ($consistencyLevel) 
    {
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion
    Write-Verbose "Making the following call to the Url: $uri"
    try
    {
        $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -StatusCodeVariable 'statusCode'
        $response | ForEach-Object {
            if ($_.'@odata.nextLink')
            {
                $nextLink = $_.'@odata.nextLink'
                $nextGroups = CallGraphAPI -accessToken $accessToken -Uri $nextLink -Method GET
                $response.value += $nextGroups.value
            }
        }
        Write-Verbose "The status code is $statusCode"
        Write-Verbose 'The call was successful.'
        Write-Verbose "Number of objects: $($response.Count) objects."
        Write-Verbose "Number of items in each object: $($response.value.Count)"
    }
    catch
    {
        $statusCode = $_.Exception.statuscode.value__
        $statusCodeMessage = $_.Exception.statuscode
        $statusMessage = $_.Exception.Message
        switch ($statusCode)
        {
            400
            {
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401
            {
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Host 'Not found. The resource does not exist.' -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message below.' -ForegroundColor Red 
            }
        }
        Write-Host "Error: $statusMessage" -ForegroundColor Red
        Write-Host "The status code is $statusCode"
        Write-Host "$statusCode indicates $statusCodeMessage"
        Write-Host "The status message is $statusMessage"
        Write-Host 'The full error message follows below:'
        Write-Host '----------------------------------------------------------'
        Write-Host "$_"
    }
    Write-Verbose "Response value: $($response.value)"
    return $response
}



