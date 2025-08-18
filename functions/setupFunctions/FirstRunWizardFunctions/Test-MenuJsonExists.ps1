function Test-MenuJsonExists()
{
    <#
    .SYNOPSIS
        Ensures that menu.json exists with default menu definitions.
    
    .DESCRIPTION
        Checks if menu.json exists, and if not, creates it with comprehensive default values
        for all menu configurations including hierarchy, app mode defaults, and menu definitions.
        If the file exists, merges any missing menu configurations with existing content.
    
    .PARAMETER MenuFile
        Path to the menu.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file exists or was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuFile,
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring menu.json exists: $MenuFile"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Ensuring menu.json exists: $MenuFile" -LogLevel "Information"
    
    try
    {
        # Define comprehensive default menu structure using ordered hashtables to preserve menu order
        $defaultMenus = [ordered]@{
            name = "menu.json"
            description = "This file contains the definitions for the menus used in the application."
            version = $version.version.toString()
            appModeHierarchy = [ordered]@{
                full = @("*")
                advanced = @("advanced", "helpdesk", "registration")
                helpdesk = @("helpdesk")
                registration = @("registration")
                advancedRegistration = @("advancedRegistration", "registration")
                admin = @("admin", "advanced", "helpdesk", "registration")
                custom = @()
            }
            appModeDefaults = [ordered]@{
                full = [ordered]@{
                    description = "Full administrative access with all features enabled"
                    capabilities = @(
                        "all_menus",
                        "all_actions", 
                        "settings_management",
                        "advanced_diagnostics",
                        "export_all",
                        "device_management"
                    )
                }
                advanced = [ordered]@{
                    description = "Advanced user with helpdesk and configuration capabilities"
                    capabilities = @(
                        "advanced_features",
                        "helpdesk_operations",
                        "device_registration",
                        "settings_view",
                        "advanced_exports"
                    )
                }
                helpdesk = [ordered]@{
                    description = "Helpdesk operator with device troubleshooting and user assignment capabilities"
                    capabilities = @(
                        "device_assignment",
                        "device_troubleshooting",
                        "basic_exports",
                        "device_actions",
                        "user_management"
                    )
                }
                registration = [ordered]@{
                    description = "Device registration specialist with Autopilot enrollment capabilities"
                    capabilities = @(
                        "autopilot_registration",
                        "device_import",
                        "basic_exports",
                        "device_status_check"
                    )
                }
                advancedRegistration = [ordered]@{
                    description = "Advanced registration specialist with administrative Autopilot capabilities"
                    capabilities = @(
                        "advanced_autopilot",
                        "custom_import",
                        "device_preparation",
                        "advanced_device_actions"
                    )
                }
                admin = [ordered]@{
                    description = "System administrator with full configuration and management capabilities"
                    capabilities = @(
                        "system_administration",
                        "advanced_features",
                        "helpdesk_operations",
                        "device_registration",
                        "full_configuration"
                    )
                }
                custom = [ordered]@{
                    description = "Customizable mode where users define their own access patterns"
                    capabilities = @("user_defined")
                }
            }
            mainMenu = [ordered]@{
                Title = "Main Menu"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @()
                items = @(
                    [ordered]@{
                        name = "Give a device to a user"
                        description = "Start the user and device readiness check"
                        blockType = "action"
                        includeInDisplayModes = @("full", "helpdesk", "registration")
                    },
                    [ordered]@{
                        name = "Check device status"
                        description = "Troubleshoot a device"
                        blockType = "menu"
                        menuName = "checkMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Autopilot menu"
                        description = "Import a device into Autopilot and perform related actions"
                        blockType = "menu"
                        menuName = "autopilotMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Change application settings"
                        description = "Modify the application settings"
                        blockType = "menu"
                        menuName = "settingsMenu"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Check for script updates"
                        description = "Check if there are any updates available for the scripts"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Restart the device"
                        description = "Restart the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Show Group Assignments"
                        description = "Show the group assignments for the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Export Menu"
                        description = "Export device information"
                        blockType = "menu"
                        menuName = "exportMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration")
                    },
                    [ordered]@{
                        name = "About"
                        description = "Learn more about this application"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    }
                )
            }
            checkMenu = [ordered]@{
                Title = "Check Device Status"
                Description = "How would you like to lookup the device?"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                items = @(
                    [ordered]@{
                        name = "Lookup device by Serial Number"
                        description = "Lookup a device by its serial number"
                        blockType = "menu"
                        menuName = "serialNumberMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Lookup device by User"
                        description = "Lookup a device by the user id or email address"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    }
                )
            }
            serialNumberMenu = [ordered]@{
                Title = "Lookup by Serial Number"
                Description = "How would you like to enter the serial number?"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                items = @(
                    [ordered]@{
                        name = "Enter a serial number"
                        description = "Lookup a device by its serial number"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Use this device's serial number"
                        description = "Lookup the device the application is running on"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    }
                )
            }
            autopilotMenu = [ordered]@{
                Title = "Autopilot Menu"
                Description = "Import a device into Autopilot and perform related actions"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                items = @(
                    [ordered]@{
                        name = "Import device into Autopilot"
                        description = "Import a device into Autopilot"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Custom import device into Autopilot (requires admin rights)"
                        description = "Custom import a device into Autopilot"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Import Corporate Device Identifier for Device Preparation (requires admin rights)"
                        description = "Import a Corporate Device Identifier for Device Preparation"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Export Corporate Device Identifier for manual upload to Device Preparation (requires admin rights)"
                        description = "Export a Corporate Device Identifier for manual upload to Device Preparation"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Get device hash for manual upload to Autopilot (requires admin rights)"
                        description = "Get the device hash for manual upload to Autopilot"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Download and install latest Windows updates(requires admin rights)"
                        description = "Download and install the latest Windows updates"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Check device Autopilot status"
                        description = "Check if a device is registered in Autopilot"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Delete device from Autopilot"
                        description = "Delete a device from Autopilot"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Quick Import device into Autopilot (requires admin rights)"
                        description = "Quick import a device into Autopilot"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Delete Corporate Device Identifier from Device Preparation (requires admin rights)"
                        description = "Delete a Corporate Device Identifier from Device Preparation"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advancedRegistration")
                    }
                )
            }
            settingsMenu = [ordered]@{
                Title = "Settings menu"
                Description = "Make changes to the application settings"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced")
                items = @(
                    [ordered]@{
                        name = "Change environment settings"
                        description = "Change the environment settings"
                        blockType = "menu"
                        menuName = "environmentMenu"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Change Entra Credentials"
                        description = "Change the Entra credentials"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Change Auto Update settings"
                        description = "Change the Auto Update settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Change App Mode settings"
                        description = "Change the App Mode settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    }
                )
            }
            environmentMenu = [ordered]@{
                Title = "Change Environment Menu"
                Description = "Manage your environment settings and configurations"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced")
                items = @(
                    [ordered]@{
                        name = "View global environment settings"
                        description = "View the global environment settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "View domain specific environment settings"
                        description = "View the domain specific environment settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "View group inclusion/exclusion settings for all domains"
                        description = "View the group inclusion/exclusion settings for all domains"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Change global environment settings"
                        description = "Change the global environment settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    },
                    [ordered]@{
                        name = "Change domain specific settings"
                        description = "Change the domain specific environment settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    },
                    [ordered]@{
                        name = "Change authentication settings"
                        description = "Change the authentication settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    },
                    [ordered]@{
                        name = "Change group inclusion/exclusion"
                        description = "Change the group inclusion/exclusion settings"
                        blockType = "menu"
                        menuName = "groupsEditMenu"
                        includeInDisplayModes = @("full", "admin")
                    }
                )
            }
            exportMenu = [ordered]@{
                Title = "Export Menu"
                Description = "Choose what you would like to export"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @(
                    [ordered]@{
                        name = "Export Autopilot Devices"
                        description = "Export Autopilot devices to a CSV file"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Export Imported Autopilot Devices"
                        description = "Export imported Autopilot devices to a CSV file"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    [ordered]@{
                        name = "Export Managed Windows Devices"
                        description = "Export managed Windows devices to a CSV file"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        name = "Export Unmanaged Windows Devices"
                        description = "Export unmanaged Windows devices to a CSV file"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Export device storage report"
                        description = "Export a report of device storage to a CSV file"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        name = "Export Application Assignments"
                        description = "Export application assignments to a CSV file"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    }
                )
            }
            deviceWaitMenu = [ordered]@{
                Title = "Options for Device With Serial Number `$serialNumber"
                Description = "Choose what you would like to do with this device:"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @(
                    [ordered]@{
                        Name = "Restart the device"
                        Description = "Restart the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        Name = "Continue to wait for profile assignment"
                        Description = "Continue to wait for profile assignment"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        Name = "Delete the device from Autopilot"
                        Description = "Delete the device from Autopilot"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    }
                )
            }
            deviceMenu = [ordered]@{
                Title = "Device Selection"
                Description = "Select a device for user `$UserName (`$(`$deviceInfo.value[0].userDisplayName))"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
            }
            deviceActionsMenu = [ordered]@{
                Title = "Device Actions for `$deviceName"
                Description = "Select an action to perform on this device:"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @(
                    [ordered]@{
                        name = "Wipe Device"
                        description = "Wipe the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Clean Device"
                        description = "Clean the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    [ordered]@{
                        name = "Sync Device"
                        description = "Sync the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        name = "Get LAPS Password"
                        description = "Retrieve the LAPS password for the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Get BitLocker Recovery Key"
                        description = "Retrieve the BitLocker recovery key for the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Get Hardware Password Details"
                        description = "Retrieve the BIOS password details for the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    [ordered]@{
                        name = "Restart Device"
                        description = "Restart the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        name = "Show Device Health Status"
                        description = "Show the health status of the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        name = "Check next user readiness state"
                        description = "Check the next user readiness state for the selected device"
                        type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    }
                )
            }
            reportExportMenu = [ordered]@{
                Title = "Export report"
                Description = "Select the format to which you would like to export the report"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @(
                    [ordered]@{
                        Name = "Export to HTML"
                        Description = "Export the report in HTML format"
                        Type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    [ordered]@{
                        Name = "Export to CSV"
                        Description = "Export the report in CSV format"
                        Type = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    }
                )
            }
            groupsEditMenu = [ordered]@{
                Title = "Groups Editor for `$DomainName"
                Description = "Select which group settings you want to modify:"
                type = "static"
                includeInDisplayModes = @("full", "admin")
                items = @(
                    [ordered]@{
                        name = "Edit Groups to Include"
                        description = "Modify the groups that are included"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    },
                    [ordered]@{
                        name = "Edit Groups to Exclude"
                        description = "Modify the groups that are excluded"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    },
                    [ordered]@{
                        name = "View Current Group Settings"
                        description = "View the current group settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    }
                )
            }
            appModeMenu = [ordered]@{
                Title = "`$menuTitle"
                Description = "`$menuDescription"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin")
            }
            groupMenu = [ordered]@{
                Title = "Select a group"
                Description = "Did you mean:"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced")
            }
            userMenu = [ordered]@{
                Title = "Select a user"
                Description = "Did you mean:"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
            }
            groupAssignmentsMenu = [ordered]@{
                Title = "Group Assignments for `$groupName"
                Description = "What type of assignments would you like to see?"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced")
            }
        }
        
        if (Test-Path -Path $MenuFile)
        {
            Write-Verbose "[$functionName] Menu file exists, checking for missing default values: $MenuFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu file exists, checking for updates: $MenuFile" -LogLevel "Information"
            
            try
            {
                # Load existing menu configurations
                $existingMenus = Get-Content -Path $MenuFile -Raw | ConvertFrom-Json
                
                # Convert JSON object to hashtable for merging
                $existingHashtable = @{}
                $existingMenus.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject])
                    {
                        $existingHashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
                    }
                    else
                    {
                        $existingHashtable[$_.Name] = $_.Value
                    }
                }
                
                # Merge defaults into existing configuration
                $mergedMenus = Merge-ConfigurationDefaults -ExistingConfig $existingHashtable -DefaultConfig $defaultMenus
                
                if ($null -ne $mergedMenus)
                {
                    Write-Verbose "[$functionName] Merging default menu configurations into existing file"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Merging default menu configurations into existing file" -LogLevel "Information"
                    $mergedJson = ConvertTo-OrderedJson -InputObject $mergedMenus -Depth $maxJSONDepth
                    Set-Content -Path $MenuFile -Value $mergedJson -Encoding UTF8 -Force
                    Write-Verbose "[$functionName] Updated menu.json with missing default values"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Updated menu.json with missing default values" -LogLevel "Information"
                    if (-not $Silent)
                    {
                        Write-Host "Menu file updated with new default values." -ForegroundColor Green
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Menu file is up-to-date"
                }
                return $true
            }
            catch
            {
                Write-Verbose "[$functionName] Error processing existing menu file: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error processing existing menu file: $($_.Exception.Message)" -LogLevel "Warning"
                # Continue with creating new file as fallback
            }
        }
        
        if (-not $Silent)
        {
            Write-Host "`n── Menu Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default menu.json file..." -ForegroundColor White
        }
        
        # File doesn't exist, create it with default menu configurations
        if (-not $Silent)
        {
            Write-Host "Creating default menu.json file..." -ForegroundColor White
        }
        
        # Convert to JSON with proper ordering and write to file
        $menuJson = ConvertTo-OrderedJson -InputObject $defaultMenus -Depth $maxJSONDepth
        Set-Content -Path $MenuFile -Value $menuJson -Encoding UTF8 -Force
        Write-Verbose "[$functionName] Created comprehensive menu.json with all menu definitions"
        
        $success = $true
        
        if ($success)
        {
            Write-Host "Menu file created successfully." -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu file created successfully: $MenuFile" -LogLevel "Information"
            return $true
        }
        else
        {
            Write-Host "Failed to create menu file." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to create menu file: $MenuFile" -LogLevel "Error"
            return $false
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error ensuring menu.json exists: $($_.Exception.Message)" -LogLevel "Error"
        Write-Host "Error creating menu file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
}