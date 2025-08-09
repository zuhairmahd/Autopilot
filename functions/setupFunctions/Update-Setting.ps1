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
    
    Error Handling:
    - Returns $false if settings file is not found
    - Returns $false if required parameters are missing for the specified SettingType
    - Returns $false if the settings file lacks the required JSON structure section
    - Returns $false if JSON parsing fails during load or save operations
    - Returns $false if backup creation fails
    - Returns $false if post-update verification fails (value mismatch)
    - Provides detailed verbose logging for troubleshooting all failure scenarios
    - Creates timestamped backups before any modification attempts
    - Gracefully handles PSCustomObject to hashtable conversion errors
    - Validates array comparisons for auth settings with detailed mismatch reporting
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
    
    # Private helper function to convert PSCustomObject to hashtable (PowerShell 5.1 compatible)
    function ConvertTo-HashtableFromPSObject {
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$PSObject,
            
            [string]$Context = "object"
        )
        
        try {
            $hashtable = @{}
            foreach ($property in $PSObject.PSObject.Properties) {
                $hashtable[$property.Name] = $property.Value
            }
            Write-Verbose "[$functionName] Successfully converted $Context to hashtable with $($hashtable.Count) properties"
            return $hashtable
        }
        catch {
            Write-Warning "[$functionName] Failed to convert $Context to hashtable: $($_.Exception.Message)"
            throw
        }
    }
    
    <#
    .SYNOPSIS
        Converts a hashtable structure to a nested PSCustomObject.

    .DESCRIPTION
        This helper function takes a hashtable representing domain settings and converts it into
        a nested PSCustomObject structure. It validates that each domain entry contains the required
        properties ('groupsToInclude', 'groupsToExclude', and 'settings') and constructs a corresponding
        PSCustomObject for each domain.

    .PARAMETER DomainsHash
        The hashtable containing domain settings to convert.
    #>
    function ConvertTo-PSObjectFromHashtable {
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]$DomainsHash
        )
        
        try {
            $newDomainsObj = [PSCustomObject]@{}
            foreach ($domainKey in $DomainsHash.Keys) {
                $domainValue = $DomainsHash[$domainKey]
                
                # Validate domain structure
                if (-not $domainValue.ContainsKey('groupsToInclude') -or 
                    -not $domainValue.ContainsKey('groupsToExclude') -or 
                    -not $domainValue.ContainsKey('settings')) {
                    Write-Warning "[$functionName] Domain '$domainKey' missing required properties"
                    throw "Invalid domain structure for '$domainKey'"
                }
                
                $domainObj = [PSCustomObject]@{
                    "groupsToInclude" = $domainValue['groupsToInclude']
                    "groupsToExclude" = $domainValue['groupsToExclude']
                    "settings"        = [PSCustomObject]$domainValue['settings']
                }
                $newDomainsObj | Add-Member -MemberType NoteProperty -Name $domainKey -Value $domainObj
            }
            Write-Verbose "[$functionName] Successfully converted domains hashtable to PSCustomObject with $($DomainsHash.Count) domains"
            return $newDomainsObj
        }
        catch {
            Write-Warning "[$functionName] Failed to convert domains hashtable to PSCustomObject: $($_.Exception.Message)"
            throw
        }
    }
    
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

    # Private helper function to validate SettingName and SettingValue for Global/Auth
    function Test-SettingNameAndValue {
        param(
            [string]$SettingName,
            $SettingValue,
            [string]$functionName,
            [string]$settingType
        )
        if (-not $SettingName -or $null -eq $SettingValue) {
            Write-Warning "[$functionName] SettingName and SettingValue are required for $settingType setting type"
            return $false
        }
        return $true
    }
    
    # Validate parameters based on setting type
    switch ($SettingType) {
        'Global' {
            if (-not (Test-SettingNameAndValue -SettingName $SettingName -SettingValue $SettingValue -functionName $functionName -settingType 'Global')) {
                return $false
            }
            Write-Verbose "[$functionName] Updating global setting '$SettingName' to '$SettingValue'"
        }
        'Auth' {
            if (-not (Test-SettingNameAndValue -SettingName $SettingName -SettingValue $SettingValue -functionName $functionName -settingType 'Auth')) {
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
                # Convert PSCustomObject to hashtable using helper function
                $globalSettingsHash = ConvertTo-HashtableFromPSObject -PSObject $settingsObj.globalSettings -Context "globalSettings"
                
                # Update the specific setting
                $globalSettingsHash[$SettingName] = $SettingValue
                Write-Verbose "[$functionName] Updated globalSettings.$SettingName = $SettingValue"
                
                # Convert back to PSCustomObject structure
                $settingsObj.globalSettings = [PSCustomObject]$globalSettingsHash
            }
            
            'Auth' {
                # Convert PSCustomObject to hashtable using helper function
                $authSettingsHash = ConvertTo-HashtableFromPSObject -PSObject $settingsObj.auth -Context "auth"
                
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
                            # Convert settings object to hashtable using helper function
                            $settingsHash = ConvertTo-HashtableFromPSObject -PSObject $property.Value -Context "domain '$($domainProperty.Name)' settings"
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
                
                # Convert back to nested PSCustomObjects using helper function
                $settingsObj.domains = ConvertTo-PSObjectFromHashtable -DomainsHash $domainsHash
            }
        }
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settingsObj | ConvertTo-Json -Depth $jsonDepth | Set-Content -Path $SettingsFile -Force
        
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