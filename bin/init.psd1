@(
    @{
        'description' = 'The path to the authentication configuration file.'
        'reldefault' = '.\\.secrets\\config.json'
        'value' = '.\\.secrets\\config.json'
        'name' = 'configFile'
        'default' = '.\\.secrets\\config.json'
        'type' = 'string'
        'devdefault' = '.\\.secrets\\config.json'
    },
    @{
        'description' = 'The path to the configuration file.'
        'reldefault' = 'settings.json'
        'value' = 'settings.json'
        'name' = 'configuration'
        'default' = 'settings.json'
        'type' = 'string'
        'devdefault' = 'settings.json'
    },
    @{
        'description' = 'The Autopilot group tag.'
        'reldefault' = 'MSB01'
        'value' = 'MSB01'
        'name' = 'GroupTag'
        'default' = ''
        'type' = 'string'
        'devdefault' = 'MSB01'
    },
    @{
        'description' = 'How long to wait before giving up on importing a device.'
        'reldefault' = '60'
        'value' = '60'
        'name' = 'maxWaitTime'
        'default' = '30'
        'type' = 'string'
        'devdefault' = '60'
    },
    @{
        'description' = 'How long to wait before initiating another check.'
        'reldefault' = '60'
        'value' = '60'
        'name' = 'timeInSeconds'
        'default' = '30'
        'type' = 'string'
        'devdefault' = '60'
    },
    @{
        'description' = 'The repository provider to use.'
        'reldefault' = 'Github'
        'value' = @(
            'Github',
            'Gitlab'
        )
        'name' = 'Repo'
        'default' = 'Github'
        'type' = 'array'
        'devdefault' = 'Github'
    },
    @{
        'description' = 'The release branch to use.'
        'reldefault' = '2.2'
        'value' = '2.2'
        'name' = 'Release'
        'default' = 'main'
        'type' = 'string'
        'devdefault' = 'main'
    },
    @{
        'description' = 'The operating system of the devices you are working with'
        'reldefault' = 'Windows'
        'value' = 'Windows'
        'name' = 'operatingSystem'
        'default' = 'Windows'
        'type' = 'string'
        'devdefault' = 'Windows'
    },
    @{
        'description' = 'Whether to show the license banner at the start of the script.'
        'reldefault' = 'true'
        'value' = @(
            'true',
            'false'
        )
        'name' = 'showLicenseBanner'
        'default' = 'true'
        'type' = 'array'
        'devdefault' = 'true'
    },
    @{
        'description' = 'Whether to run the script in test mode.'
        'reldefault' = 'false'
        'value' = @(
            'true',
            'false'
        )
        'name' = 'testMode'
        'default' = 'false'
        'type' = 'array'
        'devdefault' = 'false'
    },
    @{
        'description' = 'The app mode in which the script will run'
        'reldefault' = 'helpdesk'
        'value' = @(
            'helpdesk',
            'full',
            'registration'
        )
        'name' = 'appMode'
        'default' = 'helpdesk'
        'type' = 'array'
        'devdefault' = 'full'
    },
    @{
        'description' = 'The domain of the Microsoft Entra ID tenant.'
        'reldefault' = 'contoso.com'
        'value' = 'contoso.com'
        'name' = 'domain'
        'default' = 'contoso.com'
        'type' = 'string'
        'devdefault' = 'contoso.com'
    },
    @{
        'description' = 'The prefix for the device names in Autopilot.'
        'reldefault' = 'Autopilot-'
        'value' = 'Autopilot-'
        'name' = 'deviceNamePrefix'
        'default' = 'Autopilot-'
        'type' = 'string'
        'devdefault' = 'Autopilot-'
    },
    @{
        'description' = 'The maximum number of devices allowed per user.'
        'reldefault' = '15'
        'value' = '15'
        'name' = 'maxNumberOfDevicesAllowed'
        'default' = '15'
        'type' = 'string'
        'devdefault' = '15'
    },
    @{
        'description' = 'The maximum length of the username.'
        'reldefault' = '20'
        'value' = '20'
        'name' = 'MaxUserNameLength'
        'default' = '20'
        'type' = 'string'
        'devdefault' = '20'
    },
    @{
        'description' = 'The maximum length of the serial number.'
        'reldefault' = '100'
        'value' = '100'
        'name' = 'MaxSerialNumberLength'
        'default' = '100'
        'type' = 'string'
        'devdefault' = '100'
    },
    @{
        'description' = 'The minimum length of the serial number.'
        'reldefault' = '7'
        'value' = '7'
        'name' = 'MinSerialNumberLength'
        'default' = '7'
        'type' = 'string'
        'devdefault' = '7'
    },
    @{
        'description' = 'The preferred browser to use for web interactions.'
        'reldefault' = 'Edge'
        'value' = @(
            'Edge',
            'Chrome',
            'Firefox'
        )
        'name' = 'preferredBrowser'
        'default' = 'Edge'
        'type' = 'array'
        'devdefault' = 'Edge'
    },
    @{
        'description' = 'Whether to use a private session for web interactions.'
        'reldefault' = 'true'
        'value' = @(
            'true',
            'false'
        )
        'name' = 'privateSession'
        'default' = 'true'
        'type' = 'array'
        'devdefault' = 'true'
    },
    @{
        'description' = 'The minimum physical memory required for devices.'
        'reldefault' = '16'
        'value' = '16'
        'name' = 'MinimumDevicePhysicalMemoryInGB'
        'default' = '16'
        'type' = 'string'
        'devdefault' = '16'
    },
    @{
        'description' = 'The minimum length of the username.'
        'reldefault' = '3'
        'value' = '3'
        'name' = 'MinUsernameLength'
        'default' = '3'
        'type' = 'string'
        'devdefault' = '3'
    },
    @{
        'value' = @(
            'test',
            'support',
            '-cma',
            '-test',
            'onmicrosoft.com',
            '-a',
            '-sup'
        )
        'name' = 'userPatternsToExclude'
    },
    @{
        'description' = 'The desired Autopilot profiles to assign to devices.'
        'reldefault' = @(
            'AutopilotProfile1',
            'AutopilotProfile2'
        )
        'value' = @(
            'AutopilotProfile1',
            'AutopilotProfile2'
        )
        'name' = 'DesiredAutopilotProfiles'
        'default' = @(
            'AutopilotProfile1',
            'AutopilotProfile2'
        )
        'type' = 'array'
        'devdefault' = @(
            'AutopilotProfile1',
            'AutopilotProfile2'
        )
    },
    @{
        'description' = 'The groups to include in the Autopilot device assignment.'
        'reldefault' = @(
        )
        'value' = @(
        )
        'name' = 'groupsToInclude'
        'default' = @(
        )
        'type' = 'array'
        'devdefault' = @(
        )
    },
    @{
        'description' = 'The groups to exclude from the Autopilot device assignment.'
        'reldefault' = @(
        )
        'value' = @(
        )
        'name' = 'groupsToExclude'
        'default' = @(
        )
        'type' = 'array'
        'devdefault' = @(
        )
    },
    @{
        'description' = 'The device management applications to use.'
        'reldefault' = @(
            'Intune',
            'Microsoft Entra ID'
        )
        'value' = @(
            'Intune',
            'Microsoft Entra ID'
        )
        'name' = 'deviceManagementApps'
        'default' = @(
            'Intune',
            'Microsoft Entra ID'
        )
        'type' = 'array'
        'devdefault' = @(
            'Intune',
            'Microsoft Entra ID'
        )
    },
    @{
        'description' = 'The required scopes for the script to function correctly.'
        'reldefault' = @(
            @{
                'Scope' = 'User.Read.All'
                'Reason' = 'Required to read user profiles, group memberships, and registered devices.'
                'Endpoints' = @(
                    '/users',
                    'users/{id}',
                    'users/{id}/memberOf',
                    'users/{id}/registeredDevices'
                )
            },
            @{
                'Scope' = 'Device.Read.All'
                'Reason' = 'Required to read Microsoft Entra ID device objects.'
                'Endpoints' = @(
                    'devices'
                )
            },
            @{
                'Scope' = 'DeviceManagementApps.ReadWrite.All'
                'Reason' = 'Required to read application information and manage app assignments.'
                'Endpoints' = @(
                    'deviceAppManagement/mobileApps',
                    'deviceAppManagement/mobileApps/{id}/assignments'
                )
            },
            @{
                'Scope' = 'DeviceManagementConfiguration.Read.All'
                'Reason' = 'Required to read Intune device configuration policies.'
                'Endpoints' = @(
                    'deviceManagement/deviceConfigurations'
                )
            },
            @{
                'Scope' = 'DeviceManagementManagedDevices.Read.All'
                'Reason' = 'Required to read Intune managed device properties.'
                'Endpoints' = @(
                    '/deviceManagement/managedDevices',
                    'deviceManagement/managedDevices/{id}'
                )
            },
            @{
                'Scope' = ''
                'Reason' = ''
                'Endpoints' = @(
                )
            }
        )
        'value' = @(
            @{
                'Scope' = 'User.Read.All'
                'Reason' = 'Required to read user profiles, group memberships, and registered devices.'
                'Endpoints' = @(
                    '/users',
                    'users/{id}',
                    'users/{id}/memberOf',
                    'users/{id}/registeredDevices'
                )
            },
            @{
                'Scope' = 'Device.Read.All'
                'Reason' = 'Required to read Microsoft Entra ID device objects.'
                'Endpoints' = @(
                    'devices'
                )
            },
            @{
                'Scope' = 'DeviceManagementApps.ReadWrite.All'
                'Reason' = 'Required to read application information and manage app assignments.'
                'Endpoints' = @(
                    'deviceAppManagement/mobileApps',
                    'deviceAppManagement/mobileApps/{id}/assignments'
                )
            },
            @{
                'Scope' = 'DeviceManagementConfiguration.Read.All'
                'Reason' = 'Required to read Intune device configuration policies.'
                'Endpoints' = @(
                    'deviceManagement/deviceConfigurations'
                )
            },
            @{
                'Scope' = 'DeviceManagementManagedDevices.Read.All'
                'Reason' = 'Required to read Intune managed device properties.'
                'Endpoints' = @(
                    '/deviceManagement/managedDevices',
                    'deviceManagement/managedDevices/{id}'
                )
            },
            @{
                'Scope' = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
                'Reason' = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
                'Endpoints' = @(
                    'directory/deviceLocalCredentials'
                )
            },
            @{
                'Scope' = 'DeviceManagementServiceConfig.ReadWrite.All'
                'Reason' = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
                'Endpoints' = @(
                    'deviceManagement/autopilotEvents',
                    'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                    'deviceManagement/windowsAutopilotDeviceIdentities'
                )
            },
            @{
                'Scope' = 'BitlockerKey.Read.All'
                'Reason' = 'Required to read BitLocker recovery keys for all devices.'
                'Endpoints' = @(
                    'informationProtection/bitlocker/recoveryKeys'
                )
            },
            @{
                'Scope' = 'openid'
                'Reason' = 'Standard scope required for user sign-in with OpenID Connect.'
                'Endpoints' = @(
                )
            },
            @{
                'Scope' = 'profile'
                'Reason' = 'Standard scope to get basic user profile information during sign-in.'
                'Endpoints' = @(
                )
            },
            @{
                'Scope' = 'offline_access'
                'Reason' = 'Standard scope that provides refresh tokens to maintain access when the user is not active.'
                'Endpoints' = @(
                )
            }
        )
        'name' = 'requiredScopes'
        'default' = @(
            @{
                'Scope' = 'User.Read.All'
                'Reason' = 'Required to read user profiles, group memberships, and registered devices.'
                'Endpoints' = @(
                    '/users',
                    'users/{id}',
                    'users/{id}/memberOf',
                    'users/{id}/registeredDevices'
                )
            },
            @{
                'Scope' = 'Device.Read.All'
                'Reason' = 'Required to read Microsoft Entra ID device objects.'
                'Endpoints' = @(
                    'devices'
                )
            },
            @{
                'Scope' = 'DeviceManagementApps.ReadWrite.All'
                'Reason' = 'Required to read application information and manage app assignments.'
                'Endpoints' = @(
                    'deviceAppManagement/mobileApps',
                    'deviceAppManagement/mobileApps/{id}/assignments'
                )
            },
            @{
                'Scope' = 'DeviceManagementConfiguration.Read.All'
                'Reason' = 'Required to read Intune device configuration policies.'
                'Endpoints' = @(
                    'deviceManagement/deviceConfigurations'
                )
            },
            @{
                'Scope' = ''
                'Reason' = ''
                'Endpoints' = @(
                )
            }
        )
        'type' = 'array'
        'devdefault' = @(
            @{
                'Scope' = 'User.Read.All'
                'Reason' = 'Required to read user profiles, group memberships, and registered devices.'
                'Endpoints' = @(
                    '/users',
                    'users/{id}',
                    'users/{id}/memberOf',
                    'users/{id}/registeredDevices'
                )
            },
            @{
                'Scope' = 'Device.Read.All'
                'Reason' = 'Required to read Microsoft Entra ID device objects.'
                'Endpoints' = @(
                    'devices'
                )
            },
            @{
                'Scope' = 'DeviceManagementApps.ReadWrite.All'
                'Reason' = 'Required to read application information and manage app assignments.'
                'Endpoints' = @(
                    'deviceAppManagement/mobileApps',
                    'deviceAppManagement/mobileApps/{id}/assignments'
                )
            },
            @{
                'Scope' = 'DeviceManagementConfiguration.Read.All'
                'Reason' = 'Required to read Intune device configuration policies.'
                'Endpoints' = @(
                    'deviceManagement/deviceConfigurations'
                )
            },
            @{
                'Scope' = 'DeviceManagementManagedDevices.Read.All'
                'Reason' = 'Required to read Intune managed device properties.'
                'Endpoints' = @(
                    '/deviceManagement/managedDevices',
                    'deviceManagement/managedDevices/{id}'
                )
            },
            @{
                'Scope' = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
                'Reason' = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
                'Endpoints' = @(
                    'directory/deviceLocalCredentials'
                )
            },
            @{
                'Scope' = 'DeviceManagementServiceConfig.ReadWrite.All'
                'Reason' = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
                'Endpoints' = @(
                    'deviceManagement/autopilotEvents',
                    'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                    'deviceManagement/windowsAutopilotDeviceIdentities'
                )
            },
            @{
                'Scope' = 'BitlockerKey.Read.All'
                'Reason' = 'Required to read BitLocker recovery keys for all devices.'
                'Endpoints' = @(
                    'informationProtection/bitlocker/recoveryKeys'
                )
            },
            @{
                'Scope' = 'openid'
                'Reason' = ''
                'Endpoints' = @(
                )
            },
            @{
                'Scope' = ''
                'Reason' = ''
                'Endpoints' = @(
                )
            }
        )
    }
)
