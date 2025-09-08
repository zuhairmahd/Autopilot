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
    $additionalScopes = @($additionalScopes)
    
    Write-Verbose "[$functionName] Basic scopes: $($basicScopes.Count), Additional scopes: $($additionalScopes.Count)"
    
    # Merge and deduplicate
    $allScopes = @($basicScopes) + @($additionalScopes)
    $requiredScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
    
    Write-Verbose "[$functionName] Merged scopes - Total unique: $($requiredScopes.Count)"
    
    return @{ RequiredScopes = $requiredScopes }
}