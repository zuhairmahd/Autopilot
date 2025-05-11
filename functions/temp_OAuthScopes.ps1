function Format-ScopeValueString
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Scopes
    )
    
    Write-Verbose "Formatting scope string: '$Scopes'"
    
    # Handle null or empty scope strings
    if ([string]::IsNullOrWhiteSpace($Scopes)) {
        Write-Verbose "Empty or null scope string provided, returning default scopes"
        return "offline_access openid"
    }
    
    # Standard scopes that don't need prefixes
    $standardScopes = @("offline_access", "openid", "profile")
    $scopesArray = $Scopes.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    $formattedScopesArray = @()
    
    # Process each scope individually
    foreach ($scope in $scopesArray) {
        if ([string]::IsNullOrWhiteSpace($scope)) {
            continue
        }
        
        if ($standardScopes -contains $scope) {
            # Standard scopes don't need prefixes
            $formattedScopesArray += $scope
            Write-Verbose "  - Added standard scope: $scope"
        }
        elseif ($scope.StartsWith("https://graph.microsoft.com/")) {
            # Already has Graph API prefix
            $formattedScopesArray += $scope
            Write-Verbose "  - Added scope with existing prefix: $scope"
        }
        else {
            # Add Graph API prefix to other scopes
            $formattedScope = "https://graph.microsoft.com/$scope"
            $formattedScopesArray += $formattedScope
            Write-Verbose "  - Added scope with Graph prefix: $formattedScope"
        }
    }
    
    # Ensure we have essential standard scopes
    foreach ($stdScope in @("offline_access", "openid")) {
        if ($formattedScopesArray -notcontains $stdScope) {
            $formattedScopesArray += $stdScope
            Write-Verbose "  - Added missing essential standard scope: $stdScope"
        }
    }
    
    # Create a clean, deduplicated scope string
    $result = ($formattedScopesArray | Select-Object -Unique) -join ' '
    Write-Verbose "Formatted scope result: '$result'"
    return $result
}
