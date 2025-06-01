function FormatScopes()
{
    [CmdletBinding()]
    param(
        [string]$scopes,
        [switch]$AsIs,
        [switch]$Reverse
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] [FormatScopes] Called with AsIs=$AsIs, Reverse=$Reverse"
    #Check for null or empty scopes.
    if (-not $scopes)
    {
        Write-Verbose "[$functionName] [FormatScopes] No scopes provided. Returning empty string."
        return ""
    }
    #region Format scopes properly if necessary
    $scopesFormatted = $scopes
    Write-Verbose "[$functionName] [FormatScopes] Received a scope string of length $($scopes.Length) characters"
    if (!$AsIs -and $scopes -and -not $scopes.Contains("https://graph.microsoft.com/"))
    {
        Write-Verbose "[$functionName] [FormatScopes] Formatting scopes to include Graph API prefix"
        $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $formattedScopesArray = @()
        Write-Verbose "[$functionName] [FormatScopes] Processing scope array with $($scopesArray.Count) items"
        foreach ($scope in $scopesArray)
        {
            Write-Verbose "[$functionName] Processing scope: $scope"
            if ($scope -eq "offline_access")
            {
                $formattedScopesArray += $scope
                Write-Verbose "[$functionName] [FormatScopes] Added as is: $scope"
            }
            else
            {
                # Check if the scope already has the Graph prefix
                if (-not $scope.StartsWith("https://graph.microsoft.com/"))
                {
                    $formattedScopesArray += "https://graph.microsoft.com/$scope"
                    Write-Verbose "[$functionName] [FormatScopes] Added prefix: https://graph.microsoft.com/$scope"
                }
                else
                {
                    $formattedScopesArray += $scope
                    Write-Verbose "[$functionName] [FormatScopes] Added as is (already has prefix): $scope"
                }
            }
        }
        Write-Verbose "[$functionName] [FormatScopes] Count of Scopes formatted to include Graph API prefix: $($formattedScopesArray.count)"
        Write-Verbose "[$functionName] [FormatScopes] Converting from array back to string."
        $scopesFormatted = $formattedScopesArray -join ' '
    }
    elseif ($AsIs -and $scopes -and $scopes.Contains("https://graph.microsoft.com/"))
    {
        Write-Verbose "[$functionName] [FormatScopes] Reversing scopes already formatted with Graph API prefix"
        Write-Verbose "[$functionName] [FormatScopes] The type of scopes received is: $($scopes.GetType())"
        Write-Verbose "[$functionName] [FormatScopes] Converting into an array."
        $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $FormattedScopesArray = @()
        Write-Verbose "[$functionName] [FormatScopes] Processing scope array with $($scopesArray.Count) items"
        foreach ($scope in $scopesArray)
        {
            Write-Verbose "[$functionName] [FormatScopes] Processing scope: $scope"
            if ($scope.StartsWith("https://graph.microsoft.com/"))
            {
                Write-Verbose "[$functionName] [FormatScopes] Removing prefix from scope: $scope"
                $formattedScope = $scope -replace "https://graph.microsoft.com/", ""
                $formattedScopesArray += $formattedScope
                Write-Verbose "[$functionName] [FormatScopes] Scope is now $formattedScope"
            }
            else
            {
                $formattedScopesArray += $scope
                Write-Verbose "[$functionName] [FormatScopes] Added as is (no prefix): $scope"
            }
        }
        $scopesFormatted = $FormattedScopesArray
    }
    else
    {
        Write-Verbose "[$functionName] [FormatScopes] Scopes already properly formatted or empty"
    }
    Write-Verbose "[$functionName] [FormatScopes] Using scopes: $($scopesFormatted.count)"
    if (!$AsIs -and !$Reverse)
    {
        Write-Verbose "[$functionName] [FormatScopes] Checking for openid."
        if (-not $scopesFormatted.Contains("openid"))
        {
            $scopesFormatted = "openid $scopesFormatted"
            Write-Verbose "[$functionName] [FormatScopes] Added openid to scopes: $scopesFormatted"
        }
        else
        {
            Write-Verbose "[$functionName] [FormatScopes] openid already present in scopes."
        }
        Write-Verbose "[$functionName] [FormatScopes] Checking for offline_access."
        if (-not $scopesFormatted.Contains("offline_access"))
        {
            $scopesFormatted = "offline_access $scopesFormatted"
            Write-Verbose "[$functionName] [FormatScopes] Added offline_access to scopes: $scopesFormatted"
        }
        else
        {
            Write-Verbose "[$functionName] [FormatScopes] offline_access already present in scopes."
        }
    }
    else
    {
        Write-Verbose "[$functionName] [FormatScopes] Skipping openid and offline_access addition."
    }
    #endregion Format scopes
    return $scopesFormatted
}    

function Get-TokenFromResponse
{
    param($tokenResponse, $domain, $refreshToken)
    $functionName = $MyInvocation.MyCommand.Name
    $tokenExpiryTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
    Write-Verbose "[$functionName] Token absolute expiry time: $($tokenExpiryTime)"
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
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting HTTP listener function with redirectUri: $redirectUri"
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
            Write-Verbose "[$functionName] Local IP addresses: $($localIp -join ', ')"
        }
        catch
        {
            Write-Verbose "[$functionName] Could not get local IP address: $_"
        }
        # Create HTTP listener
        $listener = New-Object System.Net.HttpListener
        # Make sure redirect URI ends with a slash for matching
        $redirectUri = $redirectUri.TrimEnd('/') + '/'
        Write-Verbose "[$functionName] Using redirect URI: $redirectUri"
        # Add prefix
        $listener.Prefixes.Add($redirectUri)
        Write-Verbose "[$functionName] Added listener prefix: $redirectUri"
        # Start listener
        Write-Verbose "[$functionName] Starting HTTP listener..."
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
                        Write-Verbose "[$functionName] Received HTTP request"
                        # Get request details for diagnostics
                        $request = $context.Request
                        Write-Verbose "[$functionName] Request URL: $($request.Url)"
                        Write-Verbose "[$functionName] Request headers: $($request.Headers)"
                        # Check if QueryString exists and has keys
                        if ($null -ne $request.QueryString -and $request.QueryString.Count -gt 0)
                        {
                            Write-Verbose "[$functionName] Query string keys: $($request.QueryString.AllKeys -join ', ')"
                            # Check for code
                            $code = $request.QueryString.Get("code")
                            if ($null -ne $code)
                            {
                                Write-Verbose "[$functionName] Successfully retrieved authorization code"
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
                                    Write-Verbose "[$functionName] Error in response: $authError - $errorDescription"
                                    $result.ErrorMessage = "Authentication error: $authError - $errorDescription"
                                }
                                else
                                {
                                    Write-Verbose "[$functionName] No code or error found in query string"
                                    $result.ErrorMessage = "Authorization code not found in the response"
                                }
                            }
                        }
                        else
                        {
                            Write-Verbose "[$functionName] Query string is empty or null"
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
                    Write-Verbose "[$functionName] Error while waiting for request: $_"
                    Write-Verbose "[$functionName] Exception details: $($_.Exception.ToString())"
                    $result.ErrorMessage = "HTTP listener error: $($_.Exception.Message)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Listener is no longer listening"
                $result.ErrorMessage = "HTTP listener stopped unexpectedly"
                break
            }
            # Brief pause before checking again
            Start-Sleep -Milliseconds 100
        }
        # Check for timeout
        if ($stopwatch.Elapsed -ge $timeout)
        {
            Write-Verbose "[$functionName] Timeout waiting for authentication response"
            $result.ErrorMessage = "Timed out waiting for authentication response"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error in HTTP listener: $_"
        Write-Verbose "[$functionName] Exception details: $($_.Exception.ToString())"
        $result.ErrorMessage = "Failed to start HTTP listener: $($_.Exception.Message)"
    }
    finally
    {
        # Clean up
        if ($listener -and $listener.IsListening)
        {
            $listener.Stop()
            $listener.Close()
            Write-Verbose "[$functionName] HTTP listener stopped"
        }
    }
    return $result
}

function Save-TokenToCache
{
    param($cachedToken, $cacheType, $cacheTokenFile, $cacheFolder)
    $functionName = $MyInvocation.MyCommand.Name
    # Save access token according to cache type
    if ($cacheType -eq 'memory')
    {
        Write-Verbose "[$functionName] Saving access token to memory cache."
        $Global:MemoryCache['accessToken'] = $cachedToken
    }
    else
    {
        Write-Verbose "[$functionName] Saving access token to cache file: $cacheTokenFile"
        if (-not (Test-Path -Path $cacheFolder))
        {
            Write-Verbose "[$functionName] Creating cache folder: $cacheFolder"
            New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
        }
        $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
        Write-Verbose "[$functionName] Access token saved to $cacheTokenFile"
    }
}

function Save-RefreshTokenToConfig
{
    param($refreshToken, $configFilePath)
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] [Save-RefreshTokenToConfig] Called with configFilePath=$configFilePath, refreshToken provided=$($null -ne $refreshToken)"
    if (-not $refreshToken)
    {
        Write-Verbose "[$functionName] No refresh token to save"
        return
    }

    $DeligatedCredentials = @{}
    try
    {
        Write-Verbose "[$functionName] Saving refresh token to config file: $configFilePath"
        # Read the current config
        $config = Get-Content -Raw -Path $configFilePath | ConvertFrom-Json
        if (isEncrypted -data $config)
        {
            Write-Verbose "[$functionName] Config file is encrypted. Decrypting."
            $decryptedConfig = DecryptObject -encryptedObject $config -excludeFields @('domain', 'name', 'scope')
            if ($decryptedConfig.deligatedCredentials)
            {
                Write-Verbose "[$functionName] Updating existing deligatedCredentials property"
                $decryptedConfig.deligatedCredentials.refresh_token = $refreshToken.refresh_token
                if ($refreshToken.scope)
                {
                    Write-Verbose "[$functionName] Updating existing scope in deligatedCredentials"
                    $formattedScopes = FormatScopes -scopes $refreshToken.scope -AsIs -Reverse
                    $decryptedConfig.deligatedCredentials.scope = $formattedScopes 
                }
            }
            else
            {
                Write-Verbose "[$functionName] Creating new deligatedCredentials property"
                $decryptedConfig | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $DeligatedCredentials
                $decryptedConfig.deligatedCredentials.refresh_token = $refreshToken.refresh_token
                if ($refreshToken.scope)
                {
                    Write-Verbose "[$functionName] Adding scope to new deligatedCredentials"
                    $formattedScopes = FormatScopes -scopes $refreshToken.scope -AsIs -Reverse
                    $decryptedConfig.deligatedCredentials.scope = $formattedScopes
                }
            }
            # Re-encrypt the config
            Write-Verbose "[$functionName] Re-encrypting config with refresh token"
            $Config = EncryptObject -DecryptedObject $decryptedConfig -excludeFields @('domain', 'name', 'scope')
        }
        else
        {
            Write-Verbose "[$functionName] Config is not encrypted, updating directly"
            if (-not $config.deligatedCredentials)
            {
                Write-Verbose "[$functionName] Creating new deligatedCredentials property"
                $config | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $emptyDeligatedCredentials
            }
        }
        # Save the updated config
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -Force
        Write-Verbose "[$functionName] Refresh token saved to config file"
    }
    catch
    {
        Write-Error "Failed to save refresh token to config: $_"
    }
}

function Format-TokenOutput
{
    param($token, $secureString)
    $functionName = $MyInvocation.MyCommand.Name
    if ($secureString)
    {
        Write-Verbose "[$functionName] Converting access token to secure string"
        $secureAccessToken = ConvertTo-SecureString -String $token -AsPlainText -Force
        Write-Verbose "[$functionName] Returning secure token"
        return $secureAccessToken
    }
    else
    {
        Write-Verbose "[$functionName] Returning plain text access token"
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
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Testing refresh token validity..."
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
        Write-Verbose "[$functionName] Attempting to validate refresh token by getting a new access token..."
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $refreshTokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $refreshTokenRequestBody
        Write-Verbose "[$functionName] Refresh token is valid. Successfully obtained a new access token."
        return $true, $tokenResponse
    }
    catch
    {
        Write-Verbose "[$functionName] Refresh token validation failed: $_"
        Write-Verbose "[$functionName] Refresh token appears to be invalid or expired."
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
    $functionName = $MyInvocation.MyCommand.Name
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
        Write-Verbose "[$functionName] Checking whether to save the refresh token..."
        if ($tokenResponse.refresh_token -and $tokenResponse.refresh_token -ne $accessTokenObject.refresh_token)
        {
            Write-Verbose "[$functionName] Saving new refresh token as it differs from the existing one."
            Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
        }
        else
        {
            Write-Verbose "[$functionName] No need to save refresh token as it hasn't changed."
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
    $functionName = $MyInvocation.MyCommand.Name
    $accessTokenObject = $null
    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
        
    # Get token from memory cache
    if ($cacheType -eq 'memory')
    {
        Write-Verbose "[$functionName] Using memory cache for access token."
        if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
        {
            Write-Verbose "[$functionName] Initializing memory cache."
            New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
        }
            
        if ($Global:MemoryCache.ContainsKey('accessToken'))
        {
            $accessTokenObject = $Global:MemoryCache['accessToken']
                
            if ($accessTokenObject.domain -eq $domain)
            {
                Write-Verbose "[$functionName] Domain matches. Using cached token."
                Write-Verbose "[$functionName] Token for $domain found in memory cache."
                    
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
            Write-Verbose "[$functionName] No token found in memory cache."
            # Check if we have a refresh token in config even if there's no memory cache
            if ($Deligated -and $configRefreshToken)
            {
                Write-Verbose "[$functionName] No access token in memory, but found refresh token in config."
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
            Write-Verbose "[$functionName] Cache file exists: $cacheTokenFile"
            try
            {
                $accessTokenObject = Get-Content -Path $cacheTokenFile -Raw -Force | ConvertFrom-Json
                    
                if ($accessTokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Domain matches. Using cached token."
                    $accessToken = $accessTokenObject.access_token
                        
                    # Handle time formats
                    if ($accessTokenObject.AbsoluteExpiryTime -is [string])
                    {
                        $absoluteExpiryTime = [datetime]::Parse($accessTokenObject.absoluteExpiryTime).ToLocalTime()
                        if ($absoluteExpiryTime -lt $accessTokenObject.AbsoluteExpiryTime)
                        {
                            Write-Verbose "[$functionName] Resolving time differences between UTC and local time."
                            $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                        }
                    }
                    else
                    {
                        $absoluteExpiryTime = $accessTokenObject.AbsoluteExpiryTime
                    }
                        
                    Write-Verbose "[$functionName] Absolute Expiry Time: $absoluteExpiryTime"
                    Write-Verbose "[$functionName] We will renew the token $($renewalLeadTime) minutes before it expires."
                        
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
                    Write-Verbose "[$functionName] Domain $domain does not match cached token domain $($accessTokenObject.domain)."
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
                Write-Verbose "[$functionName] No access token in file cache, but found refresh token in config."
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
    param($tenantId, $clientId, $clientSecret, $scopes, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $configFilePath, $configRefreshToken, $AuthType)
    $functionName = $MyInvocation.MyCommand.Name
    # First check if we have a valid refresh token in config
    if ($configRefreshToken)
    {
        Write-Verbose "[$functionName] Found refresh token in config. Testing its validity before requesting new authorization..."
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
        if ($isValid)
        {
            Write-Host "Existing refresh token is valid. Using it without requesting a new authorization."
            $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $configRefreshToken
            # Cache the access token
            Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
            # We don't need to save the refresh token again since it's the same one
            Write-Verbose "[$functionName] Using existing refresh token that is still valid."
            return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
        }
        else
        {
            Write-Verbose "[$functionName] Existing refresh token is invalid. Will proceed with new authorization."
        }
    }
    # Generate a random state string
    Write-Verbose "[$functionName] Generating random state string."
    $state = [System.Guid]::NewGuid().ToString()
    $scopesFormatted = FormatScopes -scopes $scopes
    $encodedScopes = [uri]::EscapeDataString($scopesFormatted)
    
    $automaticFlowSuccess = $false
    switch ($AuthType)
    {
        PublicAuthFlow
        {
            Write-Verbose "[$functionName] Using device auth flow."
            $deviceCodeRequestUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"
            Write-Verbose "[$functionName] Device code request URL: $deviceCodeRequestUrl"
            $deviceCodeRequestBody = @{
                client_id = $clientId
                scope     = "$resource/DeviceManagementManagedDevices.ReadWrite.All $resource/offline_access openid profile email" # offline_access for refresh token if needed later
            }
            Write-Verbose "[$functionName] Requesting device code with body: $($deviceCodeRequestBody | ConvertTo-Json -Depth 3)"
            try
            {
                $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri $deviceCodeRequestUrl -Body $deviceCodeRequestBody
                Write-Verbose "[$functionName] Device code response: $($deviceCodeResponse | ConvertTo-Json -Depth 3)"
            }
            catch
            {
                Write-Error "Error requesting device code: $($_.Exception.Message)"
                Write-Error "Response: $($_.Exception.Response.GetResponseStream() | ForEach-Object { New-Object System.IO.StreamReader($_) } | ForEach-Object { $_.ReadToEnd() })"
                return $null
            }
            Write-Host ""
            Write-Host $deviceCodeResponse.message
            Write-Host "Waiting for authentication..."
            Write-Host ""
            # --- Poll for Access Token ---
            Write-Verbose "[$functionName] Polling for access token using device code."
            $tokenRequestUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
            $tokenRequestBody = @{
                grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                client_id   = $clientId
                device_code = $deviceCodeResponse.device_code
            }
            $accessToken = $null
            $timeoutSeconds = $deviceCodeResponse.expires_in # Typically 15 minutes
            Write-Verbose "[$functionName] Token request URL: $tokenRequestUrl"
            Write-Verbose "[$functionName] Token request body: $($tokenRequestBody | ConvertTo-Json -Depth 3)"
            Write-Verbose "Timeout for polling: $timeoutSeconds seconds"
            $intervalSeconds = $deviceCodeResponse.interval # Typically 5 seconds
            Write-Verbose "Polling interval: $intervalSeconds seconds"
            $startTime = Get-Date
            Write-Verbose "[$functionName] Start time for polling: $startTime"
            while ((Get-Date -UFormat %s) -lt ($startTime.AddSeconds($timeoutSeconds) | Get-Date -UFormat %s))
            {
                Write-Verbose "[$functionName] Polling for access token..."
                Start-Sleep -Seconds $intervalSeconds
                try
                {
                    $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenRequestUrl -Body $tokenRequestBody -ErrorAction SilentlyContinue
                    Write-Verbose "[$functionName] Polling attempt successful."
                    Write-Verbose "[$functionName] Token response: $($tokenResponse | ConvertTo-Json -Depth 3)"
                    if ($tokenResponse.access_token)
                    {
                        $accessToken = $tokenResponse.access_token
                        Write-Host "Authentication successful. Access token acquired."
                        break
                    }
                    elseif ($tokenResponse.error -ne "authorization_pending")
                    {
                        Write-Error "Error polling for token: $($tokenResponse.error_description)"
                        return $null
                    }
                }
                catch
                {
                    # Handle potential network errors during polling, but continue if it's just pending
                    Write-Warning "Polling attempt failed: $($_.Exception.Message)"
                }
                Write-Host -NoNewline "."
            }
            if (-not $accessToken)
            {
                Write-Error "Authentication timed out or failed."
                return $null
            }
        }
        'interactive'
        {
            Write-Verbose "[$functionName] Using interactive authentication flow."
            $redirectUri = "http://localhost:8080/"
            Write-Verbose "[$functionName] Redirect URI: $redirectUri"
            $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
            Write-Verbose "[$functionName] Encoded Redirect URI: $encodedRedirectUri"
            Write-Verbose "[$functionName] Attempting automatic HTTP listener flow"
            try
            {
                Write-Verbose "[$functionName] Starting HTTP listener at $redirectUri"
                $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=$encodedScopes&state=$state"
                Write-Verbose "[$functionName] Authorization URL: $authUrl"
                Write-Host "Opening browser for user authentication and consent..."
                Start-Process $authUrl
                $listenerResult = Start-HttpListener -redirectUri $redirectUri
                if ($listenerResult.Success)
                {
                    Write-Verbose "[$functionName] HTTP listener successfully captured the authorization code"
                    $code = $listenerResult.Code
                    $automaticFlowSuccess = $true
                }
                else
                {
                    Write-Warning "HTTP listener failed to capture the authorization code: $($listenerResult.ErrorMessage)"
                    Write-Verbose "[$functionName] Will fall back to manual code input"
                    $automaticFlowSuccess = $false
                }
            }
            catch
            {
                Write-Warning "Error in automatic HTTP listener flow: $_"
                Write-Verbose "[$functionName] Will fall back to manual code input"
                $automaticFlowSuccess = $false
            }
        }
        'Private'
        {
            Write-Verbose "[$functionName] Using non-interactive mode (manual code input)"
            $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
            Write-Verbose "[$functionName] Redirect URI: $redirectUri"
            $encodedRedirectUri = [uri]::EscapeDataString($redirectUri)
            Write-Verbose "[$functionName] Encoded Redirect URI: $encodedRedirectUri"
        }
        default
        {
            Write-Error "Invalid AuthType specified. Use 'interactive' or 'device'."
            return $null
        }
    }
    
    # Fall back to manual code input if automatic flow failed
    if (-not $automaticFlowSuccess)
    {
        # Step 1: Open the authorization URL
        $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$encodedRedirectUri&response_mode=query&scope=$encodedScopes&state=$state"
        Write-Verbose "[$functionName] Authorization URL: $authUrl"
        Write-Host "Opening browser for user authentication and consent..."
        Start-Process $authUrl
        Write-Host "After granting consent, copy the 'code' parameter from the redirected URL and paste it below."
        $code = Read-Host "Enter the authorization code"
        Write-Verbose "[$functionName] Received authorization code input from user"
        #The $code string above contains the intire URL. Extract the code from the URL.
        if ($code -match '.*code=([^&]+).*')
        {
            $code = $Matches[1]
            Write-Verbose "[$functionName] Extracted code from URL: $($code.Substring(0, [Math]::Min(10, $code.Length)))..."
        }
        else
        {
            Write-Warning "Could not extract code parameter from the provided URL"
            Write-Verbose "[$functionName] Input received: $($code.Substring(0, [Math]::Min(30, $code.Length)))..."
        }
    }           
    # Regardless of how we got the code, exchange it for a token
    if ($code -and $AuthType -ne 'PublicAuthFlow')
    {
        Write-Verbose "[$functionName] Exchanging authorization code for access token"
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $tokenRequestBody = @{
            client_id     = $clientId
            client_secret = $clientSecret
            code          = $code
            redirect_uri  = $redirectUri
            grant_type    = "authorization_code"
            scope         = $scopesFormatted
        }
        Write-Verbose "[$functionName] Token request parameters:"
        Write-Verbose "[$functionName]   Endpoint: $tokenEndpoint"
        Write-Verbose "[$functionName]   Client ID: $clientId"
        Write-Verbose "[$functionName]   Redirect URI: $redirectUri"
        Write-Verbose "[$functionName]   Grant Type: authorization_code"
        Write-Verbose "[$functionName]   Scopes: $scopesFormatted"
        try
        {
            Write-Verbose "[$functionName] Sending token request to $tokenEndpoint"
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $tokenRequestBody -ErrorVariable tokenError
            Write-Verbose "[$functionName] Access token received successfully"
        }            
        catch
        {
            Write-Error "Failed to get delegated access token: $_"
            if ($tokenError)
            {
                Write-Verbose "[$functionName] Error details: $($tokenError | Out-String)"
                if ($_.ErrorDetails.Message)
                {
                    Write-Verbose "[$functionName] Error message details: $($_.ErrorDetails.Message)"
                    try
                    {
                        $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                        Write-Verbose "[$functionName] Error JSON: $($errorJson | ConvertTo-Json -Depth 3)"
                        Write-Verbose "[$functionName] Error code: $($errorJson.error)"
                        Write-Verbose "[$functionName] Error description: $($errorJson.error_description)"
                    }
                    catch
                    {
                        Write-Verbose "[$functionName] Could not convert error details to JSON: $_"
                    }
                }
            }
            if ($_.Exception.Response)
            {
                Write-Verbose "[$functionName] Status code: $($_.Exception.Response.StatusCode)"
                # Try to get more information from the response
                try
                {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    Write-Verbose "[$functionName] Response body: $responseBody"
                    try
                    {
                        $responseJson = $responseBody | ConvertFrom-Json
                        Write-Verbose "[$functionName] Error code: $($responseJson.error)"
                        Write-Verbose "[$functionName] Error description: $($responseJson.error_description)"
                    }
                    catch
                    {
                        Write-Verbose "[$functionName] Could not parse response body as JSON"
                    }
                }
                catch
                {
                    Write-Verbose "[$functionName] Could not read response stream: $_"
                }
            }
            return $null
        }
    }
    
    # Log the token response properties (without exposing the actual token)
    if ($tokenResponse)
    {
        Write-Verbose "[$functionName] Token response contains the following properties:"
        foreach ($prop in $tokenResponse.PSObject.Properties.Name)
        {
            if ($prop -eq "access_token" -or $prop -eq "refresh_token" -or $prop -eq "id_token")
            {
                {
                    $tokenLength = $tokenResponse.$prop.Length
                    Write-Verbose "[$functionName]   $($prop): [Token of length $tokenLength]"
                }
                else
                {
                    Write-Verbose "[$functionName]   $($prop): $($tokenResponse.$prop)"
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
    }
    else 
    {
        Write-Verbose "[$functionName] Token response is null. Authorization code exchange failed."
        return $null
    }
}

function Get-ClientCredentialsToken
{
    param($tenantId, $clientId, $clientSecret, $domain, $cacheType, $cacheTokenFile, $cacheFolder)
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Using non-delegated access..."
    Write-Verbose "[$functionName] Requesting new access token with client credentials flow"
    $body = @{
        client_id     = $clientId
        scope         = 'https://graph.microsoft.com/.default'
        client_secret = $clientSecret
        grant_type    = 'client_credentials'
    }
    Write-Verbose "[$functionName] Token request body: client_id=$clientId, scope=https://graph.microsoft.com/.default, grant_type=client_credentials"
    try
    {
        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        Write-Verbose "[$functionName] Sending request to token endpoint: $tokenEndpoint"
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorVariable restError
            
        Write-Verbose "[$functionName] Access token received successfully"
        Write-Verbose "[$functionName] Token expires in: $($tokenResponse.expires_in) seconds"
            
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
            Write-Verbose "[$functionName] Error details: $($restError | Out-String)"
        }
            
        if ($_.Exception.Response)
        {
            Write-Verbose "[$functionName] Status code: $($_.Exception.Response.StatusCode)"
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorMessage = $streamReader.ReadToEnd()
            $streamReader.Close()
            Write-Error "Server Response: $errorMessage"
            
            try
            {
                $errorJson = $errorMessage | ConvertFrom-Json
                Write-Verbose "[$functionName] Error code: $($errorJson.error)"
                Write-Verbose "[$functionName] Error description: $($errorJson.error_description)"
            }
            catch
            {
                Write-Verbose "[$functionName] Could not parse error message as JSON: $_"
            }
        }
        return $null
    }
}

#region Encryption functions
$excludeFields = @('domain', 'name', 'scopes')
function TestIsBase64String
{
    param (
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value))
    {
        return $false
    }
    # A common check: length must be a multiple of 4.
    # And it should not contain characters outside the Base64 character set.
    # This is a basic check; more robust validation might be needed for edge cases.
    if (($Value.Length % 4 -ne 0) -or ($Value -notmatch "^[a-zA-Z0-9+/]*=*$"))
    {
        return $false
    }

    try
    {
        $null = [Convert]::FromBase64String($Value)
        return $true
    }
    catch
    {
        return $false
    }
}

function isEncrypted
{
    [CmdletBinding()]
    param (
        [psObject]$data
    )
    
    function CountEncryptionStatus
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject
        )
        
        $result = [PSCustomObject]@{
            EncryptedCount   = 0
            UnencryptedCount = 0
        }
        
        if ($null -eq $InputObject)
        {
            return $result
        }
        
        if ($InputObject -is [array])
        {
            foreach ($item in $InputObject)
            {
                $itemStatus = CountEncryptionStatus -InputObject $item
                $result.EncryptedCount += $itemStatus.EncryptedCount
                $result.UnencryptedCount += $itemStatus.UnencryptedCount
            }
        }
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    $nestedStatus = CountEncryptionStatus -InputObject $prop.Value
                    $result.EncryptedCount += $nestedStatus.EncryptedCount
                    $result.UnencryptedCount += $nestedStatus.UnencryptedCount
                }
                elseif ($prop.Value -is [string] -and $prop.Value.Length -gt 0)
                {
                    Write-Verbose "Checking if the value of $($prop.Name) is encrypted."
                    if (TestIsBase64String -Value $prop.Value)
                    {
                        Write-Verbose "The value of $($prop.Name) is encrypted."
                        $result.EncryptedCount++
                    }
                    else
                    {
                        Write-Verbose "The value of $($prop.Name) is not encrypted."
                        $result.UnencryptedCount++
                    }
                }
                else
                {
                    Write-Verbose "The value of $($prop.Name) is not a string, skipping."
                    $result.UnencryptedCount++
                }
            }
        }
        else
        {
            if ($InputObject -is [string] -and $InputObject.Length -gt 0)
            {
                if (TestIsBase64String -Value $InputObject)
                {
                    $result.EncryptedCount++
                }
                else
                {
                    $result.UnencryptedCount++
                }
            }
            else
            {
                $result.UnencryptedCount++
            }
        }
        
        return $result
    }
    
    $isEncrypted = $false
    Write-Verbose 'Checking if the data is encrypted.'
    
    $encryptionStatus = CountEncryptionStatus -InputObject $data
    $encryptedCount = $encryptionStatus.EncryptedCount
    $unencryptedCount = $encryptionStatus.UnencryptedCount
    
    Write-Verbose "The number of encrypted values is $encryptedCount"
    Write-Verbose "The number of unencrypted values is $unencryptedCount"
    
    # If the number of encrypted values is greater than the number of unencrypted values, the data is encrypted.
    if ($encryptedCount -gt $unencryptedCount -and $encryptedCount -gt 0)
    {
        $isEncrypted = $true
    }
    
    Write-Verbose "The data is encrypted: $isEncrypted"
    return $isEncrypted
}

function DecryptObject
{
    [CmdletBinding()]
    param (
        [object]$encryptedObject,
        [string[]]$excludeFields
    )
    
    function Invoke-RecursiveDecryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            return $null 
        }
        Write-Verbose "[DECRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[DECRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveDecryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[DECRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
        
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
            
                Write-Verbose "[DECRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[DECRYPT] Value type: $($value.GetType().FullName)"
            
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
            
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveDecryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($value -is [string] -and (TestIsBase64String -Value $value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($value))
                            $result[$key] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for key '$key' at path '$currentPropertyPath'. Value: '$value'. Assigning original value."
                            $result[$key] = $value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Hashtable key '$key' is not a decodable string. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
        
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[DECRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[DECRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[decrypt] Property type: $($prop.Value.GetType().FullName)"
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($prop.Value -is [string] -and (TestIsBase64String -Value $prop.Value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($prop.Value))
                            $result[$prop.Name] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for property '$($prop.Name)' at path '$currentPropertyPath'. Value: '$($prop.Value)'. Assigning original value."
                            $result[$prop.Name] = $prop.Value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Property '$($prop.Name)' is not a decodable string. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string element directly in an array)
        elseif ($InputObject -is [string])
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this string) was excluded
            {
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            elseif (TestIsBase64String -Value $InputObject)
            {
                Write-Verbose ("[DECRYPT] Attempting to decrypt primitive string value at path '{0}'" -f $ParentPath)
                try
                {
                    $decodedValuePrim = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
                    Write-Verbose ("[DECRYPT] Decrypted primitive value at path '{0}': {1}" -f $ParentPath, $decodedValuePrim)
                    return $decodedValuePrim
                }
                catch
                {
                    Write-Warning "[DECRYPT] Failed to decode Base64 string for primitive at path '$ParentPath'. Value: '$InputObject'. Returning original value."
                    return $InputObject # Keep original if not valid Base64 or UTF8
                }
            }
            else
            {
                # Not Base64, return as is
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is not Base64. Returning as-is."
                return $InputObject
            }
        }
        else # Other primitive types (int, bool, etc.) or other object types, return as is
        {
            Write-Verbose "[DECRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not a string or already handled. Returning as-is."
            return $InputObject
        }
    }
    
    $result = Invoke-RecursiveDecryption -InputObject $encryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were decrypted.'
        return $null
    }
    
    Write-Verbose "Decryption complete"
    return $result
}

function EncryptObject
{
    [CmdletBinding()]
    param (
        [object]$decryptedObject,
        [string[]]$excludeFields
    )


    function Invoke-RecursiveEncryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            Write-Verbose "[ENCRYPT] InputObject is null at path '$ParentPath'. Returning null."; return $null 
        }
        Write-Verbose "[ENCRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[ENCRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveEncryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[ENCRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
        
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
            
                Write-Verbose "[ENCRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Value type: $($value.GetType().FullName)"
                Write-Verbose "[ENCRYPT] Value: $value"
            
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
            
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[ENCRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($null -eq $value)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' has null value. Assigning null."
                    $result[$key] = $null
                }
                elseif ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveEncryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$key] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, $encodedValue)
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Hashtable key '$key' value type '$($value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
        
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[ENCRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[ENCRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Property type: $($prop.Value.GetType().FullName)"
                if ($prop.Name -in $excludeFields)
                {
                    Write-Verbose "[ENCRYPT] Property value: $($prop.Value)"    
                }
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded
                Write-Verbose "[ENCRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"
                if ($null -eq $prop.Value)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is null. Assigning null."
                    $result[$prop.Name] = $null
                }
                elseif ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $prop.Value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$prop.Name] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, 'redacted')
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Property '$($prop.Name)' type '$($prop.Value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string/number/bool element directly in an array)
        elseif (($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [bool] -or $InputObject -is [double]))
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this primitive) was excluded
            {
                Write-Verbose "[ENCRYPT] Primitive value at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            else
            {
                Write-Verbose ("[ENCRYPT] Encrypting primitive value at path '{0}'" -f $ParentPath)
                $stringValuePrim = $InputObject.ToString()
                $encodedValuePrim = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValuePrim))
                Write-Verbose ("[ENCRYPT] Encrypted primitive value at path '{0}': {1}" -f $ParentPath, $encodedValuePrim)
                return $encodedValuePrim
            }
        }
        else # Other types not explicitly handled (e.g. custom objects not PSCustomObject/hashtable, or other primitive types if any), return as is.
        {
            Write-Verbose "[ENCRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not processed for encryption. Returning as-is."
            return $InputObject
        }
    }

    $result = Invoke-RecursiveEncryption -InputObject $decryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were encrypted.'
        return $null
    }
    
    Write-Verbose "Encryption complete"
    return $result
}

function DecryptAndEncrypt()
{
    param (
        $data,
        [string[]]$excludeFields = $excludeFields,
        [string]$operation
    )
    
    # ### Main script ###
    if ($operation -eq 'encrypt')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is already encrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = EncryptObject -decryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'decrypt')
    {
        if (!(isEncrypted -data $data))
        {
            Write-Host 'The data is already decrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = DecryptObject -encryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'check')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is encrypted.'
        }
        else
        {
            Write-Host "The data in $inputFile is not encrypted."
        }
        exit
    }
    else
    {
        Write-Error 'No operation was specified.'
        exit
    }


    #make sure the output file exists.  If so, prompt to overwrite., otherwise create, unless the Force switch is set.
    if (Test-Path $outputFile)
    {
        if ($Force)
        {
            Clear-Content -Path $OutputFile
        }
        else
        {
            $overwrite = Read-Host -Prompt "The file $outputFile already exists.  Do you want to overwrite it? (Y/N)"
            if ($overwrite -eq 'Y')
            {
                Clear-Content -Path $OutputFile
            }
            else
            {
                Write-Host "The file $outputFile was not overwritten.  Exiting."
                exit
            }
        }
    }
    else
    {
        New-Item -Path $OutputFile -ItemType File -Force | Out-Null
    }


    #write the encoded data to the output file if it is not null.
    if ($encodedData)
    {
        Write-Host "Processing data in $inputFile"
        Write-Host "Writing data to $outputFile"
        Write-Verbose "The encoded data is: $($encodedData | ConvertTo-Json)"
       
        $encodedData | ConvertTo-Json | Set-Content -Path $outputFile -ErrorAction Stop
        Write-Host 'Data processed successfully.'
    }
    else
    {
        Write-Host 'No data was processed.'
        exit
    }
}
#endregion Encryption functions

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
        [ValidateSet('PublicAuthFlow', 'Interactive', 'Private')]
        [string]$AuthType = 'Private',
        [switch]$ForceNewToken,
        [ValidateSet('file', 'memory')]
        [string]$CacheType = 'Memory'
    )
    #region Main function logic
    $functionName = $MyInvocation.MyCommand.Name
    # Read and process configuration file
    if (-not $configFile)
    {
        Write-Error "Config file not found. Please provide a valid config file."
        return $null
    }
    
    Write-Verbose "[$functionName] Reading config file $configFile"
    try
    {
        $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        Write-Verbose "[$functionName] Config file loaded successfully"
        Write-Verbose "[$functionName] Decrypting values from $configFile"
        $configRefreshToken = $null
        if (isEncrypted -data $config)
        {
            Write-Verbose "[$functionName] Config file is encrypted. Decrypting."
            $config = DecryptObject -encryptedObject $config -excludeFields @('domain', 'name')
            # Extract the refresh token if it exists
            if ($config.deligatedCredentials.refresh_token)
            {
                $configRefreshToken = $config.deligatedCredentials.refresh_token
                Write-Verbose "[$functionName] Found refresh token in encrypted config."
            }
        }
        else
        {
            Write-Verbose "[$functionName] Config file is not encrypted. Using as is."
            # Extract the refresh token if it exists
            if ($config.deligatedCredentials.refresh_token)
            {
                $configRefreshToken = $config.deligatedCredentials.refresh_token
                Write-Verbose "[$functionName] Found refresh token in config."
            }
        }
    
        $tenantId = $config.tenantId
        $clientId = $config.appId
        $clientSecret = $config.appSecret
        $domain = $config.domain
    
        Write-Verbose "[$functionName] Config file values:"
        Write-Verbose "[$functionName]   Domain: $domain"
        Write-Verbose "[$functionName]   Tenant ID: $tenantId"
        Write-Verbose "[$functionName]   Client ID: $clientId" 
        Write-Verbose "[$functionName]   Client Secret: [REDACTED]"
        Write-Verbose "[$functionName]   Has refresh token: $($null -ne $configRefreshToken)"
    }
    catch
    {
        Write-Error "Failed to read or process config file: $_"
        return $null
    }
    
    #region Log parameters
    Write-Verbose "[$functionName] Received parameters:"
    Write-Verbose "[$functionName] Configuration File: $configFile"
    Write-Verbose "[$functionName] Renewal Lead Time: $renewalLeadTime"
    Write-Verbose "[$functionName] Secure String: $SecureString"
    Write-Verbose "[$functionName] Force New Token: $ForceNewToken"
    Write-Verbose "[$functionName] Use Public Auth Flow: $UsePublicAuthFlow"
    Write-Verbose "[$functionName] Interactive: $Interactive"
    Write-Verbose "[$functionName] Cache Type: $CacheType"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] Deligated: $Deligated"
    Write-Verbose "[$functionName] Scopes: $Scopes"
    Write-Verbose "[$functionName] Config has refresh token: $($null -ne $configRefreshToken)"
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

function ProcessFilterCondition
{
    [CmdletBinding()]
    param(
        [string]$condition
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing filter condition: $condition"
    # Check if this is a function-based filter (contains, startswith, endswith)
    Write-Verbose "[$functionName] Checking for function-based filter..."
    if ($condition -match '(startswith|contains|endswith)\s*\(([^,]+),\s*([^)]+)\)')
    {
        Write-Verbose "[$functionName] Found function-based filter: $($Matches[1])"
        $filterOperator = $Matches[1]
        Write-Verbose "[$functionName] Filter Operator: $filterOperator"
        $filterKey = $Matches[2].Trim()
        Write-Verbose "[$functionName] Filter Key: $filterKey"
        $filterValue = $Matches[3].Trim()
        Write-Verbose "[$functionName] Filter Value: $filterValue"
        # Remove quotes if present in the value
        Write-Verbose "[$functionName] Removing quotes from filter value..."
        $filterValue = $filterValue -replace "^'|'$", ""
        Write-Verbose "[$functionName] Filter Value after removing double quotes: $filterValue"
        $filterValue = $filterValue -replace '^"|"$', ""
        Write-Verbose "[$functionName] Filter Value after removing single quotes: $filterValue"
        Write-Verbose "[$functionName] Filter Key after removing quotes: $FilterKey"
        Write-Verbose "[$functionName] Filter Value: $FilterValue"
        Write-Verbose "[$functionName] Filter Operator: $FilterOperator"
        $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
        Write-Verbose "[$functionName] Encoded Filter Value: $encodedFilterValue"
        # Rebuild the function call with encoded value
        $returnFilter = "$filterOperator($filterKey,'$encodedFilterValue')"
        Write-Verbose "[$functionName] Returning filter: $returnFilter"
        return $returnFilter
    }
    # Check for standard comparison operators
    elseif ($condition -match '([^\s]+)\s+(eq|ne|gt|lt|ge|le)\s+(.+)')
    {
        Write-Verbose "[$functionName] Not a function based filter. Checking for standard comparison operators..."
        $filterKey = $Matches[1].Trim()
        $filterOperator = $Matches[2].Trim()
        $filterValue = $Matches[3].Trim()
        Write-Verbose "[$functionName] Filter Key: $FilterKey"
        Write-Verbose "[$functionName] Filter Operator: $FilterOperator"
        Write-Verbose "[$functionName] Filter Value: $FilterValue"
        # Special handling for null and empty string
        Write-Verbose "[$functionName] Checking for null or empty string..."
        if ($filterValue -eq "null" -or $filterValue -eq "''" -or $filterValue -eq '""')
        {
            Write-Verbose "[$functionName] Filter value is null or empty string."
            Write-Verbose "[$functionName] Returning filter without encoding: $filterKey $filterOperator $filterValue"
            # Don't encode null or empty string values
            return "$filterKey $filterOperator $filterValue"
        }
        else
        {
            # Remove quotes if present
            Write-Verbose "[$functionName] Checking for quotes and removing from value if present..."
            Write-Verbose "[$functionName] Value before processing: $filterValue"
            $filterValue = $filterValue -replace "^'|'$", ""
            Write-Verbose "[$functionName] Value after removing double quotes: $filterValue"
            $filterValue = $filterValue -replace '^"|"$', ""
            Write-Verbose "[$functionName] Value after removing single quotes: $filterValue"
            Write-Verbose "[$functionName] Filter Key: $FilterKey"
            Write-Verbose "[$functionName] Filter Value: $FilterValue"
            $encodedFilterValue = [uri]::EscapeDataString($FilterValue)
            Write-Verbose "[$functionName] Encoded Filter Value: $encodedFilterValue"
            # Add quotes back for the encoded value
            $returnFilter = "$filterKey $filterOperator '$encodedFilterValue'"
            Write-Verbose "[$functionName] Returning filter: $returnFilter"
            return $returnFilter
        }
    }
    else
    {
        Write-Verbose "[$functionName] Unrecognized filter condition format: $condition"
        return $condition
    }
}

function CallGraphAPI()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$ResourcePath,
        [string]$APIVersion = 'beta',
        [string]$method = 'get',
        [string]$Filter = $null,
        [string]$ExtraParameters = $null,
        [string]$body = $null,
        [switch]$consistencyLevel,
        [switch]$secureString
    )
    
    #region variables and logs
    $functionName = $MyInvocation.MyCommand.Name
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    else
    {
        Write-Host 'Access token not provided. Please provide a valid access token.' -ForegroundColor Red
        return
    }
    Write-Verbose "[$functionName] Resource Path: $ResourcePath"
    Write-Verbose "[$functionName] Method: $method"
    Write-Verbose "[$functionName] Filter: $filter"
    Write-Verbose "[$functionName] Extra Parameters: $ExtraParameters"
    Write-Verbose "[$functionName] Version: $APIVersion"
    Write-Verbose "[$functionName] Consistency Level: $consistencyLevel"
    Write-Verbose "[$functionName] Body: $body"
    Write-Verbose "[$functionName] SecureString: $secureString"
    $uri = "https://graph.microsoft.com/$APIVersion/$ResourcePath"
    $statusCode = $null
    Write-Verbose "[$functionName] Uri: $uri"
    #endregion

    #region Encode filter and add headers
    if ($Filter)
    {
        Write-Verbose "[$functionName] Processing filter string: $Filter"
        Write-Verbose "[$functionName] Splitting filter by logical operators while preserving operators."
        $filterParts = [System.Collections.ArrayList]::new()
        $logicalOperators = [System.Collections.ArrayList]::new()
        # Pattern to match a logical operator with surrounding spaces
        $pattern = '\s+(and|or)\s+'
        $lastIndex = 0
        # Find all logical operators and their positions
        $logicalOperaterMatches = [regex]::Matches($Filter, $pattern)
        Write-Verbose "[$functionName] Found $($logicalOperaterMatches.Count) logical operators."
        # If no logical operators, process as a single condition
        if ($logicalOperaterMatches.Count -eq 0)
        {
            Write-Verbose "[$functionName] No logical operators found. Processing as a single filter condition."
            $processedFilter = ProcessFilterCondition -condition $Filter
            Write-Verbose "[$functionName] Processed single filter condition: $processedFilter"
            $encodedFilter = $processedFilter
            Write-Verbose "[$functionName] Encoded filter: $encodedFilter"
        }
        else
        {
            # Process each part of the filter
            Write-Verbose "[$functionName] Logical operators found. Processing filter as multiple conditions."
            foreach ($logicalOperatorMatch in $logicalOperaterMatches)
            {
                Write-Verbose "[$functionName] Processing filter condition before logical operator: $($Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex))"
                $condition = $Filter.Substring($lastIndex, $logicalOperatorMatch.Index - $lastIndex)
                Write-Verbose "[$functionName] Condition to process: $condition"
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"
                # Store the logical operator (and, or)
                [void]$logicalOperators.Add($logicalOperatorMatch.Value.Trim())
                $lastIndex = $logicalOperatorMatch.Index + $logicalOperatorMatch.Length
                Write-Verbose "[$functionName] Logical operators so far: $($logicalOperators -join ', ')"
            }
            # Don't forget the last part after the last logical operator
            if ($lastIndex -lt $Filter.Length)
            {
                Write-Verbose "[$functionName] Processing filter condition after the last logical operator."
                $condition = $Filter.Substring($lastIndex)
                [void]$filterParts.Add((ProcessFilterCondition -condition $condition))
                Write-Verbose "[$functionName] Processed filter condition: $($filterParts[$filterParts.Count - 1])"
            }
            # Rebuild the filter string with processed parts and original logical operators
            Write-Verbose "[$functionName] Rebuilding the filter string with processed parts and logical operators."
            $encodedFilter = $filterParts[0]
            for ($i = 0; $i -lt $logicalOperators.Count; $i++)
            {
                $encodedFilter += " $($logicalOperators[$i]) $($filterParts[$i+1])"
                Write-Verbose "[$functionName] Adding logical operator: $($logicalOperators[$i])"
            }
            Write-Verbose "[$functionName] Processed complex filter: $encodedFilter"
        }
        $encodedUri = "$uri`?`$filter=$([uri]::EscapeUriString($encodedFilter))"
        Write-Verbose "[$functionName] Uri after applying filters: $encodedUri"
    }
    else
    {
        Write-Verbose "[$functionName] No filter provided."
        $encodedUri = $uri
    }
    
    if ($extraParameters)
    {
        Write-Verbose "[$functionName] Extra parameters provided."
        Write-Verbose "[$functionName] Splitting the extra parameters by ampersand to get individual key-value pairs."
        # Initialize the parameter list
        $paramsList = @()
        # Split by ampersand to get individual key-value pairs
        $keyValuePairs = $extraParameters -split '&'
        Write-Verbose "[$functionName] Found $($keyValuePairs.Count) key-value pairs."
        foreach ($pair in $keyValuePairs)
        {
            Write-Verbose "[$functionName] Processing key-value pair: $pair"
            # Split each pair by equals sign to separate key and value
            $keyAndValue = $pair -split '=', 2
            if ($keyAndValue.Count -eq 2)
            {
                $key = $keyAndValue[0].Trim()
                $value = $keyAndValue[1].Trim()
                Write-Verbose "[$functionName] Key: $key"
                Write-Verbose "[$functionName] Value: $value"
                # Add the $ prefix to the key for OData parameters
                $formattedKey = "`$$key"
                Write-Verbose "[$functionName] Formatted Key with $ prefix: $formattedKey"
                # Add the formatted parameter to the list
                $paramsList += "$formattedKey=$value"
            }
            else
            {
                Write-Warning "Invalid parameter format: $pair - skipping"
            }
        }
        Write-Verbose "[$functionName] Final parameter list:"
        $paramsList | ForEach-Object { Write-Verbose $_ }
        # Join the parameters with & to create a complete query string
        $queryString = $paramsList -join '&'
        Write-Verbose "[$functionName] Final query string: $queryString"
        if ($filter) 
        {
            Write-Verbose "[$functionName] Adding extra parameters to the uri along with the filter."
            $encodedUri = "$encodedUri`&$queryString"
        }
        else
        {
            Write-Verbose "[$functionName] No filter provided. Adding extra parameters to the uri."
            $encodedUri = "$encodedUri`?$queryString"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No extra parameters provided."
    }
    if ($consistencyLevel)
    {
        Write-Verbose "[$functionName] Adding consistency level to the headers."
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        Write-Verbose "[$functionName] No consistency level provided."
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    #endregion

    #region prepare the call
    # Create parameter hashtable for splatting
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        $restParams['Body'] = $body
    }
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Verbose "[$functionName] Making the following call to Microsoft Graph:" 
    Write-Verbose "[$functionName] URI: $encodedUri." 
    Write-Verbose "[$functionName] Method: $method."
    #endregion
    try
    {
        $response = Invoke-RestMethod @restParams
        $response | ForEach-Object {
            if ($_.'@odata.nextLink')
            {
                $nextLink = $_.'@odata.nextLink'
                # $nextGroups = CallGraphAPI -accessToken $accessToken -ResourcePath $nextLink -Method GET
                $nextGroups = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing 
                $response.value += $nextGroups.value
            }
        }
        Write-Verbose "[$functionName] The call was successful."
        if ($response.count)
        {
            Write-Verbose "[$functionName] Number of objects returned: $($response.count)."
        }
        if ($response.value.Count)
        {
            Write-Verbose "[$functionName] Number of items returned: $($response.value.Count)."
        }
        if ($PSVersionTable.PSVersion.Major -ge 7)
        {
            Write-Verbose "[$functionName] Status code: $statusCode"
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
        }
    }
    catch
    {
        if ($null -eq $_.Exception.statusCode)
        {
            $statusCode = [regex]::Match($_.Exception.Message, '\d+').Value
            Write-Verbose "[$functionName] Status code: $statusCode"
            $statusCodeMessage = $_.Exception | Out-String
            Write-Verbose "[$functionName] Status code message: $statusCodeMessage"
            $statusMessage = $statusCodeMessage
        }
        else
        {
            $statusCode = $_.Exception.statuscode.value__
            $statusCodeMessage = $_.Exception.statuscode
            $statusMessage = $_.Exception.Message
        }
        switch ($statusCode)
        {
            400
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Bad request. Please check the resource name.' -ForegroundColor Red 
            }
            401
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Unauthorized. Please check your access token.' -ForegroundColor Red 
            }
            403
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Forbidden. You do not have permission to access this resource.' -ForegroundColor Red 
            }
            404
            {
                Write-Verbose "[$functionName] Status code: $statusCode"
                Write-Host 'Not found. The resource does not exist.' -ForegroundColor Red 
            }
            default
            {
                Write-Host 'An unknown error occurred. Please check the error message below.' -ForegroundColor Red 
                Write-Host "Error: $statusMessage" -ForegroundColor Red
                Write-Host "The status code is $statusCode"
                Write-Host "$statusCode indicates $statusCodeMessage"
                Write-Host "Status message: $statusMessage"
                Write-Host 'The full error message follows below:'
                Write-Host '----------------------------------------------------------'
                Write-Host "$_"
                if ($_.Exception.Response)
                {
                    $errorResponse = $_.Exception.Response.GetResponseStream()
                    $streamReader = New-Object System.IO.StreamReader($errorResponse)
                    $errorMessage = $streamReader.ReadToEnd()
                    $streamReader.Close()
                    Write-Error "Server Response: $errorMessage"
                }   
            }
        }
        Write-Verbose "[$functionName] Failed to call the Graph API: $_"
        Write-Verbose "[$functionName] The status code is $statusCode"
        Write-Verbose "[$functionName] $statusCode indicates $statusCodeMessage"
        Write-Verbose "[$functionName] Status message: $statusMessage"
        Write-Verbose "[$functionName] The full error message follows below:"
        Write-Verbose "[$functionName] ----------------------------------------------------------"
        Write-Verbose "[$functionName] Error: $($_)"
        Write-Verbose "[$functionName] Exception message: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Exception response: $($_.Exception.Response)"
        if ($_.Exception.Response -and $psversionTable.PSVersion.Major -ge 7)
        {
            {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($errorResponse)
                $errorMessage = $streamReader.ReadToEnd()
                $streamReader.Close()
                Write-Verbose "[$functionName] Server Response: $errorMessage"
            }   
        }
        # return $statusCode
        return $null
    }
    Write-Verbose "[$functionName] Response: $($response)"
    Write-Verbose "[$functionName] Response value: $($response.value)"
    return $response
}

