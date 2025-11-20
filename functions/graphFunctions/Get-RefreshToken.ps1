function Get-RefreshToken()
{
    <#
    .SYNOPSIS
    Refreshes an expired access token using a refresh token.

    .DESCRIPTION
    This function uses a refresh token to obtain a new access token from Microsoft Graph.
    It validates the refresh token, requests a new access token, caches the result, and
    optionally saves the new refresh token if it has changed. The function supports both
    file and memory caching strategies.

    .PARAMETER accessTokenObject
    The current access token object containing the refresh token.

    .PARAMETER clientId
    The Azure AD application (client) ID.

    .PARAMETER clientSecret
    The Azure AD application client secret (optional for delegated flows).

    .PARAMETER tenantId
    The Azure AD tenant ID.

    .PARAMETER scopes
    Array of permission scopes for the new token.

    .PARAMETER domain
    The domain/tenant identifier for cache key generation.

    .PARAMETER cacheType
    The cache storage type: 'file' or 'memory'.

    .PARAMETER cacheTokenFile
    Path to the cache token file (for file-based caching).

    .PARAMETER cacheFolder
    Path to the cache folder (for file-based caching).

    .PARAMETER configFilePath
    Path to configuration file for saving refresh tokens.

    .OUTPUTS
    System.String or System.Security.SecureString
    Returns the new access token, or $null if refresh fails.

    .EXAMPLE
    $newToken = Get-RefreshToken -accessTokenObject $tokenObj -clientId $appId -tenantId $tenant -scopes $scopes -domain $domain -cacheType 'file' -cacheTokenFile $cachePath -cacheFolder $folder -configFilePath $configPath

    .NOTES
    Validates refresh token before attempting refresh.
    Saves new refresh token only if it differs from the existing one.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$accessTokenObject,
        [Parameter(Mandatory = $true)]
        [string]$clientId,
        [string]$clientSecret,
        [Parameter(Mandatory = $true)]
        [string]$tenantId,
        [string[]]$scopes,
        [Parameter(Mandatory = $true)]
        [string]$domain,
        [ValidateSet('file', 'memory')]
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$cacheFolder,
        [string]$configFilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting to use refresh token to get a new access token" -LogLevel "Verbose"
    try
    {
        # First test if the refresh token is valid
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $accessTokenObject.refresh_token -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
        if (-not $isValid)
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Refresh token is invalid or expired. Cannot proceed with token refresh." -LogLevel "Warning"
            return $null
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Refresh token is valid. Proceeding to get new access token." -LogLevel "Information"
        $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $tokenResponse.refresh_token
        # Cache the access token based on cache type
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        # Only save the refresh token if it's different from the one we already have
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether to save the refresh token..." -LogLevel "Verbose"
        if ($tokenResponse.refresh_token -and $tokenResponse.refresh_token -ne $accessTokenObject.refresh_token)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Saving new refresh token as it differs from the existing one." -LogLevel "Verbose"
            Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
        }
        else
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No need to save refresh token as it hasn't changed." -LogLevel "Verbose"
        }
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
    }
    catch
    {
        Write-Host "Failed to use refresh token: $_. Will request new authorization."
        Write-Host "Refresh token might be expired or revoked, proceeding with new authorization."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to use refresh token: $_. Will request new authorization." -LogLevel "Error"
        return $null
    }
}