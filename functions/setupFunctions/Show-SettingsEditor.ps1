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
        - Uses existing Update-GlobalSetting, Update-DomainSettings, and Update-AuthSetting functions
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
    
    if ($SettingsType -eq 'Domain')
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Domain name provided: '$DomainName'" -LogLevel "Information"
        Write-Verbose "[$functionName] Domain name provided: '$DomainName'"
    }
    
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
            $settingsTemplate = $defaultSettings.domains.PSObject.Properties | Select-Object -First 1 | ForEach-Object { $_.Value.settings }
            $currentValues = $currentSettings.domains.$DomainName.settings
            Write-Log -LogFile $logFile -Module $functionName -Message "Editing domain settings for domain: '$DomainName'" -LogLevel "Information"
            Write-Verbose "[$functionName] Editing domain settings for domain: '$DomainName'"
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
        
        # Process each setting in the template
        if ($settingsTemplate -is [hashtable])
        {
            # Handle hashtable (auth settings)
            foreach ($settingName in $settingsTemplate.Keys)
            {
                $defaultValue = $settingsTemplate[$settingName]
                $currentValue = if ($currentValues.PSObject.Properties.Name -contains $settingName) { $currentValues.$settingName } else { $defaultValue }
                
                Write-Log -LogFile $logFile -Module $functionName -Message "Processing setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Processing setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'"
                
                if (-not $Silent)
                {
                    Write-Host "Setting: $settingName" -ForegroundColor Yellow
                    Write-Host "Description: $(Get-SettingDescription -SettingName $settingName)" -ForegroundColor Gray
                    Write-Host "Current value: $currentValue" -ForegroundColor Cyan
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
                    $updatedSettings[$settingName] = $newValue
                    $hasChanges = $true
                    Write-Log -LogFile $logFile -Module $functionName -Message "Setting '$settingName' changed from '$currentValue' to '$newValue'" -LogLevel "Information"
                    Write-Verbose "[$functionName] Setting '$settingName' changed from '$currentValue' to '$newValue'"
                    if (-not $Silent)
                    {
                        Write-Host "Updated to: $newValue" -ForegroundColor Green
                    }
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Setting '$settingName' unchanged (value: '$currentValue')" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Setting '$settingName' unchanged (value: '$currentValue')"
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
        }
        else
        {
            # Handle PSCustomObject (global and domain settings)
            foreach ($setting in $settingsTemplate.PSObject.Properties)
            {
                $settingName = $setting.Name
                $defaultValue = $setting.Value
                $currentValue = if ($currentValues.PSObject.Properties.Name -contains $settingName) { $currentValues.$settingName } else { $defaultValue }
                
                Write-Log -LogFile $logFile -Module $functionName -Message "Processing setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Processing setting: '$settingName', Current: '$currentValue', Default: '$defaultValue'"
                
                if (-not $Silent)
                {
                    Write-Host "Setting: $settingName" -ForegroundColor Yellow
                    Write-Host "Description: $(Get-SettingDescription -SettingName $settingName)" -ForegroundColor Gray
                    Write-Host "Current value: $currentValue" -ForegroundColor Cyan
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
                    $updatedSettings[$settingName] = $newValue
                    $hasChanges = $true
                    Write-Log -LogFile $logFile -Module $functionName -Message "Setting '$settingName' changed from '$currentValue' to '$newValue'" -LogLevel "Information"
                    Write-Verbose "[$functionName] Setting '$settingName' changed from '$currentValue' to '$newValue'"
                    if (-not $Silent)
                    {
                        Write-Host "Updated to: $newValue" -ForegroundColor Green
                    }
                }
                else
                {
                    Write-Log -LogFile $logFile -Module $functionName -Message "Setting '$settingName' unchanged (value: '$currentValue')" -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Setting '$settingName' unchanged (value: '$currentValue')"
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
        Retrieves the default settings structure efficiently without file operations.
    #>
    $functionName = $MyInvocation.MyCommand.Name
    $logFile = "$PWD\Logs\Autopilot.log"
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving default settings structure using cached defaults" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Retrieving default settings structure using cached defaults"
    
    try
    {
        # Instead of creating a temporary file and calling Test-SettingsJsonExists,
        # directly create the default structure here to avoid unnecessary file operations
        Write-Log -LogFile $logFile -Module $functionName -Message "Creating default structure without file operations" -LogLevel "Debug"
        Write-Verbose "[$functionName] Creating default structure without file operations"
        
        $defaultSettings = @{
            description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
            version        = "1.3.0.0"
            auth           = @{
                delegated           = $true
                authType            = "PublicAuthFlow"
                changePwOnNextStart = $false
                renewalLeadTime     = 5
                noSaveRefreshToken  = $false
                secureString        = $false
                forceNewToken       = $false
                cacheType           = "Memory"
                scope               = @(
                    "offline_access",
                    "openid", 
                    "Device.ReadWrite.All",
                    "DeviceManagementApps.Read.All",
                    "DeviceManagementConfiguration.ReadWrite.All",
                    "DeviceManagementManagedDevices.PrivilegedOperations.All",
                    "DeviceManagementManagedDevices.ReadWrite.All",
                    "DeviceManagementServiceConfig.ReadWrite.All"
                )
            }
            globalSettings = @{
                configFile                       = ".\\.secrets\\config.json"
                maxWaitTime                      = "30"
                showLicenseBanner                = $true
                deviceContactThresholdInDays     = 30
                appMode                          = "full"
                timeInSeconds                    = "60"
                maxUserMatchDisplay              = "10"
                release                          = "master"
                repo                             = "Github"
                testMode                         = $false
                operatingSystem                  = "Windows"
                autoUpdate                       = $true
            }
            domains        = @{
                "example.com" = @{
                    groupsToInclude = @()
                    groupsToExclude = @()
                    settings        = @{
                        domain                          = "example.com"
                        maxWaitTime                     = "30"
                        showLicenseBanner               = $true
                        deviceContactThresholdInDays    = 30
                        appMode                         = "full"
                        timeInSeconds                   = "60"
                        maxUserMatchDisplay             = "10"
                        release                         = "master"
                        repo                            = "Github"
                        autoUpdate                      = $true
                        deviceNamePrefix                = ""
                        operatingSystem                 = "Windows"
                        minUsernameLength               = 3
                        maxUserNameLength               = 50
                        maxSerialNumberLength           = 50
                        minSerialNumberLength           = 7
                        minimumDevicePhysicalMemoryInGB = 8
                        maxNumberOfDevicesAllowed       = 15
                        preferredBrowser                = "Chrome"
                        privateSession                  = $false
                        userPatternsToExclude           = @( 
                            "-test",
                            "onmicrosoft.com"
                        )
                        desiredAutopilotProfiles        = @()
                    }
                }
            }
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Default settings structure created successfully" -LogLevel "Information"
        Write-Verbose "[$functionName] Default settings structure created successfully"
        
        # Convert to PSCustomObject to match the JSON structure behavior
        $jsonString = $defaultSettings | ConvertTo-Json -Depth 10
        $defaultStructure = $jsonString | ConvertFrom-Json
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Default settings structure converted to PSCustomObject format" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Default settings structure converted to PSCustomObject format"
        
        return $defaultStructure
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error creating default settings structure: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error creating default settings structure: $($_.Exception.Message)"
        return $null
    }
}

function Get-CurrentSettings()
{
    <#
    .SYNOPSIS
        Loads current settings from the settings file.
    #>
    param(
        [string]$SettingsFile,
        [string]$SettingsType,
        [string]$DomainName
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $logFile = "$PWD\Logs\Autopilot.log"
    
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

function Get-SettingDescription()
{
    <#
    .SYNOPSIS
        Returns a user-friendly description for a setting.
    #>
    param([string]$SettingName)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting description for setting: '$SettingName'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting description for setting: '$SettingName'" -LogLevel "Verbose"
    
    $descriptions = @{
        'configFile'                      = 'Path to the configuration file storing encrypted authentication data'
        'maxWaitTime'                     = 'Maximum time in seconds to wait for operations to complete'
        'showLicenseBanner'               = 'Whether to display the license banner on startup'
        'deviceContactThresholdInDays'    = 'Number of days before a device is considered stale'
        'appMode'                         = 'Application mode controlling which features are available'
        'timeInSeconds'                   = 'Default timeout for operations in seconds'
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
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Determining input type for setting '$SettingName' with value type: $($Value.GetType().Name)"
    Write-Log -LogFile $logFile -Module $functionName -Message "Determining input type for setting '$SettingName' with value type: $($Value.GetType().Name)" -LogLevel "Verbose"
    
    # Check for specific known enumerated types
    if ($SettingName -eq 'appMode') { 
        Write-Verbose "[$functionName] Detected AppMode setting"
        return 'AppMode' 
    }
    if ($SettingName -eq 'cacheType') { 
        Write-Verbose "[$functionName] Detected CacheType setting"
        return 'CacheType' 
    }
    if ($SettingName -eq 'repo') { 
        Write-Verbose "[$functionName] Detected Repo setting"
        return 'Repo' 
    }
    if ($SettingName -eq 'operatingSystem') { 
        Write-Verbose "[$functionName] Detected OperatingSystem setting"
        return 'OperatingSystem' 
    }
    if ($SettingName -eq 'preferredBrowser') { 
        Write-Verbose "[$functionName] Detected Browser setting"
        return 'Browser' 
    }
    if ($SettingName -eq 'authType') { 
        Write-Verbose "[$functionName] Detected AuthType setting"
        return 'AuthType' 
    }
    
    # Check by value type
    if ($Value -is [bool]) { 
        Write-Verbose "[$functionName] Detected Boolean value type"
        return 'Boolean' 
    }
    if ($Value -is [array]) { 
        Write-Verbose "[$functionName] Detected Array value type"
        return 'Array' 
    }
    if ($Value -match '^\d+$') { 
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
            '1' { 
                Write-Verbose "[$functionName] User selected: True"
                Write-Log -LogFile $logFile -Module $functionName -Message "User selected: True" -LogLevel "Information"
                return $true 
            }
            '2' { 
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
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting repository input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting repository input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $repos = @('Github', 'Gitlab')
    return Get-EnumeratedInput -Options $repos -CurrentValue $CurrentValue -PromptText "repository"
}

function Get-OperatingSystemInput()
{
    param($CurrentValue)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting operating system input for current value: '$CurrentValue'"
    Write-Log -LogFile $logFile -Module $functionName -Message "Getting operating system input for current value: '$CurrentValue'" -LogLevel "Verbose"
    
    $systems = @('Windows', 'macOS', 'Linux')
    return Get-EnumeratedInput -Options $systems -CurrentValue $CurrentValue -PromptText "operating system"
}

function Get-BrowserInput()
{
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
            Write-Verbose "[$functionName] User selected option $choice: '$selectedValue'"
            Write-Log -LogFile $logFile -Module $functionName -Message "User selected option $choice: '$selectedValue'" -LogLevel "Information"
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
    
    Write-Host "`nEnter new values (one per line). Press Enter on empty line to finish:" -ForegroundColor Yellow
    Write-Host "Leave first line empty to keep current values." -ForegroundColor Gray
    
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
                Write-Log -LogFile $logFile -Module $functionName -Message "User chose to keep current array values" -LogLevel "Verbose"
                Write-Verbose "[$functionName] User chose to keep current array values"
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
    
    # Ensure single values are still treated as arrays
    if ($newValues.Count -eq 1)
    {
        $result = @($newValues[0])
        Write-Log -LogFile $logFile -Module $functionName -Message "Single value converted to array to maintain type consistency" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Single value converted to array to maintain type consistency"
    }
    else
    {
        $result = $newValues
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
        Saves global settings using existing Update-GlobalSetting function.
    #>
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
            Write-Verbose "[$functionName] Updating global setting: $key = $($Settings[$key])"
            Write-Log -LogFile $logFile -Module $functionName -Message "Updating global setting: $key = $($Settings[$key])" -LogLevel "Verbose"
            
            $success = Update-GlobalSetting -SettingsFile $SettingsFile -SettingName $key -SettingValue $Settings[$key]
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
        Saves auth settings using existing Update-AuthSetting function.
    #>
    param(
        [hashtable]$Settings,
        [string]$SettingsFile
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Saving auth settings to: $SettingsFile"
    Write-Log -LogFile $logFile -Module $functionName -Message "Saving auth settings to: $SettingsFile" -LogLevel "Information"
    
    try
    {
        foreach ($key in $Settings.Keys)
        {
            Write-Verbose "[$functionName] Updating auth setting: $key = $($Settings[$key])"
            Write-Log -LogFile $logFile -Module $functionName -Message "Updating auth setting: $key = $($Settings[$key])" -LogLevel "Verbose"
            
            $success = Update-AuthSetting -SettingsFile $SettingsFile -SettingName $key -SettingValue $Settings[$key]
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
        Saves domain settings using existing Update-DomainSettings function.
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
        $success = Update-DomainSettings -SettingsFile $SettingsFile -DomainName $DomainName -Settings $Settings -MergeSettings
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