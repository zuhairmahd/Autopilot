function NormalizeUserName()
{
    <#
    .SYNOPSIS
    Normalizes a user name by ensuring it includes the domain suffix.

    .DESCRIPTION
    This function takes a user name and ensures it is in the correct format with the domain
    suffix (e.g., user@domain.com). If the user name is missing the domain suffix, it is
    automatically appended using the domain from settings. The function trims whitespace
    and validates the format.

    .PARAMETER UserName
    The user name to normalize. Can be with or without domain suffix.

    .PARAMETER Settings
    The settings object containing the domain property. Defaults to script-level $settings.

    .OUTPUTS
    System.String
    Returns the normalized user name in the format username@domain.

    .EXAMPLE
    $normalizedName = NormalizeUserName -UserName "john.doe"
    # Returns "john.doe@contoso.com" if domain is "contoso.com"
    
    $normalizedName = NormalizeUserName -UserName "jane@contoso.com"
    # Returns "jane@contoso.com" unchanged

    .NOTES
    Automatically appends domain suffix if missing.
    Trims leading and trailing whitespace.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [string]$UserName,
        $Settings = $settings # Use the script-level $settings by default
    )
    $functionName = $MyInvocation.MyCommand.Name
    $domain = $settings.domain
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] UserName: $UserName"
    Write-Verbose "[$functionName] Normalizing user name: $UserName"
    $UserName = $UserName.Trim()
    Write-Verbose "[$functionName] Checking if the user name $username is missing the $domain suffix."
    if ($userName -notmatch "@$domain$")
    {
        Write-Verbose "[$functionName] the user name $username is missing the $domain suffix."
        $UserName = "$UserName@$domain"
        Write-Verbose "[$functionName] The user name is now $userName"
    }
    else
    {
        Write-Verbose "[$functionName] The user name is already in the correct format: $UserName"
    }
    Write-Verbose "[$functionName] Final user name: $UserName"
    Write-Verbose "[$functionName] Returning user name: $UserName"
    return $UserName
}
