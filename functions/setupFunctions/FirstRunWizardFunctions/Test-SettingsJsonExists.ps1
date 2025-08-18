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
        #app modes are: full, helpDesk, advanced, advancedRegistration, registration, admin, custom
        $defaultSettings = @{
            description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
            version        = $version.version.toString()
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
                maxWaitTime                  = 30
                showLicenseBanner            = $true
                deviceContactThresholdInDays = 30
                appMode                      = "full"
                timeInSeconds                = 60
                maxUserMatchDisplay          = 10
                maxGroupMatchDisplay         = 10
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
                        maxWaitTime                     = "30"
                        showLicenseBanner               = $true
                        deviceContactThresholdInDays    = 30
                        appMode                         = "full"
                        timeInSeconds                   = "60"
                        maxUserMatchDisplay             = "10"
                        maxGroupMatchDisplay            = 10
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
                        groupPatternsToExclude          = @()  
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
                if ($null -ne $mergedSettings)
                {
                    Write-Verbose "[$functionName] Merging default settings into existing configuration"
                    Write-SafeLog "Merging default settings into existing configuration" "Information"
                    $mergedJson = ConvertTo-OrderedJson -InputObject $mergedSettings -Depth $maxJSONDepth
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
        $settingsJson = ConvertTo-OrderedJson -InputObject $defaultSettings -Depth $maxJSONDepth
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

