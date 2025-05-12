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
    function FormatScopes()
    {
        [CmdletBinding()]
        param(
            [string]$scopes,
            [switch]$AsIs,
            [switch]$Reverse
        )

        Write-Verbose "[FormatScopes] Called with AsIs=$AsIs, Reverse=$Reverse"
        #region Format scopes properly if necessary
        $scopesFormatted = $scopes
        Write-Verbose "[FormatScopes] Received a scope string of length $($scopes.Length) characters"
        if (!$AsIs -and $scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
        {
            Write-Verbose "[FormatScopes] Formatting scopes to include Graph API prefix"
            $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
            $formattedScopesArray = @()
            Write-Verbose "[FormatScopes] Processing scope array with $($scopesArray.Count) items"
            foreach ($scope in $scopesArray)
            {
                Write-Verbose "Processing scope: $scope"
                if ($scope -eq "offline_access")
                {
                    $formattedScopesArray += $scope
                    Write-Verbose "[FormatScopes] Added as is: $scope"
                }
                else
                {
                    # Check if the scope already has the Graph prefix
                    if (-not $scope.StartsWith("https://graph.microsoft.com/"))
                    {
                        $formattedScopesArray += "https://graph.microsoft.com/$scope"
                        Write-Verbose "[FormatScopes] Added prefix: https://graph.microsoft.com/$scope"
                    }
                    else
                    {
                        $formattedScopesArray += $scope
                        Write-Verbose "[FormatScopes] Added as is (already has prefix): $scope"
                    }
                }
            }
            Write-Verbose "[FormatScopes] Count of Scopes formatted to include Graph API prefix: $($formattedScopesArray.count)"
            Write-Verbose "[FormatScopes] Converting from array back to string."
            $scopesFormatted = $formattedScopesArray -join ' '
        }
        elseif ($AsIs -and $scopes -and $scopes.Contains("https://graph.microsoft.com/"))
        {
            Write-Verbose "[FormatScopes] Reversing scopes already formatted with Graph API prefix"
            Write-Verbose "[FormatScopes] The type of scopes received is: $($scopes.GetType())"
            Write-Verbose "[FormatScopes] Converting into an array."
            $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
            $FormattedScopesArray = @()
            Write-Verbose "[FormatScopes] Processing scope array with $($scopesArray.Count) items"
            foreach ($scope in $scopesArray)
            {
                Write-Verbose "[FormatScopes] Processing scope: $scope"
                if ($scope.StartsWith("https://graph.microsoft.com/"))
                {
                    Write-Verbose "[FormatScopes] Removing prefix from scope: $scope"
                    $formattedScope = $scope -replace "https://graph.microsoft.com/", ""
                    $formattedScopesArray += $formattedScope
                    Write-Verbose "[FormatScopes] Scope is now $formattedScope"
                }
                else
                {
                    $formattedScopesArray += $scope
                    Write-Verbose "[FormatScopes] Added as is (no prefix): $scope"
                }
            }
            $scopesFormatted = $FormattedScopesArray
        }
        else
        {
            Write-Verbose "[FormatScopes] Scopes already properly formatted or empty"
        }
        Write-Verbose "[FormatScopes] Using scopes: $($scopesFormatted.count)"
        if (!$AsIs -and !$Reverse)
        {
            Write-Verbose "[FormatScopes] Checking for openid."
            if (-not $scopesFormatted.Contains("openid"))
            {
                $scopesFormatted = "openid $scopesFormatted"
                Write-Verbose "[FormatScopes] Added openid to scopes: $scopesFormatted"
            }
            else
            {
                Write-Verbose "[FormatScopes] openid already present in scopes."
            }
            Write-Verbose "[FormatScopes] Checking for offline_access."
            if (-not $scopesFormatted.Contains("offline_access"))
            {
                $scopesFormatted = "offline_access $scopesFormatted"
                Write-Verbose "[FormatScopes] Added offline_access to scopes: $scopesFormatted"
            }
            else
            {
                Write-Verbose "[FormatScopes] offline_access already present in scopes."
            }
        }
        else
        {
            Write-Verbose "[FormatScopes] Skipping openid and offline_access addition."
        }
        #endregion Format scopes
        return $scopesFormatted
    }    

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
        Write-Verbose "[Save-RefreshTokenToConfig] Called with configFilePath=$configFilePath, refreshToken provided=$($null -ne $refreshToken)"
        if (-not $refreshToken)
        {
            Write-Verbose "No refresh token to save"
            return
        }

        $DeligatedCredentials = @{}
        try
        {
            Write-Verbose "Saving refresh token to config file: $configFilePath"
            # Read the current config
            $config = Get-Content -Raw -Path $configFilePath | ConvertFrom-Json
            if (isEncrypted -data $config)
            {
                Write-Verbose "Config file is encrypted. Decrypting."
                $decryptedConfig = DecryptObject -encryptedObject $config -excludeFields @('domain', 'name', 'scope')
                if ($decryptedConfig.deligatedCredentials)
                {
                    Write-Verbose "Updating existing deligatedCredentials property"
                    $decryptedConfig.deligatedCredentials.refresh_token = $refreshToken.refresh_token
                    if ($refreshToken.scope)
                    {
                        Write-Verbose "Updating existing scope in deligatedCredentials"
                        $formattedScopes = FormatScopes -scopes $refreshToken.scope -AsIs -Reverse
                        $decryptedConfig.deligatedCredentials.scope = $formattedScopes 
                    }
                }
                else
                {
                    Write-Verbose "Creating new deligatedCredentials property"
                    $decryptedConfig | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $DeligatedCredentials
                    $decryptedConfig.deligatedCredentials.refresh_token = $refreshToken.refresh_token
                    if ($refreshToken.scope)
                    {
                        Write-Verbose "Adding scope to new deligatedCredentials"
                        $formattedScopes = FormatScopes -scopes $refreshToken.scope -AsIs -Reverse
                        $decryptedConfig.deligatedCredentials.scope = $formattedScopes
                    }
                }
                # Re-encrypt the config
                Write-Verbose "Re-encrypting config with refresh token"
                $Config = EncryptObject -DecryptedObject $decryptedConfig -excludeFields @('domain', 'name', 'scope')
            }
            else
            {
                Write-Verbose "Config is not encrypted, updating directly"
                if (-not $config.deligatedCredentials)
                {
                    Write-Verbose "Creating new deligatedCredentials property"
                    $config | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $emptyDeligatedCredentials
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
                Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
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
        $scopesFormatted = FormatScopes -scopes $scopes
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
                    Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
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
            if ($config.deligatedCredentials.refresh_token)
            {
                $configRefreshToken = $config.deligatedCredentials.refresh_token
                Write-Verbose "Found refresh token in encrypted config."
            }
        }
        else
        {
            Write-Verbose "Config file is not encrypted. Using as is."
            # Extract the refresh token if it exists
            if ($config.deligatedCredentials.refresh_token)
            {
                $configRefreshToken = $config.deligatedCredentials.refresh_token
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
