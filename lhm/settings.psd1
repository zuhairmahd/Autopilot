@{
    version = '1.3.0.0'
    globalSettings = @{
        appMode = 'full'
        maxWaitTime = 30
        repo = 'Github'
        repoInfo = @{
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoPath = 'zuhairmahd'
            baseURL = 'https://www.github.com'
            repoName = 'Autopilot'
        }
        maxUserMatchDisplay = 10
        maxGroupMatchDisplay = 10
        appInfo = @{
            description = 'Autopilot for Windows devices'
            name = 'Autopilot'
            companyName = 'Zuhair Mahmoud'
        }
        showLicenseBanner = $false
        testMode = $false
        configFile = '.\.secrets\config.json'
        validateScopes = $false
        autoUpdate = $true
        release = 'master'
        deviceContactThresholdInDays = 30
        timeInSeconds = 60
        operatingSystem = 'Windows'
    }
    requiredScopes = @(
        @{
            Endpoints = @(
                '/users',
                'users/{id}',
                'users/{id}/memberOf',
                'users/{id}/registeredDevices'
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
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/{id}/assignments'
            )
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Reason = 'Required to read application information and manage app assignments.'
        },
        @{
            Endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            Scope = 'DeviceManagementConfiguration.Read.All'
            Reason = 'Required to read Intune device configuration policies.'
        },
        @{
            Endpoints = @(
                '/deviceManagement/managedDevices',
                'deviceManagement/managedDevices/{id}'
            )
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Reason = 'Required to read Intune managed device properties.'
        },
        @{
            Endpoints = @(
                'directory/deviceLocalCredentials'
            )
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Endpoints = @(
                'informationProtection/bitlocker/recoveryKeys'
            )
            Scope = 'BitlockerKey.Read.All'
            Reason = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            Endpoints = @()
            Scope = 'openid'
            Reason = 'Standard scope required for user sign-in with OpenID Connect.'
        },
        @{
            Endpoints = @()
            Scope = 'profile'
            Reason = 'Standard scope to get basic user profile information during sign-in.'
        },
        @{
            endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            reason = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            endpoints = @(
                'deviceAppManagement/mobileApps'
            )
            scope = 'DeviceManagementApps.Read.All'
            reason = 'Required to read application information in Intune.'
        },
        @{
            endpoints = @(
                'deviceManagement/managedDevices'
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
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    auth = @{
        validateScopes = $true
        secureString = $false
        authType = 'PublicAuthFlow'
        forceNewToken = $false
        cacheType = 'Memory'
        renewalLeadTime = 5
        delegated = $true
        noSaveRefreshToken = $false
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
        changePwOnNextStart = $true
    }
}
