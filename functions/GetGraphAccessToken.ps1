function GetGraphAccessToken()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, ParameterSetName = 'Manual')]
        [string]$tenantId,
        [Parameter(Mandatory = $false, ParameterSetName = 'Manual')]
        [string]$clientId,
        [Parameter(Mandatory = $false, ParameterSetName = 'Manual')]
        [string]$clientSecret,
        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]$configFile
    )

    #region write a verbose log of the received parameters
    Write-Verbose "TenantId: $tenantId"
    Write-Verbose "ClientId: $clientId"
    Write-Verbose "ClientSecret: $clientSecret"
    Write-Verbose "ConfigFile: $configFile"
    #endregion
    if ($configFile)
    {
        Write-Verbose "Reading config file $configFile"
        $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        Write-Verbose "Decrypting values from $configFile"
        $config = GetDecryptedObject -encryptedObject $config -excludeFields 'domain'
        $tenantId = $config.tenantId
        $clientId = $config.appId
        $clientSecret = $config.appSecret
    }
    else 
    {
        Write-Verbose "Using parameters from the command line"
    }

    if ($tenantId -and $clientId -and $clientSecret)
    {
        $body = @{
            client_id     = $clientId
            scope         = 'https://graph.microsoft.com/.default'
            client_secret = $clientSecret
            grant_type    = 'client_credentials'
        }   
        $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType 'application/x-www-form-urlencoded' -Body $body
        $accessToken = $tokenResponse.access_token
    }
    return $accessToken
}

