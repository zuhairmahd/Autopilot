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
        Retrieves the default settings structure from Test-SettingsJsonExists.
    #>
    $functionName = $MyInvocation.MyCommand.Name
    $logFile = "$PWD\Logs\Autopilot.log"
    
    Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving default settings structure" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Retrieving default settings structure"
    
    try
    {
        # Call Test-SettingsJsonExists to get the default structure
        # We'll extract the $defaultSettings variable from that function
        $tempFile = [System.IO.Path]::GetTempFileName()
        Write-Log -LogFile $logFile -Module $functionName -Message "Created temporary file: $tempFile" -LogLevel "Debug"
        Write-Verbose "[$functionName] Created temporary file: $tempFile"
        
        # Create a temporary settings file to trigger the default creation
        if (Test-SettingsJsonExists -SettingsFile $tempFile -Silent)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Successfully created default settings in temp file" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Successfully created default settings in temp file"
            $content = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            Write-Log -LogFile $logFile -Module $functionName -Message "Default settings structure retrieved successfully" -LogLevel "Information"
            Write-Verbose "[$functionName] Default settings structure retrieved successfully"
            return $content
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Failed to create default settings" -LogLevel "Warning"
        Write-Verbose "[$functionName] Failed to create default settings"
        return $null
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error getting default settings structure: $($_.Exception.Message)" -LogLevel "Error"
        Write-Verbose "Error getting default settings structure: $($_.Exception.Message)"
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
        return $descriptions[$SettingName]
    }
    else
    {
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
    
    # Determine the type of input needed
    $inputType = Get-SettingInputType -SettingName $SettingName -Value $DefaultValue
    
    switch ($inputType)
    {
        'Boolean'
        {
            return Get-BooleanInput -CurrentValue $CurrentValue
        }
        'AppMode'
        {
            return Get-AppModeInput -CurrentValue $CurrentValue
        }
        'CacheType'
        {
            return Get-CacheTypeInput -CurrentValue $CurrentValue
        }
        'Repo'
        {
            return Get-RepoInput -CurrentValue $CurrentValue
        }
        'OperatingSystem'
        {
            return Get-OperatingSystemInput -CurrentValue $CurrentValue
        }
        'Browser'
        {
            return Get-BrowserInput -CurrentValue $CurrentValue
        }
        'AuthType'
        {
            return Get-AuthTypeInput -CurrentValue $CurrentValue
        }
        'Array'
        {
            return Get-ArrayInput -CurrentValue $CurrentValue
        }
        'Number'
        {
            return Get-NumberInput -SettingName $SettingName -CurrentValue $CurrentValue
        }
        default
        {
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
    
    # Check for specific known enumerated types
    if ($SettingName -eq 'appMode') { return 'AppMode' }
    if ($SettingName -eq 'cacheType') { return 'CacheType' }
    if ($SettingName -eq 'repo') { return 'Repo' }
    if ($SettingName -eq 'operatingSystem') { return 'OperatingSystem' }
    if ($SettingName -eq 'preferredBrowser') { return 'Browser' }
    if ($SettingName -eq 'authType') { return 'AuthType' }
    
    # Check by value type
    if ($Value -is [bool]) { return 'Boolean' }
    if ($Value -is [array]) { return 'Array' }
    if ($Value -match '^\d+$') { return 'Number' }
    
    return 'String'
}

function Get-BooleanInput()
{
    <#
    .SYNOPSIS
        Gets boolean input from user with menu.
    #>
    param($CurrentValue)
    
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
            return $CurrentValue
        }
        
        switch ($choice)
        {
            '1' { return $true }
            '2' { return $false }
            default
            {
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
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
            return $CurrentValue
        }
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $modes.Count)
        {
            return $modes[[int]$choice - 1]
        }
        
        Write-Host "Invalid choice. Please enter a number between 1 and $($modes.Count)." -ForegroundColor Red
    } while ($true)
}

function Get-CacheTypeInput()
{
    param($CurrentValue)
    
    $types = @('Memory', 'File')
    return Get-EnumeratedInput -Options $types -CurrentValue $CurrentValue -PromptText "cache type"
}

function Get-RepoInput()
{
    param($CurrentValue)
    
    $repos = @('Github', 'Gitlab')
    return Get-EnumeratedInput -Options $repos -CurrentValue $CurrentValue -PromptText "repository"
}

function Get-OperatingSystemInput()
{
    param($CurrentValue)
    
    $systems = @('Windows', 'macOS', 'Linux')
    return Get-EnumeratedInput -Options $systems -CurrentValue $CurrentValue -PromptText "operating system"
}

function Get-BrowserInput()
{
    param($CurrentValue)
    
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
            return $CurrentValue
        }
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $Options.Count)
        {
            return $Options[[int]$choice - 1]
        }
        
        Write-Host "Invalid choice. Please enter a number between 1 and $($Options.Count)." -ForegroundColor Red
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
    
    do
    {
        $input = Read-Host "Enter number (current: $CurrentValue, press Enter to keep)"
        
        if ([string]::IsNullOrWhiteSpace($input))
        {
            return $CurrentValue
        }
        
        if ($input -match '^\d+$')
        {
            $number = [int]$input
            
            # Add specific validation for certain settings
            if ($SettingName -eq 'minUsernameLength' -and $number -lt 1)
            {
                Write-Host "Minimum username length must be at least 1." -ForegroundColor Red
                continue
            }
            
            if ($SettingName -eq 'maxWaitTime' -and $number -lt 1)
            {
                Write-Host "Maximum wait time must be at least 1 second." -ForegroundColor Red
                continue
            }
            
            return $number
        }
        
        Write-Host "Please enter a valid number." -ForegroundColor Red
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
    
    $input = Read-Host "Enter value (current: '$CurrentValue', press Enter to keep)"
    
    if ([string]::IsNullOrWhiteSpace($input))
    {
        return $CurrentValue
    }
    
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
    
    try
    {
        foreach ($key in $Settings.Keys)
        {
            $success = Update-GlobalSetting -SettingsFile $SettingsFile -SettingName $key -SettingValue $Settings[$key]
            if (-not $success)
            {
                Write-Warning "Failed to update global setting: $key"
                return $false
            }
        }
        return $true
    }
    catch
    {
        Write-Warning "Error saving global settings: $($_.Exception.Message)"
        return $false
    }
}

function Get-AuthTypeInput()
{
    param($CurrentValue)
    
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
    
    try
    {
        foreach ($key in $Settings.Keys)
        {
            $success = Update-AuthSetting -SettingsFile $SettingsFile -SettingName $key -SettingValue $Settings[$key]
            if (-not $success)
            {
                Write-Warning "[$functionName] Failed to update auth setting: $key"
                return $false
            }
            Write-Verbose "[$functionName] Updated auth setting: $key = $($Settings[$key])"
        }
        return $true
    }
    catch
    {
        Write-Warning "[$functionName] Error saving auth settings: $($_.Exception.Message)"
        return $false
    }
}
{
    <#
    .SYNOPSIS
        Saves domain settings using existing Update-DomainSettings function.
    #>
    param(
        [string]$DomainName,
        [hashtable]$Settings,
        [string]$SettingsFile
    )
    
    try
    {
        $success = Update-DomainSettings -SettingsFile $SettingsFile -DomainName $DomainName -Settings $Settings -MergeSettings
        return $success
    }
    catch
    {
        Write-Warning "Error saving domain settings: $($_.Exception.Message)"
        return $false
    }
}