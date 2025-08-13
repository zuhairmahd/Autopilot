function Test-ScopeAvailability
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
    
    # Ensure LogFile variable exists for Write-Log calls
    if (-not (Get-Variable -Name LogFile -Scope Global -ErrorAction SilentlyContinue)) {
        $global:LogFile = "$env:TEMP\autopilot-scope-validation.log"
    }
    
    # Try to use Write-Log if available, otherwise use Write-Verbose
    try {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Starting scope availability validation" -LogLevel "Information"
        } else {
            Write-Verbose "[$functionName] Starting scope availability validation (Write-Log not available)"
        }
    } catch {
        Write-Verbose "[$functionName] Starting scope availability validation (Write-Log failed: $($_.Exception.Message))"
    }
    
    # Initialize the result object
    $result = @{
        HasAllRequiredScopes = $false
        MissingScopes = @()
        AvailableScopes = @()
        ScopeSource = ""
        UnavailableFunctionality = @()
        RecommendedAction = ""
    }
    
    # Handle empty required scopes - if no scopes are required, all are available
    if ($RequiredScopes.Count -eq 0) {
        Write-Verbose "[$functionName] No required scopes specified - returning success"
        $result.HasAllRequiredScopes = $true
        $result.RecommendedAction = "No specific scopes required."
        return $result
    }
    
    try {
        # Determine if this is delegated or application authentication
        $isDelegated = $AuthConfiguration.Delegated -eq $true
        Write-Verbose "[$functionName] Authentication type: $(if ($isDelegated) { 'Delegated' } else { 'Application' })"
        
        if ($isDelegated) {
            # For delegated authentication, use the scopes that were requested during authentication
            Write-Verbose "[$functionName] Using delegated authentication - checking requested scopes"
            $result.ScopeSource = "Delegated (Requested during authentication)"
            
            # Get the scopes that were actually requested
            if ($RequestedScopes -and $RequestedScopes.Count -gt 0) {
                $result.AvailableScopes = $RequestedScopes
                Write-Verbose "[$functionName] Available delegated scopes: $($RequestedScopes -join ', ')"
            } else {
                Write-Warning "[$functionName] No requested scopes provided for delegated authentication"
                $result.AvailableScopes = @()
            }
        } else {
            # For application authentication, decode the JWT token to get actual scopes
            Write-Verbose "[$functionName] Using application authentication - decoding JWT token"
            $result.ScopeSource = "Application (JWT token claims)"
            
            try {
                $decodedToken = DecodeJwtToken -Token $AccessToken -raw
                Write-Verbose "[$functionName] Successfully decoded JWT token"
                
                # Extract scopes from the token (they can be in 'scp' or 'roles' claim)
                $tokenScopes = @()
                if ($decodedToken.scp) {
                    $tokenScopes += $decodedToken.scp -split ' '
                    Write-Verbose "[$functionName] Found scopes in 'scp' claim: $($decodedToken.scp)"
                }
                if ($decodedToken.roles) {
                    $tokenScopes += $decodedToken.roles
                    Write-Verbose "[$functionName] Found roles in 'roles' claim: $($decodedToken.roles -join ', ')"
                }
                
                $result.AvailableScopes = $tokenScopes | Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique
                Write-Verbose "[$functionName] Available application scopes: $($result.AvailableScopes -join ', ')"
            }
            catch {
                Write-Error "[$functionName] Failed to decode JWT token: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decode JWT token: $($_.Exception.Message)" -LogLevel "Error"
                $result.AvailableScopes = @()
            }
        }
        
        # Compare required scopes with available scopes
        $missingScopes = @()
        $unavailableFunctionality = @()
        
        foreach ($requiredScope in $RequiredScopes) {
            $scopeName = $requiredScope.Scope
            $scopeReason = $requiredScope.Reason
            $scopeEndpoints = $requiredScope.Endpoints -join ', '
            
            Write-Verbose "[$functionName] Checking required scope: $scopeName"
            
            # Check if this scope is available
            $isAvailable = $result.AvailableScopes -contains $scopeName
            
            if (-not $isAvailable) {
                Write-Verbose "[$functionName] Missing required scope: $scopeName"
                $missingScopes += $requiredScope
                
                # Add to unavailable functionality
                $unavailableFunctionality += @{
                    Scope = $scopeName
                    Reason = $scopeReason
                    Endpoints = $scopeEndpoints
                    Impact = "Features requiring this scope will not function"
                }
            } else {
                Write-Verbose "[$functionName] Required scope available: $scopeName"
            }
        }
        
        $result.MissingScopes = $missingScopes
        $result.UnavailableFunctionality = $unavailableFunctionality
        $result.HasAllRequiredScopes = $missingScopes.Count -eq 0
        
        # Set recommended action based on authentication type and missing scopes
        if ($result.HasAllRequiredScopes) {
            $result.RecommendedAction = "All required scopes are available. No action needed."
            Write-Host "✓ All required Microsoft Graph API scopes are available." -ForegroundColor Green
        } else {
            Write-Host "⚠ Some required Microsoft Graph API scopes are missing." -ForegroundColor Yellow
            
            if ($isDelegated) {
                $result.RecommendedAction = "Re-authenticate with additional scopes to enable full functionality."
                Write-Host "Missing scopes for delegated authentication. Re-authentication will be required." -ForegroundColor Yellow
            } else {
                $result.RecommendedAction = "Contact your administrator to add the missing application permissions to your Microsoft Entra application registration."
                Write-Host "Missing application permissions. Contact your administrator to add these permissions." -ForegroundColor Yellow
            }
        }
        
        # Log summary
        try {
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Scope validation complete. Has all scopes: $($result.HasAllRequiredScopes). Missing: $($missingScopes.Count)" -LogLevel "Information"
            }
        } catch {
            # Ignore logging errors in tests
        }
        Write-Verbose "[$functionName] Scope validation complete. Missing scopes: $($missingScopes.Count)"
        
        return $result
    }
    catch {
        Write-Error "[$functionName] Error during scope validation: $($_.Exception.Message)"
        try {
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error during scope validation: $($_.Exception.Message)" -LogLevel "Error"
            }
        } catch {
            # Ignore logging errors in tests
        }
        
        # Return a failed result
        $result.HasAllRequiredScopes = $false
        $result.RecommendedAction = "Scope validation failed. Please check the logs for more information."
        return $result
    }
}