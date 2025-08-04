function Test-SettingsJsonExists()
{
    <#
    .SYNOPSIS
        Ensures that settings.json exists with default values.
    
    .DESCRIPTION
        Checks if settings.json exists, and if not, creates it with comprehensive default values
        based on the existing settings structure.
    
    .PARAMETER SettingsFile
        Path to the settings.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .PARAMETER DomainName
        The domain name to use for domain-specific configuration defaults.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file exists or was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        [switch]$Silent,
        [string]$AuthType = "Delegated",
        [bool]$IsDelegated = $true,
        [string]$DomainName = "example.com"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring settings.json exists: $SettingsFile"
    try
    {
        # Define comprehensive default settings structure with correct property order
        $defaultSettings = @{
            description      = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
            version          = "1.3.0.0"
            auth             = @{
                delegated           = $IsDelegated
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
            requiredScopes   = @(
                @{
                    Scope     = "User.Read.All"
                    Reason    = "Required to read user profiles, group memberships, and registered devices."
                    Endpoints = @(
                        "/users",
                        "users/{id}",
                        "users/{id}/memberOf",
                        "users/{id}/registeredDevices"
                    )
                },
                @{
                    Scope     = "Device.Read.All"
                    Reason    = "Required to read Microsoft Entra ID device objects."
                    Endpoints = @(
                        "devices"
                    )
                },
                @{
                    Scope     = "DeviceManagementApps.ReadWrite.All"
                    Reason    = "Required to read application information and manage app assignments."
                    Endpoints = @(
                        "deviceAppManagement/mobileApps",
                        "deviceAppManagement/mobileApps/{id}/assignments"
                    )
                },
                @{
                    Scope     = "DeviceManagementConfiguration.Read.All"
                    Reason    = "Required to read Intune device configuration policies."
                    Endpoints = @(
                        "deviceManagement/deviceConfigurations"
                    )
                },
                @{
                    Scope     = "DeviceManagementManagedDevices.Read.All"
                    Reason    = "Required to read Intune managed device properties."
                    Endpoints = @(
                        "/deviceManagement/managedDevices",
                        "deviceManagement/managedDevices/{id}"
                    )
                },
                @{
                    Scope     = "DeviceManagementManagedDevices.PrivilegedOperations.All"
                    Reason    = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
                    Endpoints = @(
                        "directory/deviceLocalCredentials"
                    )
                },
                @{
                    Scope     = "DeviceManagementServiceConfig.ReadWrite.All"
                    Reason    = "Required to read Autopilot events and to read and manage Autopilot device identities."
                    Endpoints = @(
                        "deviceManagement/autopilotEvents",
                        "deviceManagement/importedWindowsAutopilotDeviceIdentities",
                        "deviceManagement/windowsAutopilotDeviceIdentities"
                    )
                },
                @{
                    Scope     = "BitlockerKey.Read.All"
                    Reason    = "Required to read BitLocker recovery keys for all devices."
                    Endpoints = @(
                        "informationProtection/bitlocker/recoveryKeys"
                    )
                },
                @{
                    Scope     = "openid"
                    Reason    = "Standard scope required for user sign-in with OpenID Connect."
                    Endpoints = @()
                },
                @{
                    Scope     = "profile"
                    Reason    = "Standard scope to get basic user profile information during sign-in."
                    Endpoints = @()
                },
                @{
                    scope     = "DeviceManagementConfiguration.ReadWrite.All"
                    reason    = "Required to create, update, and delete Intune device configuration policies."
                    endpoints = @(
                        "deviceManagement/deviceConfigurations"
                    )
                },
                @{
                    scope     = "DeviceManagementApps.Read.All"
                    reason    = "Required to read application information in Intune."
                    endpoints = @(
                        "deviceAppManagement/mobileApps"
                    )
                },
                @{
                    scope     = "DeviceManagementManagedDevices.ReadWrite.All"
                    reason    = "Required to create, update, and delete Intune managed device properties."
                    endpoints = @(
                        "deviceManagement/managedDevices"
                    )
                },
                @{
                    scope     = "DeviceManagementManagedDevices.PrivilegedOperations.All"
                    reason    = "Required for privileged operations on managed devices, such as reading LAPS passwords."
                    endpoints = @(
                        "deviceManagement/managedDevices"
                    )
                },
                @{
                    scope     = "BitlockerKey.Read.All"
                    reason    = "Required to read BitLocker recovery keys for all devices."
                    endpoints = @(
                        "informationProtection/bitlocker/recoveryKeys"
                    )
                },
                @{
                    scope     = "openid"
                    reason    = "Standard scope required for user sign-in with OpenID Connect."
                    endpoints = @()
                },
                @{
                    scope     = "profile"
                    reason    = "Standard scope to get basic user profile information during sign-in."
                    endpoints = @()
                },
                @{
                    scope     = "offline_access"
                    reason    = "Standard scope that provides refresh tokens to maintain access when the user is not active."
                    endpoints = @()
                }
            )
            menuItemsToInclude = @(
                "Autopilot menu",
                "Restart the device",
                "Export Menu",
                "Quick Import device into Autopilot (requires admin rights)",
                "Custom import device into Autopilot (requires admin rights)",
                "Import Corporate Device Identifier for Device Preparation (requires admin rights)",
                "Delete Corporate Device Identifier from Device Preparation (requires admin rights)",
                "Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)",
                "Get device hash for manual upload to Autopilot (requires admin rights)",
                "Download and install latest Windows updates(requires admin rights)",
                "Check device Autopilot status",
                "Change application settings",
                "Change password and authentication information",
                "Export Autopilot Devices",
                "Export Imported Autopilot Devices",
                "Export Managed Windows Devices",
                "Export Unmanaged Windows Devices",
                "Export device storage report",
                "Export Application Assignments",
                "Wipe Device",
                "Clean Device",
                "Restart Device",
                "Show Device Health Status",
                "Check next user readiness state"
            )
            globalSettings = @{
                configFile                   = ".\.secrets\config.json"
                maxWaitTime                  = "30"
                showLicenseBanner            = $true
                deviceContactThresholdInDays = 30
                appMode                      = "full"
                timeInSeconds                = "60"
                maxUserMatchDisplay          = "10"
                release                      = "master"
                repo                         = "Github"
                testMode                     = $false
                operatingSystem              = "Windows"
                autoUpdate                   = $true
            }
            domains        = @{
                $DomainName = @{
                    groupsToInclude = @()
                    groupsToExclude = @()
                    settings        = @{
                        domain                          = $DomainName
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

        if (Test-Path -Path $SettingsFile)
        {
            Write-Verbose "[$functionName] Settings file exists, checking for missing default values: $SettingsFile"
            Write-SafeLog "Settings file exists, checking for updates: $SettingsFile" "Information"
            
            try
            {
                # Load existing settings
                $existingSettings = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
                
                # Convert JSON object to hashtable for merging
                $existingHashtable = @{}
                $existingSettings.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject])
                    {
                        $existingHashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
                    }
                    else
                    {
                        $existingHashtable[$_.Name] = $_.Value
                    }
                }
                
                # Merge defaults into existing configuration
                $mergedSettings = Merge-ConfigurationDefaults -ExistingConfig $existingHashtable -DefaultConfig $defaultSettings
                
                # Convert back to JSON with proper ordering and save if changes were made
                $mergedJson = ConvertTo-OrderedJson -InputObject $mergedSettings -Depth 10
                $existingJson = Get-Content -Path $SettingsFile -Raw
                
                if ($mergedJson -ne $existingJson)
                {
                    Set-Content -Path $SettingsFile -Value $mergedJson -Encoding UTF8 -Force
                    Write-Verbose "[$functionName] Updated settings.json with missing default values"
                    Write-SafeLog "Updated settings.json with missing default values" "Information"
                    
                    if (-not $Silent)
                    {
                        Write-Host "Settings file updated with new default values." -ForegroundColor Green
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Settings file is up-to-date"
                }
                
                return $true
            }
            catch
            {
                Write-Verbose "[$functionName] Error processing existing settings file: $($_.Exception.Message)"
                Write-SafeLog "Error processing existing settings file: $($_.Exception.Message)" "Warning"
                # Continue with creating new file as fallback
            }
        }
        
        if (-not $Silent)
        {
            Write-Host "`n── Settings Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default settings.json file..." -ForegroundColor White
        }
        
        # File doesn't exist, create it with default settings
        if (-not $Silent)
        {
            Write-Host "Creating default settings.json file..." -ForegroundColor White
        }
        
        # Convert to JSON with proper ordering and write to file
        $settingsJson = ConvertTo-OrderedJson -InputObject $defaultSettings -Depth 10
        Set-Content -Path $SettingsFile -Value $settingsJson -Encoding UTF8 -Force
        Write-Verbose "[$functionName] Created comprehensive settings.json with requiredScopes"
        
        $success = $true
        
        if ($success)
        {
            Write-Host "Settings file created successfully." -ForegroundColor Green
            Write-SafeLog "Settings file created successfully: $SettingsFile" "Information"
            return $true
        }
        else
        {
            Write-Host "Failed to create settings file." -ForegroundColor Red
            Write-SafeLog "Failed to create settings file: $SettingsFile" "Error"
            return $false
        }
        
    }
    catch
    {
        Write-SafeLog "Error ensuring settings.json exists: $($_.Exception.Message)" "Error"
        Write-Host "Error creating settings file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
}

