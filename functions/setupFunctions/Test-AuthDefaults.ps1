function Test-AuthDefaults()
{
    <#
    .SYNOPSIS
        Ensures that auth section in settings.json has all required default values.
    
    .DESCRIPTION
        Checks if the auth section in settings.json contains all required settings,
        and if not, adds the missing default values. This function follows the same
        pattern as Test-SettingsJsonExists but focuses specifically on the auth section.
    
    .PARAMETER SettingsFile
        Path to the settings.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the auth section exists and was updated with defaults, $false otherwise.
    
    .EXAMPLE
        Test-AuthDefaults -SettingsFile "settings.json"
    
    .EXAMPLE
        Test-AuthDefaults -SettingsFile "custom-settings.json" -Silent
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Creates backup before modification for safety
        - Uses the exact default auth structure provided in requirements
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        [switch]$Silent
    )
    
    # Helper function to safely log messages
    function Write-SafeLogFallback
    {
        param($Message, $Level)
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue)
        {
            Write-SafeLog $Message $Level
        }
        else
        {
            Write-Verbose "[$functionName] $Message"
        }
    }
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring auth defaults in: $SettingsFile"
    Write-SafeLogFallback "Ensuring auth defaults in: $SettingsFile" "Information"
    
    try
    {
        # Define default auth structure with exact values from requirements
        $defaultAuth = @{
            changePwOnNextStart = $false
            authType            = "PublicAuthFlow"
            noSaveRefreshToken  = $false
            forceNewToken       = $false
            renewalLeadTime     = 5
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
            cacheType           = "Memory"
            secureString        = $false
            delegated           = $true
        }
        
        Write-Verbose "[$functionName] Default auth structure defined with $($defaultAuth.Keys.Count) properties"
        Write-SafeLogFallback "Default auth structure defined with $($defaultAuth.Keys.Count) properties" "Verbose"
        
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            Write-SafeLogFallback "Settings file not found: $SettingsFile" "Warning"
            return $false
        }
        
        # Load existing settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settings = $jsonContent | ConvertFrom-Json
        
        Write-Verbose "[$functionName] Loaded existing settings from file"
        Write-SafeLogFallback "Loaded existing settings from file" "Verbose"
        
        # Convert to hashtable for easier manipulation
        $settingsHash = @{}
        foreach ($property in $settings.PSObject.Properties)
        {
            if ($property.Value -is [PSCustomObject])
            {
                $nestedHash = @{}
                foreach ($nestedProp in $property.Value.PSObject.Properties)
                {
                    $nestedHash[$nestedProp.Name] = $nestedProp.Value
                }
                $settingsHash[$property.Name] = $nestedHash
            }
            else
            {
                $settingsHash[$property.Name] = $property.Value
            }
        }
        
        $authUpdated = $false
        
        # Check if auth section exists
        if (-not $settingsHash.ContainsKey('auth'))
        {
            Write-Verbose "[$functionName] Auth section not found, creating new one"
            Write-SafeLogFallback "Auth section not found, creating new one" "Information"
            $settingsHash['auth'] = $defaultAuth
            $authUpdated = $true
        }
        else
        {
            Write-Verbose "[$functionName] Auth section exists, checking for missing defaults"
            Write-SafeLogFallback "Auth section exists, checking for missing defaults" "Verbose"
            
            $currentAuth = $settingsHash['auth']
            
            # Check each default property and add if missing
            foreach ($key in $defaultAuth.Keys)
            {
                if (-not $currentAuth.ContainsKey($key))
                {
                    $currentAuth[$key] = $defaultAuth[$key]
                    $authUpdated = $true
                    Write-Verbose "[$functionName] Added missing auth property: $key = $($defaultAuth[$key])"
                    Write-SafeLogFallback "Added missing auth property: $key = $($defaultAuth[$key])" "Information"
                }
                else
                {
                    Write-Verbose "[$functionName] Auth property '$key' already exists with value: $($currentAuth[$key])"
                }
            }
        }
        
        # Save updated settings if changes were made
        if ($authUpdated)
        {
            # Create backup
            $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $SettingsFile -Destination $backupFile -Force
            Write-Verbose "[$functionName] Created backup: $backupFile"
            Write-SafeLogFallback "Created backup: $backupFile" "Information"
            
            # Convert hashtable back to PSCustomObject for JSON output
            $outputSettings = [PSCustomObject]@{}
            foreach ($key in $settingsHash.Keys)
            {
                if ($settingsHash[$key] -is [hashtable])
                {
                    $outputSettings | Add-Member -MemberType NoteProperty -Name $key -Value ([PSCustomObject]$settingsHash[$key])
                }
                else
                {
                    $outputSettings | Add-Member -MemberType NoteProperty -Name $key -Value $settingsHash[$key]
                }
            }
            
            # Save updated settings
            $jsonOutput = $outputSettings | ConvertTo-Json -Depth $maxJSONDepth
            Set-Content -Path $SettingsFile -Value $jsonOutput -Force
            
            Write-Verbose "[$functionName] Auth defaults updated successfully"
            Write-SafeLogFallback "Auth defaults updated successfully" "Information"
            
            if (-not $Silent)
            {
                Write-Host "Auth section updated with default values." -ForegroundColor Green
            }
        }
        else
        {
            Write-Verbose "[$functionName] Auth section already has all required defaults"
            Write-SafeLogFallback "Auth section already has all required defaults" "Information"
            
            if (-not $Silent)
            {
                Write-Host "Auth section is up-to-date." -ForegroundColor Green
            }
        }
        
        return $true
    }
    catch
    {
        Write-SafeLogFallback "Error ensuring auth defaults: $($_.Exception.Message)" "Error"
        Write-Warning "[$functionName] Error ensuring auth defaults: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Get-AuthDefaults()
{
    <#
    .SYNOPSIS
        Returns the default auth configuration structure.
    
    .DESCRIPTION
        Provides the default auth configuration that should be present in settings.json.
        This function serves as the single source of truth for auth defaults.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns hashtable with default auth configuration.
    
    .EXAMPLE
        $authDefaults = Get-AuthDefaults
    
    .NOTES
        Uses the exact default auth structure provided in requirements.
    #>
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Returning default auth configuration"
    
    return @{
        changePwOnNextStart = $false
        authType            = "PublicAuthFlow"
        noSaveRefreshToken  = $false
        forceNewToken       = $false
        renewalLeadTime     = 5
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
        cacheType           = "Memory"
        secureString        = $false
        delegated           = $true
    }
}