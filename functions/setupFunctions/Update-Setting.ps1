function Update-Setting()
{
<#
.SYNOPSIS
    Updates settings in the settings.json file with unified logic for all setting types.

.DESCRIPTION
    This function consolidates the functionality of Update-GlobalSetting, Update-DomainSettings,
    and Update-AuthSetting into a single unified function. It loads the existing settings.json file,
    updates the specified setting(s), and saves the file back. This allows for granular
    updates without overwriting the entire configuration structure.

.PARAMETER SettingType
    The type of setting to update. Valid values: 'Global', 'Domain', 'Auth'.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER SettingName
    The name of the setting to update. Required for Global and Auth types.

.PARAMETER SettingValue
    The new value for the setting. Required for Global and Auth types.

.PARAMETER Settings
    A hashtable containing multiple settings to update. Used for Domain type or bulk updates.

.PARAMETER DomainName
    The name of the domain to update settings for. Required when SettingType is 'Domain'.

.PARAMETER MergeSettings
    If specified, merges the provided settings with existing settings.
    If not specified, replaces the entire settings section.
    Only applicable for Domain type.

.OUTPUTS
    System.Boolean
    Returns $true if the setting was updated successfully, $false otherwise.

.EXAMPLE
    # Update a global setting
    $success = Update-Setting -SettingType "Global" -SettingName "GroupTag" -SettingValue "NEWGROUP"

.EXAMPLE
    # Update an auth setting
    $success = Update-Setting -SettingType "Auth" -SettingName "Delegated" -SettingValue $true

.EXAMPLE
    # Update domain settings with merge
    $domainSettings = @{ "GroupTag" = "NEWGROUP"; "deviceNamePrefix" = "win11-" }
    $success = Update-Setting -SettingType "Domain" -DomainName "contoso.com" -Settings $domainSettings -MergeSettings

.EXAMPLE
    # Replace entire domain settings
    $success = Update-Setting -SettingType "Domain" -DomainName "contoso.com" -Settings $domainSettings

.NOTES
    - Consolidates Update-GlobalSetting, Update-DomainSettings, and Update-AuthSetting
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other settings in the file
    - Creates backup before modification for safety
    - Validates JSON structure before and after update
    - Includes enhanced array comparison logic for auth settings
    - Supports merge capability for domain settings
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Domain', 'Auth')]
        [string]$SettingType,
        
        [string]$SettingsFile = "settings.json",
        
        [string]$SettingName,
        
        $SettingValue,
        
        [hashtable]$Settings,
        
        [string]$DomainName,
        
        [switch]$MergeSettings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating $SettingType setting(s) in file: $SettingsFile"
    
    # Validate parameters based on setting type
    switch ($SettingType) {
        'Global' {
            if (-not $SettingName -or $null -eq $SettingValue) {
                Write-Warning "[$functionName] SettingName and SettingValue are required for Global setting type"
                return $false
            }
            Write-Verbose "[$functionName] Updating global setting '$SettingName' to '$SettingValue'"
        }
        'Auth' {
            if (-not $SettingName -or $null -eq $SettingValue) {
                Write-Warning "[$functionName] SettingName and SettingValue are required for Auth setting type"
                return $false
            }
            Write-Verbose "[$functionName] Updating auth setting '$SettingName' to '$SettingValue'"
        }
        'Domain' {
            if (-not $DomainName -or -not $Settings) {
                Write-Warning "[$functionName] DomainName and Settings are required for Domain setting type"
                return $false
            }
            Write-Verbose "[$functionName] Updating settings for domain '$DomainName', merge mode: $MergeSettings"
        }
    }
    
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
        
        # Validate structure based on setting type
        $requiredSection = switch ($SettingType) {
            'Global' { 'globalSettings' }
            'Auth' { 'auth' }
            'Domain' { 'domains' }
        }
        
        if (-not $settingsObj.PSObject.Properties.Name -contains $requiredSection)
        {
            Write-Warning "[$functionName] Settings file does not contain $requiredSection section"
            return $false
        }
        
        # Process the update based on setting type
        switch ($SettingType) {
            'Global' {
                # Convert PSCustomObject to hashtable for easier manipulation (PowerShell 5.1 compatible)
                $globalSettingsHash = @{}
                foreach ($property in $settingsObj.globalSettings.PSObject.Properties)
                {
                    $globalSettingsHash[$property.Name] = $property.Value
                }
                
                # Update the specific setting
                $globalSettingsHash[$SettingName] = $SettingValue
                Write-Verbose "[$functionName] Updated globalSettings.$SettingName = $SettingValue"
                
                # Convert back to PSCustomObject structure
                $settingsObj.globalSettings = [PSCustomObject]$globalSettingsHash
            }
            
            'Auth' {
                # Convert PSCustomObject to hashtable for easier manipulation (PowerShell 5.1 compatible)
                $authSettingsHash = @{}
                foreach ($property in $settingsObj.auth.PSObject.Properties)
                {
                    $authSettingsHash[$property.Name] = $property.Value
                }
                
                # Update the specific setting
                $authSettingsHash[$SettingName] = $SettingValue
                Write-Verbose "[$functionName] Updated auth.$SettingName = $SettingValue"
                
                # Convert back to PSCustomObject structure
                $settingsObj.auth = [PSCustomObject]$authSettingsHash
            }
            
            'Domain' {
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
            }
        }
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settingsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update based on setting type
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        $verificationResult = switch ($SettingType) {
            'Global' {
                if ($verifySettings.globalSettings.PSObject.Properties.Name -contains $SettingName -and
                    $verifySettings.globalSettings.$SettingName -eq $SettingValue)
                {
                    Write-Verbose "[$functionName] Successfully updated and verified global setting"
                    $true
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify global setting update"
                    $false
                }
            }
            'Auth' {
                if ($verifySettings.auth.PSObject.Properties.Name -contains $SettingName)
                {
                    $actualValue = $verifySettings.auth.$SettingName
                    
                    # Handle array comparison specially (preserved from Update-AuthSetting)
                    if ($SettingValue -is [array] -and $actualValue -is [array])
                    {
                        $comparisonResult = Compare-Object $SettingValue $actualValue
                        if ($null -eq $comparisonResult)
                        {
                            Write-Verbose "[$functionName] Successfully updated and verified auth setting (array)"
                            $true
                        }
                        else
                        {
                            Write-Warning "[$functionName] Array values do not match after update"
                            Write-Verbose "[$functionName] Expected: $($SettingValue -join ', ') | Actual: $($actualValue -join ', ')"
                            $false
                        }
                    }
                    # Handle scalar comparison
                    elseif ($actualValue -eq $SettingValue)
                    {
                        Write-Verbose "[$functionName] Successfully updated and verified auth setting (scalar)"
                        $true
                    }
                    else
                    {
                        Write-Warning "[$functionName] Setting value does not match after update"
                        Write-Verbose "[$functionName] Expected: '$SettingValue' | Actual: '$actualValue'"
                        $false
                    }
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify auth setting update - property not found"
                    $false
                }
            }
            'Domain' {
                if ($verifySettings.domains.PSObject.Properties.Name -contains $DomainName)
                {
                    Write-Verbose "[$functionName] Successfully updated and verified domain settings"
                    $true
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify domain settings update"
                    $false
                }
            }
        }
        
        return $verificationResult
    }
    catch
    {
        Write-Warning "[$functionName] Error updating $SettingType setting: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}