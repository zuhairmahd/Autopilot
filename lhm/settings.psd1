@{
    auth = @{
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
        delegated = $true
        cacheType = 'Memory'
        validateScopes = $true
        authType = 'PublicAuthFlow'
        secureString = $false
        changePwOnNextStart = $true
        forceNewToken = $false
        noSaveRefreshToken = $false
        renewalLeadTime = 5
    }
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    globalSettings = @{
        timeInSeconds = 60
        maxGroupMatchDisplay = 10
        autoUpdate = $true
        repoInfo = @{
            baseURL = 'https://www.github.com'
            repoPath = 'zuhairmahd'
            repoName = 'Autopilot'
            baseSourceURL = 'https://raw.githubusercontent.com'
        }
        appMode = 'full'
        maxUserMatchDisplay = 10
        showLicenseBanner = $false
        validateScopes = $false
        testMode = $false
        maxWaitTime = 30
        repo = 'Github'
        configFile = '.\.secrets\config.json'
        release = 'master'
        operatingSystem = 'Windows'
        appInfo = @{
            name = 'Autopilot'
            description = 'Autopilot for Windows devices'
            companyName = 'Zuhair Mahmoud'
        }
        deviceContactThresholdInDays = 30
    }
    version = '1.3.0.0'
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
}
