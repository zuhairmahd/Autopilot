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
        
        $cachedToken = [ordered] @{
            'domain'           = $domain
            access_token       = $tokenResponse.access_token
            AbsoluteExpiryTime = $tokenExpiryTime
            'expires_in'       = $tokenResponse.expires_in
        }
        
        # Add refresh token if available
        if ($refreshToken -or $tokenResponse.refresh_token)
        {
            $cachedToken.Add('refresh_token', $tokenResponse.refresh_token)
        }
        
        # Add scope if available
        if ($tokenResponse.scope)
        {
            $cachedToken.Add('scope', $tokenResponse.scope)
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
                Write-Verbose "Config file is encrypted. Decrypting."
                $decryptedConfig = DecryptObject -encryptedObject $config -excludeFields @('domain', 'name')
                # Check if refresh_token property exists and update it instead of adding
                if ($decryptedConfig.refresh_token)
                {
                    Write-Verbose "Refresh token property already exists. Updating value."
                    $decryptedConfig.refresh_token = $refreshToken
                }
                else
                {
                    Write-Verbose "Adding the refresh token..."
                    $decryptedConfig.Add('refresh_token', $refreshToken)
                }
                # Re-encrypt the config
                Write-Verbose "Re-encrypting config with refresh token"
                $Config = EncryptObject -PlainObject $decryptedConfig -excludeFields @('domain', 'name')
            }
            else
            {
                Write-Verbose "Config is not encrypted, updating directly"
                # Check if refresh_token property exists and update it instead of adding
                if ($config.refresh_token)
                {
                    Write-Verbose "Refresh token property already exists. Updating value."
                    $config.refresh_token = $refreshToken
                }
                else
                {
                    Write-Verbose "Adding the refresh token..."
                    $config.Add('refresh_token', $refreshToken)
                }
            }
            # Save the updated config
            $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -Force
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

    function Test-RefreshTokenValidity
    {
        param(
            $refreshToken,
            $clientId,
            $clientSecret,
            $tenantId,
            $scopes,
            $domain
        )
        
        Write-Verbose "Testing refresh token validity..."
        try
        {
            # Ensure scopes are properly formatted for the token refresh
            $scopesFormatted = $scopes
            if ($scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
            {
                $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
                $formattedScopesArray = @()
                foreach ($scope in $scopesArray)
                {
                    if ($scope -eq "offline_access")
                    {
                        $formattedScopesArray += $scope
                    }
                    else
                    {
                        $formattedScopesArray += "https://graph.microsoft.com/$scope"
                    }
                }
                $scopesFormatted = $formattedScopesArray -join ' '
            }
            $refreshTokenRequestBody = @{
                client_id     = $clientId
                client_secret = $clientSecret
                refresh_token = $refreshToken
                grant_type    = 'refresh_token'
                scope         = $scopesFormatted
            }
            $refreshTokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            Write-Verbose "Attempting to validate refresh token by getting a new access token..."
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $refreshTokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $refreshTokenRequestBody
            Write-Verbose "Refresh token is valid. Successfully obtained a new access token."
            return $true, $tokenResponse
        }
        catch
        {
            Write-Verbose "Refresh token validation failed: $_"
            Write-Verbose "Refresh token appears to be invalid or expired."
            return $false, $null
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
            # First test if the refresh token is valid
            $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $accessTokenObject.refresh_token -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
            if (-not $isValid)
            {
                Write-Host "Refresh token is invalid or expired."
                return $null
            }
            Write-Host "Successfully refreshed access token."
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $tokenResponse.refresh_token
            # Cache the access token based on cache type
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            # Only save the refresh token if it's different from the one we already have
            Write-Verbose "Checking whether to save the refresh token..."
            if ($tokenResponse.refresh_token -and $tokenResponse.refresh_token -ne $accessTokenObject.refresh_token)
            {
                Write-Verbose "Saving new refresh token as it differs from the existing one."
                Save-RefreshTokenToConfig -refreshToken $tokenResponse.refresh_token -configFilePath $configFilePath
            }
            else
            {
                Write-Verbose "No need to save refresh token as it hasn't changed."
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
        param($tenantId, $clientId, $clientSecret, $scopes, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $configFilePath, $configRefreshToken)
        # First check if we have a valid refresh token in config
        if ($configRefreshToken)
        {
            Write-Verbose "Found refresh token in config. Testing its validity before requesting new authorization..."
            $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
            if ($isValid)
            {
                Write-Host "Existing refresh token is valid. Using it without requesting a new authorization."
                $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $configRefreshToken
                # Cache the access token
                Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
                # We don't need to save the refresh token again since it's the same one
                Write-Verbose "Using existing refresh token that is still valid."
                return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
            }
            else
            {
                Write-Verbose "Existing refresh token is invalid. Will proceed with new authorization."
            }
        }
        
        # Generate a random state string
        Write-Verbose "Generating random state string."
        $state = [System.Guid]::NewGuid().ToString()
        $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
        
        #region Format scopes properly if necessary
        $scopesFormatted = $scopes
        Write-Verbose "Original scopes: $scopes"
        
        if ($scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
        {
            Write-Verbose "Formatting scopes to include Graph API prefix"
            $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
            $formattedScopesArray = @()
            
            Write-Verbose "Processing scope array with ${$scopesArray.Count} items"
            foreach ($scope in $scopesArray)
            {
                Write-Verbose "Processing scope: $scope"
                if ($scope -eq "offline_access")
                {
                    $formattedScopesArray += $scope
                    Write-Verbose "Added as is: $scope"
                }
                else
                {
                    # Check if the scope already has the Graph prefix
                    if (-not $scope.StartsWith("https://graph.microsoft.com/"))
                    {
                        $formattedScopesArray += "https://graph.microsoft.com/$scope"
                        Write-Verbose "Added with prefix: https://graph.microsoft.com/$scope"
                    }
                    else
                    {
                        $formattedScopesArray += $scope
                        Write-Verbose "Added as is (already has prefix): $scope"
                    }
                }
            }
            $scopesFormatted = $formattedScopesArray -join ' '
            Write-Verbose "Final formatted scopes: $scopesFormatted"
        }
        else
        {
            Write-Verbose "Scopes already properly formatted or empty"
        }
        
        Write-Verbose "Using scopes: $scopesFormatted"
        
        # Ensure scopes include openid and offline_access
        if (-not $scopesFormatted.Contains("openid"))
        {
            $scopesFormatted = "openid $scopesFormatted"
            Write-Verbose "Added openid to scopes: $scopesFormatted"
        }
        
        if (-not $scopesFormatted.Contains("offline_access"))
        {
            $scopesFormatted = "offline_access $scopesFormatted"
            Write-Verbose "Added offline_access to scopes: $scopesFormatted"
        }
        #endregion Format scopes

        # Encode parameters
        $encodedScopes = [uri]::EscapeDataString($scopesFormatted)
        $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
        
        # Step 1: Open the authorization URL
        $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=$encodedScopes&state=$state"
        Write-Verbose "Authorization URL: $authUrl"
        Write-Host "Opening browser for user authentication and consent..."
        Start-Process $authUrl
        Write-Host "After granting consent, copy the 'code' parameter from the redirected URL and paste it below."
        $code = Read-Host "Enter the authorization code"
        Write-Verbose "Received authorization code input from user"
        
        #The $code string above contains the intire URL. Extract the code from the URL.
        if ($code -match '.*code=([^&]+).*')
        {
            $code = $Matches[1]
            Write-Verbose "Extracted code from URL: $($code.Substring(0, [Math]::Min(10, $code.Length)))..."
        }
        else
        {
            Write-Warning "Could not extract code parameter from the provided URL"
            Write-Verbose "Input received: $($code.Substring(0, [Math]::Min(30, $code.Length)))..."
        }
        
        # Step 2: Exchange the code for a token
        Write-Verbose "Exchanging authorization code for access token"
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $tokenRequestBody = @{
            client_id     = $clientId
            client_secret = $clientSecret
            code          = $code
            redirect_uri  = $redirectUri
            grant_type    = "authorization_code"
            scope         = $scopesFormatted
        }
        
        Write-Verbose "Token request parameters:"
        Write-Verbose "  Endpoint: $tokenEndpoint"
        Write-Verbose "  Client ID: $clientId"
        Write-Verbose "  Redirect URI: $redirectUri"
        Write-Verbose "  Grant Type: authorization_code"
        Write-Verbose "  Scopes: $scopesFormatted"
        
        try
        {
            Write-Verbose "Sending token request to $tokenEndpoint"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $tokenRequestBody -ErrorVariable tokenError
            Write-Verbose "Access token received successfully"
            
            # Log the token response properties (without exposing the actual token)
            Write-Verbose "Token response contains the following properties:"
            foreach ($prop in $tokenResponse.PSObject.Properties.Name)
            {
                if ($prop -eq "access_token" -or $prop -eq "refresh_token" -or $prop -eq "id_token")
                {
                    $tokenLength = $tokenResponse.$prop.Length
                    Write-Verbose "  $($prop): [Token of length $tokenLength]"
                }
                else
                {
                    Write-Verbose "  $($prop): $($tokenResponse.$prop)"
                }
            }
            
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
            if ($tokenError)
            {
                Write-Verbose "Error details: $($tokenError | Out-String)"
                if ($_.ErrorDetails.Message)
                {
                    Write-Verbose "Error message details: $($_.ErrorDetails.Message)"
                    try
                    {
                        $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                        Write-Verbose "Error JSON: $($errorJson | ConvertTo-Json -Depth 3)"
                        Write-Verbose "Error code: $($errorJson.error)"
                        Write-Verbose "Error description: $($errorJson.error_description)"
                    }
                    catch
                    {
                        Write-Verbose "Could not convert error details to JSON: $_"
                    }
                }
            }
            
            if ($_.Exception.Response)
            {
                Write-Verbose "Status code: $($_.Exception.Response.StatusCode)"
                
                # Try to get more information from the response
                try
                {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    Write-Verbose "Response body: $responseBody"
                    
                    try
                    {
                        $responseJson = $responseBody | ConvertFrom-Json
                        Write-Verbose "Error code: $($responseJson.error)"
                        Write-Verbose "Error description: $($responseJson.error_description)"
                    }
                    catch
                    {
                        Write-Verbose "Could not parse response body as JSON"
                    }
                }
                catch
                {
                    Write-Verbose "Could not read response stream: $_"
                }
            }
            
            return $null
        }
    }
    
    function Get-ClientCredentialsToken
    {
        param($tenantId, $clientId, $clientSecret, $domain, $cacheType, $cacheTokenFile, $cacheFolder)
        
        Write-Verbose "Using non-delegated access..."
        Write-Verbose "Requesting new access token with client credentials flow"
        
        $body = @{
            client_id     = $clientId
            scope         = 'https://graph.microsoft.com/.default'
            client_secret = $clientSecret
            grant_type    = 'client_credentials'
        }
        
        Write-Verbose "Token request body: client_id=$clientId, scope=https://graph.microsoft.com/.default, grant_type=client_credentials"
        
        try
        {
            $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            Write-Verbose "Sending request to token endpoint: $tokenEndpoint"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorVariable restError
            
            Write-Verbose "Access token received successfully"
            Write-Verbose "Token expires in: $($tokenResponse.expires_in) seconds"
            
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain
            
            # Cache the token
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
        catch
        {
            Write-Error "Failed to get access token: $_"
            
            if ($restError)
            {
                Write-Verbose "Error details: $($restError | Out-String)"
            }
            
            if ($_.Exception.Response)
            {
                Write-Verbose "Status code: $($_.Exception.Response.StatusCode)"
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Error "Server Response: $errorMessage"
                
                try
                {
                    $errorJson = $errorMessage | ConvertFrom-Json
                    Write-Verbose "Error code: $($errorJson.error)"
                    Write-Verbose "Error description: $($errorJson.error_description)"
                }
                catch
                {
                    Write-Verbose "Could not parse error message as JSON: $_"
                }
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
        Write-Verbose "Config file loaded successfully"
        Write-Verbose "Decrypting values from $configFile"
        $configRefreshToken = $null
        if (isEncrypted -data $config)
        {
            Write-Verbose "Config file is encrypted. Decrypting."
            $config = DecryptObject -encryptedObject $config -excludeFields @('domain', 'name')
            # Extract the refresh token if it exists
            if ($config.refresh_token)
            {
                $configRefreshToken = $config.refresh_token
                Write-Verbose "Found refresh token in encrypted config."
            }
        }
        else
        {
            Write-Verbose "Config file is not encrypted. Using as is."
            # Extract the refresh token if it exists
            if ($config.refresh_token)
            {
                $configRefreshToken = $config.refresh_token
                Write-Verbose "Found refresh token in config."
            }
        }
        
        $tenantId = $config.tenantId
        $clientId = $config.appId
        $clientSecret = $config.appSecret
        $domain = $config.domain
        
        Write-Verbose "Config file values:"
        Write-Verbose "  Domain: $domain"
        Write-Verbose "  Tenant ID: $tenantId"
        Write-Verbose "  Client ID: $clientId" 
        Write-Verbose "  Client Secret: [REDACTED]"
        Write-Verbose "  Has refresh token: $($null -ne $configRefreshToken)"
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
                -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFile `
                -configRefreshToken $configRefreshToken
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
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBX73fh46etFb3S
# 1KVDSW8fKufgcBJScNABVSAl33qWlqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN5sikc
# 3EHQ6Gp9AAAAA3myMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwNDI3MDQyNDA1WhcNMjUwNDMw
# MDQyNDA1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# ovzp2dEJ0VpmlAuPsKtcIE1zRJYzwGF0rnzGQiLf4NyErp4nOWXuS9LAw3EgO5qj
# 34EvPahWPNSfM3UGmQgz9hp3ppFrnbuKLlW6NUpV1GXSKIzPMHpS0ZfQW6i9qVwR
# en+kod37jEQS7D8+PW4V1DCCuPflRWV7BRmBow8axDxc3tjiX0rowqSSIHWicCeh
# MLV2GWMq7hP1lJ0/y3e9XiCXxq2kG89EYN9duEwiEmTOzs4vsR7lDBgoPOhBkcfC
# rTjyQp/f0dwNjyIMdsrQ5ILF58cMRVJI1Qoayya+w5ltShuOQWNxFyvf9O/KoRSB
# eW4PjWTXLjvdRxzcEnrb3kJ7QjXzxpCIIXJKzCpzeqEr+bg2jDuSENmgAvGlPgGa
# jwAjwpTCzQKzpQICEs7g21MiBVVGcYSgPPCsu/76i5o0Qvx9Zo9lTK7Kw5Xo6bA+
# 7McjpTsmBi5M5yrw28Lys6AEkbE+XJQrEXwRlUEneCpYIcHSuLc1/yKe8MUkLmKJ
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFAwjrr8MMnrWNlVt6S3S59/V1Ld7MB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBABzdevuOZcUKbCKr
# MyWTeyoLOQyI8jnHrFG9u3wYspHASKn6+TkdbfeBjLrE4Y55LFbv8cuD8k0UiNlP
# dDUXrjM86VXXPhVmTwGFWA/RAiq5cMJqcyc00A6Jfdg40MCVE/NUEy7ho1K+cM31
# hzTa8p3w7Al+EZga5v0RK0+QoVcwelUc4X6SLfQmRU9tPuT9hmM3Q9mvkw55/T1N
# ndo5thW9Oe972njgnM82cZUJd5c2oG6Nw9bYiYbTp9K8ocP0ItE+VfScwYTfrWSK
# VKvcGYb2Y1IlwgzsuAcZly0nIHLjYa8OmnurbpZ9HwFW2ZOaAPP1tBbvrLJ/rBSd
# TMumzG2ulFnL761DvjqO5tW3yD031GEbcoolB3w3J6iu/q/NBTweNc+TUkbQLawJ
# jrKNWyWXXKig5l3XQ51QkaAgOnT+RKw/DsYI5UMlH4tD8pKRQ9ugVZOus4Rqx+af
# t1XBbtvWnglQuYqxmml36gvksCXR7o5J3bXJKvNx69lNtNbqIu17Tz1lRl27ZFPh
# I0/6ly/4LDXySKTZQx40PjTxHfFh55IBGWYh5VPA88cGaGnEVbYXClEh7vwQjF7u
# qhfLhC5qPoRDaVJIQiodBmwzihkDJVtKPEpMcDklY1hzh20CIV5CHu6pZGpUSk4T
# 4Saw5kH24b4EsjfMKHq89g/o22TfMIIG5zCCBM+gAwIBAgITMwADebIpHNxB0Ohq
# fQAAAAN5sjANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDQyNzA0MjQwNVoXDTI1MDQzMDA0MjQw
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAKL86dnR
# CdFaZpQLj7CrXCBNc0SWM8BhdK58xkIi3+DchK6eJzll7kvSwMNxIDuao9+BLz2o
# VjzUnzN1BpkIM/Yad6aRa527ii5VujVKVdRl0iiMzzB6UtGX0FuovalcEXp/pKHd
# +4xEEuw/Pj1uFdQwgrj35UVlewUZgaMPGsQ8XN7Y4l9K6MKkkiB1onAnoTC1dhlj
# Ku4T9ZSdP8t3vV4gl8atpBvPRGDfXbhMIhJkzs7OL7Ee5QwYKDzoQZHHwq048kKf
# 39HcDY8iDHbK0OSCxefHDEVSSNUKGssmvsOZbUobjkFjcRcr3/TvyqEUgXluD41k
# 1y473Ucc3BJ6295Ce0I188aQiCFySswqc3qhK/m4Now7khDZoALxpT4Bmo8AI8KU
# ws0Cs6UCAhLO4NtTIgVVRnGEoDzwrLv++ouaNEL8fWaPZUyuysOV6OmwPuzHI6U7
# JgYuTOcq8NvC8rOgBJGxPlyUKxF8EZVBJ3gqWCHB0ri3Nf8invDFJC5iiQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQMI66/DDJ61jZVbekt0uff1dS3ezAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQAc3Xr7jmXFCmwiqzMlk3sq
# CzkMiPI5x6xRvbt8GLKRwEip+vk5HW33gYy6xOGOeSxW7/HLg/JNFIjZT3Q1F64z
# POlV1z4VZk8BhVgP0QIquXDCanMnNNAOiX3YONDAlRPzVBMu4aNSvnDN9Yc02vKd
# 8OwJfhGYGub9EStPkKFXMHpVHOF+ki30JkVPbT7k/YZjN0PZr5MOef09TZ3aObYV
# vTnve9p44JzPNnGVCXeXNqBujcPW2ImG06fSvKHD9CLRPlX0nMGE361kilSr3BmG
# 9mNSJcIM7LgHGZctJyBy42GvDpp7q26WfR8BVtmTmgDz9bQW76yyf6wUnUzLpsxt
# rpRZy++tQ746jubVt8g9N9RhG3KKJQd8Nyeorv6vzQU8HjXPk1JG0C2sCY6yjVsl
# l1yooOZd10OdUJGgIDp0/kSsPw7GCOVDJR+LQ/KSkUPboFWTrrOEasfmn7dVwW7b
# 1p4JULmKsZppd+oL5LAl0e6OSd21ySrzcevZTbTW6iLte089ZUZdu2RT4SNP+pcv
# +Cw18kik2UMeND408R3xYeeSARlmIeVTwPPHBmhpxFW2FwpRIe78EIxe7qoXy4Qu
# aj6EQ2lSSEIqHQZsM4oZAyVbSjxKTHA5JWNYc4dtAiFeQh7uqWRqVEpOE+EmsOZB
# 9uG+BLI3zCh6vPYP6Ntk3zCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwADebIpHNxB0OhqfQAAAAN5sjAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDaRMsL9KlBpI7LAz+1DMLUt6Av
# oUXw+ETcDBhXer6ABTANBgkqhkiG9w0BAQEFAASCAYB7Obo8HyuFPYaC9mmwLPHi
# catGYbMG1h5OI2M3nHGw9rMAD6Jwn+MYTiHQobyMZSQctNtdwW2byZVv//IZQGSu
# ATgXRheAMhxRcNiI5eMlgzCKnv2kQU35xRKAEL7DHKYFp2ZktIbuiHTZEqwURtYF
# usKNlP1XCNreBfzFx5xK67qSxdJGL45CX68v/7IgS3dPjOzDYcwcbu2Lg1Ouj06V
# mtyIvUQ9HE0TNQa8LK+m86qmRtzDQJIDbM34jnKY1PAtO9+Ykgo6EB0NmghDZEor
# Dk5+odmUEoDsiaRmXx5nYQHbrfTASVCM/q7AOsceDkXN73mYxH+YZmjIpII4VaCm
# CQ7KbvgkuYtHFwmWlE4d2PO3Me6DIMNFdU5PWBhIu4i/efTL3Mt2YlZvGnmZzBd9
# 80ICJuOSLIxvvBw7gm5iOdNh1nHp+uWvTmIOrdVnuFR1aH65nOYDuWFRcgngiTlp
# hJf7vT1SXefw3Ka65TQEpCWDK1xEcfaNOvWigtABBqOhghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgTqp7lr0VTAOcPx+//PcBBexlt47OWmsQUGCxeA2c
# zG4CBmgLr1eWexgTMjAyNTA0MjgwMjIxMzguMjg3WjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046QkI3My05NkZELTc3RUYxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC
# EzMAAABF33vn5wwJFp4AAAAAAEUwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODQ3WhcNMjUxMTE5MTg0ODQ3WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046QkI3My05NkZELTc3RUYxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwI7T9DdCYDUnYfj4
# va+Mk9tdPmx23cLwlHHIA8ZEIuTEgrFV8F5gIAHDzvgdrLpaAfNYt5y+Vtpx5RHb
# FVJnRgnwWE3FrDKGO1r+kFXcXRCxzajb7rv7n+pBSwhwwKmQeiTA8UZNujosLQ1W
# 0ojOEL7xMc4l5mzLugA6CL618wL7gaZWwaOGq6RROC7Yv1r18+y1O2mSoEMzM3lV
# r3PvIj3UTmtbovReZOc7NlPuGPTAwjXtqpS16GU7Df4CrBvC9a5n9M15oqCtWjZE
# ZlsgfMzA28KvSKqqS/UyRBUwbLEC0kP6d/rOzyy0uxCgP259ntzUF6c+N7XmC5X0
# 4PFo7OSnKcsJ004j9W4gki6MtRHBlPW1hB3EUlPzMfx7vPVk+/0erh3DKe5UUiZ5
# 4aC6hclk3qc74OoRcXkRiqheE7fDLMmkGzGziMfii8o1K0fcDUhL1Etff2GL6G0N
# 3qs/2stJrtm4oyoURJawlTN5yJ85zzcF1XSaM7P595jhFz8gB4QBTvs67wQa5nrM
# JRHNWTlvqYbImoYYX7yhzmAULFO3essnrvIriGpi1pv4NvoPSsvgoQ70DjVUrDbi
# f8gwOlIefpcunbGYzCKNZC3rOexU6JGeU0NlZLA9UPaF3pxenjEFqsZWVr3JKf6/
# sbstAIFsyM2ZOMivlI8pfaWS4W8CAwEAAaOCAcswggHHMB0GA1UdDgQWBBQl0Nvq
# 9SXQRMmn8B3Grz2HYyuV8jAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAGy9tedaeCT4seFHGLKgQteRiPy0
# twNtoLqOU80gWazoi0L5DHQGhXiVDMVJb9zu1IU3J5unNxwad9hA6/4jeu/kHgZF
# z3EEszczT480nzwx69zWtVPuCH//b7h1qNZ0p7YKpamUDu1ZjBWuSmgPhK/GgVLX
# LO1TQ6ntrjbz8bMJf35HsUFWvCRrbPpX4hhNepUbL0jU3l1YECHoleDhtrnqV5v+
# rz/lXQxhGyVSjPh+NTg80Xwk8Of/7saYnvMdW28xoelULIYnFqTxPn+1vKJX1Qnl
# HzBBUtWKVDPU/fMERcU2UF052chin0TCQayP8cABd1jYYILQMatiYJzSLAAdNiPM
# x/clpoD0w13egpMD9B3bx0qyruz2MQK31KR4ZwoKGLfCwuuayzB2aEDcp3Q+SVGg
# ngYn8SaTjneUZLohh/Wk9A4LOkZhDBYjFQ1BotbTc9KYUV05JXNaheMSwRiFQuCe
# ZnTtqwhN+UpTO+lZGzBjxPYTXObQYrY6vsB4jzmgzV2+UkE6J2nczJP6LdijGr2P
# KPpQ3bVG8dpqnOaY8ahKtQouoTfJPHG25BrrX2whPch8xZBYSWn0NYj/yZKje/cr
# qJYvUoEALhomQbuBU5+Fv4U/R8xzMUGJgoeHIh8n9OoNN2JEtMOeypI6oTrGVRtK
# YtHyZmb4a5gUM8TXMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEXfe+fnDAkWngAAAAAA
# RTANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCDMNNkGaGMeFqx3PoKZALj7GnYoXznaqwSAdHSLxk7f
# lTCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEILgEVTrIyIo/ceMv5rhPHM70
# iM9F0uvKQRUOfiHf0m5xMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARd975+cMCRaeAAAAAABFMCIE
# IOmhLNjA0gqIOPkkKMUk/mPXUn8rZ6nRPaDxOVzDqYJIMA0GCSqGSIb3DQEBCwUA
# BIICAFyFWdLabGsmJfsD4Bh/iXzRjaw+1pllFkWtSC9KB9Wb4wLZuFQle9kYXahx
# 30Kw7Z+4Nam74QvVY05rau0umk7ATKsOdRV0OgAkZiMaNJOxVtNdypn1sNz8j+w4
# bTLYWBl00nvOGWeGNGiDuRLMYYZtMJyEMMUV++3k2elWyZTZ3oilmjDRe1Br3wiX
# TiUSaan6ylIxsv8rE1LWe3P4huk1m1Ip+3OSNG/l1NL4IEtm8QphY6+kE2xMtzSU
# mFSBtEMDqFq1T+HowfXdGrytTI4I3VKX3OCLRzy1ORmGs5kU9kzDlsB+H5jJuh68
# GKRB2tysbGg6K4xtFzRAtaZztWL8Eo9U6MuknVwkBpxoUbuft54Ec1KXuE4m07KN
# TKQaCbpW9jVQzIX/FCqwDLYZvjfVt7w28jcGL0WVLh8HzXwJ3UiNBsZlRYScdHen
# tLEqFW5AL1E/D9wWP+sjTRnJ2elRBmPI41+7/K0tn46f32kaFrfjJQYELU3TS+uB
# oj6/B1bud1XkPVNVq2/qx2F1VGBtED+RccxZY9cvpW5C43xk+/w+nP9um0Vssik6
# 4e75jQ/w202t2++f0XIZS+oQqS2XUsXbUB/va+/B445jIdEH1Xn6gwnof/SuQe3g
# xyC64fGhmkKD5mDm9qZtTuB1h92GBtlIKIy5MwTstR7Q6xOx
# SIG # End signature block
