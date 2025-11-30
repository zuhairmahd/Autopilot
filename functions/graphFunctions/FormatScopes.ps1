function FormatScopes()
{
    <#
    .SYNOPSIS
    Formats OAuth scopes for Microsoft Graph API authentication.

    .DESCRIPTION
    This function processes OAuth scope strings for use with Microsoft Graph API. In normal mode,
    it adds the Graph API URL prefix to scopes and includes default OpenID Connect scopes. In
    reverse mode, it removes the Graph API prefix from scopes. The function handles space-separated
    scope strings and validates input.

    .PARAMETER scopes
    Array of scope strings to format. Can be space-separated or an array.

    .PARAMETER Reverse
    When specified, removes Graph API prefixes instead of adding them.

    .OUTPUTS
    System.String[] or System.String
    Returns formatted scope array or string. Returns empty string if no scopes provided.

    .EXAMPLE
    $formattedScopes = FormatScopes -scopes "User.Read Device.Read"
    $cleanScopes = FormatScopes -scopes $graphScopes -Reverse

    .NOTES
    Default OpenID scopes: offline_access, openid, profile.
    Normal mode adds "https://graph.microsoft.com/" prefix to non-OpenID scopes.
    Reverse mode removes the Graph API URL prefix.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [string[]]$scopes,
        [switch]$Reverse
    )
    $functionName = $MyInvocation.MyCommand.Name
    $openIdScopes = @('offline_access', 'openid', 'profile')
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
        #If the $formattedScopesArray does not contain a scope in the $openIdScopes, add the missing scope.
        foreach ($defaultScope in $openIdScopes)
        {
            if ($formattedScopesArray -notcontains $defaultScope)
            {
                Write-Verbose "[$functionName] Adding default scope: $defaultScope"
                $formattedScopesArray += $defaultScope
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

