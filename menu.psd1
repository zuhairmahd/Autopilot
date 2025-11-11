@{
    version                   = '1.3.0.0'
    name                      = 'menu.psd1'
    description               = 'This file contains the definitions for the menus used in the application.'
    appModeHierarchy          = @{
        custom               = @()
        helpdesk             = @('helpdesk')
        advancedRegistration = @(
            'advancedRegistration',
            'registration'
        )
        registration         = @(
            'helpdesk',
            'registration'
        )
        admin                = @(
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        advanced             = @(
            'advanced',
            'helpdesk',
            'registration'
        )
        full                 = @('*')
    }
    appModeDefaults           = @{
        custom               = @{
            capabilities = @('user_defined')
            description  = 'Customizable mode where users define their own access patterns'
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
        advancedRegistration = @{
            capabilities = @(
                'advanced_autopilot',
                'custom_import',
                'device_preparation',
                'advanced_device_actions'
            )
            description  = 'Advanced registration specialist with administrative Autopilot capabilities'
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
        includeInDisplayModes = @()
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'Give a device to a user'
                description           = 'Start the user and device readiness check'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                blockType             = 'menu'
                name                  = 'Check device status'
                menuName              = 'checkMenu'
                description           = 'Troubleshoot a device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                blockType             = 'menu'
                name                  = 'Autopilot menu'
                menuName              = 'autopilotMenu'
                description           = 'Import a device into Autopilot and perform related actions'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'menu'
                name                  = 'Change application settings'
                menuName              = 'settingsMenu'
                description           = 'Modify the application settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'helpdesk',
                    'registration',
                    'advancedRegistration',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Check for script updates'
                description           = 'Check if there are any updates available for the scripts'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration',
                    'helpdesk'
                )
                blockType             = 'action'
                name                  = 'Restart the device'
                description           = 'Restart the device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'helpdesk',
                    'registration',
                    'advancedRegistration',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Shutdown the device'
                description           = 'Shutdown the device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'menu'
                name                  = 'Group Assignments Menu'
                menuName              = 'getGroupAssignmentsMenu'
                description           = 'View or export various     group assignment reports'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration'
                )
                blockType             = 'menu'
                name                  = 'Export Menu'
                menuName              = 'exportMenu'
                description           = 'Export device information'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'About'
                description           = 'Learn more about this application'
            }
        )
        type                  = 'static'
        Title                 = 'Main Menu'
        Description           = 'Please choose from one of the following options'
    }
    checkMenu                 = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                blockType             = 'menu'
                name                  = 'Lookup device by Serial Number'
                menuName              = 'serialNumberMenu'
                description           = 'Lookup a device by its serial number'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Lookup device by User'
                description           = 'Lookup a device by the user id or email address'
            }
        )
        type                  = 'static'
        Title                 = 'Check Device Status'
        Description           = 'How would you like to lookup the device?'
    }
    autopilotMenu             = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'registration',
            'advancedRegistration'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Quick Import device into Autopilot (requires admin rights)'
                description           = 'Quick import a device into Autopilot'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Custom import device into Autopilot (requires admin rights)'
                description           = 'Custom import a device into Autopilot'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Import Corporate Device Identifier for Device Preparation (requires admin rights)'
                description           = 'Import a Corporate Device Identifier for Device Preparation'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)'
                description           = 'Export a Corporate Device Identifier for manual upload to Device Preparation'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Get device hash for manual upload to Autopilot (requires admin rights)'
                description           = 'Get the device hash for manual upload to Autopilot'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Download and install latest Windows updates(requires admin rights)'
                description           = 'Download and install the latest Windows updates'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Check device Autopilot status'
                description           = 'Check if a device is registered in Autopilot'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Delete device from Autopilot'
                description           = 'Delete a device from Autopilot'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Delete Corporate Device Identifier from Device Preparation (requires admin rights)'
                description           = 'Delete a Corporate Device Identifier from Device Preparation'
            }
        )
        type                  = 'static'
        Title                 = 'Autopilot Menu'
        Description           = 'Import a device into Autopilot and perform related actions'
    }
    settingsMenu              = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'menu'
                name                  = 'Change environment settings'
                menuName              = 'environmentMenu'
                description           = 'Change the environment settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Change Entra Credentials'
                description           = 'Change the Entra credentials'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Change Auto Update settings'
                description           = 'Change the Auto Update settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change App Mode settings'
                description           = 'Change the App Mode settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change repository information'
                description           = 'Edit repository information settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change cache settings'
                description           = 'Edit cache settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Restore application defaults'
                description           = 'Restore all application defaults including menus, local and global settings'
            }
        )
        type                  = 'static'
        Title                 = 'Settings menu'
        Description           = 'Make changes to the application settings'
    }
    exportMenu                = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'menu'
                name                  = 'Export Device Assignment Reports'
                menuName              = 'deviceReportsMenu'
                description           = 'Export various device assignment reports'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Export Autopilot Devices'
                description           = 'Export Autopilot devices to a CSV file'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Export Imported Autopilot Devices'
                description           = 'Export imported Autopilot devices to a CSV file'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Export Managed Windows Devices'
                description           = 'Export managed Windows devices to a CSV file'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                type                  = 'action'
                name                  = 'Export Unmanaged Windows Devices'
                description           = 'Export unmanaged Windows devices to a CSV file'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Export device storage report'
                description           = 'Export a report of device storage to a CSV file'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                type                  = 'action'
                name                  = 'Export Application Assignments'
                description           = 'Export application assignments to a CSV file'
            }
        )
        type                  = 'static'
        Title                 = 'Export Menu'
        Description           = 'Choose what you would like to export'
    }
    deviceReportsMenu         = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Assigned Windows Devices'
                description           = 'Generate a report of assigned Windows devices'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Unassigned Windows Devices'
                description           = 'Generate a report of unassigned Windows devices'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Pre-provisioned Windows Devices'
                description           = 'Generate a report of Windows devices pre-provisioned with Autopilot'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'All Windows Devices'
                description           = 'Generate a report of all Windows devices with their assignment'
            }
        )
        type                  = 'static'
        Title                 = 'Device Reports Menu'
        Description           = 'Select the type of device report you would like to export'
    }
    serialNumberMenu          = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Enter a serial number'
                description           = 'Lookup a device by its serial number'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Use this device''s serial number'
                description           = 'Lookup the device the application is running on'
            }
        )
        type                  = 'static'
        Title                 = 'Lookup by Serial Number'
        Description           = 'How would you like to enter the serial number?'
    }
    environmentMenu           = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'View global environment settings'
                description           = 'View the global environment settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'View domain specific environment settings'
                description           = 'View the domain specific environment settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'View group inclusion/exclusion settings for all domains'
                description           = 'View the group inclusion/exclusion settings for all domains'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change global environment settings'
                description           = 'Change the global environment settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change domain specific settings'
                description           = 'Change the domain specific environment settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change authentication settings'
                description           = 'Change the authentication settings'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'menu'
                name                  = 'Change inclusion/exclusion'
                menuName              = 'inclusionExclusionMenu'
                description           = 'Change the inclusion/exclusion settings for groups and Autopilot profiles'
            }
        )
        type                  = 'static'
        Title                 = 'Change Environment Menu'
        Description           = 'Manage your environment settings and configurations'
    }
    userMenu                  = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        type                  = 'dynamic'
        Title                 = 'Select a user'
        Description           = 'Did you mean:'
    }
    deviceMenu                = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        type                  = 'dynamic'
        Title                 = 'Device Selection'
        Description           = 'Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))'
    }
    groupMenu                 = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        type                  = 'dynamic'
        Title                 = 'Select a group'
        Description           = 'Did you mean:'
    }
    deviceActionsMenu         = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Wipe Device'
                description           = 'Wipe the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                type                  = 'action'
                name                  = 'Clean Device'
                description           = 'Clean the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Sync Device'
                description           = 'Sync the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Get LAPS Password'
                description           = 'Retrieve the LAPS password for the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Get BitLocker Recovery Key'
                description           = 'Retrieve the BitLocker recovery key for the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Get Hardware Password Details'
                description           = 'Retrieve the BIOS password details for the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Restart Device'
                description           = 'Restart the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Show Device Health Status'
                description           = 'Show the health status of the selected device'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Check next user readiness state'
                description           = 'Check the next user readiness state for the selected device'
            }
        )
        type                  = 'static'
        Title                 = 'Device Actions for $deviceName'
        Description           = 'Select an action to perform on this device:'
    }
    appModeMenu               = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        type                  = 'dynamic'
        Title                 = '$menuTitle'
        Description           = '$menuDescription'
    }
    getGroupAssignmentsMenu   = @{
        Title                 = 'Group Assignments Menu'
        Description           = 'View or export various group assignment reports'
        items                 = @(
            @{
                description           = 'View direct group assignments'
                name                  = 'View direct group assignments'
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description           = 'View indirect group assignments'
                name                  = 'View indirect group assignments (All Users/All Devices)'
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description           = 'View all unassigned configuration profiles     '
                name                  = 'View all unassigned configurations'        
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )                   
            },
            @{
                description           = 'Export direct group assignments to a CSV file'
                name                  = 'Export direct group assignments'        
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )                       
            },
            @{
                description           = 'Export indirect group assignments to a CSV file'
                name                  = 'Export indirect group assignments (All Users/All Devices)'        
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )                                           
            },
            @{
                description           = 'Export all unassigned configuration profiles to a CSV file'
                name                  = 'Export all unassigned configurations'        
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )                       
            },
            @{
                description           = 'Export all Windows configurations and their assignments to a CSV file'
                name                  = 'Export all Windows configurations and their assignments'
                blockType             = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )           
            },
            @{
                description           = 'Export all tenant configurations and their assignments to a CSV file'
                name                  = 'Export all tenant configurations and their assignments'
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
    groupAssignmentsMenu      = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        type                  = 'dynamic'
        Title                 = 'Group Assignments for $groupName'
        Description           = 'What type of assignments would you like to see?'
    }
    deviceWaitMenu            = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items                 = @(@{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'Restart the device'
                Description           = 'Restart the device'
            })
        type                  = 'static'
        Title                 = 'Device Wait Menu'
        Description           = 'Choose what you would like to do with this device:'
    }
    inclusionExclusionMenu    = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change group inclusion/exclusion'
                description           = 'Modify the groups that are included or excluded from operations'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change Autopilot profile settings'
                description           = 'Modify the Autopilot profiles that are considered valid for assignment'
            }
        )
        type                  = 'static'
        Title                 = 'Inclusion/Exclusion Settings'
        Description           = 'Manage group and Autopilot profile inclusion/exclusion settings:'
    }
    groupsEditMenu            = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Edit Groups to Include'
                description           = 'Modify the groups that are included'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Edit Groups to Exclude'
                description           = 'Modify the groups that are excluded'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'View Current Group Settings'
                description           = 'View the current group settings'
            }
        )
        type                  = 'static'
        Title                 = 'Groups Edit Menu'
        Description           = 'Select which group settings you want to modify:'
    }
    reportExportMenu          = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'Display on Screen'
                Description           = 'Display the report on screen'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'Export to HTML'
                Description           = 'Export the report in HTML format'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'Export to CSV'
                Description           = 'Export the report in CSV format'
            }
        )
        type                  = 'static'
        Title                 = 'Device Health Menu'
        Description           = 'Select whether you want to display or export the device health report'
    }
    autopilotProfilesEditMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        items                 = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Modify Autopilot profiles to include'
                description           = 'Modify the Autopilot profiles that are included'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'View current Autopilot profile settings'
                description           = 'View the current Autopilot profile settings'
            }
        )
        type                  = 'static'
        Title                 = 'Autopilot Profiles Edit Menu'
        Description           = 'Select which Autopilot profile settings you want to modify:'
    }
}
