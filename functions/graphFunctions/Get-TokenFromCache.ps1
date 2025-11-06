function Get-TokenFromCache()
{
    [CmdletBinding()]
    param(
        [ValidateSet('file', 'memory')]
        [string]$cacheType,
        [string]$domain,
        [int]$renewalLeadTime,
        [string]$clientId,
        [string]$clientSecret,
        [string]$tenantId,
        [string[]]$scopes,
        [bool]$delegated,
        [string]$cacheFolder,
        [string]$cacheTokenFile,
        [bool]$secureString,
        [string]$configFilePath,
        [string]$configRefreshToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting token cache retrieval for domain: $domain"
    Write-Verbose "[$functionName] Cache type: $cacheType, Delegated: $delegated"
    
    # Calculate time buffer for token renewal
    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
    Write-Verbose "[$functionName] Token renewal buffer time: $timeBuffer"
    
    # Get cached token object based on cache type
    $accessTokenObject = Get-CachedTokenObject -cacheType $cacheType -cacheTokenFile $cacheTokenFile -domain $domain 
    
    # If we have a cached token, validate and return it
    if ($accessTokenObject)
    {
        $validToken = Test-CachedTokenValidity -accessTokenObject $accessTokenObject -timeBuffer $timeBuffer -domain $domain -cacheType $cacheType -requestedScopes $scopes
        if ($validToken)
        {
            return $validToken
        }
        
        # Token is expired, try to refresh it
        $refreshedToken = Invoke-TokenRefresh -accessTokenObject $accessTokenObject -delegated $delegated -configRefreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath 
        if ($refreshedToken)
        {
            return $refreshedToken
        }
    }
    
    # No cached token found, try config refresh token as fallback
    if ($delegated -and $configRefreshToken)
    {
        Write-Verbose "[$functionName] No valid cached token found, attempting to use config refresh token"
        $refreshTokenObject = @{ refresh_token = $configRefreshToken }
        return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    Write-Verbose "[$functionName] No valid token found in cache or config"
    return $null
}

