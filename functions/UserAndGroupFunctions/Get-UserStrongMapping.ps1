function Get-UserStrongMapping()
{
    <#
    .SYNOPSIS
    Checks if a user has strong authentication mapping (certificate-based) enabled.

    .DESCRIPTION
    This function queries Microsoft Graph to retrieve a user's authorization information and
    determines if strong authentication mapping is enabled by checking for certificate user IDs.
    Strong mapping uses certificate-based authentication to enhance security. The function returns
    detailed information about the user including certificate count and user details.

    .PARAMETER accessToken
    The Microsoft Graph API access token for authentication. This parameter is mandatory.

    .PARAMETER UserName
    The user principal name to check for strong mapping. This parameter is mandatory.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with properties:
    - StrongMapping: Boolean indicating if strong mapping is enabled
    - UserName: The user principal name queried
    - DisplayName: User's display name
    - UserId: User's Graph ID
    - Certificates: Array of certificate user IDs
    - CertificateCount: Number of certificates found

    .EXAMPLE
    $mapping = Get-UserStrongMapping -accessToken $token -UserName "john.doe@contoso.com"
    if ($mapping.StrongMapping) {
        Write-Host "$($mapping.DisplayName) has $($mapping.CertificateCount) certificates configured"
    }

    .NOTES
    Queries authorizationInfo.certificateUserIds from Microsoft Graph.
    Requires appropriate Microsoft Graph permissions (User.Read.All or Directory.Read.All).
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$UserName
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting function to check strong mapping for user: $UserName"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting strong mapping check for user: $UserName" -LogLevel Information

    $userURI = "users/$UserName"
    Write-Verbose "[$functionName] User URI: $userURI"
    Write-Log -LogFile $LogFile -Module $functionName -Message "User URI: $userURI" -LogLevel Verbose

    $returnObject = @{
        StrongMapping    = $false
        UserName         = $UserName
        DisplayName      = ""
        UserId           = ""
        Certificates     = @()
        CertificateCount = 0
    }

    $ExtraParameters = "select=id,displayName,userPrincipalName,authorizationInfo"
    Write-Verbose "[$functionName] Calling Graph API with ExtraParameters: $ExtraParameters"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Calling Graph API for user info with ExtraParameters: $ExtraParameters" -LogLevel Verbose
    $userInfo = CallGraphApi -accessToken $accessToken -ResourcePath $userURI -ExtraParameters $ExtraParameters

    Write-Log -LogFile $LogFile -Module $functionName -Message "Graph API response: $($userInfo | ConvertTo-Json -Depth 3)" -LogLevel Verbose
    Write-Verbose "[$functionName] Graph API response: $($userInfo | ConvertTo-Json -Depth 3)"

    if ($null -ne $userInfo)
    {
        if ($userInfo.id)
        {
            Write-Verbose "[$functionName] User ID found: $($userInfo.id)"
            Write-Verbose "[$functionName] User Display Name: $($userInfo.displayName)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "User ID: $($userInfo.id), Display Name: $($userInfo.displayName)" -LogLevel Information
            $returnObject.DisplayName = $userInfo.displayName
            $returnObject.UserId = $userInfo.id
        }
        $certs = $userInfo.authorizationInfo.certificateUserIds
        Write-Verbose "[$functionName] Certificate array: $($certs | ConvertTo-Json)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Certificate array: $($certs | ConvertTo-Json)" -LogLevel Verbose
        if ($null -ne $certs -and $certs.Count -gt 0)
        {
            $returnObject.Certificates = @($certs)
            $returnObject.CertificateCount = $returnObject.Certificates.Count
            $returnObject.StrongMapping = $true
            Write-Verbose "[$functionName] Strong mapping enabled. Found $($returnObject.CertificateCount) certificates."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Strong mapping enabled. Found $($returnObject.CertificateCount) certificates." -LogLevel Information
        }
        else
        {
            Write-Verbose "[$functionName] No certificates found for user. Strong mapping not enabled."
            Write-Log -LogFile $LogFile -Module $functionName -Message "No certificates found for user. Strong mapping not enabled." -LogLevel Information
        }
    }
    else
    {
        Write-Verbose "[$functionName] No user info returned from Graph API."
        Write-Log -LogFile $LogFile -Module $functionName -Message "No user info returned from Graph API." -LogLevel Warning
    }

    Write-Verbose "[$functionName] Returning object: $($returnObject | ConvertTo-Json -Depth 3)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Returning object: $($returnObject | ConvertTo-Json -Depth 3)" -LogLevel Verbose
    return $returnObject
}