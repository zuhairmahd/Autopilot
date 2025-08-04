function Test-RefreshTokenValidity()
{
    param(
        $refreshToken,
        $clientId,
        $clientSecret,
        $tenantId,
        $scopes,
        $domain,
        $AuthType
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write verbose and log the function name and parameters
    Write-Verbose "[$functionName] Testing refresh token validity with parameters:clientId=$clientId, tenantId=$tenantId, domain=$domain, AuthType=$AuthType"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Testing refresh token validity with parameters: refreshToken=$refreshToken, clientId=$clientId, tenantId=$tenantId, scopes=$scopes, domain=$domain, AuthType=$AuthType"
    try
    {
        # Ensure scopes are properly formatted for the token refresh
        $scopesFormatted = $scopes
        if ($scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
        {
            Write-Verbose "[$functionName] Scopes provided, formatting them for token refresh"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Scopes provided, formatting them for token refresh" -LogLevel "Verbose"
            $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
            $formattedScopesArray = @()
            foreach ($scope in $scopesArray)
            {
                if ($scope -eq "offline_access")
                {
                    $formattedScopesArray += $scope
                }
                else
                {
                    $formattedScopesArray += "https://graph.microsoft.com/$scope"
                }
            }
            $scopesFormatted = $formattedScopesArray -join ' '
        }
        $refreshTokenRequestBody = @{
            client_id     = $clientId
            refresh_token = $refreshToken
            grant_type    = 'refresh_token'
            scope         = $scopesFormatted
        }
        if ($auth.AuthType -eq 'PublicAuthFlow')
        {
            Write-Verbose "[$functionName] Public authentication flow detected, client secret will not be included in the request"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Public authentication flow detected, client secret will not be included in the request" -LogLevel "Verbose"
        }
        else
        {
            Write-Verbose "[$functionName] Non-public authentication flow detected, client secret will be included in the request"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Non-public authentication flow detected, client secret will be included in the request" -LogLevel "Verbose"
            $refreshTokenRequestBody.Add('client_secret', $clientSecret)
        }
        $refreshTokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        Write-Verbose "[$functionName] Attempting to validate refresh token by getting a new access token.."
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $refreshTokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $refreshTokenRequestBody
        Write-Verbose "[$functionName] Refresh token is valid. Successfully obtained a new access token."
        return $true, $tokenResponse
    }
    catch
    {
        Write-Verbose "[$functionName] Refresh token validation failed: $_"
        Write-Verbose "[$functionName] Refresh token appears to be invalid or expired."
        return $false, $null
    }
}

