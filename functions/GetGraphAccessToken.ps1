function GetGraphAccessToken()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$configFile,
        [int]$renewalLeadTime = 5,
        [switch]$SecureString,
        [parameter(parameterSetName = 'Deligated')]
        [switch]$Deligated,
        [parameter(parameterSetName = 'Deligated')]
        [string]$Scopes,
        [switch]$ForceNewToken,
        [ValidateSet('file', 'memory')]
        [string]$CacheType = 'Memory'
    )
    
    #region Helper functions
    function Get-TokenFromResponse
    {
        param($tokenResponse, $domain, $refreshToken)
        
        $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
        Write-Verbose "Token absolute expiry time: $($tokenExpiryTime)"
        
        $cachedToken = [PSCustomObject] @{
            'domain'           = $domain
            access_token       = $tokenResponse.access_token
            AbsoluteExpiryTime = $tokenExpiryTime
            'expires_in'       = $tokenResponse.expires_in
        }
        
        # Add refresh token if available
        if ($refreshToken -or $tokenResponse.refresh_token)
        {
            $cachedToken | Add-Member -MemberType NoteProperty -Name 'refresh_token' -Value ($refreshToken ?? $tokenResponse.refresh_token)
        }
        
        # Add scope if available
        if ($tokenResponse.scope)
        {
            $cachedToken | Add-Member -MemberType NoteProperty -Name 'scope' -Value $tokenResponse.scope
        }
        
        return $cachedToken
    }
    
    function Save-TokenToCache
    {
        param($cachedToken, $cacheType, $cacheTokenFile, $cacheFolder)
        
        # Save access token according to cache type
        if ($cacheType -eq 'memory')
        {
            Write-Verbose "Saving access token to memory cache."
            $Global:MemoryCache['accessToken'] = $cachedToken
        }
        else
        {
            Write-Verbose "Saving access token to cache file: $cacheTokenFile"
            if (-not (Test-Path -Path $cacheFolder))
            {
                Write-Verbose "Creating cache folder: $cacheFolder"
                New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
            }
            $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
            Write-Verbose "Access token saved to $cacheTokenFile"
        }
    }
    
    function Save-RefreshTokenToConfig
    {
        param($refreshToken, $configFilePath)
        
        if (-not $refreshToken)
        {
            Write-Verbose "No refresh token to save"
            return
        }
        
        try
        {
            Write-Verbose "Saving refresh token to config file: $configFilePath"
            
            # Read the current config
            $config = Get-Content -Raw -Path $configFilePath | ConvertFrom-Json
            
            # Determine if the config is encrypted
            $isEncrypted = isEncrypted -data $config
            
            # Add or update the refresh_token property
            if ($isEncrypted)
            {
                Write-Verbose "Config is encrypted, decrypting before updating"
                $decryptedConfig = DecryptObject -encryptedObject $config -excludeFields 'domain'
                $decryptedConfig | Add-Member -MemberType NoteProperty -Name 'refresh_token' -Value $refreshToken -Force
                
                # Re-encrypt the config
                Write-Verbose "Re-encrypting config with refresh token"
                $updatedConfig = EncryptObject -object $decryptedConfig -excludeFields 'domain'
            }
            else
            {
                Write-Verbose "Config is not encrypted, updating directly"
                $config | Add-Member -MemberType NoteProperty -Name 'refresh_token' -Value $refreshToken -Force
                $updatedConfig = $config
            }
            
            # Save the updated config
            $updatedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -Force
            Write-Verbose "Refresh token saved to config file"
        }
        catch
        {
            Write-Error "Failed to save refresh token to config: $_"
        }
    }
    
    function Format-TokenOutput
    {
        param($token, $secureString)
        
        if ($secureString)
        {
            Write-Verbose "Converting access token to secure string"
            $secureAccessToken = ConvertTo-SecureString -String $token -AsPlainText -Force
            Write-Verbose "Returning secure token"
            return $secureAccessToken
        }
        else
        {
            Write-Verbose "Returning plain text access token"
            return $token
        }
    }
    
    function Get-RefreshToken
    {
        param(
            $accessTokenObject,
            $clientId,
            $clientSecret,
            $tenantId,
            $scopes,
            $domain,
            $cacheType,
            $cacheTokenFile,
            $cacheFolder,
            $configFilePath
        )
        
        Write-Host "Using refresh token to get a new access token..."
        try
        {
            $refreshTokenRequestBody = @{
                client_id     = $clientId
                client_secret = $clientSecret
                refresh_token = $accessTokenObject.refresh_token
                grant_type    = 'refresh_token'
                scope         = $Scopes
            }
            
            $refreshTokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $refreshTokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $refreshTokenRequestBody
            
            Write-Host "Successfully refreshed access token."
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $tokenResponse.refresh_token
            
            # Cache the access token based on cache type
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            
            # Always save the refresh token to the config file
            if ($tokenResponse.refresh_token)
            {
                Save-RefreshTokenToConfig -refreshToken $tokenResponse.refresh_token -configFilePath $configFilePath
            }
            
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
        catch
        {
            Write-Host "Failed to use refresh token: $_. Will request new authorization."
            Write-Host "Refresh token might be expired or revoked, proceeding with new authorization."
            return $null
        }
    }
    
    function Get-TokenFromCache
    {
        param(
            $cacheType,
            $domain,
            $renewalLeadTime,
            $clientId,
            $clientSecret,
            $tenantId,
            $scopes,
            $deligated,
            $cacheFolder,
            $cacheTokenFile,
            $secureString,
            $configFilePath,
            $configRefreshToken
        )
        
        $accessTokenObject = $null
        $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
        
        # Get token from memory cache
        if ($cacheType -eq 'memory')
        {
            Write-Verbose "Using memory cache for access token."
            if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
            {
                Write-Verbose "Initializing memory cache."
                New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
            }
            
            if ($Global:MemoryCache.ContainsKey('accessToken'))
            {
                $accessTokenObject = $Global:MemoryCache['accessToken']
                
                if ($accessTokenObject.domain -eq $domain)
                {
                    Write-Verbose "Domain matches. Using cached token."
                    Write-Verbose "Token for $domain found in memory cache."
                    
                    # Check if token is still valid
                    if ($accessTokenObject.access_token -and 
                        $accessTokenObject.AbsoluteExpiryTime -and 
                        $accessTokenObject.AbsoluteExpiryTime -gt $timeBuffer)
                    {
                        
                        Write-Host "Access token is valid until $($accessTokenObject.AbsoluteExpiryTime)."
                        Write-Host "Using cached access token for $($accessTokenObject.domain) from memory."
                        return $accessTokenObject.access_token
                    }
                    else
                    {
                        Write-Host "Access token in memory is expired or invalid."
                        # Try to use refresh token if available
                        if ($Deligated)
                        {
                            # First check if the object has a refresh token
                            if ($accessTokenObject.refresh_token)
                            {
                                return Get-RefreshToken -accessTokenObject $accessTokenObject -clientId $clientId -clientSecret $clientSecret `
                                    -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                    -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                            }
                            # If not, check if we have one in the config
                            elseif ($configRefreshToken)
                            {
                                $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                                return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                                    -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                    -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                            }
                        }
                    }
                }
                else
                {
                    Write-Host "Domain does not match. Requesting a new token from $domain."
                }
            }
            else
            {
                Write-Verbose "No token found in memory cache."
                # Check if we have a refresh token in config even if there's no memory cache
                if ($Deligated -and $configRefreshToken)
                {
                    Write-Verbose "No access token in memory, but found refresh token in config."
                    $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                    return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                        -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                        -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                }
            }
        }
        # Get token from file cache
        elseif ($cacheType -eq 'file')
        {
            if (Test-Path -Path $cacheTokenFile)
            {
                Write-Verbose "Cache file exists: $cacheTokenFile"
                try
                {
                    $accessTokenObject = Get-Content -Path $cacheTokenFile -Raw -Force | ConvertFrom-Json
                    
                    if ($accessTokenObject.domain -eq $domain)
                    {
                        Write-Verbose "Domain matches. Using cached token."
                        $accessToken = $accessTokenObject.access_token
                        
                        # Handle time formats
                        if ($accessTokenObject.AbsoluteExpiryTime -is [string])
                        {
                            $absoluteExpiryTime = [datetime]::Parse($accessTokenObject.absoluteExpiryTime).ToLocalTime()
                            if ($absoluteExpiryTime -lt $accessTokenObject.AbsoluteExpiryTime)
                            {
                                Write-Verbose "Resolving time differences between UTC and local time."
                                $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                            }
                        }
                        else
                        {
                            $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                        }
                        
                        Write-Verbose "Absolute Expiry Time: $absoluteExpiryTime"
                        Write-Verbose "We will renew the token $($renewalLeadTime) minutes before it expires."
                        
                        # Check if token is still valid
                        if ($accessToken -and $absoluteExpiryTime -gt $timeBuffer)
                        {
                            Write-Host "Access token for $($accessTokenObject.domain) is valid until $absoluteExpiryTime."
                            Write-Host "Using cached access token from disk."
                            return $accessToken
                        }
                        else
                        {
                            Write-Host "Access token is expired or invalid."
                            # Try to use refresh token if available
                            if ($Deligated)
                            {
                                # First check if the cache file has a refresh token
                                if ($accessTokenObject.refresh_token)
                                {
                                    return Get-RefreshToken -accessTokenObject $accessTokenObject -clientId $clientId -clientSecret $clientSecret `
                                        -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                        -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                                }
                                # If not, check if we have one in the config
                                elseif ($configRefreshToken)
                                {
                                    $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                                    return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                                        -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                                        -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                                }
                                else
                                {
                                    Write-Host "Requesting a new token for $domain."
                                }
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "Domain $domain does not match cached token domain $($accessTokenObject.domain)."
                    }
                }
                catch
                {
                    Write-Host "Failed to read cache file: $_"
                    Write-Host "Cache file may be corrupted or invalid. Requesting a new token."
                }
            }
            else
            {
                Write-Host "No cache file found."
                # Check if we have a refresh token in config even if there's no cache file
                if ($Deligated -and $configRefreshToken)
                {
                    Write-Verbose "No access token in file cache, but found refresh token in config."
                    $refreshTokenObject = @{ refresh_token = $configRefreshToken }
                    return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret `
                        -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType `
                        -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
                }
            }
        }
        else
        {
            Write-Error "Invalid cache type. Use 'file' or 'memory'."
            return $null
        }
        
        return $null
    }
    
    function Get-DelegatedToken
    {
        param($tenantId, $clientId, $clientSecret, $scopes, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $configFilePath)
        
        # Generate a random state string
        Write-Verbose "Generating random state string."
        $state = [System.Guid]::NewGuid().ToString()
        $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
        
        # Ensure scopes include openid and offline_access
        if (-not $scopes.Contains("openid"))
        {
            $scopes = "openid $scopes"
            Write-Verbose "Added openid to scopes"
        }
        
        # Encode parameters
        $encodedScopes = [uri]::EscapeDataString($scopes)
        $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
        
        # Step 1: Open the authorization URL
        $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=openid%20offline_access%20$($encodedScopes)&state=$state"
        Write-Host "Opening browser for user authentication and consent..."
        Start-Process $authUrl
        Write-Host "After granting consent, copy the 'code' parameter from the redirected URL and paste it below."
        $code = Read-Host "Enter the authorization code"
        
        # Step 2: Exchange the code for a token
        Write-Verbose "Exchanging authorization code for access token"
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $tokenRequestBody = @{
            client_id     = $clientId
            client_secret = $clientSecret
            code          = $code
            redirect_uri  = $redirectUri
            grant_type    = "authorization_code"
            scope         = "openid offline_access $scopes"
        }
        
        try
        {
            Write-Verbose "Sending token request to $tokenEndpoint"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $tokenRequestBody
            
            Write-Verbose "Access token received"
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain
            
            # Cache the access token based on cache type
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            
            # Save the refresh token to config file regardless of cache type
            if ($tokenResponse.refresh_token)
            {
                Save-RefreshTokenToConfig -refreshToken $tokenResponse.refresh_token -configFilePath $configFilePath
            }
            
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
        catch
        {
            Write-Error "Failed to get delegated access token: $_"
            if ($_.Exception.Response)
            {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Error "Server Response: $errorMessage"
            }
            return $null
        }
    }
    
    function Get-ClientCredentialsToken
    {
        param($tenantId, $clientId, $clientSecret, $domain, $cacheType, $cacheTokenFile, $cacheFolder)
        
        Write-Verbose "Using non-deligated access..."
        Write-Verbose "Requesting new access token"
        
        $body = @{
            client_id     = $clientId
            scope         = 'https://graph.microsoft.com/.default'
            client_secret = $clientSecret
            grant_type    = 'client_credentials'
        }
        
        try
        {
            $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body
            
            Write-Verbose "Access token received"
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain
            
            # Cache the token
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
        catch
        {
            Write-Error "Failed to get access token: $_"
            if ($_.Exception.Response)
            {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Error "Server Response: $errorMessage"
            }
            return $null
        }
    }
    #endregion Helper functions
    
    #region Main function logic
    # Read and process configuration file
    if (-not $configFile)
    {
        Write-Error "Config file not found. Please provide a valid config file."
        return $null
    }
    
    Write-Verbose "Reading config file $configFile"
    try
    {
        $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        Write-Verbose "Decrypting values from $configFile"
        $configRefreshToken = $null
        
        if (isEncrypted -data $config)
        {
            Write-Verbose "Config file is encrypted. Decrypting."
            $config = DecryptObject -encryptedObject $config -excludeFields 'domain'
            # Extract the refresh token if it exists
            if (Get-Member -InputObject $config -Name 'refresh_token' -MemberType NoteProperty)
            {
                $configRefreshToken = $config.refresh_token
                Write-Verbose "Found refresh token in encrypted config."
            }
        }
        else
        {
            Write-Verbose "Config file is not encrypted. Using as is."
            # Extract the refresh token if it exists
            if (Get-Member -InputObject $config -Name 'refresh_token' -MemberType NoteProperty)
            {
                $configRefreshToken = $config.refresh_token
                Write-Verbose "Found refresh token in config."
            }
        }
        
        $tenantId = $config.tenantId
        $clientId = $config.appId
        $clientSecret = $config.appSecret
        $domain = $config.domain
    }
    catch
    {
        Write-Error "Failed to read or process config file: $_"
        return $null
    }
    
    #region Log parameters
    Write-Verbose "Received parameters:"
    Write-Verbose "Configuration File: $configFile"
    Write-Verbose "Renewal Lead Time: $renewalLeadTime"
    Write-Verbose "Secure String: $SecureString"
    Write-Verbose "Force New Token: $ForceNewToken"
    Write-Verbose "Cache Type: $CacheType"
    Write-Verbose "Domain: $domain"
    Write-Verbose "Deligated: $Deligated"
    Write-Verbose "Scopes: $Scopes"
    Write-Verbose "Config has refresh token: $($null -ne $configRefreshToken)"
    #endregion Log parameters
    
    # Set up cache paths
    $cacheFolder = Split-Path $configFile
    $cacheTokenFile = Join-Path $cacheFolder "accessToken.json"
    
    # Try to get token from cache if not forcing new token
    $accessToken = $null
    if (-not $ForceNewToken)
    {
        $accessToken = Get-TokenFromCache -cacheType $CacheType -domain $domain -renewalLeadTime $renewalLeadTime `
            -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $Scopes `
            -deligated $Deligated -cacheFolder $cacheFolder -cacheTokenFile $cacheTokenFile `
            -secureString $SecureString -configFilePath $configFile -configRefreshToken $configRefreshToken
            
        if ($accessToken)
        {
            return $accessToken
        }
    }
    else
    {
        Write-Host "Force new token requested. Ignoring cache."
    }
    
    # Get new token if we don't have a valid cached token
    if ($tenantId -and $clientId -and $clientSecret)
    {
        if ($Deligated)
        {
            return Get-DelegatedToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret `
                -scopes $Scopes -domain $domain -cacheType $CacheType `
                -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFile
        }
        else
        {
            return Get-ClientCredentialsToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret `
                -domain $domain -cacheType $CacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        }
    }
    else
    {
        Write-Error "Missing required authentication parameters (tenantId, clientId, or clientSecret)"
        return $null
    }
    #endregion Main function logic
}

# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDAmZYm/rzfHNS7
# Q1KuuJwghs9L+RUVtBpqTO07pQfAvaCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN7hFrp
# 1U6LB3wLAAAAA3uEMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDI2MDQyODMwWhcNMjUwNDI5
# MDQyODMwWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h5g5eiaYpPz1B08V9hqjElk20N+8/puFpgJ1zJ64xzYtACnPYFYdSdVAojyK4Az8
# YcbYxE+1ik8TVFsB9ARcIOszkpm24IGKMGrQued67wrw6bszHlgwV0/9orSviw8/
# TzVue0Qbd/jflcK03TXjTN5PSELqRCXl+4j3b+Mt78Gc8u2UR/p+WrmYEkgeTRsn
# 6mIOr9n/vnDyiK8ECU4E5jjUoQ7oe7COcPQVsRJ1/sYH8nghkPCSQVG0n0y3Fi0Q
# 4MSe+LayByyO1u/A9EMsk0yTUFBvsFJDF//sAcO4kyCaKcfNPnIHvVa992z1u9uT
# Rw11WWrFqNor8Weume2PZY8BGhSaJL0j0iWWhTGwxQR6OwnRjhNI8QflLgxAUImO
# OsvfQZSCi1YWk2cFvX+AT9+o+6LBRlNyLnroMr1l5zJBL2ZCkoKbG1wp1sf+m2bO
# dwlKinAvviG+GBqvGkCfXEqF62cj0o06+Uox3ieyKi9vL1F1L4JLZQaGFpSHydeZ
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFLT4rWHrwwfh86z/13qLIjtysJzWMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFJ3H+2emMur6q4x
# 2ou6dltN2XEVNCMfjWsWryWLfyHyA5iBWHiZd7Fu37GXhOhj1oVZrQVxTZkrQRgZ
# f4fbejbBUwCsozJMb9dNB3ZtPahGfbOcWwcKBzXS4V/sDkGwt4Lu2maYwjgIquGh
# 6sdLLPFtXXkIcQ6bCP16283T8sndrX/hLvusFY80o3COvQG6mJBXM4HSdY+ZAOPO
# 3Ddows/3cJUP3ZpTjxrQGIDXq2ZPFm5/eOMjW7fM64NUYq+LPTMYlB2X2zlv6cX+
# DleOK4VXVjGORe3A3jaYqeWq5yh5Csos05JPXosgi01bAaOLwDYCQj+ElhqpQaqR
# 3zcLLF25mYLGgNIV3owuIgEVVpVE/iMo76g4ME5a+hEzcS2G1UVKkK0o8gGxDlrc
# KDgsrE/3koPFSubzVfWORrLzJYfbzB0R1M5fk4GsQhFiWY1sFmzMc4wHcV/+ilUh
# STVT6hvCYV5546l4/nGIrS4MQF01SxmutmhtQAdz0vay4ni5FKaoW3afZIFVE6NU
# RRT/gHvzWDc1AIkdBcfEkUgx4tZrC0Qkj+tsCX6Z04MPuoyBrEuLYrPIg5NbAcLu
# +4doG7Reu5pmuKhN6xl3F1MQ/2qhWxwNcecmkzK8qjOblVnwbGbOD/rdO2xilgrl
# oZDi+vcePFW2TOnG31Do716PWRqYMIIG5zCCBM+gAwIBAgITMwADe4Ra6dVOiwd8
# CwAAAAN7hDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyNjA0MjgzMFoXDTI1MDQyOTA0Mjgz
# MFowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIeYOXom
# mKT89QdPFfYaoxJZNtDfvP6bhaYCdcyeuMc2LQApz2BWHUnVQKI8iuAM/GHG2MRP
# tYpPE1RbAfQEXCDrM5KZtuCBijBq0Lnneu8K8Om7Mx5YMFdP/aK0r4sPP081bntE
# G3f435XCtN0140zeT0hC6kQl5fuI92/jLe/BnPLtlEf6flq5mBJIHk0bJ+piDq/Z
# /75w8oivBAlOBOY41KEO6HuwjnD0FbESdf7GB/J4IZDwkkFRtJ9MtxYtEODEnvi2
# sgcsjtbvwPRDLJNMk1BQb7BSQxf/7AHDuJMgminHzT5yB71Wvfds9bvbk0cNdVlq
# xajaK/Fnrpntj2WPARoUmiS9I9IlloUxsMUEejsJ0Y4TSPEH5S4MQFCJjjrL30GU
# gotWFpNnBb1/gE/fqPuiwUZTci566DK9ZecyQS9mQpKCmxtcKdbH/ptmzncJSopw
# L74hvhgarxpAn1xKhetnI9KNOvlKMd4nsiovby9RdS+CS2UGhhaUh8nXmQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBS0+K1h68MH4fOs/9d6iyI7crCc1jAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBSdx/tnpjLq+quMdqLunZb
# TdlxFTQjH41rFq8li38h8gOYgVh4mXexbt+xl4ToY9aFWa0FcU2ZK0EYGX+H23o2
# wVMArKMyTG/XTQd2bT2oRn2znFsHCgc10uFf7A5BsLeC7tpmmMI4CKrhoerHSyzx
# bV15CHEOmwj9etvN0/LJ3a1/4S77rBWPNKNwjr0BupiQVzOB0nWPmQDjztw3aMLP
# 93CVD92aU48a0BiA16tmTxZuf3jjI1u3zOuDVGKviz0zGJQdl9s5b+nF/g5XjiuF
# V1YxjkXtwN42mKnlqucoeQrKLNOST16LIItNWwGji8A2AkI/hJYaqUGqkd83Cyxd
# uZmCxoDSFd6MLiIBFVaVRP4jKO+oODBOWvoRM3EthtVFSpCtKPIBsQ5a3Cg4LKxP
# 95KDxUrm81X1jkay8yWH28wdEdTOX5OBrEIRYlmNbBZszHOMB3Ff/opVIUk1U+ob
# wmFeeeOpeP5xiK0uDEBdNUsZrrZobUAHc9L2suJ4uRSmqFt2n2SBVROjVEUU/4B7
# 81g3NQCJHQXHxJFIMeLWawtEJI/rbAl+mdODD7qMgaxLi2KzyIOTWwHC7vuHaBu0
# XruaZrioTesZdxdTEP9qoVscDXHnJpMyvKozm5VZ8Gxmzg/63TtsYpYK5aGQ4vr3
# HjxVtkzpxt9Q6O9ej1kamDCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
# AAQwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTJaFw0yNjA0MTMx
# NzMxNTJaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDhzqDoM6JjpsA7AI9s
# GVAXa2OjdyRRm5pvlmisydGnis6bBkOJNsinMWRn+TyTiK8ElXXDn9v+jKQj55cC
# pprEx3IA7Qyh2cRbsid9D6tOTKQTMfFFsI2DooOxOdhz9h0vsgiImWLyTnW6locs
# vsJib1g1zRIVi+VoWPY7QeM73L81GZxY2NqZk6VGPFbZxaBSxR1rNIeBEJ6TztXZ
# sz/Xtv6jxZdRb3UimCBFqyaJnrlYQUdcpvKGbYtuEErplaZCgV4T4ZaspYIYr+r/
# hGJNow2Edda9a/7/8jnxS07FWLcNorV9DpgvIggYfMPgKa1ysaK/G6mr9yuse6cY
# 0Hv/9Ca6XZk/0dw6Zj9qm2BSfBP7bSD8DfuIN+65XDrJLYujT+Sn+Nv4ny8TgUyo
# iLDEYHIvjzY8xUELep381sVBrwyaPp6exT4cSq/1qv4BtwrC6ZtmokkqZCsZpI11
# Z+TY2h2BxY6aruPKFvHBk6OcuPT9vCexQ1w0B7T2/6qKjPJBB6zwDdRc9xFBvwb5
# zTJo7YgKJ9ZMrvJK7JQnzyTWa03bYI1+1uOK2IB5p+hn1WaGflF9v5L8rlqtW9Nw
# u6S3k91MNDGXnnsQgToD7pcUGl2yM7OQvN0SHsQuTw9U8yNB88KAq0nzhzXt93YL
# 36nEXWURBQVdj9i0Iv42az1xZQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQkRZmhd5AqfMPKg7BuZBaEKvgs
# ZzBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGct
# OF2Vsw0iiR0q3NJryKj6kQ73kJzdU7Jj+FCwghx0zKTaEk7Mu38zVZd9DISUOT9C
# 3IvNfrdN05vkn6c7y3SnPPCLtli8yI2oq8BA7nSww4mfdPeEI+mnE02GgYVXHPZT
# KJDhva86tywsr1M4QVdZtQwk5tH08zTBmwAEiG7iTpVUvEQN7QZJ5Bf9kTs8d9OD
# jgu5+3ggqpiae/UK6iyneCUVixV6AucxZlRnxS070XxAKICi4liEvk6UKSyANv29
# 78dCEsWd6V+Dp1C5sgWyoH0iUKidgoln8doxm9i0DvL0Q5ErhzGW9N60JcAdrKJJ
# cfS54T9P3bBUbRyy/lV1TKPrJWubba+UpgCRcg0q8M4Hz6ziH5OBKGVRrYAK7YVa
# fsnOVNJumTQgTxES5iaS7IT8FOST3dYMzHs/Auefgn7l+S9uONDTw57B+kyGHxK4
# 91AqqZnjQjhbZTIkowxNt63XokWKZKoMKGCcIHqXCWl7SB9uj3tTumult8EqnoHa
# TZ/tj5ONatBg3451w87JAB3EYY8HAlJokbeiF2SULGAAnlqcLF5iXtKNDkS5rpq2
# Mh5WE3Qp88sU+ljPkJBT4kLYfv3Hh387pg4VH1ph7nj8Ia6nt1FQh8tK/X+PQM9z
# oSV/djJbGWhaPzJ5jeQetkVoCVEzCEBfI9DesRf3MIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADe4Ra6dVOiwd8CwAAAAN7hDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBtdIpUQPQEgYWLhGG8ndgawsIt
# jb5fdFqX6qaCPQkErjANBgkqhkiG9w0BAQEFAASCAYA1QIlhr+0bYtaai1Q2na3B
# QKVZfHIIo87PBhPCb41OSmswAbrJJzqbeuPC4YgXSVJ3vC1pyhNeZ+7ew8W42s6I
# BxgX8ABpQyBrTBGLnsG4+ftDtvdBgRbuPU+JwLSNgd3U4pAIJpot9WBfXno4dKnR
# bsOrdkByOoEfnpsQqbLD3mRI/blAseJsjvvsXY9ZvdZ/hA1le4MK/hnFOsCuUHPE
# gNHJdjrQZpW+tjQSG3E6QIxcljeG+V1NHmPUX8OCH1S6noG+im8oSw+zoMYo8Xz3
# ANymXIHys9WiFeLUMtLJe8JuR8IO0SaAawn55NMqPzMzT1kXNfFchSsnT92vBIVM
# R4XL2Fib+NfBeC7Jh+XXaHLKeeuGOfPgZLSmONLPTmwQqpkzA2mO4Ou1CI/NmhZi
# MJksofhgM4oeQnauL8UYx9zAmMvE+apFhsl/LppWSj9mluE6I+ACyID035eG3OWw
# BUWrGh75ypcD4YV7b6MhLPvKzOjfO9as6z+ai+DgaQChghgRMIIYDQYKKwYBBAGC
# NwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgyKmv9xBLOSxrNlRgQXWpdOF+Nc3EIQ+QXZxjeRU4
# AqMCBmgLyvojiRgTMjAyNTA0MjYyMDI3NDYuODk3WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAAR+OVCzehYN3HAAAAAABHMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MFoXDTI1MTExOTE4NDg1MFowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDocLpu99z/+NeI
# ZmR32GJg2VT/jd96pYLsvNngeH4qXwK1qVmFaXXkkVbxb1fOQJMukYkba3WEc69W
# /Z4BszAuxguThDVlY9sk4ZYkGMgxoq1Z5inUPvj4Qh8xVvlhiAS6Of/uLwDsbsKl
# g2fGpmvztiPSOL9P15k00I4bsl1vlmRSut2tNwJQ5sXpoT7GI/2T2A0GnWbFECKR
# CyGW9rsny9o0LNIUl4NYAd4awGSs6OIzKPpIK1JfK90wXHvaXwGJcN9P8QPRJIHK
# uFoVGzIUG/C0jQC4rQ62yTGvc2sZ4AxTQwflfVBBaiHq8gn/YDHpZileGkB2IQaz
# ZEiEc5Or5Xer9mUDU+2FEe66w8e2WkLXanqxaD5+Zco+E+QdwcTYGo78jFxPDvNr
# aTr5QAgITc4dY/PBC3cYFzcgDyUx2xOVCBvgabqJxj7rXrj4Bhd2S/ZTYOVHhi8c
# DWBaefM8JgiO8GCIIRvlNWng8FKFt09ZfNxmsSdCJlWw3rNAwsBY1xp8pmmv9r2M
# 9rNIRkZ+sh0xd3GuASWs2bOrqBi0aTzgY9b3CxY+/m+RU+UTim5JkmpJM/AIP68/
# S+1NwFqXK5yxTJBIInhoEgdEHi+a2JR2SlV3AkpJa0/B6sZaoEa+zgshIfFa66XB
# mnnsydV4uG7W1INoaNVwxBKDdmqNRwIDAQABo4IByzCCAccwHQYDVR0OBBYEFORU
# dlggOj7vT7m2XvFhSEW8ht1oMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEADSJUQ9XamDh0gkC1XvrhVz6A
# MwGVKuKJA+tklJzBa4UVYP3Y9r1RLU08RYJIjPEkpwiwDWitK58gsZxwNh4Nc4fF
# iQrZUJZ9BInfnodv8WOO83zY8YQdJMcpgBzeYVXiNCedumqFKXj0mMMuWaBynv7w
# wn7FnHJwzLru4jt4VLeef+BycnYwPoMa75LF/9xZo/0TJ371qtBYdbsceKmNhQUT
# D2vIvvPkHTPH/NA2IkLsQ1Am51nzh52WEDzRCoXeld6+/KClnfsEB1/vfR6pYPxw
# ZTvTZ7uh7y8D6g4hDpEcjIses754W2aRpxTPru6n+z2EzkvHF70B/g5oAodmVTUB
# b+pxpu77UHm0TraVodjfXJJNs+h1RjnCu9Miku2KhPmpBrsSne31y3gXstm5vctp
# 1tFox9amTWvhIV88l1EIC3yX+BN9cGKtL65REl/y8yqa2PIW2i18JMRIr4T7liHf
# X0A6sdPsl7GudLyEVHAWsW8NFVzt/vdyRhzMUpsxhPL1qGQgD45Q+3bgTlel5MWl
# WgYG+b+LLUXR5uiybbIswnORTU/jDycNAx8u4c5+14sen5/fmqcrQa316l7WqcQ6
# rOcoxDFym7k2RVuEhZNQ4XNXCKI7kb8PMrRtMbobV0mryd0UlbQUbPsJuN9nUE2A
# DmgnO3bQGyERvppedCExggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAA
# AABHMA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjYyMDI3
# NDZaMC8GCSqGSIb3DQEJBDEiBCBJeXrV36xqy614sBbVY2K3Udh1Ue3N2CTKqgQ3
# yqITfzCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIJNm85ZyhQAGGe9QPhd3
# +xvmMKCvfjHhf8tl6mRICsynMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAR+OVCzehYN3HAAAAAABH
# MIIDXgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3QTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# ACAF09m+ILyMNydZT7P3lOLNVFzdoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67ea/DAiGA8yMDI1MDQyNjE3NDg0NFoYDzIwMjUwNDI3MTc0ODQ0WjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDrt5r8AgEAMAcCAQACAg/hMAcCAQACAhNdMAoCBQDr
# uOx8AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAKth3G6by8tonfUM44Sr
# e2JLhrCK/WeTgr97bO4crUM+2gL+OYpn8JC+IJGTdovlFJx1QddvoNaDB/Npx+S7
# EyzkLMVqmrEJqHgMQF1UUkwxQjNzImKFa/5+c2YV+y7wEVCOoZi1HLNV2c5KVi0R
# iIxsgd4yBB1aeBvp6BTQ1q6WJZP8WU1BR/xeZ4h//e7Ppdja29Pg8JKy8hiTZH63
# iWgLWnwtp0FVmc4Trhs41BlOgl7WixhAq+zJYYKr+ctTm1i1e2HSVzcvIwhQaxJX
# lVByeU/Rp9UTVWK6GU8jdeOsYHEpQWPLDhgO93kTouTy+SrxhEMQxoVSx8G01m8G
# W8EwDQYJKoZIhvcNAQEBBQAEggIA51asuEg++6AOq8PxryT+6/OdtfmIFb8la3ge
# bb0sXC3Qoq9ujv85KHSz4evRWVi97VqiyQLfwJd0Lzst/T3sNEJzpOtXLYZLpx8n
# W2MKPDOGuhy4v7D2hfFvqlvcQ3ofPuTn2s1aXGX9KybPhPihC5VFOOGIR5FCInqf
# tepfH7vHpRUMQllRcy1lDU2jF4bSwLf2EVSD+O5YIhDPeYI1rJvjlogYVr1E0LmG
# m+ED8YUIweXpeXBZ+FGeZOtMdQ2ZNv4ETRGaw4Er6HHmIIbXs97Q/yFi6wwunRBM
# ZKe7x33y/4Ijqkaoy61/zkr1rXe4/YdohU+gsb2x80Mo/XK9qKck1XzeBfYT2vtC
# ntkHPHulLUkn4u4M2cnX8tIYUbMwby22g4cH6Va3mFBtQIZx8fyLUWNi1e18VirB
# aDSyPhTu9U7F/Ui6fTDXGcS97ncqkrmO2HMRH8FD/n6uMWvbqRK8g3x0U9l13p8+
# VcUBj24CvzkRDozGxDljXrOSI5o4ygArY5iY/YtTUACkhfCGG+aKiU0tLKXQ9Tkr
# AMzCp85eaPWX19vxfcrlH5hbqda9H/DBiyttUuBM5mwe3bIczRKnIHW7T4k/gfWd
# AkFKu6sbdfZiOAMAkGwueh4PQDKa5UabMnurNgrO+1q4bv4OL4SG1IDRGXTgC+RV
# /9bxvp0=
# SIG # End signature block
