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
        [string]$MenuConfigFile = "$pwd\menu.json"
    )
    $functionName = $MyInvocation.MyCommand.Name
    
    # If MenuName is provided, try to load from configuration
    if ($MenuName)
    {
        Write-Verbose "[$functionName] Loading menu from configuration: $MenuName"
        $menuConfig = Get-MenuConfiguration -MenuName $MenuName -MenuConfigFile $MenuConfigFile
        
        if ($menuConfig)
        {
            Write-Verbose "[$functionName] Successfully loaded menu configuration for: $MenuName"
            
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
                foreach ($item in $menuConfig.items)
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
                    }
                    
                    # Handle different block types
                    if ($item.blockType -eq "action" -or $item.type -eq "action")
                    {
                        # Set placeholder action that can be overridden by AddMenuItem
                        $menuItem.Action = {
                            Write-Host "Action not implemented for menu item: $($item.name)" -ForegroundColor Yellow
                        }
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
            return $menu
        }
        else
        {
            Write-Verbose "[$functionName] Could not load menu configuration for '$MenuName', falling back to manual creation"
        }
    }
    
    # Fallback to manual creation if no MenuName provided or config not found
    if (-not $Title)
    {
        Write-Verbose "[$functionName] No Title provided and no menu configuration found"
        throw "Either MenuName (for configuration-based menu) or Title (for manual menu) must be provided"
    }
    
    Write-Verbose "[$functionName] Creating new menu manually with title: $Title and description: $Description"    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

