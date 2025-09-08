function Show-AboutApplication()
{
    [CmdletBinding()]
    param(
        [string]$accessToken
    )
    
    $FunctionName = $MyInvocation.MyCommand.Name
    $uri = "applications(appId='$appId')"
    $extraParameters = "select=displayName"
    Write-Verbose "[$FunctionName] Retrieving registered application name from Microsoft Graph"
    $registeredAppName = (CallGraphApi -ResourcePath $uri -accessToken $accessToken -extraParameters $extraParameters).displayName
    Write-Verbose "[$FunctionName] Retrieved registered application name: $registeredAppName"
    if (-not $registeredAppName)
    {
        Write-Verbose "[$FunctionName] Failed to retrieve registered application name."
        $registeredAppName = "Unknown (failed to retrieve from Microsoft Graph)"
    }
    Write-Host "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))"
    Write-Host "Copyright (c) $((Get-Date).Year) $($version.companyName)" -ForegroundColor Cyan
    if ($updateAvailable.success -eq $true)
    {
        Write-Host "Last updated on $($updateAvailable.ReleaseDate)"
        Write-Host "File checksum: $($updateAvailable.Hash)"
        if ($version.hash -eq $updateAvailable.hash)
        {
            Write-Host "Checksums match: You are running a genuine copy of the script." -ForegroundColor Green
        }
        else
        {
            Write-Host "Checksums do not match: The script may have been tampered with. We recommend you stop using the script immediately." -ForegroundColor Yellow
        }
        if ($updateAvailable.version -gt $version.version)
        {
            Write-Host "An update is available to version $($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) (revision $($updateAvailable.version.revision))" -ForegroundColor Yellow
            Write-Host "Release date: $($updateAvailable.ReleaseDate)" -ForegroundColor Yellow
            Write-Host "Go to 'Check For Script Updates' to download the latest version." -ForegroundColor Yellow
        }
    }
    Write-Host "==========================================================`n"
    Write-Host "Domain: $domain"
    Write-Host "Application name from config: $name"
    Write-Host "Registered application name: $registeredAppName"
    Write-Host "Application id: $appId"
    Write-Host "Tenant id: $tenantId"
    Write-Host "Delegated authentication: $($auth.delegated)."
    if ($auth.delegated)
    {
        Write-Host "Authentication type: $($auth.AuthType)"
    }
    Write-Host "Auto Update enabled: $($settings.autoUpdate)" -ForegroundColor Cyan
}