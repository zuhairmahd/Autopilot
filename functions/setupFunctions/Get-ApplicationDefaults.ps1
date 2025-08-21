function Get-ApplicationDefaults()
{
    <#
    .SYNOPSIS
        Single source of truth for all application default values and overwrite configurations.
    
    .DESCRIPTION
        Provides all default configuration structures for the application including
        settings, auth, menus, strings, and overwrite configurations. This function serves as the centralized
        repository for all default values and force-overwrite settings to ensure consistency across the application.
    
    .PARAMETER DefaultType
        Type of defaults to return: 'Settings', 'Auth', 'Global', 'Domain', 'Menus', 'Strings', 'Overwrite', 'All'
    
    .PARAMETER DomainName
        Domain name to use for domain-specific defaults. Defaults to "example.com"
    
    .PARAMETER Version
        Version string to use in configurations. If not provided, uses global version.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns hashtable with requested default configuration or overwrite settings.
    
    .EXAMPLE
        $authDefaults = Get-ApplicationDefaults -DefaultType "Auth"
    
    .EXAMPLE
        $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
    
    .EXAMPLE
        $allDefaults = Get-ApplicationDefaults -DefaultType "All"
    
    .EXAMPLE
        $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "contoso.com"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Single source of truth for all default values and overwrite configurations
        - Replaces individual default value functions to eliminate duplication
        - Domain configurations are now handled separately but this provides templates
        - Overwrite configurations specify target locations (global, local, or universal)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Settings', 'Auth', 'Global', 'Domain', 'Menus', 'Strings', 'Overwrite', 'All')]
        [string]$DefaultType,
        [string]$DomainName = "example.com",
        [string]$Version
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Getting default values for type: $DefaultType"
    
    # Use global version if available, otherwise default
    if (-not $Version)
    {
        $Version = if ($global:version -and $global:version.version)
        {
            $global:version.version.toString()
        }
        else
        {
            "1.3.0.0"
        }
    }
    
    Write-Verbose "[$functionName] Using version: $Version"
    
    # Define all default structures
    $defaults = @{
        
        # Authentication defaults - single source of truth
        Auth           = @{
            changePwOnNextStart = $false
            authType            = "PublicAuthFlow"
            noSaveRefreshToken  = $false
            forceNewToken       = $false
            validateScopes      = $true
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
        
        # Global settings defaults - single source of truth
        Global         = @{
            configFile                   = ".\.secrets\config.json"
            maxWaitTime                  = 30
            showLicenseBanner            = $true
            deviceContactThresholdInDays = 30
            appMode                      = "full"
            timeInSeconds                = 60
            maxUserMatchDisplay          = 10
            maxGroupMatchDisplay         = 10
            release                      = "auto"
            repo                         = "Github"
            repoInfo                     = @{
                repoName      = "Autopilot"
                baseSourceURL = "https: / / raw.githubusercontent.com"
                baseURL       = "https: / / www.github.com"
                repoPath      = "zuhairmahd"
            }
            testMode                     = $false
            operatingSystem              = "Windows"
            autoUpdate                   = $true
        }
        
        # Domain template defaults - single source of truth for domain structure
        Domain         = @{
            groupsToInclude  = @()
            groupsToExclude  = @()
            settings         = @{
                appInfo                         = @{
                    name        = "Autopilot"
                    companyName = "Zuhair Mahmoud"
                    description = "Autopilot for Windows devices"
                    version     = $Version
                }
                domain                          = $DomainName
                maxWaitTime                     = 30
                showLicenseBanner               = $true
                deviceContactThresholdInDays    = 30
                appMode                         = "full"
                timeInSeconds                   = 60
                maxUserMatchDisplay             = 10
                maxGroupMatchDisplay            = 10
                release                         = "master"
                repo                            = "Github"
                repoInfo                        = @{
                    repoName      = "Autopilot"
                    baseSourceURL = "https: / / raw.githubusercontent.com"
                    baseURL       = "https: / / www.github.com"
                    repoPath      = "zuhairmahd"
                }
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
            additionalScopes = @()
        }
        
        # Required scopes for Microsoft Graph API
        RequiredScopes = @(
            @{
                Scope     = "User.Read.All"
                Reason    = "Required to read user profiles, group memberships, and registered devices."
                Endpoints = @(
                    "/ users",
                    "users /
                {
                    id
                }",
                    "users /
                {
                    id
                } / memberOf",
                    "users /
                {
                    id
                } / registeredDevices"
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
                    "deviceAppManagement / mobileApps",
                    "deviceAppManagement / mobileApps /
                {
                    id
                } / assignments"
                )
            },
            @{
                Scope     = "DeviceManagementConfiguration.Read.All"
                Reason    = "Required to read Intune device configuration policies."
                Endpoints = @(
                    "deviceManagement / deviceConfigurations"
                )
            },
            @{
                Scope     = "DeviceManagementManagedDevices.Read.All"
                Reason    = "Required to read Intune managed device properties."
                Endpoints = @(
                    "/ deviceManagement / managedDevices",
                    "deviceManagement / managedDevices /
                {
                    id
                }"
                )
            },
            @{
                Scope     = "DeviceManagementManagedDevices.PrivilegedOperations.All"
                Reason    = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
                Endpoints = @(
                    "directory / deviceLocalCredentials"
                )
            },
            @{
                Scope     = "DeviceManagementServiceConfig.ReadWrite.All"
                Reason    = "Required to read Autopilot events and to read and manage Autopilot device identities."
                Endpoints = @(
                    "deviceManagement / autopilotEvents",
                    "deviceManagement / importedWindowsAutopilotDeviceIdentities",
                    "deviceManagement / windowsAutopilotDeviceIdentities"
                )
            },
            @{
                Scope     = "BitlockerKey.Read.All"
                Reason    = "Required to read BitLocker recovery keys for all devices."
                Endpoints = @(
                    "informationProtection / bitlocker / recoveryKeys"
                )
            },
            @{
                Scope     = "openid"
                Reason    = "Standard scope required for user sign -in with OpenID Connect."
                Endpoints = @()
            },
            @{
                Scope     = "profile"
                Reason    = "Standard scope to get basic user profile information during sign -in ."
                Endpoints = @()
            },
            @{
                scope     = "DeviceManagementConfiguration.ReadWrite.All"
                reason    = "Required to create, update, and delete Intune device configuration policies."
                endpoints = @(
                    "deviceManagement / deviceConfigurations"
                )
            },
            @{
                scope     = "DeviceManagementApps.Read.All"
                reason    = "Required to read application information in Intune."
                endpoints = @(
                    "deviceAppManagement / mobileApps"
                )
            },
            @{
                scope     = "DeviceManagementManagedDevices.ReadWrite.All"
                reason    = "Required to create, update, and delete Intune managed device properties."
                endpoints = @(
                    "deviceManagement / managedDevices"
                )
            },
            @{
                scope     = "offline_access"
                reason    = "Standard scope that provides refresh tokens to maintain access when the user is not active."
                endpoints = @()
            }
        )
    }
    
    # Complete settings structure combining all components
    $defaults.Settings = @{
        description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
        version        = $Version
        auth           = $defaults.Auth
        requiredScopes = $defaults.RequiredScopes
        globalSettings = $defaults.Global
        # Note: domains section is now handled by separate domain configuration files
        # This structure is maintained for backward compatibility during migration
    }
    
    # Overwrite configurations - centralized force-overwrite settings
    $defaults.Overwrite = @{
        # Global settings that should be forcibly overwritten
        # These settings will only be applied during global settings processing
        GlobalSettings    = @{
            # Force automatic updates to be enabled
            "autoUpdate"        = $true
            # Ensure license banner is shown
            "showLicenseBanner" = $true
            # Force test mode to be disabled in production
            "testMode"          = $false
        }
        
        # Local/domain settings that should be forcibly overwritten
        # These settings will only be applied during domain settings processing
        LocalSettings     = @{
            # Ensure consistent device contact threshold across domains
            "deviceContactThresholdInDays"    = 30
            # Standardize wait times across domains
            "maxWaitTime"                     = 30
            # Ensure minimum memory requirements are enforced
            "minimumDevicePhysicalMemoryInGB" = 8
        }
        
        # Universal settings that apply to both global and local contexts
        # These will be applied to both global and domain settings processing
        UniversalSettings = @{
            # Ensure consistent operating system specification
            "operatingSystem" = "Windows"
            # Standardize repository source
            "repo"            = "Github"
            # Ensure consistent release branch
            "release"         = "master"
        }
    }
    
    Write-Verbose "[$functionName] Default structures created for: $($defaults.Keys -join ', ')"
    
    # Return requested defaults
    switch ($DefaultType)
    {
        'Auth'
        {
            Write-Verbose "[$functionName] Returning auth defaults"
            return $defaults.Auth
        }
        'Global'
        {
            Write-Verbose "[$functionName] Returning global defaults"
            return $defaults.Global
        }
        'Domain'
        {
            Write-Verbose "[$functionName] Returning domain template defaults for: $DomainName"
            return $defaults.Domain
        }
        'Settings'
        {
            Write-Verbose "[$functionName] Returning complete settings defaults"
            return $defaults.Settings
        }
        'Overwrite'
        {
            Write-Verbose "[$functionName] Returning overwrite configuration"
            return $defaults.Overwrite
        }
        'All'
        {
            Write-Verbose "[$functionName] Returning all defaults"
            return $defaults
        }
        default
        {
            Write-Warning "[$functionName] Unknown default type: $DefaultType"
            return $null
        }
    }
}

# Backward compatibility functions - these call the centralized function
function Get-AuthDefaults()
{
    <#
    .SYNOPSIS
        Returns the default auth configuration structure (backward compatibility).
    
    .DESCRIPTION
        Wrapper function for backward compatibility. Calls Get-ApplicationDefaults.
    #>
    [CmdletBinding()]
    param()
    
    return Get-ApplicationDefaults -DefaultType "Auth"
}

function Get-GlobalDefaults()
{
    <#
    .SYNOPSIS
        Returns the default global settings structure.
    
    .DESCRIPTION
        Wrapper function that calls Get-ApplicationDefaults for global settings.
    #>
    [CmdletBinding()]
    param()
    
    return Get-ApplicationDefaults -DefaultType "Global"
}

function Get-DomainDefaults()
{
    <#
    .SYNOPSIS
        Returns the default domain configuration template.
    
    .DESCRIPTION
        Wrapper function that calls Get-ApplicationDefaults for domain template.
    #>
    [CmdletBinding()]
    param(
        [string]$DomainName = "example.com"
    )
    
    return Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
}