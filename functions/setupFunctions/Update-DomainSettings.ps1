function Update-DomainSettings()
<#
.SYNOPSIS
>>>>>>> master
.SYNOPSIS
.SYNOPSIS
function Update-DomainSettings()
<#
.SYNOPSIS
    Updates settings for a specific domain in the settings.json file.

.DESCRIPTION
    This function loads the existing settings.json file, updates settings for a specific
    domain, and saves the file back. This allows for granular updates to domain-specific
    configurations without affecting other domains or global settings.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER DomainName
    The name of the domain to update settings for.

.PARAMETER Settings
    A hashtable containing the settings to update for the domain.

.PARAMETER MergeSettings
    If specified, merges the provided settings with existing domain settings.
    If not specified, replaces the entire settings section for the domain.

.OUTPUTS
    System.Boolean
    Returns $true if the domain settings were updated successfully, $false otherwise.

.EXAMPLE
    # Update GroupTag for a specific domain
    $domainSettings = @{ "GroupTag" = "NEWGROUP"; "deviceNamePrefix" = "win11-" }
    $success = Update-DomainSettings -DomainName "contoso.com" -Settings $domainSettings

.EXAMPLE
    # Merge settings with existing domain configuration
    $newSettings = @{ "MaxUserNameLength" = 60 }
    $success = Update-DomainSettings -DomainName "contoso.com" -Settings $newSettings -MergeSettings

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other domains and global settings
    - Creates backup before modification for safety
    - Can either merge or replace domain settings
#>
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [string]$DomainName,
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,
        [switch]$MergeSettings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating settings for domain '$DomainName' in file: $SettingsFile"
    Write-Verbose "[$functionName] Merge mode: $MergeSettings"
    
    try
    {
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Load existing settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settingsObj = $jsonContent | ConvertFrom-Json
        
        # Validate structure
        if (-not $settingsObj.PSObject.Properties.Name -contains 'domains')
        {
            Write-Warning "[$functionName] Settings file does not contain domains section"
            return $false
        }
        
        # Convert domains to hashtable for easier manipulation (PowerShell 5.1 compatible)
        $domainsHash = @{}
        foreach ($domainProperty in $settingsObj.domains.PSObject.Properties)
        {
            $domainHash = @{}
            
            # Convert each domain's properties
            foreach ($property in $domainProperty.Value.PSObject.Properties)
            {
                if ($property.Name -eq 'settings' -and $property.Value -is [PSCustomObject])
                {
                    # Convert settings object to hashtable
                    $settingsHash = @{}
                    foreach ($settingProperty in $property.Value.PSObject.Properties)
                    {
                        $settingsHash[$settingProperty.Name] = $settingProperty.Value
                    }
                    $domainHash[$property.Name] = $settingsHash
                }
                else
                {
                    $domainHash[$property.Name] = $property.Value
                }
            }
            
            $domainsHash[$domainProperty.Name] = $domainHash
        }
        
        # Initialize domain if it doesn't exist
        if (-not $domainsHash.ContainsKey($DomainName))
        {
            Write-Verbose "[$functionName] Creating new domain entry for: $DomainName"
            $domainsHash[$DomainName] = @{
                "groupsToInclude" = @()
                "groupsToExclude" = @()
                "settings"        = @{}
            }
        }
        
        # Update domain settings
        if ($MergeSettings -and $domainsHash[$DomainName].ContainsKey('settings'))
        {
            # Merge with existing settings
            Write-Verbose "[$functionName] Merging settings with existing domain configuration"
            foreach ($key in $Settings.Keys)
            {
                $domainsHash[$DomainName]['settings'][$key] = $Settings[$key]
                Write-Verbose "[$functionName] Updated domain setting: $key = $($Settings[$key])"
            }
        }
        else
        {
            # Replace entire settings section
            Write-Verbose "[$functionName] Replacing entire settings section for domain"
            $domainsHash[$DomainName]['settings'] = $Settings
        }
        
        # Convert back to nested PSCustomObjects
        $newDomainsObj = [PSCustomObject]@{}
        foreach ($domainKey in $domainsHash.Keys)
        {
            $domainValue = $domainsHash[$domainKey]
            $domainObj = [PSCustomObject]@{
                "groupsToInclude" = $domainValue['groupsToInclude']
                "groupsToExclude" = $domainValue['groupsToExclude']
                "settings"        = [PSCustomObject]$domainValue['settings']
            }
            $newDomainsObj | Add-Member -MemberType NoteProperty -Name $domainKey -Value $domainObj
        }
        
        # Update the settings object
        $settingsObj.domains = $newDomainsObj
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settingsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.domains.PSObject.Properties.Name -contains $DomainName)
        {
            Write-Verbose "[$functionName] Successfully updated and verified domain settings"
            return $true
        }
        else
        {
            Write-Warning "[$functionName] Failed to verify domain settings update"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error updating domain settings: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

