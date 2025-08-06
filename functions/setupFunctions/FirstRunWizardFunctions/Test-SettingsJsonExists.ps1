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
    Write-SafeLog "Ensuring settings.json exists: $SettingsFile" "Information"
    try
    {
        # Define comprehensive default settings structure with correct property order
        $defaultSettings = @{
            description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
            version        = "1.3.0.0"
            auth           = @{
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
            requiredScopes = @(
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
            menus          = @(
                @{
                    name                  = "Give a device to a user"
                    description           = "Start the user and device readiness check"
                    type                  = "action"
                    includeInDisplayModes = @("helpdesk", "registration")
                },
                @{
                    name                  = "Check device status"
                    description           = "Troubleshoot a device"
                    type                  = "submenu"
                    includeInDisplayModes = @("helpdesk", "registration")
                    items                 = @(
                        @{
                            name                  = "Lookup device by Serial Number"
                            description           = "Lookup a device by its serial number"
                            type                  = "submenu"
                            includeInDisplayModes = @()
                            items                 = @(
                                @{
                                    name                  = "Enter a serial number"
                                    description           = "Lookup a device by its serial number"
                                    type                  = "action"
                                    includeInDisplayModes = @()
                                },
                                @{
                                    name                  = "Use this device's serial number"
                                    description           = "Lookup the device the application is running on"
                                    type                  = "action"
                                    includeInDisplayModes = @()
                                }
                            )
                        },
                        @{
                            name                  = "Lookup device by User"
                            description           = "Lookup a device by the user id or email address"
                            type                  = "action"
                            includeInDisplayModes = @()
                        }
                    )
                },
                @{
                    name                  = "Autopilot menu"
                    description           = "Import a device into Autopilot and perform related actions"
                    type                  = "submenu"
                    includeInDisplayModes = @("registration")
                    items                 = @(
                        @{
                            name                  = "Import device into Autopilot"
                            description           = "Import a device into Autopilot"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Custom import device into Autopilot (requires admin rights)"
                            description           = "Custom import a device into Autopilot"
                            type                  = "action"
                            includeInDisplayModes = @("advancedRegistration")
                        },
                        @{
                            name                  = "Import Corporate Device Identifier for Device Preparation (requires admin rights)"
                            description           = "Import a Corporate Device Identifier for Device Preparation"
                            type                  = "action"
                            includeInDisplayModes = @("advancedRegistration")
                        },
                        @{
                            name                  = "Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)"
                            description           = "Export a Corporate Device Identifier for manual upload to Device Preparation"
                            type                  = "action"
                            includeInDisplayModes = @("advancedRegistration")
                        },
                        @{
                            name                  = "Get device hash for manual upload to Autopilot (requires admin rights)"
                            description           = "Get the device hash for manual upload to Autopilot"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Download and install latest Windows updates(requires admin rights)"
                            description           = "Download and install the latest Windows updates"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Check device Autopilot status"
                            description           = "Check if a device is registered in Autopilot"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Delete device from Autopilot"
                            description           = "Delete a device from Autopilot"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        }
                    )
                },
                @{
                    name                  = "Change application settings"
                    description           = "Change the application settings"
                    type                  = "submenu"
                    includeInDisplayModes = @("advanced")
                    items                 = @(
                        @{
                            name                  = "Change application settings"
                            description           = "Change the application settings"
                            type                  = "action"
                            includeInDisplayModes = @()
                        },
                        @{
                            name                  = "Change password and authentication information"
                            description           = "Change the password and authentication information"
                            type                  = "action"
                            includeInDisplayModes = @()
                        },
                        @{
                            name                  = "Change Auto Update setting"
                            description           = "Change the Auto Update setting"
                            type                  = "action"
                            includeInDisplayModes = @()
                        },
                        @{
                            name                  = "Restore defaults"
                            description           = "Restore the application to its default settings"
                            type                  = "action"
                            includeInDisplayModes = @()
                        }
                    )
                },
                @{
                    name                  = "Check for script updates"
                    description           = "Check for updates to the scripts used by the application"
                    type                  = "action"
                    includeInDisplayModes = @()
                },
                @{
                    name                  = "Restart the device"
                    description           = "Restart the device"
                    type                  = "action"
                    includeInDisplayModes = @()
                },
                @{
                    name                  = "Export Menu"
                    description           = "Export various device configuration"
                    type                  = "submenu"
                    includeInDisplayModes = @("registration")
                    items                 = @(
                        @{
                            name                  = "Export Autopilot Devices"
                            description           = "Export Autopilot devices to a CSV file"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Export Imported Autopilot Devices"
                            description           = "Export imported Autopilot devices to a CSV file"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Export Managed Windows Devices"
                            description           = "Export managed Windows devices to a CSV file"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Export Unmanaged Windows Devices"
                            description           = "Export unmanaged Windows devices to a CSV file"
                            type                  = "action"
                            includeInDisplayModes = @("advanced")
                        },
                        @{
                            name                  = "Export device storage report"
                            description           = "Export a report of device storage to a CSV file"
                            type                  = "action"
                            includeInDisplayModes = @("registration")
                        },
                        @{
                            name                  = "Export Application Assignments"
                            description           = "Export application assignments to a CSV file"
                            type                  = "action"
                            includeInDisplayModes = @("advanced")
                        }
                    )
                },
                @{
                    name                  = "About"
                    description           = "Learn more about the application"
                    type                  = "action"
                    includeInDisplayModes = @()
                },
                @{
                    name                  = "Device Actions"
                    description           = "Perform various device actions"
                    type                  = "submenu"
                    includeInDisplayModes = @()
                    items                 = @(
                        @{
                            name                  = "Wipe Device"
                            description           = "Wipe the selected device"
                            type                  = "action"
                            includeInDisplayModes = @("helpdesk", "registration")
                        },
                        @{
                            name                  = "Clean Device"
                            description           = "Clean the selected device"
                            type                  = "action"
                            includeInDisplayModes = @("advanced")
                        },
                        @{
                            name                  = "Sync Device"
                            description           = "Sync the selected device"
                            type                  = "action"
                            includeInDisplayModes = @("helpdesk", "registration")
                        },
                        @{
                            name                  = "Get LAPS Password"
                            description           = "Retrieve the LAPS password for the selected device"
                            type                  = "action"
                            includeInDisplayModes = @("helpdesk", "registration")
                        },
                        @{
                            name                  = "Get BitLocker Recovery Key"
                            description           = "Retrieve the BitLocker recovery key for the selected device"
                            type                  = "action"
                            includeInDisplayModes = @("helpdesk", "registration")
                        },
                        @{
                            name                  = "Restart Device"
                            description           = "Restart the selected device"
                            type                  = "action"
                            includeInDisplayModes = @()
                        },
                        @{
                            name                  = "Show Device Health Status"
                            description           = "Show the health status of the selected device"
                            type                  = "action"
                            includeInDisplayModes = @()
                        },
                        @{
                            name                  = "Check next user readiness state"
                            description           = "Check the next user readiness state for the selected device"
                            type                  = "action"
                            includeInDisplayModes = @()
                        }
                    )
                }
            )
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
                if ($null -ne $mergedSettings)
                {
                    Write-Verbose "[$functionName] Merging default settings into existing configuration"
                    Write-SafeLog "Merging default settings into existing configuration" "Information"
                    $mergedJson = ConvertTo-OrderedJson -InputObject $mergedSettings -Depth 10
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

