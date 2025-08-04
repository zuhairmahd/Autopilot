function ConvertFrom-SecureString-ToPlainText()
{
    <#
    .SYNOPSIS
    Converts a SecureString to plain text.
    
    .DESCRIPTION
    This function converts a SecureString to plain text for use in encryption operations.
    The plain text should be cleared from memory as soon as possible after use.
    
    .PARAMETER SecureString
    The SecureString to convert.
    
    .OUTPUTS
    Returns the plain text string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [SecureString]$SecureString
    )
    
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
}

