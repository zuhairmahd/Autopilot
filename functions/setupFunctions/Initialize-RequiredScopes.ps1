function Initialize-RequiredScopes()
{
    <#
    .SYNOPSIS
        Processes and merges required scopes from configuration.
    #>
    [CmdletBinding()]
    param(
        $InitFileContent,
        [string]$Domain
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Get basic scopes from configuration
    $basicScopes = $InitFileContent.requiredScopes
    if ($null -eq $basicScopes) 
    { 
        Write-Verbose "[$functionName] No basic scopes found, initializing as empty array"
        $basicScopes = @() 
    }
    
    # Get auth scopes if present
    $authScopes = @()
    if ($InitFileContent.auth -and $InitFileContent.auth.scope)
    {
        $authScopes = @($InitFileContent.auth.scope)
        Write-Verbose "[$functionName] Found $($authScopes.Count) auth scopes"
    }
    
    # Get additional scopes for the domain from separate file
    $additionalScopes = $null
    
    # Load from separate domain file
    Write-Verbose "[$functionName] Loading additional scopes from separate domain file for: $Domain"
    $domainConfig = Get-DomainConfigurationFromFiles -DomainName $Domain -ConfigurationPath $pwd
    if ($domainConfig -and $domainConfig.additionalScopes)
    {
        $additionalScopes = $domainConfig.additionalScopes
    }
    
    if ($null -eq $additionalScopes) 
    { 
        Write-Verbose "[$functionName] No additional scopes found for $Domain, initializing as empty array"
        $additionalScopes = @() 
    }
    
    # Ensure arrays and merge
    $basicScopes = @($basicScopes)
    $authScopes = @($authScopes)
    $additionalScopes = @($additionalScopes)
    
    Write-Verbose "[$functionName] Basic scopes: $($basicScopes.Count), Auth scopes: $($authScopes.Count), Additional scopes: $($additionalScopes.Count)"
    
    # Merge and deduplicate - scopes can be strings or hashtables with Scope, Endpoints, and Reason properties
    $allScopes = @($basicScopes) + @($authScopes) + @($additionalScopes)
    
    # Normalize scopes to hashtable format with consistent casing
    $normalizedScopes = @()
    foreach ($scope in $allScopes)
    {
        if ($null -eq $scope)
        {
            continue 
        }
        
        if ($scope -is [string])
        {
            # Convert simple string scope to hashtable format
            $normalizedScopes += @{
                Scope     = $scope
                Endpoints = @()
                Reason    = ''
            }
        }
        elseif ($scope -is [hashtable])
        {
            # Normalize hashtable keys to consistent casing (capital first letter)
            $normalizedScope = @{
                Scope     = if ($scope.ContainsKey('Scope'))
                {
                    $scope['Scope'] 
                }
                elseif ($scope.ContainsKey('scope'))
                {
                    $scope['scope'] 
                }
                else
                {
                    '' 
                }
                Endpoints = if ($scope.ContainsKey('Endpoints'))
                {
                    $scope['Endpoints'] 
                }
                elseif ($scope.ContainsKey('endpoints'))
                {
                    $scope['endpoints'] 
                }
                else
                {
                    @() 
                }
                Reason    = if ($scope.ContainsKey('Reason'))
                {
                    $scope['Reason'] 
                }
                elseif ($scope.ContainsKey('reason'))
                {
                    $scope['reason'] 
                }
                else
                {
                    '' 
                }
            }
            
            # Only add if we have a valid scope name
            if (-not [string]::IsNullOrWhiteSpace($normalizedScope.Scope))
            {
                $normalizedScopes += $normalizedScope
            }
        }
    }
    
    # Deduplicate by Scope name
    $uniqueScopeNames = @{}
    $requiredScopes = @()
    foreach ($scope in $normalizedScopes)
    {
        if (-not $uniqueScopeNames.ContainsKey($scope.Scope))
        {
            $uniqueScopeNames[$scope.Scope] = $true
            $requiredScopes += $scope
        }
    }
    
    Write-Verbose "[$functionName] Merged scopes - Total unique: $($requiredScopes.Count)"
    
    return @{ RequiredScopes = $requiredScopes }
}