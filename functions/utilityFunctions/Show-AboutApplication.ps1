function Show-AboutApplication()
{
    <#
    .SYNOPSIS
    Displays the About Application menu with version, update, and support information.

    .DESCRIPTION
    This function creates and displays an interactive About Application menu that provides
    access to version information, Azure app registration details, logs, documentation,
    license information, and support options. The menu continues to display until the user
    navigates back or to the main menu.

    .PARAMETER updateAvailable
    Object containing update availability information with a success property.

    .PARAMETER accessToken
    The Microsoft Graph API access token (currently not actively used in function body).

    .PARAMETER Release
    The current release branch name (e.g., "main", "develop").

    .PARAMETER name
    The application name (currently not actively used in function body).

    .OUTPUTS
    System.String
    Returns navigation command ("Back", "Main Menu", or exit code).

    .EXAMPLE
    Show-AboutApplication -updateAvailable $updateInfo -Release "main"

    .NOTES
    Displays version information, update settings, and auto-update status.
    Provides menu options for viewing Azure app info, logs, documentation, license, and support.
    Processes menu selections in a loop until user exits.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        $updateAvailable = $updateAvailable,
        [string]$accessToken,
        [string]$Release,
        [string]$name
    )
    
    $FunctionName = $MyInvocation.MyCommand.Name
    
    # Display version information
    Show-VersionInfo
    
    # Display update information if available
    if ($updateAvailable.success)
    {
        Show-AppUpdateInfo -updateAvailable $updateAvailable
    }
    # Display update settings
    Write-Host "Auto Update enabled: $($settings.autoUpdate)" -ForegroundColor Cyan
    Write-Host "Update branch: $Release" -ForegroundColor Cyan

    #Create About Application menu
    $aboutMenu = NewMenu -MenuName "aboutMenu"
    
    #Add menu items
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View Azure App Registration and Scopes" -Action {
        Write-Host "`n================ Azure App Registration Information ================`n"   
        return 'ShowAzureAppInfo'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View logs" -Action {
        Write-Host "`n================ Log File ================`n"   
        return 'ViewLogs'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View Documentation" -Action {
        Write-Host "`n================ Documentation ================`n"            
        return 'ViewDocumentation'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "View License" -Action {
        Write-Host "`n================ License ================`n"            
        return 'ViewLicense'
    } -returnsValue
    $aboutMenu = AddMenuItem -Menu $aboutMenu -Name "Request support" -Action {
        Write-Host "`n================ Support Information ================`n"   
        return 'RequestSupport'
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
                Show-AzureAppInfoAndTokenScopes -accessToken $accessToken -Name $name
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
            'ViewDocumentation'
            {
                if ([string]::IsNullOrEmpty($settings.documentationURL))
                {
                    Write-Host "No documentation URL configured." -ForegroundColor Yellow
                    write-log -logFile $LogFile -Module "$FunctionName" -Message "- No documentation URL configured." -LogLevel "Warning"
                    return
                }                                                   
                Write-Host "`n================ Documentation ================`n"            
                $browserLaunched = LaunchBrowser -url $settings.documentationURL -browser $settings.preferredBrowser
                if ($browserLaunched)
                {
                    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Launched documentation URL $($settings.documentationURL) in browser: $($settings.preferredBrowser)" -LogLevel "Information"                               
                    Write-Host "Opened documentation URL $($settings.documentationURL) in browser: $($settings.preferredBrowser)" -ForegroundColor Green
                }
                else
                {
                    Write-Host "Failed to open documentation URL: $($settings.documentationURL)" -ForegroundColor Red
                    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Failed to open documentation URL: $($settings.documentationURL)" -LogLevel "Warning"
                }                       
            }                                       
            'ViewLicense'
            {
                if ([string]::IsNullOrEmpty($settings.licenseURL))
                {
                    Write-Host "No license URL configured." -ForegroundColor Yellow
                    write-log -logFile $LogFile -Module "$FunctionName" -Message "- No license URL configured." -LogLevel "Warning"
                    return
                }                                                           
                Write-Host "`n================ License ================`n"            
                $browserLaunched = LaunchBrowser -url $settings.licenseURL -browser $settings.preferredBrowser
                if ($browserLaunched)
                {
                    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Launched license URL $($settings.licenseURL) in browser: $($settings.preferredBrowser)" -LogLevel "Information"                               
                    Write-Host "Opened license URL $($settings.licenseURL) in browser: $($settings.preferredBrowser)" -ForegroundColor Green
                }
                else
                {
                    Write-Host "Failed to open license URL: $($settings.licenseURL)" -ForegroundColor Red
                    write-log -logFile $LogFile -Module "$FunctionName" -Message "- Failed to open license URL: $($settings.licenseURL      )" -LogLevel "Warning"
                }                       
            }                                   
            'RequestSupport'
            {
                Send-DiagnosticInformation
            }
        }                   
        Write-Host "Press any key to continue..."        
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")             
    }
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

function Show-AppUpdateInfo()
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

function Show-AzureAppInfoAndTokenScopes()
{
    [CmdletBinding()]
    param(
        [string]$accessToken,
        [string]$name
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
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Displaying application information" -LogLevel "Information"
        if ($decodedToken.app_displayname -ne $name)
        {
            Write-Host "Application name from config: $name"
            Write-Host "Registered application name: $($decodedToken.app_displayname)"
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Application name from config: $name, Registered application name: $decodedToken.app_displayname" -LogLevel "Information"       
        }
        else
        {
            Write-Host "Application name: $name"
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Application name: $name" -LogLevel "Information"
        }
        Write-Host "Application id: $($decodedToken.appid)"
        Write-Host "Tenant id: $($decodedToken.tid)"
        Write-Host "Tenant Region Scope: $($decodedToken.tenant_region_scope)"
        Write-Host "Tenant Region Subscope: $($decodedToken.tenant_region_sub_scope)"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Application id: $($decodedToken.appid), Tenant id: $($decodedToken.tid), Tenant Region Scope: $($decodedToken.tenant_region_scope), Tenant Region Subscope: $($decodedToken.tenant_region_sub_scope)" -LogLevel "Information"                                   
        Write-Host "Delegated authentication: $($auth.delegated)."    
        Write-Host "Authentication type: $($auth.AuthType)"
        write-log -logFile $LogFile -Module "$FunctionName" -Message "- Authentication type: $($auth.AuthType), Delegated authentication: $($auth.delegated)" -LogLevel "Information"
        Write-Host "Signed-in user: $($decodedToken.given_name) $($decodedToken.family_name) ($($decodedToken.name))"
        Write-Host "User type: $($decodedToken.idtyp)"
        Write-Host "User principal name: $($decodedToken.upn)"
        Write-Host "User Unique Name: $($decodedToken.unique_name)"
        if ($auth.delegated)
        {
            Write-Host "Signed-in user: $($decodedToken.given_name) $($decodedToken.family_name) ($($decodedToken.name))"
            Write-Host "User type: $($decodedToken.idtyp)"
            Write-Host "User principal name: $($decodedToken.upn)"
            Write-Host "User Unique Name: $($decodedToken.unique_name)"
            Write-Host "Signed-in IP Address: $($decodedToken.ipaddr)"
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Signed-in user: $($decodedToken.given_name) $($decodedToken.family_name) ($($decodedToken.name)), User type: $($decodedToken.idtyp), User principal name: $($decodedToken.upn), User Unique Name: $($decodedToken.unique_name), Signed-in IP Address: $($decodedToken.ipaddr)" -LogLevel "Information"
        }
        else
        {
            Write-Host "No user information available (application-only authentication)." -ForegroundColor Yellow
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- No user information available (application-only authentication)." -LogLevel "Information"
        }
        # Display scopes in multi-column format
        Write-Host "================ Granted Scopes ================"                                   
        if ($displayScopes.Count -gt 0)
        {
            Format-ScopesInColumns -scopes $displayScopes
            write-log -logFile $LogFile -Module "$FunctionName" -Message "- Displayed $($displayScopes.Count) granted scopes." -LogLevel "Information"  
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