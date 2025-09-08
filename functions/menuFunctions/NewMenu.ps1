function NewMenu()
{
    <#
    .SYNOPSIS
        Creates a new menu from configuration or manually.
    
    .DESCRIPTION
        Creates a new menu either from configuration or manually, with proper
        menu item structure and filtering support.
    
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
        - Simplified implementation focused on core menu creation
        - Maintains PowerShell 5.1 compatibility
        - Supports both configuration-based and manual menu creation
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
    Write-Verbose "[$functionName] Starting menu creation - MenuName: '$MenuName', Title: '$Title'"
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
                $menu = [ordered]@{
                    Title       = $menuConfig.Title
                    Description = $menuConfig.Description
                    Items       = @()
                    PreFiltered = $false
                }
                
                # Process static menu items if they exist
                if ($menuConfig.type -eq "static" -and $menuConfig.items)
                {
                    Write-Verbose "[$functionName] Processing $($menuConfig.items.Count) static menu items"
                    
                    # Apply filtering if enabled
                    $itemsToProcess = if ($DisableEarlyFiltering) { 
                        $menuConfig.items 
                    } else { 
                        FilterMenuItemsByAppMode -MenuItems $menuConfig.items
                        $menu.PreFiltered = $true
                    }
                    
                    # Process each menu item
                    foreach ($item in $itemsToProcess)
                    {
                        $menuItem = @{
                            Name        = $item.name
                            Description = $item.description
                        }
                        
                        # Set display modes (default to "full" if not specified)
                        $menuItem.includeInDisplayModes = if ($item.includeInDisplayModes -and $item.includeInDisplayModes.Count -gt 0) {
                            $item.includeInDisplayModes
                        } else {
                            @("full")
                        }
                        
                        # Handle different item types
                        if ($item.blockType -eq "action" -or $item.type -eq "action")
                        {
                            # Create placeholder action that AddMenuItem can override
                            $itemName = $item.name
                            $currentLogFile = $LogFile
                            $currentFunctionName = $functionName
                            $menuItem.Action = {
                                Write-Log -LogFile $currentLogFile -Module $currentFunctionName -Message "Placeholder action called for menu item: $itemName - action may not have been properly initialized" -LogLevel "Warning"
                                Write-Verbose "[$currentFunctionName] Placeholder action executed for menu item: $itemName"
                                Write-Host "This feature is not yet configured. Please contact your administrator." -ForegroundColor Yellow
                            }.GetNewClosure()
                        }
                        elseif ($item.blockType -eq "menu" -or $item.type -eq "submenu")
                        {
                            # Handle submenu reference
                            if ($item.menuName)
                            {
                                Write-Verbose "[$functionName] Creating submenu: $($item.menuName)"
                                $submenu = NewMenu -MenuName $item.menuName -MenuConfigFile $MenuConfigFile -DisableEarlyFiltering:$DisableEarlyFiltering
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
    
    $menu = [ordered]@{
        Title       = $Title
        Description = $Description
        Items       = @()
    }
    
    return $menu
}

