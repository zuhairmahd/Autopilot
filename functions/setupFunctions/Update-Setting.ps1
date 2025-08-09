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
    Write-Log -LogFile $logFile -Message "Updating $SettingType setting(s) in file: $SettingsFile" -Module $functionName

    function ConvertTo-HashtableFromPSObject()
    {
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$PSObject,
            [string]$Context = "object"
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Converting $Context to hashtable"
        Write-Log -LogFile $logFile -Message "Converting $Context to hashtable" -Module $functionName
        try
        {
            $hashtable = @{}
            foreach ($property in $PSObject.PSObject.Properties)
            {
                $hashtable[$property.Name] = $property.Value
                Write-Log -LogFile $logFile -Message "Converted property '$($property.Name)' to hashtable" -Module $functionName
                Write-Verbose "[$functionName] Converted property '$($property.Name)' to hashtable"
            }
            Write-Verbose "[$functionName] Successfully converted $Context to hashtable with $($hashtable.Count) properties"
            Write-Log -LogFile $logFile -Message "Successfully converted $Context to hashtable with $($hashtable.Count) properties" -Module $functionName -LogLevel "Verbose"
            return $hashtable
        }
        catch
        {
            Write-Warning "[$functionName] Failed to convert $Context to hashtable: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Failed to convert $Context to hashtable: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
            throw
        }
    }
    
    function ConvertTo-PSObjectFromHashtable()
    {
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]$DomainsHash
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Converting domains hashtable to PSCustomObject"
        Write-Log -LogFile $logFile -Message "Converting domains hashtable to PSCustomObject" -Module $functionName
        try
        {
            $newDomainsObj = [PSCustomObject]@{}
            foreach ($domainKey in $DomainsHash.Keys)
            {
                $domainValue = $DomainsHash[$domainKey]
                Write-Verbose "[$functionName] Converting domain '$domainKey' to PSCustomObject"
                Write-Log -LogFile $logFile -Message "Converting domain '$domainKey' to PSCustomObject" -Module $functionName
                # Validate domain structure
                if (-not $domainValue.ContainsKey('groupsToInclude') -or 
                    -not $domainValue.ContainsKey('groupsToExclude') -or 
                    -not $domainValue.ContainsKey('settings'))
                {
                    Write-Warning "[$functionName] Domain '$domainKey' missing required properties"
                    Write-Log -LogFile $logFile -Message "Invalid domain structure for '$domainKey'" -Module $functionName -LogLevel "Error"
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
            Write-Log -LogFile $logFile -Message "Successfully converted domains hashtable to PSCustomObject with $($DomainsHash.Count) domains" -Module $functionName
            return $newDomainsObj
        }
        catch
        {
            Write-Warning "[$functionName] Failed to convert domains hashtable to PSCustomObject: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Failed to convert domains hashtable to PSCustomObject: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"   
            throw
        }
    }
    
    function Test-SettingNameAndValue()
    {
        param(
            [string]$SettingName,
            $SettingValue,
            [string]$functionName,
            [string]$settingType
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Testing setting name and value for $settingType"
        Write-Log -LogFile $logFile -Message "Testing setting name and value for $settingType" -Module $functionName
        if (-not $SettingName -or $null -eq $SettingValue)
        {
            Write-Warning "[$functionName] SettingName and SettingValue are required for $settingType setting type"
            Write-Log -LogFile $logFile -Message "SettingName and SettingValue are required for $settingType setting type" -Module $functionName -LogLevel "Warning"
            return $false
        }
        Write-Verbose "[$functionName] Validation passed for '$SettingName' (type '$settingType')"
        Write-Log -LogFile $logFile -Message "Validation passed for '$SettingName' (type '$settingType')" -Module $functionName -LogLevel "Verbose"
        return $true
    }
    
    # Validate parameters based on setting type
    switch ($SettingType)
    {
        'Global'
        {
            if (-not (Test-SettingNameAndValue -SettingName $SettingName -SettingValue $SettingValue -functionName $functionName -settingType 'Global'))
            {
                Write-Log -LogFile $logFile -Message "Invalid parameters for Global setting type" -Module $functionName -LogLevel "Error"
                return $false
            }
            Write-Verbose "[$functionName] Updating global setting '$SettingName' to '$SettingValue'"
            Write-Log -LogFile $logFile -Message "Updating global setting '$SettingName' to '$SettingValue'" -Module $functionName
        }
        'Auth'
        {
            if (-not (Test-SettingNameAndValue -SettingName $SettingName -SettingValue $SettingValue -functionName $functionName -settingType 'Auth'))
            {
                Write-Log -LogFile $logFile -Message "Invalid parameters for Auth setting type" -Module $functionName -LogLevel "Error"
                return $false
            }
            Write-Verbose "[$functionName] Updating auth setting '$SettingName' to '$SettingValue'"
            Write-Log -LogFile $logFile -Message "Updating auth setting '$SettingName' to '$SettingValue'" -Module $functionName
        }
        'Domain'
        {
            if (-not $DomainName -or -not $Settings)
            {
                Write-Warning "[$functionName] DomainName and Settings are required for Domain setting type"
                Write-Log -LogFile $logFile -Message "DomainName and Settings are required for Domain setting type" -Module $functionName -LogLevel "Warning"
                return $false
            }
            Write-Verbose "[$functionName] Updating settings for domain '$DomainName', merge mode: $MergeSettings"
            Write-Log -LogFile $logFile -Message "Updating settings for domain '$DomainName', merge mode: $MergeSettings" -Module $functionName
        }
    }
    
    try
    {
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            Write-Log -LogFile $logFile -Message "Settings file not found: $SettingsFile" -Module $functionName -LogLevel "Warning"
            return $false
        }
        
        # Load existing settings
        Write-Verbose "[$functionName] Loading existing settings from $SettingsFile"
        Write-Log -LogFile $logFile -Message "Loading existing settings from $SettingsFile" -Module $functionName
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settingsObj = $jsonContent | ConvertFrom-Json
        
        # Validate structure based on setting type
        $requiredSection = switch ($SettingType)
        {
            'Global'
            {
                Write-Verbose "[$functionName] Validating structure for globalSettings"
                Write-Log -LogFile $logFile -Message "Validating structure for globalSettings" -Module $functionName
                'globalSettings' 
            }
            'Auth'
            {
                Write-Verbose "[$functionName] Validating structure for auth"
                Write-Log -LogFile $logFile -Message "Validating structure for auth" -Module $functionName
                'auth' 
            }
            'Domain'
            {
                Write-Verbose "[$functionName] Validating structure for domains"
                Write-Log -LogFile $logFile -Message "Validating structure for domains" -Module $functionName
                'domains' 
            }
        }
        
        if (-not $settingsObj.PSObject.Properties.Name -contains $requiredSection)
        {
            Write-Warning "[$functionName] Settings file does not contain $requiredSection section"
            Write-Log -LogFile $logFile -Message "Settings file does not contain $requiredSection section" -Module $functionName -LogLevel "Warning"    
            return $false
        }
        
        # Process the update based on setting type
        switch ($SettingType)
        {
            'Global'
            {
                # Convert PSCustomObject to hashtable using helper function
                Write-Verbose "[$functionName] Converting globalSettings to hashtable"
                Write-Log -LogFile $logFile -Message "Converting globalSettings to hashtable" -Module $functionName
                $globalSettingsHash = ConvertTo-HashtableFromPSObject -PSObject $settingsObj.globalSettings -Context "globalSettings"
                
                # Update the specific setting
                Write-Verbose "[$functionName] Updating globalSettings.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updating globalSettings.$SettingName = $SettingValue" -Module $functionName
                $globalSettingsHash[$SettingName] = $SettingValue
                Write-Verbose "[$functionName] Updated globalSettings.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updated globalSettings.$SettingName = $SettingValue" -Module $functionName

                # Convert back to PSCustomObject structure
                Write-Log -LogFile $logFile -Message "Converting hashtable back to PSCustomObject for globalSettings" -Module $functionName
                Write-Verbose "[$functionName] Converting hashtable back to PSCustomObject for globalSettings"
                $settingsObj.globalSettings = [PSCustomObject]$globalSettingsHash
            }
            
            'Auth'
            {
                # Convert PSCustomObject to hashtable using helper function
                Write-Verbose "[$functionName] Converting auth to hashtable"
                Write-Log -LogFile $logFile -Message "Converting auth to hashtable" -Module $functionName
                $authSettingsHash = ConvertTo-HashtableFromPSObject -PSObject $settingsObj.auth -Context "auth"
                
                # Update the specific setting
                Write-Verbose "[$functionName] Updating auth.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updating auth.$SettingName = $SettingValue" -Module $functionName
                $authSettingsHash[$SettingName] = $SettingValue
                Write-Verbose "[$functionName] Updated auth.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updated auth.$SettingName = $SettingValue" -Module $functionName
                # Convert back to PSCustomObject structure
                Write-Verbose "[$functionName] Converting hashtable back to PSCustomObject for auth"
                Write-Log -LogFile $logFile -Message "Converting hashtable back to PSCustomObject for auth" -Module $functionName
                $settingsObj.auth = [PSCustomObject]$authSettingsHash
            }
            
            'Domain'
            {
                # Convert domains to hashtable for easier manipulation (PowerShell 5.1 compatible)
                Write-Verbose "[$functionName] Processing domain settings for '$DomainName' (Merge=$MergeSettings)"
                Write-Log -LogFile $logFile -Message "Processing domain settings for '$DomainName' (Merge=$MergeSettings)" -Module $functionName
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
                    Write-Log -LogFile $logFile -Message "Creating new domain entry for: $DomainName" -Module $functionName
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
                    Write-Log -LogFile $logFile -Message "Merging provided settings into existing domain configuration for '$DomainName'" -Module $functionName
                    foreach ($key in $Settings.Keys)
                    {
                        $domainsHash[$DomainName]['settings'][$key] = $Settings[$key]
                        Write-Verbose "[$functionName] Updated domain setting: $key = $($Settings[$key])"
                        Write-Log -LogFile $logFile -Message "Updated domain setting: $key = $($Settings[$key])" -Module $functionName -LogLevel "Verbose"
                    }
                }
                else
                {
                    # Replace entire settings section
                    Write-Verbose "[$functionName] Replacing entire settings section for domain"
                    Write-Log -LogFile $logFile -Message "Replacing entire settings section for domain '$DomainName'" -Module $functionName
                    $domainsHash[$DomainName]['settings'] = $Settings
                }
                
                # Convert back to nested PSCustomObjects using helper function
                Write-Verbose "[$functionName] Converting domains hashtable back to PSCustomObject structure"
                Write-Log -LogFile $logFile -Message "Converting domains hashtable back to PSCustomObject structure" -Module $functionName
                $settingsObj.domains = ConvertTo-PSObjectFromHashtable -DomainsHash $domainsHash
            }
        }
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        Write-Log -LogFile $logFile -Message "Created backup: $backupFile" -Module $functionName
        
        # Save updated settings
        $settingsObj | ConvertTo-Json -Depth $jsonDepth | Set-Content -Path $SettingsFile -Force
        Write-Verbose "[$functionName] Saved updated settings to $SettingsFile"
        Write-Log -LogFile $logFile -Message "Saved updated settings to $SettingsFile" -Module $functionName
        
        # Verify the update based on setting type
        Write-Verbose "[$functionName] Verifying update for SettingType '$SettingType'"
        Write-Log -LogFile $logFile -Message "Verifying update for SettingType '$SettingType'" -Module $functionName -LogLevel "Verbose"
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        $verificationResult = switch ($SettingType)
        {
            'Global'
            {
                if ($verifySettings.globalSettings.PSObject.Properties.Name -contains $SettingName -and
                    $verifySettings.globalSettings.$SettingName -eq $SettingValue)
                {
                    Write-Verbose "[$functionName] Successfully updated and verified global setting"
                    Write-Log -LogFile $logFile -Message "Successfully updated and verified global setting '$SettingName'" -Module $functionName
                    $true
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify global setting update"
                    Write-Log -LogFile $logFile -Message "Failed to verify global setting update for '$SettingName'" -Module $functionName -LogLevel "Warning"
                    $false
                }
            }
            'Auth'
            {
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
                            Write-Log -LogFile $logFile -Message "Successfully updated and verified auth setting '$SettingName' (array)" -Module $functionName
                            $true
                        }
                        else
                        {
                            Write-Warning "[$functionName] Array values do not match after update"
                            Write-Verbose "[$functionName] Expected: $($SettingValue -join ', ') | Actual: $($actualValue -join ', ')"
                            Write-Log -LogFile $logFile -Message "Array values do not match for '$SettingName' | Expected: $($SettingValue -join ', ') | Actual: $($actualValue -join ', ')" -Module $functionName -LogLevel "Warning"
                            $false
                        }
                    }
                    # Handle scalar comparison
                    elseif ($actualValue -eq $SettingValue)
                    {
                        Write-Verbose "[$functionName] Successfully updated and verified auth setting (scalar)"
                        Write-Log -LogFile $logFile -Message "Successfully updated and verified auth setting '$SettingName' (scalar)" -Module $functionName
                        $true
                    }
                    else
                    {
                        Write-Warning "[$functionName] Setting value does not match after update"
                        Write-Verbose "[$functionName] Expected: '$SettingValue' | Actual: '$actualValue'"
                        Write-Log -LogFile $logFile -Message "Setting value mismatch for '$SettingName' | Expected: '$SettingValue' | Actual: '$actualValue'" -Module $functionName -LogLevel "Warning"
                        $false
                    }
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify auth setting update - property not found"
                    Write-Log -LogFile $logFile -Message "Failed to verify auth setting update - property '$SettingName' not found" -Module $functionName -LogLevel "Warning"
                    $false
                }
            }
            'Domain'
            {
                if ($verifySettings.domains.PSObject.Properties.Name -contains $DomainName)
                {
                    Write-Verbose "[$functionName] Successfully updated and verified domain settings"
                    Write-Log -LogFile $logFile -Message "Successfully updated and verified domain settings for '$DomainName'" -Module $functionName
                    $true
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify domain settings update"
                    Write-Log -LogFile $logFile -Message "Failed to verify domain settings update for '$DomainName'" -Module $functionName -LogLevel "Warning"
                    $false
                }
            }
        }
        Write-Log -LogFile $logFile -Message "Verification result: $verificationResult" -Module $functionName -LogLevel "Information"
        return $verificationResult
    }
    catch
    {
        Write-Warning "[$functionName] Error updating $SettingType setting: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        Write-Log -LogFile $logFile -Message "Error updating $SettingType setting: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        Write-Log -LogFile $logFile -Message "Full error: $($_.Exception | Out-String)" -Module $functionName -LogLevel "Debug"
        return $false
    }
}