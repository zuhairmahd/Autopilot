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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting required menu analysis operation" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Input parameters - AppMode: '$CurrentAppMode', ConfigFile: '$MenuConfigFile'" -LogLevel "Debug"
    
    # Performance tracking
    $startTime = Get-Date
    
    # Always include the main menu
    $requiredMenus = @("mainMenu")
    Write-Log -LogFile $LogFile -Module $functionName -Message "Initialized required menus list with mainMenu" -LogLevel "Debug"
    
    # If no app mode specified or full mode, return all menus
    if (-not $CurrentAppMode -or $CurrentAppMode -eq "full")
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Full access mode detected, analyzing all available menus" -LogLevel "Verbose"
        
        try 
        {
            # Get all menu names from cached configuration
            Write-Log -LogFile $LogFile -Module $functionName -Message "Loading menu configuration for full menu analysis" -LogLevel "Debug"
            $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile $MenuConfigFile
            
            if ($menuConfig) {
                $allMenus = $menuConfig.PSObject.Properties.Name | Where-Object { $_ -notlike "appMode*" -and $_ -notin @("name", "description", "version") }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Found $($allMenus.Count) total menus in configuration: [$($allMenus -join ', ')]" -LogLevel "Verbose"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Full mode analysis completed in $((Get-Date) - $startTime) milliseconds" -LogLevel "Debug"
                return $allMenus
            } else {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load menu configuration, returning minimal menu set" -LogLevel "Warning"
                return $requiredMenus
            }
        }
        catch 
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading menu configuration for full mode: $_ - returning minimal menu set" -LogLevel "Warning"
            return $requiredMenus
        }
    }
    
    try
    {
        # Get app mode hierarchy for filtering
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving app mode hierarchy for dependency analysis" -LogLevel "Debug"
        $hierarchyAllowed = Get-AppModeHierarchy -CurrentAppMode $CurrentAppMode
        Write-Log -LogFile $LogFile -Module $functionName -Message "App mode hierarchy for analysis: [$($hierarchyAllowed -join ', ')] - $($hierarchyAllowed.Count) modes" -LogLevel "Verbose"
        
        # Load menu configuration to analyze dependencies
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading menu configuration for dependency analysis" -LogLevel "Debug"
        $menuConfig = Get-CachedMenuConfiguration -MenuConfigFile $MenuConfigFile
        
        if (-not $menuConfig) {
            Write-Log -LogFile $LogFile -Module $functionName -Message "No menu configuration available, returning minimal menu set" -LogLevel "Warning"
            return $requiredMenus
        }
        
        # Analyze main menu items to find required submenus
        if ($menuConfig.mainMenu -and $menuConfig.mainMenu.items)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing main menu with $($menuConfig.mainMenu.items.Count) items" -LogLevel "Debug"
            
            $filteredMainItems = FilterMenuItemsByAppMode -MenuItems $menuConfig.mainMenu.items -CurrentAppMode $CurrentAppMode
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered main menu items from $($menuConfig.mainMenu.items.Count) to $($filteredMainItems.Count) for current app mode" -LogLevel "Verbose"
            
            $submenuCount = 0
            $nestedMenuCount = 0
            
            foreach ($item in $filteredMainItems)
            {
                # If item references a submenu, add it to required menus
                if ($item.menuName -and $item.menuName -notin $requiredMenus)
                {
                    $requiredMenus += $item.menuName
                    $submenuCount++
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Adding required submenu from main menu: $($item.menuName)" -LogLevel "Debug"
                    
                    # Recursively check for nested menu dependencies
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing nested dependencies for submenu: $($item.menuName)" -LogLevel "Debug"
                    $nestedMenus = GetRequiredMenusRecursive -MenuName $item.menuName -MenuConfig $menuConfig -CurrentAppMode $CurrentAppMode
                    
                    foreach ($nestedMenu in $nestedMenus)
                    {
                        if ($nestedMenu -notin $requiredMenus)
                        {
                            $requiredMenus += $nestedMenu
                            $nestedMenuCount++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Adding nested required menu: $nestedMenu" -LogLevel "Debug"
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Nested menu already in required list: $nestedMenu" -LogLevel "Debug"
                        }
                    }
                }
                elseif ($item.menuName)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Submenu already in required list: $($item.menuName)" -LogLevel "Debug"
                }
            }
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Dependency analysis completed - Direct submenus: $submenuCount, Nested menus: $nestedMenuCount" -LogLevel "Verbose"
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "No main menu items found in configuration" -LogLevel "Warning"
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        # Summary logging
        Write-Log -LogFile $LogFile -Module $functionName -Message "Required menu analysis completed for '$CurrentAppMode': [$($requiredMenus -join ', ')] - $($requiredMenus.Count) total menus" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Performance: Menu analysis completed in $duration milliseconds" -LogLevel "Verbose"
        
        return $requiredMenus
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error analyzing menu dependencies: $_ - returning minimal menu set" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fallback: Returning basic required menus: [$($requiredMenus -join ', ')]" -LogLevel "Warning"
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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Analyzing with app mode: $CurrentAppMode" -LogLevel "Debug"
    
    $nestedMenus = @()
    $itemsProcessed = 0
    $nestedReferencesFound = 0
    
    # Check if the specified menu exists in configuration
    if ($MenuConfig.PSObject.Properties.Name -contains $MenuName)
    {
        $menuDef = $MenuConfig.$MenuName
        Write-Log -LogFile $LogFile -Module $functionName -Message "Found menu definition for: $MenuName" -LogLevel "Debug"
        
        # If this menu has items, check for nested menu references
        if ($menuDef.items)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' has $($menuDef.items.Count) items to analyze" -LogLevel "Debug"
            
            $filteredItems = FilterMenuItemsByAppMode -MenuItems $menuDef.items -CurrentAppMode $CurrentAppMode
            Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered items for '$MenuName' from $($menuDef.items.Count) to $($filteredItems.Count)" -LogLevel "Debug"
            
            foreach ($item in $filteredItems)
            {
                $itemsProcessed++
                $itemName = if ($item.name) { $item.name } else { "Unnamed Item $itemsProcessed" }
                
                if ($item.menuName -and $item.menuName -notin $nestedMenus)
                {
                    $nestedMenus += $item.menuName
                    $nestedReferencesFound++
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Found nested menu reference in '$MenuName': $($item.menuName) (from item: $itemName)" -LogLevel "Debug"
                    
                    # Recursively check this nested menu
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Recursively analyzing nested menu: $($item.menuName)" -LogLevel "Debug"
                    $deeperMenus = GetRequiredMenusRecursive -MenuName $item.menuName -MenuConfig $MenuConfig -CurrentAppMode $CurrentAppMode
                    
                    $addedDeeperMenus = 0
                    foreach ($deeperMenu in $deeperMenus)
                    {
                        if ($deeperMenu -notin $nestedMenus)
                        {
                            $nestedMenus += $deeperMenu
                            $addedDeeperMenus++
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Added deeper nested menu from '$($item.menuName)': $deeperMenu" -LogLevel "Debug"
                        }
                        else
                        {
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Deeper menu already tracked: $deeperMenu" -LogLevel "Debug"
                        }
                    }
                    
                    if ($addedDeeperMenus -gt 0) {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Added $addedDeeperMenus deeper nested menus from: $($item.menuName)" -LogLevel "Debug"
                    }
                }
                elseif ($item.menuName)
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Menu reference already tracked: $($item.menuName) (from item: $itemName)" -LogLevel "Debug"
                }
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu '$MenuName' has no items or items property" -LogLevel "Debug"
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu definition not found in configuration: $MenuName" -LogLevel "Warning"
    }
    
    # Summary logging
    Write-Log -LogFile $LogFile -Module $functionName -Message "Recursive analysis completed for '$MenuName' - Items: $itemsProcessed, References: $nestedReferencesFound, Total nested: $($nestedMenus.Count)" -LogLevel "Debug"
    if ($nestedMenus.Count -gt 0) {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Nested menus found for '$MenuName': [$($nestedMenus -join ', ')]" -LogLevel "Verbose"
    }
    
    return $nestedMenus
}