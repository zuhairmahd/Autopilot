function Show-AboutApplication()
{
    [CmdletBinding()]
    param(
        $updateAvailable = $updateAvailable,
        [string]$accessToken,
        [string]$Release,
        [string]$appId,
        [string]$tenantId,
        [string]$name
    )
    
    $FunctionName = $MyInvocation.MyCommand.Name
    $uri = "applications(appId='$appId')"
    $extraParameters = "select=displayName"
    Write-Verbose "[$FunctionName] Retrieving registered application name from Microsoft Graph"
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Retrieving registered application name from Microsoft Graph" -LogLevel "Information"                    
    $registeredAppName = (CallGraphApi -ResourcePath $uri -accessToken $accessToken -extraParameters $extraParameters).displayName
    Write-Verbose "[$FunctionName] Retrieved registered application name: $registeredAppName"
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Retrieved registered application name: $registeredAppName" -LogLevel "Information"                                                  
    if (-not $registeredAppName)
    {
        Write-Verbose "[$FunctionName] Failed to retrieve registered application name."
        $registeredAppName = "Unknown (failed to retrieve from Microsoft Graph)"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Failed to retrieve registered application name." -LogLevel "Warning"                        
    }
    Write-Host "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))"
    Write-Host "Copyright (c) $((Get-Date).Year) $($appMetaData.companyName)" -ForegroundColor Cyan
    Write-Verbose "[$functionName] Update available: $($updateAvailable | Out-String)"              
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Update available: $($updateAvailable | Out-String)" -LogLevel "Information" 
    if ($updateAvailable.success -eq $true)
    {
        Write-Host "Last updated on $($updateAvailable.ReleaseDate | FormatDateWithTimeZone)"
        Write-Host "File checksum: $($updateAvailable.Hash)"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Last updated on $($updateAvailable.ReleaseDate | FormatDateWithTimeZone)" -LogLevel "Information"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- File checksum: $($updateAvailable.Hash)" -LogLevel "Information"                        
        if ($updateAvailable.version -gt $version.version)
        {
            Write-Host "An update is available to version $($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) (revision $($updateAvailable.version.revision))" -ForegroundColor Yellow
            Write-Host "Release date: $($updateAvailable.ReleaseDate)" -ForegroundColor Yellow
            Write-Host "Go to 'Check For Script Updates' to download the latest version." -ForegroundColor Yellow
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- An update is available to version $($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) (revision $($updateAvailable.version.revision))" -LogLevel "Information"                   
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Release date: $($updateAvailable.ReleaseDate)" -LogLevel "Information"                   
        }
        else 
        {
            if ($version.hash -eq $updateAvailable.hash)
            {
                Write-Host "Checksums match: You are running a genuine copy of the script." -ForegroundColor Green
                write-log -logFile $LogFile -Module "$FunctionName" -Message "- Checksums match: Genuine copy of the script." -LogLevel "Information"                   
            }
            else
            {
                Write-Host "Checksums do not match: The script may have been tampered with. We recommend you stop using the script immediately." -ForegroundColor Yellow
                write-log -logFile $LogFile -Module "$FunctionName" -Message "- Checksums do not match: The script may have been tampered with." -LogLevel "Warning"    
            }
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
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Authentication type: $($auth.AuthType)" -LogLevel "Information"             
        # Decode the access token to get actual granted scopes
        try
        {
            $decodedToken = DecodeJwtToken -Token $accessToken -raw
            $grantedScopes = @()
            $OIDScopes = @('openid', 'profile', 'email')                          
            if ($decodedToken.scp)
            {
                # Delegated auth - scp is space-separated string
                $grantedScopes = $decodedToken.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
                Write-Verbose "[$FunctionName] Token has delegated scopes (scp): $($grantedScopes -join ', ')"
                write-Log -LogFile $LogFile -Module "$FunctionName" -Message "- Token has delegated scopes (scp): $($grantedScopes -join ', ')" -LogLevel "Information"
            }
            elseif ($decodedToken.roles)
            {
                # Application auth - roles is array
                $grantedScopes = $decodedToken.roles
                Write-Verbose "[$FunctionName] Token has application scopes (roles): $($grantedScopes -join ', ')"
                write-Log -LogFile $LogFile -Module "$FunctionName" -Message "- Token has application scopes (roles): $($grantedScopes -join ', ')" -LogLevel "Information"                   
            }
            
            if ($grantedScopes.Count -gt 0)
            {
                Write-Host "Acquired token scopes ($($grantedScopes.Count)):"
                write-Log -LogFile $LogFile -Module "$FunctionName" -Message "- Acquired token scopes ($($grantedScopes.Count)):" -LogLevel "Information"                       
                foreach ($scope in ($grantedScopes | Sort-Object))
                {
                    #display it if it is not a OID scope
                    if ($OIDScopes -notcontains $scope)
                    {
                        write-Log -LogFile $LogFile -Module "$FunctionName" -Message "`t$scope" -LogLevel "Information"                       
                        Write-Host "`t$scope"
                    }                   
                }
            }
            else
            {
                Write-Host "No scopes found in token." -ForegroundColor Yellow
                write-Log -LogFile $LogFile -Module "$FunctionName" -Message "- No scopes found in token." -LogLevel "Warning"                      
            }
        }
        catch
        {
            Write-Verbose "[$FunctionName] Failed to decode access token: $($_.Exception.Message)"
            write-Log -LogFile $LogFile -Module "$FunctionName" -Message "- Failed to decode access token: $($_.Exception.Message)" -LogLevel "Warning"                                             
            Write-Host "Unable to decode token scopes: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host "Auto Update enabled: $($settings.autoUpdate)" -ForegroundColor Cyan
    Write-Host "Update branch: $Release" -ForegroundColor Cyan
}