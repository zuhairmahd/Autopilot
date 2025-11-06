@{
    repoInfo = @{
        baseSourceURL = 'https://raw.githubusercontent.com'
        repoPath = 'zuhairmahd'
        baseURL = 'https://www.github.com'
        repoName = 'Autopilot'
    }
    globalSettings = @{
        cacheSettings = @{
            enabled = $true
            defaultExpirationMinutes = 15
            maxCacheSize = 1000
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
        }
        timeInSeconds = 60
        repoInfo = @{
            repoName = 'Autopilot'
            baseSourceURL = 'https://raw.githubusercontent.com'
            baseURL = 'https://www.github.com'
            repoPath = 'zuhairmahd'
        }
        deviceContactThresholdInDays = 30
        configFile = '.\.secrets\config.json'
        release = 'auto'
        maxMenuItemsPerPage = 15
        strongMappingOptional = $true
        maxGroupMatchDisplay = 10
        maxUserMatchDisplay = 10
        appModes = @('full')
        checkStrongMapping = $false
        showLicenseBanner = $true
        maxWaitTime = 30
        operatingSystem = 'Windows'
        autoUpdate = $true
        validateScopes = $true
    }
    auth = @{
        forceNewToken = $false
        delegated = $true
        changePwOnNextStart = $false
        renewalLeadTime = 5
        secureString = $false
        cacheType = 'Memory'
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
        authType = 'PublicAuthFlow'
    }
    version = '1.3.0.0'
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    cacheSettings = @{
        cacheTypes = @{
            Configuration = @{
                enabled = $true
                expirationMinutes = 60
            }
            DirectoryObjects = @{
                enabled = $true
                expirationMinutes = 5
            }
            Devices = @{
                expirationMinutes = 5
                enabled = $true
            }
        }
        enabled = $true
        defaultExpirationMinutes = 15
        maxCacheSize = 1000
    }
    requiredScopes = @(
        @{
            Endpoints = @(
                '/users',
                'users/id',
                'users/id/memberOf',
                'users/id/registeredDevices'
            )
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
            Scope = 'User.Read.All'
        },
        @{
            Endpoints = @('devices')
            Reason = 'Required to read Microsoft Entra ID device objects.'
            Scope = 'Device.Read.All'
        },
        @{
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/id/assignments'
            )
            Reason = 'Required to read application information and manage app assignments.'
            Scope = 'DeviceManagementApps.ReadWrite.All'
        },
        @{
            Endpoints = @('deviceManagement/deviceConfigurations')
            Reason = 'Required to read Intune device configuration policies.'
            Scope = 'DeviceManagementConfiguration.Read.All'
        },
        @{
            Endpoints = @(
                'deviceManagement/managedDevices',
                'deviceManagement/managedDevices/id'
            )
            Reason = 'Required to read Intune managed device properties.'
            Scope = 'DeviceManagementManagedDevices.Read.All'
        },
        @{
            Endpoints = @('directory/deviceLocalCredentials')
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
        },
        @{
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
        },
        @{
            Endpoints = @('informationProtection/bitlocker/recoveryKeys')
            Reason = 'Required to read BitLocker recovery keys for all devices.'
            Scope = 'BitlockerKey.Read.All'
        },
        @{
            endpoints = @('deviceManagement/deviceConfigurations')
            reason = 'Required to create, update, and delete Intune device configuration policies.'
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
        },
        @{
            endpoints = @('deviceAppManagement/mobileApps')
            reason = 'Required to read application information in Intune.'
            scope = 'DeviceManagementApps.Read.All'
        },
        @{
            endpoints = @('deviceManagement/managedDevices')
            reason = 'Required to create, update, and delete Intune managed device properties.'
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
        },
        @{
            endpoints = @('deviceManagement/deviceHealthScripts')
            reason = 'Required to read Intune device management scripts.'
            scope = 'DeviceManagementScripts.Read.All'
        },
        @{
            endpoints = @('deviceManagement/deviceHealthScripts')
            reason = 'Required to create, update, and delete Intune device management scripts.'
            scope = 'DeviceManagementScripts.ReadWrite.All'
        }
    )
}
