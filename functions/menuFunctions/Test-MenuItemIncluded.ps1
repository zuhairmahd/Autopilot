function Test-MenuItemIncluded()
{
    <#
    .SYNOPSIS
    Determines if a menu item should be included based on application mode configuration.

    .DESCRIPTION
    This function checks whether a specific menu item should be included in the current menu
    based on the active application modes and menu configuration. It loads menu configuration
    from file if not provided, maps the current menu to its configuration, and checks the
    item's includeInDisplayModes property against effective app modes. The function supports
    hierarchical app mode checking through inheritance.

    .PARAMETER MenuItemName
    The name of the menu item to check for inclusion. This parameter is mandatory.

    .PARAMETER Menus
    Optional array of menu configuration objects. If not provided, loads from menu.psd1.

    .PARAMETER CurrentMenu
    Optional hashtable representing the current menu context for more accurate lookups.

    .OUTPUTS
    System.Boolean
    Returns $true if the menu item should be included based on app modes, $false otherwise.
    Returns $true by default if no app mode restrictions are found.

    .EXAMPLE
    if (Test-MenuItemIncluded -MenuItemName "Advanced Features" -CurrentMenu $menu) {
        # Show advanced features menu item
    }

    .NOTES
    Uses Get-EffectiveAppModes to determine active application modes.
    Loads menu configuration from Get-CachedMenuConfiguration if not provided.
    Supports menu title pattern matching to identify current menu type.
    Checks includeInDisplayModes property for app mode filtering.
    Includes hierarchical app mode checking (e.g., "reporting" includes "reporting.devices").
    Returns $true by default if no app mode configuration exists.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuItemName,
        [Parameter(Mandatory = $false)]
        [PSCustomObject[]]$Menus,
        [Parameter(Mandatory = $false)]
        [hashtable]$CurrentMenu
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking if menu item '$MenuItemName' should be included"
    # Get effective app modes (handle both single and multiple modes)
    $effectiveAppModes = Get-EffectiveAppModes -Settings $settings
    Write-Verbose "[$functionName] Effective app modes: [$($effectiveAppModes -join ', ')]"  
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting menu item inclusion check for '$MenuItemName' with effective app modes: [$($effectiveAppModes -join ', ')]" -LogLevel "Verbose"

    # If $Menus parameter is null, check if we can load menu configuration from file
    if ($null -eq $Menus)
    {
        Write-Verbose "[$functionName] Menus parameter is null, attempting to load from menu.psd1"
        try
        {
            $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile "$pwd\menu.psd1"
            if ($menuConfig)
            {
                Write-Verbose "[$functionName] Successfully loaded menu configuration from file"
                
                # Try to determine which menu we're working with
                $menuType = $null
                if ($CurrentMenu -and $CurrentMenu.Title)
                {
                    $menuTitle = $CurrentMenu.Title
                    Write-Verbose "[$functionName] Current menu title: '$menuTitle'"
                    
                    # Map menu titles to menu configuration keys
                    foreach ($configKey in $menuConfig.Keys)
                    {
                        $config = $menuConfig[$configKey]
                        if ($config.Title -and $config.Title -like "*$menuTitle*")
                        {
                            $menuType = $configKey
                            Write-Verbose "[$functionName] Matched menu type: '$menuType'"
                            break
                        }
                    }
                    
                    # Additional pattern matching for common menu types
                    if (-not $menuType)
                    {
                        if ($menuTitle -like "*Autopilot*")
                        {
                            $menuType = "autopilotMenu"
                        }
                        elseif ($menuTitle -like "*Device Actions*" -or $menuTitle -like "*Select an action*")
                        {
                            $menuType = "deviceActionsMenu"
                        }
                        elseif ($menuTitle -like "*Options for Device*" -or $menuTitle -like "*Choose what you would like to do*")
                        {
                            $menuType = "deviceWaitMenu"
                        }
                        else
                        {
                            $menuType = "mainMenu"
                        }
                        Write-Verbose "[$functionName] Using pattern-matched menu type: '$menuType'"
                    }
                }
                
                if ($menuType -and $menuConfig[$menuType])
                {
                    Write-Verbose "[$functionName] Using menu configuration for type: '$menuType'"
                    return Test-MenuItemIncluded -MenuItemName $MenuItemName -Menus @($menuConfig[$menuType]) -CurrentMenu $CurrentMenu
                }
            }
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to load menu configuration: $_"
        }
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Could not load menu configuration, allowing menu item '$MenuItemName'" -LogLevel "Debug"
        return $true
    }
    
    # Get combined app mode hierarchy from menu configuration for all effective modes
    $hierarchyResult = Get-CombinedAppModeHierarchy -AppModes $effectiveAppModes
    
    # Extract the actual allowed modes array from the result
    $hierarchyAllowed = if ($hierarchyResult -is [hashtable] -and $hierarchyResult.AllowedModes) {
        $hierarchyResult.AllowedModes
    } else {
        $hierarchyResult
    }
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Combined app mode hierarchy for [$($effectiveAppModes -join ', ')]: [$($hierarchyAllowed -join ', ')]" -LogLevel "Debug"

    # If the $settings.appMode hierarchy includes '*', assume the menu needs to be displayed (full mode)
    if ($hierarchyAllowed -contains '*')
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "App mode hierarchy includes '*' (full access), allowing menu item '$MenuItemName'" -LogLevel "Debug"
        return $true
    }

    # Helper function to recursively search for menu item
    function Find-MenuItemRecursive()
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$SearchName,
            [Parameter(Mandatory = $true)]
            [PSCustomObject[]]$MenuItems
        )
        $functionName = $MyInvocation.MyCommand.Name
        Write-Log -LogFile $LogFile -Module $functionName -Message "Searching for menu item '$SearchName' in provided menus" -LogLevel "Verbose"
        foreach ($menuItem in $MenuItems)
        {
            # Check if this menu item matches the search name
            Write-Log -LogFile $LogFile -Module $functionName -Message "Checking menu item: $($menuItem.name)" -LogLevel "Verbose"
            if ($menuItem.name -eq $SearchName)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$SearchName'" -LogLevel "Verbose"
                return $menuItem
            }
            
            # If this menu item has sub-items, search recursively
            if ($menuItem.items -and $menuItem.items.Count -gt 0)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$($menuItem.name)' has sub-items, searching recursively" -LogLevel "Verbose"
                $found = Find-MenuItemRecursive -SearchName $SearchName -MenuItems $menuItem.items
                if ($found)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$SearchName' in sub-items of '$($menuItem.name)'" -LogLevel "Verbose"
                    return $found
                }
            }
        }
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$SearchName' not found in provided menus" -LogLevel "Verbose"
        # If we reach here, the item was not found
        return $null
    }

    # Search for the menu item in the provided menus
    $foundMenuItem = Find-MenuItemRecursive -SearchName $MenuItemName -MenuItems $Menus
    
    # If the menu item is not found, return true (include it by default)
    if ($null -eq $foundMenuItem)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' not found in menus configuration, allowing by default" -LogLevel "Verbose"
        return $true
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu item '$MenuItemName' in menus configuration" -LogLevel "Verbose"

    # Check if the menu item has includeInDisplayModes array
    if ($foundMenuItem.includeInDisplayModes -and $foundMenuItem.includeInDisplayModes.Count -gt 0)
    {
        # Use hierarchical checking instead of direct matching
        $appModeMatches = $false
        foreach ($allowedMode in $foundMenuItem.includeInDisplayModes)
        {
            if ($hierarchyAllowed -contains $allowedMode)
            {
                $appModeMatches = $true
                break
            }
        }
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu item '$MenuItemName' hierarchical includeInDisplayModes check: $appModeMatches (checking [$($foundMenuItem.includeInDisplayModes -join ', ')] against hierarchy [$($hierarchyAllowed -join ', ')])" -LogLevel "Verbose"
        return $appModeMatches
    }

    # If no includeInDisplayModes array is found, include by default
    Write-Log -LogFile $LogFile -Module $functionName -Message "No includeInDisplayModes found for menu item '$MenuItemName', allowing by default" -LogLevel "Verbose"
    return $true
}

