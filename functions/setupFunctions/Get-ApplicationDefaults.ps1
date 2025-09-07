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
        Domain name to use for domain-specific defaults. Defaults to "example.com"
    
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
        [string]$DomainName = "example.com",
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
    
    Write-Verbose "[$functionName] Getting default values for type: $DefaultType (cache miss: $cacheKey)"
    
    # Define all default structures
    $defaults = @{
        
        # Authentication defaults - single source of truth
        Auth           = @{
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
        Global         = @{
            configFile                   = ".\.secrets\config.json"
            maxWaitTime                  = 30
            showLicenseBanner            = $true
            validateScopes               = $true
            deviceContactThresholdInDays = 30
            appMode                      = "full"
            timeInSeconds                = 60
            maxUserMatchDisplay          = 10
            maxGroupMatchDisplay         = 10
            release                      = "auto"
            repoInfo                     = @{
                repoName      = "Autopilot"
                baseSourceURL = "https://raw.githubusercontent.com"
                baseURL       = "https://www.github.com"
                repoPath      = "zuhairmahd"
            }
            testMode                     = $false
            operatingSystem              = "Windows"
            autoUpdate                   = $true
        }
        
        # Domain template defaults - single source of truth for domain structure
        Domain         = @{
            groupsToInclude                 = @()
            groupsToExclude                 = @()
            domain                          = $DomainName
            companyName                     = ""
            version                         = $Version
            validateScopes                  = $true
            maxWaitTime                     = 30
            showLicenseBanner               = $true
            deviceContactThresholdInDays    = 30
            appMode                         = "full"
            timeInSeconds                   = 60
            maxUserMatchDisplay             = 10
            maxGroupMatchDisplay            = 10
            release                         = "master"
            repoInfo                        = @{
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
            desiredAutopilotProfiles        = @()
            additionalScopes                = @()
        }
        
        # Required scopes for Microsoft Graph API
        RequiredScopes = @(
            @{
                Scope     = "User.Read.All"
                Reason    = "Required to read user profiles, group memberships, and registered devices."
                Endpoints = @(
                    "/ users",
                    "users /
                {
                    id
                }",
                    "users /
                {
                    id
                } / memberOf",
                    "users /
                {
                    id
                } / registeredDevices"
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
                    "deviceAppManagement / mobileApps",
                    "deviceAppManagement / mobileApps /
                {
                    id
                } / assignments"
                )
            },
            @{
                Scope     = "DeviceManagementConfiguration.Read.All"
                Reason    = "Required to read Intune device configuration policies."
                Endpoints = @(
                    "deviceManagement / deviceConfigurations"
                )
            },
            @{
                Scope     = "DeviceManagementManagedDevices.Read.All"
                Reason    = "Required to read Intune managed device properties."
                Endpoints = @(
                    "/ deviceManagement / managedDevices",
                    "deviceManagement / managedDevices /
                {
                    id
                }"
                )
            },
            @{
                Scope     = "DeviceManagementManagedDevices.PrivilegedOperations.All"
                Reason    = "Required for highly privileged operations, specifically to read local admin (LAPS) passwords."
                Endpoints = @(
                    "directory / deviceLocalCredentials"
                )
            },
            @{
                Scope     = "DeviceManagementServiceConfig.ReadWrite.All"
                Reason    = "Required to read Autopilot events and to read and manage Autopilot device identities."
                Endpoints = @(
                    "deviceManagement / autopilotEvents",
                    "deviceManagement / importedWindowsAutopilotDeviceIdentities",
                    "deviceManagement / windowsAutopilotDeviceIdentities"
                )
            },
            @{
                Scope     = "BitlockerKey.Read.All"
                Reason    = "Required to read BitLocker recovery keys for all devices."
                Endpoints = @(
                    "informationProtection / bitlocker / recoveryKeys"
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
                scope     = "DeviceManagementConfiguration.ReadWrite.All"
                reason    = "Required to create, update, and delete Intune device configuration policies."
                endpoints = @(
                    "deviceManagement / deviceConfigurations"
                )
            },
            @{
                scope     = "DeviceManagementApps.Read.All"
                reason    = "Required to read application information in Intune."
                endpoints = @(
                    "deviceAppManagement / mobileApps"
                )
            },
            @{
                scope     = "DeviceManagementManagedDevices.ReadWrite.All"
                reason    = "Required to create, update, and delete Intune managed device properties."
                endpoints = @(
                    "deviceManagement / managedDevices"
                )
            },
            @{
                scope     = "offline_access"
                reason    = "Standard scope that provides refresh tokens to maintain access when the user is not active."
                endpoints = @()
            }
        )
        
        # Strings defaults - UI text and localization
        Strings        = @{
            Description   = "This is the strings file for the Intune Helpdesk script. It contains all the user-facing strings used in the script."
            deviceActions = @{
                none            = "No action"
                contactAdmin    = "Contact an Intune administrator"
                contactHelpdesk = "Contact the helpdesk"
                WipeOrClean     = "Wipe or clean the device"
            }
            deviceStates  = @{
                Ready    = "The device is ready for the next user"
                NotReady = "The device is not ready for the next user"
            }
            returnValues  = @{
                "1001"                         = "Some updates were installed"
                deviceRestartSuccessMessage    = "The device was restarted successfully."
                deviceNotAssignedMessage       = "The device is not assigned to a deployment profile."
                userCanceledMessage            = "Operation canceled by user"
                noUserDeviceFoundMessage       = "No user or device found."
                EnrollmentFailedMessage        = "The device enrollment failed."
                noUserFoundInDirectoryMessage  = "This user does not exist"
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
        Menus          = @{
            version         = $Version
            name            = 'menu.psd1'
            description     = 'This file contains the definitions for the menus used in the application.'
            appModeHierarchy = @{
                full                 = @('*')
                advanced             = @('advanced', 'helpdesk', 'registration')
                helpdesk             = @('helpdesk')
                registration         = @('registration')
                advancedRegistration = @('advancedRegistration', 'registration')
                admin                = @('admin', 'advanced', 'helpdesk', 'registration')
                custom               = @()
            }
            appModeDefaults = @{
                full                = @{
                    description  = 'Full administrative access with all features enabled'
                    capabilities = @('all_menus', 'all_actions', 'settings_management', 'advanced_diagnostics', 'export_all', 'device_management')
                }
                advanced            = @{
                    description  = 'Advanced user with helpdesk and configuration capabilities'
                    capabilities = @('advanced_features', 'helpdesk_operations', 'device_registration', 'settings_view', 'advanced_exports')
                }
                helpdesk            = @{
                    description  = 'Helpdesk operator with device troubleshooting and user assignment capabilities'
                    capabilities = @('device_assignment', 'device_troubleshooting', 'basic_exports', 'device_actions', 'user_management')
                }
                registration        = @{
                    description  = 'Device registration specialist with Autopilot enrollment capabilities'
                    capabilities = @('autopilot_registration', 'device_import', 'basic_exports', 'device_status_check')
                }
                advancedRegistration = @{
                    description  = 'Advanced registration specialist with administrative Autopilot capabilities'
                    capabilities = @('advanced_autopilot', 'custom_import', 'device_preparation', 'advanced_device_actions')
                }
                admin               = @{
                    description  = 'System administrator with full configuration and management capabilities'
                    capabilities = @('system_administration', 'advanced_features', 'helpdesk_operations', 'device_registration', 'full_configuration')
                }
                custom              = @{
                    description  = 'Customizable mode where users define their own access patterns'
                    capabilities = @('user_defined')
                }
            }
            mainMenu        = @{
                Title               = 'Main Menu'
                Description         = 'Please choose from one of the following options'
                type                = 'static'
                includeInDisplayModes = @()
                items               = @(
                    @{
                        name                   = 'Give a device to a user'
                        description            = 'Start the user and device readiness check'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Check device status'
                        description            = 'Troubleshoot a device'
                        blockType              = 'menu'
                        menuName               = 'checkMenu'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Autopilot menu'
                        description            = 'Import a device into Autopilot and perform related actions'
                        blockType              = 'menu'
                        menuName               = 'autopilotMenu'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Change application settings'
                        description            = 'Modify the application settings'
                        blockType              = 'menu'
                        menuName               = 'settingsMenu'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Check for script updates'
                        description            = 'Check if there are any updates available for the scripts'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Restart the device'
                        description            = 'Restart the device'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Show Group Assignments'
                        description            = 'Show the group assignments for the device'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Export Menu'
                        description            = 'Export device information'
                        blockType              = 'menu'
                        menuName               = 'exportMenu'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration')
                    },
                    @{
                        name                   = 'About'
                        description            = 'Learn more about this application'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    }
                )
            }
            checkMenu        = @{
                Title               = 'Check Device Status'
                Description         = 'How would you like to lookup the device?'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk')
                items               = @(
                    @{
                        name                   = 'Lookup device by Serial Number'
                        description            = 'Lookup a device by its serial number'
                        blockType              = 'menu'
                        menuName               = 'serialNumberMenu'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Lookup device by User'
                        description            = 'Lookup a device by the user id or email address'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    }
                )
            }
            autopilotMenu    = @{
                Title               = 'Autopilot Menu'
                Description         = 'Import a device into Autopilot and perform related actions'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                items               = @(
                    @{
                        name                   = 'Import device into Autopilot'
                        description            = 'Import a device into Autopilot'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Custom import device into Autopilot (requires admin rights)'
                        description            = 'Custom import a device into Autopilot'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Import Corporate Device Identifier for Device Preparation (requires admin rights)'
                        description            = 'Import a Corporate Device Identifier for Device Preparation'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)'
                        description            = 'Export a Corporate Device Identifier for manual upload to Device Preparation'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Get device hash for manual upload to Autopilot (requires admin rights)'
                        description            = 'Get the device hash for manual upload to Autopilot'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Download and install latest Windows updates(requires admin rights)'
                        description            = 'Download and install the latest Windows updates'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Check device Autopilot status'
                        description            = 'Check if a device is registered in Autopilot'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Delete device from Autopilot'
                        description            = 'Delete a device from Autopilot'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Quick Import device into Autopilot (requires admin rights)'
                        description            = 'Quick import a device into Autopilot'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Delete Corporate Device Identifier from Device Preparation (requires admin rights)'
                        description            = 'Delete a Corporate Device Identifier from Device Preparation'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advancedRegistration')
                    }
                )
            }
            settingsMenu     = @{
                Title               = 'Settings menu'
                Description         = 'Make changes to the application settings'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced')
                items               = @(
                    @{
                        name                   = 'Change environment settings'
                        description            = 'Change the environment settings'
                        blockType              = 'menu'
                        menuName               = 'environmentMenu'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Change Entra Credentials'
                        description            = 'Change the Entra credentials'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Change Auto Update settings'
                        description            = 'Change the Auto Update settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Change App Mode settings'
                        description            = 'Change the App Mode settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    }
                )
            }
            exportMenu       = @{
                Title               = 'Export Menu'
                Description         = 'Choose what you would like to export'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                items               = @(
                    @{
                        name                   = 'Export Autopilot Devices'
                        description            = 'Export Autopilot devices to a CSV file'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Export Imported Autopilot Devices'
                        description            = 'Export imported Autopilot devices to a CSV file'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'registration', 'advancedRegistration')
                    },
                    @{
                        name                   = 'Export Managed Windows Devices'
                        description            = 'Export managed Windows devices to a CSV file'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Export Unmanaged Windows Devices'
                        description            = 'Export unmanaged Windows devices to a CSV file'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Export device storage report'
                        description            = 'Export a report of device storage to a CSV file'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Export Application Assignments'
                        description            = 'Export application assignments to a CSV file'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    }
                )
            }
            serialNumberMenu = @{
                Title               = 'Lookup by Serial Number'
                Description         = 'How would you like to enter the serial number?'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk')
                items               = @(
                    @{
                        name                   = 'Enter a serial number'
                        description            = 'Lookup a device by its serial number'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Use this device''s serial number'
                        description            = 'Lookup the device the application is running on'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    }
                )
            }
            environmentMenu  = @{
                Title               = 'Change Environment Menu'
                Description         = 'Manage your environment settings and configurations'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced')
                items               = @(
                    @{
                        name                   = 'View global environment settings'
                        description            = 'View the global environment settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'View domain specific environment settings'
                        description            = 'View the domain specific environment settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'View group inclusion/exclusion settings for all domains'
                        description            = 'View the group inclusion/exclusion settings for all domains'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Change global environment settings'
                        description            = 'Change the global environment settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    },
                    @{
                        name                   = 'Change domain specific settings'
                        description            = 'Change the domain specific environment settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    },
                    @{
                        name                   = 'Change authentication settings'
                        description            = 'Change the authentication settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    },
                    @{
                        name                   = 'Change group inclusion/exclusion'
                        description            = 'Change the group inclusion/exclusion settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    }
                )
            }
            # Dynamic menus (these are created programmatically)
            userMenu         = @{
                type                  = 'dynamic'
                Title                 = 'Select a user'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                Description           = 'Did you mean:'
            }
            deviceMenu       = @{
                type                  = 'dynamic'
                Title                 = 'Device Selection'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                Description           = 'Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))'
            }
            groupMenu        = @{
                type                  = 'dynamic'
                Title                 = 'Select a group'
                includeInDisplayModes = @('full', 'admin', 'advanced')
                Description           = 'Did you mean:'
            }
            # Additional menus for various workflows
            deviceActionsMenu = @{
                Title               = 'Device Actions for $deviceName'
                Description         = 'Select an action to perform on this device:'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                items               = @(
                    @{
                        name                   = 'Wipe Device'
                        description            = 'Wipe the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Clean Device'
                        description            = 'Clean the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced')
                    },
                    @{
                        name                   = 'Sync Device'
                        description            = 'Sync the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Get LAPS Password'
                        description            = 'Retrieve the LAPS password for the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Get BitLocker Recovery Key'
                        description            = 'Retrieve the BitLocker recovery key for the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Get Hardware Password Details'
                        description            = 'Retrieve the BIOS password details for the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk')
                    },
                    @{
                        name                   = 'Restart Device'
                        description            = 'Restart the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Show Device Health Status'
                        description            = 'Show the health status of the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Check next user readiness state'
                        description            = 'Check the next user readiness state for the selected device'
                        type                   = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    }
                )
            }
            # Additional dynamic and static menus that exist in the committed menu.psd1
            appModeMenu = @{
                type                  = 'dynamic'
                Title                 = '$menuTitle'
                includeInDisplayModes = @('full', 'admin')
                Description           = '$menuDescription'
            }
            groupAssignmentsMenu = @{
                type                  = 'dynamic'
                Title                 = 'Group Assignments for $groupName'
                includeInDisplayModes = @('full', 'admin', 'advanced')
                Description           = 'What type of assignments would you like to see?'
            }
            deviceWaitMenu = @{
                Title               = 'Device Wait Menu'
                Description         = 'Choose what you would like to do with this device:'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                items               = @(
                    @{
                        name                   = 'Restart the device'
                        Description            = 'Restart the device'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    }
                )
            }
            groupsEditMenu = @{
                Title               = 'Groups Edit Menu'
                Description         = 'Select which group settings you want to modify:'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin')
                items               = @(
                    @{
                        name                   = 'Edit Groups to Include'
                        description            = 'Modify the groups that are included'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    },
                    @{
                        name                   = 'Edit Groups to Exclude'
                        description            = 'Modify the groups that are excluded'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    },
                    @{
                        name                   = 'View Current Group Settings'
                        description            = 'View the current group settings'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin')
                    }
                )
            }
            reportExportMenu = @{
                Title               = 'Report Export Menu'
                Description         = 'Select the format to which you would like to export the report'
                type                = 'static'
                includeInDisplayModes = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                items               = @(
                    @{
                        name                   = 'Export in HTML format'
                        Description            = 'Export the report in HTML format'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    },
                    @{
                        name                   = 'Export in CSV format'
                        Description            = 'Export the report in CSV format'
                        blockType              = 'action'
                        includeInDisplayModes  = @('full', 'admin', 'advanced', 'helpdesk', 'registration')
                    }
                )
            }
        }
    }
    
    # Complete settings structure combining all components
    $defaults.Settings = @{
        description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
        version        = $Version
        auth           = $defaults.Auth
        requiredScopes = $defaults.RequiredScopes
        globalSettings = $defaults.Global
    }
    
    # Overwrite configurations - centralized force-overwrite settings
    $defaults.Overwrite = @{
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
        [string]$DomainName = "example.com"
    )
    
    return Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
}