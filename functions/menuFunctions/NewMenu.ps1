function NewMenu()
{
    <#
    .SYNOPSIS
        Creates a new menu with extensive logging and unified cache integration.
    
    .DESCRIPTION
        Creates a new menu either from configuration or manually, with comprehensive
        logging for performance monitoring and troubleshooting. Integrates with the
        unified cache management system.
    
    .PARAMETER Title
        Title for manually created menus
        
    .PARAMETER Description
        Description for manually created menus
        
    .PARAMETER MenuName
        Name of menu to load from configuration
        
    .PARAMETER MenuConfigFile
        Path to menu configuration file
        
    .PARAMETER DisableEarlyFiltering
        Disable early filtering optimization for testing/compatibility
        
    .OUTPUTS
        OrderedDictionary - Menu object with items and metadata
        
    .NOTES
        - Extensive logging for performance optimization monitoring
        - Integrates with unified cache management system
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Title,
        [Parameter(Mandatory = $false)]
        [string]$Description,
        [Parameter(Mandatory = $false)]
        [string]$MenuName,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu",
        [Parameter(Mandatory = $false)]
        [switch]$DisableEarlyFiltering
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting menu creation operation" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Parameters - MenuName: '$MenuName', Title: '$Title', Description: '$Description', DisableEarlyFiltering: $DisableEarlyFiltering" -LogLevel "Debug"
    
    # Performance tracking
    $startTime = Get-Date
    
    # If MenuName is provided, try to load from configuration
    if ($MenuName)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading menu from configuration: $MenuName" -LogLevel "Verbose"
        
        try {
            $menuConfig = Get-CachedMenuConfiguration -MenuName $MenuName -MenuConfigFile $MenuConfigFile
            
            if ($menuConfig)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully loaded menu configuration for: $MenuName" -LogLevel "Verbose"
                $itemCount = if ($menuConfig.items) { $menuConfig.items.Count } else { 0 }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Menu type: $($menuConfig.type), Items count: $itemCount" -LogLevel "Debug"
                
                # Create menu object from configuration
                $menu = [ordered]@{
                    Title       = $menuConfig.Title
                    Description = $menuConfig.Description
                    Items       = @()
                    PreFiltered = $false
                }
                
                Write-Log -LogFile $LogFile -Module $functionName -Message "Created base menu object with title: '$($menu.Title)'" -LogLevel "Debug"
                
                # If menu type is static and has items, add them
                if ($menuConfig.type -eq "static" -and $menuConfig.items)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Processing static menu items: $($menuConfig.items.Count) items to process" -LogLevel "Verbose"
                    
                    # Apply early filtering based on app mode to improve performance (unless disabled)
                    if ($DisableEarlyFiltering)
                    {
                        $filteredItems = $menuConfig.items
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Early filtering disabled, using all $($filteredItems.Count) items (compatibility mode)" -LogLevel "Verbose"
                    }
                    else
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Applying early filtering optimization to menu items" -LogLevel "Debug"
                        $filteredItems = FilterMenuItemsByAppMode -MenuItems $menuConfig.items
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Early filtering completed: $($menuConfig.items.Count) -> $($filteredItems.Count) items ($(if ($menuConfig.items.Count -gt 0) { [math]::Round((($menuConfig.items.Count - $filteredItems.Count) / $menuConfig.items.Count) * 100, 1) } else { 0 })% reduction)" -LogLevel "Verbose"
                        $menu.PreFiltered = $true
                    }
                    
                    $itemsProcessed = 0
                    $actionItems = 0
                    $submenuItems = 0
                    $defaultedModes = 0
                    
                    foreach ($item in $filteredItems)
                    {
                        $itemsProcessed++
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Processing menu item $itemsProcessed/$($filteredItems.Count): '$($item.name)'" -LogLevel "Debug"
                        
                        # Create menu item with proper structure for AddMenuItem compatibility
                        $menuItem = @{
                            Name = $item.name
                            Description = $item.description
                        }
                        
                        # Handle includeInDisplayModes - default to "full" if empty/missing
                        if ($item.includeInDisplayModes -and $item.includeInDisplayModes.Count -gt 0)
                        {
                            $menuItem.includeInDisplayModes = $item.includeInDisplayModes
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Item '$($item.name)' has display modes: [$($item.includeInDisplayModes -join ', ')]" -LogLevel "Debug"
                        }
                        else
                        {
                            $menuItem.includeInDisplayModes = @("full")
                            $defaultedModes++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Defaulting includeInDisplayModes to 'full' for item: $($item.name)" -LogLevel "Debug"
                        }
                        
                        # Handle different block types
                        if ($item.blockType -eq "action" -or $item.type -eq "action")
                        {
                            $actionItems++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Creating action item: '$($item.name)'" -LogLevel "Debug"
                            
                            # Set placeholder action that can be overridden by AddMenuItem
                            # Capture the item name in the closure
                            $itemName = $item.name
                            $menuItem.Action = {
                                Write-Host "Action not implemented for menu item: $itemName" -ForegroundColor Yellow
                            }.GetNewClosure()
                        }
                        elseif ($item.blockType -eq "menu" -or $item.type -eq "submenu")
                        {
                            $submenuItems++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Creating submenu item: '$($item.name)'" -LogLevel "Debug"
                            
                            # Handle submenu reference
                            if ($item.menuName)
                            {
                                Write-Log -LogFile $LogFile -Module $functionName -Message "Item '$($item.name)' references submenu: $($item.menuName)" -LogLevel "Debug"
                                
                                $submenu = NewMenu -MenuName $item.menuName -MenuConfigFile $MenuConfigFile -DisableEarlyFiltering:$DisableEarlyFiltering
                                if ($submenu)
                                {
                                    $menuItem.Submenu = $submenu
                                    Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully created submenu '$($item.menuName)' with $($submenu.Items.Count) items" -LogLevel "Debug"
                                }
                                else
                                {
                                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to create submenu: $($item.menuName)" -LogLevel "Warning"
                                }
                            }
                            else
                            {
                                Write-Log -LogFile $LogFile -Module $functionName -Message "Submenu item '$($item.name)' has no menuName specified" -LogLevel "Warning"
                            }
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Unknown block type for item '$($item.name)': $($item.blockType)/$($item.type)" -LogLevel "Warning"
                        }
                        
                        $menu.Items += $menuItem
                    }
                    
                    $endTime = Get-Date
                    $duration = ($endTime - $startTime).TotalMilliseconds
                    
                    # Summary logging
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu creation completed - Items processed: $itemsProcessed, Actions: $actionItems, Submenus: $submenuItems, Defaulted modes: $defaultedModes" -LogLevel "Verbose"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Performance: Menu creation completed in $duration milliseconds" -LogLevel "Verbose"
                }
                else
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' is not static type or has no items - Type: $($menuConfig.type)" -LogLevel "Debug"
                }
                
                Write-Log -LogFile $LogFile -Module $functionName -Message "Created menu '$($menu.Title)' with $($menu.Items.Count) items from configuration" -LogLevel "Information"
                return $menu
            }
            else
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Could not load menu configuration for '$MenuName', falling back to manual creation" -LogLevel "Warning"
            }
        }
        catch {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error loading menu configuration for '$MenuName': $_ - falling back to manual creation" -LogLevel "Error"
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No MenuName provided, creating manual menu" -LogLevel "Debug"
    }
    
    # Fallback to manual creation if no MenuName provided or config not found
    if (-not $Title)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No Title provided and no menu configuration found - cannot create menu" -LogLevel "Error"
        throw "Either MenuName (for configuration-based menu) or Title (for manual menu) must be provided"
    }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Creating new menu manually with title: '$Title' and description: '$Description'" -LogLevel "Information"
    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    Write-Log -LogFile $LogFile -Module $functionName -Message "Manual menu creation completed in $duration milliseconds" -LogLevel "Debug"
    
    return $menu
}

