function NewMenu()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Title,
        [Parameter(Mandatory = $false)]
        [string]$Description,
        [Parameter(Mandatory = $false)]
        [string]$MenuName,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.json",
        [Parameter(Mandatory = $false)]
        [switch]$DisableEarlyFiltering
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Creating new menu - MenuName: '$MenuName', Title: '$Title'" -LogLevel "Debug"
    
    # If MenuName is provided, try to load from configuration
    if ($MenuName)
    {
        Write-Verbose "[$functionName] Loading menu from configuration: $MenuName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading menu from configuration: $MenuName" -LogLevel "Debug"
        $menuConfig = Get-MenuConfiguration -MenuName $MenuName -MenuConfigFile $MenuConfigFile
        
        if ($menuConfig)
        {
            Write-Verbose "[$functionName] Successfully loaded menu configuration for: $MenuName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully loaded menu configuration for: $MenuName" -LogLevel "Debug"
            
            # Create menu object from configuration
            $menu = [ordered]@{
                Title       = $menuConfig.Title
                Description = $menuConfig.Description
                Items       = @()
            }
            
            # If menu type is static and has items, add them
            if ($menuConfig.type -eq "static" -and $menuConfig.items)
            {
                Write-Verbose "[$functionName] Adding static menu items from configuration"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Adding $($menuConfig.items.Count) static menu items from configuration" -LogLevel "Debug"
                
                # Apply early filtering based on app mode to improve performance (unless disabled)
                if ($DisableEarlyFiltering)
                {
                    $filteredItems = $menuConfig.items
                    Write-Verbose "[$functionName] Early filtering disabled, using all $($filteredItems.Count) items"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Early filtering disabled, using all items" -LogLevel "Debug"
                }
                else
                {
                    $filteredItems = FilterMenuItemsByAppMode -MenuItems $menuConfig.items
                    Write-Verbose "[$functionName] Filtered to $($filteredItems.Count) items for current app mode"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered to $($filteredItems.Count) items for current app mode" -LogLevel "Debug"
                }
                
                foreach ($item in $filteredItems)
                {
                    # Create menu item with proper structure for AddMenuItem compatibility
                    $menuItem = @{
                        Name = $item.name
                        Description = $item.description
                    }
                    
                    # Handle includeInDisplayModes - default to "full" if empty/missing
                    if ($item.includeInDisplayModes -and $item.includeInDisplayModes.Count -gt 0)
                    {
                        $menuItem.includeInDisplayModes = $item.includeInDisplayModes
                    }
                    else
                    {
                        $menuItem.includeInDisplayModes = @("full")
                        Write-Verbose "[$functionName] Defaulting includeInDisplayModes to 'full' for item: $($item.name)"
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Defaulting includeInDisplayModes to 'full' for item: $($item.name)" -LogLevel "Debug"
                    }
                    
                    # Handle different block types
                    if ($item.blockType -eq "action" -or $item.type -eq "action")
                    {
                        # Set placeholder action that can be overridden by AddMenuItem
                        # Capture the item name in the closure
                        $itemName = $item.name
                        $menuItem.Action = {
                            Write-Host "Action not implemented for menu item: $itemName" -ForegroundColor Yellow
                        }.GetNewClosure()
                    }
                    elseif ($item.blockType -eq "menu" -or $item.type -eq "submenu")
                    {
                        # Handle submenu reference
                        if ($item.menuName)
                        {
                            Write-Verbose "[$functionName] Item '$($item.name)' references submenu: $($item.menuName)"
                            $submenu = NewMenu -MenuName $item.menuName -MenuConfigFile $MenuConfigFile
                            if ($submenu)
                            {
                                $menuItem.Submenu = $submenu
                            }
                        }
                    }
                    
                    $menu.Items += $menuItem
                }
            }
            
            Write-Verbose "[$functionName] Created menu '$($menu.Title)' with $($menu.Items.Count) items from configuration"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Created menu '$($menu.Title)' with $($menu.Items.Count) items from configuration" -LogLevel "Information"
            return $menu
        }
        else
        {
            Write-Verbose "[$functionName] Could not load menu configuration for '$MenuName', falling back to manual creation"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Could not load menu configuration for '$MenuName', falling back to manual creation" -LogLevel "Warning"
        }
    }
    
    # Fallback to manual creation if no MenuName provided or config not found
    if (-not $Title)
    {
        Write-Verbose "[$functionName] No Title provided and no menu configuration found"
        throw "Either MenuName (for configuration-based menu) or Title (for manual menu) must be provided"
    }
    
    Write-Verbose "[$functionName] Creating new menu manually with title: $Title and description: $Description"  
    Write-Log -LogFile $LogFile -Module $functionName -Message "Creating new menu manually with title: $Title and description: $Description" -LogLevel "Information"    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

