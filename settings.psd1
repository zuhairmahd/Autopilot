@{
    requiredScopes = @(
        @{
            Endpoints = @(
                '/users',
                'users/id',
                'users/id/memberOf',
                'users/id/registeredDevices'
            )
            Scope = 'User.Read.All'
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
        },
        @{
            Endpoints = @('devices')
            Scope = 'Device.Read.All'
            Reason = 'Required to read Microsoft Entra ID device objects.'
        },
        @{
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/id/assignments'
            )
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Reason = 'Required to read application information and manage app assignments.'
        },
        @{
            Endpoints = @('deviceManagement/deviceConfigurations')
            Scope = 'DeviceManagementConfiguration.Read.All'
            Reason = 'Required to read Intune device configuration policies.'
        },
        @{
            Endpoints = @(
                'deviceManagement/managedDevices',
                'deviceManagement/managedDevices/id'
            )
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Reason = 'Required to read Intune managed device properties.'
        },
        @{
            Endpoints = @('directory/deviceLocalCredentials')
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Endpoints = @('informationProtection/bitlocker/recoveryKeys')
            Scope = 'BitlockerKey.Read.All'
            Reason = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            endpoints = @('deviceManagement/deviceConfigurations')
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            endpoints = @('deviceAppManagement/mobileApps')
            scope = 'DeviceManagementApps.Read.All'
            reason = 'Required to read application information in Intune.'
        },
        @{
            endpoints = @('deviceManagement/managedDevices')
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune managed device properties.'
        },
        @{
            endpoints = @('deviceManagement/deviceHealthScripts')
            scope = 'DeviceManagementScripts.Read.All'
            reason = 'Required to read Intune device management scripts.'
        },
        @{
            endpoints = @('deviceManagement/deviceHealthScripts')
            scope = 'DeviceManagementScripts.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device management scripts.'
        }
    )
    repoInfo = @{
        repoName = 'Autopilot'
        repoPath = 'zuhairmahd'
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL = 'https://www.github.com'
    }
    globalSettings = @{
        timeInSeconds = 60
        repoInfo = @{
            repoName = 'Autopilot'
            repoPath = 'zuhairmahd'
            baseSourceURL = 'https://raw.githubusercontent.com'
            baseURL = 'https://www.github.com'
        }
        checkStrongMapping = $false
        maxUserMatchDisplay = 10
        operatingSystem = 'Windows'
        maxGroupMatchDisplay = 10
        deviceContactThresholdInDays = 30
        validateScopes = $true
        autoUpdate = $false
        configFile = '.\.secrets\config.json'
        migrateLegacyConfiguration = $true
        appModes = @('full')
        release = 'auto'
        strongMappingOptional = $true
        maxMenuItemsPerPage = 15
        showLicenseBanner = $true
        privateSession = $false
        cacheSettings = @{
            maxCacheSize = 1000
            enabled = $true
            cacheTypes = @{
                Configuration = @{
                    enabled = $true
                    expirationMinutes = 60
                }
                DirectoryObjects = @{
                    enabled = $true
                    expirationMinutes = 15
                }
                Devices = @{
                    enabled = $true
                    expirationMinutes = 15
                }
            }
            defaultExpirationMinutes = 15
        }
        maxWaitTime = 30
    }
    auth = @{
        cacheType = 'Memory'
        authType = 'PublicAuthFlow'
        delegated = $true
        renewalLeadTime = 5
        changePwOnNextStart = $false
        forceNewToken = $false
        secureString = $false
        scope = @(
            'Device.ReadWrite.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.ReadWrite.All',
            'DeviceManagementScripts.Read.All',
            'DeviceManagementManagedDevices.PrivilegedOperations.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        )
        noSaveRefreshToken = $false
    }
    cacheSettings = @{
        maxCacheSize = 1000
        enabled = $true
        cacheTypes = @{
            Configuration = @{
                enabled = $true
                expirationMinutes = 60
            }
            DirectoryObjects = @{
                enabled = $true
                expirationMinutes = 15
            }
            Devices = @{
                enabled = $true
                expirationMinutes = 15
            }
        }
        defaultExpirationMinutes = 15
    }
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version = '1.3.0.0'
}
