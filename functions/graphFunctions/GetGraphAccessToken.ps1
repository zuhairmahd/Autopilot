function GetGraphAccessToken()
{
    <#
    .SYNOPSIS
    Main entry point for acquiring Microsoft Graph API access tokens with automatic auth flow detection.

    .DESCRIPTION
    This is the primary token acquisition function that orchestrates the complete authentication process.
    It automatically determines whether to use delegated (user) or application (client credentials) auth
    based on parameters, handles configuration file processing, manages encrypted credential storage,
    implements token caching strategies, and provides flexible renewal options. The function abstracts
    the complexity of different auth flows into a unified interface.

    .PARAMETER configFile
    Path to the configuration file containing auth settings. This parameter is mandatory.

    .PARAMETER renewalLeadTime
    Minutes before expiry to renew token. Default is 5 minutes.

    .PARAMETER SecureString
    When specified, returns access token as SecureString.

    .PARAMETER NoSaveRefreshToken
    (Delegated only) Prevents saving refresh token to configuration.

    .PARAMETER delegated
    When specified, forces delegated (user) authentication flow.

    .PARAMETER Scope
    (Delegated only) Array of Microsoft Graph permission scopes.

    .PARAMETER AuthType
    (Delegated only) Authentication type: 'PublicAuthFlow', 'Interactive', or 'Private'. Default is 'Private'.

    .PARAMETER ForceNewToken
    (Delegated only) Forces new token acquisition bypassing cache.

    .PARAMETER ForceNewRefreshToken
    (Delegated only) Forces new refresh token acquisition.

    .PARAMETER CacheType
    Token cache storage type: 'file' or 'memory'. Default is 'Memory'.

    .PARAMETER APIVersion
    Microsoft Graph API version: 'Beta' (default) or 'v1.0'.

    .OUTPUTS
    System.String or System.Security.SecureString
    Returns the access token, or $null on error.

    .EXAMPLE
    $token = GetGraphAccessToken -configFile "config.json"
    $token = GetGraphAccessToken -configFile "config.json" -delegated -Scope @("User.Read") -CacheType 'file'
    $token = GetGraphAccessToken -configFile "config.json" -ForceNewToken -SecureString

    .NOTES
    Unified entry point for all authentication flows.
    Auto-detects delegated vs application auth from config and parameters.
    Processes encrypted configuration files securely.
    Manages both in-memory and file-based token caching.
    Handles refresh token extraction from encrypted config.
    Delegates to Get-DelegatedToken or Get-ClientCredentialsToken based on auth type.
    Implements comprehensive error handling and logging.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$configFile,
        [int]$renewalLeadTime = 5,
        [switch]$SecureString,
        [parameter(parameterSetName = 'delegated')]
        [switch]$NoSaveRefreshToken,
        [parameter(parameterSetName = 'delegated')]
        [switch]$delegated,
        [parameter(parameterSetName = 'delegated')]
        [string[]]$Scope,
        [parameter(parameterSetName = 'delegated')]
        [ValidateSet('PublicAuthFlow', 'Interactive', 'Private')]
        [string]$AuthType = 'Private', 
        [parameter(parameterSetName = 'delegated')]
        [switch]$ForceNewToken,
        [parameter(parameterSetName = 'delegated')]
        [switch]$ForceNewRefreshToken,
        [ValidateSet('file', 'memory')]
        [string]$CacheType = 'Memory',
        [string]$APIVersion = 'Beta'
    )
    $functionName = $MyInvocation.MyCommand.Name
        
    #region Process config files
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting Graph access token retrieval" -LogLevel "Verbose"
    # Read and process configuration file
    if (-not $configFile)
    {
        Write-Error "Config file not found. Please provide a valid config file."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Config file not found. Please provide a valid config file." -LogLevel "Verbose"
        return $null
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message "Accessing config values from in-memory encrypted config" -LogLevel "Debug"
    $configRefreshToken = $null
    
    # Extract the refresh token if it exists using the new encryption system
    try
    {
        $configRefreshToken = Get-DecryptedConfigValue -PropertyPath "delegatedCredentials.refresh_token"
        if ($configRefreshToken)
        {
            Write-Verbose "[$functionName] Found refresh token in encrypted config."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found refresh token in encrypted config" -LogLevel "Verbose"
        }
        else
        {
            Write-Verbose "[$functionName] No refresh token found in config."
            Write-Log -LogFile $LogFile -Module $functionName -Message "No refresh token found in config" -LogLevel "Verbose"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] No delegatedCredentials.refresh_token found in config."
    }
    # Handle ForceNewRefreshToken parameter
    if ($ForceNewRefreshToken -and $delegated)
    {
        Write-Host "Force new refresh token requested. Invalidating existing refresh token." -ForegroundColor Yellow
        Write-Verbose "[$functionName] ForceNewRefreshToken requested. Clearing existing refresh token from memory."
        
        # Clear the configRefreshToken variable so a new one will be obtained
        $configRefreshToken = $null
        Write-Verbose "[$functionName] Cleared configRefreshToken variable. New refresh token will be obtained and saved to config."
    }    
    
    #get the tenant Id
    try
    {
        $tenantId = Get-DecryptedConfigValue -PropertyPath "tenantId"
        if ($tenantId)
        {
            Write-Verbose "[$functionName] Tenant ID found in config: $tenantId"
        }
        else
        {
            Write-Error "Tenant ID not found in config file."
            return $null
        }
    }
    catch
    {
        Write-Error "Tenant ID not found in config file."
        return $null
    }
    
    #get the domain
    try
    {
        $domain = Get-DecryptedConfigValue -PropertyPath "domain"
        if ($domain)
        {
            Write-Verbose "[$functionName] Domain found in config: $domain"
        }
        else
        {
            Write-Error "Domain not found in config file."
            return $null
        }
    }
    catch
    {
        Write-Error "Domain not found in config file."
        return $null
    }
    
    #get the client id
    try
    {
        $clientId = Get-DecryptedConfigValue -PropertyPath "appId"
        if ($clientId)
        {
            Write-Verbose "[$functionName] Client ID found in config: $clientId"
        }
        else
        {
            Write-Error "Client ID not found in config file."
            return $null
        }
    }
    catch
    {
        Write-Error "Client ID not found in config file."
        return $null
    }
    
    #get the client secret
    try
    {
        $clientSecret = Get-DecryptedConfigValue -PropertyPath "AppSecret"
        if ($clientSecret)
        {
            Write-Verbose "[$functionName] Client Secret found in config."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Client Secret found in config" -LogLevel "Verbose"
        }
        else
        {
            Write-Verbose "[$functionName] Client Secret not found in config file."
            Write-Verbose "Checking whether the authtype is public flow which does not require client secret."
            if ($AuthType -ne 'PublicAuthFlow')
            {
                Write-Verbose "[$functionName] Will check for certificate thumbprint as alternative authentication method."
            }
            else
            {
                Write-Verbose "[$functionName] Public Auth Flow does not require Client Secret."
            }
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Client Secret not found in config file."
        Write-Verbose "Checking whether the authtype is public flow which does not require client secret."
        if ($AuthType -ne 'PublicAuthFlow')
        {
            Write-Verbose "[$functionName] Will check for certificate thumbprint as alternative authentication method."
        }
        else
        {
            Write-Verbose "[$functionName] Public Auth Flow does not require Client Secret."
        }
    }
    
    # Check for certificate thumbprint (try both "certificateThumbprint" and "thumbprint" for compatibility)
    try
    {
        $certificateThumbprint = Get-DecryptedConfigValue -PropertyPath "certificateThumbprint"
        if (-not $certificateThumbprint)
        {
            $certificateThumbprint = Get-DecryptedConfigValue -PropertyPath "thumbprint"
        }
        
        if ($certificateThumbprint)
        {
            Write-Verbose "[$functionName] Certificate thumbprint found in config: $certificateThumbprint"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Certificate thumbprint found in config: $certificateThumbprint" -LogLevel "Verbose"
        }
        else
        {
            Write-Verbose "[$functionName] Certificate thumbprint not found in config."
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Certificate thumbprint not found in config."
        $certificateThumbprint = $null
    }
    # Validate that we have at least one authentication method for non-delegated flows
    if (-not $delegated -and -not $clientSecret -and -not $certificateThumbprint)
    {
        Write-Error "[$functionName] Either client secret or certificate thumbprint must be provided for non-delegated authentication."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Either client secret or certificate thumbprint must be provided for non-delegated authentication" -LogLevel "Error"
        return $null
    }
    if ($delegated )
    {
        Write-Verbose "[$functionName] Delegated access selected. Checking for scope."
        if ($null -eq $scope -or $scope -eq '')
        {
            Write-Verbose "[$functionName] No scope provided in parameters. Checking config file for scope."
            try
            {
                $configScope = Get-AuthConfigValue -PropertyPath "scope"
                if ($configScope)
                {
                    Write-Verbose "[$functionName] Found scope in config file."
                    $Scope = $configScope
                    Write-Verbose "[$functionName] Using scope from config file: $Scope"
                }
                else
                {
                    Write-Error "No scope provided."
                    return $null
                }
            }
            catch
            {
                Write-Error "No scope provided."
                return $null
            }
        }
        else
        {
            Write-Verbose "[$functionName] Scope provided in parameters: $Scope"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Non-delegated access selected. No scope required."
        Write-Verbose "[$functionName] Using default scope: $Scope"
    }
    #endregion Process config files
    
    #region Log parameters
    Write-Verbose "[$functionName] Received parameters:"
    Write-Verbose "[$functionName] Configuration File: $configFile"
    Write-Verbose "[$functionName] Renewal Lead Time: $renewalLeadTime" 
    Write-Verbose "[$functionName] Secure String: $SecureString"
    Write-Verbose "[$functionName] Force New Token: $ForceNewToken"
    Write-Verbose "[$functionName] Force New Refresh Token: $ForceNewRefreshToken"
    Write-Verbose "[$functionName] Use Public Auth Flow: $UsePublicAuthFlow"
    Write-Verbose "[$functionName] Interactive: $Interactive"
    Write-Verbose "[$functionName] Cache Type: $CacheType"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] delegated: $delegated"
    Write-Verbose "[$functionName] Scopes: $Scope"
    Write-Verbose "[$functionName] Config has refresh token: $($null -ne $configRefreshToken)"
    #endregion Log parameters

    # Set up cache paths
    if ([string]::IsNullOrWhiteSpace($configFile) -or -not (Test-Path $configFile))
    {
        # Use temp directory instead of current directory to avoid creating folders in project root
        $tempPath = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $cacheFolder = Join-Path $tempPath "AutopilotCache"
        Write-Verbose "[$functionName] Config file is empty or doesn't exist, using temp directory for cache: $cacheFolder"
    }
    else
    {
        $cacheFolder = Split-Path $configFile
    }
    $cacheTokenFile = Join-Path $cacheFolder "accessToken.json"

    #region Try to get token from cache if not forcing new token
    $accessToken = $null
    if (-not $ForceNewToken)
    {
        Write-Verbose "[$functionName] Attempting to retrieve token from cache."
        write-log -logFile $logFile -Module $functionName -Message "Attempting to retrieve token from cache."
        $accessToken = Get-TokenFromCache -cacheType $CacheType -domain $domain -renewalLeadTime $renewalLeadTime `
            -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $Scope `
            -delegated $delegated -cacheFolder $cacheFolder -cacheTokenFile $cacheTokenFile `
            -secureString $SecureString -configFilePath $configFile -configRefreshToken $configRefreshToken
        if ($accessToken)
        {
            Write-Verbose "[$functionName] Successfully retrieved valid token from cache."                                                  
            write-log -logFile $logFile -Module $functionName -Message "Successfully retrieved valid token from cache."
            return $accessToken
        }
    }
    else
    {
        Write-Host "Force new token requested. Ignoring cache."
        write-log -logFile $logFile -Module $functionName -Message "Force new token requested. Ignoring cache."                 
    }
    #endregion Try to get token from cache if not forcing new token
        
    #region Authentication flow
    if ($delegated)
    {
        Write-Verbose "[$functionName] delegated authentication flow selected." 
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using delegated authentication flow"
        $params = @{
            tenantId           = $tenantId 
            clientId           = $clientId 
            scopes             = $Scope
            domain             = $domain 
            cacheType          = $CacheType
            AuthType           = $AuthType
            cacheTokenFile     = $cacheTokenFile
            cacheFolder        = $cacheFolder 
            configFilePath     = $configFile
            configRefreshToken = $configRefreshToken
        }
        
        # Debug the scopes parameter being passed
        Write-Verbose "[$functionName] Scope parameter value: '$Scope'"
        Write-Verbose "[$functionName] Scope parameter type: $($Scope.GetType().Name)"
        if ([string]::IsNullOrEmpty($Scope))
        {
            Write-Warning "[$functionName] WARNING: Scope parameter is null or empty!"
        }
        switch ($AuthType)
        {
            PublicAuthFlow
            {
                Write-Verbose "[$functionName] Using public authentication flow for delegated token."
                write-log -logFile $logFile -Module $functionName -Message "Using public authentication flow for delegated token." 
            }
            Interactive
            {
                Write-Verbose "[$functionName] Using interactive authentication flow for delegated token."
                write-log -logFile $logFile -Module $functionName -Message "Using interactive authentication flow for delegated token."         
                $params += @{
                    clientSecret = $clientSecret
                }
            }
            Private
            {
                Write-Verbose "[$functionName] Using private authentication flow for delegated token."
                write-log -logFile $logFile -Module $functionName -Message "Using private authentication flow for delegated token."     
                $params += @{
                    clientSecret = $clientSecret
                }
            }        
        }
        if ($NoSaveRefreshToken)
        {
            Write-Verbose "[$functionName] No save refresh token option selected. Not saving refresh token."
            write-log -logFile $logFile -Module $functionName -Message "No save refresh token option selected. Not saving refresh token."   
            $params += @{
                NoSaveRefreshToken = $NoSaveRefreshToken
            }
        }
        if ($ForceNewRefreshToken)
        {
            Write-Verbose "[$functionName] Force new refresh token requested. This will force a new authentication flow."
            write-log -logFile $logFile -Module $functionName -Message "Force new refresh token requested. This will force a new authentication flow."          
            # Add a marker to indicate this was a forced refresh token renewal
            $params += @{
                ForcedRenewal = $true
            }
        }
        return Get-DelegatedToken @params
    }
    else
    {
        # Non-delegated (client credentials) authentication
        Write-Verbose "[$functionName] Using non-delegated (client credentials) authentication flow."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using non-delegated (client credentials) authentication flow" -LogLevel "Verbose"
        
        if ($tenantId -and $clientId -and ($clientSecret -or $certificateThumbprint))
        {
            Write-Verbose "[$functionName] Preparing parameters for client credentials token retrieval."
            write-log -logFile $logFile -Module $functionName -Message "Preparing parameters for client credentials token retrieval."
            $params = @{
                tenantId       = $tenantId
                clientId       = $clientId
                domain         = $domain
                cacheType      = $CacheType
                cacheTokenFile = $cacheTokenFile
                cacheFolder    = $cacheFolder
            }
            
            if ($clientSecret)
            {
                Write-Verbose "[$functionName] Using client secret for authentication."
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using client secret for authentication" -LogLevel "Verbose"
                $params['clientSecret'] = $clientSecret
            }
            
            if ($certificateThumbprint)
            {
                Write-Verbose "[$functionName] Using certificate thumbprint for authentication: $certificateThumbprint"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using certificate thumbprint for authentication: $certificateThumbprint" -LogLevel "Verbose"
                $params['certificateThumbprint'] = $certificateThumbprint
            }
            
            if ($clientSecret -and $certificateThumbprint)
            {
                Write-Verbose "[$functionName] Both client secret and certificate available - will try certificate first with fallback to secret."
                Write-Log -LogFile $LogFile -Module $functionName -Message "Both client secret and certificate available - will try certificate first with fallback to secret" -LogLevel "Warning"
            }
            
            if ($SecureString)
            {
                Write-Verbose "[$functionName] Secure string option selected. Returning token as SecureString."         
                write-log -logFile $logFile -Module $functionName -Message "Secure string option selected. Returning token as SecureString."   
                $params['secureString'] = $true
            }
            
            return Get-ClientCredentialsToken @params
        }
        else
        {
            Write-Error "[$functionName] Missing required authentication parameters (tenantId, clientId, and either clientSecret or certificateThumbprint)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Missing required authentication parameters" -LogLevel "Error"
            return $null
        }
    }
    #endregion Authentication flow
}

