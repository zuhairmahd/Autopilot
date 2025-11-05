function Get-ApplicationDefaults()
{
    <#
    .SYNOPSIS
        Single source of truth for all application default values and overwrite configurations.
    
    .DESCRIPTION
        Provides all default configuration structures for the application including
        settings, auth, menus, strings, and overwrite configurations. This function serves as the centralized
        repository for all default values and force-overwrite settings to ensure consistency across the application.
    
    .PARAMETER DefaultType
        Type of defaults to return: 'Settings', 'Auth', 'Global', 'Domain', 'Menus', 'Strings', 'Overwrite', 'All'
    
    .PARAMETER DomainName
        Domain name to use for domain-specific defaults.
    
    .PARAMETER Version
        Version string to use in configurations. If not provided, uses global version.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns hashtable with requested default configuration or overwrite settings.
    
    .EXAMPLE
        $authDefaults = Get-ApplicationDefaults -DefaultType "Auth"
    
    .EXAMPLE
        $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
    
    .EXAMPLE
        $allDefaults = Get-ApplicationDefaults -DefaultType "All"
    
    .EXAMPLE
        $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName "contoso.com"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Single source of truth for all default values and overwrite configurations
        - Replaces individual default value functions to eliminate duplication
        - Domain configurations are now handled separately but this provides templates
        - Overwrite configurations specify target locations (global, local, or universal)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Settings', 'Auth', 'Global', 'Domain', 'Menus', 'Strings', 'Overwrite', 'All')]
        [string]$DefaultType,
        [string]$DomainName,
        [string]$Version
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Initialize script-level cache if not exists
    $script:defaultsCache = New-Object 'System.Collections.Concurrent.ConcurrentDictionary[string,object]'
    
    # Use global version if available, otherwise default
    if (-not $Version)
    {
        $Version = if ($global:version -and $global:version.version)
        {
            $global:version.version.toString()
        }
        else
        {
            "1.3.0.0"
        }
    }
    
    # Create cache key based on parameters
    $cacheKey = "$DefaultType-$DomainName-$Version"
    if ($script:defaultsCache.ContainsKey($cacheKey))
    {
        Write-Verbose "[$functionName] Returning cached defaults for: $cacheKey"
        return $script:defaultsCache[$cacheKey]
    }
    Write-Verbose "[$functionName] Cache miss for defaults: $cacheKey"
    Write-Verbose "[$functionName] Getting default values for type: $DefaultType (cache miss: $cacheKey)"
    
    # Define all default structures
    $defaults = [ordered]@{
        
        # Authentication defaults - single source of truth
        Auth           = [ordered]@{
            changePwOnNextStart = $false
            authType            = "PublicAuthFlow"
            noSaveRefreshToken  = $false
            forceNewToken       = $false
            renewalLeadTime     = 5
            scope               = @(
                "offline_access",
                "openid",
                "Device.ReadWrite.All",
                "DeviceManagementApps.Read.All",
                "DeviceManagementConfiguration.ReadWrite.All",
                "DeviceManagementManagedDevices.PrivilegedOperations.All",
                "DeviceManagementManagedDevices.ReadWrite.All",
                "DeviceManagementServiceConfig.ReadWrite.All"
            )
            cacheType           = "Memory"
            secureString        = $false
            delegated           = $true
        }
        
        # Global settings defaults - single source of truth
        Global         = [ordered]@{
            configFile                   = ".\.secrets\config.json"
            maxWaitTime                  = 30
            showLicenseBanner            = $true
            validateScopes               = $true
            deviceContactThresholdInDays = 30
            appModes                     = @(
                "full"
            )
            timeInSeconds                = 60
            maxUserMatchDisplay          = 10
            checkStrongMapping           = $false
            strongMappingOptional        = $true
            maxGroupMatchDisplay         = 10
            maxMenuItemsPerPage          = 15
            release                      = "auto"
            cacheSettings                = [ordered]@{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = [ordered]@{
                    Configuration    = [ordered]@{
                        enabled           = $true
                        expirationMinutes = 60
                    }
                    DirectoryObjects = [ordered]@{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                    Devices          = [ordered]@{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                }
            }
            repoInfo                     = [ordered]@{
                repoName      = "Autopilot"
                baseSourceURL = "https://raw.githubusercontent.com"
                baseURL       = "https://www.github.com"
                repoPath      = "zuhairmahd"
            }
            operatingSystem              = "Windows"
            autoUpdate                   = $true
        }
        
        # Domain template defaults - single source of truth for domain structure
        Domain         = [ordered]@{
            groupsToInclude                 = @()
            groupsToExclude                 = @()
            autopilotProfilesToInclude      = @()
            autopilotDeviceAllowedVendors   = @(
                "Dell",
                "VMWare"
            )
            domain                          = $DomainName
            companyName                     = ""
            version                         = $Version
            validateScopes                  = $false
            maxWaitTime                     = 30
            showLicenseBanner               = $true
            deviceContactThresholdInDays    = 30
            checkStrongMapping              = $false
            strongMappingOptional           = $true
            migrateLegacyConfiguration      = $true
            appModes                        = @(
                "full"
            )
            timeInSeconds                   = 60
            maxUserMatchDisplay             = 20
            maxGroupMatchDisplay            = 20
            maxMenuItemsPerPage             = 20
            release                         = "master"
            cacheSettings                   = [ordered]@{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = [ordered]@{
                    Configuration    = [ordered]@{
                        enabled           = $true
                        expirationMinutes = 60
                    }
                    DirectoryObjects = [ordered]@{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                    Devices          = [ordered]@{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                }
            }
            repoInfo                        = [ordered]@{
                repoName      = "Autopilot"
                baseSourceURL = "https://raw.githubusercontent.com"
                baseURL       = "https://www.github.com"
                repoPath      = "zuhairmahd"
            }
            autoUpdate                      = $true
            deviceNamePrefix                = ""
            operatingSystem                 = "Windows"
            minUsernameLength               = 3
            maxUserNameLength               = 50
            maxSerialNumberLength           = 50
            minSerialNumberLength           = 7
            minimumDevicePhysicalMemoryInGB = 8
            maxNumberOfDevicesAllowed       = 15
            preferredBrowser                = "Chrome"
            privateSession                  = $false
            userPatternsToExclude           = @( 
                "-test",
                "onmicrosoft.com"
            )
            groupPatternsToExclude          = @()  
            groupTag                        = ''
            assignedUser                    = ''
            additionalScopes                = @()
        }
        
        # Required scopes for Microsoft Graph API
        RequiredScopes = @(
            @{
                Scope     = "User.Read.All"
                Reason    = "Required to read user profiles, group memberships, and registered devices."
                Endpoints = @(
                    "/users",
                    "users/id",
                    "users/id/memberOf",
                    "users/id/registeredDevices"
                )
            },
            @{
                Scope     = "Device.Read.All"
                Reason    = "Required to read Microsoft Entra ID device objects."
                Endpoints = @(
                    "devices"
                )
            },
            @{
                Scope     = "DeviceManagementApps.ReadWrite.All"
                Reason    = "Required to read application information and manage app assignments."
                Endpoints = @(
                    "deviceAppManagement/mobileApps",
                    "deviceAppManagement/mobileApps/id/assignments"
                )
            },
            @{
                Scope     = "DeviceManagementConfiguration.Read.All"
                Reason    = "Required to read Intune device configuration policies."
                Endpoints = @(
                    "deviceManagement/deviceConfigurations"
                )
            },
            @{
                Scope     = "DeviceManagementManagedDevices.Read.All"
                Reason    = "Required to read Intune managed device properties."
                Endpoints = @(
                    "deviceManagement/managedDevices",
                    "deviceManagement/managedDevices/id"
                )
            },
            @{
                Scope     = "DeviceManagementManagedDevices.PrivilegedOperations.All"
                Reason    = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
                Endpoints = @(
                    "directory/deviceLocalCredentials"
                )
            },
            @{
                Scope     = "DeviceManagementServiceConfig.ReadWrite.All"
                Reason    = "Required to read Autopilot events and to read and manage Autopilot device identities."
                Endpoints = @(
                    "deviceManagement/autopilotEvents",
                    "deviceManagement/importedWindowsAutopilotDeviceIdentities",
                    "deviceManagement/windowsAutopilotDeviceIdentities"
                )
            },
            @{
                Scope     = "BitlockerKey.Read.All"
                Reason    = "Required to read BitLocker recovery keys for all devices."
                Endpoints = @(
                    "informationProtection/bitlocker/recoveryKeys"
                )
            },
            @{
                scope     = "DeviceManagementConfiguration.ReadWrite.All"
                reason    = "Required to create, update, and delete Intune device configuration policies."
                endpoints = @(
                    "deviceManagement/deviceConfigurations"
                )
            },
            @{
                scope     = "DeviceManagementApps.Read.All"
                reason    = "Required to read application information in Intune."
                endpoints = @(
                    "deviceAppManagement/mobileApps"
                )
            },
            @{
                scope     = "DeviceManagementManagedDevices.ReadWrite.All"
                reason    = "Required to create, update, and delete Intune managed device properties."
                endpoints = @(
                    "deviceManagement/managedDevices"
                )
            },
            @{
                Scope     = "openid"
                Reason    = "Standard scope required for user sign -in with OpenID Connect."
                Endpoints = @()
            },
            @{
                Scope     = "profile"
                Reason    = "Standard scope to get basic user profile information during sign -in ."
                Endpoints = @()
            },
            @{
                scope     = "offline_access"
                reason    = "Standard scope that provides refresh tokens to maintain access when the user is not active."
                endpoints = @()
            }
        )
        
        # Strings defaults - UI text and localization
        Strings        = [ordered]@{
            Description   = "This is the strings file for the Intune Helpdesk script. It contains all the user-facing strings used in the script."
            deviceActions = @{
                none             = "No action"
                contactAdmin     = "Contact an Intune administrator"
                contactHelpdesk  = "Contact the helpdesk"
                connectToNetwork = "Connect the device to a network"
                WipeOrClean      = "Wipe or clean the device"
            }
            deviceStates  = @{
                Ready    = "The device is ready for the next user"
                NotReady = "The device is not ready for the next user"
            }
            returnValues  = @{
                "1001"                         = "Some updates were installed"
                deviceRestartSuccessMessage    = "The device was restarted successfully."
                deviceNotAssignedMessage       = "The device is not assigned to a deployment profile."
                manufacturerNotAllowed         = 'You are not allowed to import this device using this script.  Please contact your system administrator.'
                deviceIsInIntuneMessage        = 'The device is in Intune. Delete the device and try again.'
                userCanceledMessage            = "Operation canceled by user"
                noUserDeviceFoundMessage       = "No user or device found."
                EnrollmentFailedMessage        = "The device enrollment failed."
                noUserFoundInDirectoryMessage  = "This user does not exist"
                testUpdateMessage              = "Only Update tests. No update applied"
                deviceSyncFailedMessage        = "The device sync failed."
                "1003"                         = "Updates failed to install"
                noRestartMessage               = "Device not restarted."
                deviceRestartFailedMessage     = "The device restart failed."
                serialNumberNotFoundMessage    = "The serial number was not found."
                InvalidSignatureMessage        = "The signature is invalid. The update will be aborted."
                deviceUnknownActionMessage     = "The action may still be in progress. You can check the device status in the Intune portal."
                deviceWipeFailedMessage        = "The device wipe failed."
                "999"                          = "No updates were found"
                deviceCleanSuccessMessage      = "The device was cleaned successfully."
                "1000"                         = "All updates were installed"
                InvalidFileHash                = "The file hash is invalid. The update will be aborted."
                UpdateCancelledMessage         = "The update was cancelled."
                UpdateNotNeededMessage         = "The script is already up to date."
                noBitLockerKeysFoundMessage    = "No BitLocker keys found for this device."
                deviceDeleteSuccessMessage     = "The device was deleted successfully."
                UpdateSuccessMessage           = "The script was updated successfully."
                deviceAssignmentPendingMessage = "The device is pending assignment to a deployment profile."
                noGroupFoundInDirectoryMessage = "This group does not exist"
                deviceAssignedMessage          = "The device is assigned to a deployment profile."
                noGroupAssignmentsFoundMessage = "No assignments found for the specified group."
                noDeviceFound                  = "No device found"
                notContactedMessage            = "The device has not contacted the enrollment service."
                invalidFileType                = "Invalid file type."
                PendingResetMessage            = "The device is pending a reset."
                backoutText                    = "Returning to previous menu"
                noLAPSFoundMessage             = "No LAPS password found for this device."
                unknownErrorMessage            = "An unknown error occurred."
            }
        }
        
        # Menu defaults - complete menu structure 
        Menus          = [ordered]@{
            version                   = '1.3.0.0'
            name                      = 'menu.psd1'
            description               = 'This file contains the definitions for the menus used in the application.'
            appModeHierarchy          = @{
                advanced             = @(
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                admin                = @(
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                custom               = @()
                registration         = @(
                    'helpdesk',
                    'registration'
                )
                advancedRegistration = @(
                    'advancedRegistration',
                    'registration'
                )
                helpdesk             = @(
                    'helpdesk'
                )
                full                 = @(
                    '*'
                )
            }
            appModeDefaults           = @{
                advanced             = @{
                    capabilities = @(
                        'advanced_features',
                        'helpdesk_operations',
                        'device_registration',
                        'settings_view',
                        'advanced_exports'
                    )
                    description  = 'Advanced user with helpdesk and configuration capabilities'
                }
                admin                = @{
                    capabilities = @(
                        'system_administration',
                        'advanced_features',
                        'helpdesk_operations',
                        'device_registration',
                        'full_configuration'
                    )
                    description  = 'System administrator with full configuration and management capabilities'
                }
                custom               = @{
                    capabilities = @(
                        'user_defined'
                    )
                    description  = 'Customizable mode where users define their own access patterns'
                }
                registration         = @{
                    capabilities = @(
                        'autopilot_registration',
                        'device_import',
                        'basic_exports',
                        'device_status_check'
                    )
                    description  = 'Device registration specialist with Autopilot enrollment capabilities'
                }
                advancedRegistration = @{
                    capabilities = @(
                        'advanced_autopilot',
                        'custom_import',
                        'device_preparation',
                        'advanced_device_actions'
                    )
                    description  = 'Advanced registration specialist with administrative Autopilot capabilities'
                }
                helpdesk             = @{
                    capabilities = @(
                        'device_assignment',
                        'device_troubleshooting',
                        'basic_exports',
                        'device_actions',
                        'user_management'
                    )
                    description  = 'Helpdesk operator with device troubleshooting and user assignment capabilities'
                }
                full                 = @{
                    capabilities = @(
                        'all_menus',
                        'all_actions',
                        'settings_management',
                        'advanced_diagnostics',
                        'export_all',
                        'device_management'
                    )
                    description  = 'Full administrative access with all features enabled'
                }
            }
            mainMenu                  = @{
                Title                 = 'Main Menu'
                Description           = 'Please choose from one of the following options'
                items                 = @(
                    @{
                        description           = 'Start the user and device readiness check'
                        name                  = 'Give a device to a user'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        menuName              = 'checkMenu'
                        description           = 'Troubleshoot a device'
                        name                  = 'Check device status'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        menuName              = 'autopilotMenu'
                        description           = 'Import a device into Autopilot and perform related actions'
                        name                  = 'Autopilot menu'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        menuName              = 'settingsMenu'
                        description           = 'Modify the application settings'
                        name                  = 'Change application settings'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Check if there are any updates available for the scripts'
                        name                  = 'Check for script updates'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'helpdesk',
                            'registration',
                            'advancedRegistration',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Restart the device'
                        name                  = 'Restart the device'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Shutdown the device'
                        name                  = 'Shutdown the device'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'helpdesk',
                            'registration',
                            'advancedRegistration',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Show the group assignments for the device'
                        name                  = 'Show Group Assignments'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        menuName              = 'exportMenu'
                        description           = 'Export device information'
                        name                  = 'Export Menu'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration'
                        )
                    },
                    @{
                        description           = 'Learn more about this application'
                        name                  = 'About'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @()
            }
            checkMenu                 = @{
                Title                 = 'Check Device Status'
                Description           = 'How would you like to lookup the device?'
                items                 = @(
                    @{
                        menuName              = 'serialNumberMenu'
                        description           = 'Lookup a device by its serial number'
                        name                  = 'Lookup device by Serial Number'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Lookup a device by the user id or email address'
                        name                  = 'Lookup device by User'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            }
            autopilotMenu             = @{
                Title                 = 'Autopilot Menu'
                Description           = 'Import a device into Autopilot and perform related actions'
                items                 = @(
                    @{
                        description           = 'Quick import a device into Autopilot'
                        name                  = 'Quick Import device into Autopilot (requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Custom import a device into Autopilot'
                        name                  = 'Custom import device into Autopilot (requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Import a Corporate Device Identifier for Device Preparation'
                        name                  = 'Import Corporate Device Identifier for Device Preparation (requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Export a Corporate Device Identifier for manual upload to Device Preparation'
                        name                  = 'Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Get the device hash for manual upload to Autopilot'
                        name                  = 'Get device hash for manual upload to Autopilot (requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Download and install the latest Windows updates'
                        name                  = 'Download and install latest Windows updates(requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Check if a device is registered in Autopilot'
                        name                  = 'Check device Autopilot status'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Delete a device from Autopilot'
                        name                  = 'Delete device from Autopilot'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Delete a Corporate Device Identifier from Device Preparation'
                        name                  = 'Delete Corporate Device Identifier from Device Preparation (requires admin rights)'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advancedRegistration'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            }
            settingsMenu              = @{
                Title                 = 'Settings menu'
                Description           = 'Make changes to the application settings'
                items                 = @(
                    @{
                        menuName              = 'environmentMenu'
                        description           = 'Change the environment settings'
                        name                  = 'Change environment settings'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Change the Entra credentials'
                        name                  = 'Change Entra Credentials'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Change the Auto Update settings'
                        name                  = 'Change Auto Update settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Change the App Mode settings'
                        name                  = 'Change App Mode settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }
            exportMenu                = @{
                Title                 = 'Export Menu'
                Description           = 'Choose what you would like to export'
                items                 = @(
                    @{
                        menuName              = 'deviceReportsMenu'
                        description           = 'Export various device assignment reports'
                        name                  = 'Export Device Assignment Reports'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Export Autopilot devices to a CSV file'
                        name                  = 'Export Autopilot Devices'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Export imported Autopilot devices to a CSV file'
                        name                  = 'Export Imported Autopilot Devices'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'registration',
                            'advancedRegistration'
                        )
                    },
                    @{
                        description           = 'Export managed Windows devices to a CSV file'
                        name                  = 'Export Managed Windows Devices'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        description           = 'Export unmanaged Windows devices to a CSV file'
                        name                  = 'Export Unmanaged Windows Devices'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Export a report of device storage to a CSV file'
                        name                  = 'Export device storage report'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        description           = 'Export application assignments to a CSV file'
                        name                  = 'Export Application Assignments'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
            deviceReportsMenu         = @{
                Title                 = 'Device Reports Menu'
                Description           = 'Select the type of device report you would like to export'
                items                 = @(
                    @{
                        description           = 'Generate a report of assigned Windows devices'
                        name                  = 'Assigned Windows Devices'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Generate a report of unassigned Windows devices'
                        name                  = 'Unassigned Windows Devices'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Generate a report of Windows devices pre-provisioned with Autopilot'
                        name                  = 'Pre-provisioned Windows Devices'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Generate a report of all Windows devices with their assignment'
                        name                  = 'All Windows Devices'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }               
            serialNumberMenu          = @{
                Title                 = 'Lookup by Serial Number'
                Description           = 'How would you like to enter the serial number?'
                items                 = @(
                    @{
                        description           = 'Lookup a device by its serial number'
                        name                  = 'Enter a serial number'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Lookup the device the application is running on'
                        name                  = 'Use this device''s serial number'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            }
            environmentMenu           = @{
                Title                 = 'Change Environment Menu'
                Description           = 'Manage your environment settings and configurations'
                items                 = @(
                    @{
                        description           = 'View the global environment settings'
                        name                  = 'View global environment settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'View the domain specific environment settings'
                        name                  = 'View domain specific environment settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'View the group inclusion/exclusion settings for all domains'
                        name                  = 'View group inclusion/exclusion settings for all domains'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Change the global environment settings'
                        name                  = 'Change global environment settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        description           = 'Change the domain specific environment settings'
                        name                  = 'Change domain specific settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        description           = 'Change the authentication settings'
                        name                  = 'Change authentication settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        menuName              = 'inclusionExclusionMenu'
                        description           = 'Change the inclusion/exclusion settings for groups and Autopilot profiles'
                        name                  = 'Change inclusion/exclusion'
                        blockType             = 'menu'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }
            userMenu                  = @{
                Title                 = 'Select a user'
                Description           = 'Did you mean:'
                type                  = 'dynamic'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
            deviceMenu                = @{
                Title                 = 'Device Selection'
                Description           = 'Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))'
                type                  = 'dynamic'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
            groupMenu                 = @{
                Title                 = 'Select a group'
                Description           = 'Did you mean:'
                type                  = 'dynamic'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }
            deviceActionsMenu         = @{
                Title                 = 'Device Actions for $deviceName'
                Description           = 'Select an action to perform on this device:'
                items                 = @(
                    @{
                        description           = 'Wipe the selected device'
                        name                  = 'Wipe Device'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Clean the selected device'
                        name                  = 'Clean Device'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced'
                        )
                    },
                    @{
                        description           = 'Sync the selected device'
                        name                  = 'Sync Device'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        description           = 'Retrieve the LAPS password for the selected device'
                        name                  = 'Get LAPS Password'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Retrieve the BitLocker recovery key for the selected device'
                        name                  = 'Get BitLocker Recovery Key'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Retrieve the BIOS password details for the selected device'
                        name                  = 'Get Hardware Password Details'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk'
                        )
                    },
                    @{
                        description           = 'Restart the selected device'
                        name                  = 'Restart Device'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        description           = 'Show the health status of the selected device'
                        name                  = 'Show Device Health Status'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        description           = 'Check the next user readiness state for the selected device'
                        name                  = 'Check next user readiness state'
                        type                  = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
            appModeMenu               = @{
                Title                 = '$menuTitle'
                Description           = '$menuDescription'
                type                  = 'dynamic'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
            groupAssignmentsMenu      = @{
                Title                 = 'Group Assignments for $groupName'
                Description           = 'What type of assignments would you like to see?'
                type                  = 'dynamic'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }
            deviceWaitMenu            = @{
                Title                 = 'Device Wait Menu'
                Description           = 'Choose what you would like to do with this device:'
                items                 = @(
                    @{
                        Description           = 'Restart the device'
                        name                  = 'Restart the device'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
            inclusionExclusionMenu    = @{
                Title                 = 'Inclusion/Exclusion Settings'
                Description           = 'Manage group and Autopilot profile inclusion/exclusion settings:'
                items                 = @(
                    @{
                        description           = 'Modify the groups that are included or excluded from operations'
                        name                  = 'Change group inclusion/exclusion'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        description           = 'Modify the Autopilot profiles that are considered valid for assignment'
                        name                  = 'Change Autopilot profile settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
            groupsEditMenu            = @{
                Title                 = 'Groups Edit Menu'
                Description           = 'Select which group settings you want to modify:'
                items                 = @(
                    @{
                        description           = 'Modify the groups that are included'
                        name                  = 'Edit Groups to Include'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        description           = 'Modify the groups that are excluded'
                        name                  = 'Edit Groups to Exclude'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        description           = 'View the current group settings'
                        name                  = 'View Current Group Settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
            reportExportMenu          = @{
                Title                 = 'Device Health Menu'
                Description           = 'Select whether you want to display or export the device health report'
                items                 = @(
                    @{
                        Description           = 'Display the report on screen'
                        name                  = 'Display on Screen'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        Description           = 'Export the report in HTML format'
                        name                  = 'Export to HTML'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    },
                    @{
                        Description           = 'Export the report in CSV format'
                        name                  = 'Export to CSV'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin',
                            'advanced',
                            'helpdesk',
                            'registration'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
            autopilotProfilesEditMenu = @{
                Title                 = 'Autopilot Profiles Edit Menu'
                Description           = 'Select which Autopilot profile settings you want to modify:'
                items                 = @(
                    @{
                        description           = 'Modify the Autopilot profiles that are included'
                        name                  = 'Modify Autopilot profiles to include'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    },
                    @{
                        description           = 'View the current Autopilot profile settings'
                        name                  = 'View current Autopilot profile settings'
                        blockType             = 'action'
                        includeInDisplayModes = @(
                            'full',
                            'admin'
                        )
                    }
                )
                type                  = 'static'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
        }
    }
    
    # Complete settings structure combining all components
    $defaults.Settings = [ordered]@{
        description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
        version        = $Version
        auth           = $defaults.Auth
        requiredScopes = $defaults.RequiredScopes
        globalSettings = $defaults.Global
    }
    
    # Overwrite configurations - centralized force-overwrite settings
    $defaults.Overwrite = [ordered]@{
        # Global settings that should be forcibly overwritten
        # These settings will only be applied during global settings processing
        GlobalSettings    = @{
            #input global settings here
        }
        
        # Local/domain settings that should be forcibly overwritten
        # These settings will only be applied during domain settings processing
        LocalSettings     = @{
            # Enter local settings here
        }
        
        # Universal settings that apply to both global and local contexts
        # These will be applied to both global and domain settings processing
        UniversalSettings = @{
            # Enter universal settings here
        }
    }
    
    Write-Verbose "[$functionName] Default structures created for: $($defaults.Keys -join ', ')"
    
    # Return requested defaults
    switch ($DefaultType)
    {
        'Auth'
        {
            Write-Verbose "[$functionName] Returning auth defaults"
            $result = $defaults.Auth
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'Global'
        {
            Write-Verbose "[$functionName] Returning global defaults"
            $result = $defaults.Global
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'Domain'
        {
            Write-Verbose "[$functionName] Returning domain template defaults for: $DomainName"
            $result = $defaults.Domain
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'Settings'
        {
            Write-Verbose "[$functionName] Returning complete settings defaults"
            $result = $defaults.Settings
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'Strings'
        {
            Write-Verbose "[$functionName] Returning strings defaults"
            $result = $defaults.Strings
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'Menus'
        {
            Write-Verbose "[$functionName] Returning menu defaults"
            $result = $defaults.Menus
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'Overwrite'
        {
            Write-Verbose "[$functionName] Returning overwrite configuration"
            $result = $defaults.Overwrite
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        'All'
        {
            Write-Verbose "[$functionName] Returning all defaults"
            $result = $defaults
            $script:defaultsCache[$cacheKey] = $result
            return $result
        }
        default
        {
            Write-Warning "[$functionName] Unknown default type: $DefaultType"
            return $null
        }
    }
}

# Backward compatibility functions - these call the centralized function
function Get-AuthDefaults()
{
    <#
    .SYNOPSIS
        Returns the default auth configuration structure (backward compatibility).
    
    .DESCRIPTION
        Wrapper function for backward compatibility. Calls Get-ApplicationDefaults.
    #>
    [CmdletBinding()]
    param()
    
    return Get-ApplicationDefaults -DefaultType "Auth"
}

function Get-GlobalDefaults()
{
    <#
    .SYNOPSIS
        Returns the default global settings structure.
    
    .DESCRIPTION
        Wrapper function that calls Get-ApplicationDefaults for global settings.
    #>
    [CmdletBinding()]
    param()
    
    return Get-ApplicationDefaults -DefaultType "Global"
}

function Get-DomainDefaults()
{
    <#
    .SYNOPSIS
        Returns the default domain configuration template.
    
    .DESCRIPTION
        Wrapper function that calls Get-ApplicationDefaults for domain template.
    #>
    [CmdletBinding()]
    param(
        [string]$DomainName
    )
    
    return Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
}