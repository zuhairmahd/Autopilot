@{
    version = '1.3.0.0'
    globalSettings = @{
        repo = 'Github'
        showLicenseBanner = $false
        timeInSeconds = 60
        validateScopes = $false
        configFile = '.\.secrets\config.json'
        release = 'master'
        testMode = $false
        autoUpdate = $true
        maxGroupMatchDisplay = 10
        deviceContactThresholdInDays = 30
        operatingSystem = 'Windows'
        maxUserMatchDisplay = 10
        appInfo = @{
            description = 'Autopilot for Windows devices'
            name = 'Autopilot'
            companyName = 'Zuhair Mahmoud'
        }
        maxWaitTime = 30
        repoInfo = @{
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoPath = 'zuhairmahd'
            baseURL = 'https://www.github.com'
            repoName = 'Autopilot'
        }
        appMode = 'full'
    }
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
        cacheType = 'Memory'
        changePwOnNextStart = $true
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
        delegated = $true
        noSaveRefreshToken = $false
        secureString = $false
        validateScopes = $true
        authType = 'PublicAuthFlow'
        forceNewToken = $false
    }
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
}
