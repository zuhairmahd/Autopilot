function Invoke-TokenRefresh()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject,
        [bool]$delegated,
        [string]$configRefreshToken,
        [string]$clientId,
        [string]$clientSecret,
        [string]$tenantId,
        [string[]]$scopes,
        [string]$domain,
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$cacheFolder,
        [string]$configFilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $delegated)
    {
        Write-Verbose "[$functionName] Not using delegated authentication, skipping refresh token logic"
        return $null
    }
    
    # Try cached refresh token first
    if ($accessTokenObject.refresh_token)
    {
        Write-Verbose "[$functionName] Attempting to refresh token using cached refresh token"
        return Get-RefreshToken -accessTokenObject $accessTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    # Try config refresh token as fallback
    if ($configRefreshToken)
    {
        Write-Verbose "[$functionName] Attempting to refresh token using config refresh token"
        $refreshTokenObject = @{ refresh_token = $configRefreshToken }
        return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    Write-Verbose "[$functionName] No refresh token available for token refresh"
    return $null
}

