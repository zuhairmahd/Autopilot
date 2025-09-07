function Get-AvailableDomains()
{
    <#
    .SYNOPSIS
        Gets a list of available domains from separate domain configuration files.
    
    .DESCRIPTION
        Scans the configuration directory for domain configuration files (.psd1) and returns
        a list of available domain names. Also checks the main settings.psd1 for
        backward compatibility with domains stored in the old format.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files are stored.
        Defaults to the current working directory.
    
    .PARAMETER SettingsFile
        Path to the main settings.psd1 file to check for legacy domain configurations.
    
    .OUTPUTS
        System.Array
        Returns an array of domain names that have configuration files available.
    
    .EXAMPLE
        $domains = Get-AvailableDomains -ConfigurationPath "."
    
    .NOTES
        This function supports both the new separate file format and legacy format
        for backward compatibility during transition.
        Phase 4A Optimization: Uses pre-allocated ArrayList for efficient collection building.
        Uses PowerShell Data File (.psd1) format for optimal performance.
    #>
    [CmdletBinding()]
    [OutputType([System.Array])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $pwd,
        
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Message "Scanning for available domains in: $ConfigurationPath" -Module $functionName -LogLevel "Information"
    
    # Phase 4A Optimization: Use pre-allocated ArrayList for efficient collection building
    $availableDomains = New-Object System.Collections.ArrayList
    
    try
    {
        # First, check for separate domain configuration files (.psd1 format)
        $domainFiles = Get-ChildItem -Path $ConfigurationPath -Filter "*.psd1" -ErrorAction SilentlyContinue
        
        # Phase 4A Optimization: Pre-allocate capacity if we have an estimate
        if ($domainFiles.Count -gt 0)
        {
            $availableDomains.Capacity = $domainFiles.Count
        }
        
        foreach ($file in $domainFiles)
        {
            # Skip common configuration files
            if ($file.Name -in @("settings.psd1", "strings.psd1", "menu.psd1", "config.psd1", "init.psd1", "lastrun.psd1"))
            {
                continue
            }
            
            # Extract domain name from filename (remove .psd1 extension)
            $domainName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            
            # Validate that this is a domain configuration file
            try
            {
                $content = Import-PowerShellDataFile -Path $file.FullName -ErrorAction Stop
                # Check that it's a hashtable and has the required properties for domain configuration
                if ($content -and 
                    ($content.ContainsKey('groupsToInclude') -or $content.Keys -contains 'groupsToInclude') -and 
                    ($content.ContainsKey('groupsToExclude') -or $content.Keys -contains 'groupsToExclude'))
                {
                    [void]$availableDomains.Add($domainName)
                    Write-Verbose "[$functionName] Found domain configuration: $domainName"
                }
                else
                {
                    Write-Verbose "[$functionName] Skipping file that doesn't match domain format: $($file.Name)"
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Skipping invalid PSD1 file: $($file.Name) - $($_.Exception.Message)"
            }
        }
        
        # Also check the main settings.psd1 for legacy domains (backward compatibility)
        if ($SettingsFile -and (Test-Path $SettingsFile))
        {
            try
            {
                $settingsContent = Import-PowerShellDataFile -Path $SettingsFile -ErrorAction Stop
                if ($settingsContent -and $settingsContent.ContainsKey('domains'))
                {
                    $legacyDomains = $settingsContent['domains'].Keys
                    foreach ($legacyDomain in $legacyDomains)
                    {
                        if ($legacyDomain -notin $availableDomains)
                        {
                            [void]$availableDomains.Add($legacyDomain)
                            Write-Verbose "[$functionName] Found legacy domain configuration: $legacyDomain"
                        }
                    }
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Failed to read legacy domains from settings file: $($_.Exception.Message)"
            }
        }
        
Write-Log -LogFile $logFile -Message "Found $($availableDomains.Count) available domains: $($availableDomains -join ', ')" -Module $functionName -LogLevel "Verbose"
        
        # Debug: Check what we're about to return
        Write-Verbose "[$functionName] Debug: About to return array of type $($availableDomains.GetType().Name) with $($availableDomains.Count) items"
        for ($i = 0; $i -lt $availableDomains.Count; $i++)
        {
            Write-Verbose "[$functionName] Debug: Domain[$i] = '$($availableDomains[$i])' (Length: $($availableDomains[$i].Length))"
        }
        
        # Phase 4A Optimization: Convert ArrayList to Array for return compatibility
        $resultArray = [System.Array]$availableDomains.ToArray()
        Write-Verbose "[$functionName] Debug: Final result array type: $($resultArray.GetType().Name), Count: $($resultArray.Count)"
        return $resultArray
    }
    catch
    {
        Write-Warning "[$functionName] Error scanning for available domains: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error scanning for available domains: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        return @()
    }
}