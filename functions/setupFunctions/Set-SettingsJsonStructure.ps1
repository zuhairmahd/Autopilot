function Set-SettingsJsonStructure()
<#
.SYNOPSIS
    Creates or updates the entire settings.json structure with new configuration data.

.DESCRIPTION
    This function creates a new settings.json file with the proper structure (description,
    version, globalSettings, domains) or updates an existing one. It wraps configuration
    data in the appropriate settings.json structure format.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER ConfigData
    A hashtable containing the configuration data to be placed in globalSettings.

.PARAMETER Description
    Optional description for the settings file. Defaults to a standard description.

.PARAMETER Version
    Optional version for the settings file. Defaults to "1.0".

.PARAMETER PreserveExistingDomains
    If specified and the settings file already exists, preserves existing domain configurations.

.OUTPUTS
    System.Boolean
    Returns $true if the settings file was created/updated successfully, $false otherwise.

.EXAMPLE
    # Create new settings.json with configuration data
    $config = @{ "GroupTag" = "MSB01"; "maxWaitTime" = "60" }
    $success = Set-SettingsJsonStructure -ConfigData $config

.EXAMPLE
    # Update settings.json while preserving existing domains
    $config = @{ "testMode" = $true }
    $success = Set-SettingsJsonStructure -ConfigData $config -PreserveExistingDomains

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Creates proper settings.json structure with globalSettings and domains
    - Can preserve existing domain configurations when updating
    - Creates backup before modification for safety
#>
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,
        [string]$Description = "This is the configuration file for the script. It contains the settings for the script to run correctly.",
        [string]$Version = "1.0",
        [switch]$PreserveExistingDomains
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating/updating settings structure in file: $SettingsFile"
    Write-Verbose "[$functionName] Preserve existing domains: $PreserveExistingDomains"
    
    try
    {
        $existingDomains = @{}
        
        # If preserving domains and file exists, load existing domains
        if ($PreserveExistingDomains -and (Test-Path -Path $SettingsFile))
        {
            Write-Verbose "[$functionName] Loading existing domains to preserve"
            $existingContent = Get-Content -Path $SettingsFile -Raw -Force
            $existingSettings = $existingContent | ConvertFrom-Json
            
            if ($existingSettings.PSObject.Properties.Name -contains 'domains')
            {
                # Convert existing domains to hashtable
                foreach ($domainProperty in $existingSettings.domains.PSObject.Properties)
                {
                    $domainHash = @{}
                    foreach ($property in $domainProperty.Value.PSObject.Properties)
                    {
                        if ($property.Name -eq 'settings' -and $property.Value -is [PSCustomObject])
                        {
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
                    $existingDomains[$domainProperty.Name] = $domainHash
                }
                Write-Verbose "[$functionName] Preserved $($existingDomains.Count) existing domains"
            }
            
            # Create backup
            $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $SettingsFile -Destination $backupFile -Force
            Write-Verbose "[$functionName] Created backup: $backupFile"
        }
        
        # Create the settings structure
        $settingsStructure = @{
            "description"    = $Description
            "version"        = $Version
            "globalSettings" = $ConfigData
            "domains"        = @{}
        }
        
        # Add preserved domains if any
        if ($existingDomains.Count -gt 0)
        {
            $settingsStructure["domains"] = $existingDomains
        }
        
        # Convert to JSON and save
        $jsonOutput = $settingsStructure | ConvertTo-Json -Depth 10
        $jsonOutput | Set-Content -Path $SettingsFile -Force
        
        # Verify the file was created correctly
        if (Test-Path -Path $SettingsFile)
        {
            $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
            $verifySettings = $verifyContent | ConvertFrom-Json
            
            if ($verifySettings.PSObject.Properties.Name -contains 'globalSettings' -and
                $verifySettings.PSObject.Properties.Name -contains 'domains')
            {
                Write-Verbose "[$functionName] Successfully created/updated settings.json structure"
                return $true
            }
        }
        
        Write-Warning "[$functionName] Failed to verify settings.json structure"
        return $false
    }
    catch
    {
        Write-Warning "[$functionName] Error creating/updating settings structure: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

