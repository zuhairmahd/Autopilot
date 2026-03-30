@{
    description       = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version           = '1.3.0.0'
    auth              = @{
        changePwOnNextStart = $false
        authType            = 'PublicAuthFlow'
        noSaveRefreshToken  = $false
        forceNewToken       = $false
        renewalLeadTime     = 5
        scope               = @(
            'Device.ReadWrite.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.ReadWrite.All',
            'Mail.Send',
            'DeviceManagementScripts.Read.All',
            'DeviceManagementManagedDevices.PrivilegedOperations.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All'
        )
        cacheType           = 'Disk'
        secureString        = $false
        delegated           = $true
    }
    cacheSettings     = @{
        enabled                  = $true
        defaultExpirationMinutes = 15
        maxCacheSize             = 1000
        cacheTypes               = @{
            Configuration    = @{
                enabled           = $true
                expirationMinutes = 60
            }
            DirectoryObjects = @{
                enabled           = $true
                expirationMinutes = 15
            }
            Devices          = @{
                enabled           = $true
                expirationMinutes = 15
            }
        }
    }
    repoInfo          = @{
        repoName      = 'Autopilot'
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL       = 'https://www.github.com'
        repoPath      = 'zuhairmahd'
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
            scope     = 'Mail.Send'
            endpoints = @('me/sendMail')
            reason    = 'Required to send emails on behalf of the signed-in user.'
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
            scope     = 'DeviceManagementConfiguration.ReadWrite.All'
            endpoints = @('deviceManagement/deviceConfigurations')
            reason    = 'Required to create, update, and delete Intune device configuration policies.'
        },
        @{
            scope     = 'DeviceManagementApps.Read.All'
            endpoints = @('deviceAppManagement/mobileApps')
            reason    = 'Required to read application information in Intune.'
        },
        @{
            scope     = 'DeviceManagementManagedDevices.ReadWrite.All'
            endpoints = @('deviceManagement/managedDevices')
            reason    = 'Required to create, update, and delete Intune managed device properties.'
        },
        @{
            scope     = 'DeviceManagementScripts.Read.All'
            endpoints = @('deviceManagement/deviceHealthScripts')
            reason    = 'Required to read Intune device management scripts.'
        },
        @{
            scope     = 'DeviceManagementScripts.ReadWrite.All'
            endpoints = @('deviceManagement/deviceHealthScripts')
            reason    = 'Required to create, update, and delete Intune device management scripts.'
        }
    )
    corporateSettings = @{
        useCorporateSettings       = $false
        corporateDomain            = ''
        corporateSettingsFilePaths = @()
    }
    globalSettings    = @{
        configFile                                = '.\.secrets\config.json'
        maxWaitTime                               = 30
        showLicenseBanner                         = $true
        validateScopes                            = $true
        deviceContactThresholdInDays              = 30
        includeEnrolledDevicesInNextUserReadiness = $true
        useGridForLogDisplay                      = $true
        DisplayManualFilterSelection              = $false
        appModes                                  = @('full')
        timeInSeconds                             = 60
        maxUserMatchDisplay                       = 10
        checkStrongMapping                        = $false
        strongMappingOptional                     = $true
        maxGroupMatchDisplay                      = 10
        maxMenuItemsPerPage                       = 15
        release                                   = 'auto'
        operatingSystem                           = 'Windows'
        operatingSystemVersion                    = 11
        minimumOSServiceRelease                   = '22h2'
        verifyAutopilotDeviceMinimumSpecs         = $true
        runPIVTest                                = $false
        preferredBrowser                          = 'Chrome'
        documentationURL                          = 'https://github.com/zuhairmahd/Autopilot/blob/master/readme.md'
        licenseURL                                = 'https://github.com/zuhairmahd/Autopilot/blob/master/LICENSE'
        privateSession                            = $false
        migrateLegacyConfiguration                = $true
        hideEmptyMenus                            = $true
        autoUpdate                                = $true
    }
}
