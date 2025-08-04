function Get-TokenFromResponse()
{
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

