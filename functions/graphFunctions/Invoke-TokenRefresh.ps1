function Invoke-TokenRefresh()
{
    <#
    .SYNOPSIS
    Orchestrates token refresh using cached or configured refresh tokens.

    .DESCRIPTION
    This function manages the token refresh process for delegated authentication flows.
    It attempts to use a cached refresh token first, then falls back to a configured
    refresh token if available. The function only operates in delegated authentication mode.

    .PARAMETER accessTokenObject
    The current access token object potentially containing a cached refresh token.

    .PARAMETER delegated
    Boolean indicating if using delegated authentication flow.

    .PARAMETER configRefreshToken
    Refresh token from configuration file (fallback option).

    .PARAMETER clientId
    The Azure AD application (client) ID.

    .PARAMETER clientSecret
    The Azure AD application client secret (optional for delegated flows).

    .PARAMETER tenantId
    The Azure AD tenant ID.

    .PARAMETER scopes
    Array of permission scopes for the refreshed token.

    .PARAMETER domain
    The domain/tenant identifier for cache key generation.

    .PARAMETER cacheType
    The cache storage type: 'file' or 'memory'.

    .PARAMETER cacheTokenFile
    Path to the cache token file (for file-based caching).

    .PARAMETER cacheFolder
    Path to the cache folder (for file-based caching).

    .PARAMETER configFilePath
    Path to configuration file for refresh token operations.

    .OUTPUTS
    System.String or System.Security.SecureString
    Returns a refreshed access token if successful, otherwise $null.

    .EXAMPLE
    $token = Invoke-TokenRefresh -accessTokenObject $tokenObj -delegated $true -clientId $appId -tenantId $tenant -scopes $scopes -domain $domain -cacheType 'file' -cacheTokenFile $file -cacheFolder $folder -configFilePath $config

    .NOTES
    Only operates in delegated authentication mode.
    Tries cached refresh token before falling back to configured refresh token.
    Compatible with PowerShell 5.1.
    #>
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

