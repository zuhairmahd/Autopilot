function Get-TokenFromCache()
{
    <#
    .SYNOPSIS
    Retrieves a valid access token from cache or refreshes an expired token.

    .DESCRIPTION
    This function attempts to retrieve a cached access token for the specified domain. It validates
    the cached token's expiry time considering a renewal lead time buffer. If the token is expired,
    it attempts to refresh it using the refresh token. The function supports both file and memory
    caching strategies and handles both delegated and application authentication flows.

    .PARAMETER cacheType
    The cache storage type: 'file' or 'memory'.

    .PARAMETER domain
    The domain/tenant identifier for cache key generation.

    .PARAMETER renewalLeadTime
    Time buffer in minutes before token expiry to trigger renewal.

    .PARAMETER clientId
    The Azure AD application (client) ID.

    .PARAMETER clientSecret
    The Azure AD application client secret (for application flows).

    .PARAMETER tenantId
    The Azure AD tenant ID.

    .PARAMETER scopes
    Array of permission scopes for token validation.

    .PARAMETER delegated
    Boolean indicating if using delegated authentication flow.

    .PARAMETER cacheFolder
    Path to the cache folder (for file-based caching).

    .PARAMETER cacheTokenFile
    Path to the cache token file (for file-based caching).

    .PARAMETER secureString
    Boolean indicating if token should be returned as SecureString.

    .PARAMETER configFilePath
    Path to configuration file for refresh token operations.

    .PARAMETER configRefreshToken
    Refresh token from configuration (for delegated flows).

    .OUTPUTS
    System.String or System.Security.SecureString
    Returns a valid access token if available in cache or successfully refreshed, otherwise $null.

    .EXAMPLE
    $token = Get-TokenFromCache -cacheType 'file' -domain 'contoso.com' -renewalLeadTime 5 -clientId $appId -tenantId $tenant -scopes $scopes -delegated $true -cacheFolder $folder -cacheTokenFile $file -secureString $false -configFilePath $config

    .NOTES
    Automatically handles token expiry and refresh logic.
    Supports both file and memory caching.
    Compatible with PowerShell 5.1.
    #>
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
    write-log -logFile $logFile -Module $functionName -Message "Starting token cache retrieval for domain: $domain, Cache type: $cacheType, Delegated: $delegated"
    # Calculate time buffer for token renewal
    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
    Write-Verbose "[$functionName] Token renewal buffer time: $timeBuffer"
    write-log -logFile $logFile -Module $functionName -Message "Token renewal buffer time: $timeBuffer"
    # Get cached token object based on cache type
    $accessTokenObject = Get-CachedTokenObject -cacheType $cacheType -cacheTokenFile $cacheTokenFile -domain $domain 
    
    # If we have a cached token, validate and return it
    if ($accessTokenObject)
    {
        Write-Verbose "[$functionName] Cached token object found, validating token" 
        write-log -logFile $logFile -Module $functionName -Message "Cached token object found, validating token"            
        $validToken = Test-CachedTokenValidity -accessTokenObject $accessTokenObject -timeBuffer $timeBuffer -domain $domain -cacheType $cacheType -requestedScopes $scopes
        if ($validToken)
        {
            Write-Verbose "[$functionName] Valid cached token found, returning token"
            write-log -logFile $logFile -Module $functionName -Message "Valid cached token found, returning token"              
            return $validToken
        }
        
        # Token is expired, try to refresh it
        $refreshedToken = Invoke-TokenRefresh -accessTokenObject $accessTokenObject -delegated $delegated -configRefreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath 
        if ($refreshedToken)
        {
            Write-Verbose "[$functionName] Token refreshed successfully, returning refreshed token"     
            write-log -logFile $logFile -Module $functionName -Message "Token refreshed successfully, returning refreshed token"
            return $refreshedToken
        }
    }
    
    # No cached token found, try config refresh token as fallback
    if ($delegated -and $configRefreshToken)
    {
        Write-Verbose "[$functionName] No valid cached token found, attempting to use config refresh token"
        write-log -logFile $logFile -Module $functionName -Message "No valid cached token found, attempting to use config refresh token"                    
        $refreshTokenObject = @{ refresh_token = $configRefreshToken }
        return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    Write-Verbose "[$functionName] No valid token found in cache or config"
    write-log -logFile $logFile -Module $functionName -Message "No valid token found in cache or config"                                    
    return $null
}

