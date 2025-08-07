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
        Specifies whether to edit 'Global' or 'Domain' settings.
    
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
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses existing Update-GlobalSetting and Update-DomainSettings functions
        - Leverages Test-SettingsJsonExists for default settings structure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Domain')]
        [string]$SettingsType,
        
        [string]$SettingsFile = "settings.json",
        
        [string]$DomainName,
        
        [switch]$Silent,
        
        [hashtable]$PresetValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting settings editor for $SettingsType settings"
    
    try
    {
        # Validate parameters
        if ($SettingsType -eq 'Domain' -and [string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Warning "[$functionName] DomainName is required when editing Domain settings"
            return $false
        }
        
        # Get default settings structure from Test-SettingsJsonExists
        $defaultSettings = Get-DefaultSettingsStructure
        if (-not $defaultSettings)
        {
            Write-Warning "[$functionName] Failed to get default settings structure"
            return $false
        }
        
        # Load current settings
        $currentSettings = Get-CurrentSettings -SettingsFile $SettingsFile -SettingsType $SettingsType -DomainName $DomainName
        if (-not $currentSettings)
        {
            Write-Warning "[$functionName] Failed to load current settings"
            return $false
        }
        
        # Get settings template to edit
        if ($SettingsType -eq 'Global')
        {
            $settingsTemplate = $defaultSettings.globalSettings
            $currentValues = $currentSettings.globalSettings
        if (-not $Silent)
        {
            Write-Host "`n── Global Settings Editor ──" -ForegroundColor Cyan
            Write-Host "Modify global application settings that apply to all domains." -ForegroundColor White
        }
        }
        else
        {
            $settingsTemplate = $defaultSettings.domains.PSObject.Properties | Select-Object -First 1 | ForEach-Object { $_.Value.settings }
            $currentValues = $currentSettings.domains.$DomainName.settings
            if (-not $Silent)
            {
                Write-Host "`n── Domain Settings Editor ──" -ForegroundColor Cyan
                Write-Host "Modify settings specific to domain: $DomainName" -ForegroundColor White
            }
        }
        
        if (-not $settingsTemplate)
        {
            Write-Warning "[$functionName] No settings template found for $SettingsType"
            return $false
        }
        
        Write-Host ""
        $updatedSettings = @{}
        $hasChanges = $false
        
        # Process each setting in the template
        foreach ($setting in $settingsTemplate.PSObject.Properties)
        {
            $settingName = $setting.Name
            $defaultValue = $setting.Value
            $currentValue = if ($currentValues.PSObject.Properties.Name -contains $settingName) { $currentValues.$settingName } else { $defaultValue }
            
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
                if (-not $Silent)
                {
                    Write-Host "Updated to: $newValue" -ForegroundColor Green
                }
            }
            else
            {
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
            if (-not $Silent)
            {
                Write-Host "Saving changes..." -ForegroundColor Yellow
            }
            
            $success = if ($SettingsType -eq 'Global')
            {
                Save-GlobalSettings -Settings $updatedSettings -SettingsFile $SettingsFile
            }
            else
            {
                Save-DomainSettings -DomainName $DomainName -Settings $updatedSettings -SettingsFile $SettingsFile
            }
            
            if ($success)
            {
                if (-not $Silent)
                {
                    Write-Host "Settings saved successfully!" -ForegroundColor Green
                }
                return $true
            }
            else
            {
                if (-not $Silent)
                {
                    Write-Host "Failed to save settings!" -ForegroundColor Red
                }
                return $false
            }
        }
        else
        {
            if (-not $Silent)
            {
                Write-Host "No changes were made." -ForegroundColor Yellow
            }
            return $true
        }
    }
    catch
    {
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
    try
    {
        # Call Test-SettingsJsonExists to get the default structure
        # We'll extract the $defaultSettings variable from that function
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # Create a temporary settings file to trigger the default creation
        if (Test-SettingsJsonExists -SettingsFile $tempFile -Silent)
        {
            $content = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            return $content
        }
        
        return $null
    }
    catch
    {
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
    
    try
    {
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Verbose "Settings file not found, creating with defaults"
            if (-not (Test-SettingsJsonExists -SettingsFile $SettingsFile -Silent))
            {
                return $null
            }
        }
        
        $content = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
        return $content
    }
    catch
    {
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
        'configFile' = 'Path to the configuration file storing encrypted authentication data'
        'maxWaitTime' = 'Maximum time in seconds to wait for operations to complete'
        'showLicenseBanner' = 'Whether to display the license banner on startup'
        'deviceContactThresholdInDays' = 'Number of days before a device is considered stale'
        'appMode' = 'Application mode controlling which features are available'
        'timeInSeconds' = 'Default timeout for operations in seconds'
        'maxUserMatchDisplay' = 'Maximum number of user matches to display in search results'
        'release' = 'Release branch or version to track for updates'
        'repo' = 'Repository source for updates (Github/Gitlab)'
        'testMode' = 'Enable test mode with additional debugging features'
        'operatingSystem' = 'Target operating system (Windows/macOS/Linux)'
        'autoUpdate' = 'Automatically check for and install updates'
        'domain' = 'Domain name for this configuration'
        'deviceNamePrefix' = 'Prefix to add to device names during enrollment'
        'minUsernameLength' = 'Minimum allowed username length'
        'maxUserNameLength' = 'Maximum allowed username length'
        'maxSerialNumberLength' = 'Maximum allowed serial number length'
        'minSerialNumberLength' = 'Minimum allowed serial number length'
        'minimumDevicePhysicalMemoryInGB' = 'Minimum required device memory in GB'
        'maxNumberOfDevicesAllowed' = 'Maximum devices a user can have enrolled'
        'preferredBrowser' = 'Default browser for web-based operations'
        'privateSession' = 'Use private/incognito browsing sessions'
        'userPatternsToExclude' = 'Username patterns to exclude from operations'
        'desiredAutopilotProfiles' = 'Autopilot profiles to assign to devices'
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
        'Boolean' {
            return Get-BooleanInput -CurrentValue $CurrentValue
        }
        'AppMode' {
            return Get-AppModeInput -CurrentValue $CurrentValue
        }
        'CacheType' {
            return Get-CacheTypeInput -CurrentValue $CurrentValue
        }
        'Repo' {
            return Get-RepoInput -CurrentValue $CurrentValue
        }
        'OperatingSystem' {
            return Get-OperatingSystemInput -CurrentValue $CurrentValue
        }
        'Browser' {
            return Get-BrowserInput -CurrentValue $CurrentValue
        }
        'Array' {
            return Get-ArrayInput -CurrentValue $CurrentValue
        }
        'Number' {
            return Get-NumberInput -SettingName $SettingName -CurrentValue $CurrentValue
        }
        default {
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
            default {
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
                return $CurrentValue
            }
            
            $newValues += $input
        }
        else
        {
            $input = Read-Host "Value"
            if ([string]::IsNullOrWhiteSpace($input))
            {
                break
            }
            $newValues += $input
        }
    } while ($true)
    
    return $newValues
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

function Save-DomainSettings()
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