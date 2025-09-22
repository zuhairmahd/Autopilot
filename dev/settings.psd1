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
            'offline_access',
            'openid',
            'Device.ReadWrite.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.ReadWrite.All',
            'DeviceManagementManagedDevices.PrivilegedOperations.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        )
        cacheType = 'Memory'
        secureString = $false
        delegated = $false
    }
    requiredScopes = @(
        @{
            Endpoints = @(
                '/ users',
                'users /`r`n                {`r`n                    id`r`n                }',
                'users /`r`n                {`r`n                    id`r`n                } / memberOf',
                'users /`r`n                {`r`n                    id`r`n                } / registeredDevices'
            )
            Scope = 'User.Read.All'
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
        },
        @{
            Endpoints = @(
                'devices'
            )
            Scope = 'Device.Read.All'
            Reason = 'Required to read Microsoft Entra ID device objects.'
        },
        @{
            Endpoints = @(
                'deviceAppManagement / mobileApps',
                'deviceAppManagement / mobileApps /`r`n                {`r`n                    id`r`n                } / assignments'
            )
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Reason = 'Required to read application information and manage app assignments.'
        },
        @{
            Endpoints = @(
                'deviceManagement / deviceConfigurations'
            )
            Scope = 'DeviceManagementConfiguration.Read.All'
            Reason = 'Required to read Intune device configuration policies.'
        },
        @{
            Endpoints = @(
                '/ deviceManagement / managedDevices',
                'deviceManagement / managedDevices /`r`n                {`r`n                    id`r`n                }'
            )
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Reason = 'Required to read Intune managed device properties.'
        },
        @{
            Endpoints = @(
                'directory / deviceLocalCredentials'
            )
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            Endpoints = @(
                'deviceManagement / autopilotEvents',
                'deviceManagement / importedWindowsAutopilotDeviceIdentities',
                'deviceManagement / windowsAutopilotDeviceIdentities'
            )
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Endpoints = @(
                'informationProtection / bitlocker / recoveryKeys'
            )
            Scope = 'BitlockerKey.Read.All'
            Reason = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            Endpoints = @()
            Scope = 'openid'
            Reason = 'Standard scope required for user sign -in with OpenID Connect.'
        },
        @{
            Endpoints = @()
            Scope = 'profile'
            Reason = 'Standard scope to get basic user profile information during sign -in .'
        },
        @{
            endpoints = @(
                'deviceManagement / deviceConfigurations'
            )
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            endpoints = @(
                'deviceAppManagement / mobileApps'
            )
            scope = 'DeviceManagementApps.Read.All'
            reason = 'Required to read application information in Intune.'
        },
        @{
            endpoints = @(
                'deviceManagement / managedDevices'
            )
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune managed device properties.'
        },
        @{
            endpoints = @()
            scope = 'offline_access'
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
        }
    )
    globalSettings = @{
        configFile = '.\.secrets\config.json'
        maxWaitTime = 30
        showLicenseBanner = $false
        validateScopes = $false
        deviceContactThresholdInDays = 30
        appMode = 'full'
        timeInSeconds = 60
        maxUserMatchDisplay = 10
        checkStrongMapping = $false
        strongMappingOptional = $true
        maxGroupMatchDisplay = 10
        release = 'auto'
        repoInfo = @{
            repoName = 'Autopilot'
            repoPath = 'zuhairmahd'
            baseSourceURL = 'https://raw.githubusercontent.com'
            baseURL = 'https://www.github.com'
        }
        testMode = $false
        operatingSystem = 'Windows'
        autoUpdate = $false
    }
}
