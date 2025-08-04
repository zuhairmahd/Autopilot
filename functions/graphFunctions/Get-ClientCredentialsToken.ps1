function Get-ClientCredentialsToken()
{
    param($tenantId, $clientId, $clientSecret, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $secureString)
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Using non-delegated access..."
    Write-Verbose "[$functionName] Requesting new access token with client credentials flow"
    $body = @{
        client_id     = $clientId
        scope         = 'https://graph.microsoft.com/.default'
        client_secret = $clientSecret
        grant_type    = 'client_credentials'
    }
    Write-Verbose "[$functionName] Token request body: client_id=$clientId, scope=https://graph.microsoft.com/.default, grant_type=client_credentials"
    try
    {
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        Write-Verbose "[$functionName] Sending request to token endpoint: $tokenEndpoint"
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorVariable restError
        Write-Verbose "[$functionName] Access token received successfully" 
        Write-Verbose "[$functionName] Token expires in: $($tokenResponse.expires_in) seconds"
        $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain
        # Cache the token
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $secureString
    }
    catch
    {
        Write-Error "Failed to get access token: $_"
            
        if ($restError)
        {
            Write-Verbose "[$functionName] Error details: $($restError | Out-String)"
        }
            
        if ($_.Exception.Response)
        {
            Write-Verbose "[$functionName] Status code: $($_.Exception.Response.StatusCode)"
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorMessage = $streamReader.ReadToEnd()
            $streamReader.Close()
            Write-Error "Server Response: $errorMessage"
            
            try
            {
                $errorJson = $errorMessage | ConvertFrom-Json
                Write-Verbose "[$functionName] Error code: $($errorJson.error)"
                Write-Verbose "[$functionName] Error description: $($errorJson.error_description)"
            }
            catch
            {
                Write-Verbose "[$functionName] Could not parse error message as JSON: $_"
            }
        }
        return $null
    }
}

