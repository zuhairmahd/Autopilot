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
        return $null
    }
    
    # Handle different time formats for expiry time
    $absoluteExpiryTime = Get-NormalizedExpiryTime -accessTokenObject $accessTokenObject
    
    if ($absoluteExpiryTime -gt $timeBuffer)
    {
        # Token is not expired, but check if scopes match (for delegated auth)
        if ($requestedScopes -and $requestedScopes.Count -gt 0)
        {
            Write-Verbose "[$functionName] Validating cached token has required scopes"
            
            try
            {
                # Decode the cached token to check its scopes
                $decodedToken = DecodeJwtToken -Token $accessTokenObject.access_token -raw
                
                # Extract granted scopes from scp claim (delegated) or roles claim (application)
                $grantedScopes = @()
                if ($decodedToken.scp)
                {
                    # Delegated auth - scp is space-separated string
                    $grantedScopes = $decodedToken.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
                    Write-Verbose "[$functionName] Cached token has delegated scopes (scp): $($grantedScopes -join ', ')"
                }
                elseif ($decodedToken.roles)
                {
                    # Application auth - roles is array
                    $grantedScopes = $decodedToken.roles
                    Write-Verbose "[$functionName] Cached token has application scopes (roles): $($grantedScopes -join ', ')"
                }
                
                # Check if all requested scopes are present in granted scopes
                $missingScopes = @()
                foreach ($requestedScope in $requestedScopes)
                {
                    if ($grantedScopes -notcontains $requestedScope)
                    {
                        $missingScopes += $requestedScope
                    }
                }
                
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

