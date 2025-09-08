@{
    requiredScopes = @(
        @{
            Reason = 'Required to read user profiles, group memberships, and registered devices.'
            Scope = 'User.Read.All'
            Endpoints = @(
                '/users',
                'users/{id}',
                'users/{id}/memberOf',
                'users/{id}/registeredDevices'
            )
        },
        @{
            Reason = 'Required to read Microsoft Entra ID device objects.'
            Scope = 'Device.Read.All'
            Endpoints = @(
                'devices'
            )
        },
        @{
            Reason = 'Required to read application information and manage app assignments.'
            Scope = 'DeviceManagementApps.ReadWrite.All'
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/{id}/assignments'
            )
        },
        @{
            Reason = 'Required to read Intune device configuration policies.'
            Scope = 'DeviceManagementConfiguration.Read.All'
            Endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
        },
        @{
            Reason = 'Required to read Intune managed device properties.'
            Scope = 'DeviceManagementManagedDevices.Read.All'
            Endpoints = @(
                '/deviceManagement/managedDevices',
                'deviceManagement/managedDevices/{id}'
            )
        },
        @{
            Reason = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
            Scope = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Endpoints = @(
                'directory/deviceLocalCredentials'
            )
        },
        @{
            Reason = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
            Scope = 'DeviceManagementServiceConfig.ReadWrite.All'
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
        },
        @{
            Reason = 'Required to read BitLocker recovery keys for all devices.'
            Scope = 'BitlockerKey.Read.All'
            Endpoints = @(
                'informationProtection/bitlocker/recoveryKeys'
            )
        },
        @{
            Reason = 'Standard scope required for user sign-in with OpenID Connect.'
            Scope = 'openid'
            Endpoints = @()
        },
        @{
            Reason = 'Standard scope to get basic user profile information during sign-in.'
            Scope = 'profile'
            Endpoints = @()
        },
        @{
            reason = 'Required to create, update, and delete Intune device configuration policies.'
            scope = 'DeviceManagementConfiguration.ReadWrite.All'
            endpoints = @(
                'deviceManagement/deviceConfigurations'
            )
        },
        @{
            reason = 'Required to read application information in Intune.'
            scope = 'DeviceManagementApps.Read.All'
            endpoints = @(
                'deviceAppManagement/mobileApps'
            )
        },
        @{
            reason = 'Required to create, update, and delete Intune managed device properties.'
            scope = 'DeviceManagementManagedDevices.ReadWrite.All'
            endpoints = @(
                'deviceManagement/managedDevices'
            )
        },
        @{
            reason = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
            scope = 'offline_access'
            endpoints = @()
        }
    )
    globalSettings = @{
        showLicenseBanner = $false
        configFile = '.\.secrets\config.json'
        repoInfo = @{
            baseURL = 'https://www.github.com'
            repoPath = 'zuhairmahd'
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoName = 'Autopilot'
        }
        maxGroupMatchDisplay = 10
        deviceContactThresholdInDays = 30
        timeInSeconds = 60
        operatingSystem = 'Windows'
        testMode = $false
        repo = 'Github'
        appMode = 'full'
        maxUserMatchDisplay = 10
        release = 'master'
        maxWaitTime = 30
        appInfo = @{
            name = 'Autopilot'
            description = 'Autopilot for Windows devices'
            companyName = 'Zuhair Mahmoud'
        }
        validateScopes = $false
        autoUpdate = $true
    }
    description = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    auth = @{
        delegated = $true
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
        validateScopes = $true
        changePwOnNextStart = $true
        authType = 'PublicAuthFlow'
        secureString = $false
        noSaveRefreshToken = $false
        cacheType = 'Memory'
        forceNewToken = $false
    }
    version = '1.3.0.0'
}
