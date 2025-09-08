@{
    requiredScopes = @(
        @{
            Scope = 'User.Read.All'
            Endpoints = @(
                '/users',
                'users/{id}',
                'users/{id}/memberOf',
                'users/{id}/registeredDevices'
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
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/{id}/assignments'
            )
            Reason = 'Required to read application information and manage app assignments.'
        },
        @{
            Scope = 'DeviceManagementConfiguration.Read.All'
            Endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            Reason = 'Required to read Intune device configuration policies.'
        },
        @{
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Endpoints = @(
                '/deviceManagement/managedDevices',
                'deviceManagement/managedDevices/{id}'
            )
            Reason = 'Required to read Intune managed device properties.'
        },
        @{
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Endpoints = @(
                'directory/deviceLocalCredentials'
            )
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Scope = 'BitlockerKey.Read.All'
            Endpoints = @(
                'informationProtection/bitlocker/recoveryKeys'
            )
            Reason = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            Scope = 'openid'
            Endpoints = @()
            Reason = 'Standard scope required for user sign-in with OpenID Connect.'
        },
        @{
            Scope = 'profile'
            Endpoints = @()
            Reason = 'Standard scope to get basic user profile information during sign-in.'
        },
        @{
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            reason = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            scope = 'DeviceManagementApps.Read.All'
            endpoints = @(
                'deviceAppManagement/mobileApps'
            )
            reason = 'Required to read application information in Intune.'
        },
        @{
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            endpoints = @(
                'deviceManagement/managedDevices'
            )
            reason = 'Required to create, update, and delete Intune managed device properties.'
        },
        @{
            scope = 'offline_access'
            endpoints = @()
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
        }
    )
    auth = @{
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
        forceNewToken = $false
        secureString = $false
        changePwOnNextStart = $true
        noSaveRefreshToken = $false
        cacheType = 'Memory'
        delegated = $true
        validateScopes = $true
        authType = 'PublicAuthFlow'
    }
    version = '1.3.0.0'
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    globalSettings = @{
        showLicenseBanner = $false
        timeInSeconds = 60
        repo = 'Github'
        appInfo = @{
            name = 'Autopilot'
            companyName = 'Zuhair Mahmoud'
            description = 'Autopilot for Windows devices'
        }
        maxGroupMatchDisplay = 10
        operatingSystem = 'Windows'
        testMode = $false
        repoInfo = @{
            repoPath = 'zuhairmahd'
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoName = 'Autopilot'
            baseURL = 'https://www.github.com'
        }
        maxWaitTime = 30
        release = 'master'
        appMode = 'full'
        configFile = '.\.secrets\config.json'
        validateScopes = $false
        autoUpdate = $true
        maxUserMatchDisplay = 10
        deviceContactThresholdInDays = 30
    }
}
