function Format-TokenOutput()
{
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

