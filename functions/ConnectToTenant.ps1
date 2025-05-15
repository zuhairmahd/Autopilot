function ConnectToTenant()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$configFile
    )
    $functionName = $MyInvocation.MyCommand.Name
    $success = $false
    Write-Verbose "[$functionName] Reading app registration details from $configFile."
    if ($configFile)
    {
        $Config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        $config = DecryptObject -encryptedObject $Config -excludeFields @('domain', 'name')
        if ($Config.appId)
        {
            $clientID = $Config.AppId
        }
        else
        {
            Write-Error 'A client id must be provided in the config file.'
            exit 1
        }
        if ($config.domain)
        {
            $domain = $config.domain
        }
        else
        {
            Write-Host 'No domain was provided.  Defaulting  to Your Company'
            $domain = 'Your Company'
        }
        if ($Config.tenantId)
        {
            $tenantID = $Config.tenantId
        }
        else
        {
            Write-Error 'A tenant id must be provided in the config file.'
            exit 1
        }
        if ($Config.AppSecret)
        {
            $clientSecret = $Config.AppSecret
        }
        elseif ($Config.thumbprint)
        {
            $thumbprint = $Config.thumbprint
        }
        else
        {
            Write-Host 'Either a client secret or a certificate thumbprint must be provided in the config file.'
            exit 1
        }
    }
    else
    {
        Write-Host "The file $configFile does not exist."
        Write-Host 'Please provide a valid config file.'
        exit 1
    }
    if ($clientSecret -and -not $success)
    {
        Write-Verbose "[$functionName] Connecting to Microsoft Graph using client secret authentication with the following details:"
        Write-Verbose "[$functionName] Client ID: $clientID"
        Write-Verbose "[$functionName] Tenant ID: $tenantID"
        Write-Verbose "[$functionName] Client Secret: $clientSecret"
        $credentials = New-Object System.Management.Automation.PSCredential ($clientID, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))
        Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credentials -NoWelcome -ErrorAction Stop
        Write-Host "Successfully connected to $domain using a client secret"
        $success = $true
    }
    elseif ($thumbprint -and -not $success)
    {
        Write-Verbose "[$functionName] Connecting to Microsoft Graph using certificate authentication with the following details:"
        Write-Verbose "[$functionName] Client ID: $clientID"
        Write-Verbose "[$functionName] Tenant ID: $tenantID"
        Write-Verbose "[$functionName] Certificate Thumbprint: $thumbprint"
        Connect-MgGraph -TenantId $tenantID -ClientId $clientID -CertificateThumbprint $thumbprint -NoWelcome -ErrorAction Stop
        Write-Host "Successfully connected to $domain    using certificate authentication."
        $success = $true
    }
    return $success
}
