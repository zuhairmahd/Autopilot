function GetRequiredMenusForAppMode()
{
    <#
    .SYNOPSIS
        Determines required menus for the current application mode with extensive logging.
    
    .DESCRIPTION
        Analyzes menu dependencies to determine which menus are required for the current
        application mode, providing comprehensive logging for performance monitoring.
    
    .PARAMETER CurrentAppMode
        Current application mode (defaults to settings.appMode)
        
    .PARAMETER MenuConfigFile
        Path to menu configuration file
        
    .OUTPUTS
        Array - Names of required menus for the current app mode
        
    .NOTES
        - Extensive logging for performance optimization monitoring
        - Recursive dependency analysis
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $settings.appMode,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.psd1"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Determining required menus for app mode: $CurrentAppMode"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting required menu analysis operation" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Input parameters - AppMode: '$CurrentAppMode', ConfigFile: '$MenuConfigFile'" -LogLevel "Debug"
    
    # Performance tracking
    $startTime = Get-Date
    
    # Always include the main menu
    $requiredMenus = @("mainMenu")
    Write-Verbose "[$functionName] Initialized required menus with mainMenu"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Initialized required menus list with mainMenu" -LogLevel "Debug"
    
    # If no app mode specified or full mode, return all menus
    if (-not $CurrentAppMode -or $CurrentAppMode -eq "full")
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Full access mode detected, analyzing all available menus" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Full access mode detected, returning all menus"
        try 
        {
            # Get all menu names from cached configuration
            Write-Log -LogFile $LogFile -Module $functionName -Message "Loading menu configuration for full menu analysis" -LogLevel "Debug"
            Write-Verbose "[$functionName] Loading menu configuration for full menu analysis"
            $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile $MenuConfigFile
            Write-Verbose "[$functionName] Menu configuration loaded"
            if ($menuConfig)
            {
                $allMenus = $menuConfig.PSObject.Properties.Name | Where-Object { $_ -notlike "appMode*" -and $_ -notin @("name", "description", "version") }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($allMenus.Count) total menus in configuration: [$($allMenus -join ', ')]" -LogLevel "Verbose"
                Write-Verbose "[$functionName] Found $($allMenus.Count) total menus in configuration"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Full mode analysis completed in $((Get-Date) - $startTime) milliseconds" -LogLevel "Debug"
                Write-Verbose "[$functionName] Full mode analysis completed"
                return $allMenus
            }
            else
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load menu configuration, returning minimal menu set" -LogLevel "Warning"
                Write-Verbose "[$functionName] Failed to load menu configuration, returning minimal menu set"
                return $requiredMenus
            }
        }
        catch 
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading menu configuration for full mode: $_ - returning minimal menu set" -LogLevel "Warning"
            Write-Verbose "[$functionName] Error reading menu configuration for full mode, returning minimal menu set"
            return $requiredMenus
        }
    }
    
    try
    {
        # Get app mode hierarchy for filtering
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving app mode hierarchy for dependency analysis" -LogLevel "Debug"
        Write-Verbose "[$functionName] Retrieving app mode hierarchy for dependency analysis"
        $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $CurrentAppMode
        Write-Log -LogFile $LogFile -Module $functionName -Message "App mode hierarchy for analysis: [$($hierarchyAllowed -join ', ')] - $($hierarchyAllowed.Count) modes" -LogLevel "Verbose"
        Write-Verbose "[$functionName] App mode hierarchy: [$($hierarchyAllowed -join ', ')]"
        # Load menu configuration to analyze dependencies
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading menu configuration for dependency analysis" -LogLevel "Debug"
        $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile $MenuConfigFile
        Write-Verbose "[$functionName] Menu configuration loaded for dependency analysis"
        if (-not $menuConfig)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "No menu configuration available, returning minimal menu set" -LogLevel "Warning"
            Write-Verbose "[$functionName] No menu configuration available, returning minimal menu set"
            return $requiredMenus
        }
        
        # Analyze main menu items to find required submenus
        if ($menuConfig.mainMenu -and $menuConfig.mainMenu.items)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing main menu with $($menuConfig.mainMenu.items.Count) items" -LogLevel "Debug"
            Write-Verbose "[$functionName] Analyzing main menu items with $($menuConfig.mainMenu.items.Count) items"
            $filteredMainItems = FilterMenuItemsByAppMode -MenuItems $menuConfig.mainMenu.items -CurrentAppMode $CurrentAppMode
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered main menu items from $($menuConfig.mainMenu.items.Count) to $($filteredMainItems.Count) for current app mode" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Filtered main menu items from $($menuConfig.mainMenu.items.Count) to $($filteredMainItems.Count) for current app mode"
            $submenuCount = 0
            $nestedMenuCount = 0
            foreach ($item in $filteredMainItems)
            {
                # If item references a submenu, add it to required menus
                Write-Verbose "[$functionName] Checking submenu requirement for item: $($item.name)"
                if ($item.menuName -and $item.menuName -notin $requiredMenus)
                {
                    $requiredMenus += $item.menuName
                    $submenuCount++
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Adding required submenu from main menu: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Added required submenu: $($item.menuName)"
                    # Recursively check for nested menu dependencies
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing nested dependencies for submenu: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Analyzing nested dependencies for submenu: $($item.menuName)"
                    $nestedMenus = GetRequiredMenusRecursive -MenuName $item.menuName -MenuConfig $menuConfig -CurrentAppMode $CurrentAppMode
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($nestedMenus.Count) nested menus for submenu: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Found $($nestedMenus.Count) nested menus for submenu: $($item.menuName)"
                    foreach ($nestedMenu in $nestedMenus)
                    {
                        Write-Verbose "[$functionName] Processing nested menu: $nestedMenu"
                        if ($nestedMenu -notin $requiredMenus)
                        {
                            $requiredMenus += $nestedMenu
                            $nestedMenuCount++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Adding nested required menu: $nestedMenu" -LogLevel "Debug"
                            Write-Verbose "[$functionName] Added nested required menu: $nestedMenu"
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Nested menu already in required list: $nestedMenu" -LogLevel "Debug"
                            Write-Verbose "[$functionName] Nested menu already in required list: $nestedMenu"
                        }
                    }
                }
                elseif ($item.menuName)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Submenu already in required list: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Submenu already in required list: $($item.menuName)"
                }
            }
            Write-Log -LogFile $LogFile -Module $functionName -Message "Dependency analysis completed - Direct submenus: $submenuCount, Nested menus: $nestedMenuCount" -LogLevel "Verbose"
            Write-Verbose "[$functionName] Dependency analysis completed - Direct submenus: $submenuCount, Nested menus: $nestedMenuCount"
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "No main menu items found in configuration" -LogLevel "Warning"
            Write-Verbose "[$functionName] No main menu items found in configuration"
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        Write-Verbose "[$functionName] Menu analysis completed in $duration milliseconds"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu analysis completed in $duration milliseconds" -LogLevel "Verbose"
        # Summary logging
        Write-Log -LogFile $LogFile -Module $functionName -Message "Required menu analysis completed for '$CurrentAppMode': [$($requiredMenus -join ', ')] - $($requiredMenus.Count) total menus" -LogLevel "Information"
        Write-Verbose "[$functionName] Required menus for '$CurrentAppMode': [$($requiredMenus -join ', ')]"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Performance: Menu analysis completed in $duration milliseconds" -LogLevel "Verbose"
        return $requiredMenus
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error analyzing menu dependencies: $_ - returning minimal menu set" -LogLevel "Error"
        Write-Verbose "[$functionName] Error analyzing menu dependencies, returning minimal menu set"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fallback: Returning basic required menus: [$($requiredMenus -join ', ')]" -LogLevel "Warning"
        Write-Verbose "[$functionName] Fallback: Returning basic required menus: [$($requiredMenus -join ', ')]"
        return $requiredMenus
    }
}

function GetRequiredMenusRecursive()
{
    <#
    .SYNOPSIS
        Recursively analyzes menu dependencies with extensive logging.
    
    .DESCRIPTION
        Recursively analyzes a menu's dependencies to find all nested menu references,
        providing comprehensive logging for troubleshooting and performance monitoring.
    
    .PARAMETER MenuName
        Name of the menu to analyze
        
    .PARAMETER MenuConfig
        Menu configuration object
        
    .PARAMETER CurrentAppMode
        Current application mode
        
    .OUTPUTS
        Array - Names of nested menus required by the specified menu
        
    .NOTES
        - Extensive logging for troubleshooting recursive dependencies
        - Prevents infinite recursion through dependency tracking
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MenuName,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MenuConfig,
        [Parameter(Mandatory = $false)]
        [string]$CurrentAppMode = $settings.appMode
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting recursive dependency analysis for menu: $MenuName" -LogLevel "Debug"
    Write-Verbose "[$functionName] Recursively analyzing menu: $MenuName with app mode: $CurrentAppMode"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing with app mode: $CurrentAppMode" -LogLevel "Debug"
    
    $nestedMenus = @()
    $itemsProcessed = 0
    $nestedReferencesFound = 0
    
    # Check if the specified menu exists in configuration
    if ($MenuConfig.PSObject.Properties.Name -contains $MenuName)
    {
        $menuDef = $MenuConfig.$MenuName
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu definition for: $MenuName" -LogLevel "Debug"
        Write-Verbose "[$functionName] Found menu definition for: $MenuName"
        # If this menu has items, check for nested menu references
        if ($menuDef.items)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' has $($menuDef.items.Count) items to analyze" -LogLevel "Debug"
            Write-Verbose "[$functionName] Menu '$MenuName' has $($menuDef.items.Count) items to analyze"
            $filteredItems = FilterMenuItemsByAppMode -MenuItems $menuDef.items -CurrentAppMode $CurrentAppMode
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered items for '$MenuName' from $($menuDef.items.Count) to $($filteredItems.Count)" -LogLevel "Debug"
            Write-Verbose "[$functionName] Filtered items for '$MenuName' from $($menuDef.items.Count) to $($filteredItems.Count)"
            foreach ($item in $filteredItems)
            {
                $itemsProcessed++
                $itemName = if ($item.name)
                {
                    $item.name 
                }
                else
                {
                    "Unnamed Item $itemsProcessed" 
                }
                Write-Verbose "[$functionName] Analyzing menu item: $($item.name)"
                if ($item.menuName -and $item.menuName -notin $nestedMenus)
                {
                    $nestedMenus += $item.menuName
                    $nestedReferencesFound++
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found nested menu reference in '$MenuName': $($item.menuName) (from item: $itemName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Found nested menu reference: $($item.menuName)"
                    # Recursively check this nested menu
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Recursively analyzing nested menu: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Recursively analyzing nested menu: $($item.menuName)"
                    $deeperMenus = GetRequiredMenusRecursive -MenuName $item.menuName -MenuConfig $MenuConfig -CurrentAppMode $CurrentAppMode
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($deeperMenus.Count) deeper nested menus from: $($item.menuName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Found $($deeperMenus.Count) deeper nested menus for submenu: $($item.menuName)"
                    $addedDeeperMenus = 0
                    foreach ($deeperMenu in $deeperMenus)
                    {
                        Write-Verbose "[$functionName] Processing deeper nested menu: $deeperMenu"
                        if ($deeperMenu -notin $nestedMenus)
                        {
                            $nestedMenus += $deeperMenu
                            $addedDeeperMenus++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Added deeper nested menu from '$($item.menuName)': $deeperMenu" -LogLevel "Debug"
                            Write-Verbose "[$functionName] Added deeper nested menu: $deeperMenu"
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Deeper menu already tracked: $deeperMenu" -LogLevel "Debug"
                            Write-Verbose "[$functionName] Deeper menu already tracked: $deeperMenu"
                        }
                    }
                    if ($addedDeeperMenus -gt 0)
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Added $addedDeeperMenus deeper nested menus from: $($item.menuName)" -LogLevel "Debug"
                        Write-Verbose "[$functionName] Added $addedDeeperMenus deeper nested menus from: $($item.menuName)"
                    }
                }
                elseif ($item.menuName)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu reference already tracked: $($item.menuName) (from item: $itemName)" -LogLevel "Debug"
                    Write-Verbose "[$functionName] Menu reference already tracked: $($item.menuName)"
                }
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' has no items or items property" -LogLevel "Debug"
            Write-Verbose "[$functionName] Menu '$MenuName' has no items or items property"
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu definition not found in configuration: $MenuName" -LogLevel "Warning"
        Write-Verbose "[$functionName] Menu definition not found in configuration: $MenuName"
    }
    
    # Summary logging
    Write-Log -LogFile $LogFile -Module $functionName -Message "Recursive analysis completed for '$MenuName' - Items: $itemsProcessed, References: $nestedReferencesFound, Total nested: $($nestedMenus.Count)" -LogLevel "Debug"
    if ($nestedMenus.Count -gt 0)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Nested menus found for '$MenuName': [$($nestedMenus -join ', ')]" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Nested menus found for '$MenuName': [$($nestedMenus -join ', ')]"
    }
    
    return $nestedMenus
}