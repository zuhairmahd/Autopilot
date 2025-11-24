function Resolve-UserWithMatching()
{
    <#
    .SYNOPSIS
        [DEPRECATED] Backward compatibility wrapper for Resolve-DirectoryObject (User entity type).
    
    .DESCRIPTION
        This function is deprecated and maintained only for backward compatibility.
        It is now a thin wrapper around Resolve-DirectoryObject with EntityType="User".
        
        Please migrate to Resolve-DirectoryObject for new code:
        Resolve-DirectoryObject -EntityName $UserName -AccessToken $AccessToken -Settings $Settings -ReturnValues $ReturnValues -EntityType "User"
        
        This wrapper will be removed in a future version.
    
    .PARAMETER UserName
        The username (email address) to search for in Entra ID.
    
    .PARAMETER AccessToken
        The access token for authenticating with Microsoft Graph API.
    
    .PARAMETER Settings
        The settings object containing configuration such as maxUserMatchDisplay.
    
    .PARAMETER ReturnValues
        The return values hashtable containing navigation messages.
    
    .OUTPUTS
        Returns the validated userPrincipalName if a user is found and confirmed,
        or a return value code for navigation (back, exit, etc.).
    
    .EXAMPLE
        $resolvedUser = Resolve-UserWithMatching -UserName "john.doe@contoso.com" -AccessToken $token -Settings $settings -ReturnValues $returnValues
        if ($resolvedUser -notin $returnValues.Values) {
            # Proceed with the resolved username
        }
    
    .NOTES
        DEPRECATED: This function is maintained for backward compatibility only.
        Use Resolve-DirectoryObject with EntityType="User" instead.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,
        [Parameter(Mandatory = $true)]
        [hashtable]$ReturnValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] DEPRECATION WARNING: Resolve-UserWithMatching is deprecated. Please use Resolve-DirectoryObject with EntityType='User' instead."
    
    # Call the unified function with User entity type
    return Resolve-DirectoryObject -EntityName $UserName -AccessToken $AccessToken -Settings $Settings -ReturnValues $ReturnValues -EntityType "User"
}
