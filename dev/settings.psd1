@{
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version = '1.3.0.0'
    auth = @{
        changePwOnNextStart = $false
        authType = 'PublicAuthFlow'
        noSaveRefreshToken = $false
        forceNewToken = $false
        renewalLeadTime = 5
        scope = @(
            'Device.ReadWrite.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.ReadWrite.All',
            'Mail.Send',
            'DeviceManagementScripts.Read.All',
            'DeviceManagementManagedDevices.PrivilegedOperations.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        )
        cacheType = 'File'
        secureString = $false
        delegated = $true
    }
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
    repoInfo = @{
        repoName = 'Autopilot'
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL = 'https://www.github.com'
        repoPath = 'zuhairmahd'
    }
    requiredScopes = @(
        @{
            Scope = 'User.Read.All'
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
            Endpoints = @(
                '/users',
                'users/id',
                'users/id/memberOf',
                'users/id/registeredDevices'
            )
        },
        @{
            Scope = 'Device.Read.All'
            Reason = 'Required to read Microsoft Entra ID device objects.'
            Endpoints = @('devices')
        },
        @{
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Reason = 'Required to read application information and manage app assignments.'
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/id/assignments'
            )
        },
        @{
            scope = 'Mail.Send'
            reason = 'Required to send emails on behalf of the signed-in user.'
            endpoints = @('me/sendMail')
        },
        @{
            Scope = 'DeviceManagementConfiguration.Read.All'
            Reason = 'Required to read Intune device configuration policies.'
            Endpoints = @('deviceManagement/deviceConfigurations')
        },
        @{
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Reason = 'Required to read Intune managed device properties.'
            Endpoints = @(
                'deviceManagement/managedDevices',
                'deviceManagement/managedDevices/id'
            )
        },
        @{
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
            Endpoints = @('directory/deviceLocalCredentials')
        },
        @{
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
        },
        @{
            Scope = 'BitlockerKey.Read.All'
            Reason = 'Required to read BitLocker recovery keys for all devices.'
            Endpoints = @('informationProtection/bitlocker/recoveryKeys')
        },
        @{
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device configuration policies.'
            endpoints = @('deviceManagement/deviceConfigurations')
        },
        @{
            scope = 'DeviceManagementApps.Read.All'
            reason = 'Required to read application information in Intune.'
            endpoints = @('deviceAppManagement/mobileApps')
        },
        @{
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune managed device properties.'
            endpoints = @('deviceManagement/managedDevices')
        },
        @{
            scope = 'DeviceManagementScripts.Read.All'
            reason = 'Required to read Intune device management scripts.'
            endpoints = @('deviceManagement/deviceHealthScripts')
        },
        @{
            scope = 'DeviceManagementScripts.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device management scripts.'
            endpoints = @('deviceManagement/deviceHealthScripts')
        }
    )
    corporateSettings = @{
        useCorporateSettings = $false
        corporateDomain = 'arabictutor.com'
        corporateSettingsFilePaths = @(
            '\\test\folder\path',
            '\\localhost\c$\users\username\code\autopilot',
            '\\test\sysvol\Autopilot'
        )
    }
    globalSettings = @{
        configFile = '.\.secrets\config.json'
        maxWaitTime = 30
        showLicenseBanner = $false
        validateScopes = $false
        deviceContactThresholdInDays = 30
        includeEnrolledDevicesInNextUserReadiness = $true
        useGridForLogDisplay = $true
        DisplayManualFilterSelection = $false
        appModes = @('full')
        timeInSeconds = 60
        maxUserMatchDisplay = 10
        checkStrongMapping = $false
        strongMappingOptional = $true
        maxGroupMatchDisplay = 10
        maxMenuItemsPerPage = 15
        release = 'auto'
        operatingSystem = 'Windows'
        preferredBrowser = 'Chrome'
        documentationURL = 'https://github.com/zuhairmahd/Autopilot/blob/master/readme.md'
        licenseURL = 'https://github.com/zuhairmahd/Autopilot/blob/master/LICENSE'
        privateSession = $false
        migrateLegacyConfiguration = $true
        hideEmptyMenus = $true
        autoUpdate = $false
    }
}
