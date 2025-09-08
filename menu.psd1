@{
    userMenu             = @{
        type                  = 'dynamic'
        Title                 = 'Select a user'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        Description           = 'Did you mean:'
    }
    version              = '1.3.0.0'
    groupsEditMenu       = @{
        Description           = 'Select which group settings you want to modify:'
        items                 = @(
            @{
                description           = 'Modify the groups that are included'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Edit Groups to Include'
            },
            @{
                description           = 'Modify the groups that are excluded'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Edit Groups to Exclude'
            },
            @{
                description           = 'View the current group settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'View Current Group Settings'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        type                  = 'static'
        Title                 = 'Groups Editor for $DomainName'
    }
    groupAssignmentsMenu = @{
        type                  = 'dynamic'
        Title                 = 'Group Assignments for $groupName'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        Description           = 'What type of assignments would you like to see?'
    }
    settingsMenu         = @{
        Description           = 'Make changes to the application settings'
        items                 = @(
            @{
                description           = 'Change the environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'menu'
                menuName              = 'environmentMenu'
                name                  = 'Change environment settings'
            },
            @{
                description           = 'Change the Entra credentials'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Change Entra Credentials'
            },
            @{
                description           = 'Change the Auto Update settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Change Auto Update settings'
            },
            @{
                description           = 'Change the App Mode settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change App Mode settings'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        type                  = 'static'
        Title                 = 'Settings menu'
    }
    description          = 'This file contains the definitions for the menus used in the application.'
    deviceActionsMenu    = @{
        Description           = 'Select an action to perform on this device:'
        items                 = @(
            @{
                description           = 'Wipe the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Wipe Device'
            },
            @{
                description           = 'Clean the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                type                  = 'action'
                name                  = 'Clean Device'
            },
            @{
                description           = 'Sync the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Sync Device'
            },
            @{
                description           = 'Retrieve the LAPS password for the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Get LAPS Password'
            },
            @{
                description           = 'Retrieve the BitLocker recovery key for the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Get BitLocker Recovery Key'
            },
            @{
                description           = 'Retrieve the BIOS password details for the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Get Hardware Password Details'
            },
            @{
                description           = 'Restart the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Restart Device'
            },
            @{
                description           = 'Show the health status of the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Show Device Health Status'
            },
            @{
                description           = 'Check the next user readiness state for the selected device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Check next user readiness state'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        type                  = 'static'
        Title                 = 'Device Actions for $deviceName'
    }
    exportMenu           = @{
        Description           = 'Choose what you would like to export'
        items                 = @(
            @{
                description           = 'Export Autopilot devices to a CSV file'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Export Autopilot Devices'
            },
            @{
                description           = 'Export imported Autopilot devices to a CSV file'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Export Imported Autopilot Devices'
            },
            @{
                description           = 'Export managed Windows devices to a CSV file'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Export Managed Windows Devices'
            },
            @{
                description           = 'Export unmanaged Windows devices to a CSV file'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                type                  = 'action'
                name                  = 'Export Unmanaged Windows Devices'
            },
            @{
                description           = 'Export a report of device storage to a CSV file'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                type                  = 'action'
                name                  = 'Export device storage report'
            },
            @{
                description           = 'Export application assignments to a CSV file'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                type                  = 'action'
                name                  = 'Export Application Assignments'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        type                  = 'static'
        Title                 = 'Export Menu'
    }
    serialNumberMenu     = @{
        Description           = 'How would you like to enter the serial number?'
        items                 = @(
            @{
                description           = 'Lookup a device by its serial number'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Enter a serial number'
            },
            @{
                description           = 'Lookup the device the application is running on'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Use this device''s serial number'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
        type                  = 'static'
        Title                 = 'Lookup by Serial Number'
    }
    environmentMenu      = @{
        Description           = 'Manage your environment settings and configurations'
        items                 = @(
            @{
                description           = 'View the global environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'View global environment settings'
            },
            @{
                description           = 'View the domain specific environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'View domain specific environment settings'
            },
            @{
                description           = 'View the group inclusion/exclusion settings for all domains'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'View group inclusion/exclusion settings for all domains'
            },
            @{
                description           = 'Change the global environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change global environment settings'
            },
            @{
                description           = 'Change the domain specific environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change domain specific settings'
            },
            @{
                description           = 'Change the authentication settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change authentication settings'
            },
            @{
                description           = 'Change the group inclusion/exclusion settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType             = 'action'
                name                  = 'Change group inclusion/exclusion'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        type                  = 'static'
        Title                 = 'Change Environment Menu'
    }
    name                 = 'menu.psd1'
    deviceWaitMenu       = @{
        Description           = 'Choose what you would like to do with this device:'
        items                 = @(
            @{
                Description           = 'Restart the device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                Name                  = 'Restart the device'
            },
            @{
                Description           = 'Continue to wait for profile assignment'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                Name                  = 'Continue to wait for profile assignment'
            },
            @{
                Description           = 'Delete the device from Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                blockType             = 'action'
                Name                  = 'Delete the device from Autopilot'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        type                  = 'static'
        Title                 = 'Options for Device With Serial Number '
    }
    reportExportMenu     = @{
        Description           = 'Select the format to which you would like to export the report'
        items                 = @(
            @{
                Description           = 'Export the report in HTML format'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                Type                  = 'action'
                Name                  = 'Export to HTML'
            },
            @{
                Description           = 'Export the report in CSV format'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                Type                  = 'action'
                Name                  = 'Export to CSV'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        type                  = 'static'
        Title                 = 'Export report'
    }
    appModeHierarchy     = @{
        full                 = @(
            '*'
        )
        advanced             = @(
            'advanced',
            'helpdesk',
            'registration'
        )
        advancedRegistration = @(
            'advancedRegistration',
            'registration'
        )
        registration         = @(
            'registration'
        )
        admin                = @(
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        custom               = @(
        )
        helpdesk             = @(
            'helpdesk'
        )
    }
    autopilotMenu        = @{
        Description           = 'Import a device into Autopilot and perform related actions'
        items                 = @(
            @{
                description           = 'Import a device into Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Import device into Autopilot'
            },
            @{
                description           = 'Custom import a device into Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Custom import device into Autopilot (requires admin rights)'
            },
            @{
                description           = 'Import a Corporate Device Identifier for Device Preparation'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Import Corporate Device Identifier for Device Preparation (requires admin rights)'
            },
            @{
                description           = 'Export a Corporate Device Identifier for manual upload to Device Preparation'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)'
            },
            @{
                description           = 'Get the device hash for manual upload to Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Get device hash for manual upload to Autopilot (requires admin rights)'
            },
            @{
                description           = 'Download and install the latest Windows updates'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Download and install latest Windows updates(requires admin rights)'
            },
            @{
                description           = 'Check if a device is registered in Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Check device Autopilot status'
            },
            @{
                description           = 'Delete a device from Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Delete device from Autopilot'
            },
            @{
                description           = 'Quick import a device into Autopilot'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Quick Import device into Autopilot (requires admin rights)'
            },
            @{
                description           = 'Delete a Corporate Device Identifier from Device Preparation'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
                type                  = 'action'
                name                  = 'Delete Corporate Device Identifier from Device Preparation (requires admin rights)'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'registration',
            'advancedRegistration'
        )
        type                  = 'static'
        Title                 = 'Autopilot Menu'
    }
    deviceMenu           = @{
        type                  = 'dynamic'
        Title                 = 'Device Selection'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        Description           = 'Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))'
    }
    groupMenu            = @{
        type                  = 'dynamic'
        Title                 = 'Select a group'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        Description           = 'Did you mean:'
    }
    checkMenu            = @{
        Description           = 'How would you like to lookup the device?'
        items                 = @(
            @{
                description           = 'Lookup a device by its serial number'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                blockType             = 'menu'
                menuName              = 'serialNumberMenu'
                name                  = 'Lookup device by Serial Number'
            },
            @{
                description           = 'Lookup a device by the user id or email address'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                type                  = 'action'
                name                  = 'Lookup device by User'
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
        type                  = 'static'
        Title                 = 'Check Device Status'
    }
    appModeDefaults      = @{
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
        custom               = @{
            capabilities = @(
                'user_defined'
            )
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
    }
    appModeMenu          = @{
        type                  = 'dynamic'
        Title                 = '$menuTitle'
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        Description           = '$menuDescription'
    }
    mainMenu             = @{
        Description           = 'Please choose from one of the following options'
        items                 = @(
            @{
                description           = 'Start the user and device readiness check'
                includeInDisplayModes = @(
                    'full',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'Give a device to a user'
            },
            @{
                description           = 'Troubleshoot a device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                blockType             = 'menu'
                menuName              = 'checkMenu'
                name                  = 'Check device status'
            },
            @{
                description           = 'Import a device into Autopilot and perform related actions'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                blockType             = 'menu'
                menuName              = 'autopilotMenu'
                name                  = 'Autopilot menu'
            },
            @{
                description           = 'Modify the application settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'menu'
                menuName              = 'settingsMenu'
                name                  = 'Change application settings'
            },
            @{
                description           = 'Check if there are any updates available for the scripts'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Check for script updates'
            },
            @{
                description           = 'Restart the device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                blockType             = 'action'
                name                  = 'Restart the device'
            },
            @{
                description           = 'Show the group assignments for the device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType             = 'action'
                name                  = 'Show Group Assignments'
            },
            @{
                description           = 'Export device information'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration'
                )
                blockType             = 'menu'
                menuName              = 'exportMenu'
                name                  = 'Export Menu'
            },
            @{
                description           = 'Learn more about this application'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType             = 'action'
                name                  = 'About'
            }
        )
        includeInDisplayModes = @(
        )
        type                  = 'static'
        Title                 = 'Main Menu'
    }
}
