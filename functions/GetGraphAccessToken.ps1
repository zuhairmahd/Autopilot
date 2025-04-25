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
    #region Read config file
    if ($configFile)
    {
        Write-Verbose "Reading config file $configFile"
        $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        Write-Verbose "Decrypting values from $configFile"
        if (isEncrypted -data $config)
        {
            Write-Verbose "Config file is encrypted. Decrypting."
            $config = DecryptObject -encryptedObject $config -excludeFields 'domain'
        }
        else
        {
            Write-Verbose "Config file is not encrypted. Using as is."
        }
        $tenantId = $config.tenantId
        $clientId = $config.appId
        $clientSecret = $config.appSecret
        $domain = $config.domain
    }
    else
    {
        Write-Error "Config file not found. Please provide a valid config file."
        return $null
    }
    #endregion

    #region write a verbose log of the received parameters
    Write-Verbose "Received parameters:"
    Write-Verbose "Configuration File: $configFile"
    Write-Verbose "Renewal Lead Time: $renewalLeadTime"
    Write-Verbose "Secure String: $SecureString"
    Write-Verbose "Force New Token: $ForceNewToken"
    Write-Verbose "Cache Type: $CacheType"
    Write-Verbose "Domain: $domain"
    Write-Verbose "Deligated: $Deligated"
    Write-Verbose "Scopes: $Scopes"
    #endregion
    
    $cacheFolder = Split-Path $configFile
    $cacheTokenFile = $cacheFolder + "\accessToken.json"
    #region Check for existing token
    if (-not $ForceNewToken)
    {
        Write-Verbose "Checking for existing token in cache"
        if ($CacheType -eq 'memory')
        {
            Write-Verbose "Using memory cache for access token."
            if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
            {
                Write-Verbose "Initializing memory cache."
                New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
            }
            Write-Verbose "Checking for existing token in cache"
            if ($CacheType -eq 'memory')
            {
                if ($Global:MemoryCache.ContainsKey('accessToken'))
                {
                    $accessTokenObject = $Global:MemoryCache['accessToken']
                    if ($accessTokenObject.domain -eq $domain)
                    {
                        Write-Verbose "Domain matches. Using cached token."
                        Write-Verbose "Domain: $($accessTokenObject.domain)"
                        Write-Verbose "Matching domain: $domain"
                        Write-Verbose "Token for $domain found in memory cache."
                        $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
                        if ($accessTokenObject.access_token -and $accessTokenObject.AbsoluteExpiryTime -and $accessTokenObject.AbsoluteExpiryTime -gt $timeBuffer)
                        {
                            Write-Host "Access token is valid until $($accessTokenObject.AbsoluteExpiryTime)."
                            Write-Host "Using cached access token for $($accessTokenObject.domain) from memory."
                            return $accessTokenObject.access_token
                        }
                        else
                        {
                            Write-Host "Access token in memory is expired or invalid."
                            # Check if we have a refresh token to use
                            if ($accessTokenObject.refresh_token -and $Deligated)
                            {
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
                                    $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
                                    Write-Verbose "Token absolute expiry time: $($tokenExpiryTime)"
                                    
                                    $cachedToken = [PSCustomObject] @{
                                        'domain'           = $domain
                                        access_token       = $tokenResponse.access_token
                                        refresh_token      = $tokenResponse.refresh_token
                                        AbsoluteExpiryTime = $tokenExpiryTime
                                        'expires_in'       = $tokenResponse.expires_in
                                        scope              = $tokenResponse.scope
                                    }
                                    
                                    # Cache the token based on user preference
                                    if ($CacheType -eq 'memory')
                                    {
                                        Write-Verbose "Saving refreshed access token to memory cache."
                                        $Global:MemoryCache['accessToken'] = $cachedToken
                                    }
                                    else
                                    {
                                        Write-Verbose "Saving refreshed access token to cache file: $cacheTokenFile"
                                        if (-not (Test-Path -Path $cacheFolder))
                                        {
                                            Write-Verbose "Creating cache folder: $cacheFolder"
                                            New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
                                        }
                                        $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
                                        Write-Verbose "Refreshed access token saved to $cacheTokenFile"
                                    }
                                    if ($SecureString)
                                    {
                                        Write-Verbose "Converting access token to secure string"
                                        $secureAccessToken = ConvertTo-SecureString -String $tokenResponse.access_token -AsPlainText -Force
                                        Write-Verbose "Returning secure token"
                                        return $secureAccessToken
                                    }
                                    else
                                    {
                                        Write-Verbose "Returning plain text access token"
                                        return $tokenResponse.access_token
                                    }
                                }
                                catch
                                {
                                    Write-Host "Failed to use refresh token: $_. Will request new authorization."
                                    Write-Host "Refresh token might be expired or revoked, proceeding with new authorization."
                                }
                            }
                            else
                            {
                                Write-Host "Requesting a new token."
                            }
                        }
                    }
                    else
                    {
                        Write-Host "Domain does not match. Requesting a new token from $domain."
                        $accessTokenObject = $null
                    }
                }
                else
                {
                    Write-Verbose "No token found in memory cache."
                }
            }
        }
        elseif ($CacheType -eq 'file')
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
                        Write-Verbose "Cache file read successfully"
                        $accessToken = $accessTokenObject.access_token
                        Write-Verbose "Access Token Expirey Time in UTC: $($accessTokenObject.AbsoluteExpiryTime)"
                        $absoluteExpiryTime = [datetime]::Parse($accessTokenObject.absoluteExpiryTime).ToLocalTime()
                        if ($absoluteExpiryTime -lt $accessTokenObject.AbsoluteExpiryTime)
                        {
                            Write-Verbose "Resolving time differences between UTC and local time."
                            $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                        }
                        Write-Verbose "Absolute Expiry Time: $absoluteExpiryTime"
                        $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
                        Write-Verbose "we will renew the token $($renewalLeadTime) minutes before it expires."
                        if ($accessTokenObject.access_token -and $accessTokenObject.AbsoluteExpiryTime -and $absoluteExpiryTime -gt $timeBuffer)
                        {
                            Write-Host "Access token for $($accessTokenObject.domain) is valid until $absoluteExpiryTime."
                            Write-Host "Using cached access token from disk."
                            return $accessToken
                        }
                        else
                        {
                            Write-Host "Access token is expired or invalid."
                            # Check if we have a refresh token to use
                            if ($accessTokenObject.refresh_token -and $Deligated)
                            {
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
                                    $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
                                    Write-Verbose "Token absolute expiry time: $($tokenExpiryTime)"
                                    $cachedToken = [PSCustomObject] @{
                                        'domain'           = $domain
                                        access_token       = $tokenResponse.access_token
                                        refresh_token      = $tokenResponse.refresh_token
                                        AbsoluteExpiryTime = $tokenExpiryTime
                                        'expires_in'       = $tokenResponse.expires_in
                                        scope              = $tokenResponse.scope
                                    }
                                    # Save refreshed token to file
                                    Write-Verbose "Saving refreshed access token to cache file: $cacheTokenFile"
                                    if (-not (Test-Path -Path $cacheFolder))
                                    {
                                        Write-Verbose "Creating cache folder: $cacheFolder"
                                        New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
                                    }
                                    $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
                                    Write-Verbose "Refreshed access token saved to $cacheTokenFile"
                                    if ($SecureString)
                                    {
                                        Write-Verbose "Converting access token to secure string"
                                        $secureAccessToken = ConvertTo-SecureString -String $tokenResponse.access_token -AsPlainText -Force
                                        Write-Verbose "Returning secure token"
                                        return $secureAccessToken
                                    }
                                    else
                                    {
                                        Write-Verbose "Returning plain text access token"
                                        return $tokenResponse.access_token
                                    }
                                }
                                catch
                                {
                                    Write-Host "Failed to use refresh token: $_. Will request new authorization."
                                    Write-Host "Refresh token might be expired or revoked, proceeding with new authorization."
                                }
                            }
                            else
                            {
                                Write-Host "Requesting a new token for $domain."
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "Domain $domain does not match cached token domain $($accessTokenObject.domain)."
                        $accessTokenObject = $null
                    }
                }
                catch
                {
                    Write-Host "Failed to read cache file: $_"
                    Write-Host "Cache file may be corrupted or invalid. Requesting a new token."
                    $cachedToken = $null
                }
            }
            else
            {
                Write-Host "No cache file found."
            }
        }
        else
        {
            Write-Error "Invalid cache type. Use 'file' or 'memory'."
            return $null
        }
    }
    else
    {
        Write-Host "Force new token requested. Ignoring cache."
        $accessToken = $null
        $tokenExpiryTime = $null
        $cachedToken = $null
    }
    #endregion

    
    if ($tenantId -and $clientId -and $clientSecret)
    {
        if ($deligated)
        {
            #Generate a random state string and assign it to a variable.
            Write-Verbose "Generating random state string."
            $state = [System.Guid]::NewGuid().ToString()
            Write-Verbose "State string: $state"
            $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
            Write-Verbose "Using deligated access..." 
            
            # Ensure scopes include openid and offline_access
            if (-not $scopes.Contains("openid"))
            {
                $scopes = "openid $scopes"
                Write-Verbose "Added openid to scopes"
            }
            
            Write-Verbose "Requesting the following scopes: $scopes"
            Write-Verbose "Encoding scopes..."
            $encodedScopes = [uri]::EscapeDataString($scopes)
            Write-Verbose "Encoded scopes: $encodedScopes"
            
            #also encode the redirectUri using escapestring.
            Write-Verbose "Encoding redirect URI..."
            $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
            Write-Verbose "Encoded redirect URI: $encodedRedirectUri"
            
            # Step 1: Open the authorization URL in the user's default browser to prompt for login and consent.
            $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=openid%20offline_access%20$($encodedScopes)&state=$state"
            Write-Host "Opening browser for user authentication and consent..."
            Start-Process $authUrl
            Write-Host "After granting consent, copy the 'code' parameter from the redirected URL and paste it below."
            $code = Read-Host "Enter the authorization code"
            
            # Step 2: Exchange the authorization code for an access token
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
                Write-Verbose "Calculating absolute expiry time"
                $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
                Write-Verbose "Token absolute expiry time: $($tokenExpiryTime)"
                
                $cachedToken = [PSCustomObject] @{
                    'domain'           = $domain
                    access_token       = $tokenResponse.access_token
                    refresh_token      = $tokenResponse.refresh_token
                    AbsoluteExpiryTime = $tokenExpiryTime
                    'expires_in'       = $tokenResponse.expires_in
                    scope              = $tokenResponse.scope
                }
                
                # Cache the token based on user preference
                if ($CacheType -eq 'memory')
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
                
                if ($SecureString)
                {
                    Write-Verbose "Converting access token to secure string"
                    $secureAccessToken = ConvertTo-SecureString -String $tokenResponse.access_token -AsPlainText -Force
                    Write-Verbose "Returning secure token"
                    return $secureAccessToken
                }
                else
                {
                    Write-Verbose "Returning plain text access token"
                    return $tokenResponse.access_token
                }
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
        else 
        {
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
                $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType 'application/x-www-form-urlencoded' -Body $body
                Write-Verbose "Access token received"
                Write-Verbose "Calculating absolute expiry time"
                Write-Verbose "Converting from $($tokenResponse.expires_in)"
                $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
                Write-Verbose "Converted to $($tokenExpiryTime)"
                Write-Verbose "Token absolute expiry time: $($tokenExpiryTime)"
                Write-Verbose "Creating hashtable for cached token"
                $cachedToken = [psCustomObject] @{
                    'domain'           = $domain
                    access_token       = $tokenResponse.access_token
                    AbsoluteExpiryTime = $tokenExpiryTime
                    'expires_in'       = $tokenResponse.expires_in
                }
                Write-Verbose "Access token hashtable created"
                if ($CacheType -eq 'memory')
                {
                    Write-Verbose "Saving access token to memory cache."
                    $Global:MemoryCache['accessToken'] = $cachedToken
                }
                else
                {
                    Write-Verbose "Saving access token to cache file: $cacheTokenFile"
                    Write-Verbose "Creating cache folder if it does not exist"
                    if (-not (Test-Path -Path $cacheFolder))
                    {
                        Write-Verbose "Creating cache folder: $cacheFolder"
                        New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
                    }
                    else 
                    {
                        Write-Verbose "Cache folder already exists: $cacheFolder"
                    }
                    Write-Verbose "Saving access token to disk cache."
                    $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
                    Write-Verbose "Access token saved to $cacheTokenFile"
                }
                if ($SecureString)
                {
                    Write-Verbose "Converting access token to secure string"
                    $secureAccessToken = ConvertTo-SecureString -String $tokenResponse.access_token -AsPlainText -Force
                    Write-Verbose "Returning secure token"
                    return $secureAccessToken
                }
                else
                {
                    Write-Verbose "Returning plain text access token"
                    return $tokenResponse.access_token
                }
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
                    # Reset cache on failure
                    $accessToken = $null
                    $tokenExpiryTime = $null
                    $cachedToken = $null
                    return $cachedToken
                }        
            }
        }
    }
}


# SIG # Begin signature block
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAmZ6rI4TBzJhlh
# lZ4SyW17XBGl0o8xaqLb6f7/+2o+3aCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN0uwl7
# vtDCSQaiAAAAA3S7MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDIzMDQ0NDU1WhcNMjUwNDI2
# MDQ0NDU1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h/5tCSWKbPKt8F93wvLZlP5AAfdF3mukm8z0mBQtyMLGXK+NWnLO8fvV0ge5eUjI
# A9wcMLEcX2TvQCW7IyvihQMgHy1L6uzT9xKUmyQI9kJGEXpw64rtKAgDlJqD6GgA
# WnyhOzNcHRfgN0HNTai/MezVyct6AF9SxZn1XinCOhUbBx1wTZTvScxwTEqe43HU
# ZIVJ40G32BYnBeOoSXYAO0ZK4b+mxStrfB9II8lQ3tdTxu524cM+qaIF23QUnhBa
# asuCBhne2rFQuaQnY++/GvWc+ZdkR1d4eoV4zyt9d+mzYHNZ9JNOI4XWn78S2rKd
# gsL9xWj1YKAD1mhVFuuBKMIXktSaSDXiPdhGWSQcaTYbchw2OI0Peb3Xf50WD9qD
# GAPcYdjtB0vugl/dx5YJOLBfqiIxXeVg6TEsgSQTRDQdBaKDjHma/gXRJIsQw5KP
# mJMHaAZ5dEDoVuXbDev27Yvv4VV95giO3wLUx2iOsC1qDenBWiFyWPe4WovyDvxF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCmIHt4RADaTywJxAromEjAGzJZjMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFXeJOg62AhYTxzF
# Yip4wYPtqc/tDdCid07e6FTg2jM84hJXep5mqbcU8VtqDNTqVODwDy1dFGRmHAdu
# 3F4o2Hkb0W4QVFAZsHR9yd+BQTJGDBFv+i23cHJ+qODBTZ6rh1NOMRGSuH6k3lX7
# nsI0/WQXbff/5XsSqpO9/d0+2VwWmeujUSCQf48tY7PsXBH+4rPOe3U9NW0/HXiI
# adefC8/N9UltDmQ4by+CtRmra3nBkIEAPRmFC1ERfq3JMPAJ4yJ3ddzakrjO0w56
# JyW7yeawoSB3iX8due4vRy2rDIfFWsKrcIKEqBZItd3ZTDIuLXbpQD/tZxocQPIx
# Eg6Wy5XRMlKxgQmxVP8IIsmz9InLM1qjhAtGgIv+kx+iisyg1qvojhnGnJohaZbq
# 2XH5Nx84JnfOfTAZ0mfEuSnuZA7IvCtaL66lP6Q1TikBAIGUa5wwk6cL0GGFGcI4
# p/Lr9n34HsCuJp4Qu/d6IaHMwA0s4YJnwH/bJctKJYO5VhV5MEVDU2QgeVkAkQ5G
# EIKOIBA1SR+fC87xg9dmbFjmAHqA3wkNgL1DVijsPpMXByQnkP3IqFFlDrP+rlBz
# WBv7814VxOszcciIgYPGI24asSBGXE6oQyAKkmTfTthhzNdgT5JxpNrgBwFEuUle
# mnqxm4/T9GIubTff34taJzANNNJVMIIG5zCCBM+gAwIBAgITMwADdLsJe77QwkkG
# ogAAAAN0uzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyMzA0NDQ1NVoXDTI1MDQyNjA0NDQ1
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIf+bQkl
# imzyrfBfd8Ly2ZT+QAH3Rd5rpJvM9JgULcjCxlyvjVpyzvH71dIHuXlIyAPcHDCx
# HF9k70AluyMr4oUDIB8tS+rs0/cSlJskCPZCRhF6cOuK7SgIA5Sag+hoAFp8oTsz
# XB0X4DdBzU2ovzHs1cnLegBfUsWZ9V4pwjoVGwcdcE2U70nMcExKnuNx1GSFSeNB
# t9gWJwXjqEl2ADtGSuG/psUra3wfSCPJUN7XU8buduHDPqmiBdt0FJ4QWmrLggYZ
# 3tqxULmkJ2Pvvxr1nPmXZEdXeHqFeM8rfXfps2BzWfSTTiOF1p+/EtqynYLC/cVo
# 9WCgA9ZoVRbrgSjCF5LUmkg14j3YRlkkHGk2G3IcNjiND3m913+dFg/agxgD3GHY
# 7QdL7oJf3ceWCTiwX6oiMV3lYOkxLIEkE0Q0HQWig4x5mv4F0SSLEMOSj5iTB2gG
# eXRA6Fbl2w3r9u2L7+FVfeYIjt8C1MdojrAtag3pwVohclj3uFqL8g78RQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQpiB7eEQA2k8sCcQK6JhIwBsyWYzAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBV3iToOtgIWE8cxWIqeMGD
# 7anP7Q3QondO3uhU4NozPOISV3qeZqm3FPFbagzU6lTg8A8tXRRkZhwHbtxeKNh5
# G9FuEFRQGbB0fcnfgUEyRgwRb/ott3ByfqjgwU2eq4dTTjERkrh+pN5V+57CNP1k
# F233/+V7EqqTvf3dPtlcFpnro1EgkH+PLWOz7FwR/uKzznt1PTVtPx14iGnXnwvP
# zfVJbQ5kOG8vgrUZq2t5wZCBAD0ZhQtREX6tyTDwCeMid3Xc2pK4ztMOeiclu8nm
# sKEgd4l/HbnuL0ctqwyHxVrCq3CChKgWSLXd2UwyLi126UA/7WcaHEDyMRIOlsuV
# 0TJSsYEJsVT/CCLJs/SJyzNao4QLRoCL/pMfoorMoNar6I4ZxpyaIWmW6tlx+Tcf
# OCZ3zn0wGdJnxLkp7mQOyLwrWi+upT+kNU4pAQCBlGucMJOnC9BhhRnCOKfy6/Z9
# +B7AriaeELv3eiGhzMANLOGCZ8B/2yXLSiWDuVYVeTBFQ1NkIHlZAJEORhCCjiAQ
# NUkfnwvO8YPXZmxY5gB6gN8JDYC9Q1Yo7D6TFwckJ5D9yKhRZQ6z/q5Qc1gb+/Ne
# FcTrM3HIiIGDxiNuGrEgRlxOqEMgCpJk307YYczNdgT5JxpNrgBwFEuUlemnqxm4
# /T9GIubTff34taJzANNNJVMIIG5zCCBM+gAwIBAgITMwADdLsJe77QwkkGogAAAAN0uzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyMzA0NDQ1NVoXDTI1MDQyNjA0NDQ1NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlBcmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhhaXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIf+bQklimzyrfBfd8Ly2ZT+QAH3Rd5rpJvM9JgULcjCxlyvjVpyzvH71dIHuXlIyAPcHDCxHF9k70AluyMr4oUDIB8tS+rs0/cSlJskCPZCRhF6cOuK7SgIA5Sag+hoAFp8oTszXB0X4DdBzU2ovzHs1cnLegBfUsWZ9V4pwjoVGwcdcE2U70nMcExKnuNx1GSFSeNBt9gWJwXjqEl2ADtGSuG/psUra3wfSCPJUN7XU8buduHDPqmiBdt0FJ4QWmrLggYZ3tqxULmkJ2Pvvxr1nPmXZEdXeHqFeM8rfXfps2BzWfSTTiOF1p+/EtqynYLC/cVo9WCgA9ZoVRbrgSjCF5LUmkg14j3YRlkkHGk2G3IcNjiND3m913+dFg/agxgD3GHY7QdL7oJf3ceWCTiwX6oiMV3lYOkxLIEkE0Q0HQWig4x5mv4F0SSLEMOSj5iTB2gGeXRA6Fbl2w3r9u2L7+FVfeYIjt8C1MdojrAtag3pwVohclj3uFqL8g78RQIDAQABo4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDV...
