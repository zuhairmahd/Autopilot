function Test-CachedTokenValidity()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject,
        [datetime]$timeBuffer,
        [string]$domain,
        [string]$cacheType,
        [string[]]$requestedScopes = @()
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $accessTokenObject.access_token)
    {
        Write-Verbose "[$functionName] No access token in cached object"
        write-log -logFile $logFile -Module "$functionName" -Message "No access token found in cached token object for $domain in $cacheType cache" -LogLevel "Warning"
        return $null
    }
    
    # Handle different time formats for expiry time
    $absoluteExpiryTime = Get-NormalizedExpiryTime -accessTokenObject $accessTokenObject
    write-log -logFile $logFile -Module "$functionName" -Message "Cached token expiry time for $domain in $cacheType cache: $absoluteExpiryTime"
    Write-Verbose "[$functionName] Normalized expiry time: $absoluteExpiryTime"
    if ($absoluteExpiryTime -gt $timeBuffer)
    {
        # Token is not expired, but check if scopes match (for delegated auth)
        write-log -logFile $logFile -Module "$functionName" -Message "Validating cached token scopes for $domain in $cacheType cache"                   
        Write-Verbose "[$functionName] Access token is not expired, validating scopes if requested"
        
        # Normalize requestedScopes to array first (may be passed as space-separated string or array)
        # BUGFIX: Filter empty elements created by multiple consecutive spaces
        # Note: Parameter is [string[]] so strings get wrapped in array automatically
        $requestedScopesArray = @()
        if ($requestedScopes.Count -eq 1 -and $requestedScopes[0] -match ' ')
        {
            # Single element array containing space-separated scopes (string was passed)
            Write-Verbose "[$functionName] Normalizing space-separated scope string to array - VERSION 2024-11-15-FINAL"
            $splitScopes = $requestedScopes[0] -split ' '
            foreach ($scope in $splitScopes)
            {
                if (-not [string]::IsNullOrWhiteSpace($scope))
                {
                    $requestedScopesArray += $scope.Trim()
                }
            }
        }
        else
        {
            # Already an array or empty
            $requestedScopesArray = $requestedScopes
        }
        Write-Verbose "[$functionName] Requested scopes after normalization (count=$($requestedScopesArray.Count)): $($requestedScopesArray -join ', ')"
        
        if ($requestedScopesArray -and $requestedScopesArray.Count -gt 0)
        {
            Write-Verbose "[$functionName] Validating cached token has required scopes"
            write-log -logFile $logFile -Module "$functionName" -Message "Validating cached token has required scopes for $domain in $cacheType cache: $($requestedScopesArray -join ', ')"                   
            try
            {
                # Decode the cached token to check its scopes
                $decodedToken = DecodeJwtToken -Token $accessTokenObject.access_token -raw
                
                # Extract granted scopes from scp claim (delegated) or roles claim (application)
                $grantedScopes = @()
                if ($decodedToken.scp)
                {
                    # Delegated auth - scp is space-separated string
                    Write-Verbose "[$functionName] Cached token has delegated scopes (scp)"
                    $grantedScopes = $decodedToken.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
                    Write-Verbose "[$functionName] Cached token has delegated scopes (scp): $($grantedScopes -join ', ')"
                    write-log -logFile $logFile -Module "$functionName" -Message "Cached token has delegated scopes (scp): $($grantedScopes -join ', ')"                                
                }
                elseif ($decodedToken.roles)
                {
                    # Application auth - roles is array
                    $grantedScopes = $decodedToken.roles
                    Write-Verbose "[$functionName] Cached token has application scopes (roles): $($grantedScopes -join ', ')"
                    write-log -logFile $logFile -Module "$functionName" -Message "Cached token has application scopes (roles): $($grantedScopes -join ', ')"                    
                }
                
                # Check if all requested scopes are present in granted scopes
                $missingScopes = $requestedScopesArray | Where-Object { $grantedScopes -notcontains $_ } 
                if ($missingScopes.Count -gt 0)
                {
                    Write-Verbose "[$functionName] Cached token is missing required scopes: $($missingScopes -join ', ')"
                    Write-Verbose "[$functionName] Token will be invalidated and re-acquired with updated scopes"
                    Write-Log -LogFile $logFile -Module "$functionName" -Message "Cached token missing scopes: $($missingScopes -join ', ') - invalidating cache" -LogLevel "Warning"
                    return $null
                }
                else
                {
                    Write-Verbose "[$functionName] Cached token has all required scopes"
                    write-log -logFile $logFile -Module "$functionName" -Message "Cached token has all required scopes for $domain in $cacheType cache"                     
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to decode cached token for scope validation: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Module "$functionName" -Message "Failed to decode cached token: $($_.Exception.Message)" -LogLevel "Warning"
                # Continue with token - expiry is still valid
            }
        }
        
        Write-Verbose "[$functionName] Access token for $domain is valid until $absoluteExpiryTime"
        Write-Verbose "[$functionName] Using cached access token from $cacheType cache"
        write-log -logFile $logFile -Module "$functionName" -Message "Using valid cached access token for $domain from $cacheType cache (expires: $absoluteExpiryTime)"                         
        Write-Host "Valid Token retrieved from cache." -ForegroundColor Green
        [console]::beep(200, 200)
        return $accessTokenObject.access_token
    }
    else
    {
        Write-Verbose "[$functionName] Access token for $domain is expired or invalid"
        Write-Verbose "[$functionName] Absolute expiry time: $absoluteExpiryTime, Time buffer: $timeBuffer"
        Write-Verbose "[$functionName] Will attempt to refresh token"
        Write-Log -LogFile $logFile -Module "$functionName" -Message "Access token in $cacheType cache is expired or invalid (expires: $absoluteExpiryTime, buffer: $timeBuffer)" -LogLevel "Warning"
        return $null
    }
}

