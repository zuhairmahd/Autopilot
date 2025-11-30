function Get-TokenFromResponse()
{
    <#
    .SYNOPSIS
    Constructs a cached token object from an OAuth token response.

    .DESCRIPTION
    This function processes an OAuth token response and creates a standardized cached token
    object with expiry time calculation, domain association, and optional refresh token and
    scope information. The resulting object is suitable for caching and token management.

    .PARAMETER tokenResponse
    The OAuth token response object containing access_token, expires_in, and optional refresh_token and scope.

    .PARAMETER domain
    The domain/tenant identifier to associate with the cached token.

    .PARAMETER refreshToken
    Optional refresh token to include in the cached token object.

    .OUTPUTS
    System.Collections.Specialized.OrderedDictionary
    Returns an ordered hashtable containing token data with calculated absolute expiry time.

    .EXAMPLE
    $cachedToken = Get-TokenFromResponse -tokenResponse $response -domain "contoso.com" -refreshToken $refreshToken

    .NOTES
    Calculates absolute expiry time from current time plus expires_in seconds.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param($tokenResponse, $domain, $refreshToken)
    $functionName = $MyInvocation.MyCommand.Name
    $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
    Write-Verbose "[$functionName] Token absolute expiry time: $($tokenExpiryTime)"
    $cachedToken = [ordered] @{
        'domain'           = $domain
        access_token       = $tokenResponse.access_token
        AbsoluteExpiryTime = $tokenExpiryTime
        'expires_in'       = $tokenResponse.expires_in
    }
        
    # Add refresh token if available
    if ($refreshToken -or $tokenResponse.refresh_token)
    {
        $cachedToken.Add('refresh_token', $tokenResponse.refresh_token)
    }
        
    # Add scope if available
    if ($tokenResponse.scope)
    {
        $cachedToken.Add('scope', $tokenResponse.scope)
    }
        
    return $cachedToken
}

