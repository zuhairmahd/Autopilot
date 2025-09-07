function Show-GroupsViewer()
{
    <#
    .SYNOPSIS
        Read-only viewer for domain-level group inclusion and exclusion settings.
    
    .DESCRIPTION
        Provides a read-only interface for users to view groupsToInclude and groupsToExclude
        arrays at the domain level. These settings control which groups are included or excluded
        from various operations within the application. Displays settings for all domains or
        a specific domain in a formatted, easy-to-read manner.
    
    .PARAMETER SettingsFile
        Path to the settings.psd1 file. Defaults to "settings.psd1".
    
    .PARAMETER DomainName
        Optional domain name to view group settings for. If not provided, will attempt
        to use the currently loaded domain from the session. If no loaded domain is
        available, displays settings for all domains.
    
    .PARAMETER Silent
        If specified, uses minimal output for programmatic usage.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully displayed, $false otherwise.
    
    .EXAMPLE
        Show-GroupsViewer
        
        Displays group settings for the currently loaded domain if available, 
        otherwise displays settings for all domains.
    
    .EXAMPLE
        Show-GroupsViewer -DomainName "contoso.com"
        
        Displays group settings for the specified domain only.
    
    .EXAMPLE
        Show-GroupsViewer -SettingsFile "settings.psd1" -Silent
        
        Displays group settings with minimal output.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Read-only display with no modification capabilities
        - Supports both single domain and all domains display (prioritizes loaded domain)
        - Uses similar formatting to other settings viewers
        - Complements the Show-GroupsEditor function
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.psd1",
        [string]$DomainName,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $logFile -Module $functionName -Message "Starting groups viewer for domain: '$DomainName'" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Starting groups viewer for domain: '$DomainName'"
    
    try
    {
        # Check if settings file exists for configuration path determination
        Write-Log -LogFile $logFile -Module $functionName -Message "Checking settings file: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Checking settings file: $SettingsFile"
        
        if (-not (Test-Path -Path $SettingsFile))
        {
Write-Log -LogFile $logFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Verbose"
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Get available domains using the new architecture
        $configPath = Split-Path $SettingsFile -Parent
        Write-Log -LogFile $logFile -Module $functionName -Message "Getting available domains from: $configPath" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Getting available domains from: $configPath"
        
        $availableDomains = Get-AvailableDomains -ConfigurationPath $configPath -SettingsFile $SettingsFile
        if ($availableDomains.Count -eq 0)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No domains available in configuration" -LogLevel "Error"
            Write-Warning "[$functionName] No domains available in configuration"
            return $false
        }
        
Write-Log -LogFile $logFile -Module $functionName -Message "Found $($availableDomains.Count) available domains: $($availableDomains -join ', ')" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Found $($availableDomains.Count) available domains: $($availableDomains -join ', ')"
        
        # Determine which domains to display (following domain settings viewer pattern)
        $domainsToDisplay = @()
        if ([string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No domain specified, Displaying all domains" -LogLevel "Verbose"
            Write-Verbose "[$functionName] No domain specified, Displaying all domains"
            # Fall back to showing all domains if no passed domain
            $domainsToDisplay = $availableDomains
Write-Log -LogFile $logFile -Module $functionName -Message "No loaded domain found, displaying group settings for all $($availableDomains.Count) domains" -LogLevel "Verbose"
            Write-Verbose "[$functionName] No loaded domain found, displaying group settings for all $($availableDomains.Count) domains"
        }
        else
        {
            if ($availableDomains -contains $DomainName)
            {
                $domainsToDisplay = @($DomainName)
                Write-Log -LogFile $logFile -Module $functionName -Message "Displaying group settings for specific domain: '$DomainName'" -LogLevel "Information"
                Write-Verbose "[$functionName] Displaying group settings for specific domain: '$DomainName'"
            }
            else
            {
Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$DomainName' not found in settings" -LogLevel "Verbose"
                Write-Warning "[$functionName] Domain '$DomainName' not found in settings"
                return $false
            }
        }
        
        if (-not $Silent)
        {
            Write-Host "`n══ Groups Settings Viewer ══" -ForegroundColor Cyan
            Write-Host "Current group inclusion and exclusion settings for domain(s)." -ForegroundColor White
            Write-Host "These settings control which groups are included or excluded from operations.`n" -ForegroundColor Gray
        }
        
        $totalDomainsDisplayed = 0
        $totalIncludeGroups = 0
        $totalExcludeGroups = 0
        
        # Display each domain's group settings
        foreach ($domain in $domainsToDisplay)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Loading configuration for domain: $domain" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Loading configuration for domain: $domain"
            
            # Load domain configuration using new architecture
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName $domain -ConfigurationPath $configPath
            if ($null -eq $domainConfig)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load configuration for domain: $domain" -LogLevel "Warning"
                Write-Warning "[$functionName] Failed to load configuration for domain: $domain"
                continue
            }
            
            # Get current group settings with safe defaults
            $includeGroups = if ($domainConfig.groupsToInclude) 
            { 
                $domainConfig.groupsToInclude 
            } 
            else 
            { 
                @() 
            }
            
            $excludeGroups = if ($domainConfig.groupsToExclude) 
            { 
                $domainConfig.groupsToExclude 
            } 
            else 
            { 
                @() 
            }
            
            $totalIncludeGroups += if ($includeGroups)
            {
                $includeGroups.Count 
            }
            else
            {
                0 
            }
            $totalExcludeGroups += if ($excludeGroups)
            {
                $excludeGroups.Count 
            }
            else
            {
                0 
            }
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Domain '$domain' has $($includeGroups.Count) include groups and $($excludeGroups.Count) exclude groups" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Domain '$domain' has $($includeGroups.Count) include groups and $($excludeGroups.Count) exclude groups"
            
            if (-not $Silent)
            {
                # Display domain header
                if ($domainsToDisplay.Count -gt 1)
                {
                    Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
                    Write-Host "Domain: " -NoNewline -ForegroundColor White
                    Write-Host "$domain" -ForegroundColor Yellow
                    Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
                }
                else
                {
                    Write-Host "Domain: " -NoNewline -ForegroundColor White
                    Write-Host "$domain" -ForegroundColor Yellow
                }
                
                # Display Groups to Include
                Write-Host "`nGroups to Include:" -ForegroundColor Green
                Write-Host "  Description: " -NoNewline -ForegroundColor Gray
                Write-Host "Groups in this list will be specifically included in operations" -ForegroundColor White
                Write-Host "  Current Value: " -NoNewline -ForegroundColor Cyan
                
                if ($includeGroups -and $includeGroups.Count -gt 0)
                {
                    # Detect format and display accordingly
                    $firstElement = $includeGroups[0]
                    if ($firstElement -is [string])
                    {
                        # Old string format
                        Write-Host "[$($includeGroups.Count) group(s)] [Legacy Format]" -ForegroundColor Yellow
                        foreach ($group in $includeGroups)
                        {
                            Write-Host "    - $group" -ForegroundColor White
                        }
                    }
                    elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and $firstElement.name)
                    {
                        # New hashtable format
                        Write-Host "[$($includeGroups.Count) group(s)] [Enhanced Format]" -ForegroundColor Green
                        foreach ($group in $includeGroups)
                        {
                            Write-Host "    - Name: $($group.name)" -ForegroundColor White
                            if ($group.id)
                            {
                                Write-Host "      ID:   $($group.id)" -ForegroundColor Gray
                            }
                            else
                            {
                                Write-Host "      ID:   (not resolved)" -ForegroundColor Yellow
                            }
                        }
                    }
                    else
                    {
                        # Fallback for unknown format
                        Write-Host "[$($includeGroups.Count) group(s)]" -ForegroundColor Green
                        foreach ($group in $includeGroups)
                        {
                            Write-Host "    - $group" -ForegroundColor White
                        }
                    }
                }
                else
                {
                    Write-Host "(empty - no groups specified)" -ForegroundColor Gray
                }
                
                # Display Groups to Exclude
                Write-Host "`nGroups to Exclude:" -ForegroundColor Red
                Write-Host "  Description: " -NoNewline -ForegroundColor Gray
                Write-Host "Groups in this list will be specifically excluded from operations" -ForegroundColor White
                Write-Host "  Current Value: " -NoNewline -ForegroundColor Cyan
                
                if ($excludeGroups -and $excludeGroups.Count -gt 0)
                {
                    # Detect format and display accordingly
                    $firstElement = $excludeGroups[0]
                    if ($firstElement -is [string])
                    {
                        # Old string format
                        Write-Host "[$($excludeGroups.Count) group(s)] [Legacy Format]" -ForegroundColor Yellow
                        foreach ($group in $excludeGroups)
                        {
                            Write-Host "    - $group" -ForegroundColor White
                        }
                    }
                    elseif (($firstElement -is [hashtable] -or $firstElement -is [PSCustomObject]) -and $firstElement.name)
                    {
                        # New hashtable format
                        Write-Host "[$($excludeGroups.Count) group(s)] [Enhanced Format]" -ForegroundColor Green
                        foreach ($group in $excludeGroups)
                        {
                            Write-Host "    - Name: $($group.name)" -ForegroundColor White
                            if ($group.id)
                            {
                                Write-Host "      ID:   $($group.id)" -ForegroundColor Gray
                            }
                            else
                            {
                                Write-Host "      ID:   (not resolved)" -ForegroundColor Yellow
                            }
                        }
                    }
                    else
                    {
                        # Fallback for unknown format
                        Write-Host "[$($excludeGroups.Count) group(s)]" -ForegroundColor Green
                        foreach ($group in $excludeGroups)
                        {
                            Write-Host "    - $group" -ForegroundColor White
                        }
                    }
                }
                else
                {
                    Write-Host "(empty - no groups specified)" -ForegroundColor Gray
                }
                
                Write-Host ""  # Empty line for spacing
            }
            $totalDomainsDisplayed++
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully displayed group settings for $totalDomainsDisplayed domains" -LogLevel "Information"
        Write-Verbose "[$functionName] Successfully displayed group settings for $totalDomainsDisplayed domains"
        
        if (-not $Silent)
        {
            Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "Summary:" -ForegroundColor White
            Write-Host "  Domains displayed: $totalDomainsDisplayed" -ForegroundColor White
            Write-Host "  Total groups to include: $totalIncludeGroups" -ForegroundColor Green
            Write-Host "  Total groups to exclude: $totalExcludeGroups" -ForegroundColor Red
            Write-Host ""
            Write-Host "Use the groups editor to modify these values." -ForegroundColor Gray
        }
        
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in groups viewer: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in groups viewer: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}