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
        if (Test-Path -Path $SettingsFile)
        {
            Write-Verbose "[$functionName] Settings file already exists: $SettingsFile"
            Write-SafeLog "Settings file already exists: $SettingsFile" "Information"
            return $true
        }
        
        if (-not $Silent)
        {
            Write-Host "`n── Settings Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default settings.json file..." -ForegroundColor White
        }
        
        # Create comprehensive settings.json using ordered dictionary
        $settings = [ordered]@{
            description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
            version        = "1.1.0.0"
            auth           = [ordered]@{
                Delegated           = $IsDelegated
                authType            = "PublicAuthFlow"
                changePWOnNextStart = $false
                renewalLeadTime     = 5
                NoSaveRefreshToken  = $false
                SecureString        = $false
                ForceNewToken       = $false
                CacheType           = "Memory"
                scope               = @(
                    "offline_access",
                    "openid",
                    "Device.ReadWrite.All",
                    "DeviceManagementApps.Read.All",
                    "DeviceManagementConfiguration.ReadWrite.All",
                    "DeviceManagementManagedDevices.PrivilegedOperations.All",
                    "DeviceManagementManagedDevices.ReadWrite.All",
                    "DeviceManagementServiceConfig.ReadWrite.All",
                    "BitlockerKey.Read.All",
                    "User.Read.All"
                )
            }
            globalSettings = [ordered]@{
                operatingSystem     = "Windows"
                autoUpdate          = $true
                showLicenseBanner   = $true
                testMode            = $false
                configFile          = ".\.secrets\config.json"
                maxWaitTime         = "30"
                maxUserMatchDisplay = "10"
                timeInSeconds       = "60"
                Release             = "main"
                Repo                = "Github"
                appMode             = "helpdesk"
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
                    Scope     = "offline_access"
                    Reason    = "Standard scope that provides refresh tokens to maintain access when the user is not active."
                    Endpoints = @()
                }
            )

            domains        = [ordered]@{
                $DomainName = [ordered]@{
                    groupsToInclude = @()
                    groupsToExclude = @()
                    settings        = [ordered]@{
                        domain                          = $DomainName
                        deviceNamePrefix                = ""
                        operatingSystem                 = "Windows"
                        MinUsernameLength               = 3
                        MaxUserNameLength               = 50
                        MaxSerialNumberLength           = 50
                        MinSerialNumberLength           = 7
                        MinimumDevicePhysicalMemoryInGB = 8
                        maxNumberOfDevicesAllowed       = 15
                        preferredBrowser                = "Chrome"
                        privateSession                  = $false
                        userPatternsToExclude           = @( 
                            "-test",
                            "onmicrosoft.com"
                        )
                        DesiredAutopilotProfiles        = @()
                    }
                }
            }
        }
        
        # Convert to JSON and write to file
        $settingsJson = $settings | ConvertTo-Json -Depth 10
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

