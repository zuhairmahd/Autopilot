function Test-ScopeAvailability()
{
    <#
    .SYNOPSIS
    Validates that an access token has all required Microsoft Graph scopes.

    .DESCRIPTION
    This function validates whether an access token contains all required Microsoft Graph API scopes.
    It decodes the JWT token to extract available scopes (scp for delegated, roles for application),
    compares them against required scopes, and returns detailed validation results including missing
    scopes and recommended actions. The function excludes OAuth/OIDC protocol scopes (openid, profile,
    offline_access) from validation for application authentication.

    .PARAMETER AccessToken
    The access token string to validate. This parameter is mandatory.

    .PARAMETER RequiredScopes
    Array of required Microsoft Graph API scope strings. If empty, validation passes automatically.

    .PARAMETER AuthConfiguration
    Hashtable containing authentication configuration including delegated flag and scope array.
    This parameter is mandatory.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with properties:
    - HasAllRequiredScopes: Boolean indicating if all required scopes are present
    - MissingScopes: Array of missing scope strings
    - AvailableScopes: Array of available scope strings
    - ScopeSource: Source of scopes ('scp' or 'roles')
    - UnavailableFunctionality: Array of functionality that may be unavailable
    - RecommendedAction: String describing recommended action if scopes are missing

    .EXAMPLE
    $validation = Test-ScopeAvailability -AccessToken $token -RequiredScopes @("User.Read", "Device.Read") -AuthConfiguration $authConfig
    if (-not $validation.HasAllRequiredScopes) {
        Write-Host "Missing scopes: $($validation.MissingScopes -join ', ')"
    }

    .NOTES
    Excludes OAuth/OIDC protocol scopes for application auth: openid, profile, offline_access.
    Handles both delegated (scp claim) and application (roles claim) authentication.
    Provides detailed validation results for troubleshooting scope issues.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $false)]
        [array]$RequiredScopes = @(),
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthConfiguration
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting scope availability validation"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting scope availability validation" -logLevel "Information"
    $RequestedScopes = if ($AuthConfiguration.delegated -eq $true) { $AuthConfiguration.scope } else { @() }               
    # Define scopes that should be excluded from validation for non-delegated (application) authentication
    # These are OAuth/OIDC protocol scopes, not Microsoft Graph API scopes
    $excludedScopesForApplication = @(
        'openid',
        'profile',
        'offline_access'
        # Additional non-Graph scopes can be added here in the future
    )
    Write-Verbose "[$functionName] Excluded scopes for application auth: $($excludedScopesForApplication -join ', ')"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Excluded scopes for application auth: $($excludedScopesForApplication -join ', ')" -LogLevel "Debug"
    
    # Initialize the result object
    $result = @{
        HasAllRequiredScopes     = $false
        MissingScopes            = @()
        AvailableScopes          = @()
        ScopeSource              = ""
        UnavailableFunctionality = @()
        RecommendedAction        = ""
    }
    Write-Verbose "[$functionName] Initialized result object with default values"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Initialized result object" -LogLevel "Debug"
    
    # Handle empty required scopes - if no scopes are required, all are available
    Write-Verbose "[$functionName] Checking if required scopes are specified (Count: $($RequiredScopes.Count))"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Required scopes count: $($RequiredScopes.Count)" -LogLevel "Debug"
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
        Write-Verbose "[$functionName] Authentication type determined: $(if ($isDelegated) { 'Delegated' } else { 'Application' })"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Authentication type: $(if ($isDelegated) { 'Delegated' } else { 'Application' })" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "AuthConfiguration.Delegated value: $($AuthConfiguration.Delegated)" -LogLevel "Debug"
        
        # Filter required scopes - exclude OIDC protocol scopes for BOTH delegated and application auth
        # These scopes (openid, profile, offline_access) are OAuth/OIDC protocol scopes, not Microsoft Graph API scopes
        # They should NEVER be validated as "missing" because:
        #   1. They're automatically granted during authentication flow
        #   2. They're not Graph API permissions
        #   3. They're filtered out of the available scopes list
        # Therefore, we exclude them from the required scopes list to prevent false "missing scope" warnings
        $originalCount = $RequiredScopes.Count
        $filteredRequiredScopes = $RequiredScopes | Where-Object { 
            $scopeName = $_.Scope
            $excludedScopesForApplication -notcontains $scopeName
        }
        $excludedFromRequired = $originalCount - $filteredRequiredScopes.Count
        if ($excludedFromRequired -gt 0)
        {
            $excludedScopeNames = $RequiredScopes | Where-Object { 
                $excludedScopesForApplication -contains $_.Scope 
            } | ForEach-Object { $_.Scope }
            $authTypeLabel = if ($isDelegated) { "delegated" } else { "application" }
            Write-Verbose "[$functionName] Excluded $excludedFromRequired OIDC protocol scope(s) from required scopes for $authTypeLabel auth: $($excludedScopeNames -join ', ')"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Excluded $excludedFromRequired OIDC protocol scope(s) from required scopes for $authTypeLabel auth: $($excludedScopeNames -join ', ')" -LogLevel "Information"
        }
        Write-Verbose "[$functionName] Filtered required scopes count: $($filteredRequiredScopes.Count) (excluded OIDC protocol scopes)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Required scopes after filtering out OIDC protocol scopes: $($filteredRequiredScopes.Count)" -LogLevel "Debug"
        
        # Update RequiredScopes to use the filtered list
        $RequiredScopes = $filteredRequiredScopes
        if ($isDelegated)
        {
            # For delegated authentication, decode the JWT token to get ACTUAL granted scopes
            # Important: We must check what was GRANTED (scp claim), not what was REQUESTED
            Write-Verbose "[$functionName] Processing delegated authentication scopes"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using delegated authentication - decoding JWT token to check granted scopes" -logLevel "Information"
            $result.ScopeSource = "Delegated (JWT token 'scp' claim)"
            
            try
            {
                Write-Verbose "[$functionName] Decoding JWT access token to extract granted scopes"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Attempting to decode JWT token for delegated auth" -LogLevel "Debug"
                $decodedToken = DecodeJwtToken -Token $AccessToken -raw
                Write-Verbose "[$functionName] Successfully decoded JWT token"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully decoded JWT token" -LogLevel "Information"
                
                # Extract scopes from the 'scp' claim (delegated permissions)
                $tokenScopes = @()
                Write-Verbose "[$functionName] Extracting scopes from JWT token 'scp' claim"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Extracting scopes from JWT token 'scp' claim" -LogLevel "Debug"
                
                if ($decodedToken.scp)
                {
                    # scp claim is a space-separated string for delegated auth
                    $scpScopes = $decodedToken.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
                    $tokenScopes += $scpScopes
                    Write-Verbose "[$functionName] Found $($scpScopes.Count) scopes in 'scp' claim: $($decodedToken.scp)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found scopes in 'scp' claim: $($decodedToken.scp)" -logLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No 'scp' claim found in JWT token for delegated auth"
                    Write-Warning "[$functionName] No 'scp' claim found in JWT token - this may indicate an issue with the token"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No 'scp' claim found in JWT token" -LogLevel "Warning"
                }
                
                # Filter out non-Graph scopes for delegated authentication
                Write-Verbose "[$functionName] Filtering token scopes - excluding non-Graph scopes"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Filtering out excluded scopes: $($excludedScopesForApplication -join ', ')" -LogLevel "Debug"
                
                $unfilteredScopes = $tokenScopes
                Write-Verbose "[$functionName] Unfiltered scopes count: $($unfilteredScopes.Count)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Unfiltered scopes: $($unfilteredScopes -join ', ')" -LogLevel "Debug"
                
                # Exclude OAuth/OIDC protocol scopes that don't apply to Graph API
                $filteredScopes = $unfilteredScopes | Where-Object { $excludedScopesForApplication -notcontains $_ }
                
                $excludedCount = $unfilteredScopes.Count - $filteredScopes.Count
                if ($excludedCount -gt 0)
                {
                    $excludedItems = $unfilteredScopes | Where-Object { $excludedScopesForApplication -contains $_ }
                    Write-Verbose "[$functionName] Excluded $excludedCount non-Graph scope(s): $($excludedItems -join ', ')"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Excluded $excludedCount non-Graph scope(s): $($excludedItems -join ', ')" -logLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No scopes excluded from filtering"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No scopes excluded - all scopes are Graph API scopes" -LogLevel "Debug"
                }
                
                $result.AvailableScopes = @($filteredScopes | Sort-Object -Unique)
                Write-Verbose "[$functionName] Available delegated scopes from token: $($result.AvailableScopes -join ', ')"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Available delegated scopes from token: $($result.AvailableScopes -join ', ')" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Total delegated scopes available: $($result.AvailableScopes.Count)" -LogLevel "Debug"
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to decode JWT token for delegated auth: $($_.Exception.Message)"
                Write-Error "[$functionName] Failed to decode JWT token for delegated auth: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decode JWT token: $($_.Exception.Message)" -LogLevel "Error"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Exception details: $($_.Exception.GetType().FullName)" -LogLevel "Debug"
                $result.AvailableScopes = @()
            }
        }
        else
        {
            # For application authentication, decode the JWT token to get actual scopes
            Write-Verbose "[$functionName] Processing application (non-delegated) authentication scopes"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using application authentication - decoding JWT token" -LogLevel "Information"
            $result.ScopeSource = "Application (JWT token claims)"
            
            try
            {
                Write-Verbose "[$functionName] Decoding JWT access token"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Attempting to decode JWT token" -LogLevel "Debug"
                $decodedToken = DecodeJwtToken -Token $AccessToken -raw
                Write-Verbose "[$functionName] Successfully decoded JWT token"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully decoded JWT token" -LogLevel "Information"
                
                # Extract scopes from the token (they can be in 'scp' or 'roles' claim)
                $tokenScopes = @()
                Write-Verbose "[$functionName] Extracting scopes from JWT token claims"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Extracting scopes from JWT token claims ('scp' and 'roles')" -LogLevel "Debug"
                
                if ($decodedToken.scp)
                {
                    $scpScopes = $decodedToken.scp -split ' '
                    $tokenScopes += $scpScopes
                    Write-Verbose "[$functionName] Found $($scpScopes.Count) scopes in 'scp' claim: $($decodedToken.scp)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found scopes in 'scp' claim: $($decodedToken.scp)" -logLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No 'scp' claim found in JWT token"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No 'scp' claim found in JWT token" -LogLevel "Debug"
                }
                
                if ($decodedToken.roles)
                {
                    $tokenScopes += $decodedToken.roles
                    Write-Verbose "[$functionName] Found $($decodedToken.roles.Count) roles in 'roles' claim: $($decodedToken.roles -join ', ')"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found roles in 'roles' claim: $($decodedToken.roles -join ', ')" -logLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No 'roles' claim found in JWT token"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No 'roles' claim found in JWT token" -LogLevel "Debug"
                }
                
                # Filter out non-Graph scopes for application authentication
                Write-Verbose "[$functionName] Filtering token scopes - excluding non-Graph scopes for application auth"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Filtering out excluded scopes: $($excludedScopesForApplication -join ', ')" -LogLevel "Debug"
                
                $unfilteredScopes = $tokenScopes | Where-Object { $_ -and $_.Trim() }
                Write-Verbose "[$functionName] Unfiltered scopes count: $($unfilteredScopes.Count)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Unfiltered scopes: $($unfilteredScopes -join ', ')" -LogLevel "Debug"
                
                # Exclude OAuth/OIDC protocol scopes that don't apply to Graph API
                $filteredScopes = $unfilteredScopes | Where-Object { $excludedScopesForApplication -notcontains $_ }
                
                $excludedCount = $unfilteredScopes.Count - $filteredScopes.Count
                if ($excludedCount -gt 0)
                {
                    $excludedItems = $unfilteredScopes | Where-Object { $excludedScopesForApplication -contains $_ }
                    Write-Verbose "[$functionName] Excluded $excludedCount non-Graph scope(s): $($excludedItems -join ', ')"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Excluded $excludedCount non-Graph scope(s): $($excludedItems -join ', ')" -logLevel "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] No scopes excluded from filtering"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "No scopes excluded - all scopes are Graph API scopes" -LogLevel "Debug"
                }
                
                $result.AvailableScopes = @($filteredScopes | Sort-Object -Unique)
                Write-Verbose "[$functionName] Available application scopes after filtering: $($result.AvailableScopes -join ', ')"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Available application scopes: $($result.AvailableScopes -join ', ')" -LogLevel "Information"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Total application scopes available: $($result.AvailableScopes.Count)" -LogLevel "Debug"
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to decode JWT token: $($_.Exception.Message)"
                Write-Error "[$functionName] Failed to decode JWT token: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decode JWT token: $($_.Exception.Message)" -LogLevel "Error"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Exception details: $($_.Exception.GetType().FullName)" -LogLevel "Debug"
                $result.AvailableScopes = @()
            }
        }
        
        # Compare required scopes with available scopes using hierarchy awareness
        Write-Verbose "[$functionName] Beginning scope comparison - checking $($RequiredScopes.Count) required scope(s) against $($result.AvailableScopes.Count) available scope(s)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Starting scope comparison: Required=$($RequiredScopes.Count), Available=$($result.AvailableScopes.Count)" -logLevel "Information"
        
        $missingScopes = @()
        $unavailableFunctionality = @()
        $scopeCheckCount = 0
        
        foreach ($requiredScope in $RequiredScopes)
        {
            $scopeCheckCount++
            $scopeName = $requiredScope.Scope
            $scopeReason = $requiredScope.Reason
            $scopeEndpoints = $requiredScope.Endpoints -join ', '
            
            Write-Verbose "[$functionName] Checking scope $scopeCheckCount/$($RequiredScopes.Count): $scopeName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Checking required scope: $scopeName" -logLevel "Information"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Scope reason: $scopeReason" -LogLevel "Debug"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Scope endpoints: $scopeEndpoints" -LogLevel "Debug"
            
            # Check if this scope is available using hierarchical comparison
            # This allows higher-privilege scopes (e.g., Device.ReadWrite.All) to satisfy
            # lower-privilege requirements (e.g., Device.Read.All)
            Write-Verbose "[$functionName] Performing hierarchical scope comparison for: $scopeName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invoking Test-ScopeHierarchy for scope: $scopeName" -LogLevel "Debug"
            $isAvailable = Test-ScopeHierarchy -RequiredScope $scopeName -AvailableScopes $result.AvailableScopes
            if (-not $isAvailable)
            {
                Write-Verbose "[$functionName] Scope NOT satisfied: $scopeName (no available scope satisfies this requirement)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing required scope: $scopeName (not satisfied by any available scope)" -LogLevel "Warning"
                $missingScopes += $requiredScope
                # Add to unavailable functionality
                $unavailableFunctionality += @{
                    Scope     = $scopeName
                    Reason    = $scopeReason
                    Endpoints = $scopeEndpoints
                    Impact    = "Features requiring this scope will not function"
                }
                Write-Verbose "[$functionName] Added to missing scopes list (Total missing: $($missingScopes.Count))"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Added to unavailable functionality: $scopeName" -LogLevel "Debug"
            }
            else
            {
                Write-Verbose "[$functionName] Scope satisfied: $scopeName"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Required scope satisfied: $scopeName" -LogLevel "Information"
            }
        }
        Write-Verbose "[$functionName] Scope comparison complete - Missing: $($missingScopes.Count), Satisfied: $($RequiredScopes.Count - $missingScopes.Count)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Scope comparison complete - Total checked: $scopeCheckCount, Missing: $($missingScopes.Count), Satisfied: $($RequiredScopes.Count - $missingScopes.Count)" -logLevel "Information"
        Write-Verbose "[$functionName] Building result object"
        $result.MissingScopes = $missingScopes
        $result.UnavailableFunctionality = $unavailableFunctionality
        $result.HasAllRequiredScopes = $missingScopes.Count -eq 0
        Write-Log -LogFile $LogFile -Module $functionName -Message "Result object populated - HasAllRequiredScopes: $($result.HasAllRequiredScopes)" -LogLevel "Debug"
        # Set recommended action based on authentication type and missing scopes
        Write-Verbose "[$functionName] Determining recommended action based on validation results"
        if ($result.HasAllRequiredScopes)
        {
            $result.RecommendedAction = "All required scopes are available. No action needed."
            Write-Verbose "[$functionName] All required scopes are available"
            Write-Log -LogFile $LogFile -Module $functionName -Message "All required Microsoft Graph API scopes are available." -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] Some required scopes are missing - generating recommendations"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Some required Microsoft Graph API scopes are missing." -LogLevel "Warning"
            if ($isDelegated)
            {
                $result.RecommendedAction = "Re-authenticate with additional scopes to enable full functionality."
                Write-Verbose "[$functionName] Delegated auth - re-authentication required"
                Write-Host "Missing scopes for delegated authentication. Re-authentication will be required." -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing scopes for delegated authentication. Re-authentication will be required." -LogLevel "Warning"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing scopes: $($missingScopes.Scope -join ', ')" -LogLevel "Debug"
            }
            else
            {
                $result.RecommendedAction = "Contact your administrator to add the missing application permissions to your Microsoft Entra application registration."
                Write-Verbose "[$functionName] Application auth - admin consent required"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing application permissions. Contact your administrator to add these permissions." -LogLevel "Warning"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Missing scopes: $($missingScopes.Scope -join ', ')" -LogLevel "Debug"
            }
        }
        
        # Log summary
        Write-Verbose "[$functionName] Scope validation complete. Missing scopes: $($missingScopes.Count)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Scope validation complete. Has all scopes: $($result.HasAllRequiredScopes). Missing: $($missingScopes.Count)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Available scopes: $($result.AvailableScopes.Count), Required scopes: $($RequiredScopes.Count), Satisfied: $($RequiredScopes.Count - $missingScopes.Count)" -LogLevel "Debug"
        
        return $result
    }
    catch
    {
        Write-Verbose "[$functionName] Exception caught during scope validation: $($_.Exception.Message)"
        Write-Error "[$functionName] Error during scope validation: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error during scope validation: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exception type: $($_.Exception.GetType().FullName)" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Stack trace: $($_.ScriptStackTrace)" -LogLevel "Debug"
        
        # Return a failed result
        Write-Verbose "[$functionName] Returning failed result due to exception"
        $result.HasAllRequiredScopes = $false
        $result.RecommendedAction = "Scope validation failed. Please check the logs for more information."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Returning failed validation result" -LogLevel "Warning"
        return $result
    }
}