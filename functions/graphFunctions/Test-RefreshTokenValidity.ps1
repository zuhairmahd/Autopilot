function Test-RefreshTokenValidity()
{
    <#
    .SYNOPSIS
    Tests if a refresh token is valid by attempting to use it to acquire a new access token.

    .DESCRIPTION
    This function validates an OAuth refresh token by making a token refresh request to Azure AD.
    It formats scopes appropriately, constructs the token refresh request body, attempts token
    acquisition, and returns validation status with detailed error information. The function
    determines if a refresh token can still be used or if re-authentication is required.

    .PARAMETER refreshToken
    The OAuth refresh token to validate.

    .PARAMETER clientId
    The application (client) ID.

    .PARAMETER clientSecret
    Optional client secret for confidential client applications.

    .PARAMETER tenantId
    The Azure AD tenant ID.

    .PARAMETER scopes
    Space-separated string of Microsoft Graph permission scopes.

    .PARAMETER domain
    The domain name for logging context.

    .PARAMETER AuthType
    Authentication type for logging context.

    .OUTPUTS
    System.Collections.Hashtable
    Returns hashtable with properties:
    - IsValid: Boolean indicating if refresh token is valid
    - AccessToken: New access token if validation successful
    - RefreshToken: New refresh token if provided in response
    - ExpiresIn: Token expiration time in seconds
    - Error: Error message if validation failed

    .EXAMPLE
    $result = Test-RefreshTokenValidity -refreshToken $rt -clientId $cid -tenantId $tid -scopes $scopeString
    if ($result.IsValid) {
        $newToken = $result.AccessToken
    }

    .NOTES
    Formats scopes with https://graph.microsoft.com/ prefix if needed.
    Handles offline_access scope specially (no prefix).
    Makes actual token refresh request to validate.
    Returns detailed error information for troubleshooting.
    Does not save the new refresh token - caller must handle.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
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

