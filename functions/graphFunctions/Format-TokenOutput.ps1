function Format-TokenOutput()
{
    <#
    .SYNOPSIS
    Formats an access token as either a secure string or plain text.

    .DESCRIPTION
    This function converts an access token to the requested output format. When the secureString
    parameter is specified, it converts the plain text token to a SecureString object for enhanced
    security. Otherwise, it returns the token as plain text.

    .PARAMETER token
    The access token string to format.

    .PARAMETER secureString
    When specified, converts the token to a SecureString. When omitted, returns plain text.

    .OUTPUTS
    System.String or System.Security.SecureString
    Returns a SecureString if secureString is specified, otherwise returns the plain text token.

    .EXAMPLE
    $secureToken = Format-TokenOutput -token $accessToken -secureString
    $plainToken = Format-TokenOutput -token $accessToken

    .NOTES
    SecureString conversion provides additional protection for sensitive token data.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
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

