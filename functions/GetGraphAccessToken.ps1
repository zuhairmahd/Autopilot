function GetGraphAccessToken()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$configFile,
        [int]$renewalLeadTime = 5,
        [switch]$SecureString,
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
                            Write-Host "Access token in memory is expired or invalid. Requesting a new one."
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
                        #convert to local time
                        $absoluteExpiryTime = [datetime]::Parse($accessTokenObject.absoluteExpiryTime).ToLocalTime()
                        $timeBuffer = $absoluteExpiryTime.AddMinutes(-$renewalLeadTime)
                        Write-Verbose "we will renew the token $($renewalLeadTime) minutes before it expires, which will be on $($timeBuffer)"
                        if ($accessTokenObject.access_token -and $accessTokenObject.AbsoluteExpiryTime -and $absoluteExpiryTime -gt $timeBuffer)
                        {
                            Write-Host "Access token for $($accessTokenObject.domain) is valid until $absoluteExpiryTime."
                            Write-Host "Using cached access token from disk."
                            return $accessToken
                        }
                        else
                        {
                            Write-Host "Access token is expired or invalid. Requesting a new one for $domain."
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
                    Write-Error "Failed to read cache file: $_"
                    Write-Verbose "Cache file may be corrupted or invalid. Requesting a new token."
                    $cachedToken = $null
                }
            }
            else
            {
                Write-Verbose "No cache file found."
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
        Write-Verbose "Force new token requested. Ignoring cache."
        $accessToken = $null
        $tokenExpiryTime = $null
        $cachedToken = $null
    }
    #endregion

    
    if ($tenantId -and $clientId -and $clientSecret)
    {
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
            $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in).ToLocalTime()
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

