function HasScope()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ResourcePath,
        $requiredScopes = $settings.requiredScopes,
        $accessToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting scope validation for $($ResourcePath.Count) resource paths" -LogLevel "Verbose"
    
    # Get authorized scopes from the access token
    $tokenData = DecodeJwtToken -Token $accessToken
    Write-Verbose "[$functionName] Raw token roles: $($tokenData.roles)" 
    Write-Verbose "[$functionName] Token roles type: $($tokenData.roles.GetType().Name)"
    
    # Handle both single string and array cases
    if ($tokenData.roles -is [string])
    {
        # If it's a string, split it by comma and trim whitespace
        $authorizedScopes = $tokenData.roles -split ',' | ForEach-Object { $_.Trim() }
        Write-Verbose "[$functionName] Converted string to array of $($authorizedScopes.Count) scopes"
    }
    else
    {
        # If it's already an array, use it as is
        $authorizedScopes = $tokenData.roles
    }
    
    Write-Verbose "[$functionName] Total authorized scopes/roles: $($authorizedScopes.Count)"
    Write-Verbose "[$functionName] Available authorized scopes: $($authorizedScopes -join ', ')"
    Write-Verbose "[$functionName] Individual scopes:"
    $authorizedScopes | ForEach-Object { Write-Verbose "[$functionName]   - '$_'" }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Total authorized scopes/roles: $($authorizedScopes.Count)" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Available authorized scopes: $($authorizedScopes -join ', ')" -LogLevel "Information"
    
    # Define Microsoft Graph scope hierarchy - broader scopes include more specific ones
    $scopeHierarchy = @{
        # Directory permissions hierarchy - most comprehensive permissions
        'Directory.ReadWrite.All'                      = @('Directory.Read.All', 'User.Read.All', 'User.ReadWrite.All', 'Group.Read.All', 'Group.ReadWrite.All', 'Organization.Read.All', 'Organization.ReadWrite.All', 'Device.Read.All', 'Device.ReadWrite.All')
        'Directory.Read.All'                           = @('User.Read.All', 'Group.Read.All', 'Organization.Read.All', 'Device.Read.All')
        
        # User permissions hierarchy  
        'User.ReadWrite.All'                           = @('User.Read.All', 'User.ReadBasic.All')
        'User.Read.All'                                = @('User.ReadBasic.All')
        
        # Group permissions hierarchy
        'Group.ReadWrite.All'                          = @('Group.Read.All', 'GroupMember.Read.All', 'GroupMember.ReadWrite.All')
        'Group.Read.All'                               = @('GroupMember.Read.All')
        
        # Device permissions hierarchy
        'Device.ReadWrite.All'                         = @('Device.Read.All')
        
        # DeviceManagement permissions hierarchy
        'DeviceManagementConfiguration.ReadWrite.All'  = @('DeviceManagementConfiguration.Read.All')
        'DeviceManagementManagedDevices.ReadWrite.All' = @('DeviceManagementManagedDevices.Read.All')
        'DeviceManagementApps.ReadWrite.All'           = @('DeviceManagementApps.Read.All')
        'DeviceManagementServiceConfig.ReadWrite.All'  = @('DeviceManagementServiceConfig.Read.All')
        'DeviceManagementRBAC.ReadWrite.All'           = @('DeviceManagementRBAC.Read.All')
        
        # Application permissions hierarchy
        'Application.ReadWrite.All'                    = @('Application.Read.All')
        
        # Organization permissions hierarchy
        'Organization.ReadWrite.All'                   = @('Organization.Read.All')
        
        # Files permissions hierarchy
        'Files.ReadWrite.All'                          = @('Files.Read.All', 'Files.ReadWrite', 'Files.Read')
        'Files.Read.All'                               = @('Files.Read')
        'Files.ReadWrite'                              = @('Files.Read')
        
        # Sites permissions hierarchy
        'Sites.FullControl.All'                        = @('Sites.Manage.All', 'Sites.ReadWrite.All', 'Sites.Read.All')
        'Sites.Manage.All'                             = @('Sites.ReadWrite.All', 'Sites.Read.All')
        'Sites.ReadWrite.All'                          = @('Sites.Read.All')
        
        # Mail permissions hierarchy
        'Mail.ReadWrite'                               = @('Mail.Read')
        
        # Calendar permissions hierarchy
        'Calendars.ReadWrite'                          = @('Calendars.Read')
        
        # Contacts permissions hierarchy
        'Contacts.ReadWrite'                           = @('Contacts.Read')
        
        # Security permissions hierarchy
        'SecurityEvents.ReadWrite.All'                 = @('SecurityEvents.Read.All')
        'SecurityActions.ReadWrite.All'                = @('SecurityActions.Read.All')
    }
    
    # Helper function to check if a required scope is satisfied by any authorized scope
    function Test-ScopeAuthorization
    {
        param(
            [string]$RequiredScope,
            [string[]]$AuthorizedScopes,
            [hashtable]$ScopeHierarchy
        )
        
        $functionName = $MyInvocation.MyCommand.Name

        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Testing authorization for required scope: $RequiredScope" -LogLevel "Debug"
        
        # Direct match
        if ($AuthorizedScopes -contains $RequiredScope)
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Direct scope match found for: $RequiredScope" -LogLevel "Verbose"
            return $true
        }
        
        # Check if any authorized scope includes the required scope through hierarchy
        foreach ($authorizedScope in $AuthorizedScopes)
        {
            Write-Verbose "[$functionName]     Checking authorized scope: '$authorizedScope' against required: '$RequiredScope'"
            Write-Verbose "[$functionName] Checking if authorized scope '$authorizedScope' can satisfy '$RequiredScope'"
            if ($ScopeHierarchy.ContainsKey($authorizedScope))
            {
                $includedScopes = $ScopeHierarchy[$authorizedScope]
                Write-Verbose "[$functionName]       '$authorizedScope' includes: $($includedScopes -join ', ')"
                Write-Verbose "[$functionName] Scope '$authorizedScope' includes: $($includedScopes -join ', ')"
                if ($includedScopes -contains $RequiredScope)
                {
                    Write-Verbose "[$functionName]       ✅ MATCH: '$authorizedScope' includes '$RequiredScope'"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Hierarchical scope match: '$authorizedScope' includes '$RequiredScope'" -LogLevel "Debug"
                    return $true
                }
                else
                {
                    Write-Verbose "[$functionName]       ❌ No match: '$RequiredScope' not in included scopes"
                }
            }
            else
            {
                Write-Verbose "[$functionName]       No hierarchy defined for: '$authorizedScope'"
                Write-Verbose "[$functionName] No hierarchy defined for authorized scope: '$authorizedScope'"
            }
        }
        
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No scope authorization found for: $RequiredScope" -LogLevel "Verbose"
        return $false
    }
    
    $returnObjects = @()
    $allScopesAuthorized = $true
    Write-Verbose "[$functionName] Checking $($ResourcePath.Count) resource paths for required scopes."
    
    foreach ($uri in $ResourcePath)
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking resource path: $uri" -LogLevel "Verbose"
        
        # Normalize $uri to relative path for endpoint comparison
        if ($uri -match 'https?://[^/]+/(v1\.0|beta)/(.+)')
        {
            $relativeUri = $Matches[2]
            Write-Verbose "[$functionName] Extracted relative URI from full URL: $relativeUri"
        }
        else
        {
            $relativeUri = $uri
            Write-Verbose "[$functionName] Using URI as-is: $relativeUri"
        }
        
        # Strip query parameters if present
        if ($relativeUri -match '^([^?]+)')
        {
            $relativeUri = $Matches[1]
            Write-Verbose "[$functionName] Removed query parameters: $relativeUri"
        }
        
        # Normalize dynamic parameters by replacing GUIDs, IDs, and other dynamic segments
        $normalizedUri = $relativeUri
        
        # Replace GUID patterns (8-4-4-4-12 format) with {id}
        $normalizedUri = $normalizedUri -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '{id}'
        
        # Replace other common ID patterns
        # Replace serial numbers (alphanumeric, typically 7-20 characters)
        $normalizedUri = $normalizedUri -replace '/[A-Za-z0-9]{7,20}(?=/|$)', '/{id}'
        
        # Replace numeric IDs
        $normalizedUri = $normalizedUri -replace '/\d+(?=/|$)', '/{id}'
        
        # Replace UPN patterns (email-like identifiers)
        $normalizedUri = $normalizedUri -replace '/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?=/|$)', '/{id}'
        
        # Handle special cases for common Microsoft Graph patterns
        # Replace any remaining dynamic segments that look like IDs but might not match above patterns
        $normalizedUri = $normalizedUri -replace '/[A-Za-z0-9_.-]{10,}(?=/|$)', '/{id}'
        
        Write-Verbose "[$functionName] Original URI: $relativeUri"
        Write-Verbose "[$functionName] Normalized URI for pattern matching: $normalizedUri"
        
        # Find required scopes for this endpoint
        # Normalize endpoints for comparison - handle leading slash variations and dynamic parameters
        [array]$matchingScopes = $requiredScopes | Where-Object { 
            $normalizedEndpoints = $_.endpoints | ForEach-Object { 
                $endpoint = $_
                # Remove leading slash if present for comparison
                if ($endpoint.StartsWith('/'))
                {
                    $endpoint = $endpoint.Substring(1) 
                }
                $endpoint
            }
            
            Write-Verbose "[$functionName]   Checking scope '$($_.Scope)' with normalized endpoints: $($normalizedEndpoints -join ', ')"
            
            # Check for exact matches first (for both original and normalized URIs)
            $exactMatch = $normalizedEndpoints -contains $relativeUri -or $normalizedEndpoints -contains $normalizedUri
            
            # Check for pattern matches using wildcards
            $patternMatch = $false
            foreach ($endpoint in $normalizedEndpoints)
            {
                # Convert endpoint patterns to PowerShell wildcard patterns
                $wildcardPattern = $endpoint.Replace('{id}', '*')
                
                # Test against both original and normalized URIs
                if ($relativeUri -like $wildcardPattern -or $normalizedUri -like $wildcardPattern)
                {
                    $patternMatch = $true
                    Write-Verbose "[$functionName]     Pattern match found: '$relativeUri' or '$normalizedUri' matches pattern '$wildcardPattern'"
                    break
                }
            }
            
            $exactMatch -or $patternMatch
        }
        Write-Verbose "[$functionName] Number of matching scopes: $($matchingScopes.Count)"
        Write-Verbose "[$functionName] Matching required scopes: $($matchingScopes | Out-String) scopes."
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($matchingScopes.Count) matching scopes for endpoint: $relativeUri" -LogLevel "Verbose"
        
        # For this URI to be authorized, we need at least one matching scope to be satisfied
        # If no scopes are defined for this endpoint, we'll consider it authorized (public endpoint)
        $uriAuthorized = ($matchingScopes.Count -eq 0)
        $authorizedScopeDetails = @()
        $unauthorizedScopes = @()
        
        foreach ($scopeInfo in $matchingScopes)
        {
            # Handle both "Scope" and "scope" property names
            $requiredScope = if ($scopeInfo.Scope)
            {
                $scopeInfo.Scope 
            }
            else
            {
                $scopeInfo.scope 
            }
            Write-Verbose "[$functionName] Checking if scope '$requiredScope' is authorized"
            Write-Verbose "[$functionName] Required scope: $requiredScope"
            
            # Use the enhanced scope checking function
            $scopeAuthorized = Test-ScopeAuthorization -RequiredScope $requiredScope -AuthorizedScopes $authorizedScopes -ScopeHierarchy $scopeHierarchy
            Write-Verbose "[$functionName]   Scope authorization result for '$requiredScope': $scopeAuthorized"
            
            if ($scopeAuthorized)
            {
                Write-Verbose "[$functionName] Scope '$requiredScope' is authorized (direct or hierarchical match)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Scope '$requiredScope' is authorized for endpoint: $relativeUri" -LogLevel "Information"
                
                # Find which authorized scope satisfied this requirement
                $satisfyingScope = $null
                if ($authorizedScopes -contains $requiredScope)
                {
                    $satisfyingScope = $requiredScope
                }
                else
                {
                    foreach ($authScope in $authorizedScopes)
                    {
                        if ($scopeHierarchy.ContainsKey($authScope) -and $scopeHierarchy[$authScope] -contains $requiredScope)
                        {
                            $satisfyingScope = $authScope
                            break
                        }
                    }
                }
                
                $authorizedScopeDetails += [PSCustomObject]@{
                    RequiredScope     = $requiredScope
                    SatisfyingScope   = $satisfyingScope
                    AuthorizationType = if ($satisfyingScope -eq $requiredScope)
                    {
                        "Direct" 
                    }
                    else
                    {
                        "Hierarchical" 
                    }
                }
                
                # If at least one scope is authorized, the URI is authorized
                $uriAuthorized = $true
            }
            else
            {
                Write-Verbose "[$functionName] Scope '$requiredScope' is NOT authorized"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Scope '$requiredScope' is NOT authorized for endpoint: $relativeUri" -LogLevel "Warning"
                $unauthorizedScopes += $requiredScope
                # Continue checking other scopes - don't break here
            }
        }
        
        # Log summary for this URI
        if ($uriAuthorized)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "URI '$uri' is AUTHORIZED with $($authorizedScopeDetails.Count) satisfied scope(s)" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] URI '$uri' is NOT AUTHORIZED - no scopes satisfied"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "URI '$uri' is NOT AUTHORIZED - missing scopes: $($unauthorizedScopes -join ', ')" -LogLevel "Warning"
        }
        
        # Update overall authorization status
        if (-not $uriAuthorized)
        {
            $allScopesAuthorized = $false
        }
        
        # Create return object for this URI
        $returnObject = [PSCustomObject]@{
            Uri            = $uri
            RelativeUri    = $relativeUri
            RequiredScopes = $matchingScopes
            IsAuthorized   = $uriAuthorized
            Details        = $authorizedScopeDetails
        }
        
        $returnObjects += $returnObject
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "URI '$uri' authorization status: $uriAuthorized" -LogLevel "Information"
    }
    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Overall authorization status: $allScopesAuthorized" -LogLevel "Information"
    
    # Create a summary object for easier consumption
    $authorizationSummary = [PSCustomObject]@{
        OverallAuthorized = $allScopesAuthorized
        TotalUrisChecked  = $returnObjects.Count
        Details           = $returnObjects
    }
    
    return $authorizationSummary
}

