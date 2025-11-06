@{
    globalSettings = @{
        operatingSystem              = 'Windows'
        repoInfo                     = @{
            repoPath      = 'zuhairmahd'
            baseURL       = 'https://www.github.com'
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoName      = 'Autopilot'
        }
        timeInSeconds                = 60
        testMode                     = $false
        maxUserMatchDisplay          = 10
        maxWaitTime                  = 30
        appModes                     = @(
            'full'
        )
        showLicenseBanner            = $false
        autoUpdate                   = $true
        strongMappingOptional        = $true
        validateScopes               = $false
        maxGroupMatchDisplay         = 10
        maxMenuItemsPerPage          = 15
        release                      = 'master'
        checkStrongMapping           = $false
        configFile                   = '.\.secrets\config.json'
        deviceContactThresholdInDays = 30
        cacheSettings                = @{
            enabled                  = $true
            defaultExpirationMinutes = 15
            maxCacheSize             = 1000
            cacheTypes               = @{
                Configuration    = @{
                    enabled           = $true
                    expirationMinutes = 60
                }
                DirectoryObjects = @{
                    enabled           = $true
                    expirationMinutes = 15
                }
                Devices          = @{
                    enabled           = $true
                    expirationMinutes = 15
                }
            }
        }
    }
    description    = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version        = '1.3.0.0'
    requiredScopes = @(
        @{
            Scope     = 'User.Read.All'
            Endpoints = @(
                '/users',
                'users/{id}',
                'users/{id}/memberOf',
                'users/{id}/registeredDevices'
            )
            Reason    = 'Required to read user profiles, group memberships, and registered devices.'
        },
        @{
            Scope     = 'Device.Read.All'
            Endpoints = @(
                'devices'
            )
            Reason    = 'Required to read Microsoft Entra ID device objects.'
        },
        @{
            Scope     = 'DeviceManagementApps.ReadWrite.All'
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/{id}/assignments'
            )
            Reason    = 'Required to read application information and manage app assignments.'
        },
        @{
            Scope     = 'DeviceManagementConfiguration.Read.All'
            Endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            Reason    = 'Required to read Intune device configuration policies.'
        },
        @{
            Scope     = 'DeviceManagementManagedDevices.Read.All'
            Endpoints = @(
                '/deviceManagement/managedDevices',
                'deviceManagement/managedDevices/{id}'
            )
            Reason    = 'Required to read Intune managed device properties.'
        },
        @{
            Scope     = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Endpoints = @(
                'directory/deviceLocalCredentials'
            )
            Reason    = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            scope     = "DeviceManagementScripts.Read.All"
            reason    = "Required to read Intune device management scripts."
            endpoints = @(
                "deviceManagement/deviceHealthScripts"
            )
        },
        @{
            scope     = "DeviceManagementScripts.ReadWrite.All"
            reason    = "Required to create, update, and delete Intune device management scripts."
            endpoints = @(
                "deviceManagement/deviceHealthScripts"
            )
        },
        @{
            Scope     = 'DeviceManagementServiceConfig.ReadWrite.All'
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
            Reason    = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Scope     = 'BitlockerKey.Read.All'
            Endpoints = @(
                'informationProtection/bitlocker/recoveryKeys'
            )
            Reason    = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            scope     = 'DeviceManagementConfiguration.ReadWrite.All'
            endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            reason    = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            scope     = 'DeviceManagementApps.Read.All'
            endpoints = @(
                'deviceAppManagement/mobileApps'
            )
            reason    = 'Required to read application information in Intune.'
        },
        @{
            scope     = 'DeviceManagementManagedDevices.ReadWrite.All'
            endpoints = @(
                'deviceManagement/managedDevices'
            )
            reason    = 'Required to create, update, and delete Intune managed device properties.'
        }
    )
    auth           = @{
        changePwOnNextStart = $false
        validateScopes      = $true
        authType            = 'PublicAuthFlow'
        noSaveRefreshToken  = $false
        forceNewToken       = $false
        scope               = @(
            'offline_access',
            'openid',
            'Device.ReadWrite.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.ReadWrite.All',
            'DeviceManagementManagedDevices.PrivilegedOperations.All',
            'DeviceManagementScripts.Read.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        )
        delegated           = $true
        cacheType           = 'Memory'
        secureString        = $false
        renewalLeadTime     = 5
    }
}
