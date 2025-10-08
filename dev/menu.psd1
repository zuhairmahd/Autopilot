@{
    version = '1.3.0.0'
    name = 'menu.psd1'
    description = 'This file contains the definitions for the menus used in the application.'
    appModeHierarchy = @{
        advanced = @(
            'advanced',
            'helpdesk',
            'registration'
        )
        custom = @()
        registration = @(
            'helpdesk',
            'registration'
        )
        helpdesk = @(
            'helpdesk'
        )
        advancedRegistration = @(
            'advancedRegistration',
            'registration'
        )
        admin = @(
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        full = @(
            '*'
        )
    }
    appModeDefaults = @{
        advanced = @{
            capabilities = @(
                'advanced_features',
                'helpdesk_operations',
                'device_registration',
                'settings_view',
                'advanced_exports'
            )
            description = 'Advanced user with helpdesk and configuration capabilities'
        }
        custom = @{
            capabilities = @(
                'user_defined'
            )
            description = 'Customizable mode where users define their own access patterns'
        }
        registration = @{
            capabilities = @(
                'autopilot_registration',
                'device_import',
                'basic_exports',
                'device_status_check'
            )
            description = 'Device registration specialist with Autopilot enrollment capabilities'
        }
        helpdesk = @{
            capabilities = @(
                'device_assignment',
                'device_troubleshooting',
                'basic_exports',
                'device_actions',
                'user_management'
            )
            description = 'Helpdesk operator with device troubleshooting and user assignment capabilities'
        }
        advancedRegistration = @{
            capabilities = @(
                'advanced_autopilot',
                'custom_import',
                'device_preparation',
                'advanced_device_actions'
            )
            description = 'Advanced registration specialist with administrative Autopilot capabilities'
        }
        admin = @{
            capabilities = @(
                'system_administration',
                'advanced_features',
                'helpdesk_operations',
                'device_registration',
                'full_configuration'
            )
            description = 'System administrator with full configuration and management capabilities'
        }
        full = @{
            capabilities = @(
                'all_menus',
                'all_actions',
                'settings_management',
                'advanced_diagnostics',
                'export_all',
                'device_management'
            )
            description = 'Full administrative access with all features enabled'
        }
    }
    mainMenu = @{
        Title = 'Main Menu'
        Description = 'Please choose from one of the following options'
        type = 'static'
        items = @(
            @{
                description = 'Start the user and device readiness check'
                name = 'Give a device to a user'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                menuName = 'checkMenu'
                description = 'Troubleshoot a device'
                name = 'Check device status'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                menuName = 'autopilotMenu'
                description = 'Import a device into Autopilot and perform related actions'
                name = 'Autopilot menu'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                menuName = 'settingsMenu'
                description = 'Modify the application settings'
                name = 'Change application settings'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Check if there are any updates available for the scripts'
                name = 'Check for script updates'
                blockType = 'action'
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
                description = 'Restart the device'
                name = 'Restart the device'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Show the group assignments for the device'
                name = 'Show Group Assignments'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                menuName = 'exportMenu'
                description = 'Export device information'
                name = 'Export Menu'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration'
                )
            },
            @{
                description = 'Learn more about this application'
                name = 'About'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
        )
        includeInDisplayModes = @()
    }
    checkMenu = @{
        Title = 'Check Device Status'
        Description = 'How would you like to lookup the device?'
        type = 'static'
        items = @(
            @{
                menuName = 'serialNumberMenu'
                description = 'Lookup a device by its serial number'
                name = 'Lookup device by Serial Number'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Lookup a device by the user id or email address'
                name = 'Lookup device by User'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
    }
    autopilotMenu = @{
        Title = 'Autopilot Menu'
        Description = 'Import a device into Autopilot and perform related actions'
        type = 'static'
        items = @(
            @{
                description = 'Quick import a device into Autopilot'
                name = 'Quick Import device into Autopilot (requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Custom import a device into Autopilot'
                name = 'Custom import device into Autopilot (requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Import a Corporate Device Identifier for Device Preparation'
                name = 'Import Corporate Device Identifier for Device Preparation (requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Export a Corporate Device Identifier for manual upload to Device Preparation'
                name = 'Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Get the device hash for manual upload to Autopilot'
                name = 'Get device hash for manual upload to Autopilot (requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Download and install the latest Windows updates'
                name = 'Download and install latest Windows updates(requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Check if a device is registered in Autopilot'
                name = 'Check device Autopilot status'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Delete a device from Autopilot'
                name = 'Delete device from Autopilot'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Delete a Corporate Device Identifier from Device Preparation'
                name = 'Delete Corporate Device Identifier from Device Preparation (requires admin rights)'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'registration',
            'advancedRegistration'
        )
    }
    settingsMenu = @{
        Title = 'Settings menu'
        Description = 'Make changes to the application settings'
        type = 'static'
        items = @(
            @{
                menuName = 'environmentMenu'
                description = 'Change the environment settings'
                name = 'Change environment settings'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Change the Entra credentials'
                name = 'Change Entra Credentials'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Change the Auto Update settings'
                name = 'Change Auto Update settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Change the App Mode settings'
                name = 'Change App Mode settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
    }
    exportMenu = @{
        Title = 'Export Menu'
        Description = 'Choose what you would like to export'
        type = 'static'
        items = @(
            @{
                description = 'Export Autopilot devices to a CSV file'
                name = 'Export Autopilot Devices'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Export imported Autopilot devices to a CSV file'
                name = 'Export Imported Autopilot Devices'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                description = 'Export managed Windows devices to a CSV file'
                name = 'Export Managed Windows Devices'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                description = 'Export unmanaged Windows devices to a CSV file'
                name = 'Export Unmanaged Windows Devices'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Export a report of device storage to a CSV file'
                name = 'Export device storage report'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                description = 'Export application assignments to a CSV file'
                name = 'Export Application Assignments'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
    }
    serialNumberMenu = @{
        Title = 'Lookup by Serial Number'
        Description = 'How would you like to enter the serial number?'
        type = 'static'
        items = @(
            @{
                description = 'Lookup a device by its serial number'
                name = 'Enter a serial number'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Lookup the device the application is running on'
                name = 'Use this device''s serial number'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
    }
    environmentMenu = @{
        Title = 'Change Environment Menu'
        Description = 'Manage your environment settings and configurations'
        type = 'static'
        items = @(
            @{
                description = 'View the global environment settings'
                name = 'View global environment settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'View the domain specific environment settings'
                name = 'View domain specific environment settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'View the group inclusion/exclusion settings for all domains'
                name = 'View group inclusion/exclusion settings for all domains'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Change the global environment settings'
                name = 'Change global environment settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                description = 'Change the domain specific environment settings'
                name = 'Change domain specific settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                description = 'Change the authentication settings'
                name = 'Change authentication settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                menuName = 'inclusionExclusionMenu'
                description = 'Change the inclusion/exclusion settings for groups and Autopilot profiles'
                name = 'Change inclusion/exclusion'
                blockType = 'menu'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
    }
    userMenu = @{
        Title = 'Select a user'
        Description = 'Did you mean:'
        type = 'dynamic'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
    }
    deviceMenu = @{
        Title = 'Device Selection'
        Description = 'Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))'
        type = 'dynamic'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
    }
    groupMenu = @{
        Title = 'Select a group'
        Description = 'Did you mean:'
        type = 'dynamic'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
    }
    deviceActionsMenu = @{
        Title = 'Device Actions for $deviceName'
        Description = 'Select an action to perform on this device:'
        type = 'static'
        items = @(
            @{
                description = 'Wipe the selected device'
                name = 'Wipe Device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Clean the selected device'
                name = 'Clean Device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                description = 'Sync the selected device'
                name = 'Sync Device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                description = 'Retrieve the LAPS password for the selected device'
                name = 'Get LAPS Password'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Retrieve the BitLocker recovery key for the selected device'
                name = 'Get BitLocker Recovery Key'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Retrieve the BIOS password details for the selected device'
                name = 'Get Hardware Password Details'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                description = 'Restart the selected device'
                name = 'Restart Device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                description = 'Show the health status of the selected device'
                name = 'Show Device Health Status'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                description = 'Check the next user readiness state for the selected device'
                name = 'Check next user readiness state'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
    }
    appModeMenu = @{
        Title = '$menuTitle'
        Description = '$menuDescription'
        type = 'dynamic'
        includeInDisplayModes = @(
            'full',
            'admin'
        )
    }
    groupAssignmentsMenu = @{
        Title = 'Group Assignments for $groupName'
        Description = 'What type of assignments would you like to see?'
        type = 'dynamic'
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
    }
    deviceWaitMenu = @{
        Title = 'Device Wait Menu'
        Description = 'Choose what you would like to do with this device:'
        type = 'static'
        items = @(
            @{
                Description = 'Restart the device'
                name = 'Restart the device'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
    }
    inclusionExclusionMenu = @{
        Title = 'Inclusion/Exclusion Settings'
        Description = 'Manage group and Autopilot profile inclusion/exclusion settings:'
        type = 'static'
        items = @(
            @{
                description = 'Modify the groups that are included or excluded from operations'
                name = 'Change group inclusion/exclusion'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                description = 'Modify the Autopilot profiles that are considered valid for assignment'
                name = 'Change Autopilot profile settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin'
        )
    }
    groupsEditMenu = @{
        Title = 'Groups Edit Menu'
        Description = 'Select which group settings you want to modify:'
        type = 'static'
        items = @(
            @{
                description = 'Modify the groups that are included'
                name = 'Edit Groups to Include'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                description = 'Modify the groups that are excluded'
                name = 'Edit Groups to Exclude'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                description = 'View the current group settings'
                name = 'View Current Group Settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin'
        )
    }
    reportExportMenu = @{
        Title = 'Report Export Menu'
        Description = 'Select the format to which you would like to export the report'
        type = 'static'
        items = @(
            @{
                Description = 'Export the report in HTML format'
                name = 'Export in HTML format'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            },
            @{
                Description = 'Export the report in CSV format'
                name = 'Export in CSV format'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
    }
    autopilotProfilesEditMenu = @{
        Title = 'Autopilot Profiles Edit Menu'
        Description = 'Select which Autopilot profile settings you want to modify:'
        type = 'static'
        items = @(
            @{
                description = 'Modify the Autopilot profiles that are included'
                name = 'Modify Autopilot profiles to include'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            },
            @{
                description = 'View the current Autopilot profile settings'
                name = 'View current Autopilot profile settings'
                blockType = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
            }
        )
        includeInDisplayModes = @(
            'full',
            'admin'
        )
    }
}
