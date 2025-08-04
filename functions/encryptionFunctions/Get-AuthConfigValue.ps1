function Get-AuthConfigValue()
{
    <#
    .SYNOPSIS
    Retrieves an authentication configuration value from the init file.
    
    .DESCRIPTION
    This function retrieves authentication configuration values from the script-level $Auth variable
    which is loaded from the init file.
    
    .PARAMETER PropertyPath
    The path to the property to retrieve (e.g., "scope", "authType").
    
    .EXAMPLE
    Get-AuthConfigValue -PropertyPath "scope"
    
    .EXAMPLE
    Get-AuthConfigValue -PropertyPath "authType"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Retrieving auth config value for path: $PropertyPath"
    
    if (-not $script:Auth)
    {
        Write-Error "No auth configuration available"
        return $null
    }
    
    # Navigate the property path
    $pathParts = $PropertyPath.Split('.')
    $current = $script:Auth
    
    foreach ($part in $pathParts)
    {
        if ($current.ContainsKey($part))
        {
            $current = $current[$part]
        }
        else
        {
            Write-Verbose "[$functionName] Property path '$PropertyPath' not found in auth configuration"
            return $null
        }
    }
    
    return $current
}

