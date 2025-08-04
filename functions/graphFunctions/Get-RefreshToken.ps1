function Get-RefreshToken()
{
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
    Write-Verbose "[$functionName] Attempting to use refresh token to get a new access token"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting to use refresh token to get a new access token" -LogLevel "Information"
    try
    {
        # First test if the refresh token is valid
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $accessTokenObject.refresh_token -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
        if (-not $isValid)
        {
            Write-Verbose "[$functionName] Refresh token is invalid or expired. Cannot proceed with token refresh."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Refresh token is invalid or expired. Cannot proceed with token refresh." -LogLevel "Error"
            return $null
        }
        Write-Verbose "[$functionName] Refresh token is valid. Proceeding to get new access token."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Refresh token is valid. Proceeding to get new access token." -LogLevel "Information"
        $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $tokenResponse.refresh_token
        # Cache the access token based on cache type
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        # Only save the refresh token if it's different from the one we already have
        Write-Verbose "[$functionName] Checking whether to save the refresh token..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether to save the refresh token..." -LogLevel "Verbose"
        if ($tokenResponse.refresh_token -and $tokenResponse.refresh_token -ne $accessTokenObject.refresh_token)
        {
            Write-Verbose "[$functionName] Saving new refresh token as it differs from the existing one."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Saving new refresh token as it differs from the existing one." -LogLevel "Verbose"
            Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
        }
        else
        {
            Write-Verbose "[$functionName] No need to save refresh token as it hasn't changed."
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