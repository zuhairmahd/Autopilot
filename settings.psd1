@{
    description       = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version           = '1.3.0.0'
    cacheSettings     = @{
        maxCacheSize             = 1000
        defaultExpirationMinutes = 15
        cacheTypes               = @{
            Configuration    = @{
                expirationMinutes = 60
                enabled           = $true
            }
            DirectoryObjects = @{
                expirationMinutes = 15
                enabled           = $true
            }
            Devices          = @{
                expirationMinutes = 15
                enabled           = $true
            }
        }
        enabled                  = $true
    }
    globalSettings    = @{
        migrateLegacyConfiguration                = $true
        operatingSystem                           = 'Windows'
        documentationURL                          = 'https://github.com/zuhairmahd/Autopilot/blob/master/readme.md'
        timeInSeconds                             = 60
        maxMenuItemsPerPage                       = 15
        maxUserMatchDisplay                       = 10
        maxWaitTime                               = 30
        appModes                                  = @('full')
        autoUpdate                                = $true
        strongMappingOptional                     = $true
        preferredBrowser                          = 'Chrome'
        validateScopes                            = $true
        licenseURL                                = 'https://github.com/zuhairmahd/Autopilot/blob/master/LICENSE'
        maxGroupMatchDisplay                      = 10
        useGridForLogDisplay                      = $true
        hideEmptyMenus                            = $true
        privateSession                            = $false
        DisplayManualFilterSelection              = $false
        release                                   = 'auto'
        checkStrongMapping                        = $false
        includeEnrolledDevicesInNextUserReadiness = $true
        configFile                                = '.\.secrets\config.json'
        showLicenseBanner                         = $true
        deviceContactThresholdInDays              = 30
    }
    repoInfo          = @{
        repoPath      = 'zuhairmahd'
        baseURL       = 'https://www.github.com'
        baseSourceURL = 'https://raw.githubusercontent.com'
        repoName      = 'Autopilot'
    }
    corporateSettings = @{
        useCorporateSettings       = $false
        corporateDomain            = ''    
        corporateSettingsFilePaths = @()
    }
    requiredScopes    = @(
        @{
            Scope     = 'User.Read.All'
            Endpoints = @(
                '/users',
                'users/id',
                'users/id/memberOf',
                'users/id/registeredDevices'
            )
            Reason    = 'Required to read user profiles, group memberships, and registered devices.'
        },
        @{
            Scope     = 'Device.Read.All'
            Endpoints = @('devices')
            Reason    = 'Required to read Microsoft Entra ID device objects.'
        },
        @{
            Scope     = 'DeviceManagementApps.ReadWrite.All'
            Endpoints = @(
                'deviceAppManagement/mobileApps',
                'deviceAppManagement/mobileApps/id/assignments'
            )
            Reason    = 'Required to read application information and manage app assignments.'
        },
        @{
            Scope     = 'Mail.Send'
            Endpoints = @('me/sendMail')
            Reason    = 'Required to send emails on behalf of the signed-in user.'
        },
        @{
            Scope     = 'DeviceManagementConfiguration.Read.All'
            Endpoints = @('deviceManagement/deviceConfigurations')
            Reason    = 'Required to read Intune device configuration policies.'
        },
        @{
            Scope     = 'DeviceManagementManagedDevices.Read.All'
            Endpoints = @(
                'deviceManagement/managedDevices',
                'deviceManagement/managedDevices/id'
            )
            Reason    = 'Required to read Intune managed device properties.'
        },
        @{
            Scope     = 'DeviceManagementManagedDevices.PrivilegedOperations.All'
            Endpoints = @('directory/deviceLocalCredentials')
            Reason    = 'Required for highly privileged operations, specifically to read local admin (LAPS) passwords.'
        },
        @{
            Scope     = 'DeviceManagementServiceConfig.ReadWrite.All'
            Endpoints = @(
                'deviceManagement/autopilotEvents',
                'deviceManagement/importedWindowsAutopilotDeviceIdentities',
                'deviceManagement/windowsAutopilotDeviceIdentities'
            )
            Reason    = 'Required to read Autopilot events and to read and manage Autopilot device identities.'
        },
        @{
            Scope     = 'BitlockerKey.Read.All'
            Endpoints = @('informationProtection/bitlocker/recoveryKeys')
            Reason    = 'Required to read BitLocker recovery keys for all devices.'
        },
        @{
            Scope     = 'DeviceManagementConfiguration.ReadWrite.All'
            Endpoints = @('deviceManagement/deviceConfigurations')
            Reason    = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            Scope     = 'DeviceManagementApps.Read.All'
            Endpoints = @('deviceAppManagement/mobileApps')
            Reason    = 'Required to read application information in Intune.'
        },
        @{
            Scope     = 'DeviceManagementManagedDevices.ReadWrite.All'
            Endpoints = @('deviceManagement/managedDevices')
            Reason    = 'Required to create, update, and delete Intune managed device properties.'
        },
        @{
            Scope     = 'DeviceManagementScripts.Read.All'
            Endpoints = @('deviceManagement/deviceHealthScripts')
            Reason    = 'Required to read Intune device management scripts.'
        },
        @{
            Scope     = 'DeviceManagementScripts.ReadWrite.All'
            Endpoints = @('deviceManagement/deviceHealthScripts')
            Reason    = 'Required to create, update, and delete Intune device management scripts.'
        }
    )
    auth              = @{
        noSaveRefreshToken  = $false
        cacheType           = 'File'
        changePwOnNextStart = $false
        delegated           = $true
        forceNewToken       = $false
        scope               = @(
            'Device.ReadWrite.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.ReadWrite.All',
            'DeviceManagementScripts.Read.All',
            'Mail.Send',
            'DeviceManagementManagedDevices.PrivilegedOperations.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        )
        authType            = 'PublicAuthFlow'
        secureString        = $false
        renewalLeadTime     = 5
    }
}
