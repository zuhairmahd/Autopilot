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
        [parameter(parameterSetName = 'Deligated')]
        [switch]$Interactive,
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
    
    function Start-HttpListener
    {
        param (
            [string]$redirectUri
        )
        Write-Verbose "Starting HTTP listener function with redirectUri: $redirectUri"
        # Result object to return
        $result = @{
            Success      = $false
            Code         = $null
            ErrorMessage = $null
        }
        try
        {
            # Get local IP address for diagnostics
            try
            {
                $localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*Virtual*"}).IPAddress
                Write-Verbose "Local IP addresses: $($localIp -join ', ')"
            }
            catch
            {
                Write-Verbose "Could not get local IP address: $_"
            }
            # Create HTTP listener
            $listener = New-Object System.Net.HttpListener
            # Make sure redirect URI ends with a slash for matching
            $redirectUri = $redirectUri.TrimEnd('/') + '/'
            Write-Verbose "Using redirect URI: $redirectUri"
            # Add prefix
            $listener.Prefixes.Add($redirectUri)
            Write-Verbose "Added listener prefix: $redirectUri"
            # Start listener
            Write-Verbose "Starting HTTP listener..."
            $listener.Start()
            Write-Host "Waiting for authorization response. Please complete the sign in within your browser..."
            # Set timeout for listener
            $timeout = New-TimeSpan -Minutes 5
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            # Wait for the callback
            while ($stopwatch.Elapsed -lt $timeout)
            {
                # Check for pending request with a timeout
                if ($listener.IsListening)
                {
                    try
                    {
                        # Try to get context with a 15-second timeout
                        $task = $listener.GetContextAsync()
                        $timeoutTask = [System.Threading.Tasks.Task]::Delay(15000)
                        $completedTask = [System.Threading.Tasks.Task]::WhenAny($task, $timeoutTask).GetAwaiter().GetResult()
                        # If the HTTP request came in before timeout
                        if ($completedTask -eq $task)
                        {
                            $context = $task.GetAwaiter().GetResult()
                            Write-Verbose "Received HTTP request"
                            # Get request details for diagnostics
                            $request = $context.Request
                            Write-Verbose "Request URL: $($request.Url)"
                            Write-Verbose "Request headers: $($request.Headers)"
                            # Check if QueryString exists and has keys
                            if ($null -ne $request.QueryString -and $request.QueryString.Count -gt 0)
                            {
                                Write-Verbose "Query string keys: $($request.QueryString.AllKeys -join ', ')"
                                # Check for code
                                $code = $request.QueryString.Get("code")
                                if ($null -ne $code)
                                {
                                    Write-Verbose "Successfully retrieved authorization code"
                                    $result.Success = $true
                                    $result.Code = $code
                                }
                                else
                                {
                                    # Check if there's an error
                                    $authError = $request.QueryString.Get("error")
                                    $errorDescription = $request.QueryString.Get("error_description")
                                    if ($authError)
                                    {
                                        Write-Verbose "Error in response: $authError - $errorDescription"
                                        $result.ErrorMessage = "Authentication error: $authError - $errorDescription"
                                    }
                                    else
                                    {
                                        Write-Verbose "No code or error found in query string"
                                        $result.ErrorMessage = "Authorization code not found in the response"
                                    }
                                }
                            }
                            else
                            {
                                Write-Verbose "Query string is empty or null"
                                $result.ErrorMessage = "Empty query string in redirect response"
                            }
                            # Send response to browser
                            $response = $context.Response
                            $responseHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Authentication Complete</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f0f0f0; }
        .container { background-color: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); padding: 40px; text-align: center; max-width: 600px; }
        h1 { color: #0078d4; margin-bottom: 20px; }
        p { color: #333; font-size: 16px; line-height: 1.6; }
        .status { font-weight: bold; margin: 20px 0; padding: 10px; border-radius: 4px; }
        .success { background-color: #dff6dd; color: #107c10; }
        .error { background-color: #fde7e9; color: #d13438; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Authentication Response</h1>
        $(if ($result.Success) {
            '<div class="status success">Authentication successful! You can close this window and return to the application.</div>'
        } else {
            "<div class='status error'>Authentication error: $($result.ErrorMessage)</div>"
        })
        <p>You may close this window and return to the PowerShell window.</p>
    </div>
</body>
</html>
"@
                            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
                            $response.ContentLength64 = $buffer.Length
                            $response.ContentType = "text/html"
                            $response.StatusCode = 200
                            $response.OutputStream.Write($buffer, 0, $buffer.Length)
                            $response.Close()
                            # Break out of the loop
                            break
                        }
                    }
                    catch
                    {
                        Write-Verbose "Error while waiting for request: $_"
                        Write-Verbose "Exception details: $($_.Exception.ToString())"
                        $result.ErrorMessage = "HTTP listener error: $($_.Exception.Message)"
                    }
                }
                else
                {
                    Write-Verbose "Listener is no longer listening"
                    $result.ErrorMessage = "HTTP listener stopped unexpectedly"
                    break
                }
                # Brief pause before checking again
                Start-Sleep -Milliseconds 100
            }
            # Check for timeout
            if ($stopwatch.Elapsed -ge $timeout)
            {
                Write-Verbose "Timeout waiting for authentication response"
                $result.ErrorMessage = "Timed out waiting for authentication response"
            }
        }
        catch
        {
            Write-Verbose "Error in HTTP listener: $_"
            Write-Verbose "Exception details: $($_.Exception.ToString())"
            $result.ErrorMessage = "Failed to start HTTP listener: $($_.Exception.Message)"
        }
        finally
        {
            # Clean up
            if ($listener -and $listener.IsListening)
            {
                $listener.Stop()
                $listener.Close()
                Write-Verbose "HTTP listener stopped"
            }
        }
        return $result
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
                    $decryptedConfig | Add-Member -MemberType NoteProperty -Name 'refresh_token' -Value $refreshToken
                }
                # Re-encrypt the config
                Write-Verbose "Re-encrypting config with refresh token"
                $Config = EncryptObject -DecryptedObject $decryptedConfig -excludeFields @('domain', 'name')
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
                    $config | Add-Member -MemberType NoteProperty -Name 'refresh_token' -Value $refreshToken
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
        
        if ($interactive)
        {
            $redirectUri = "http://localhost:8080/"
        }
        else 
        {
            $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
        }

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
        
        # Attempt to fetch token using HTTP listener first
        $automaticFlowSuccess = $false
        $code = $null
        if (-not $Interactive)        
        {
            Write-Verbose "Using non-interactive mode (manual code input)"
            $automaticFlowSuccess = $false
        }
        else
        {
            # Try the automatic HTTP listener flow first
            try
            {
                Write-Verbose "Attempting automatic HTTP listener flow"
                $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=$encodedScopes&state=$state"
                Write-Verbose "Authorization URL: $authUrl"
                Write-Host "Opening browser for user authentication and consent..."
                Start-Process $authUrl
                $listenerResult = Start-HttpListener -redirectUri $redirectUri
                if ($listenerResult.Success)
                {
                    Write-Verbose "HTTP listener successfully captured the authorization code"
                    $code = $listenerResult.Code
                    $automaticFlowSuccess = $true
                }
                else
                {
                    Write-Warning "HTTP listener failed to capture the authorization code: $($listenerResult.ErrorMessage)"
                    Write-Verbose "Will fall back to manual code input"
                    $automaticFlowSuccess = $false
                }
            }
            catch
            {
                Write-Warning "Error in automatic HTTP listener flow: $_"
                Write-Verbose "Will fall back to manual code input"
                $automaticFlowSuccess = $false
            }
        }
        
        # Fall back to manual code input if automatic flow failed
        if (-not $automaticFlowSuccess)
        {
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
        }           
        # Regardless of how we got the code, exchange it for a token
        if ($code)
        {
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
        else
        {
            Write-Error "Failed to obtain authorization code. Cannot proceed with token request."
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
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDR7YFzPP0DIdQj
# z2VC/sWPH7vJP+srNwgWF6fl0RexZaCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAOBkSbr
# 6+lwVlNvAAAAA4GRMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDI4MDQxOTQxWhcNMjUwNTAx
# MDQxOTQxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# mf7+tbRuD3PX1o3SA5VcMyu24VWwwXFUAKuJ2oHdop3XXh7bGz5l0hJFpYa4AV53
# drxAPr+yqkrMkM7TGBUpHoh5GR72SDwxqL8vct8vk/RvPzGh00mADuoe6nZEmlhM
# b3hd1jSBshAAOp6YriYs5Ya4vczHUzGC2J0/v3grIM1Szrb1W192P9H/wrnvonL1
# 8RpqWqMBSTkmm+poFuQg8L4IOGFjNIwZbFtCoohbaAb8Le87voODb3PTZhSr6pY9
# PHE2z78757rwj9dBuCPDlJJ4p9IF8GcH9x+vtmESbzPr/oi38GOKlYH3d/oL86oJ
# 8otscnjWUswDBjFa3gzS3TsEDZZTVk3X065Nd4Z8ztaN1c21L1D1pgSH7DZpjK37
# WohRZ3EqLj7tdqBDXIBfXft3hKP9hqdTpQJscHlY3nroJO972+76ZUmx6gdFHPG9
# 8d6FXU0iP+VddIxaS80/lJLPp8/N07dvTXUD8CnJGkx7VpDDN0j5KH94qGcfWqxT
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFH/Gq1LSAubj5J7trvB4xaAA4rAxMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGpzME+ppSK7DG6k
# npXQw635cDKMdzVSx3mUysY/F872vnb5WTj+DoM/hUdH1oKsH6j6Vor3dshcU6IR
# GPGL0Mp8HPoqHbDoq1LR75T1IJA5SYB+yZH6TYkcjxDT4yhJ01rf74/x6JWtUi4Q
# Jjg22WFWxcD/UT5NmivRgQSMhQsLUKI9XaGBgYJuNSIJWkwYWaPBwoKpQz75IZDI
# sdl6311rU5IwkbUeXLvu7oInIBhv3hthwAzqho3u90KewmUZyP9Tma3pS8bXJXXg
# zeBLTk7vRYJzeDa+Wy0YD3gsAJqwnrTZ0VArs7eyFcK7G1go01B7ACd+YYi/FBt3
# EN59yRmn3vvJLLeFnfH8+7KOKr2JDiCnKnc4TdmiZOaZq1HV8s6ILDgfaWhrH7ve
# nKieancFYDNXomvmT7J1sOvZjMG/nBuhBfGTV8CoNXVOpNuW5et8biQuDu7ypPT8
# NDgcKpaz2Oj0AtOGgZYxY7jZF5diDx6vwF/aBwOKWTOunRnWo78z0vSsmUKPPkwm
# 1EhbhvpVWY7aSLqtQBAN8W5mle3fcw9mZt8Jk2BLlVIRJuDM2cUEuAUYXDr2Gl1Z
# lexNQUhLHDjcWCV8QidoXa6iq3pNnuphkbzUj2/t3i0vmKMnbMUniqjO0Gwl/rIf
# NJ7T5tGwLTVNY4jq1uPPD+ZqAhLYMIIG5zCCBM+gAwIBAgITMwADgZEm6+vpcFZT
# bwAAAAOBkTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyODA0MTk0MVoXDTI1MDUwMTA0MTk0
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJn+/rW0
# bg9z19aN0gOVXDMrtuFVsMFxVACridqB3aKd114e2xs+ZdISRaWGuAFed3a8QD6/
# sqpKzJDO0xgVKR6IeRke9kg8Mai/L3LfL5P0bz8xodNJgA7qHup2RJpYTG94XdY0
# gbIQADqemK4mLOWGuL3Mx1MxgtidP794KyDNUs629Vtfdj/R/8K576Jy9fEaalqj
# AUk5JpvqaBbkIPC+CDhhYzSMGWxbQqKIW2gG/C3vO76Dg29z02YUq+qWPTxxNs+/
# O+e68I/XQbgjw5SSeKfSBfBnB/cfr7ZhEm8z6/6It/BjipWB93f6C/OqCfKLbHJ4
# 1lLMAwYxWt4M0t07BA2WU1ZN19OuTXeGfM7WjdXNtS9Q9aYEh+w2aYyt+1qIUWdx
# Ki4+7XagQ1yAX137d4Sj/YanU6UCbHB5WN566CTve9vu+mVJseoHRRzxvfHehV1N
# Ij/lXXSMWkvNP5SSz6fPzdO3b011A/ApyRpMe1aQwzdI+Sh/eKhnH1qsUwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBR/xqtS0gLm4+Se7a7weMWgAOKwMTAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBqczBPqaUiuwxupJ6V0MOt
# +XAyjHc1Usd5lMrGPxfO9r52+Vk4/g6DP4VHR9aCrB+o+laK93bIXFOiERjxi9DK
# fBz6Kh2w6KtS0e+U9SCQOUmAfsmR+k2JHI8Q0+MoSdNa3++P8eiVrVIuECY4Ntlh
# VsXA/1E+TZor0YEEjIULC1CiPV2hgYGCbjUiCVpMGFmjwcKCqUM++SGQyLHZet9d
# a1OSMJG1Hly77u6CJyAYb94bYcAM6oaN7vdCnsJlGcj/U5mt6UvG1yV14M3gS05O
# 70WCc3g2vlstGA94LACasJ602dFQK7O3shXCuxtYKNNQewAnfmGIvxQbdxDefckZ
# p977ySy3hZ3x/Puyjiq9iQ4gpyp3OE3ZomTmmatR1fLOiCw4H2loax+73pyonmp3
# BWAzV6Jr5k+ydbDr2YzBv5wboQXxk1fAqDV1TqTbluXrfG4kLg7u8qT0/DQ4HCqW
# s9jo9ALThoGWMWO42ReXYg8er8Bf2gcDilkzrp0Z1qO/M9L0rJlCjz5MJtRIW4b6
# VVmO2ki6rUAQDfFuZpXt33MPZmbfCZNgS5VSESbgzNnFBLgFGFw69hpdWZXsTUFI
# Sxw43FglfEInaF2uoqt6TZ7qYZG81I9v7d4tL5ijJ2zFJ4qoztBsJf6yHzSe0+bR
# sC01TWOI6tbjzw/magIS2DCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGhAwghoMAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADgZEm6+vpcFZTbwAAAAOBkTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCAC4vpcaRzuTBahd45k93zItxCp
# sUEiMTdABvfjm2LxaDANBgkqhkiG9w0BAQEFAASCAYBk72MJQF1H8hAQ4CaV/kam
# 5QMQTqvSYqIH34WoLN9HmVhRCqctwzuRZkOTBEyLwUwrAQ+GeaiSVWHDYg5t3qdf
# 6vJqfzt2VR9muDhm+ajS8pGVRuTZCWKhGjqGerMuWCzfLViz0y6HvTturJKQH0E4
# rgNvf8WSs8HUonKMZ0R9PzRay2+NpzIzeo167bc5zxRuuImRvdJrG1WeB4vplNeZ
# 92D99IrYiS9bVjqdVR1W0k0YIdnuYgMMzQTzsRrkl204q8rPkYo77TN3AGVsy83Z
# m1AH23aflHEul9vbNeegbR05d2AvDEQ2l54xTHvD5U0eGTi10t0R63ijAwyY2ifU
# lKh6wkxBmrbtBQVRbGJ6yM1/FzjpccQ9t2UyO6UGToiY0UfzvUyeJK5xbBCWRZ55
# KV1Jka9qN9KTAnvjdpCjq6gK+BwhUIDz/MRoYkOU51lmQSDXzE7PbWIK0ZlvYBzH
# Sfu+zIAzkTrKIPyhUcILJ2Uv2nbjFTiszN+mK+3IpFKhgheQMIIXjAYKKwYBBAGC
# NwMDATGCF3wwghd4BgkqhkiG9w0BBwKgghdpMIIXZQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgkN5SDG2DJqauIE0yX1A3Oz0fqOSDSgNQwsMflT2y
# P14CBmf89zdP3RgTMjAyNTA0MjkwMzQzMjguNjMxWjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046NDVENi05NkM1LTVFNjMxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
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
# EzMAAABJcL2GqhZ4TDEAAAAAAEkwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU0WhcNMjUxMTE5MTg0ODU0WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046NDVENi05NkM1LTVFNjMxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA+pnMBEJ5wYi/nr7N
# 9J+y+uRiVD3AMm7/Q/hyzkTwT7NbQgYHobrt4NzYffDmTKX7EhoDOE0ivbiIlvSC
# p3AggM2AUVGQ3DpZRWYsTQJrPgEIK7JJ0WADhp8HOLAm3RDEfTkTyi2VZg4jJtYS
# MaQpgGPlp32JoQlHfWnYLNTwHoxhLEhuM2nv8tYkS0G30+SF+0jO4E61Zqr/oSHs
# xHE008r+dVyI5o6M9dCPczDaqAv/+aDc6QJ50tj/2Ug5uK8w3+otsQEh4R6n8JBD
# vXigwdJz8jgHdIzS5qTptOEHqzw0WiaSfA0xaF7AyeRYqe3KbD40UokOnXfiMJRb
# IXNz+wxi1tu1sKJIwPWP7PJFV4xnESb9uXsao5CCkWhCNqOZkbX2VKSkvjLVy3CC
# hpxTKZHgTsYERHg5goOr5svVmlI+zxZaPf7SzoLhk1eFiE2I8LUQ7hEs8oKfGtFk
# EwedPAjv7bpS1jKd5b6zjnTPGaNpI50Ulj3m4oqoQ1s0snP/tOOal3mVhsj9YbTK
# oY142uqgkiZhxrYMgIxkCAowm2OQDAWVhzITxjer/KGHzwnL4VX/1BSfJRs8LnI0
# GKDFhrMT3N1EufYiHEwvY+cw9wuvZVuSToLZzXDAWhqBbOClXL3e9z3dUlYolWRC
# LPgGWE9xCf6qrugNB2NZOrADiOMCAwEAAaOCAcswggHHMB0GA1UdDgQWBBRVjnhP
# XjrArN1QumQu7fwTWwJKCzAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAGF+OSZ1G/RYme6il24h6LDoni1m
# wawibMfur2XjEPdVwGjz91D3c7wavAVE1rnX1EKWyVJ1+QNCsN2EewZ9h3/Fhl1t
# YrjBz+6T4jgOzsgFEXiFhmuIieWMY2+eFMFSw4RcNUdP1fOJz1cNNPk12XL2W69y
# mUXhJLZjD1xVE98Y+Nt2NG0WPzXBHkzQW+rhepIsL1hQmgTWXs1cP/R/K7AT4VB8
# /D7X+u3U2HILtYJad72zlBYfQQZH5tsPsVjlBtRWYcMeAsdJzSNjsxOyWgyA6jqZ
# ivOm7wLuv1xS7yiaIfyTotDGNHJ1VGPwITrbTv0PQiirFLumFLIUEywIXqC1sudZ
# NxXI8z48QmuHH/KMPGkiFyq1E2XUB3PDjgjv5bCHV170f/Lgh+msMFqO/V3YoOfA
# jsRUdgJX7TlE4Dnp9NhPqLTcH8evZldegxHs6YzEflUovsJpBK6wCBuqt9TAqx1r
# H0REYeBmTVIVUh68i6yVmPFYsJazv8WXVDLbmSDuCrQ8kbv4MHdoYJy7dF/qmURf
# 9xkBuajORGaT+uRmDRLboMZHLIufi/pglNDt0Bb16+HvkJ654b+sTZ45SWNLmUb9
# QXKSt5iMMdCfzsM8LDsovzgeRG+Oal7YeLSi6GSOGxPLlcSvtXN2csLGzRPVNMJt
# FeaToNBfSPI9KyaIMYIGxDCCBsACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAElwvYaqFnhMMQAAAAAA
# STANBglghkgBZQMEAgEFAKCCBB0wEQYLKoZIhvcNAQkQAg8xAgUAMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwNDI5MDM0MzI4
# WjAvBgkqhkiG9w0BCQQxIgQgHS1lVSqOFEb641P3cpV8UHfj6+Hl1T9Xdtk4BRwH
# Ga4wgbkGCyqGSIb3DQEJEAIvMYGpMIGmMIGjMIGgBCBZKDgGu8T+xwIzm2AmYzwg
# NDM/08rlNoMjGGIJ5AbVIjB8MGWkYzBhMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVibGlj
# IFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAElwvYaqFnhMMQAAAAAASTCC
# At8GCyqGSIb3DQEJEAISMYICzjCCAsqhggLGMIICwjCCAisCAQEwggEIoYHgpIHd
# MIHaMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjo0NUQ2LTk2QzUtNUU2MzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMVACAL
# jk8yViMVfCNap6QGEogntH7UoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBBQUAAgUA67qT
# MTAiGA8yMDI1MDQyODIzNTIxN1oYDzIwMjUwNDI5MjM1MjE3WjB3MD0GCisGAQQB
# hFkKBAExLzAtMAoCBQDrupMxAgEAMAoCAQACAgwoAgH/MAcCAQACAhFKMAoCBQDr
# u+SxAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAWWkLy8Hqw3nuX78SUcQA
# Ak8VwpQCJla3/pkT3vyAv3R1E39wlZs3vqIn2a6pfY/RbXJaxwq7Ewp80CdM68u2
# tVJuKUT3Qc0RKOUfPfp16FoXMFj2QMX4ZnmRmRiSD4+p7NKmPDvSFFiJkZBZo4TL
# 8NHdHugD49ql/TFiUDaGdUEwDQYJKoZIhvcNAQEBBQAEggIAwMILgXO1v7Pim2kN
# +SV+sS46u0x9pXSmbPkjONBYsP2/D1nfdsZeJD7XPU1Kgq2ax8RrVOztZjsJNG0s
# eaq2FmLlBTBWcUIKJNwQhjlZcoQdRLY/27l4RY+OZ/BsAuWQ8cv65KyRUo/duaut
# qBF2jAQ7UaiCI7HbgognFdqjholRBRPDkne9JfRnRIzjmVLX8sagGd5M/OgCfiZo
# x96mW5Bm5g4/5NEUHqkTLV0rS79P/NilqygorzwFt+JQlb6iYH2kpD1WPC6o6vpq
# 2sefPzEuvl9qB4PzH+IM+yItwO/fVQcpq508ybyOfyngKskwPA11waLHWOocbYGl
# Ks0wtYpG34+sWQKU1a685M+rjWsV+rXRgHJkYR7JjwVFVjm4/2crY9zwBM4MP6z8
# H0w/16bkIDOkFdN7q2Ou9Pw8LGQe4UiyahyF8C4NDZWRpjdui60SIfxsf1lltD3j
# YNV0i5ojhT78XVBcnYGl3h7/U4CBnvYfsTn/Z5I6ZifJalWeYrclgjWniPYLcnZB
# qCBbtmBte528T3byBCdmqW9hwR3u23wAuogCKUJCG551nXVUgBK+gw4wq6AAPpsc
# QYP3HMnU6edmeZ4GBZSNio9f0I/LGyVoyhIwuB0PJbg8WGBP19oG7S8YGq9FHpDY
# s1wz2w+O2mBKZZulELoidbdLk5s=
# SIG # End signature block
