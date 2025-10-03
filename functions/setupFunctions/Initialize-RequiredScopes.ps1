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
    
    # Merge and deduplicate - scopes are strings, not objects
    $allScopes = @($basicScopes) + @($authScopes) + @($additionalScopes)
    $requiredScopes = $allScopes | Select-Object -Unique
    
    Write-Verbose "[$functionName] Merged scopes - Total unique: $($requiredScopes.Count)"
    
    return @{ RequiredScopes = $requiredScopes }
}