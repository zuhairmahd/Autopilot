function Update-Setting()
{
    <#
.SYNOPSIS
    Updates settings in the settings.psd1 file with unified logic for all setting types.

.DESCRIPTION
    This function consolidates the functionality of Update-GlobalSetting, Update-DomainSettings,
    and Update-AuthSetting into a single unified function. It loads the existing settings.psd1 file,
    updates the specified setting(s), and saves the file back using Export-PowerShellDataFile. 
    This allows for granular updates without overwriting the entire configuration structure.

.PARAMETER SettingType
    The type of setting to update. Valid values: 'Global', 'Domain', 'Auth'.

.PARAMETER SettingsFile
    The path to the settings.psd1 file. Defaults to "settings.psd1".

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
    - Validates PSD1 structure before and after update
    - Includes enhanced array comparison logic for auth settings
    - Supports merge capability for domain settings
    - Uses Export-PowerShellDataFile for proper PSD1 format preservation
    
    Error Handling:
    - Returns $false if settings file is not found
    - Returns $false if required parameters are missing for the specified SettingType
    - Returns $false if the settings file lacks the required PSD1 structure section
    - Returns $false if PSD1 parsing fails during load or save operations
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
        [string]$SettingsFile = "settings.psd1",
        [string]$SettingName,
        $SettingValue,
        [hashtable]$Settings,
        [string]$DomainName,
        [switch]$MergeSettings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating $SettingType setting(s) in file: $SettingsFile"
    Write-Log -LogFile $logFile -Message "Updating $SettingType setting(s) in file: $SettingsFile" -Module $functionName

    function Test-SettingNameAndValue()
    {
        [CmdletBinding()]
        param(
            [string]$SettingName,
            $SettingValue,
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
        Write-Log -LogFile $logFile -Message "Validation passed for '$SettingName' (type '$settingType')" -Module $functionName -LogLevel "Verbose"
        return $true
    }
    
    # Validate parameters based on setting type
    switch ($SettingType)
    {
        'Global'
        {
            if (-not (Test-SettingNameAndValue -SettingName $SettingName -SettingValue $SettingValue -settingType 'Global'))
            {
                Write-Log -LogFile $logFile -Message "Invalid parameters for Global setting type" -Module $functionName -LogLevel "Error"
                return $false
            }
            Write-Verbose "[$functionName] Updating global setting '$SettingName' to '$SettingValue'"
            Write-Log -LogFile $logFile -Message "Updating global setting '$SettingName' to '$SettingValue'" -Module $functionName
        }
        'Auth'
        {
            if (-not (Test-SettingNameAndValue -SettingName $SettingName -SettingValue $SettingValue -settingType 'Auth'))
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
            Write-Log -LogFile $logFile -Message "Settings file not found: $SettingsFile" -Module $functionName -LogLevel "Verbose"
            return $false
        }
        
        # Load existing settings
        Write-Verbose "[$functionName] Loading existing settings from $SettingsFile"
        Write-Log -LogFile $logFile -Message "Loading existing settings from $SettingsFile" -Module $functionName
        $settingsObj = Import-PowerShellDataFile -Path $SettingsFile -ErrorAction Stop
        
        # Debug: Check what type we got
        Write-Verbose "[$functionName] DEBUG: settingsObj type is $($settingsObj.GetType().Name)"
        Write-Log -LogFile $logFile -Message "DEBUG: settingsObj type is $($settingsObj.GetType().Name)" -Module $functionName
        
        # Convert to hashtable for easier manipulation using optimized utility
        if (-not $settingsObj -is [hashtable])
        {
            Write-Verbose "[$functionName] DEBUG: Converting object to hashtable using optimized utility"
            $settingsHash = ConvertTo-HashtableOptimized -InputObject $settingsObj -Context "main settings"
        }
        else
        {
            Write-Verbose "[$functionName] DEBUG: Using object as-is (should be hashtable)"
            $settingsHash = $settingsObj
        }
        
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
        
        if (-not $settingsHash.ContainsKey($requiredSection) -and $SettingType -ne 'Domain')
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
                # Ensure globalSettings is a hashtable using optimized utility
                $globalSettingsHash = Test-IsHashtableOrConvert -InputObject $settingsHash['globalSettings']
                
                # Update the specific setting
                Write-Verbose "[$functionName] Updating globalSettings.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updating globalSettings.$SettingName = $SettingValue" -Module $functionName
                $globalSettingsHash[$SettingName] = $SettingValue
                $settingsHash['globalSettings'] = $globalSettingsHash
                Write-Verbose "[$functionName] Updated globalSettings.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updated globalSettings.$SettingName = $SettingValue" -Module $functionName
            }
            'Auth'
            {
                # Ensure auth is a hashtable using optimized utility
                $authSettingsHash = Test-IsHashtableOrConvert -InputObject $settingsHash['auth']
                
                # Update the specific setting
                Write-Verbose "[$functionName] Updating auth.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updating auth.$SettingName = $SettingValue" -Module $functionName
                $authSettingsHash[$SettingName] = $SettingValue
                $settingsHash['auth'] = $authSettingsHash
                Write-Verbose "[$functionName] Updated auth.$SettingName = $SettingValue"
                Write-Log -LogFile $logFile -Message "Updated auth.$SettingName = $SettingValue" -Module $functionName
            }
            'Domain'
            {
                # Use new separate domain configuration file approach
                Write-Verbose "[$functionName] Processing domain settings for '$DomainName' using separate configuration file (Merge=$MergeSettings)"
                Write-Log -LogFile $logFile -Message "Processing domain settings for '$DomainName' using separate configuration file (Merge=$MergeSettings)" -Module $functionName
                
                $configPath = Split-Path $SettingsFile -Parent
                # Load existing domain configuration
                $domainConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
                
                if ($null -eq $domainConfig)
                {
                    Write-Warning "[$functionName] Failed to load domain configuration for: $DomainName"
                    Write-Log -LogFile $logFile -Message "Failed to load domain configuration for: $DomainName" -Module $functionName -LogLevel "Warning"
                    return $false
                }
                
                # Update domain settings
                if ($MergeSettings -and $domainConfig)
                {
                    # Merge with existing settings
                    Write-Verbose "[$functionName] Merging settings with existing domain configuration"
                    Write-Log -LogFile $logFile -Message "Merging provided settings into existing domain configuration for '$DomainName'" -Module $functionName
                    
                    # Convert to hashtable for easier manipulation using optimized utility
                    $existingSettings = Test-IsHashtableOrConvert -InputObject $domainConfig
                    
                    # Merge new settings
                    foreach ($key in $Settings.Keys)
                    {
                        $existingSettings[$key] = $Settings[$key]
                        Write-Log -LogFile $logFile -Message "Updated domain setting: $key = $($Settings[$key])" -Module $functionName -LogLevel "Verbose"
                    }
                    
                    # Update domain config
                    $domainConfig = $existingSettings
                }
                else
                {
                    # Replace entire settings section
                    Write-Verbose "[$functionName] Replacing entire settings section for domain"
                    Write-Log -LogFile $logFile -Message "Replacing entire settings section for domain '$DomainName'" -Module $functionName
                    $domainConfig = $Settings
                }
                
                # Save the updated domain configuration
                $saveSuccess = Save-DomainConfiguration -DomainName $DomainName -DomainConfiguration $domainConfig -ConfigurationPath $configPath
                if (-not $saveSuccess)
                {
                    Write-Warning "[$functionName] Failed to save domain configuration for: $DomainName"
                    Write-Log -LogFile $logFile -Message "Failed to save domain configuration for: $DomainName" -Module $functionName -LogLevel "Warning"
                    return $false
                }
                
                Write-Verbose "[$functionName] Successfully updated domain configuration file for: $DomainName"
                Write-Log -LogFile $logFile -Message "Successfully updated domain configuration file for: $DomainName" -Module $functionName
            }
        }
        
        # Create backup and save updated settings (not needed for Domain type as it uses separate files)
        if ($SettingType -ne 'Domain')
        {
            $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $SettingsFile -Destination $backupFile -Force
            Write-Verbose "[$functionName] Created backup: $backupFile"
            Write-Log -LogFile $logFile -Message "Created backup: $backupFile" -Module $functionName
            
            # Save updated settings using Export-PowerShellDataFile
            $exportResult = Export-PowerShellDataFile -InputObject $settingsHash -Path $SettingsFile -Force
            if ($exportResult)
            {
                Write-Verbose "[$functionName] Saved updated settings to $SettingsFile"
                Write-Log -LogFile $logFile -Message "Saved updated settings to $SettingsFile" -Module $functionName
            }
            else
            {
                Write-Warning "[$functionName] Failed to save settings file"
                Write-Log -LogFile $logFile -Message "Failed to save settings file" -Module $functionName -LogLevel "Warning"
                return $false
            }
        }
        
        # Verify the update based on setting type
        Write-Log -LogFile $logFile -Message "Verifying update for SettingType '$SettingType'" -Module $functionName -LogLevel "Verbose"
        
        if ($SettingType -ne 'Domain')
        {
            $verifySettings = Import-PowerShellDataFile -Path $SettingsFile -ErrorAction Stop
            # Convert to hashtable if needed using optimized utility
            $verifySettingsHash = Test-IsHashtableOrConvert -InputObject $verifySettings
        }
        
        $verificationResult = switch ($SettingType)
        {
            'Global'
            {
                if ($verifySettingsHash['globalSettings'] -and $verifySettingsHash['globalSettings'].ContainsKey($SettingName))
                {
                    $actualValue = $verifySettingsHash['globalSettings'][$SettingName]
                    
                    # Handle array comparison specially (for appModes and other array settings)
                    if ($SettingValue -is [array] -and $actualValue -is [array])
                    {
                        $comparisonResult = Compare-Object $SettingValue $actualValue
                        if ($null -eq $comparisonResult)
                        {
                            Write-Verbose "[$functionName] Successfully updated and verified global setting (array)"
                            Write-Log -LogFile $logFile -Message "Successfully updated and verified global setting '$SettingName' (array)" -Module $functionName
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
                        Write-Verbose "[$functionName] Successfully updated and verified global setting (scalar)"
                        Write-Log -LogFile $logFile -Message "Successfully updated and verified global setting '$SettingName' (scalar)" -Module $functionName
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
                    Write-Warning "[$functionName] Failed to verify global setting update - property not found"
                    Write-Log -LogFile $logFile -Message "Failed to verify global setting update - property '$SettingName' not found" -Module $functionName -LogLevel "Warning"
                    $false
                }
            }
            'Auth'
            {
                if ($verifySettingsHash['auth'] -and $verifySettingsHash['auth'].ContainsKey($SettingName))
                {
                    $actualValue = $verifySettingsHash['auth'][$SettingName]
                    
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
                    Write-Log -LogFile $logFile -Message "Failed to verify auth setting update - property '$SettingName' not found" -Module $functionName -LogLevel "Verbose"
                    $false
                }
            }
            'Domain'
            {
                # Verify domain configuration was saved to separate file
                $configPath = Split-Path $SettingsFile -Parent
                $domainConfigFile = Join-Path $configPath "$DomainName.psd1"
                
                if (Test-Path $domainConfigFile)
                {
                    try
                    {
                        $verifyDomainConfig = Import-PowerShellDataFile -Path $domainConfigFile -ErrorAction Stop
                        if ($verifyDomainConfig)
                        {
                            Write-Verbose "[$functionName] Successfully updated and verified domain settings in separate file"
                            Write-Log -LogFile $logFile -Message "Successfully updated and verified domain settings for '$DomainName' in separate file" -Module $functionName
                            $true
                        }
                        else
                        {
                            Write-Warning "[$functionName] Domain configuration file exists but missing settings section"
                            Write-Log -LogFile $logFile -Message "Domain configuration file exists but missing settings section for '$DomainName'" -Module $functionName -LogLevel "Warning"
                            $false
                        }
                    }
                    catch
                    {
                        Write-Warning "[$functionName] Failed to parse domain configuration file: $($_.Exception.Message)"
                        Write-Log -LogFile $logFile -Message "Failed to parse domain configuration file for '$DomainName': $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
                        $false
                    }
                }
                else
                {
                    Write-Warning "[$functionName] Failed to verify domain settings - configuration file not found"
                    Write-Log -LogFile $logFile -Message "Failed to verify domain settings - configuration file not found for '$DomainName'" -Module $functionName -LogLevel "Verbose"
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