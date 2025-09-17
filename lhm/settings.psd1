@{
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version = '1.3.0.0'
    auth = @{
        changePwOnNextStart = $true
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
        validateScopes = $false
    }
    requiredScopes = @(
        @{
            Scope = 'User.Read.All'
            Endpoints = @(
                '/ users',
                'users /`r`n                {`r`n                    id`r`n                }',
                'users /`r`n                {`r`n                    id`r`n                } / memberOf',
                'users /`r`n                {`r`n                    id`r`n                } / registeredDevices'
            )
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
        },
        @{
            Scope = 'Device.Read.All'
            Endpoints = @(
                'devices'
            )
            Reason = 'Required to read Microsoft Entra ID device objects.'
        },
        @{
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Endpoints = @(
                'deviceAppManagement / mobileApps',
                'deviceAppManagement / mobileApps /`r`n                {`r`n                    id`r`n                } / assignments'
            )
            Reason = 'Required to read application information and manage app assignments.'
        },
        @{
            Scope = 'DeviceManagementConfiguration.Read.All'
            Endpoints = @(
                'deviceManagement / deviceConfigurations'
            )
            Reason = 'Required to read Intune device configuration policies.'
        },
        @{
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Endpoints = @(
                '/ deviceManagement / managedDevices',
                'deviceManagement / managedDevices /`r`n                {`r`n                    id`r`n                }'
            )
            Reason = 'Required to read Intune managed device properties.'
        },
        @{
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Endpoints = @(
                'directory / deviceLocalCredentials'
            )
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Endpoints = @(
                'deviceManagement / autopilotEvents',
                'deviceManagement / importedWindowsAutopilotDeviceIdentities',
                'deviceManagement / windowsAutopilotDeviceIdentities'
            )
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Scope = 'BitlockerKey.Read.All'
            Endpoints = @(
                'informationProtection / bitlocker / recoveryKeys'
            )
            Reason = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            Scope = 'openid'
            Endpoints = @()
            Reason = 'Standard scope required for user sign -in with OpenID Connect.'
        },
        @{
            Scope = 'profile'
            Endpoints = @()
            Reason = 'Standard scope to get basic user profile information during sign -in .'
        },
        @{
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            endpoints = @(
                'deviceManagement / deviceConfigurations'
            )
            reason = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            scope = 'DeviceManagementApps.Read.All'
            endpoints = @(
                'deviceAppManagement / mobileApps'
            )
            reason = 'Required to read application information in Intune.'
        },
        @{
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            endpoints = @(
                'deviceManagement / managedDevices'
            )
            reason = 'Required to create, update, and delete Intune managed device properties.'
        },
        @{
            scope = 'offline_access'
            endpoints = @()
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
        }
    )
    globalSettings = @{
        configFile = '.\.secrets\config.json'
        maxWaitTime = 30
        showLicenseBanner = $true
        validateScopes = $false
        deviceContactThresholdInDays = 30
        appMode = 'full'
        timeInSeconds = 60
        maxUserMatchDisplay = 10
        maxGroupMatchDisplay = 10
        release = 'auto'
        repoInfo = @{
            repoPath = 'zuhairmahd'
            baseURL = 'https://www.github.com'
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoName = 'Autopilot'
        }
        testMode = $false
        operatingSystem = 'Windows'
        autoUpdate = $true
    }
}
