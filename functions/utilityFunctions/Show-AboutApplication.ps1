function Show-AboutApplication()
{
    [CmdletBinding()]
    param(
        $updateAvailable = $updateAvailable,
        [string]$accessToken,
        [string]$Release,
        [string]$appId,
        [string]$tenantId,
        [string]$name,
        [switch]$ShowAppRegistration,
        [switch]$ShowScopes
    )
    
    $FunctionName = $MyInvocation.MyCommand.Name
    # Retrieve registered application name
    $registeredAppName = Get-RegisteredAppName -appId $appId -accessToken $accessToken
    
    # Display version information
    Show-VersionInfo
    
    # Display update information if available
    if ($updateAvailable.success)
    {
        Show-UpdateInfo -updateAvailable $updateAvailable
    }
    # Display update settings
    Write-Host "Auto Update enabled: $($settings.autoUpdate)" -ForegroundColor Cyan
    Write-Host "Update branch: $Release" -ForegroundColor Cyan

    #Create About Application menu
    $aboutMenu = NewMenu -MenuName "aboutMenu"
    
    #Add menu items
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View Azure app registration information" -Action {
        Write-Host "`n================ Azure App Registration Information ================`n"   
        return 'ShowAzureAppInfo'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View Access Token Scopes" -Action {
        Write-Host "`n================ Access Token Scopes ================`n"   
        return 'ShowTokenScopes'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View logs" -Action {
        Write-Host "`n================ Log File ================`n"   
        return 'ViewLogs'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "Request support" -Action {
        Write-Host "`n================ Support Information ================`n"   
        return 'ShowSupportInfo'     
    } -returnsValue

    while ($menuSelectionResultPick -ne "Back" -and $menuSelectionResultPick -ne "Main Menu" -and $menuSelectionResultPick -ne 0 -and $menuSelectionResultPick -ne "0")
    {
        $menuSelectionResultPick = ShowMenu -Menu $aboutMenu -CalledBy 'Action' -StackOperation 'Push'
        Write-Verbose "[$functionName] ShowMenu returned: '$menuSelectionResultPick'"
        write-log -logFile $LogFile -Module $functionName -Message "ShowMenu returned: '$menuSelectionResultPick'" -logLevel "Information"  
        #Process navigation options
        if ($menuSelectionResultPick -eq "Back" -or $menuSelectionResultPick -eq "Main Menu" -or $menuSelectionResultPick -eq 0 -or $menuSelectionResultPick -eq "0")
        {
            Write-Verbose "[$functionName] ShowMenu returned navigation option: '$menuSelectionResultPick', treating as navigation"
            Write-Log -logFile $LogFile -Module $functionName -Message "Navigation option selected: '$menuSelectionResultPick', exiting function" -logLevel "Information"
            return $menuSelectionResultPick
        }
        if ($null -eq $menuSelectionResultPick)
        {
            Write-Verbose "[$functionName] ShowMenu returned null, treating as navigation"
            Write-Log -logFile $LogFile -Module $functionName -Message "ShowMenu returned null, exiting function" -logLevel "Information"
            return $returnValues.exitString
        }                       
    
        #process menu selection
        switch ($menuSelectionResultPick)
        {
            'ShowAzureAppInfo'
            {
                Write-Host "==========================================================`n"
                Write-Host "Domain: $domain"
                Show-ApplicationInfo -registeredAppName $registeredAppName -name $name -appId $appId -tenantId $tenantId
            }
            'ShowTokenScopes'
            {
                Write-Host "Delegated authentication: $($auth.delegated)."    
                Write-Host "Authentication type: $($auth.AuthType)"
                write-log -logFile $LogFile -Module "$FunctionName" -Message "- Authentication type: $($auth.AuthType), Delegated authentication: $($auth.delegated)" -LogLevel "Information"
        
                # Display token scopes
                Show-TokenScopes -accessToken $accessToken
            }
            'ViewLogs'
            {
                Write-Host "`n================ Log File ================`n"
                if ($settings.useGridForLogDisplay)
                {
                    Show-Log -logFile $logFile -UseGrid
                }               
                else
                {
                    Show-Log -logFile $logFile
                }                                   
            }
            'ShowSupportInfo'
            {
                Show-SupportInformation

            }
        }                   
        Write-Host "Press any key to continue..."        
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")             
        
    }
}

function Get-RegisteredAppName()
{
    [CmdletBinding()]
    param(
        [string]$appId,
        [string]$accessToken
    )
    
    $FunctionName = $MyInvocation.MyCommand.Name
    $uri = "applications(appId='$appId')"
    $extraParameters = "select=displayName"
    
    Write-Verbose "[$FunctionName] Retrieving registered application name from Microsoft Graph"
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Retrieving registered application name from Microsoft Graph" -LogLevel "Information"
    
    try
    {
        $appName = (CallGraphApi -ResourcePath $uri -accessToken $accessToken -extraParameters $extraParameters).displayName
        if ($appName)
        {
            Write-Verbose "[$FunctionName] Retrieved registered application name: $appName"
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Retrieved registered application name: $appName" -LogLevel "Information"
            return $appName
        }
    }
    catch
    {
        Write-Verbose "[$FunctionName] Failed to retrieve registered application name: $($_.Exception.Message)"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Failed to retrieve registered application name: $($_.Exception.Message)" -LogLevel "Warning"
    }
    return "Unknown (failed to retrieve from Microsoft Graph)"
}

function Show-VersionInfo()
{
    [CmdletBinding()]
    param()
    $functionName = $MyInvocation.MyCommand.Name
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Displaying version information" -LogLevel "Information"
    Write-Host "Intune Helpdesk Menu version $($version.major).$($version.minor).$($version.build) (build $($version.revision))"
    Write-Host "Copyright (c) $((Get-Date).Year) $($appMetaData.companyName)" -ForegroundColor Cyan
}

function Show-UpdateInfo()
{
    [CmdletBinding()]
    param(
        $updateAvailable
    )
    $functionName = $MyInvocation.MyCommand.Name
    $formattedDate = $updateAvailable.ReleaseDate | FormatDateWithTimeZone
    Write-Host "Last updated on $formattedDate"
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Last updated: $formattedDate, Checksum: $($updateAvailable.Hash)" -LogLevel "Information"
    
    if ($updateAvailable.updateAvailable)
    {
        $newVersion = "$($updateAvailable.version.major).$($updateAvailable.version.minor).$($updateAvailable.version.build) (revision $($updateAvailable.version.revision))"
        Write-Host "An update is available to version $newVersion" -ForegroundColor Yellow
        Write-Host "Release date: $($updateAvailable.ReleaseDate)" -ForegroundColor Yellow
        Write-Host "Go to 'Check For Script Updates' to download the latest version." -ForegroundColor Yellow
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Update available: $newVersion, Release: $($updateAvailable.ReleaseDate)" -LogLevel "Information"
    }
    elseif ($updateAvailable.versionsMatch)
    {
        if ($version.hash -eq $updateAvailable.hash)
        {
            Write-Host "Local file checksum: $($version.hash)"
            Write-Host "Remote file checksum: $($updateAvailable.Hash)"
            Write-Host "Checksums match: You are running a genuine copy of the script." -ForegroundColor Green
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Checksums match: Genuine copy" -LogLevel "Information"
        }
        else
        {
            Write-Host "Checksums do not match: The script may have been tampered with. We recommend you stop using the script immediately." -ForegroundColor Yellow
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Checksums do not match: Possible tampering" -LogLevel "Warning"
        }
    }
}

function Show-ApplicationInfo()
{
    [CmdletBinding()]
    param(
        [string]$registeredAppName,
        [string]$name,
        [string]$appId,
        [string]$tenantId
    )
    $FunctionName = $MyInvocation.MyCommand.Name
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Displaying application information" -LogLevel "Information"
    if ($registeredAppName -ne $name)
    {
        Write-Host "Application name from config: $name"
        Write-Host "Registered application name: $registeredAppName"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Application name from config: $name, Registered application name: $registeredAppName" -LogLevel "Information"       
    }
    else
    {
        Write-Host "Application name: $name"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Application name: $name" -LogLevel "Information"
    }
    Write-Host "Application id: $appId"
    Write-Host "Tenant id: $tenantId"
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Application id: $appId, Tenant id: $tenantId" -LogLevel "Information"       
}

function Show-TokenScopes()
{
    [CmdletBinding()]
    param(
        [string]$accessToken
    )
    $functionName = $MyInvocation.MyCommand.Name
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
        
        # Filter out OID scopes and sort
        $displayScopes = $grantedScopes | Where-Object { $OIDScopes -notcontains $_ } | Sort-Object
        
        if ($displayScopes.Count -gt 0)
        {
            Write-Host "Acquired token scopes ($($displayScopes.Count)):"
            write-Log -LogFile $LogFile -Module "$FunctionName" -Message "- Acquired token scopes ($($displayScopes.Count)): $($displayScopes -join ', ')" -LogLevel "Information"
            
            # Display scopes in multi-column format
            Format-ScopesInColumns -scopes $displayScopes
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

function Format-ScopesInColumns()
{
    [CmdletBinding()]
    param(
        [string[]]$scopes
    )
    $functionName = $MyInvocation.MyCommand.Name
    # Calculate optimal column layout
    $consoleWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
    $maxScopeLength = ($scopes | Measure-Object -Property Length -Maximum).Maximum
    $columnWidth = [Math]::Min($maxScopeLength + 4, 50)  # Cap at 50 chars per column
    $numColumns = [Math]::Max(1, [Math]::Floor(($consoleWidth - 4) / $columnWidth))
    $numRows = [Math]::Ceiling($scopes.Count / $numColumns)
    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Formatting scopes into $numColumns columns and $numRows rows" -LogLevel "Information"       
    # Build output array row-by-row
    for ($row = 0; $row -lt $numRows; $row++)
    {
        $line = "`t"
        for ($col = 0; $col -lt $numColumns; $col++)
        {
            $index = $row + ($col * $numRows)
            if ($index -lt $scopes.Count)
            {
                $scope = $scopes[$index]
                $line += $scope.PadRight($columnWidth)
            }
        }
        Write-Host $line.TrimEnd()
    }
}