function Show-SettingsViewer()
{
    <#
    .SYNOPSIS
        Read-only viewer for application settings displaying values and descriptions.
    
    .DESCRIPTION
        Provides a read-only interface for users to view application settings with their
        current values and descriptions. Uses the same infrastructure as Show-SettingsEditor
        but displays information without modification capabilities. Supports viewing
        global, domain-specific, and authentication settings.
    
    .PARAMETER SettingsType
        Specifies whether to view 'Global', 'Domain', or 'Auth' settings.
    
    .PARAMETER SettingsFile
        Path to the settings.json file. Defaults to "settings.json".
    
    .PARAMETER DomainName
        Required when SettingsType is 'Domain'. Specifies which domain's settings to view.
    
    .PARAMETER Silent
        If specified, uses minimal output for programmatic usage.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were successfully displayed, $false otherwise.
    
    .EXAMPLE
        Show-SettingsViewer -SettingsType "Global"
    
    .EXAMPLE
        Show-SettingsViewer -SettingsType "Domain" -DomainName "contoso.com"
    
    .EXAMPLE
        Show-SettingsViewer -SettingsType "Auth"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Leverages existing infrastructure from Show-SettingsEditor
        - Read-only display with no modification capabilities
        - Supports same settings structure as the editor
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Domain', 'Auth')]
        [string]$SettingsType,
        [string]$SettingsFile = "settings.json",
        [string]$DomainName,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $logFile -Module $functionName -Message "Starting settings viewer for $SettingsType settings" -LogLevel "Information"
    Write-Verbose "[$functionName] Starting settings viewer for $SettingsType settings"
    
    try
    {
        # Validate parameters
        if ($SettingsType -eq 'Domain' -and [string]::IsNullOrWhiteSpace($DomainName))
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "DomainName is required when viewing Domain settings" -LogLevel "Error"
            Write-Warning "[$functionName] DomainName is required when viewing Domain settings"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Parameter validation passed. SettingsType: $SettingsType, SettingsFile: $SettingsFile" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Parameter validation passed. SettingsType: $SettingsType, SettingsFile: $SettingsFile"
        
        # For auth settings, ensure auth defaults are in place
        if ($SettingsType -eq 'Auth')
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "Ensuring auth defaults are present for display" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Ensuring auth defaults are present for display"
            $authDefaultsSuccess = Test-AuthDefaults -SettingsFile $SettingsFile -Silent
            if (-not $authDefaultsSuccess)
            {
                Write-Log -LogFile $logFile -Module $functionName -Message "Failed to ensure auth defaults" -LogLevel "Error"
                Write-Warning "[$functionName] Failed to ensure auth defaults"
                return $false
            }
        }
        
        # Get default settings structure from existing infrastructure
        Write-Log -LogFile $logFile -Module $functionName -Message "Retrieving default settings structure for display" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Retrieving default settings structure for display"
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
        
        # Get settings template and current values to display
        if ($SettingsType -eq 'Global')
        {
            $settingsTemplate = $defaultSettings.globalSettings
            $currentValues = $currentSettings.globalSettings
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying global settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Displaying global settings"
            if (-not $Silent)
            {
                Write-Host "`n══ Global Settings Viewer ══" -ForegroundColor Cyan
                Write-Host "Current global application settings that apply to all domains." -ForegroundColor White
                Write-Host "These settings control the overall behavior of the application.`n" -ForegroundColor Gray
            }
        }
        elseif ($SettingsType -eq 'Auth')
        {
            $settingsTemplate = Get-AuthDefaults
            $currentValues = $currentSettings.auth
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying auth settings" -LogLevel "Information"
            Write-Verbose "[$functionName] Displaying auth settings"
            if (-not $Silent)
            {
                Write-Host "`n══ Authentication Settings Viewer ══" -ForegroundColor Cyan
                Write-Host "Current authentication and authorization settings." -ForegroundColor White
                Write-Host "These settings control how the application authenticates with Microsoft Graph API.`n" -ForegroundColor Gray
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
            
            Write-Log -LogFile $logFile -Module $functionName -Message "Displaying domain settings for domain: '$DomainName' from separate configuration file" -LogLevel "Information"
            Write-Verbose "[$functionName] Displaying domain settings for domain: '$DomainName' from separate configuration file"
            if (-not $Silent)
            {
                Write-Host "`n══ Domain Settings Viewer ══" -ForegroundColor Cyan
                Write-Host "Current settings specific to domain: " -NoNewline -ForegroundColor White
                Write-Host "$DomainName" -ForegroundColor Yellow -BackgroundColor DarkMagenta
                Write-Host "These settings override global settings for this specific domain.`n" -ForegroundColor Gray
                Write-Host "Configuration loaded from: " -NoNewline -ForegroundColor Gray
                Write-Host "$DomainName.json" -ForegroundColor Yellow
                Write-Host ""
            }
        }
        
        if (-not $settingsTemplate)
        {
            Write-Log -LogFile $logFile -Module $functionName -Message "No settings template found for $SettingsType" -LogLevel "Error"
            Write-Warning "[$functionName] No settings template found for $SettingsType"
            return $false
        }
        
        Write-Log -LogFile $logFile -Module $functionName -Message "Settings template loaded successfully. Found $($settingsTemplate.PSObject.Properties.Count) settings to display" -LogLevel "Information"
        Write-Verbose "[$functionName] Settings template loaded successfully. Found $($settingsTemplate.PSObject.Properties.Count) settings to display"
        
        # Get flattened settings for display (same as editor but read-only)
        $flattenedSettings = Get-FlattenedSettingsForViewing -SettingsTemplate $settingsTemplate -CurrentValues $currentValues
        $totalSettings = $flattenedSettings.Count
        
        Write-Verbose "[$functionName] Flattened $totalSettings settings for viewing"
        
        # Implement paging for large setting lists
        $pageSize = 10  # Settings per page
        $totalPages = [Math]::Ceiling($totalSettings / $pageSize)
        $currentPage = 1
        
        if ($totalSettings -gt $pageSize -and -not $Silent)
        {
            Write-Host "Total settings: $totalSettings (showing $pageSize per page, $totalPages pages total)" -ForegroundColor Gray
            Write-Host "Use 'n' for next page, 'p' for previous page, 'q' to quit, or page number to jump" -ForegroundColor Yellow
            Write-Host ""
        }
        
        do
        {
            $startIndex = ($currentPage - 1) * $pageSize
            $endIndex = [Math]::Min($startIndex + $pageSize - 1, $totalSettings - 1)
            $pageSettings = $flattenedSettings[$startIndex..$endIndex]
            
            if (-not $Silent)
            {
                if ($totalPages -gt 1)
                {
                    Write-Host "═══ Page $currentPage of $totalPages ═══" -ForegroundColor Cyan
                    Write-Host "Showing settings $($startIndex + 1) - $($endIndex + 1) of $totalSettings" -ForegroundColor Gray
                    Write-Host ""
                }
            }
            
            # Display settings on current page
            foreach ($settingInfo in $pageSettings)
            {
                if (-not $Silent)
                {
                    Display-SettingInfoForViewer -SettingInfo $settingInfo
                }
            }
            
            # Handle paging navigation
            if ($totalPages -gt 1 -and -not $Silent)
            {
                Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "Page navigation: [n]ext | [p]revious | [1-$totalPages] jump to page | [q]uit" -ForegroundColor Yellow
                
                do
                {
                    $userInput = Read-Host "Enter command"
                    $navigationAction = $null
                    
                    switch ($userInput.ToLower())
                    {
                        'n'
                        {
                            if ($currentPage -lt $totalPages)
                            {
                                $currentPage++
                                $navigationAction = 'continue'
                            }
                            else
                            {
                                Write-Host "Already on last page" -ForegroundColor Yellow
                            }
                        }
                        'p'
                        {
                            if ($currentPage -gt 1)
                            {
                                $currentPage--
                                $navigationAction = 'continue'
                            }
                            else
                            {
                                Write-Host "Already on first page" -ForegroundColor Yellow
                            }
                        }
                        'q'
                        {
                            $navigationAction = 'quit'
                        }
                        default
                        {
                            # Check if it's a page number
                            if ($userInput -match '^\d+$')
                            {
                                $pageNumber = [int]$userInput
                                if ($pageNumber -ge 1 -and $pageNumber -le $totalPages)
                                {
                                    $currentPage = $pageNumber
                                    $navigationAction = 'continue'
                                }
                                else
                                {
                                    Write-Host "Invalid page number. Enter 1-$totalPages" -ForegroundColor Red
                                }
                            }
                            else
                            {
                                Write-Host "Invalid command. Use n, p, q, or page number" -ForegroundColor Red
                            }
                        }
                    }
                    
                    if ($navigationAction)
                    {
                        break
                    }
                } while ($true)
                
                if ($navigationAction -eq 'quit')
                {
                    break
                }
                
                # Clear screen for next page
                Clear-Host
                Write-Host "══ $($SettingsType) Settings Viewer ══" -ForegroundColor Cyan
                if ($SettingsType -eq 'Domain')
                {
                    Write-Host "Domain: $DomainName" -ForegroundColor Yellow
                }
                Write-Host ""
            }
            else
            {
                break  # No paging needed or silent mode
            }
        } while ($true)
        
        if (-not $Silent -and $totalPages -le 1)
        {
            Write-Host "`n══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "Total settings displayed: $totalSettings" -ForegroundColor White
            Write-Host "Use the settings editor to modify these values." -ForegroundColor Gray
        }
        
        return $true
    }
    catch
    {
        Write-Log -LogFile $logFile -Module $functionName -Message "Error in settings viewer: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $logFile -Module $functionName -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -LogLevel "Debug"
        Write-Warning "[$functionName] Error in settings viewer: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Get-FlattenedSettingsForViewing()
{
    <#
    .SYNOPSIS
        Flattens settings structure for viewing while preserving nested object information.
    
    .DESCRIPTION
        Similar to Get-FlattenedSettingsForEditing but optimized for read-only display.
        Processes both template and current values to create a flat list of settings
        with proper path information for nested values.
    #>
    [CmdletBinding()]
    param(
        $SettingsTemplate,
        $CurrentValues
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Flattening settings for viewing"
    
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
                $nestedSettings = Get-FlattenedSettingsForViewing -SettingsTemplate $defaultValue -CurrentValues $currentValue
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
                $nestedSettings = Get-FlattenedSettingsForViewing -SettingsTemplate $defaultValue -CurrentValues $currentValue
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
    
    Write-Verbose "[$functionName] Flattened $($flattenedSettings.Count) settings for viewing"
    return $flattenedSettings
}

function Display-SettingInfoForViewer()
{
    <#
    .SYNOPSIS
        Displays a setting with its value and description in a formatted way for the viewer.
    #>
    [CmdletBinding()]
    param($SettingInfo)
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying setting info for: '$($SettingInfo.Path)'"
    
    # Get description using existing infrastructure
    $description = Get-SettingDescription -SettingName $SettingInfo.Name
    
    # Format the current value for display
    $displayValue = Format-SettingValueForDisplay -Value $SettingInfo.CurrentValue
    
    # Display the setting with path for nested values
    $displayName = if ($SettingInfo.IsNested) { $SettingInfo.Path } else { $SettingInfo.Name }
    
    Write-Host "Setting: " -NoNewline -ForegroundColor Yellow
    Write-Host "$displayName" -ForegroundColor White
    Write-Host "  Value: " -NoNewline -ForegroundColor Cyan
    Write-Host "$displayValue" -ForegroundColor Green
    Write-Host "  Description: " -NoNewline -ForegroundColor Gray
    Write-Host "$description" -ForegroundColor White
    
    # Show if value differs from default
    if ($SettingInfo.CurrentValue -ne $SettingInfo.DefaultValue)
    {
        $defaultDisplayValue = Format-SettingValueForDisplay -Value $SettingInfo.DefaultValue
        Write-Host "  Default: " -NoNewline -ForegroundColor Gray
        Write-Host "$defaultDisplayValue" -ForegroundColor DarkGray
    }
    
    Write-Host ""  # Empty line for spacing
}

function Display-SettingInfo()
{
    <#
    .SYNOPSIS
        Displays a setting with its value and description in a formatted way.
        
    .DESCRIPTION
        Legacy function maintained for backward compatibility.
        Now uses the improved Format-SettingValueForDisplay function.
    #>
    [CmdletBinding()]
    param(
        [string]$SettingName,
        $CurrentValue,
        $DefaultValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying setting info for: '$SettingName'"
    
    # Get description using existing infrastructure
    $description = Get-SettingDescription -SettingName $SettingName
    
    # Format the current value for display using improved function
    $displayValue = Format-SettingValueForDisplay -Value $CurrentValue
    
    # Display the setting
    Write-Host "Setting: " -NoNewline -ForegroundColor Yellow
    Write-Host "$SettingName" -ForegroundColor White
    Write-Host "  Value: " -NoNewline -ForegroundColor Cyan
    Write-Host "$displayValue" -ForegroundColor Green
    Write-Host "  Description: " -NoNewline -ForegroundColor Gray
    Write-Host "$description" -ForegroundColor White
    
    # Show if value differs from default
    if ($CurrentValue -ne $DefaultValue)
    {
        $defaultDisplayValue = Format-SettingValueForDisplay -Value $DefaultValue
        Write-Host "  Default: " -NoNewline -ForegroundColor Gray
        Write-Host "$defaultDisplayValue" -ForegroundColor DarkGray
    }
    
    Write-Host ""  # Empty line for spacing
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
        Formats a setting value for display in the UI with enhanced array and nested object handling.
    #>
    [CmdletBinding()]
    param($Value)
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Add detailed logging for debugging array display issues  
    if ($null -ne $Value) {
        Write-Verbose "[$functionName] Formatting value for display. Type: $($Value.GetType().Name), IsArray: $($Value -is [array])"
    } else {
        Write-Verbose "[$functionName] Formatting null value for display"
    }
    
    try {
        if ($Value -is [array])
        {
            Write-Verbose "[$functionName] Processing array with $($Value.Count) elements"
            if ($Value.Count -eq 0)
            {
                return "(empty array)"
            }
            else
            {
                # Handle nested arrays properly - flatten if needed
                $flattenedElements = @()
                foreach ($element in $Value)
                {
                    if ($element -is [array])
                    {
                        # Handle nested array by flattening it
                        Write-Verbose "[$functionName] Found nested array element, flattening"
                        $flattenedElements += $element
                    }
                    else
                    {
                        $flattenedElements += $element
                    }
                }
                
                # Join the flattened elements
                $joinedValue = $flattenedElements -join ', '
                Write-Verbose "[$functionName] Array elements flattened and joined as: '$joinedValue'"
                return "[$joinedValue]"
            }
        }
        elseif ($Value -is [bool])
        {
            Write-Verbose "[$functionName] Processing boolean value: $Value"
            return $Value.ToString().ToLower()
        }
        elseif ($Value -is [hashtable] -or $Value -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Processing hashtable or PSCustomObject"
            return "(nested object)"
        }
        elseif ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value))
        {
            Write-Verbose "[$functionName] Processing null or whitespace value"
            return "(not set)"
        }
        else
        {
            Write-Verbose "[$functionName] Processing other type as string: '$Value'"
            return [string]$Value
        }
    }
    catch {
        Write-Verbose "[$functionName] Error formatting value: $($_.Exception.Message)"
        # Fallback to safe string conversion
        if ($Value -is [array] -and $Value.Count -gt 0)
        {
            return "[$($Value -join ', ')]"
        }
        return $Value.ToString()
    }
}
