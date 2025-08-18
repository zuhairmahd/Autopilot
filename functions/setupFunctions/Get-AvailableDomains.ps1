function Get-AvailableDomains
{
    <#
    .SYNOPSIS
        Gets a list of available domains from separate domain configuration files.
    
    .DESCRIPTION
        Scans the configuration directory for domain configuration files and returns
        a list of available domain names. Also checks the main settings.json for
        backward compatibility with domains stored in the old format.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files are stored.
        Defaults to the current working directory.
    
    .PARAMETER SettingsFile
        Path to the main settings.json file to check for legacy domain configurations.
    
    .OUTPUTS
        System.Array
        Returns an array of domain names that have configuration files available.
    
    .EXAMPLE
        $domains = Get-AvailableDomains -ConfigurationPath "."
    
    .NOTES
        This function supports both the new separate file format and legacy format
        for backward compatibility during transition.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $pwd,
        
        [Parameter(Mandatory = $false)]
        [string]$SettingsFile = $null
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Scanning for available domains in: $ConfigurationPath"
    Write-Log -LogFile $logFile -Message "Scanning for available domains in: $ConfigurationPath" -Module $functionName -LogLevel "Information"
    
    $availableDomains = @()
    
    try
    {
        # First, check for separate domain configuration files
        $domainFiles = Get-ChildItem -Path $ConfigurationPath -Filter "*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $domainFiles)
        {
            # Skip common configuration files
            if ($file.Name -in @("settings.json", "strings.json", "menu.json", "config.json"))
            {
                continue
            }
            
            # Extract domain name from filename (remove .json extension)
            $domainName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            
            # Validate that this is a domain configuration file
            try
            {
                $content = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
                if ($content.groupsToInclude -and $content.groupsToExclude -and $content.settings)
                {
                    $availableDomains += $domainName
                    Write-Verbose "[$functionName] Found domain configuration: $domainName"
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Skipping invalid JSON file: $($file.Name)"
            }
        }
        
        # Also check the main settings.json for legacy domains (backward compatibility)
        if ($SettingsFile -and (Test-Path $SettingsFile))
        {
            try
            {
                $settingsContent = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
                if ($settingsContent.domains)
                {
                    $legacyDomains = $settingsContent.domains.PSObject.Properties.Name
                    foreach ($legacyDomain in $legacyDomains)
                    {
                        if ($legacyDomain -notin $availableDomains)
                        {
                            $availableDomains += $legacyDomain
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
        
        Write-Verbose "[$functionName] Found $($availableDomains.Count) available domains: $($availableDomains -join ', ')"
        Write-Log -LogFile $logFile -Message "Found $($availableDomains.Count) available domains: $($availableDomains -join ', ')" -Module $functionName -LogLevel "Information"
        
        return $availableDomains
    }
    catch
    {
        Write-Warning "[$functionName] Error scanning for available domains: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error scanning for available domains: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        return @()
    }
}