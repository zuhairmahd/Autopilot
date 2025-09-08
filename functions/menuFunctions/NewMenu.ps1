function NewMenu()
{
    <#
    .SYNOPSIS
        Creates a new menu from configuration or manually.
    
    .DESCRIPTION
        Creates a simple menu structure from configuration or manually. 
        No filtering or actions are applied - this is handled by AddMenuItem and ShowMenu.
        This is a simplified approach that separates menu creation from action assignment.
    
    .PARAMETER Title
        Title for manually created menus
        
    .PARAMETER Description
        Description for manually created menus
        
    .PARAMETER MenuName
        Name of menu to load from configuration
        
    .PARAMETER MenuConfigFile
        Path to menu configuration file
        
    .OUTPUTS
        Hashtable - Menu object with basic structure
        
    .NOTES
        - Simplified implementation focused on structure only
        - No filtering applied - handled by ShowMenu
        - No placeholder actions - handled by AddMenuItem  
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
        [string]$MenuConfigFile = "$pwd\menu"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating menu - MenuName: '$MenuName', Title: '$Title'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Creating menu - MenuName: '$MenuName', Title: '$Title'" -LogLevel "Debug"
    
    # Try to load from configuration if MenuName is provided
    if ($MenuName)
    {
        Write-Verbose "[$functionName] Loading menu from configuration: $MenuName"
        
        try
        {
            $menuConfig = Get-CachedMenuConfiguration -MenuName $MenuName -MenuConfigFile $MenuConfigFile
            
            if ($menuConfig)
            {
                Write-Verbose "[$functionName] Successfully loaded menu configuration for: $MenuName"
                
                # Create base menu object
                $menu = @{
                    Title       = $menuConfig.Title
                    Description = $menuConfig.Description
                    Items       = @()
                }
                
                # Process static menu items if they exist
                if ($menuConfig.type -eq "static" -and $menuConfig.items)
                {
                    Write-Verbose "[$functionName] Processing $($menuConfig.items.Count) static menu items"
                    
                    # Process each menu item - no filtering, just structure
                    foreach ($item in $menuConfig.items)
                    {
                        $menuItem = @{
                            Name        = $item.name
                            Description = $item.description
                        }
                        
                        # Preserve display modes for ShowMenu to use
                        $menuItem.includeInDisplayModes = if ($item.includeInDisplayModes -and $item.includeInDisplayModes.Count -gt 0) {
                            $item.includeInDisplayModes
                        } else {
                            @("full")
                        }
                        
                        # Handle different item types
                        if ($item.blockType -eq "action" -or $item.type -eq "action")
                        {
                            # No action assigned - AddMenuItem will handle this
                            $menuItem.Action = $null
                        }
                        elseif ($item.blockType -eq "menu" -or $item.type -eq "submenu")
                        {
                            # Handle submenu reference
                            if ($item.menuName)
                            {
                                Write-Verbose "[$functionName] Creating submenu: $($item.menuName)"
                                $submenu = NewMenu -MenuName $item.menuName -MenuConfigFile $MenuConfigFile
                                if ($submenu)
                                {
                                    $menuItem.Submenu = $submenu
                                }
                                else
                                {
                                    Write-Warning "[$functionName] Failed to create submenu: $($item.menuName)"
                                }
                            }
                            else
                            {
                                Write-Warning "[$functionName] Submenu item '$($item.name)' has no menuName specified"
                            }
                        }
                        else
                        {
                            Write-Warning "[$functionName] Unknown item type for '$($item.name)': $($item.blockType)/$($item.type)"
                        }
                        
                        $menu.Items += $menuItem
                    }
                }
                
                Write-Verbose "[$functionName] Created menu '$($menu.Title)' with $($menu.Items.Count) items"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully created menu '$($menu.Title)' with $($menu.Items.Count) items" -LogLevel "Information"
                return $menu
            }
            else
            {
                Write-Warning "[$functionName] Could not load menu configuration for '$MenuName'"
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error loading menu configuration for '$MenuName': $_"
        }
    }
    
    # Fallback to manual creation or if no MenuName provided
    if (-not $Title)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No Title provided and no menu configuration found - cannot create menu" -LogLevel "Error"
        throw "Either MenuName (for configuration-based menu) or Title (for manual menu) must be provided"
    }
    
    Write-Verbose "[$functionName] Creating manual menu with title: '$Title'"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Creating manual menu: '$Title'" -LogLevel "Information"
    
    $menu = @{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

