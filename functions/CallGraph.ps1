function CallGraph()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$uri,
        [string]$method = 'get',
        [switch]$cl
    )
    
    Write-Verbose "AccessToken: $accessToken"
    Write-Verbose "Uri: $uri"
    Write-Verbose "Method: $method"
    Write-Verbose "Consistency Level: $cl"
#Check if the URL has a filter, and if so, urlencode it.
    if ($uri -match '\?filter=')
    {
        Write-Verbose "Uri has a filter: $uri"
        Write-Verbose "Encoding the filter value."
        $uri = $uri -replace '\?filter=', '?filter=' + [System.Web.HttpUtility]::UrlEncode($uri.Split('?filter=')[1])
        Write-Verbose "Encoded Uri: $uri"
    }
    if ($cl) 
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
    Write-Host "Making the following call to the Url: $uri"
    $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
    Write-Verbose "Response: $response"
    Write-Verbose "Response value: $($response.value)"
    return $response
}

