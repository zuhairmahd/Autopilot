function Get-UserStrongMapping()
{
    [CmdletBinding()]
    param (
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