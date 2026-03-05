@{
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
        authType            = 'PublicAuthFlow'
        noSaveRefreshToken  = $false
        changePwOnNextStart = $false
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
        renewalLeadTime     = 5
        forceNewToken       = $false
        secureString        = $false
        cacheType           = 'File'
        delegated           = $true
    }
    repoInfo          = @{
        repoName      = 'Autopilot'
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL       = 'https://www.github.com'
        repoPath      = 'zuhairmahd'
    }
    cacheSettings     = @{
        maxCacheSize             = 1000
        cacheTypes               = @{
            Devices          = @{
                enabled           = $true
                expirationMinutes = 15
            }
            Configuration    = @{
                enabled           = $true
                expirationMinutes = 60
            }
            DirectoryObjects = @{
                enabled           = $true
                expirationMinutes = 15
            }
        }
        defaultExpirationMinutes = 15
        enabled                  = $true
    }
    corporateSettings = @{
        useCorporateSettings       = $false
        corporateDomain            = ''
        corporateSettingsFilePaths = @()
    }
    globalSettings    = @{
        release                                   = 'auto'
        maxUserMatchDisplay                       = 10
        includeEnrolledDevicesInNextUserReadiness = $true
        runPIVTest                                = $false
        hideEmptyMenus                            = $true
        appModes                                  = @('full')
        strongMappingOptional                     = $true
        checkStrongMapping                        = $false
        deviceContactThresholdInDays              = 30
        maxWaitTime                               = 30
        configFile                                = '.\.secrets\config.json'
        validateScopes                            = $true
        DisplayManualFilterSelection              = $false
        maxMenuItemsPerPage                       = 15
        documentationURL                          = 'https://github.com/zuhairmahd/Autopilot/blob/master/readme.md'
        licenseURL                                = 'https://github.com/zuhairmahd/Autopilot/blob/master/LICENSE'
        operatingSystem                           = 'Windows'
        operatingSystemVersion                    = 11
        minimumOSServiceRelease                   = '22h2'
        autoUpdate                                = $true
        preferredBrowser                          = 'Chrome'
        showLicenseBanner                         = $true
        maxGroupMatchDisplay                      = 10
        migrateLegacyConfiguration                = $true
        timeInSeconds                             = 60
        useGridForLogDisplay                      = $true
        privateSession                            = $false
        minimumOSServiceRelease                   = '22h2'
        repoInfo                                  = @{
            repoPath      = 'zuhairmahd'
            baseSourceURL = 'https://raw.githubusercontent.com'
            repoName      = 'Autopilot'
            baseURL       = 'https://www.github.com'
        }
        verifyAutopilotDeviceMinimumSpecs         = $true
    }
    description       = 'This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly.'
    version           = '1.3.0.0'
}
