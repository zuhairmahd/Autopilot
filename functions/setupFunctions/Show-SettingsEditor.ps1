function Show-SettingsEditor()
{
    <#
    .SYNOPSIS
        Interactive editor for application settings using default values from Test-SettingsJsonExists.
    
    .DESCRIPTION
        Provides an interactive interface for users to modify application settings.
        Uses the default settings structure from Test-SettingsJsonExists as the source of truth
        for available settings and their descriptions. Supports different data types including
        boolean, string, array, and enumerated values with proper validation.
    
    .PARAMETER SettingsType
        Specifies whether to edit 'Global', 'Domain', or 'Auth' settings.
    
    .PARAMETER SettingsFile
        Path to the settings.json file. Defaults to "settings.json".
    
    .PARAMETER DomainName
        Required when SettingsType is 'Domain'. Specifies which domain's settings to edit.
    
    .PARAMETER Silent
        If specified, uses defaults and minimal output.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully updated, $false otherwise.
    
    .EXAMPLE
        Show-SettingsEditor -SettingsType "Global"
    
    .EXAMPLE
        Show-SettingsEditor -SettingsType "Domain" -DomainName "contoso.com"
    
    .EXAMPLE
        Show-SettingsEditor -SettingsType "Auth"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses unified Update-Setting function for all setting types
        - Leverages Test-SettingsJsonExists for default settings structure
        - Supports auth settings editing with Test-AuthDefaults for validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Domain', 'Auth')]
        [string]$SettingsType,
        [string]$SettingsFile = "settings.json",
        [string]$DomainName,
        [switch]$Silent,
        [hashtable]$PresetValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting settings editor for $SettingsType settings" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting settings editor for $SettingsType settings"
    
    try
    {
        # Validate parameters
        if ($SettingsType -eq 'Domain' -and [string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "DomainName is required when editing Domain settings" -LogLevel "Error"
            Write-Warning "[$functionName] DomainName is required when editing Domain settings"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Parameter validation passed. SettingsType: $SettingsType, SettingsFile: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Parameter validation passed. SettingsType: $SettingsType, SettingsFile: $SettingsFile"
        
        # For auth settings, ensure auth defaults are in place
        if ($SettingsType -eq 'Auth')
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Ensuring auth defaults are present" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Ensuring auth defaults are present"
            $authDefaultsSuccess = Test-AuthDefaults -SettingsFile $SettingsFile -Silent
            if (-not $authDefaultsSuccess)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to ensure auth defaults" -LogLevel "Error"
                Write-Warning "[$functionName] Failed to ensure auth defaults"
                return $false
            }
        }
        
        # Get default settings structure from Test-SettingsJsonExists
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving default settings structure" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving default settings structure"
        $defaultSettings = Get-DefaultSettingsStructure
        if (-not $defaultSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to get default settings structure" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to get default settings structure"
            return $false
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully retrieved default settings structure" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Successfully retrieved default settings structure"
        
        # Load current settings
        Write-Log -LogFile $logFile -Module $functionName -Message "Loading current settings from: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Loading current settings from: $SettingsFile"
        $currentSettings = Get-CurrentSettings -SettingsFile $SettingsFile -SettingsType $SettingsType -DomainName $DomainName
        if (-not $currentSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load current settings" -LogLevel "Error"
            Write-Warning "[$functionName] Failed to load current settings"
            return $false
        }
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully loaded current settings" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Successfully loaded current settings"
        
        # Get settings template to edit
        if ($SettingsType -eq 'Global')
        {
            $settingsTemplate = $defaultSettings.globalSettings
            $currentValues = $currentSettings.globalSettings
            Write-Log -LogFile $logFile -Module $functionName -Message "Editing global settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Editing global settings"
            if (-not $Silent)
            {
                Write-Host "`n── Global Settings Editor ──" -ForegroundColor Cyan
                Write-Host "Modify global application settings that apply to all domains." -ForegroundColor White
            }
        }
        elseif ($SettingsType -eq 'Auth')
        {
            $settingsTemplate = Get-AuthDefaults
            $currentValues = $currentSettings.auth
            Write-Log -LogFile $logFile -Module $functionName -Message "Editing auth settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Editing auth settings"
            if (-not $Silent)
            {
                Write-Host "`n── Authentication Settings Editor ──" -ForegroundColor Cyan
                Write-Host "Modify authentication and authorization settings." -ForegroundColor White
                Write-Host "These settings control how the application authenticates with Microsoft Graph API." -ForegroundColor Gray
            }
        }
        else
        {
            # Load domain settings from separate domain configuration file
            $configPath = Split-Path $SettingsFile -Parent
            Write-Log -LogFile $logFile -Module $functionName -Message "Loading domain configuration for '$DomainName' from path: '$configPath'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Loading domain configuration for '$DomainName' from path: '$configPath'"
            
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName $DomainName -ConfigurationPath $configPath
            
            if ($null -eq $domainConfig -or $null -eq $domainConfig.settings)
            {
                Write-Warning "[$functionName] Failed to load domain configuration for: $DomainName"
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to load domain configuration for: $DomainName" -LogLevel "Warning"
                return $false
            }
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully loaded domain configuration for '$DomainName'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Successfully loaded domain configuration for '$DomainName'"
            
            # Get domain settings template from centralized defaults (fixed approach)
            Write-Log -LogFile $logFile -Module $functionName -Message "Getting domain settings template from centralized defaults for domain: '$DomainName'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Getting domain settings template from centralized defaults for domain: '$DomainName'"
            
            try
            {
                $domainTemplate = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
                if ($null -eq $domainTemplate -or $null -eq $domainTemplate.settings)
                {
                    Write-Warning "[$functionName] Failed to get domain template from centralized defaults"
                    Write-Log -LogFile $logFile -Module $functionName -Message "Failed to get domain template from centralized defaults" -LogLevel "Warning"
                    return $false
                }
                
                $settingsTemplate = $domainTemplate.settings
                Write-Log -LogFile $logFile -Module $functionName -Message "Successfully retrieved domain settings template with $($settingsTemplate.Count) properties" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Successfully retrieved domain settings template with $($settingsTemplate.Count) properties"
            }
            catch
            {
                Write-Warning "[$functionName] Error retrieving domain template: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Module $functionName -Message "Error retrieving domain template: $($_.Exception.Message)" -LogLevel "Error"
                return $false
            }
            
            # Use the actual domain configuration for current values
            $currentValues = $domainConfig.settings
            Write-Log -LogFile $logFile -Module $functionName -Message "Using current domain settings with $($currentValues.PSObject.Properties.Count) properties" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Using current domain settings with $($currentValues.PSObject.Properties.Count) properties"
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Editing domain settings for domain: '$DomainName' from separate configuration file" -LogLevel "Information"
            Write-Verbose "[$functionName] Editing domain settings for domain: '$DomainName' from separate configuration file"
            if (-not $Silent)
            {
                Write-Host "`n── Domain Settings Editor ──" -ForegroundColor Cyan
                Write-Host "Modify settings specific to domain: $DomainName" -ForegroundColor Yellow -BackgroundColor DarkMagenta
                Write-Host "Selected domain: $DomainName" -ForegroundColor Green
            }
        }
        
        if (-not $settingsTemplate)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No settings template found for $SettingsType" -LogLevel "Error"
            Write-Warning "[$functionName] No settings template found for $SettingsType"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Settings template loaded successfully. Found $($settingsTemplate.PSObject.Properties.Count) settings to process" -LogLevel "Information"
        Write-Verbose "[$functionName] Settings template loaded successfully. Found $($settingsTemplate.PSObject.Properties.Count) settings to process"
        
        Write-Host ""
        $updatedSettings = @{}
        $hasChanges = $false
        
        # Process each setting in the template - with support for nested objects
        $processedSettings = Get-FlattenedSettingsForEditing -SettingsTemplate $settingsTemplate -CurrentValues $currentValues
        
        foreach ($settingInfo in $processedSettings)
        {
            $settingName = $settingInfo.Name
            $settingPath = $settingInfo.Path
            $defaultValue = $settingInfo.DefaultValue
            $currentValue = $settingInfo.CurrentValue
            $isNested = $settingInfo.IsNested
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Processing setting: '$settingPath', Current: '$currentValue', Default: '$defaultValue', IsNested: $isNested" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Processing setting: '$settingPath', Current: '$currentValue', Default: '$defaultValue', IsNested: $isNested"
            
            # Skip nested container objects that should not be edited directly
            if ($isNested -and ($defaultValue -is [hashtable] -or $defaultValue -is [PSCustomObject]))
            {
                Write-Verbose "[$functionName] Skipping nested container object: '$settingPath'"
                continue
            }
            
            if (-not $Silent)
            {
                # Display setting with path for nested values
                $displayName = if ($isNested) { $settingPath } else { $settingName }
                Write-Host "Setting: $displayName" -ForegroundColor Yellow
                Write-Host "Description: $(Get-SettingDescription -SettingName $settingName)" -ForegroundColor Gray
                Write-Host "Current value: $(Format-SettingValueForDisplay -Value $currentValue)" -ForegroundColor Cyan
            }
            
            # Determine setting type and get input
            $newValue = if ($PresetValues -and $PresetValues.ContainsKey($settingName))
            {
                $PresetValues[$settingName]
            }
            elseif ($Silent)
            {
                $currentValue  # Keep current value in silent mode
            }
            else
            {
                Get-SettingInput -SettingName $settingName -CurrentValue $currentValue -DefaultValue $defaultValue
            }
            
            if ($newValue -ne $currentValue)
            {
                # For nested settings, use the path as the key
                $keyToUse = if ($isNested) { $settingPath } else { $settingName }
                $updatedSettings[$keyToUse] = $newValue
                $hasChanges = $true
                Write-Log -LogFile $logFile -Module $functionName -Message "Setting '$settingPath' changed from '$currentValue' to '$newValue'" -LogLevel "Information"
                Write-Verbose "[$functionName] Setting '$settingPath' changed from '$currentValue' to '$newValue'"
                if (-not $Silent)
                {
                    Write-Host "Updated to: $(Format-SettingValueForDisplay -Value $newValue)" -ForegroundColor Green
                }
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Setting '$settingPath' unchanged (value: '$currentValue')" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Setting '$settingPath' unchanged (value: '$currentValue')"
                if (-not $Silent)
                {
                    Write-Host "No change" -ForegroundColor Gray
                }
            }
            
            if (-not $Silent)
            {
                Write-Host ""
            }
        }
        
        # Save changes if any were made
        if ($hasChanges)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Changes detected. Saving $($updatedSettings.Count) updated settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Changes detected. Saving $($updatedSettings.Count) updated settings"
            if (-not $Silent)
            {
                Write-Host "Saving changes..." -ForegroundColor Yellow
            }
            
            $success = if ($SettingsType -eq 'Global')
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Saving global settings" -LogLevel "Verbose"
                Save-GlobalSettings -Settings $updatedSettings -SettingsFile $SettingsFile
            }
            elseif ($SettingsType -eq 'Auth')
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Saving auth settings" -LogLevel "Verbose"
                Save-AuthSettings -Settings $updatedSettings -SettingsFile $SettingsFile
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Saving domain settings for: '$DomainName'" -LogLevel "Verbose"
                Save-DomainSettings -DomainName $DomainName -Settings $updatedSettings -SettingsFile $SettingsFile
            }
            
            if ($success)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Settings saved successfully" -LogLevel "Information"
                Write-Verbose "[$functionName] Settings saved successfully"
                if (-not $Silent)
                {
                    Write-Host "Settings saved successfully!" -ForegroundColor Green
                }
                return $true
            }
            else
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to save settings" -LogLevel "Error"
                Write-Verbose "[$functionName] Failed to save settings"
                if (-not $Silent)
                {
                    Write-Host "Failed to save settings!" -ForegroundColor Red
                }
                return $false
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No changes were made" -LogLevel "Information"
            Write-Verbose "[$functionName] No changes were made"
            if (-not $Silent)
            {
                Write-Host "No changes were made." -ForegroundColor Yellow
            }
            return $true
        }
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in settings editor: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in settings editor: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Get-DefaultSettingsStructure()
{
    <#
    .SYNOPSIS
        Retrieves the default settings structure efficiently from centralized defaults.
    
    .DESCRIPTION
        Uses the centralized Get-ApplicationDefaults function to retrieve default settings.
        This ensures consistency and eliminates duplicate default value definitions.
    #>
    [CmdletBinding()]
    param()

    $functionName = $MyInvocation.MyCommand.Name
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving default settings structure from centralized defaults" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Retrieving default settings structure from centralized defaults"
    
    try
    {
        # Use centralized default values - single source of truth
        Write-Log -LogFile $logFile -Module $functionName -Message "Getting defaults from Get-ApplicationDefaults" -LogLevel "Debug"
        Write-Verbose "[$functionName] Getting defaults from Get-ApplicationDefaults"
        
        $defaultSettings = Get-ApplicationDefaults -DefaultType "Settings"
        
        if (-not $defaultSettings)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to get default settings from centralized function" -LogLevel "Error"
            Write-Verbose "[$functionName] Failed to get default settings from centralized function"
            return $null
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Default settings structure retrieved successfully from centralized source" -LogLevel "Information"
        Write-Verbose "[$functionName] Default settings structure retrieved successfully from centralized source"
        
        # Convert to PSCustomObject to match the JSON structure behavior expected by consuming functions
        $jsonString = $defaultSettings | ConvertTo-Json -Depth $global:maxJSONDepth
        $defaultStructure = $jsonString | ConvertFrom-Json
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Default settings structure converted to PSCustomObject format" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Default settings structure converted to PSCustomObject format"
        
        return $defaultStructure
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error retrieving default settings structure: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error retrieving default settings structure: $($_.Exception.Message)"
        return $null
    }
}

function Get-CurrentSettings()
{
    <#
    .SYNOPSIS
        Loads current settings from the settings file.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingsFile,
        [string]$SettingsType,
        [string]$DomainName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Loading current settings from: $SettingsFile for type: $SettingsType" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Loading current settings from: $SettingsFile for type: $SettingsType"
    
    if ($SettingsType -eq 'Domain')
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Domain name: '$DomainName'" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Domain name: '$DomainName'"
    }
    
    try
    {
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Settings file not found, creating with defaults" -LogLevel "Information"
            Write-Verbose "Settings file not found, creating with defaults"
            if (-not (Test-SettingsJsonExists -SettingsFile $SettingsFile -Silent))
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to create default settings file" -LogLevel "Error"
                Write-Verbose "[$functionName] Failed to create default settings file"
                return $null
            }
            Write-Log -LogFile $logFile -Module $functionName -Message "Default settings file created" -LogLevel "Information"
            Write-Verbose "[$functionName] Default settings file created"
        }
        
        $content = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
        Write-Log -LogFile $logFile -Module $functionName -Message "Settings file loaded successfully" -LogLevel "Information"
        Write-Verbose "[$functionName] Settings file loaded successfully"
        return $content
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error loading current settings: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "Error loading current settings: $($_.Exception.Message)"
        return $null
    }
}

function Get-FlattenedSettingsForEditing()
{
    <#
    .SYNOPSIS
        Flattens settings structure for editing while preserving nested object information.
    
    .DESCRIPTION
        Processes both template and current values to create a flat list of editable settings
        with proper path information for nested values. Handles hashtables and PSCustomObjects.
    #>
    [CmdletBinding()]
    param(
        $SettingsTemplate,
        $CurrentValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Flattening settings for editing"
    
    $flattenedSettings = @()
    
    if ($SettingsTemplate -is [hashtable])
    {
        # Handle hashtable (auth settings)
        foreach ($key in $SettingsTemplate.Keys)
        {
            $defaultValue = $SettingsTemplate[$key]
            $currentValue = Get-NestedValue -Object $CurrentValues -Path $key
            if ($null -eq $currentValue) { $currentValue = $defaultValue }
            
            if ($defaultValue -is [hashtable] -or $defaultValue -is [PSCustomObject])
            {
                # Process nested object
                $nestedSettings = Get-FlattenedSettingsForEditing -SettingsTemplate $defaultValue -CurrentValues $currentValue
                foreach ($nestedSetting in $nestedSettings)
                {
                    $nestedSetting.Path = "$key.$($nestedSetting.Path)"
                    $nestedSetting.IsNested = $true
                }
                $flattenedSettings += $nestedSettings
            }
            else
            {
                # Simple value
                $flattenedSettings += @{
                    Name = $key
                    Path = $key
                    DefaultValue = $defaultValue
                    CurrentValue = $currentValue
                    IsNested = $false
                }
            }
        }
    }
    else
    {
        # Handle PSCustomObject (global and domain settings)
        foreach ($property in $SettingsTemplate.PSObject.Properties)
        {
            $key = $property.Name
            $defaultValue = $property.Value
            $currentValue = Get-NestedValue -Object $CurrentValues -Path $key
            if ($null -eq $currentValue) { $currentValue = $defaultValue }
            
            if ($defaultValue -is [hashtable] -or $defaultValue -is [PSCustomObject])
            {
                # Process nested object
                $nestedSettings = Get-FlattenedSettingsForEditing -SettingsTemplate $defaultValue -CurrentValues $currentValue
                foreach ($nestedSetting in $nestedSettings)
                {
                    $nestedSetting.Path = "$key.$($nestedSetting.Path)"
                    $nestedSetting.IsNested = $true
                }
                $flattenedSettings += $nestedSettings
            }
            else
            {
                # Simple value
                $flattenedSettings += @{
                    Name = $key
                    Path = $key
                    DefaultValue = $defaultValue
                    CurrentValue = $currentValue
                    IsNested = $false
                }
            }
        }
    }
    
    Write-Verbose "[$functionName] Flattened $($flattenedSettings.Count) settings for editing"
    return $flattenedSettings
}

function Get-NestedValue()
{
    <#
    .SYNOPSIS
        Gets a value from a nested object using dot notation path.
    #>
    [CmdletBinding()]
    param(
        $Object,
        [string]$Path
    )
    
    if (-not $Object -or [string]::IsNullOrWhiteSpace($Path))
    {
        return $null
    }
    
    $pathParts = $Path.Split('.')
    $current = $Object
    
    foreach ($part in $pathParts)
    {
        if ($current -is [hashtable])
        {
            if ($current.ContainsKey($part))
            {
                $current = $current[$part]
            }
            else
            {
                return $null
            }
        }
        elseif ($current -is [PSCustomObject])
        {
            if ($current.PSObject.Properties.Name -contains $part)
            {
                $current = $current.$part
            }
            else
            {
                return $null
            }
        }
        else
        {
            return $null
        }
    }
    
    return $current
}

function Format-SettingValueForDisplay()
{
    <#
    .SYNOPSIS
        Formats a setting value for display in the UI.
    #>
    [CmdletBinding()]
    param($Value)
    
    if ($Value -is [array])
    {
        if ($Value.Count -eq 0)
        {
            return "(empty array)"
        }
        else
        {
            return "[$($Value -join ', ')]"
        }
    }
    elseif ($Value -is [bool])
    {
        return $Value.ToString().ToLower()
    }
    elseif ($Value -is [hashtable] -or $Value -is [PSCustomObject])
    {
        return "(nested object)"
    }
    elseif ([string]::IsNullOrWhiteSpace($Value))
    {
        return "(not set)"
    }
    else
    {
        return $Value.ToString()
    }
}

function Get-SettingDescription()
{
    <#
    .SYNOPSIS
        Returns a user-friendly description for a setting.
    #>
    [CmdletBinding()]
    param([string]$SettingName)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting description for setting: '$SettingName'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting description for setting: '$SettingName'" -LogLevel "Verbose"
    
    $descriptions = @{
        'configFile'                      = 'Path to the configuration file storing encrypted authentication data'
        'maxWaitTime'                     = 'How long, in minutes, to wait before stopping retries.'
        'showLicenseBanner'               = 'Whether to display the license banner on startup'
        'deviceContactThresholdInDays'    = 'Number of days before a device is considered stale'
        'appMode'                         = 'Application mode controlling which features are available'
        'timeInSeconds'                   = 'Default timeout to wait between retries in seconds'
        'maxUserMatchDisplay'             = 'Maximum number of user matches to display in search results'
        'release'                         = 'Release branch or version to track for updates'
        'repo'                            = 'Repository source for updates (Github/Gitlab)'
        'testMode'                        = 'Enable test mode with additional debugging features'
        'operatingSystem'                 = 'Target operating system (Windows/macOS/Linux)'
        'autoUpdate'                      = 'Automatically check for and install updates'
        'domain'                          = 'Domain name for this configuration'
        'deviceNamePrefix'                = 'Prefix to add to device names during enrollment'
        'minUsernameLength'               = 'Minimum allowed username length'
        'maxUserNameLength'               = 'Maximum allowed username length'
        'maxSerialNumberLength'           = 'Maximum allowed serial number length'
        'minSerialNumberLength'           = 'Minimum allowed serial number length'
        'minimumDevicePhysicalMemoryInGB' = 'Minimum required device memory in GB'
        'maxNumberOfDevicesAllowed'       = 'Maximum devices a user can have enrolled'
        'preferredBrowser'                = 'Default browser for web-based operations'
        'privateSession'                  = 'Use private/incognito browsing sessions'
        'userPatternsToExclude'           = 'Username patterns to exclude from operations'
        'desiredAutopilotProfiles'        = 'Autopilot profiles to assign to devices'
        'changePwOnNextStart'             = 'Force password change on next application start'
        'authType'                        = 'Authentication method (PublicAuthFlow, PrivateAuthFlow, etc.)'
        'noSaveRefreshToken'              = 'Prevent saving refresh tokens to disk'
        'forceNewToken'                   = 'Force acquisition of new authentication token'
        'renewalLeadTime'                 = 'Minutes before token expires to attempt renewal'
        'scope'                           = 'Microsoft Graph API permissions required by the application'
        'cacheType'                       = 'Token cache storage method (Memory, File)'
        'secureString'                    = 'Use secure string for password storage'
        'delegated'                       = 'Use delegated permissions (user context) vs application permissions'
        # Nested object descriptions
        'repoPath'                        = 'GitHub/GitLab repository owner/organization name'
        'baseURL'                         = 'Base URL for repository hosting service'
        'baseSourceURL'                   = 'Base URL for raw file access'
        'repoName'                        = 'Repository name'
        'companyName'                     = 'Company or organization name'
        'supportEmail'                    = 'Support contact email address'
        'supportPhone'                    = 'Support contact phone number'
        'helpDeskURL'                     = 'URL for help desk or support portal'
    }
    
    if ($descriptions.ContainsKey($SettingName))
    {
        Write-Verbose "[$functionName] Found description for '$SettingName'"
        Write-Log -LogFile $logFile -Module $functionName -Message "Found description for '$SettingName'" -LogLevel "Debug"
        return $descriptions[$SettingName]
    }
    else
    {
        Write-Verbose "[$functionName] No specific description found for '$SettingName', using generic description"
        Write-Log -LogFile $logFile -Module $functionName -Message "No specific description found for '$SettingName', using generic description" -LogLevel "Debug"
        return "Configuration setting: $SettingName"
    }
}

function Get-SettingInput()
{
    <#
    
    .SYNOPSIS
        Gets user input for a setting based on its type and validation rules.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingName,
        $CurrentValue,
        $DefaultValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting input for setting '$SettingName'. Current: '$CurrentValue', Default: '$DefaultValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting input for setting '$SettingName'. Current: '$CurrentValue', Default: '$DefaultValue'" -LogLevel "Verbose"
    
    # Determine the type of input needed
    $inputType = Get-SettingInputType -SettingName $SettingName -Value $DefaultValue
    Write-Verbose "[$functionName] Determined input type: '$inputType' for setting '$SettingName'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Determined input type: '$inputType' for setting '$SettingName'" -LogLevel "Verbose"
    
    switch ($inputType)
    {
        'Boolean'
        {
            Write-Verbose "[$functionName] Using boolean input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using boolean input for '$SettingName'" -LogLevel "Verbose"
            return Get-BooleanInput -CurrentValue $CurrentValue
        }
        'AppMode'
        {
            Write-Verbose "[$functionName] Using app mode input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using app mode input for '$SettingName'" -LogLevel "Verbose"
            return Get-AppModeInput -CurrentValue $CurrentValue
        }
        'CacheType'
        {
            Write-Verbose "[$functionName] Using cache type input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using cache type input for '$SettingName'" -LogLevel "Verbose"
            return Get-CacheTypeInput -CurrentValue $CurrentValue
        }
        'Repo'
        {
            Write-Verbose "[$functionName] Using repository input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using repository input for '$SettingName'" -LogLevel "Verbose"
            return Get-RepoInput -CurrentValue $CurrentValue
        }
        'OperatingSystem'
        {
            Write-Verbose "[$functionName] Using operating system input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using operating system input for '$SettingName'" -LogLevel "Verbose"
            return Get-OperatingSystemInput -CurrentValue $CurrentValue
        }
        'Browser'
        {
            Write-Verbose "[$functionName] Using browser input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using browser input for '$SettingName'" -LogLevel "Verbose"
            return Get-BrowserInput -CurrentValue $CurrentValue
        }
        'AuthType'
        {
            Write-Verbose "[$functionName] Using auth type input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using auth type input for '$SettingName'" -LogLevel "Verbose"
            return Get-AuthTypeInput -CurrentValue $CurrentValue
        }
        'Array'
        {
            Write-Verbose "[$functionName] Using array input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using array input for '$SettingName'" -LogLevel "Verbose"
            return Get-ArrayInput -CurrentValue $CurrentValue
        }
        'Number'
        {
            Write-Verbose "[$functionName] Using number input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using number input for '$SettingName'" -LogLevel "Verbose"
            return Get-NumberInput -SettingName $SettingName -CurrentValue $CurrentValue
        }
        default
        {
            Write-Verbose "[$functionName] Using string input for '$SettingName'"
            Write-Log -LogFile $logFile -Module $functionName -Message "Using string input for '$SettingName'" -LogLevel "Verbose"
            return Get-StringInput -SettingName $SettingName -CurrentValue $CurrentValue
        }
    }
}

function Get-SettingInputType()
{
    <#
    .SYNOPSIS
        Determines the input type for a setting.
    #>
    param(
        [string]$SettingName,
        $Value
    )
    
    Write-Verbose "[$functionName] Determining input type for setting '$SettingName' with value type: $($Value.GetType().Name)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Determining input type for setting '$SettingName' with value type: $($Value.GetType().Name)" -LogLevel "Verbose"
    
    # Check for specific known enumerated types
    if ($SettingName -eq 'appMode')
    { 
        Write-Verbose "[$functionName] Detected AppMode setting"
        return 'AppMode' 
    }
    if ($SettingName -eq 'cacheType')
    { 
        Write-Verbose "[$functionName] Detected CacheType setting"
        return 'CacheType' 
    }
    if ($SettingName -eq 'repo')
    { 
        Write-Verbose "[$functionName] Detected Repo setting"
        return 'Repo' 
    }
    if ($SettingName -eq 'operatingSystem')
    { 
        Write-Verbose "[$functionName] Detected OperatingSystem setting"
        return 'OperatingSystem' 
    }
    if ($SettingName -eq 'preferredBrowser')
    { 
        Write-Verbose "[$functionName] Detected Browser setting"
        return 'Browser' 
    }
    if ($SettingName -eq 'authType')
    { 
        Write-Verbose "[$functionName] Detected AuthType setting"
        return 'AuthType' 
    }
    
    # Check by value type
    if ($Value -is [bool])
    { 
        Write-Verbose "[$functionName] Detected Boolean value type"
        return 'Boolean' 
    }
    if ($Value -is [array])
    { 
        Write-Verbose "[$functionName] Detected Array value type"
        return 'Array' 
    }
    if ($Value -match '^\d+$')
    { 
        Write-Verbose "[$functionName] Detected Number value type"
        return 'Number' 
    }
    
    Write-Verbose "[$functionName] Defaulting to String value type"
    return 'String'
}

function Get-BooleanInput()
{
    <#
    .SYNOPSIS
        Gets boolean input from user with menu.
    #>
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting boolean input. Current value: $CurrentValue"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting boolean input. Current value: $CurrentValue" -LogLevel "Verbose"
    
    Write-Host "Choose option:" -ForegroundColor White
    if ($CurrentValue -eq $true)
    {
        Write-Host "1. True (Current)" -ForegroundColor Green
        Write-Host "2. False" -ForegroundColor White
    }
    else
    {
        Write-Host "1. True" -ForegroundColor White
        Write-Host "2. False (Current)" -ForegroundColor Green
    }
    Write-Host "Press Enter to keep current value" -ForegroundColor Yellow
    
    do
    {
        $choice = Read-Host "Enter choice (1-2)"
        
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            Write-Verbose "[$functionName] User chose to keep current boolean value: $CurrentValue"
            Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current boolean value: $CurrentValue" -LogLevel "Verbose"
            return $CurrentValue
        }
        
        switch ($choice)
        {
            '1'
            { 
                Write-Verbose "[$functionName] User selected: True"
                Write-Log -LogFile $logFile -Module $functionName -Message "User selected: True" -LogLevel "Information"
                return $true 
            }
            '2'
            { 
                Write-Verbose "[$functionName] User selected: False"
                Write-Log -LogFile $logFile -Module $functionName -Message "User selected: False" -LogLevel "Information"
                return $false 
            }
            default
            {
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
                Write-Verbose "[$functionName] Invalid choice entered: '$choice'"
                Write-Log -LogFile $logFile -Module $functionName -Message "Invalid choice entered: '$choice'" -LogLevel "Warning"
            }
        }
    } while ($true)
}

function Get-AppModeInput()
{
    <#
    .SYNOPSIS
        Gets app mode input from user.
    #>
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting app mode input. Current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting app mode input. Current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $modes = @('full', 'helpDesk', 'advanced', 'advancedRegistration', 'registration', 'admin', 'custom')
    
    Write-Host "Available app modes:" -ForegroundColor White
    for ($i = 0; $i -lt $modes.Count; $i++)
    {
        $mode = $modes[$i]
        if ($mode -eq $CurrentValue)
        {
            Write-Host "$($i + 1). $mode (Current)" -ForegroundColor Green
        }
        else
        {
            Write-Host "$($i + 1). $mode" -ForegroundColor White
        }
    }
    Write-Host "Press Enter to keep current value" -ForegroundColor Yellow
    
    do
    {
        $choice = Read-Host "Enter choice (1-$($modes.Count))"
        
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            Write-Verbose "[$functionName] User chose to keep current app mode: '$CurrentValue'"
            Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current app mode: '$CurrentValue'" -LogLevel "Verbose"
            return $CurrentValue
        }
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $modes.Count)
        {
            $selectedMode = $modes[[int]$choice - 1]
            Write-Verbose "[$functionName] User selected app mode: '$selectedMode'"
            Write-Log -LogFile $logFile -Module $functionName -Message "User selected app mode: '$selectedMode'" -LogLevel "Information"
            return $selectedMode
        }
        
        Write-Host "Invalid choice. Please enter a number between 1 and $($modes.Count)." -ForegroundColor Red
        Write-Verbose "[$functionName] Invalid choice entered: '$choice'"
        Write-Log -LogFile $logFile -Module $functionName -Message "Invalid choice entered: '$choice'" -LogLevel "Warning"
    } while ($true)
}

function Get-CacheTypeInput()
{
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting cache type input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting cache type input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $types = @('Memory', 'File')
    return Get-EnumeratedInput -Options $types -CurrentValue $CurrentValue -PromptText "cache type"
}

function Get-RepoInput()
{
    [CmdletBinding()]
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting repository input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting repository input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $repos = @('Github', 'Gitlab')
    return Get-EnumeratedInput -Options $repos -CurrentValue $CurrentValue -PromptText "repository"
}

function Get-OperatingSystemInput()
{
    [CmdletBinding()]
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting operating system input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting operating system input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $systems = @('Windows', 'macOS', 'Linux')
    return Get-EnumeratedInput -Options $systems -CurrentValue $CurrentValue -PromptText "operating system"
}

function Get-BrowserInput()
{
    [CmdletBinding()]
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting browser input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting browser input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $browsers = @('Chrome', 'Edge', 'Firefox', 'Safari')
    return Get-EnumeratedInput -Options $browsers -CurrentValue $CurrentValue -PromptText "browser"
}

function Get-EnumeratedInput()
{
    <#
    .SYNOPSIS
        Generic function for enumerated input choices.
    #>
    [CmdletBinding()]
    param(
        [array]$Options,
        $CurrentValue,
        [string]$PromptText
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting enumerated input for '$PromptText'. Current value: '$CurrentValue'. Available options: $($Options.Count)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting enumerated input for '$PromptText'. Current value: '$CurrentValue'. Options count: $($Options.Count)" -LogLevel "Verbose"
    
    Write-Host "Available $PromptText options:" -ForegroundColor White
    for ($i = 0; $i -lt $Options.Count; $i++)
    {
        $option = $Options[$i]
        if ($option -eq $CurrentValue)
        {
            Write-Host "$($i + 1). $option (Current)" -ForegroundColor Green
        }
        else
        {
            Write-Host "$($i + 1). $option" -ForegroundColor White
        }
    }
    Write-Host "Press Enter to keep current value" -ForegroundColor Yellow
    
    do
    {
        $choice = Read-Host "Enter choice (1-$($Options.Count))"
        
        if ([string]::IsNullOrWhiteSpace($choice))
        {
            Write-Verbose "[$functionName] User chose to keep current value: '$CurrentValue'"
            Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current value: '$CurrentValue'" -LogLevel "Verbose"
            return $CurrentValue
        }
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $Options.Count)
        {
            $selectedValue = $Options[[int]$choice - 1]
            Write-Verbose "[$functionName] User selected option $($choice): '$selectedValue'"
            Write-Log -LogFile $logFile -Module $functionName -Message "User selected option $($choice): '$selectedValue'" -LogLevel "Information"
            return $selectedValue
        }
        
        Write-Host "Invalid choice. Please enter a number between 1 and $($Options.Count)." -ForegroundColor Red
        Write-Verbose "[$functionName] Invalid choice entered: '$choice'"
        Write-Log -LogFile $logFile -Module $functionName -Message "Invalid choice entered: '$choice'" -LogLevel "Warning"
    } while ($true)
}

function Get-ArrayInput()
{
    <#
    .SYNOPSIS
        Gets array input from user.
    #>
    [CmdletBinding()]
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting array input. Current value count: $($CurrentValue.Count)" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Getting array input. Current value count: $($CurrentValue.Count)"
    
    Write-Host "Current array values:" -ForegroundColor Cyan
    if ($CurrentValue -and $CurrentValue.Count -gt 0)
    {
        foreach ($value in $CurrentValue)
        {
            Write-Host "  - $value" -ForegroundColor White
        }
    }
    else
    {
        Write-Host "  (empty)" -ForegroundColor Gray
    }
    
    # Determine if we should ask about replace vs add
    $shouldReplaceExisting = $true
    if ($CurrentValue -and $CurrentValue.Count -gt 0)
    {
        Write-Host "`nYou have existing values in this array." -ForegroundColor Yellow
        Write-Host "Do you want to:" -ForegroundColor White
        Write-Host "  1. Replace all existing values with new ones" -ForegroundColor White
        Write-Host "  2. Add new values to the existing ones" -ForegroundColor White
        Write-Host "  3. Keep current values unchanged" -ForegroundColor White
        $choice = Read-Host "Enter your choice (1-3)"
        while ($choice -notmatch '^[1-3]$')
        {
            Write-Host "Invalid choice. Please enter a number between 1 and 3." -ForegroundColor Red
            [console]::beep(1000, 500)
            $choice = Read-Host "Enter your choice (1-3)"
        }
        switch ($choice)
        {
            '1'
            {
                Write-Verbose "[$functionName] User chose to replace existing values"
                Write-Log -LogFile $logFile -Module $functionName -Message "User chose to replace existing values" -LogLevel "Information"
                $shouldReplaceExisting = $true
            }
            '2'
            {
                Write-Verbose "[$functionName] User chose to add new values to existing ones"
                Write-Log -LogFile $logFile -Module $functionName -Message "User chose to add new values to existing ones" -LogLevel "Information"
                $shouldReplaceExisting = $false
            }
            '3'
            {
                Write-Verbose "[$functionName] User chose to keep current values unchanged"
                Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current values unchanged" -LogLevel "Information"
                return $CurrentValue
            }
        }
    }
    
    Write-Host "`nEnter new values (one per line). Press Enter on empty line to finish:" -ForegroundColor Yellow
    if (-not $shouldReplaceExisting)
    {
        Write-Host "New values will be added to the existing ones." -ForegroundColor Green
    }
    Write-Host "Leave first line empty to cancel." -ForegroundColor Gray
    
    $newValues = @()
    $firstInput = $true
    
    do
    {
        if ($firstInput)
        {
            $input = Read-Host "Value"
            $firstInput = $false
            
            # If first input is empty, return current values
            if ([string]::IsNullOrWhiteSpace($input))
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "User cancelled input, keeping current array values" -LogLevel "Verbose"
                Write-Verbose "[$functionName] User cancelled input, keeping current array values"
                return $CurrentValue
            }
            
            $newValues += $input
            Write-Log -LogFile $logFile -Module $functionName -Message "Added first array value: '$input'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Added first array value: '$input'"
        }
        else
        {
            $input = Read-Host "Value"
            if ([string]::IsNullOrWhiteSpace($input))
            {
                break
            }
            $newValues += $input
            Write-Log -LogFile $logFile -Module $functionName -Message "Added array value: '$input'" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Added array value: '$input'"
        }
    } while ($true)
    
    # Determine final result based on user choice
    if ($shouldReplaceExisting -or -not $CurrentValue -or $CurrentValue.Count -eq 0)
    {
        # Replace existing values or no existing values
        $result = $newValues
    }
    else
    {
        # Add to existing values
        $result = @($CurrentValue) + @($newValues)
    }
    
    # Ensure single values are still treated as arrays
    if ($result.Count -eq 1)
    {
        # Force single element to remain as array 
        $result = @($result[0])
        Write-Log -LogFile $logFile -Module $functionName -Message "Single value converted to array to maintain type consistency" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Single value converted to array to maintain type consistency"
    }
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Returning array with $($result.Count) values" -LogLevel "Information"
    Write-Verbose "[$functionName] Returning array with $($result.Count) values"
    return $result
}

function Get-NumberInput()
{
    <#
    .SYNOPSIS
        Gets numeric input with validation.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingName,
        $CurrentValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting numeric input for '$SettingName'. Current value: $CurrentValue"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting numeric input for '$SettingName'. Current value: $CurrentValue" -LogLevel "Verbose"
    
    do
    {
        $input = Read-Host "Enter number (current: $CurrentValue, press Enter to keep)"
        
        if ([string]::IsNullOrWhiteSpace($input))
        {
            Write-Verbose "[$functionName] User chose to keep current numeric value: $CurrentValue"
            Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current numeric value: $CurrentValue" -LogLevel "Verbose"
            return $CurrentValue
        }
        
        if ($input -match '^\d+$')
        {
            $number = [int]$input
            Write-Verbose "[$functionName] Valid numeric input received: $number"
            Write-Log -LogFile $logFile -Module $functionName -Message "Valid numeric input received: $number" -LogLevel "Verbose"
            
            # Add specific validation for certain settings
            if ($SettingName -eq 'minUsernameLength' -and $number -lt 1)
            {
                Write-Host "Minimum username length must be at least 1." -ForegroundColor Red
                Write-Verbose "[$functionName] Validation failed: minimum username length must be at least 1"
                Write-Log -LogFile $logFile -Module $functionName -Message "Validation failed: minimum username length must be at least 1" -LogLevel "Warning"
                continue
            }
            
            if ($SettingName -eq 'maxWaitTime' -and $number -lt 1)
            {
                Write-Host "Maximum wait time must be at least 1 second." -ForegroundColor Red
                Write-Verbose "[$functionName] Validation failed: maximum wait time must be at least 1 second"
                Write-Log -LogFile $logFile -Module $functionName -Message "Validation failed: maximum wait time must be at least 1 second" -LogLevel "Warning"
                continue
            }
            
            Write-Verbose "[$functionName] Numeric validation passed, returning: $number"
            Write-Log -LogFile $logFile -Module $functionName -Message "Numeric validation passed, returning: $number" -LogLevel "Information"
            return $number
        }
        
        Write-Host "Please enter a valid number." -ForegroundColor Red
        Write-Verbose "[$functionName] Invalid numeric input: '$input'"
        Write-Log -LogFile $logFile -Module $functionName -Message "Invalid numeric input: '$input'" -LogLevel "Warning"
    } while ($true)
}

function Get-StringInput()
{
    <#
    .SYNOPSIS
        Gets string input from user.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingName,
        $CurrentValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting string input for '$SettingName'. Current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting string input for '$SettingName'. Current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $input = Read-Host "Enter value (current: '$CurrentValue', press Enter to keep)"
    
    if ([string]::IsNullOrWhiteSpace($input))
    {
        Write-Verbose "[$functionName] User chose to keep current string value: '$CurrentValue'"
        Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current string value: '$CurrentValue'" -LogLevel "Verbose"
        return $CurrentValue
    }
    
    Write-Verbose "[$functionName] User entered new string value: '$input'"
    Write-Log -LogFile $logFile -Module $functionName -Message "User entered new string value: '$input'" -LogLevel "Information"
    return $input
}

function Save-GlobalSettings()
{
    <#
    .SYNOPSIS
        Saves global settings using unified Update-Setting function with support for nested settings.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Settings,
        [string]$SettingsFile
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Saving global settings to file: '$SettingsFile'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Saving global settings to file: '$SettingsFile'" -LogLevel "Information"
    
    try
    {
        foreach ($key in $Settings.Keys)
        {
            $value = $Settings[$key]
            Write-Verbose "[$functionName] Updating global setting: $key = $value"
            Write-Log -LogFile $logFile -Module $functionName -Message "Updating global setting: $key = $value" -LogLevel "Verbose"
            
            # Handle nested settings (e.g., repoInfo.repoPath)
            if ($key.Contains('.'))
            {
                $success = Update-NestedSetting -SettingType "Global" -SettingsFile $SettingsFile -SettingPath $key -SettingValue $value
            }
            else
            {
                $success = Update-Setting -SettingType "Global" -SettingsFile $SettingsFile -SettingName $key -SettingValue $value
            }
            
            if (-not $success)
            {
                Write-Warning "[$functionName] Failed to update global setting: $key"
                Write-Verbose "[$functionName] Failed to update global setting: $key"
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update global setting: $key" -LogLevel "Error"
                return $false
            }
        }
        Write-Verbose "[$functionName] All global settings saved successfully"
        Write-Log -LogFile $logFile -Module $functionName -Message "All global settings saved successfully" -LogLevel "Information"
        return $true
    }
    catch
    {
        Write-Warning "[$functionName] Error saving global settings: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error saving global settings: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $functionName -Message "Error saving global settings: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
}

function Get-AuthTypeInput()
{
    [CmdletBinding()]
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting authentication type input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting authentication type input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $authTypes = @('PublicAuthFlow', 'PrivateAuthFlow', 'Interactive', 'Device')
    return Get-EnumeratedInput -Options $authTypes -CurrentValue $CurrentValue -PromptText "authentication type"
}

function Save-AuthSettings()
{
    <#
    .SYNOPSIS
        Saves auth settings using unified Update-Setting function.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Settings,
        [string]$SettingsFile
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Saving auth settings to: $SettingsFile"
    Write-Log -LogFile $logFile -Module $functionName -Message "Saving auth settings to: $SettingsFile" -LogLevel "Information"
    
    try
    {
        # Check for settings that require client secret and warn user
        $requiresClientSecret = $false
        $warningMessages = @()
        
        if ($Settings.ContainsKey('delegated') -and $Settings['delegated'] -eq $false)
        {
            $requiresClientSecret = $true
            $warningMessages += "Setting 'delegated' to false requires application permissions"
        }
        
        if ($Settings.ContainsKey('authType') -and $Settings['authType'] -ne 'PublicAuthFlow')
        {
            $requiresClientSecret = $true
            $warningMessages += "Authentication type '$($Settings['authType'])' requires client credentials"
        }
        
        if ($requiresClientSecret)
        {
            Write-Host "`nWARNING: Advanced Authentication Configuration" -ForegroundColor Yellow
            Write-Host "=========================================" -ForegroundColor Yellow
            foreach ($msg in $warningMessages)
            {
                Write-Host "• $msg" -ForegroundColor Yellow
            }
            Write-Host "`nThese settings require a client secret to be stored in your configuration file." -ForegroundColor Red
            Write-Host "Please ensure you have properly configured client credentials before using these settings." -ForegroundColor Red
            Write-Host "This is an advanced configuration - proceed only if you understand the implications.`n" -ForegroundColor Yellow
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Warning displayed for advanced auth configuration requiring client secret" -LogLevel "Warning"
        }
        
        foreach ($key in $Settings.Keys)
        {
            Write-Verbose "[$functionName] Updating auth setting: $key = $($Settings[$key])"
            Write-Log -LogFile $logFile -Module $functionName -Message "Updating auth setting: $key = $($Settings[$key])" -LogLevel "Verbose"
            
            # Handle nested settings (e.g., nested.property)
            if ($key.Contains('.'))
            {
                $success = Update-NestedSetting -SettingType "Auth" -SettingsFile $SettingsFile -SettingPath $key -SettingValue $Settings[$key]
            }
            else
            {
                $success = Update-Setting -SettingType "Auth" -SettingsFile $SettingsFile -SettingName $key -SettingValue $Settings[$key]
            }
            
            if (-not $success)
            {
                Write-Warning "[$functionName] Failed to update auth setting: $key"
                Write-Verbose "[$functionName] Failed to update auth setting: $key"
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to update auth setting: $key" -LogLevel "Error"
                return $false
            }
            Write-Verbose "[$functionName] Successfully updated auth setting: $key = $($Settings[$key])"
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully updated auth setting: $key = $($Settings[$key])" -LogLevel "Verbose"
        }
        Write-Verbose "[$functionName] All auth settings saved successfully"
        Write-Log -LogFile $logFile -Module $functionName -Message "All auth settings saved successfully" -LogLevel "Information"
        return $true
    }
    catch
    {
        Write-Warning "[$functionName] Error saving auth settings: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error saving auth settings: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $functionName -Message "Error saving auth settings: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
}

function Save-DomainSettings()
{
    <#
    .SYNOPSIS
        Saves domain settings using unified Update-Setting function.
    #>
    [CmdletBinding()]
    param(
        [string]$DomainName,
        [hashtable]$Settings,
        [string]$SettingsFile
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Saving domain settings for domain: '$DomainName' to file: '$SettingsFile'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Saving domain settings for domain: '$DomainName' to file: '$SettingsFile'" -LogLevel "Information"
    
    try
    {
        $success = Update-Setting -SettingType "Domain" -SettingsFile $SettingsFile -DomainName $DomainName -Settings $Settings -MergeSettings
        if ($success)
        {
            Write-Verbose "[$functionName] Domain settings saved successfully"
            Write-Log -LogFile $logFile -Module $functionName -Message "Domain settings saved successfully" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] Failed to save domain settings"
            Write-Log -LogFile $logFile -Module $functionName -Message "Failed to save domain settings" -LogLevel "Error"
        }
        return $success
    }
    catch
    {
        Write-Warning "[$functionName] Error saving domain settings: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error saving domain settings: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $functionName -Message "Error saving domain settings: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
}
function Update-NestedSetting()
{
    <#
    .SYNOPSIS
        Updates a nested setting using dot notation path.
        
    .DESCRIPTION
        Handles updating nested settings like 'repoInfo.repoPath' by parsing the path
        and updating the appropriate nested structure in the configuration.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingType,
        [string]$SettingsFile,
        [string]$SettingPath,
        $SettingValue,
        [string]$DomainName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating nested setting: $SettingPath = $SettingValue (Type: $SettingType)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Updating nested setting: $SettingPath = $SettingValue (Type: $SettingType)" -LogLevel "Information"
    
    try
    {
        # Load current settings
        if (-not (Test-Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        
        # Parse the setting path
        $pathParts = $SettingPath.Split('.')
        $currentLevel = $null
        
        # Navigate to the correct section based on setting type
        switch ($SettingType)
        {
            'Global'
            {
                if (-not $settings.globalSettings)
                {
                    $settings | Add-Member -MemberType NoteProperty -Name "globalSettings" -Value (New-Object PSObject)
                }
                $currentLevel = $settings.globalSettings
            }
            'Auth'
            {
                if (-not $settings.auth)
                {
                    $settings | Add-Member -MemberType NoteProperty -Name "auth" -Value (New-Object PSObject)
                }
                $currentLevel = $settings.auth
            }
            'Domain'
            {
                # For domain settings, we need to work with separate domain files
                Write-Warning "[$functionName] Domain nested settings not yet implemented for path-based updates"
                return $false
            }
            default
            {
                Write-Warning "[$functionName] Unknown setting type: $SettingType"
                return $false
            }
        }
        
        # Navigate through the path, creating objects as needed
        for ($i = 0; $i -lt $pathParts.Count - 1; $i++)
        {
            $part = $pathParts[$i]
            
            if (-not ($currentLevel.PSObject.Properties.Name -contains $part))
            {
                $currentLevel | Add-Member -MemberType NoteProperty -Name $part -Value (New-Object PSObject)
            }
            $currentLevel = $currentLevel.$part
        }
        
        # Set the final value
        $finalProperty = $pathParts[-1]
        if ($currentLevel.PSObject.Properties.Name -contains $finalProperty)
        {
            $currentLevel.$finalProperty = $SettingValue
        }
        else
        {
            $currentLevel | Add-Member -MemberType NoteProperty -Name $finalProperty -Value $SettingValue
        }
        
        # Save the updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
        
        Write-Verbose "[$functionName] Successfully updated nested setting: $SettingPath"
        Write-Log -LogFile $logFile -Module $functionName -Message "Successfully updated nested setting: $SettingPath" -LogLevel "Information"
        return $true
    }
    catch
    {
        Write-Warning "[$functionName] Error updating nested setting ${SettingPath}: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Module $functionName -Message "Error updating nested setting ${SettingPath}: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
}
