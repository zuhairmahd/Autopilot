function DecodeJwtToken
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        [switch]$raw,
        [switch]$RawJSON
    )
    $functionName = $MyInvocation.MyCommand.Name
    $HRIdentifyers = @{
        aud      = 'Audience'
        iss      = 'Issuer'
        wids     = 'WindowsIdentifiers'
        roles    = 'Roles'
        sub      = 'Subject'
        oid      = 'Object Identifier'
        iat      = 'IssuedAt'
        nbf      = 'NotBefore'
        exp      = 'ExpirationTime'
        idp      = 'IdentityProvider'
        appidacr = 'AuthenticationMechanism'
        idtyp    = 'IdentityType'
        tid      = 'TenantID'
        uti      = 'UniqueTokenIdentifier'
        ver      = 'Version'
    }
    $parts = $Token -split '\.'
    Write-Verbose "[$functionName] Token parts: $($parts.Length)"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing JWT token with $($parts.Length) parts" -LogLevel "Information"
    if ($parts.Length -lt 2)
    {
        Write-Verbose "[$functionName] Invalid JWT token format. Expected at least 2 parts."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid JWT token format. Expected at least 2 parts." -LogLevel "Error"
        return $returnValues.invalidJWTTokenMessage
    }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    Write-Verbose "[$functionName] Payload part: $($payload.Length)"
    switch ($payload.Length % 4)
    {
        2
        {
            Write-Verbose "[$functionName] Adjusting payload length by adding two padding characters."; $payload += '==' 
        }
        3
        {
            Write-Verbose "[$functionName] Adjusting payload length by adding one padding character."; $payload += '=' 
        }
    }
    Write-Verbose "[$functionName] Adjusted payload for Base64 decoding: $($payload.Length)"
    $bytes = [System.Convert]::FromBase64String($payload)
    Write-Verbose "[$functionName] Decoded bytes length: $($bytes.Length)"
    if ($bytes.Length -eq 0)
    {
        Write-Verbose "[$functionName] Decoded bytes are empty. Invalid JWT payload."
        return $returnValues.invalidJWTPayloadMessage
    }
    Write-Verbose "[$functionName] Decoding payload to JSON string."
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    $claims = $json | ConvertFrom-Json
    if (-not $raw)
    {
        # Convert all claims to human readable if possible
        Write-Verbose "[$functionName] Converting JWT claims to human readable format."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting JWT claims to human readable format" -LogLevel "Debug"
        $humanClaims = [ordered]@{}
        foreach ($key in $claims.PSObject.Properties.Name)
        {
            Write-Verbose "[$functionName] Processing claim: $key"
            $value = $claims.$key
            Write-Verbose "[$functionName] Claim value: $value"
            Write-Verbose "[$functionName] Claim value type: $($value.GetType().Name)"
            # Check if the key is a known identifier and convert it to human readable format
            Write-Verbose "[$functionName] Checking if claim key $key is a known identifier."
            if ($HRIdentifyers.ContainsKey($key))
            {
                Write-Verbose "[$functionName] Claim key $key is a known identifier, converting to human readable format."
                $key = $HRIdentifyers[$key]
            }
            else
            {
                Write-Verbose "[$functionName] Claim key $key is not a known identifier, Skipping."
                continue
            }
            # Try to convert unix time fields
            if ($value -is [int] -or $value -is [long])
            {
                # Heuristic: treat as unix time if key is a known time claim or value is in a reasonable unix time range
                Write-Verbose "[$functionName] Claim is a number, checking if it is a unix time."
                if ($value -gt 1000000000 -and $value -lt 3000000000)
                {
                    Write-Verbose "[$functionName] Claim $key is a unix time, converting to human readable format."
                    $dt = [DateTimeOffset]::FromUnixTimeSeconds([long]$value).UtcDateTime
                    $humanClaims[$key] = FormatDateWithTimeZone -DateTime $dt
                    continue
                }
            }
            # Try to convert arrays to comma-separated string
            Write-Verbose "[$functionName] Checking if claim value is an array."
            if ($value -is [array])
            {
                Write-Verbose "[$functionName] Claim value is an array, converting to comma-separated string."
                $humanClaims[$key] = $value -join ', '
                continue
            }
            else
            {
                Write-Verbose "[$functionName] Claim value is not an array."    
            }
            if ($key -eq 'AuthenticationMechanism')
            {
                switch ($value)
                {
                    0
                    { 
                        $value = 'Public'
                        Write-Verbose "[$functionName] AuthenticationMechanism is 0, setting value to $value"
                    }
                    1 
                    { 
                        $value = 'App Secret'
                        Write-Verbose "[$functionName] AuthenticationMechanism is 1, setting value to $value"
                    }
                    2 
                    { 
                        $value = 'Certificate'
                        Write-Verbose "[$functionName] AuthenticationMechanism is 2, setting value to $value"
                    }
                    default 
                    { 
                        $value = $value
                        Write-Verbose "[$functionName] AuthenticationMechanism is unknown, keeping value as $value"
                    }
                }
                $humanClaims[$key] = $value
                continue
            }
            # Otherwise, just copy
            $humanClaims[$key] = $value
        }
        if ($RawJSON)
        {
            Write-Verbose "[$functionName] Returning all decoded JWT claims as raw JSON."
            return $humanClaims | ConvertTo-Json -Depth 5
        }
        else
        {
            Write-Verbose "[$functionName] Returning all decoded JWT claims as object."
            return $humanClaims
        }
    }
    if ($RawJSON)
    {
        Write-Verbose "[$functionName] Returning raw decoded JWT payload as raw JSON."
        return $json 
    }
    else
    {
        Write-Verbose "[$functionName] Returning raw decoded JWT payload."
        return $json | ConvertFrom-Json
    }
}

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
    Write-Verbose "[$functionName] Starting scope validation for $($ResourcePath.Count) resource paths"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting scope validation for $($ResourcePath.Count) resource paths" -LogLevel "Information"
    
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

        Write-Verbose "[$functionName] Testing authorization for required scope: $RequiredScope"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Testing authorization for required scope: $RequiredScope" -LogLevel "Debug"
        
        # Direct match
        if ($AuthorizedScopes -contains $RequiredScope)
        {
            Write-Verbose "[$functionName] Direct scope match found for: $RequiredScope"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Direct scope match found for: $RequiredScope" -LogLevel "Debug"
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
                    Write-Verbose "[$functionName] Hierarchical scope match: '$authorizedScope' includes '$RequiredScope'"
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
        
        Write-Verbose "[$functionName] No scope authorization found for: $RequiredScope"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No scope authorization found for: $RequiredScope" -LogLevel "Debug"
        return $false
    }
    
    $returnObjects = @()
    $allScopesAuthorized = $true
    Write-Verbose "[$functionName] Checking $($ResourcePath.Count) resource paths for required scopes."
    
    foreach ($uri in $ResourcePath)
    {
        Write-Verbose "[$functionName] Checking resource path: $uri"
        Write-Verbose "[$functionName] Checking resource path: $uri"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking resource path: $uri" -LogLevel "Information"
        
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($matchingScopes.Count) matching scopes for endpoint: $relativeUri" -LogLevel "Information"
        
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
            Write-Verbose "[$functionName] URI '$uri' is AUTHORIZED with $($authorizedScopeDetails.Count) satisfied scope(s)"
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
        Write-Verbose "[$functionName] URI '$uri' authorization status: $uriAuthorized"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "URI '$uri' authorization status: $uriAuthorized" -LogLevel "Information"
    }
    
    Write-Verbose "[$functionName] Overall authorization status: $allScopesAuthorized" 
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Overall authorization status: $allScopesAuthorized" -LogLevel "Information"
    
    # Create a summary object for easier consumption
    $authorizationSummary = [PSCustomObject]@{
        OverallAuthorized = $allScopesAuthorized
        TotalUrisChecked  = $returnObjects.Count
        Details           = $returnObjects
    }
    
    return $authorizationSummary
}

function FormatScopes()
{
    [CmdletBinding()]
    param(
        [string[]]$scopes,
        [switch]$Reverse
    )
    $functionName = $MyInvocation.MyCommand.Name
    $openIdScopes = @('offline_access', 'openid')
    Write-Verbose "[$functionName] Called with Reverse=$Reverse"
    # Write-Verbose "[$functionName] Input scopes: '$scopes'"
    Write-Verbose "Passed parameter type: $($scopes.GetType().Name)"
    #Check for null or empty scopes.
    if (-not $scopes -or $scopes -eq "")
    {
        Write-Verbose "[$functionName] No scopes provided. Returning empty string."
        Write-Warning "[$functionName] WARNING: Scopes parameter is null or empty!"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No scopes provided - scopes parameter is null or empty" -LogLevel "Warning"
        return ""
    }
    
    #region Format scopes properly if necessary
    $scopesFormatted = $scopes
    Write-Verbose "[$functionName] Received $($scopes.count) scopes"
    if ($Reverse)
    {
        # Reverse mode: Remove Graph API prefixes and don't add default scopes
        Write-Verbose "[$functionName] Reverse mode: Removing Graph API prefixes"
        Write-Verbose "[$functionName] Converting scopes to array for processing"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Converting scopes to array for processing" -LogLevel "Verbose"
        $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $formattedScopesArray = @()
        Write-Verbose "[$functionName] Processing scope array with $($scopesArray.Count) items"
        foreach ($scope in $scopesArray)
        {
            Write-Verbose "[$functionName] Processing scope: $scope"
            if ($scope.StartsWith("https://graph.microsoft.com/"))
            {
                Write-Verbose "[$functionName] Removing prefix from scope: $scope"
                $formattedScope = $scope -replace "https://graph.microsoft.com/", ""
                $formattedScopesArray += $formattedScope
                Write-Verbose "[$functionName] Scope is now: $formattedScope"
            }
            else
            {
                $formattedScopesArray += $scope
                Write-Verbose "[$functionName] Added as is (no prefix): $scope"
            }
        }
        Write-Verbose "[$functionName] Count of scopes with prefixes removed: $($formattedScopesArray.count)"
        $scopesFormatted = $formattedScopesArray
    }
    else
    {
        Write-Verbose "[$functionName] Formatting scopes for normal mode"
        # Normal mode: Add Graph API prefixes and default scopes
        Write-Verbose "[$functionName] Normal mode: Adding Graph API prefixes"
        $scopesArray = $scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $formattedScopesArray = @()
        Write-Verbose "[$functionName] Processing scope array with $($scopesArray.Count) items"
        foreach ($scope in $scopesArray)
        {
            Write-Verbose "[$functionName] Processing scope: $scope"
            if ($scope -in $openIdScopes)
            {
                $formattedScopesArray += $scope
                Write-Verbose "[$functionName] Added default scope as-is: $scope"
            }
            else
            {
                # Check if the scope already has the Graph prefix
                if (-not $scope.StartsWith("https://graph.microsoft.com/"))
                {
                    $formattedScopesArray += "https://graph.microsoft.com/$scope"
                    Write-Verbose "[$functionName] Added prefix: https://graph.microsoft.com/$scope"
                }
                else
                {
                    $formattedScopesArray += $scope
                    Write-Verbose "[$functionName] Added as-is (already has prefix): $scope"
                }
            }
        }
        Write-Verbose "[$functionName] Count of scopes with prefixes added: $($formattedScopesArray.count)"
        Write-Verbose "[$functionName] Adding default scopes (openid and offline_access)"
        #If the $scopesFormatted  does not contain a scope in the $openIdScopes, add the missing scope.
        foreach ($defaultScope in $openIdScopes)
        {
            if (-not $scopesFormatted.Contains($defaultScope))
            {
                Write-Verbose "[$functionName] Adding default scope: $defaultScope"
                $scopesFormatted += " $defaultScope"
            }
            else
            {
                Write-Verbose "[$functionName] Default scope already present: $defaultScope"
            }
        }
        $scopesFormatted = $formattedScopesArray -join ' '
        # Remove any extra spaces
        $scopesFormatted = $scopesFormatted.Trim()
    }
    Write-Verbose "[$functionName] Final formatted scopes: $scopesFormatted"
    #endregion Format scopes
    return $scopesFormatted
}    

function Get-TokenFromResponse()
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

function Start-HttpListener()
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

function Save-TokenToCache()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$cachedToken,
        [Parameter(Mandatory = $true)]
        [ValidateSet('file', 'memory')]
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$cacheFolder
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting token cache save operation"
    Write-Verbose "[$functionName] Cache type: $cacheType"
    # Extract token scope from JWT token roles
    Write-Verbose "[$functionName] Decoding JWT token to extract roles/scope"
    
    Write-Verbose "[$functionName] Successfully extracted token scope: $($tokenScope -join ', ')"
    # Add scope to cached token object
    Write-Verbose "[$functionName] Adding scope property to cached token object"
    if (-not $cachedToken.scope)
    {
        Write-Verbose "[$functionName] Scope property not found in cached token, adding it"
        $cachedToken.add('scope', (DecodeJwtToken -Token $cachedToken.access_token -raw).roles)
    }
    else
    {
        Write-Verbose "[$functionName] Scope property already exists in cached token. Applying proper formatting."
        $cachedToken.scope = FormatScopes -scopes $cachedToken.scope -Reverse
    }
    
    # Save access token according to cache type
    if ($cacheType -eq 'memory')
    {
        Write-Verbose "[$functionName] Saving access token to memory cache"
        
        # Initialize global memory cache if it doesn't exist
        if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
        {
            Write-Verbose "[$functionName] Initializing global memory cache"
            New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
        }
        
        # Save to memory cache
        $Global:MemoryCache['accessToken'] = $cachedToken
        Write-Verbose "[$functionName] Token successfully saved to memory cache"
        
        # Debug: Log what was actually saved
        if ($Global:MemoryCache['accessToken'].scope)
        {
            Write-Verbose "[$functionName] Verified scope is accessible: $($Global:MemoryCache['accessToken'].scope -join ', ')"
        }
        else
        {
            Write-Warning "[$functionName] Scope property not found in saved token"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Saving access token to cache file: $cacheTokenFile"
        
        if (-not (Test-Path -Path $cacheFolder))
        {
            Write-Verbose "[$functionName] Creating cache folder: $cacheFolder"
            New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
        }
        
        try
        {
            $cachedToken | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
            Write-Verbose "[$functionName] Access token successfully saved to $cacheTokenFile"
        }
        catch
        {
            Write-Error "[$functionName] Failed to save token to cache file: $_"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to save token to cache file: $_" -LogLevel "Error"
            throw
        }
    }
}

function Save-RefreshTokenToConfig()
{
    param($refreshToken, $configFilePath)

    $functionName = $MyInvocation.MyCommand.Name
    $DeligatedCredentials = @{}
    $userPassword = $null
    $usingTempConfig = $false
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting refresh token save operation" -LogLevel "Information"
    Write-Verbose "[$functionName] Called with configFilePath=$configFilePath, refreshToken provided=$($null -ne $refreshToken)"
    
    if (-not $refreshToken)
    {
        Write-Verbose "[$functionName] No refresh token to save"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No refresh token provided - operation skipped" -LogLevel "Warning"
        return
    }
    
    # First try to use the temporary encrypted config if available to avoid password prompt
    if ($script:TempEncryptedConfig -and $script:TempEncryptionKey)
    {
        Write-Verbose "[$functionName] Using existing temporary encrypted config to avoid password prompt"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using existing temporary encrypted config to avoid duplicate password prompt" -LogLevel "Information"
        
        # Decrypt the temporary config
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            Set-Content -Path $tempFile -Value $script:TempEncryptedConfig -Encoding UTF8
            $decryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -Decrypt -InMemoryOnly
            
            if ($decryptResult.Success)
            {
                $config = ConvertFrom-Json $decryptResult.Content
                $usingTempConfig = $true
                $needsEncryption = $true
                Write-Verbose "[$functionName] Successfully obtained config from temporary encrypted config"
            }
            else
            {
                Write-Warning "[$functionName] Failed to decrypt temporary config: $($decryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt temporary config, falling back to disk file: $($decryptResult.ErrorMessage)" -LogLevel "Warning"
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error accessing temporary config: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error accessing temporary config, falling back to disk file: $_" -LogLevel "Warning"
        }
        finally
        {
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force
            }
        }
    }
    
    # Fall back to reading and decrypting from disk if temporary config is not available
    if (-not $usingTempConfig)
    {
        Write-Verbose "[$functionName] Temporary config not available, reading from disk"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Temporary config not available, reading from disk file" -LogLevel "Debug"
        
        # Read the current config from disk (it should be encrypted)
        try
        {
            $encryptedContent = Get-Content -Raw -Path $configFilePath -ErrorAction Stop
            Write-Verbose "[$functionName] Successfully read config file from disk"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully read config file from disk" -LogLevel "Debug"
        }
        catch
        {
            Write-Error "[$functionName] Failed to read config file: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to read config file: $_" -LogLevel "Error"
            return
        }
        
        # Check if config is encrypted (it should be in the new system)
        $encryptionStatus = Test-FileEncryptionStatus -FilePath $configFilePath
        Write-Log -LogFile $LogFile -Module $functionName -Message "Config file encryption status: $($encryptionStatus.IsEncrypted)" -LogLevel "Debug"
        
        if (-not $encryptionStatus.IsEncrypted)
        {
            Write-Warning "[$functionName] Config file is not encrypted. This may indicate an issue with the encryption system."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Config file is not encrypted - handling for backward compatibility" -LogLevel "Warning"
            # For backward compatibility, handle unencrypted config
            $config = ConvertFrom-Json $encryptedContent
            $needsEncryption = $true
        }
        else
        {
            Write-Verbose "[$functionName] Config file is encrypted. Prompting for password to decrypt for modification."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Config file is encrypted - prompting for password to decrypt for modification" -LogLevel "Debug"
            # Need to get the user's password to decrypt the config file
            $userPasswordSecure = Get-SecurePassword -Message "Enter your encryption password to update the refresh token"
            $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
            
            # Decrypt the config file
            $decryptResult = Invoke-JsonFileEncryption -FilePath $configFilePath -Key $userPassword -Decrypt -InMemoryOnly
            
            if (-not $decryptResult.Success)
            {
                Write-Error "[$functionName] Failed to decrypt config file: $($decryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt config file: $($decryptResult.ErrorMessage)" -LogLevel "Error"
                return
            }
            
            $config = ConvertFrom-Json $decryptResult.Content
            $needsEncryption = $true
        }
    }
    
    # Format scopes
    if ($refreshToken.scope)
    {
        Write-Verbose "[$functionName] Adding scope to new deligatedCredentials"
        $formattedScopes = FormatScopes -scopes $refreshToken.scope -Reverse
        Write-Verbose "[$functionName] Formatted scopes object type: $($formattedScopes.GetType().Name)"
        #If it is not an array, make it int an array
        if (-not ($formattedScopes -is [array]))
        {
            Write-Verbose "[$functionName] Scopes is not an array, converting to array"
            $formattedScopes = @($formattedScopes)
        }
    }
    else
    {
        Write-Verbose "[$functionName] No scopes provided in refresh token, using empty array"
        $formattedScopes = @()
    }

    # Update the config with the new refresh token
    if ($config.deligatedCredentials)
    {
        Write-Verbose "[$functionName] Updating existing deligatedCredentials property"
        $config.deligatedCredentials.refresh_token = $refreshToken.refresh_token
        $config.deligatedCredentials.scope = $formattedScopes
    }
    else
    {
        Write-Verbose "[$functionName] Creating new deligatedCredentials property"
        $deligatedCredentials.refresh_token = $refreshToken.refresh_token
        $deligatedCredentials.scope = $formattedScopes
        $config | Add-Member -MemberType NoteProperty -Name 'deligatedCredentials' -Value $DeligatedCredentials
    }

    # Re-encrypt the config and save it
    if ($needsEncryption)
    {
        # If we used temporary config but don't have user password, check if it's available in script variable
        if ($usingTempConfig -and -not $userPassword)
        {
            if ($script:UserEncryptionPassword)
            {
                Write-Verbose "[$functionName] Using cached user password from startup for disk encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using cached user password from startup - no additional prompt needed" -LogLevel "Information"
                $userPassword = $script:UserEncryptionPassword
            }
            else
            {
                Write-Verbose "[$functionName] Need user password for disk encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting for password to encrypt updated config to disk" -LogLevel "Debug"
                $userPasswordSecure = Get-SecurePassword -Message "Enter your encryption password to save the updated configuration"
                $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
            }
        }
        
        Write-Verbose "[$functionName] Re-encrypting config with refresh token for disk storage"
        # Create a temporary file for the updated config
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8
            
            # Re-encrypt with the user's password
            $encryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $userPassword
            
            if ($encryptResult.Success)
            {
                Write-Verbose "[$functionName] Config re-encrypted successfully"
                # Move the encrypted temp file to the original location
                Copy-Item -Path $tempFile -Destination $configFilePath -Force
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully saved encrypted config to disk" -LogLevel "Information"
            }
            else
            {
                Write-Error "[$functionName] Failed to re-encrypt config: $($encryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to re-encrypt config: $($encryptResult.ErrorMessage)" -LogLevel "Error"
                return
            }
        }
        finally
        {
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force
            }
        }
    }
    else
    {
        # Save the updated config without encryption
        Write-Verbose "[$functionName] Saving refresh token to config file: $configFilePath"
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -Force
    }
    Write-Verbose "[$functionName] Refresh token saved to config file"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Refresh token operation completed successfully" -LogLevel "Information"
    
    # Always update the temporary encrypted config if it exists to keep it in sync
    if ($script:TempEncryptedConfig -and $script:TempEncryptionKey)
    {
        Write-Verbose "[$functionName] Updating temporary encrypted config with new refresh token"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating temporary encrypted config to maintain consistency" -LogLevel "Debug"
        try
        {
            # Create a temporary file with the decrypted config
            $tempFile = [System.IO.Path]::GetTempFileName()
            try
            {
                $config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8
                
                # Re-encrypt with the temporary key
                $tempEncryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -InMemoryOnly
                
                if ($tempEncryptResult.Success)
                {
                    $script:TempEncryptedConfig = $tempEncryptResult.Content
                    Write-Verbose "[$functionName] Successfully updated temporary encrypted config"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully updated temporary encrypted config" -LogLevel "Debug"
                }
                else
                {
                    Write-Warning "[$functionName] Failed to update temporary encrypted config: $($tempEncryptResult.ErrorMessage)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update temporary encrypted config: $($tempEncryptResult.ErrorMessage)" -LogLevel "Warning"
                }
            }
            finally
            {
                if (Test-Path $tempFile)
                {
                    Remove-Item $tempFile -Force
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Failed to update temporary encrypted config: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update temporary encrypted config: $_" -LogLevel "Warning"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No temporary encrypted config available to update"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No temporary encrypted config available to update" -LogLevel "Debug"
    }
    
    # Clear the user password from memory
    if ($userPassword)
    {
        Clear-SecureMemory -Variables @("userPassword")
    }
}

function Format-TokenOutput()
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

function Test-RefreshTokenValidity()
{
    param(
        $refreshToken,
        $clientId,
        $clientSecret,
        $tenantId,
        $scopes,
        $domain,
        $AuthType
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
            refresh_token = $refreshToken
            grant_type    = 'refresh_token'
            scope         = $scopesFormatted
        }
        if ($AuthType -eq 'PublicAuthFlow')
        {
            $refreshTokenRequestBody.Add('client_secret', $clientSecret)
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

function Get-RefreshToken()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$accessTokenObject,
        [Parameter(Mandatory = $true)]
        [string]$clientId,
        [string]$clientSecret,
        [Parameter(Mandatory = $true)]
        [string]$tenantId,
        [string[]]$scopes,
        [Parameter(Mandatory = $true)]
        [string]$domain,
        [ValidateSet('file', 'memory')]
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$cacheFolder,
        [string]$configFilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Attempting to use refresh token to get a new access token"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Attempting to use refresh token to get a new access token" -LogLevel "Information"
    try
    {
        # First test if the refresh token is valid
        $isValid, $tokenResponse = Test-RefreshTokenValidity -refreshToken $accessTokenObject.refresh_token -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain
        if (-not $isValid)
        {
            Write-Verbose "[$functionName] Refresh token is invalid or expired. Cannot proceed with token refresh."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Refresh token is invalid or expired. Cannot proceed with token refresh." -LogLevel "Error"
            return $null
        }
        Write-Verbose "[$functionName] Refresh token is valid. Proceeding to get new access token."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Refresh token is valid. Proceeding to get new access token." -LogLevel "Information"
        $cachedToken = Get-TokenFromResponse -tokenResponse $tokenResponse -domain $domain -refreshToken $tokenResponse.refresh_token
        # Cache the access token based on cache type
        Save-TokenToCache -cachedToken $cachedToken -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder
        # Only save the refresh token if it's different from the one we already have
        Write-Verbose "[$functionName] Checking whether to save the refresh token..."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking whether to save the refresh token..." -LogLevel "Verbose"
        if ($tokenResponse.refresh_token -and $tokenResponse.refresh_token -ne $accessTokenObject.refresh_token)
        {
            Write-Verbose "[$functionName] Saving new refresh token as it differs from the existing one."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Saving new refresh token as it differs from the existing one." -LogLevel "Verbose"
            Save-RefreshTokenToConfig -refreshToken $tokenResponse -configFilePath $configFilePath
        }
        else
        {
            Write-Verbose "[$functionName] No need to save refresh token as it hasn't changed."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No need to save refresh token as it hasn't changed." -LogLevel "Verbose"
        }
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $SecureString
    }
    catch
    {
        Write-Host "Failed to use refresh token: $_. Will request new authorization."
        Write-Host "Refresh token might be expired or revoked, proceeding with new authorization."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to use refresh token: $_. Will request new authorization." -LogLevel "Error"
        return $null
    }
}

function Get-TokenFromCache()
{
    [CmdletBinding()]
    param(
        [ValidateSet('file', 'memory')]
        [string]$cacheType,
        [string]$domain,
        [int]$renewalLeadTime,
        [string]$clientId,
        [string]$clientSecret,
        [string]$tenantId,
        [string[]]$scopes,
        [bool]$deligated,
        [string]$cacheFolder,
        [string]$cacheTokenFile,
        [bool]$secureString,
        [string]$configFilePath,
        [string]$configRefreshToken
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting token cache retrieval for domain: $domain"
    Write-Verbose "[$functionName] Cache type: $cacheType, Delegated: $deligated"
    
    # Calculate time buffer for token renewal
    $timeBuffer = (Get-Date).AddMinutes($renewalLeadTime)
    Write-Verbose "[$functionName] Token renewal buffer time: $timeBuffer"
    
    # Get cached token object based on cache type
    $accessTokenObject = Get-CachedTokenObject -cacheType $cacheType -cacheTokenFile $cacheTokenFile -domain $domain 
    
    # If we have a cached token, validate and return it
    if ($accessTokenObject)
    {
        $validToken = Test-CachedTokenValidity -accessTokenObject $accessTokenObject -timeBuffer $timeBuffer -domain $domain -cacheType $cacheType
        if ($validToken)
        {
            return $validToken
        }
        
        # Token is expired, try to refresh it
        $refreshedToken = Invoke-TokenRefresh -accessTokenObject $accessTokenObject -deligated $deligated -configRefreshToken $configRefreshToken -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath 
        if ($refreshedToken)
        {
            return $refreshedToken
        }
    }
    
    # No cached token found, try config refresh token as fallback
    if ($deligated -and $configRefreshToken)
    {
        Write-Verbose "[$functionName] No valid cached token found, attempting to use config refresh token"
        $refreshTokenObject = @{ refresh_token = $configRefreshToken }
        return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    Write-Verbose "[$functionName] No valid token found in cache or config"
    return $null
}

# Helper function to get cached token object
function Get-CachedTokenObject()
{
    [CmdletBinding()]
    param(
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$domain
    )
    $functionName = $MyInvocation.MyCommand.Name
    switch ($cacheType)
    {
        'memory'
        {
            Write-Verbose "[$functionName] Checking memory cache for access token"
            
            # Initialize memory cache if it doesn't exist
            if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
            {
                Write-Verbose "[$functionName] Initializing memory cache"
                New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
            }
            
            if ($Global:MemoryCache.ContainsKey('accessToken'))
            {
                $tokenObject = $Global:MemoryCache['accessToken']
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in memory cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] Memory cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] No token found in memory cache"
            }
            return $null
        }
        
        'file'
        {
            Write-Verbose "[$functionName] Checking file cache for access token: $cacheTokenFile"
            
            if (-not (Test-Path -Path $cacheTokenFile))
            {
                Write-Verbose "[$functionName] Cache file not found: $cacheTokenFile"
                return $null
            }
            
            try
            {
                $tokenObject = Get-Content -Path $cacheTokenFile -Raw -Force | ConvertFrom-Json
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in file cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] File cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            catch
            {
                Write-Warning "[$functionName] Failed to read cache file: $_"
                Write-Verbose "[$functionName] Cache file may be corrupted or invalid"
            }
            return $null
        }
        default
        {
            Write-Error "[$functionName] Invalid cache type: $cacheType. Use 'file' or 'memory'."
            return $null
        }
    }
}

# Helper function to test cached token validity
function Test-CachedTokenValidity()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject,
        [datetime]$timeBuffer,
        [string]$domain,
        [string]$cacheType
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

# Helper function to normalize expiry time formats
function Get-NormalizedExpiryTime()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $accessTokenObject.AbsoluteExpiryTime)
    {
        Write-Verbose "[$functionName] No AbsoluteExpiryTime found in token object"
        return [datetime]::MinValue
    }
    
    try
    {
        if ($accessTokenObject.AbsoluteExpiryTime -is [string])
        {
            Write-Verbose "[$functionName] Converting string expiry time to datetime"
            $parsedTime = [datetime]::Parse($accessTokenObject.AbsoluteExpiryTime).ToLocalTime()
            
            # Handle timezone differences
            if ($parsedTime -lt $accessTokenObject.AbsoluteExpiryTime)
            {
                Write-Verbose "[$functionName] Using original expiry time to resolve timezone differences"
                return $accessTokenObject.AbsoluteExpiryTime
            }
            return $parsedTime
        }
        else
        {
            Write-Verbose "[$functionName] Using datetime expiry time as-is"
            return $accessTokenObject.AbsoluteExpiryTime
        }
    }
    catch
    {
        Write-Warning "[$functionName] Failed to parse expiry time: $_"
        return [datetime]::MinValue
    }
}

# Helper function to handle token refresh logic
function Invoke-TokenRefresh()
{
    [CmdletBinding()]
    param(
        [object]$accessTokenObject,
        [bool]$deligated,
        [string]$configRefreshToken,
        [string]$clientId,
        [string]$clientSecret,
        [string]$tenantId,
        [string[]]$scopes,
        [string]$domain,
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$cacheFolder,
        [string]$configFilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
    if (-not $deligated)
    {
        Write-Verbose "[$functionName] Not using delegated authentication, skipping refresh token logic"
        return $null
    }
    
    # Try cached refresh token first
    if ($accessTokenObject.refresh_token)
    {
        Write-Verbose "[$functionName] Attempting to refresh token using cached refresh token"
        return Get-RefreshToken -accessTokenObject $accessTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    # Try config refresh token as fallback
    if ($configRefreshToken)
    {
        Write-Verbose "[$functionName] Attempting to refresh token using config refresh token"
        $refreshTokenObject = @{ refresh_token = $configRefreshToken }
        return Get-RefreshToken -accessTokenObject $refreshTokenObject -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $scopes -domain $domain -cacheType $cacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -configFilePath $configFilePath
    }
    
    Write-Verbose "[$functionName] No refresh token available for token refresh"
    return $null
}

function LaunchBrowser()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$url,
        [ValidateSet("Chrome", "Edge", "Firefox", "Default")]
        [string]$browser
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #print log of incoming parameters.
    Write-Verbose "[$functionName] Launching browser with URL: $url"
    Write-Verbose "[$functionName] Browser preference: $browser"
    Write-Verbose "[$functionName] Private session: $private"
    if ($null -eq $browser -or $browser -eq '')
    {
        Write-Verbose "[$functionName] No browser specified, attempting to read value from settings"
        if ($null -ne $settings.preferredBrowser -and $settings.preferredBrowser -ne '')
        {
            Write-Verbose "[$functionName] Using preferred browser from settings: $($settings.preferredBrowser)"
            $browser = $settings.preferredBrowser
        }
        else
        {
            Write-Verbose "[$functionName] No preferred browser set in settings, defaulting to Edge"
            $browser = 'Default'
        }
    }
    
    switch ($Browser)
    {
        'Edge'
        {
            Write-Verbose "[$functionName] Opening Edge browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
                    ArgumentList = "--inprivate", $authUrl
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
                    ArgumentList = $authUrl
                }
            }
        }
        'Chrome'
        {
            Write-Verbose "[$functionName] Opening Chrome browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                    ArgumentList = "--incognito", $authUrl
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                    ArgumentList = $authUrl
                }
            }
        }
        'Firefox'
        {
            Write-Verbose "[$functionName] Opening Firefox browser for authentication"
            if ($settings.privateSession)
            {
                Write-Verbose "[$functionName] Private session detected.  Opening $($settings.preferredBrowser) in private mode"
                $urlParams = @{
                    FilePath     = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    ArgumentList = "-private-window", $authUrl
                }
            }
            else
            {
                $urlParams = @{
                    FilePath     = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    ArgumentList = $authUrl
                }
            }
        }
        default
        {
            Write-Verbose "[$functionName] Opening default browser for authentication"
            $urlParams = @{
                FilePath     = "start"
                ArgumentList = $authUrl
            }
        }
    }
    Write-Verbose "[$functionName] Launching $browser with URL: $url"
    try
    {
        # Start the browser with the specified URL
        Start-Process @urlParams 
        Write-Verbose "[$functionName] Browser launched successfully."
    }
    catch
    {
        Write-Error "Failed to launch browser: $_"
        return $false
    }
    return $true
}

function GetTokenFromMGGraph()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $scope,
        $apiVersion = 'Beta'
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting to get access token from Microsoft Graph with scope: $scope"
    Write-Verbose "[$functionName] Attempting to get access token from Microsoft Graph."
    Connect-MgGraph -UseDeviceCode -Scopes $scope  
    $global:data = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/$apiVersion/me" -Method GET -OutputType HttpResponseMessage
    $accessToken = $data.RequestMessage.Headers.Authorization.Parameter
    Write-Verbose "[$functionName] Successfully obtained access token."
    return $accessToken
}

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

function Get-ClientCredentialsToken()
{
    param($tenantId, $clientId, $clientSecret, $domain, $cacheType, $cacheTokenFile, $cacheFolder, $secureString)
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
        return Format-TokenOutput -token $tokenResponse.access_token -secureString $secureString
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

function BuildAuthSplatTable()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $auth
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Received object of type $($auth.GetType().Name)"
    # Dynamic splatting approach - iterate over all auth properties    # Create clean splatting hashtable starting with required parameter
    $getTokenParams = @{
        configFile = $configFile
    }    # Define valid parameters for GetGraphAccessToken function (case-insensitive comparison)
    $validParams = @('renewalLeadTime', 'SecureString', 'NoSaveRefreshToken', 'Deligated', 'Scope', 'AuthType', 'ForceNewToken', 'ForceNewRefreshToken', 'CacheType', 'configFile')
    # Define parameters that are only valid when Deligated is true (parameterSetName = 'Deligated')
    $deligatedOnlyParams = @('NoSaveRefreshToken', 'Deligated', 'Scope', 'AuthType', 'ForceNewRefreshToken')

    Write-Verbose "[$functionName] Debugging BuildAuthSplatTable - Auth object properties:"
    foreach ($key in $auth.Keys)
    {
        $value = $auth[$key]
        Write-Verbose "[$functionName]  Property: '$key' = '$value' (Type: $($value.GetType().Name))"
    }
    
    # Iterate over all properties in the auth object
    foreach ($property in $auth.Keys)
    {
        $paramName = $property
        $paramValue = $auth[$property]
        Write-Verbose "[$functionName] Processing property '$paramName' with value '$paramValue'"

        # Special debugging for scope parameter
        if ($paramName -ieq 'scope')
        {
            Write-Verbose "[$functionName] SCOPE DEBUG: Found scope parameter with value: '$paramValue'"
            Write-Verbose "[$functionName] SCOPE DEBUG: Value type: $($paramValue.GetType().Name)"
            if ($paramValue -is [array])
            {
                Write-Verbose "[$functionName] SCOPE DEBUG: Scope is array with $($paramValue.Count) elements: $($paramValue -join ', ')"
            }
        }
        
        # Find the correct parameter name (case-insensitive match)
        $correctParamName = $validParams | Where-Object { $_ -ieq $paramName } | Select-Object -First 1

        Write-Verbose "[$functionName] Case-insensitive match for '$paramName': '$correctParamName'"
        # Skip if not a valid parameter for the function
        if (-not $correctParamName)
        {
            Write-Verbose "[$functionName] Skipping parameter '$paramName' as it's not valid for GetGraphAccessToken"
            continue
        }
        
        # Skip if value is null, empty, or false for switch parameters
        if ($null -eq $paramValue -or $paramValue -eq '' -or $paramValue -eq $false)
        {
            Write-Verbose "[$functionName] Skipping parameter '$paramName' due to null/empty/false value"
            continue
        }        # Check if this is a delegated-only parameter (case-insensitive)
        $isDelegatedOnlyParam = $deligatedOnlyParams | Where-Object { $_ -ieq $paramName } | Select-Object -First 1
        if ($isDelegatedOnlyParam)
        {
            # Only add if Deligated is true in the auth object
            # Handle both hashtable and PSObject cases
            $hasDelegatedProperty = $false
            $delegatedValue = $false
            
            if ($auth -is [hashtable])
            {
                $hasDelegatedProperty = $auth.ContainsKey('Deligated')
                if ($hasDelegatedProperty)
                {
                    $delegatedValue = $auth.Deligated
                }
            }
            else
            {
                $hasDelegatedProperty = $auth.PSObject.Properties.Name -contains 'Deligated'
                if ($hasDelegatedProperty)
                {
                    $delegatedValue = $auth.Deligated
                }
            }
            
            Write-Verbose "[$functionName] Delegated check: HasProperty=$hasDelegatedProperty, Value=$delegatedValue, ValueType=$($delegatedValue.GetType().Name)"
            
            if ($hasDelegatedProperty -and $delegatedValue)
            {
                Write-Verbose "[$functionName] Adding delegated parameter '$paramName' with value: $paramValue"
                #Check if the parameter is an array, and if so convert it to a space seperated string
                if ($paramValue -is [array])
                {
                    $paramValue = $paramValue -join ' '
                    Write-Verbose "[$functionName] Converted array parameter '$paramName' to space-separated string: $paramValue"
                }
                # Use the correct parameter name (properly capitalized) for the hashtable
                $getTokenParams[$correctParamName] = $paramValue
                Write-Verbose "[$functionName] Added delegated parameter '$correctParamName' with value: $paramValue"
                
                # Special debugging for scope parameter
                if ($correctParamName -ieq 'Scope')
                {
                    Write-Verbose "[$functionName] SCOPE DEBUG: Added scope to hashtable with key '$correctParamName' and value '$paramValue'"
                }
            }
            else
            {
                Write-Verbose "[$functionName] Skipping delegated parameter '$paramName' because Deligated is not true (HasProperty=$hasDelegatedProperty, Value=$delegatedValue)"
            }
        }
        else
        {
            # Add general parameters (not restricted to delegated mode)
            Write-Verbose "[$functionName] Adding parameter '$paramName' with value: $paramValue"
            # Use the correct parameter name (properly capitalized) for the hashtable
            $getTokenParams[$correctParamName] = $paramValue
        }
    }    # Log the final splatting parameters for verification
    Write-Verbose "[$functionName] Final splatting parameters:"
    foreach ($param in $getTokenParams.GetEnumerator())
    {
        if ($param.Key -eq 'configFile')
        {
            Write-Verbose "[$functionName]   $($param.Key): $($param.Value)"
        }
        elseif ($param.Value -is [bool])
        {
            Write-Verbose "[$functionName]  $($param.Key): $($param.Value)"
        }
        else
        {
            Write-Verbose "[$functionName]  $($param.Key): '$($param.Value)'"
        }
    }
    
    # Special debug for Scope parameter
    if ($getTokenParams.ContainsKey('Scope'))
    {
        Write-Verbose "[$functionName] DEBUG: Scope parameter found in hashtable: '$($getTokenParams.Scope)'" 
    }
    else
    {
        Write-Verbose "[$functionName] DEBUG: Scope parameter NOT found in hashtable!"
        Write-Verbose "[$functionName] DEBUG: Available keys: $($getTokenParams.Keys -join ', ')"
    }
    
    # Return the splatting hashtable
    Write-Verbose "[$functionName] Returning splatting hashtable with parameters for GetGraphAccessToken"
    return $getTokenParams
}

function ProcessFilterCondition()
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

function GetGraphAccessToken()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$configFile,
        [int]$renewalLeadTime = 5,
        [switch]$SecureString,
        [parameter(parameterSetName = 'Deligated')]
        [switch]$NoSaveRefreshToken,
        [parameter(parameterSetName = 'Deligated')]
        [switch]$Deligated,
        [parameter(parameterSetName = 'Deligated')]
        [string[]]$Scope,
        [parameter(parameterSetName = 'Deligated')]
        [ValidateSet('PublicAuthFlow', 'Interactive', 'Private', 'MGGraph')]
        [string]$AuthType = 'Private', 
        [parameter(parameterSetName = 'Deligated')]
        [switch]$ForceNewToken,
        [parameter(parameterSetName = 'Deligated')]
        [switch]$ForceNewRefreshToken,
        [ValidateSet('file', 'memory')]
        [string]$CacheType = 'Memory',
        [string]$APIVersion = 'Beta'
    )
    
    #region Process config files
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting Graph access token retrieval" -LogLevel "Information"
    
    # Read and process configuration file
    if (-not $configFile)
    {
        Write-Error "Config file not found. Please provide a valid config file."
        Write-Log -LogFile $LogFile -Module $functionName -Message "Config file not found. Please provide a valid config file." -LogLevel "Error"
        return $null
    }

    Write-Verbose "[$functionName] Accessing config values from in-memory encrypted config"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Accessing config values from in-memory encrypted config" -LogLevel "Debug"
    $configRefreshToken = $null
    
    # Extract the refresh token if it exists using the new encryption system
    try
    {
        $configRefreshToken = Get-DecryptedConfigValue -PropertyPath "deligatedCredentials.refresh_token"
        if ($configRefreshToken)
        {
            Write-Verbose "[$functionName] Found refresh token in encrypted config."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Found refresh token in encrypted config" -LogLevel "Debug"
        }
        else
        {
            Write-Verbose "[$functionName] No refresh token found in config."
            Write-Log -LogFile $LogFile -Module $functionName -Message "No refresh token found in config" -LogLevel "Debug"
        }
    }
    catch
    {
        Write-Verbose "[$functionName] No deligatedCredentials.refresh_token found in config."
    }
    # Handle ForceNewRefreshToken parameter
    if ($ForceNewRefreshToken -and $Deligated)
    {
        Write-Host "Force new refresh token requested. Invalidating existing refresh token." -ForegroundColor Yellow
        Write-Verbose "[$functionName] ForceNewRefreshToken requested. Clearing existing refresh token from memory."
        
        # Clear the configRefreshToken variable so a new one will be obtained
        $configRefreshToken = $null
        Write-Verbose "[$functionName] Cleared configRefreshToken variable. New refresh token will be obtained and saved to config."
    }    
    
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
    
    try
    {
        $clientSecret = Get-DecryptedConfigValue -PropertyPath "AppSecret"
        if ($clientSecret)
        {
            Write-Verbose "[$functionName] Client Secret found in config."
        }
        else
        {
            Write-Verbose "[$functionName] Client Secret not found in config file."
            Write-Verbose "Checking whether the authtype is public flow which does not require client secret."
            if ($AuthType -ne 'PublicAuthFlow')
            {
                Write-Error "Client Secret is required for the selected authentication type."
                return $null
            }
            Write-Verbose "[$functionName] Public Auth Flow does not require Client Secret."
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Client Secret not found in config file."
        Write-Verbose "Checking whether the authtype is public flow which does not require client secret."
        if ($AuthType -ne 'PublicAuthFlow')
        {
            Write-Error "Client Secret is required for the selected authentication type."
            return $null
        }
        Write-Verbose "[$functionName] Public Auth Flow does not require Client Secret."
    }
    if ($deligated )
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
    Write-Verbose "[$functionName] Deligated: $Deligated"
    Write-Verbose "[$functionName] Scopes: $Scope"
    Write-Verbose "[$functionName] Config has refresh token: $($null -ne $configRefreshToken)"
    #endregion Log parameters
    
    # Set up cache paths
    $cacheFolder = Split-Path $configFile
    $cacheTokenFile = Join-Path $cacheFolder "accessToken.json"
    
    #region Try to get token from cache if not forcing new token
    $accessToken = $null
    if (-not $ForceNewToken)
    {
        $accessToken = Get-TokenFromCache -cacheType $CacheType -domain $domain -renewalLeadTime $renewalLeadTime `
            -clientId $clientId -clientSecret $clientSecret -tenantId $tenantId -scopes $Scope `
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
    #endregion Try to get token from cache if not forcing new token
    
    #region Authentication flow
    if ($deligated)
    {
        Write-Verbose "[$functionName] Deligated authentication flow selected." 
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
            }
            Interactive
            {
                Write-Verbose "[$functionName] Using interactive authentication flow for delegated token."
                $params += @{
                    clientSecret = $clientSecret
                }
            }
            Private
            {
                Write-Verbose "[$functionName] Using private authentication flow for delegated token."
                $params += @{
                    clientSecret = $clientSecret
                }
            }        
            MGGraph
            {
                Write-Verbose "[$functionName] Using Microsoft Graph authentication flow for delegated token."
                $params += @{
                    APIVersion = $APIVersion
                }
            }
        }
        if ($NoSaveRefreshToken)
        {
            Write-Verbose "[$functionName] No save refresh token option selected. Not saving refresh token."
            $params += @{
                NoSaveRefreshToken = $NoSaveRefreshToken
            }
        }
        if ($ForceNewRefreshToken)
        {
            Write-Verbose "[$functionName] Force new refresh token requested. This will force a new authentication flow."
            # Add a marker to indicate this was a forced refresh token renewal
            $params += @{
                ForcedRenewal = $true
            }
        }
        return Get-DelegatedToken @params
    }
    else
    {
        if ($tenantId -and $clientId -and $clientSecret)
        {
            return Get-ClientCredentialsToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret `
                -domain $domain -cacheType $CacheType -cacheTokenFile $cacheTokenFile -cacheFolder $cacheFolder -secureString $SecureString
        }
        else
        {
            Write-Error "Missing required authentication parameters (tenantId, clientId, or clientSecret)"
            return $null
        }
    }
    #endregion Authentication flow
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
    Write-Verbose "[$functionName] Preparing parameters for Invoke-RestMethod call."
    $restParams = @{
        Method          = $method
        Uri             = $encodedUri
        Headers         = $headers
        UseBasicParsing = $true
    }
    # Only add Body parameter if it exists
    if ($body)
    {
        Write-Verbose "[$functionName] Body parameter provided. Adding to the request."
        $restParams['Body'] = $body
    }
    #Add statusCodeVariable if we are running under powershell  7.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        Write-Verbose "[$functionName] PowerShell version is $($PSVersionTable.PSVersion.Major ). Adding StatusCodeVariable to the request."
        Write-Verbose "[$functionName] Added StatusCodeVariable."
        $restParams['StatusCodeVariable'] = 'statusCode'
    }
    Write-Verbose "[$functionName] Making the following call to Microsoft Graph:" 
    Write-Verbose "[$functionName] URI: $encodedUri." 
    Write-Verbose "[$functionName] Method: $method."
    #endregion
    try
    {
        $response = Invoke-RestMethod @restParams
        Write-Verbose "[$functionName] NextLink: $($response.'@odata.nextLink')"
        Write-Verbose "[$functionName] Response count: $($response.value.count)"
        if ($response.'@odata.nextLink')
        {
            Write-Verbose "[$functionName] NextLink found. Fetching additional pages."
            # Initialize an array to hold all items
            $allItems = @()
            $allItems += $response.value
            $nextLink = $response.'@odata.nextLink'
            while ($nextLink)
            {
                $nextGroup = Invoke-RestMethod -Method $method -Uri $nextLink -Headers $headers -UseBasicParsing
                Write-Verbose "[$functionName] Fetched next page with $($nextGroup.value.Count) items."
                if ($nextGroup.value)
                {
                    Write-Verbose "[$functionName] Adding items from next page to the collection."
                    $allItems += $nextGroup.value
                }
                $nextLink = $nextGroup.'@odata.nextLink'
            }
            # Optionally, reconstruct a response object if needed
            $response.value = $allItems
            Write-Verbose "[$functionName] All items collected. Total count: $($Response.value.Count)"
        }
        else 
        {
            Write-Verbose "[$functionName] No nextLink found. Single page response received."
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
        return $statusCode
        # return $null
    }
    Write-Verbose "[$functionName] Response: $($response)"
    Write-Verbose "[$functionName] Response value: $($response.value)"
    return $response
}
