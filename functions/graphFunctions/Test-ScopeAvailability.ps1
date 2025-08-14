function Test-ScopeAvailability()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [array]$RequiredScopes = @(),
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthConfiguration,
        [Parameter(Mandatory = $false)]
        [array]$RequestedScopes = @()
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting scope availability validation"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting scope availability validation" -LogLevel "Information"
    # Initialize the result object
    $result = @{
        HasAllRequiredScopes     = $false
        MissingScopes            = @()
        AvailableScopes          = @()
        ScopeSource              = ""
        UnavailableFunctionality = @()
        RecommendedAction        = ""
    }
    
    # Handle empty required scopes - if no scopes are required, all are available
    if ($RequiredScopes.Count -eq 0)
    {
        Write-Verbose "[$functionName] No required scopes specified - returning success"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No required scopes specified - returning success" -LogLevel "Information"
        $result.HasAllRequiredScopes = $true
        $result.RecommendedAction = "No specific scopes required."
        return $result
    }
    
    try
    {
        # Determine if this is delegated or application authentication
        $isDelegated = $AuthConfiguration.Delegated -eq $true
        Write-Verbose "[$functionName] Authentication type: $(if ($isDelegated) { 'Delegated' } else { 'Application' })"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Authentication type: $(if ($isDelegated) { 'Delegated' } else { 'Application' })" -LogLevel "Information"
        if ($isDelegated)
        {
            # For delegated authentication, use the scopes that were requested during authentication
            Write-Verbose "[$functionName] Using delegated authentication - checking requested scopes"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using delegated authentication - checking requested scopes" -LogLevel "Information"
            $result.ScopeSource = "Delegated (Requested during authentication)"
            
            # Get the scopes that were actually requested
            if ($RequestedScopes -and $RequestedScopes.Count -gt 0)
            {
                $result.AvailableScopes = $RequestedScopes
                Write-Verbose "[$functionName] Available delegated scopes: $($RequestedScopes -join ', ')"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Available delegated scopes: $($RequestedScopes -join ', ')" -LogLevel "Information"
            }
            else
            {
                Write-Warning "[$functionName] No requested scopes provided for delegated authentication"
                Write-Log -LogFile $LogFile -Module $functionName -Message "No requested scopes provided for delegated authentication" -LogLevel "Warning"
                $result.AvailableScopes = @()
            }
        }
        else
        {
            # For application authentication, decode the JWT token to get actual scopes
            Write-Verbose "[$functionName] Using application authentication - decoding JWT token"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using application authentication - decoding JWT token" -LogLevel "Information"
            $result.ScopeSource = "Application (JWT token claims)"
            
            try
            {
                $decodedToken = DecodeJwtToken -Token $AccessToken -raw
                Write-Verbose "[$functionName] Successfully decoded JWT token"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully decoded JWT token" -LogLevel "Information"
                # Extract scopes from the token (they can be in 'scp' or 'roles' claim)
                $tokenScopes = @()
                if ($decodedToken.scp)
                {
                    $tokenScopes += $decodedToken.scp -split ' '
                    Write-Verbose "[$functionName] Found scopes in 'scp' claim: $($decodedToken.scp)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found scopes in 'scp' claim: $($decodedToken.scp)" -LogLevel "Information"
                }
                if ($decodedToken.roles)
                {
                    $tokenScopes += $decodedToken.roles
                    Write-Verbose "[$functionName] Found roles in 'roles' claim: $($decodedToken.roles -join ', ')"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found roles in 'roles' claim: $($decodedToken.roles -join ', ')" -LogLevel "Information"
                }
                
                $result.AvailableScopes = $tokenScopes | Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique
                Write-Verbose "[$functionName] Available application scopes: $($result.AvailableScopes -join ', ')"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Available application scopes: $($result.AvailableScopes -join ', ')" -LogLevel "Information"
            }
            catch
            {
                Write-Error "[$functionName] Failed to decode JWT token: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decode JWT token: $($_.Exception.Message)" -LogLevel "Error"
                $result.AvailableScopes = @()
            }
        }
        
        # Compare required scopes with available scopes
        $missingScopes = @()
        $unavailableFunctionality = @()
        
        foreach ($requiredScope in $RequiredScopes)
        {
            $scopeName = $requiredScope.Scope
            $scopeReason = $requiredScope.Reason
            $scopeEndpoints = $requiredScope.Endpoints -join ', '
            
            Write-Verbose "[$functionName] Checking required scope: $scopeName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Checking required scope: $scopeName" -LogLevel "Information"
            
            # Check if this scope is available
            $isAvailable = $result.AvailableScopes -contains $scopeName
            
            if (-not $isAvailable)
            {
                Write-Verbose "[$functionName] Missing required scope: $scopeName"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing required scope: $scopeName" -LogLevel "Warning"
                $missingScopes += $requiredScope
                
                # Add to unavailable functionality
                $unavailableFunctionality += @{
                    Scope     = $scopeName
                    Reason    = $scopeReason
                    Endpoints = $scopeEndpoints
                    Impact    = "Features requiring this scope will not function"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Required scope available: $scopeName"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Required scope available: $scopeName" -LogLevel "Information"
            }
        }
        
        $result.MissingScopes = $missingScopes
        $result.UnavailableFunctionality = $unavailableFunctionality
        $result.HasAllRequiredScopes = $missingScopes.Count -eq 0
        
        # Set recommended action based on authentication type and missing scopes
        if ($result.HasAllRequiredScopes)
        {
            $result.RecommendedAction = "All required scopes are available. No action needed."
            Write-Host "All required Microsoft Graph API scopes are available." -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "All required Microsoft Graph API scopes are available." -LogLevel "Information"
        }
        else
        {
            Write-Host "Some required Microsoft Graph API scopes are missing." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "Some required Microsoft Graph API scopes are missing." -LogLevel "Warning"
            if ($isDelegated)
            {
                $result.RecommendedAction = "Re-authenticate with additional scopes to enable full functionality."
                Write-Host "Missing scopes for delegated authentication. Re-authentication will be required." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing scopes for delegated authentication. Re-authentication will be required." -LogLevel "Warning"
            }
            else
            {
                $result.RecommendedAction = "Contact your administrator to add the missing application permissions to your Microsoft Entra application registration."
                Write-Host "Missing application permissions. Contact your administrator to add these permissions." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing application permissions. Contact your administrator to add these permissions." -LogLevel "Warning"
            }
        }
        
        # Log summary
        Write-Log -LogFile $LogFile -Module $functionName -Message "Scope validation complete. Has all scopes: $($result.HasAllRequiredScopes). Missing: $($missingScopes.Count)" -LogLevel "Information"
        Write-Verbose "[$functionName] Scope validation complete. Missing scopes: $($missingScopes.Count)"
        
        return $result
    }
    catch
    {
        Write-Error "[$functionName] Error during scope validation: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error during scope validation: $($_.Exception.Message)" -LogLevel "Error"
        
        # Return a failed result
        $result.HasAllRequiredScopes = $false
        $result.RecommendedAction = "Scope validation failed. Please check the logs for more information."
        return $result
    }
}