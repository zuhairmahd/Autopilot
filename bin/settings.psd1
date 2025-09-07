@{
    globalSettings = @{
        deviceContactThresholdInDays = 30
        validateScopes = $false
        appMode = 'full'
        operatingSystem = 'Windows'
        testMode = $false
        release = 'master'
        maxUserMatchDisplay = 10
        showLicenseBanner = $false
        configFile = '.\.secrets\config.json'
        autoUpdate = $true
        maxGroupMatchDisplay = 10
        repo = 'Github'
        appInfo = @{
            description = 'Autopilot for Windows devices'
            companyName = 'Zuhair Mahmoud'
            name = 'Autopilot'
        }
        repoInfo = @{
            repoName = 'Autopilot'
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoPath = 'zuhairmahd'
            baseURL = 'https://www.github.com'
        }
        maxWaitTime = 30
        timeInSeconds = 60
    }
    auth = @{
        noSaveRefreshToken = $false
        cacheType = 'Memory'
        delegated = $true
        changePwOnNextStart = $true
        forceNewToken = $false
        authType = 'PublicAuthFlow'
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
        secureString = $false
        validateScopes = $true
        renewalLeadTime = 5
    }
    requiredScopes = @(
        @{
            Scope = 'User.Read.All'
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
            Endpoints = @(
                '/users',
                'users/{id}',
                'users/{id}/memberOf',
                'users/{id}/registeredDevices'
            )
        },
        @{
            Scope = 'Device.Read.All'
            Reason = 'Required to read Microsoft Entra ID device objects.'
            Endpoints = @(
                'devices'
            )
        },
        @{
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Reason = 'Required to read application information and manage app assignments.'
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/{id}/assignments'
            )
        },
        @{
            Scope = 'DeviceManagementConfiguration.Read.All'
            Reason = 'Required to read Intune device configuration policies.'
            Endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
        },
        @{
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Reason = 'Required to read Intune managed device properties.'
            Endpoints = @(
                '/deviceManagement/managedDevices',
                'deviceManagement/managedDevices/{id}'
            )
        },
        @{
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
            Endpoints = @(
                'directory/deviceLocalCredentials'
            )
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
            Endpoints = @(
                'informationProtection/bitlocker/recoveryKeys'
            )
        },
        @{
            Scope = 'openid'
            Reason = 'Standard scope required for user sign-in with OpenID Connect.'
            Endpoints = @()
        },
        @{
            Scope = 'profile'
            Reason = 'Standard scope to get basic user profile information during sign-in.'
            Endpoints = @()
        },
        @{
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device configuration policies.'
            endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
        },
        @{
            scope = 'DeviceManagementApps.Read.All'
            reason = 'Required to read application information in Intune.'
            endpoints = @(
                'deviceAppManagement/mobileApps'
            )
        },
        @{
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune managed device properties.'
            endpoints = @(
                'deviceManagement/managedDevices'
            )
        },
        @{
            scope = 'offline_access'
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
            endpoints = @()
        }
    )
    version = '1.3.0.0'
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
}
