function Get-DelegatedToken()
{
    param($tenantId, $clientId, $clientSecret, [string[]]$scopes, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $configFilePath, $configRefreshToken, $AuthType, $NoSaveRefreshToken, $ForcedRenewal, $settings = $settings)
    $functionName = $MyInvocation.MyCommand.Name
    
    # Handle null or empty scopes by providing a sensible default
    if (-not $scopes -or $scopes -eq "")
    {
        Write-Verbose "[$functionName] Scopes parameter is null or empty. Using default Graph API scopes."
        $scopes = "offline_access openid Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All"
        Write-Host "Using default scopes as none were provided: $scopes" -ForegroundColor Yellow
    }
    
    Write-Verbose "[$functionName] Starting with scopes: '$scopes'"
    
    # Debug the incoming scopes parameter
    Write-Verbose "[$functionName] Received scopes parameter: '$scopes'"
    Write-Verbose "[$functionName] Scopes parameter type: $($scopes.GetType().Name)"
    if ([string]::IsNullOrEmpty($scopes))
    {
        Write-Warning "[$functionName] WARNING: Received null or empty scopes parameter!"
    }
    
    # First check if we have a valid refresh token in config
    if ($configRefreshToken)
    {
        Write-Verbose "[$functionName] Found refresh token in config. Testing its validity before requesting new authorization..."
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -AuthType $AuthType
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
            if ($ForcedRenewal)
            {
                Write-Host "Forcing new refresh token - proceeding with new authentication flow." -ForegroundColor Yellow
            }
        }
    }
    else
    {
        if ($ForcedRenewal)
        {
            Write-Host "No existing refresh token found or refresh token was cleared - proceeding with new authentication flow." -ForegroundColor Yellow
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
                scope     = $scopesFormatted
            }
            Write-Verbose "[$functionName] Original scopes parameter: '$scopes'"
            Write-Verbose "[$functionName] Formatted scopes: '$scopesFormatted'"
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
            #extract the code and copy it to the clipboard.
            $regex = "(?<=enter the code )([A-Z0-9]+)"
            if ($deviceCodeResponse.message -match $regex)
            {
                $code = $matches[1]
                Write-Verbose "[$functionName] Extracted code from device code response: $code"
                #now copy the code to the clipboard.
                try
                {
                    Set-Clipboard -Value $code
                    Write-Host "The code has been copied to the clipboard for you to paste."
                }
                catch
                {
                    Write-Warning "Failed to copy code to clipboard. Please copy it manually: $code"
                }
            }
            else
            {
                Write-Verbose "[$functionName] No code found in device code response message."
            }
            if ($settings.preferredBrowser -eq '' -or $null -eq $settings.preferredBrowser)
            {
                Write-Verbose "[$functionName] No preferred browser set in settings, using default browser."
                $preferredBrowser = 'Default'
                $displayMessage = "If you choose 'Yes', your default browser will be used for authentication."
            }
            else
            {
                Write-Verbose "[$functionName] Using preferred browser from settings: $($settings.preferredBrowser)"
                $preferredBrowser = $settings.preferredBrowser
                $displayMessage = "If you choose 'Yes', $preferredBrowser will be used for authentication."
                if ($settings.privateSession)
                {
                    $displayMessage += " A private session (incognito) will be used."
                }
            }
            Write-Verbose "[$functionName] Preferred browser for authentication: $preferredBrowser"
            $authUrl = "https://microsoft.com/devicelogin"
            Write-Verbose "[$functionName] Authentication URL: $authUrl"
            Write-Host "Would you like to open a browser to the authentication page?"
            Write-Host "`n$displayMessage"
            $userChoice = Read-Host "Type 'Yes' to open the browser, or 'No' to continue without opening a browser `n (you will need to manually open your browser to $authUrl)"
            while ($userChoice -notin @('Yes', 'No'))
            {
                Write-Host "Invalid choice. Please type 'Yes' or 'No'."
                #beep
                [console]::beep(1000, 500)
                $userChoice = Read-Host "Type 'Yes' to open the browser, or 'No' to continue without opening a browser"
            }
            if ($userChoice -eq 'Yes')
            {
                Write-Verbose "[$functionName] User chose to open browser for authentication."
                $browserOpened = LaunchBrowser -url $authUrl -browser $preferredBrowser
                if (-not $browserOpened)
                {
                    Write-Error "Failed to open browser for authentication. Please open it manually."
                }
            }
            else
            {
                Write-Verbose "[$functionName] User chose not to open browser, will continue with manual authentication."
                Write-Host "Please open your browser to $authUrl and paste the code: $code to sign-in"
            }
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
                        $automaticFlowSuccess = $true
                        break
                    }
                    elseif ($tokenResponse.error -ne "authorization_pending")
                    {
                        Write-Error "Error polling for token: $($tokenResponse.error_description)"
                        return $null
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Authorization still pending, continuing to poll..."
                    }
                }
                catch
                {
                    # Check if this is the expected "authorization_pending" error (400 Bad Request)
                    $isAuthPending = $false
                    
                    # Check the HTTP status code first
                    if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 400)
                    {
                        Write-Verbose "[$functionName] Received 400 Bad Request during polling - checking if authorization is pending..."
                        
                        # Multiple ways to detect authorization_pending:
                        # 1. Check the exception message for common patterns
                        $exceptionMessage = $_.Exception.Message
                        if ($exceptionMessage -like "*authorization_pending*" -or 
                            $exceptionMessage -like "*Bad Request*" -or
                            $exceptionMessage -like "*400*")
                        {
                            $isAuthPending = $true
                            Write-Verbose "[$functionName] Detected authorization_pending from exception message pattern"
                        }
                        
                        # 2. Try to parse the response body if available
                        if (-not $isAuthPending)
                        {
                            try
                            {
                                $errorResponse = $_.Exception.Response.GetResponseStream()
                                if ($errorResponse -and $errorResponse.CanRead)
                                {
                                    $streamReader = New-Object System.IO.StreamReader($errorResponse)
                                    $errorMessage = $streamReader.ReadToEnd()
                                    $streamReader.Close()
                                    
                                    if ($errorMessage)
                                    {
                                        $errorJson = $errorMessage | ConvertFrom-Json
                                        if ($errorJson.error -eq "authorization_pending")
                                        {
                                            $isAuthPending = $true
                                            Write-Verbose "[$functionName] Confirmed authorization_pending from response body"
                                        }
                                    }
                                }
                            }
                            catch
                            {
                                Write-Verbose "[$functionName] Could not parse error response, but assuming authorization_pending for 400 status"
                                # For 400 errors during OAuth device flow polling, assume it's authorization_pending
                                $isAuthPending = $true
                            }
                        }
                        
                        if ($isAuthPending)
                        {
                            Write-Verbose "[$functionName] Authorization still pending (from catch block), continuing to poll..."
                        }
                    }
                    
                    # Only show warning for unexpected errors, not for authorization_pending
                    if (-not $isAuthPending)
                    {
                        Write-Warning "Polling attempt failed: $($_.Exception.Message)"
                        Write-Verbose "[$functionName] Unexpected error during polling: $($_.Exception | Out-String)"
                    }
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
                if (-not (LaunchBrowser -url $authUrl -browser $settings.preferredBrowser))
                {
                    Write-Error "Failed to launch browser. Please open the URL manually: $authUrl"
                    return $null
                }
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
        MGGraph
        {
            Write-Verbose "[$functionName] Using Microsoft Graph device code flow."
            $accessToken = GetTokenFromMGGraph -scope $scopes -apiVersion $apiVersion
            if ($accessToken)
            {
                Write-Verbose "[$functionName] Access token obtained from Microsoft Graph."
                return Format-TokenOutput -token $accessToken -secureString $SecureString
            }
            else
            {
                Write-Error "Failed to obtain access token from Microsoft Graph."
                return $null
            }
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
        if (-not (LaunchBrowser -url $authUrl -browser $settings.preferredBrowser))
        {
            Write-Error "Failed to launch browser. Please open the URL manually: $authUrl"
            return $null
        }        
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
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder        # Save the refresh token to config file regardless of cache type
        if ($tokenResponse.refresh_token)
        {
            if (-not $NoSaveRefreshToken)
            {
                Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
                if ($ForcedRenewal)
                {
                    Write-Verbose "[$functionName] Forced refresh token renewed and saved to config file $configFilePath"
                }
            }
            else
            {
                if ($ForcedRenewal)
                {
                    Write-Host "New refresh token has been obtained but was not saved due to NoSaveRefreshToken setting." -ForegroundColor Yellow
                    Write-Verbose "[$functionName] Forced refresh token renewal completed but not saved per NoSaveRefreshToken setting."
                }
            }
        }
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
    }
    else 
    {
        Write-Verbose "[$functionName] Token response is null. Authorization code exchange failed."
        return $null
    }
}

