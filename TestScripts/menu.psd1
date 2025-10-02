@{
    version = '1.3.0.0'
    name = 'menu.psd1'
    description = 'This file contains the definitions for the menus used in the application.'
    appModeHierarchy = @{
        registration = @(
            'helpdesk',
            'registration'
        )
        admin = @(
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        advanced = @(
            'advanced',
            'helpdesk',
            'registration'
        )
        full = @(
            '*'
        )
        custom = @()
        helpdesk = @(
            'helpdesk'
        )
        advancedRegistration = @(
            'advancedRegistration',
            'registration'
        )
    }
    appModeDefaults = @{
        registration = @{
            capabilities = @(
                'autopilot_registration',
                'device_import',
                'basic_exports',
                'device_status_check'
            )
            description = 'Device registration specialist with Autopilot enrollment capabilities'
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
        custom = @{
            capabilities = @(
                'user_defined'
            )
            description = 'Customizable mode where users define their own access patterns'
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
    }
    mainMenu = @{
        includeInDisplayModes = @()
        items = @(
            @{
                name = 'Give a device to a user'
                description = 'Start the user and device readiness check'
                includeInDisplayModes = @(
                    'full',
                    'helpdesk',
                    'registration'
                )
                blockType = 'action'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                name = 'Check device status'
                description = 'Troubleshoot a device'
                blockType = 'menu'
                menuName = 'checkMenu'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration',
                    'advancedRegistration'
                )
                name = 'Autopilot menu'
                description = 'Import a device into Autopilot and perform related actions'
                blockType = 'menu'
                menuName = 'autopilotMenu'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                name = 'Change application settings'
                description = 'Modify the application settings'
                blockType = 'menu'
                menuName = 'settingsMenu'
            },
            @{
                name = 'Check for script updates'
                description = 'Check if there are any updates available for the scripts'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'helpdesk',
                    'registration',
                    'advancedRegistration',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                name = 'Restart the device'
                description = 'Restart the device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                blockType = 'action'
            },
            @{
                name = 'Show Group Assignments'
                description = 'Show the group assignments for the device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'registration'
                )
                name = 'Export Menu'
                description = 'Export device information'
                blockType = 'menu'
                menuName = 'exportMenu'
            },
            @{
                name = 'About'
                description = 'Learn more about this application'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType = 'action'
            }
        )
        Description = 'Please choose from one of the following options'
        type = 'static'
        Title = 'Main Menu'
    }
    checkMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
        items = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
                name = 'Lookup device by Serial Number'
                description = 'Lookup a device by its serial number'
                blockType = 'menu'
                menuName = 'serialNumberMenu'
            },
            @{
                name = 'Lookup device by User'
                description = 'Lookup a device by the user id or email address'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            }
        )
        Description = 'How would you like to lookup the device?'
        type = 'static'
        Title = 'Check Device Status'
    }
    autopilotMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'registration',
            'advancedRegistration'
        )
        items = @(
            @{
                name = 'Quick Import device into Autopilot (requires admin rights)'
                description = 'Quick import a device into Autopilot'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'registration',
                    'advancedRegistration'
                )
            },
            @{
                name = 'Custom import device into Autopilot (requires admin rights)'
                description = 'Custom import a device into Autopilot'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            },
            @{
                name = 'Import Corporate Device Identifier for Device Preparation (requires admin rights)'
                description = 'Import a Corporate Device Identifier for Device Preparation'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            },
            @{
                name = 'Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)'
                description = 'Export a Corporate Device Identifier for manual upload to Device Preparation'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            },
            @{
                name = 'Get device hash for manual upload to Autopilot (requires admin rights)'
                description = 'Get the device hash for manual upload to Autopilot'
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
                name = 'Download and install latest Windows updates(requires admin rights)'
                description = 'Download and install the latest Windows updates'
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
                name = 'Check device Autopilot status'
                description = 'Check if a device is registered in Autopilot'
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
                name = 'Delete device from Autopilot'
                description = 'Delete a device from Autopilot'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'advancedRegistration'
                )
            },
            @{
                name = 'Delete Corporate Device Identifier from Device Preparation (requires admin rights)'
                description = 'Delete a Corporate Device Identifier from Device Preparation'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advancedRegistration'
                )
            }
        )
        Description = 'Import a device into Autopilot and perform related actions'
        type = 'static'
        Title = 'Autopilot Menu'
    }
    settingsMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        items = @(
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                name = 'Change environment settings'
                description = 'Change the environment settings'
                blockType = 'menu'
                menuName = 'environmentMenu'
            },
            @{
                name = 'Change Entra Credentials'
                description = 'Change the Entra credentials'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                name = 'Change Auto Update settings'
                description = 'Change the Auto Update settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                name = 'Change App Mode settings'
                description = 'Change the App Mode settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            }
        )
        Description = 'Make changes to the application settings'
        type = 'static'
        Title = 'Settings menu'
    }
    exportMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items = @(
            @{
                name = 'Export Autopilot Devices'
                description = 'Export Autopilot devices to a CSV file'
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
                name = 'Export Imported Autopilot Devices'
                description = 'Export imported Autopilot devices to a CSV file'
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
                name = 'Export Managed Windows Devices'
                description = 'Export managed Windows devices to a CSV file'
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
                name = 'Export Unmanaged Windows Devices'
                description = 'Export unmanaged Windows devices to a CSV file'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                name = 'Export device storage report'
                description = 'Export a report of device storage to a CSV file'
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
                name = 'Export Application Assignments'
                description = 'Export application assignments to a CSV file'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            }
        )
        Description = 'Choose what you would like to export'
        type = 'static'
        Title = 'Export Menu'
    }
    serialNumberMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk'
        )
        items = @(
            @{
                name = 'Enter a serial number'
                description = 'Lookup a device by its serial number'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                name = 'Use this device''s serial number'
                description = 'Lookup the device the application is running on'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            }
        )
        Description = 'How would you like to enter the serial number?'
        type = 'static'
        Title = 'Lookup by Serial Number'
    }
    environmentMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        items = @(
            @{
                name = 'View global environment settings'
                description = 'View the global environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                name = 'View domain specific environment settings'
                description = 'View the domain specific environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                name = 'View group inclusion/exclusion settings for all domains'
                description = 'View the group inclusion/exclusion settings for all domains'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
                blockType = 'action'
            },
            @{
                name = 'Change global environment settings'
                description = 'Change the global environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                name = 'Change domain specific settings'
                description = 'Change the domain specific environment settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                name = 'Change authentication settings'
                description = 'Change the authentication settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                name = 'Change inclusion/exclusion'
                description = 'Change the inclusion/exclusion settings for groups and Autopilot profiles'
                blockType = 'menu'
                menuName = 'inclusionExclusionMenu'
            }
        )
        Description = 'Manage your environment settings and configurations'
        type = 'static'
        Title = 'Change Environment Menu'
    }
    userMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        Description = 'Did you mean:'
        type = 'dynamic'
        Title = 'Select a user'
    }
    deviceMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        Description = 'Select a device for user $UserName ($($deviceInfo.value[0].userDisplayName))'
        type = 'dynamic'
        Title = 'Device Selection'
    }
    groupMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        Description = 'Did you mean:'
        type = 'dynamic'
        Title = 'Select a group'
    }
    deviceActionsMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items = @(
            @{
                name = 'Wipe Device'
                description = 'Wipe the selected device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                name = 'Clean Device'
                description = 'Clean the selected device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced'
                )
            },
            @{
                name = 'Sync Device'
                description = 'Sync the selected device'
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
                name = 'Get LAPS Password'
                description = 'Retrieve the LAPS password for the selected device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                name = 'Get BitLocker Recovery Key'
                description = 'Retrieve the BitLocker recovery key for the selected device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                name = 'Get Hardware Password Details'
                description = 'Retrieve the BIOS password details for the selected device'
                type = 'action'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk'
                )
            },
            @{
                name = 'Restart Device'
                description = 'Restart the selected device'
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
                name = 'Show Device Health Status'
                description = 'Show the health status of the selected device'
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
                name = 'Check next user readiness state'
                description = 'Check the next user readiness state for the selected device'
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
        Description = 'Select an action to perform on this device:'
        type = 'static'
        Title = 'Device Actions for $deviceName'
    }
    appModeMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        Description = '$menuDescription'
        type = 'dynamic'
        Title = '$menuTitle'
    }
    groupAssignmentsMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced'
        )
        Description = 'What type of assignments would you like to see?'
        type = 'dynamic'
        Title = 'Group Assignments for $groupName'
    }
    deviceWaitMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items = @(
            @{
                name = 'Restart the device'
                Description = 'Restart the device'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType = 'action'
            }
        )
        Description = 'Choose what you would like to do with this device:'
        type = 'static'
        Title = 'Device Wait Menu'
    }
    inclusionExclusionMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        items = @(
            @{
                name = 'Change group inclusion/exclusion'
                description = 'Modify the groups that are included or excluded from operations'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                name = 'Change Autopilot profile settings'
                description = 'Modify the Autopilot profiles that are considered valid for assignment'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            }
        )
        Description = 'Manage group and Autopilot profile inclusion/exclusion settings:'
        type = 'static'
        Title = 'Inclusion/Exclusion Settings'
    }
    groupsEditMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        items = @(
            @{
                name = 'Edit Groups to Include'
                description = 'Modify the groups that are included'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                name = 'Edit Groups to Exclude'
                description = 'Modify the groups that are excluded'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                name = 'View Current Group Settings'
                description = 'View the current group settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            }
        )
        Description = 'Select which group settings you want to modify:'
        type = 'static'
        Title = 'Groups Edit Menu'
    }
    reportExportMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin',
            'advanced',
            'helpdesk',
            'registration'
        )
        items = @(
            @{
                name = 'Export in HTML format'
                Description = 'Export the report in HTML format'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType = 'action'
            },
            @{
                name = 'Export in CSV format'
                Description = 'Export the report in CSV format'
                includeInDisplayModes = @(
                    'full',
                    'admin',
                    'advanced',
                    'helpdesk',
                    'registration'
                )
                blockType = 'action'
            }
        )
        Description = 'Select the format to which you would like to export the report'
        type = 'static'
        Title = 'Report Export Menu'
    }
    autopilotProfilesEditMenu = @{
        includeInDisplayModes = @(
            'full',
            'admin'
        )
        items = @(
            @{
                name = 'Modify Autopilot profiles to include'
                description = 'Modify the Autopilot profiles that are included'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            },
            @{
                name = 'View current Autopilot profile settings'
                description = 'View the current Autopilot profile settings'
                includeInDisplayModes = @(
                    'full',
                    'admin'
                )
                blockType = 'action'
            }
        )
        Description = 'Select which Autopilot profile settings you want to modify:'
        type = 'static'
        Title = 'Autopilot Profiles Edit Menu'
    }
}
