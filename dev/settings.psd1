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
                '/users',
                'users/id',
                'users/id/memberOf',
                'users/id/registeredDevices'
            )
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
            Scope = 'User.Read.All'
        },
        @{
            Endpoints = @(
                'devices'
            )
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
            Endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
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
            Endpoints = @(
                'directory/deviceLocalCredentials'
            )
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
            Endpoints = @(
                'informationProtection/bitlocker/recoveryKeys'
            )
            Reason = 'Required to read BitLocker recovery keys for all devices.'
            Scope = 'BitlockerKey.Read.All'
        },
        @{
            endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            reason = 'Required to create, update, and delete Intune device configuration policies.'
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
        },
        @{
            endpoints = @(
                'deviceAppManagement/mobileApps'
            )
            reason = 'Required to read application information in Intune.'
            scope = 'DeviceManagementApps.Read.All'
        },
        @{
            endpoints = @(
                'deviceManagement/managedDevices'
            )
            reason = 'Required to create, update, and delete Intune managed device properties.'
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
        },
        @{
            Endpoints = @()
            Reason = 'Standard scope required for user sign -in with OpenID Connect.'
            Scope = 'openid'
        },
        @{
            Endpoints = @()
            Reason = 'Standard scope to get basic user profile information during sign -in .'
            Scope = 'profile'
        },
        @{
            endpoints = @()
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
            scope = 'offline_access'
        }
    )
    globalSettings = @{
        configFile = '.\.secrets\config.json'
        maxWaitTime = 30
        showLicenseBanner = $false
        validateScopes = $false
        deviceContactThresholdInDays = 30
        appModes = @(
            'full'
        )
        timeInSeconds = 60
        maxUserMatchDisplay = 10
        checkStrongMapping = $false
        strongMappingOptional = $true
        maxGroupMatchDisplay = 10
        release = 'auto'
        repoInfo = @{
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoName = 'Autopilot'
            repoPath = 'zuhairmahd'
            baseURL = 'https://www.github.com'
        }
        operatingSystem = 'Windows'
        autoUpdate = $false
    }
}
