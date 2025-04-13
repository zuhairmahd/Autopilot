function GetGraphAccessToken()
{
    [CmdletBinding(DefaultParameterSetName = 'Manual')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
        [string]$tenantId,
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
        [string]$clientId,
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
        [string]$clientSecret,
        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]$configFile,
        [Parameter(ParameterSetName = 'Manual')]
        [Parameter(ParameterSetName = 'File')]
        [int]$renewalLeadTime = 5,
        [Parameter(ParameterSetName = 'Manual')]
        [Parameter(ParameterSetName = 'File')]
        [switch]$SecureString,
        [Parameter(ParameterSetName = 'Manual')]
        [Parameter(ParameterSetName = 'File')]
        [switch]$ForceNewToken,
        [Parameter(ParameterSetName = 'Manual')]
        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Cache')]
        [ValidateSet('file', 'memory')]
        [string]$CacheType = 'File'
    )
    #region write a verbose log of the received parameters
    if ($PSCmdlet.ParameterSetName -eq 'Manual')
    {
        Write-Verbose "Using parameters from the command line"
        foreach ($param in $PSBoundParameters.Keys)
        {
            Write-Verbose "$($param): $($PSBoundParameters[$param])"
        }
        $cacheFolder = $pwd
        Write-Verbose "Cache folder: $cacheFolder"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'File')
    {
        Write-Verbose "Using parameters from the config file $($configFile)"
        $cacheFolder = Split-Path -Path $configFile
        Write-Verbose "Cache folder: $cacheFolder"
    }
    else
    {
        Write-Error "Invalid parameter set. Use -configFile or -tenantId, -clientId, and -clientSecret."
        return $null
    }
    #Check if any other commandlines were past in the default set and add them to the verbose log.
    Write-Verbose "Checking any other commandlines passed in the default set."
    foreach ($param in $PSBoundParameters.Keys)
    {
        Write-Verbose "$($param): $($PSBoundParameters[$param])"
    }
    #endregion

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
                    Write-Verbose "Token found in memory cache."
                    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
                    if ($accessTokenObject.access_token -and $accessTokenObject.AbsoluteExpiryTime -and $accessTokenObject.AbsoluteExpiryTime -gt $timeBuffer)
                    {
                        Write-Host "Access token is valid until $($accessTokenObject.AbsoluteExpiryTime)."
                        Write-Host "Using cached access token from memory."
                        return $accessTokenObject.access_token
                    }
                    else
                    {
                        Write-Host "Access token in memory is expired or invalid. Requesting a new one."
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
                    Write-Verbose "Cache file read successfully"
                    if (isEncrypted -data $accessTokenObject)
                    {
                        Write-Verbose "Access token is encrypted. Converting to plain text."
                        $accessToken = DecryptObject -encryptedObject $accessTokenObject -excludeFields 'AbsoluteExpiryTime'
                        Write-Verbose "Decrypted access token."
                    }
                    else
                    {
                        Write-Verbose "Access token is not a secure string. Using as is."
                        $accessToken = $accessTokenObject.access_token
                    }
                    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
                    Write-Verbose "we will renew the token $($renewalLeadTime) minutes before it expires, which will be on $($timeBuffer)"
                    if ($accessTokenObject.access_token -and $accessTokenObject.AbsoluteExpiryTime -and $accessTokenObject.AbsoluteExpiryTime -gt $timeBuffer)
                    {
                        Write-Host "Access token is valid until $($accessTokenObject.AbsoluteExpiryTime)."
                        Write-Host "Using cached access token from disk."
                        return $accessToken
                    }
                    else
                    {
                        Write-Host "Access token is expired or invalid. Requesting a new one."
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

    #region Check for config file
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
    }
    else
    {
        Write-Verbose "Using parameters from the command line"
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
            $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
            Write-Verbose "Converted to $($tokenExpiryTime)"
            Write-Verbose "Token absolute expiry time: $($tokenExpiryTime)"
            Write-Verbose "Creating hashtable for cached token"
            $cachedToken = [psCustomObject] @{
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
                Write-Verbose "Encrypting access token"
                $encryptedCashedToken = EncryptObject -plainObject $cachedToken -excludeFields 'AbsoluteExpiryTime'
                Write-Verbose "Saving access token to cache file: $cacheTokenFile"
                Write-Verbose "Creating cache folder if it does not exist"
                if (-not (Test-Path -Path $cacheFolder))
                {
                    Write-Verbose "Creating cache folder: $cacheFolder"
                    New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
                }
                Write-Verbose "Saving access token to disk cache."
                $encryptedCashedToken | ConvertTo-Json | Set-Content -Path $cacheTokenFile -Force
                #make the file hidden.
                Write-Verbose "Making cache file hidden"
                $hiddenFile = Get-Item -Path $cacheTokenFile -Force
                $hiddenFile.Attributes = 'Hidden'
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

