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
        # Define comprehensive default menu structure
        $defaultMenus = @{
            name = "menu.json"
            description = "This file contains the definitions for the menus used in the application."
            version = $version.version.toString()
            appModeHierarchy = @{
                full = @("*")
                advanced = @("advanced", "helpdesk", "registration")
                helpdesk = @("helpdesk")
                registration = @("registration")
                advancedRegistration = @("advancedRegistration", "registration")
                admin = @("admin", "advanced", "helpdesk", "registration")
                custom = @()
            }
            appModeDefaults = @{
                full = @{
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
                advanced = @{
                    description = "Advanced user with helpdesk and configuration capabilities"
                    capabilities = @(
                        "advanced_features",
                        "helpdesk_operations",
                        "device_registration",
                        "settings_view",
                        "advanced_exports"
                    )
                }
                helpdesk = @{
                    description = "Helpdesk operator with device troubleshooting and user assignment capabilities"
                    capabilities = @(
                        "device_assignment",
                        "device_troubleshooting",
                        "basic_exports",
                        "device_actions",
                        "user_management"
                    )
                }
                registration = @{
                    description = "Device registration specialist with Autopilot enrollment capabilities"
                    capabilities = @(
                        "autopilot_registration",
                        "device_import",
                        "basic_exports",
                        "device_status_check"
                    )
                }
                advancedRegistration = @{
                    description = "Advanced registration specialist with administrative Autopilot capabilities"
                    capabilities = @(
                        "advanced_autopilot",
                        "custom_import",
                        "device_preparation",
                        "advanced_device_actions"
                    )
                }
                admin = @{
                    description = "System administrator with full configuration and management capabilities"
                    capabilities = @(
                        "system_administration",
                        "advanced_features",
                        "helpdesk_operations",
                        "device_registration",
                        "full_configuration"
                    )
                }
                custom = @{
                    description = "Customizable mode where users define their own access patterns"
                    capabilities = @("user_defined")
                }
            }
            mainMenu = @{
                Title = "Main Menu"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @()
                items = @(
                    @{
                        name = "Give a device to a user"
                        description = "Start the user and device readiness check"
                        blockType = "action"
                        includeInDisplayModes = @("full", "helpdesk", "registration")
                    },
                    @{
                        name = "Check device status"
                        description = "Troubleshoot a device"
                        blockType = "menu"
                        menuName = "checkMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    @{
                        name = "Autopilot menu"
                        description = "Import a device into Autopilot and perform related actions"
                        blockType = "menu"
                        menuName = "autopilotMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Change application settings"
                        description = "Modify the application settings"
                        blockType = "menu"
                        menuName = "settingsMenu"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    @{
                        name = "Get group assignments for all objects"
                        description = "Analyze group assignments across all Intune objects"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    @{
                        name = "Export devices and/or apps"
                        description = "Export device and application data"
                        blockType = "menu"
                        menuName = "exportMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    @{
                        name = "About"
                        description = "About this application"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration", "advancedRegistration")
                    }
                )
            }
            checkMenu = @{
                Title = "Check Device Status"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                items = @(
                    @{
                        name = "Serial number"
                        description = "Check a device by serial number"
                        blockType = "menu"
                        menuName = "serialNumberMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    @{
                        name = "User"
                        description = "Check all devices assigned to a user"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    }
                )
            }
            serialNumberMenu = @{
                Title = "Options for Device With Serial Number"
                Description = "Choose what you would like to do with this device:"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                items = @(
                    @{
                        name = "Show device health status"
                        description = "Display device health and status information"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Check next user readiness state"
                        description = "Check if device is ready for next user"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    @{
                        name = "Device actions"
                        description = "Perform actions on this device"
                        blockType = "menu"
                        menuName = "deviceActionsMenu"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    }
                )
            }
            autopilotMenu = @{
                Title = "Autopilot Menu"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                items = @(
                    @{
                        name = "Import a CSV file"
                        description = "Import Autopilot devices from CSV file"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Import from PowerShell"
                        description = "Import device using PowerShell method"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Delete a device"
                        description = "Delete a device from Autopilot"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Assign a deployment profile"
                        description = "Assign deployment profile to device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Show Autopilot events"
                        description = "Display Autopilot enrollment events"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Get unmanaged devices"
                        description = "Show devices not managed by Intune"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    }
                )
            }
            settingsMenu = @{
                Title = "Application Settings"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced")
                items = @(
                    @{
                        name = "Change authentication settings"
                        description = "Modify authentication configuration"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    },
                    @{
                        name = "Change environment settings"
                        description = "Modify environment configuration"
                        blockType = "menu"
                        menuName = "environmentMenu"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    @{
                        name = "Change app mode"
                        description = "Change the application mode"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    }
                )
            }
            environmentMenu = @{
                Title = "Environment Settings"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced")
                items = @(
                    @{
                        name = "View current settings"
                        description = "Display current configuration settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    @{
                        name = "Edit settings"
                        description = "Modify application settings"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin")
                    }
                )
            }
            exportMenu = @{
                Title = "Export Options"
                Description = "Please choose from one of the following options"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @(
                    @{
                        name = "Export all devices to CSV"
                        description = "Export all device information"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    @{
                        name = "Export all applications to CSV"
                        description = "Export all application information"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced")
                    },
                    @{
                        name = "Export Autopilot devices to CSV"
                        description = "Export Autopilot device information"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    }
                )
            }
            deviceWaitMenu = @{
                Title = "Options for Device With Serial Number"
                Description = "Choose what you would like to do with this device:"
                type = "static"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @(
                    @{
                        Name = "Restart the device"
                        Description = "Restart the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    @{
                        Name = "Continue to wait for profile assignment"
                        Description = "Continue to wait for profile assignment"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    },
                    @{
                        Name = "Delete the device from Autopilot"
                        Description = "Delete the device from Autopilot"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "registration", "advancedRegistration")
                    }
                )
            }
            deviceMenu = @{
                Title = "Device Selection"
                Description = "Select a device for user"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                items = @()
            }
            deviceActionsMenu = @{
                Title = "Device Actions"
                Description = "Select an action to perform on this device:"
                type = "dynamic"
                includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                items = @(
                    @{
                        name = "Wipe Device"
                        description = "Wipe the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    @{
                        name = "Clean Device"
                        description = "Clean the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    @{
                        name = "Sync Device"
                        description = "Sync the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk")
                    },
                    @{
                        name = "Restart Device"
                        description = "Restart the device"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Show Device Health Status"
                        description = "Display device health information"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration", "advancedRegistration")
                    },
                    @{
                        name = "Check next user readiness state"
                        description = "Check if device is ready for next user"
                        blockType = "action"
                        includeInDisplayModes = @("full", "admin", "advanced", "helpdesk", "registration")
                    }
                )
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