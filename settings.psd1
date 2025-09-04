@{
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    globalSettings = @{
        maxWaitTime = 30
        operatingSystem = 'Windows'
        configFile = '.\.secrets\config.json'
        showLicenseBanner = $false
        release = 'master'
        repoInfo = @{
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoPath = 'zuhairmahd'
            baseURL = 'https://www.github.com'
            repoName = 'Autopilot'
        }
        validateScopes = $false
        autoUpdate = $true
        appInfo = @{
            name = 'Autopilot'
            companyName = 'Zuhair Mahmoud'
            description = 'Autopilot for Windows devices'
        }
        repo = 'Github'
        maxGroupMatchDisplay = 10
        timeInSeconds = 60
        deviceContactThresholdInDays = 30
        testMode = $false
        maxUserMatchDisplay = 10
        appMode = 'full'
    }
    requiredScopes = @(
        @{
            Endpoints = @(
                '/users',
                'users/{id}',
                'users/{id}/memberOf',
                'users/{id}/registeredDevices'
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
                'deviceAppManagement/mobileApps/{id}/assignments'
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
                '/deviceManagement/managedDevices',
                'deviceManagement/managedDevices/{id}'
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
            Endpoints = @(
            )
            Reason = 'Standard scope required for user sign-in with OpenID Connect.'
            Scope = 'openid'
        },
        @{
            Endpoints = @(
            )
            Reason = 'Standard scope to get basic user profile information during sign-in.'
            Scope = 'profile'
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
            endpoints = @(
            )
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
            scope = 'offline_access'
        }
    )
    auth = @{
        validateScopes = $true
        changePwOnNextStart = $false
        noSaveRefreshToken = $false
        cacheType = 'Memory'
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
        renewalLeadTime = 5
        authType = 'PublicAuthFlow'
        secureString = $false
        delegated = $true
        forceNewToken = $false
    }
    version = '1.3.0.0'
}
